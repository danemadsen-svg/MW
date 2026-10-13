/// The colors that dominate an item photo.
public struct DominantColors: Hashable, Sendable {
    public let primary: RGBColor
    /// A second color covering a meaningful share of the item (stripes, prints, two-tone pieces).
    public let secondary: RGBColor?
    /// Share of item pixels belonging to the primary color, 0...1.
    public let primaryCoverage: Double
    /// Share of item pixels belonging to the secondary color, 0...1 (0 when there is none).
    public let secondaryCoverage: Double

    /// Whether the item reads as multi-colored rather than solid.
    public var isPatterned: Bool { secondary != nil }
}

/// Finds an item's dominant colors from its pixels with k-means clustering in L*a*b* space.
///
/// Feed it a small, downsampled image (64×64 is plenty). Pass a foreground mask when one is
/// available (e.g. from Vision); otherwise the background is estimated from the image border.
public struct DominantColorExtractor: Sendable {
    /// Number of k-means clusters before merging similar ones.
    public var clusterCount = 5
    public var iterations = 12
    /// Clusters closer than this (CIEDE2000) are merged into one color.
    public var mergeThreshold = 10.0
    /// A secondary color must cover at least this share of the item...
    public var minimumSecondaryCoverage = 0.2
    /// ...and differ from the primary by at least this much (CIEDE2000).
    public var minimumSecondaryDistance = 15.0
    /// When estimating the background from the border, pixels this close to it are dropped.
    public var backgroundThreshold = 12.0
    public var seed: UInt64 = 0x5EED

    public init() {}

    /// - Parameters:
    ///   - pixels: Row-major pixels, `width * height` of them.
    ///   - mask: Optional row-major foreground mask; `true` marks item pixels.
    /// - Returns: `nil` when there are no usable item pixels.
    public func extract(pixels: [RGBColor], width: Int, height: Int, mask: [Bool]? = nil) -> DominantColors? {
        guard width > 0, height > 0, pixels.count == width * height else { return nil }
        if let mask, mask.count != pixels.count { return nil }

        let foreground: [RGBColor]
        if let mask {
            foreground = zip(pixels, mask).compactMap { $1 ? $0 : nil }
        } else {
            foreground = removeBorderBackground(pixels: pixels, width: width, height: height)
        }
        guard !foreground.isEmpty else { return nil }

        let labs = foreground.map(LabColor.init)
        var clusters = kMeans(labs)
        clusters = merge(clusters)
        clusters.sort { $0.members.count > $1.members.count }
        guard let first = clusters.first else { return nil }

        let total = Double(labs.count)
        let primary = representative(of: first, pixels: foreground, labs: labs)
        let primaryCoverage = Double(first.members.count) / total

        let secondaryCluster = clusters.dropFirst().first { cluster in
            Double(cluster.members.count) / total >= minimumSecondaryCoverage
                && cluster.centroid.deltaE2000(first.centroid) >= minimumSecondaryDistance
        }
        let secondary = secondaryCluster.map { representative(of: $0, pixels: foreground, labs: labs) }
        let secondaryCoverage = secondaryCluster.map { Double($0.members.count) / total } ?? 0

        return DominantColors(
            primary: primary,
            secondary: secondary,
            primaryCoverage: primaryCoverage,
            secondaryCoverage: secondaryCoverage
        )
    }

    // MARK: - Background

    /// Estimates the background from the outermost ring of pixels and drops everything close to it.
    /// Keeps all pixels when the border isn't uniform enough to be a backdrop.
    private func removeBorderBackground(pixels: [RGBColor], width: Int, height: Int) -> [RGBColor] {
        var border: [LabColor] = []
        for x in 0..<width {
            border.append(LabColor(pixels[x]))
            border.append(LabColor(pixels[(height - 1) * width + x]))
        }
        for y in 0..<height {
            border.append(LabColor(pixels[y * width]))
            border.append(LabColor(pixels[y * width + width - 1]))
        }
        let background = mean(border)
        let uniform = border.filter { $0.deltaE2000(background) <= backgroundThreshold }.count
        guard Double(uniform) / Double(border.count) >= 0.6 else { return pixels }

        let kept = pixels.filter { LabColor($0).deltaE2000(background) > backgroundThreshold }
        // A photo that is almost entirely "background" is probably a close-up of the item itself.
        return Double(kept.count) / Double(pixels.count) < 0.05 ? pixels : kept
    }

    // MARK: - Clustering

    private struct Cluster {
        var centroid: LabColor
        var members: [Int]
    }

    private func kMeans(_ labs: [LabColor]) -> [Cluster] {
        var rng = SeededGenerator(seed: seed)
        let k = min(clusterCount, labs.count)

        // k-means++ seeding.
        var centroids = [labs[Int.random(in: 0..<labs.count, using: &rng)]]
        while centroids.count < k {
            let distances = labs.map { lab in centroids.map { squaredDistance(lab, $0) }.min() ?? 0 }
            let total = distances.reduce(0, +)
            guard total > 0 else { break }
            var target = Double.random(in: 0..<total, using: &rng)
            var chosen = labs.count - 1
            for (index, distance) in distances.enumerated() {
                target -= distance
                if target < 0 {
                    chosen = index
                    break
                }
            }
            centroids.append(labs[chosen])
        }

        var assignment = [Int](repeating: 0, count: labs.count)
        for _ in 0..<iterations {
            var changed = false
            for (index, lab) in labs.enumerated() {
                var best = 0
                var bestDistance = Double.infinity
                for (c, centroid) in centroids.enumerated() {
                    let distance = squaredDistance(lab, centroid)
                    if distance < bestDistance {
                        bestDistance = distance
                        best = c
                    }
                }
                if assignment[index] != best {
                    assignment[index] = best
                    changed = true
                }
            }
            for c in centroids.indices {
                let members = labs.indices.filter { assignment[$0] == c }.map { labs[$0] }
                if !members.isEmpty { centroids[c] = mean(members) }
            }
            if !changed { break }
        }

        var clusters = centroids.map { Cluster(centroid: $0, members: []) }
        for (index, c) in assignment.enumerated() {
            clusters[c].members.append(index)
        }
        return clusters.filter { !$0.members.isEmpty }
    }

    /// Repeatedly merges the closest pair of clusters while they're within `mergeThreshold`.
    private func merge(_ input: [Cluster]) -> [Cluster] {
        var clusters = input
        while clusters.count > 1 {
            var closest: (Int, Int, Double)?
            for i in clusters.indices {
                for j in clusters.indices where j > i {
                    let distance = clusters[i].centroid.deltaE2000(clusters[j].centroid)
                    if distance < (closest?.2 ?? .infinity) { closest = (i, j, distance) }
                }
            }
            guard let (i, j, distance) = closest, distance <= mergeThreshold else { break }
            let a = clusters[i], b = clusters[j]
            let total = Double(a.members.count + b.members.count)
            let wa = Double(a.members.count) / total, wb = Double(b.members.count) / total
            let centroid = LabColor(
                l: a.centroid.l * wa + b.centroid.l * wb,
                a: a.centroid.a * wa + b.centroid.a * wb,
                b: a.centroid.b * wa + b.centroid.b * wb
            )
            clusters[i] = Cluster(centroid: centroid, members: a.members + b.members)
            clusters.remove(at: j)
        }
        return clusters
    }

    /// The real pixel closest to the cluster centroid, so the result is a color that actually
    /// appears in the photo rather than an average no pixel has.
    private func representative(of cluster: Cluster, pixels: [RGBColor], labs: [LabColor]) -> RGBColor {
        var best = cluster.members[0]
        var bestDistance = Double.infinity
        for index in cluster.members {
            let distance = squaredDistance(labs[index], cluster.centroid)
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return pixels[best]
    }

    private func squaredDistance(_ x: LabColor, _ y: LabColor) -> Double {
        let dl = x.l - y.l, da = x.a - y.a, db = x.b - y.b
        return dl * dl + da * da + db * db
    }

    private func mean(_ labs: [LabColor]) -> LabColor {
        let count = Double(labs.count)
        var l = 0.0, a = 0.0, b = 0.0
        for lab in labs {
            l += lab.l
            a += lab.a
            b += lab.b
        }
        return LabColor(l: l / count, a: a / count, b: b / count)
    }
}
