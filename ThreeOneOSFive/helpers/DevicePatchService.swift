import Foundation

enum DevicePatchService {
    static func apply(project: PatchProject) throws -> PatchTransactionReceipt {
        let bundleIDs = orderedBundleIdentifiers(in: project)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            let effectiveProject = projectUsingInstalledAssetIndexerPathIfNeeded(
                project,
                roots: roots
            )
            return try PatchTransaction.apply(
                project: effectiveProject,
                backupRoot: try PatchProjectLibrary.backupRootURL(),
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func inspectRestore(receipt: PatchTransactionReceipt) throws -> PatchRestoreInspection {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.inspectRestore(
                receipt: receipt,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func restore(
        receipt: PatchTransactionReceipt,
        allowChangedTargets: Bool = false
    ) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.restore(
                receipt: receipt,
                allowChangedTargets: allowChangedTargets,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func resetToAppliedState(
        receipt: PatchTransactionReceipt,
        project: PatchProject
    ) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.resetToAppliedState(
                receipt: receipt,
                fallbackProject: project,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func latestReceipt(projectID: UUID) -> PatchTransactionReceipt? {
        guard let backupRoot = try? PatchProjectLibrary.backupRootURL() else { return nil }
        return PatchTransaction.latestReceipt(projectID: projectID, backupRoot: backupRoot)
    }

    private static func orderedBundleIdentifiers(in project: PatchProject) -> [String] {
        project.allBundleIdentifiers
    }

    private static let assetIndexerDirectory =
        "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar"
    private static let currentAssetIndexerFilename =
        "assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D"
    private static let legacyAssetIndexerFilename =
        "assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D"

    private static func projectUsingInstalledAssetIndexerPathIfNeeded(
        _ project: PatchProject,
        roots: [String: URL],
        fileManager: FileManager = .default
    ) -> PatchProject {
        var adjusted = project

        for index in adjusted.rules.indices {
            let rule = adjusted.rules[index]
            let currentPath = assetIndexerDirectory + "/" + currentAssetIndexerFilename
            guard rule.relativePath == currentPath,
                  let root = roots[rule.bundleID] else {
                continue
            }

            let currentURL = root.appendingPathComponent(currentPath, isDirectory: false)
            guard !fileManager.fileExists(atPath: currentURL.path) else {
                continue
            }

            let legacyPath = assetIndexerDirectory + "/" + legacyAssetIndexerFilename
            let legacyURL = root.appendingPathComponent(legacyPath, isDirectory: false)
            guard fileManager.fileExists(atPath: legacyURL.path) else {
                continue
            }

            adjusted.rules[index].relativePath = legacyPath
            log(
                "patch: U6 asset indexer missing; using installed legacy target " +
                "\(legacyPath) for \(rule.bundleID)"
            )
        }

        return adjusted
    }

    private static func withResolvedContainers<T>(
        bundleIDs: [String],
        operation: ([String: URL]) throws -> T
    ) throws -> T {
        var roots: [String: URL] = [:]

        for bundleID in bundleIDs {
            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
                  ContainerStore.isApplicationContainerPath(path) else {
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try operation(roots)
    }
}
