import Foundation
import Observation
import StoreKit

/// The one-time purchase that unlocks the full app (Chapter 6.2).
///
/// Free: up to `freeItemLimit` items, unlimited outfit generation and sketch previews.
/// Lifetime unlock (non-consumable): unlimited items, the avatar and try-on renders.
///
/// Receipt validation happens on device: StoreKit 2 transactions are JWS-signed by the App Store
/// and `VerificationResult` checks the signature, so only `.verified` transactions count. There is
/// no server, in keeping with the app's on-device design.
@MainActor
@Observable
final class PurchaseManager {
    static let productID = "com.danemadsen.wardrobe.lifetime"
    static let freeItemLimit = 25

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        /// Waiting on Ask to Buy or a payment method update; the unlock arrives later via `Transaction.updates`.
        case pending
        case failed(String)
    }

    private(set) var product: Product?
    private(set) var isUnlocked = false
    private(set) var purchaseState: PurchaseState = .idle
    private(set) var isLoadingProduct = false

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var hasStarted = false

    init() {}

    /// Starts listening for transactions and loads the current entitlement and the product.
    /// Call once at launch; later calls do nothing.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        updatesTask = Task { [weak self] in
            // Purchases made on other devices, Ask to Buy approvals, refunds and revocations.
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task {
            await refreshEntitlements()
            await loadProduct()
        }
    }

    func canAddItem(currentItemCount: Int) -> Bool {
        isUnlocked || currentItemCount < Self.freeItemLimit
    }

    func loadProduct() async {
        guard product == nil, !isLoadingProduct else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            product = nil
        }
    }

    func purchase() async {
        if product == nil {
            await loadProduct()
        }
        guard let product else {
            purchaseState = .failed("The App Store isn't reachable right now. Check your connection and try again.")
            return
        }
        purchaseState = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try Self.verified(verification)
                await transaction.finish()
                await refreshEntitlements()
                purchaseState = .idle
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed("The purchase didn't go through. \(error.localizedDescription)")
        }
    }

    /// Re-syncs purchases with the App Store (may ask the user to sign in).
    func restore() async {
        purchaseState = .purchasing
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = isUnlocked ? .idle : .failed("No previous purchase was found for this Apple Account.")
        } catch StoreKitError.userCancelled {
            purchaseState = .idle
        } catch {
            purchaseState = .failed("Purchases couldn't be restored. \(error.localizedDescription)")
        }
    }

    func clearError() {
        if case .failed = purchaseState {
            purchaseState = .idle
        }
    }

    /// Recomputes `isUnlocked` from the verified, unrevoked entitlements.
    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productID, transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isUnlocked = unlocked
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = update {
            await transaction.finish()
        }
        await refreshEntitlements()
        if isUnlocked, purchaseState == .pending {
            purchaseState = .idle
        }
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }
}
