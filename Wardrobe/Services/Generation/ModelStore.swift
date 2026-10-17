import CryptoKit
import Foundation
import Observation
import WardrobeCore
import ZIPFoundation

/// Downloads, verifies and installs the on-device image model, once (Chapter 4.3).
///
/// This is the app's only network access, and it only happens when the user taps Download after
/// accepting the model license. The archive comes straight from the model's public page, is
/// checked against a pinned SHA-256, unpacked into Application Support (excluded from backups),
/// and the archive is deleted.
@MainActor
@Observable
final class ModelStore {
    enum State: Equatable {
        case notInstalled
        case downloading(fraction: Double)
        case verifying
        case installing
        case installed
        case failed(String)
    }

    let model: ImageModelDescriptor
    private(set) var state: State

    @ObservationIgnored private var downloader: ModelDownloader?
    @ObservationIgnored private var resumeData: Data?
    @ObservationIgnored private var installTask: Task<Void, Never>?

    init(model: ImageModelDescriptor = ImageModelCatalog.default) {
        self.model = model
        state = Self.isInstalled(model) ? .installed : .notInstalled
    }

    /// Where the model's resources live once installed.
    var resourcesURL: URL? {
        state == .installed ? Self.installURL(for: model) : nil
    }

    var isBusy: Bool {
        switch state {
        case .downloading, .verifying, .installing: true
        case .notInstalled, .installed, .failed: false
        }
    }

    /// Free space on the device, when the system reports it.
    var availableBytes: Int64? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    var hasEnoughSpace: Bool {
        guard let available = availableBytes else { return true }
        return available >= model.requiredFreeBytes
    }

    func download() {
        guard !isBusy, state != .installed else { return }
        guard hasEnoughSpace else {
            let needed = ByteCountFormatter.string(fromByteCount: model.requiredFreeBytes, countStyle: .file)
            state = .failed("Not enough free space. The model needs about \(needed) while installing.")
            return
        }
        state = .downloading(fraction: 0)
        let model = model
        let resume = resumeData
        resumeData = nil

        installTask = Task {
            let downloader = ModelDownloader { [weak self] fraction in
                Task { @MainActor in
                    guard let self, case .downloading = self.state else { return }
                    self.state = .downloading(fraction: fraction)
                }
            }
            self.downloader = downloader
            do {
                let archive = try await downloader.download(from: model.downloadURL, resumeData: resume)
                self.downloader = nil
                state = .verifying
                try await Self.verifyAndInstall(archive: archive, model: model) { [weak self] in
                    Task { @MainActor in self?.state = .installing }
                }
                state = .installed
            } catch let error as ModelDownloader.DownloadError {
                self.downloader = nil
                switch error {
                case .cancelled(let data):
                    resumeData = data
                    state = .notInstalled
                case .failed(let message, let data):
                    resumeData = data
                    state = .failed(message)
                }
            } catch {
                self.downloader = nil
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        downloader?.cancel()
    }

    /// Deletes the installed model to free space. It can be downloaded again later.
    func remove() {
        guard !isBusy else { return }
        DiffusionEngine.shared.unload()
        try? FileManager.default.removeItem(at: Self.installURL(for: model))
        resumeData = nil
        state = .notInstalled
    }

    // MARK: - Files

    nonisolated static func modelsDirectory() -> URL {
        URL.applicationSupportDirectory.appending(path: "Models", directoryHint: .isDirectory)
    }

    nonisolated static func installURL(for model: ImageModelDescriptor) -> URL {
        modelsDirectory().appending(path: model.id, directoryHint: .isDirectory)
    }

    nonisolated static func isInstalled(_ model: ImageModelDescriptor) -> Bool {
        let path = installURL(for: model).path
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: path) else { return false }
        return model.missingResources(in: Set(names)).isEmpty
    }

    /// Checks the archive's SHA-256, unpacks it, and moves the model folder into place.
    /// Runs off the main actor; deletes the archive whatever happens.
    private nonisolated static func verifyAndInstall(archive: URL, model: ImageModelDescriptor, onInstalling: @escaping @Sendable () -> Void) async throws {
        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            defer { try? fileManager.removeItem(at: archive) }

            guard try sha256(of: archive) == model.sha256 else {
                throw InstallError("The download was damaged. Please try again.")
            }
            onInstalling()

            let modelsDirectory = modelsDirectory()
            let staging = modelsDirectory.appending(path: "staging-\(UUID().uuidString)", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: staging) }

            try fileManager.unzipItem(at: archive, to: staging)
            let unpacked = staging.appending(path: model.archiveFolder, directoryHint: .isDirectory)
            let names = Set((try? fileManager.contentsOfDirectory(atPath: unpacked.path)) ?? [])
            let missing = model.missingResources(in: names)
            guard missing.isEmpty else {
                throw InstallError("The model is incomplete (missing \(missing.joined(separator: ", "))). Please try again.")
            }

            var destination = installURL(for: model)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: unpacked, to: destination)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? destination.setResourceValues(values)
        }.value
    }

    private nonisolated static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 8 * 1_024 * 1_024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private struct InstallError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}

/// A single large download with progress, cancellation and resume data, on a delegate-based
/// URLSession (the async convenience APIs don't report download progress).
final class ModelDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    enum DownloadError: Error {
        /// The user cancelled; resume data lets the next attempt continue where this one stopped.
        case cancelled(resumeData: Data?)
        case failed(String, resumeData: Data?)
    }

    private let onProgress: @Sendable (Double) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?
    private var task: URLSessionDownloadTask?
    private var session: URLSession?
    private var userCancelled = false

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func download(from url: URL, resumeData: Data?) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForResource = 60 * 60 * 3
            configuration.waitsForConnectivity = true
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
            let task = resumeData.map { session.downloadTask(withResumeData: $0) } ?? session.downloadTask(with: url)
            lock.lock()
            self.continuation = continuation
            self.session = session
            self.task = task
            lock.unlock()
            task.resume()
        }
    }

    func cancel() {
        lock.lock()
        userCancelled = true
        let task = self.task
        lock.unlock()
        task?.cancel(byProducingResumeData: { _ in
            // The resume data also arrives in didCompleteWithError's userInfo; handled there.
        })
    }

    // MARK: URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The temporary file is deleted when this method returns, so move it now.
        if let response = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            finish(.failure(DownloadError.failed("The download server returned an error (\(response.statusCode)).", resumeData: nil)))
            return
        }
        let destination = FileManager.default.temporaryDirectory.appending(path: "model-\(UUID().uuidString).zip")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            finish(.success(destination))
        } catch {
            finish(.failure(DownloadError.failed("The download couldn't be saved. \(error.localizedDescription)", resumeData: nil)))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer { session.finishTasksAndInvalidate() }
        guard let error else { return }
        let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        lock.lock()
        let cancelled = userCancelled
        lock.unlock()
        if cancelled {
            finish(.failure(DownloadError.cancelled(resumeData: resumeData)))
        } else {
            finish(.failure(DownloadError.failed("The download stopped. \(error.localizedDescription)", resumeData: resumeData)))
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
