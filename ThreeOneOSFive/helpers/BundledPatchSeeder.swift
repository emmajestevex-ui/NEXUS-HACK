import Foundation

enum BundledPatchSeeder {
    enum TargetBundleChoice: String, CaseIterable, Identifiable {
        case freeFireMax
        case freeFireTH

        var id: String { rawValue }

        var label: String {
            switch self {
            case .freeFireMax: return "Free Fire Max"
            case .freeFireTH: return "Free Fire TH"
            }
        }

        var bundleID: String {
            switch self {
            case .freeFireMax: return "com.dts.freefiremax"
            case .freeFireTH: return "com.dts.freefireth"
            }
        }

        init?(bundleID: String) {
            switch BundledPatchSeeder.normalizedBundleID(bundleID) {
            case "com.dts.freefiremax": self = .freeFireMax
            case "com.dts.freefireth": self = .freeFireTH
            default: return nil
            }
        }
    }

    enum AssetIndexerVariant: String, CaseIterable, Identifiable {
        case pen
        case h5

        var id: String { rawValue }

        var label: String {
            switch self {
            case .pen: return "PEN"
            case .h5: return "H5"
            }
        }

        var bundleID: String {
            switch self {
            case .pen: return "com.dts.freefiremax"
            case .h5: return "com.dts.freefireth"
            }
        }

        var filename: String {
            switch self {
            case .pen: return "assetindexer.PENojQAQ-f9a1I6Dzjs0n1Z3rtVU~3D"
            case .h5: return "assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D"
            }
        }
    }

    private struct ProjectSpec {
        let id: UUID
        let defaultName: String
        let legacyDefaultNames: Set<String>
        let requiredCapability: String?
        let bundleID: String
        let payloads: [PayloadSpec]

        init(
            id: UUID,
            defaultName: String,
            legacyDefaultNames: Set<String>,
            requiredCapability: String? = nil,
            bundleID: String = "com.dts.freefireth",
            payloads: [PayloadSpec]
        ) {
            self.id = id
            self.defaultName = defaultName
            self.legacyDefaultNames = legacyDefaultNames
            self.requiredCapability = requiredCapability
            self.bundleID = bundleID
            self.payloads = payloads
        }
    }

    private struct PayloadSpec {
        let directory: String
        let filenameCandidates: [String]
        let targetFilename: String?
        let remoteSlugs: Set<String>

        init(
            directory: String,
            filenameCandidates: [String],
            targetFilename: String? = nil,
            remoteSlugs: Set<String> = []
        ) {
            self.directory = directory
            self.filenameCandidates = filenameCandidates
            self.targetFilename = targetFilename
            self.remoteSlugs = remoteSlugs
        }
    }

    private struct BundledPackageSpec {
        let id: UUID
        let resourceName: String
        let resourceExtension: String
        let sortRank: Int
    }

    private enum SeedError: Error {
        case missingPayload(String)
        case emptyPayload(String)
    }

    private static let payloadDirectoryName = "BundledPatchPayloads"
    private static let seedDate = Date(timeIntervalSince1970: 0)
    private static let assetIndexerProjectID = UUID(uuidString: "A55E0001-3105-4A55-9001-00000000BEEF")!
    private static let assetIndexerVariantKey = "greeg.assetIndexerVariant"
    private static let remoteAssetIndexerVariantPrefix = "greeg.remoteAssetIndexerVariant."
    private static let remoteTargetBundlePrefix = "greeg.remoteTargetBundle."
    private static let assetIndexerDirectory = "Documents/contentcache/Compulsory/ios/gameassetbundles/avatar"
    private static let bundledPackages: [BundledPackageSpec] = []

    private static let projects: [ProjectSpec] = []
    private static let retiredBundledProjectIDs: Set<UUID> = [
        UUID(uuidString: "A55E0001-3105-4A55-9001-00000000BEEF")!,
        UUID(uuidString: "A55E0002-0144-4A55-9001-00000000BEEF")!,
        UUID(uuidString: "A55E0003-3105-4A55-9001-00000000BEEF")!,
        UUID(uuidString: "A55E0004-3105-4A55-9001-00000000BEEF")!,
        UUID(uuidString: "A55E0005-3105-4A55-9001-00000000BEEF")!,
    ]

    private static var activeProjects: [ProjectSpec] {
        projects.filter { spec in
            if spec.payloads.contains(where: {
                RemoteContentLibrary.isBuiltInDisabled(
                    bundleID: effectiveBundleID(for: spec),
                    relativePath: targetPath(for: $0),
                    slugs: $0.remoteSlugs
                )
            }) {
                return false
            }
            guard let capability = spec.requiredCapability else { return true }
            return LicenseEntitlements.has(capability)
        }
    }

    static var projectIDs: Set<UUID> {
        Set(activeProjects.map { $0.id })
            .union(bundledPackages.map(\.id))
            .union(remoteProjectIDs())
    }

    static func sortRank(for id: UUID) -> Int {
        if let index = projects.firstIndex(where: { $0.id == id }) {
            return index * 10
        }
        if let package = bundledPackages.first(where: { $0.id == id }) {
            return package.sortRank
        }
        if let index = sortedRemoteProjectIDs().firstIndex(of: id) {
            return (projects.count * 10) + index
        }
        return Int.max
    }

    static var selectedAssetIndexerVariant: AssetIndexerVariant {
        let raw = UserDefaults.standard.string(forKey: assetIndexerVariantKey) ?? AssetIndexerVariant.pen.rawValue
        return AssetIndexerVariant(rawValue: raw) ?? .pen
    }

    static func setAssetIndexerVariant(_ variant: AssetIndexerVariant, fileManager: FileManager = .default) {
        UserDefaults.standard.set(variant.rawValue, forKey: assetIndexerVariantKey)
        seedIfNeeded(fileManager: fileManager)
    }

    static func setAssetIndexerVariant(
        _ variant: AssetIndexerVariant,
        for projectID: UUID,
        fileManager: FileManager = .default
    ) {
        if projectID == assetIndexerProjectID {
            setAssetIndexerVariant(variant, fileManager: fileManager)
        } else {
            UserDefaults.standard.set(variant.rawValue, forKey: remoteAssetIndexerVariantKey(for: projectID))
            UserDefaults.standard.set(variant.bundleID, forKey: remoteTargetBundleKey(for: projectID))
            seedIfNeeded(fileManager: fileManager)
        }
    }

    static func isAssetIndexerProject(_ project: PatchProject) -> Bool {
        project.id == assetIndexerProjectID
    }

    static func hasAssetIndexerRule(_ project: PatchProject) -> Bool {
        project.id == assetIndexerProjectID || project.rules.contains { isAssetIndexerPath($0.relativePath) }
    }

    static func selectedAssetIndexerVariant(for project: PatchProject) -> AssetIndexerVariant {
        if project.id == assetIndexerProjectID {
            return selectedAssetIndexerVariant
        }
        if let override = remoteAssetIndexerVariantOverride(for: project.id) {
            return override
        }
        if let bundleID = project.rules.first?.bundleID,
           normalizedBundleID(bundleID) == AssetIndexerVariant.pen.bundleID {
            return .pen
        }
        if let bundleID = project.rules.first?.bundleID,
           normalizedBundleID(bundleID) == AssetIndexerVariant.h5.bundleID {
            return .h5
        }
        if project.rules.contains(where: { $0.relativePath.localizedCaseInsensitiveContains(AssetIndexerVariant.pen.filename) }) {
            return .pen
        }
        return .h5
    }

    static func canOverrideTargetBundle(_ project: PatchProject) -> Bool {
        !hasAssetIndexerRule(project) && !project.rules.isEmpty
    }

    static func selectedTargetBundle(for project: PatchProject) -> TargetBundleChoice {
        targetBundleOverride(for: project.id)
            ?? TargetBundleChoice(bundleID: project.allBundleIdentifiers.first ?? "")
            ?? .freeFireTH
    }

    static func setTargetBundle(
        _ choice: TargetBundleChoice,
        for projectID: UUID,
        fileManager: FileManager = .default
    ) {
        UserDefaults.standard.set(choice.bundleID, forKey: remoteTargetBundleKey(for: projectID))
        seedIfNeeded(fileManager: fileManager)
    }

    static func isBuiltInRemoteFile(_ file: RemoteContentFile) -> Bool {
        let requestedBundle = normalizedBundleID(file.targetBundleID)
        let requestedSlug = normalizedSlug(file.slug)
        return projects
            .contains { spec in
                spec.payloads.contains { payload in
                    let slugMatches = payload.remoteSlugs.contains {
                        remoteSlugMatches(requestedSlug, expected: $0)
                    }
                    return slugMatches && normalizedBundleID(spec.bundleID) == requestedBundle
                }
            }
    }

    static func seedIfNeeded(fileManager: FileManager = .default) {
        seedBundledPackages(fileManager: fileManager)
        removeRetiredBundledProjects(fileManager: fileManager)
        removeBuiltInRemoteDuplicates(fileManager: fileManager)

        for spec in activeProjects {
            do {
                try seed(spec, fileManager: fileManager)
                log("patch: bundled GREEG patch \(spec.defaultName) is ready")
            } catch SeedError.missingPayload(let filename) {
                log("patch: bundled payload missing for \(spec.defaultName): \(filename)")
            } catch SeedError.emptyPayload(let filename) {
                log("patch: bundled payload is empty for \(spec.defaultName): \(filename)")
            } catch {
                log("patch: bundled patch \(spec.defaultName) could not be prepared: \(error.localizedDescription)")
            }
        }
        seedRemoteProjects(fileManager: fileManager)
    }

    private static func removeRetiredBundledProjects(fileManager: FileManager) {
        for item in PatchProjectLibrary.load(fileManager: fileManager)
            where retiredBundledProjectIDs.contains(item.id) {
            do {
                try PatchProjectLibrary.deleteRetiredBundledPackage(item, fileManager: fileManager)
                log("patch: retired bundled project removed \(item.id.uuidString)")
            } catch {
                log("patch: retired bundled project \(item.id.uuidString) could not be removed: \(error.localizedDescription)")
            }
        }
    }

    private static func seedBundledPackages(fileManager: FileManager) {
        for spec in bundledPackages {
            do {
                try seedBundledPackage(spec, fileManager: fileManager)
                log("patch: bundled package \(spec.resourceName) is ready")
            } catch {
                log("patch: bundled package \(spec.resourceName) could not be prepared: \(error.localizedDescription)")
            }
        }
    }

    private static func seedBundledPackage(_ spec: BundledPackageSpec, fileManager: FileManager) throws {
        guard let packageURL = Bundle.main.url(
            forResource: spec.resourceName,
            withExtension: spec.resourceExtension,
            subdirectory: payloadDirectoryName
        ) else {
            throw SeedError.missingPayload("\(spec.resourceName).\(spec.resourceExtension)")
        }

        let data = try PatchProjectLibrary.readPackage(at: packageURL)
        let summary = try PatchPackageCodec.inspect(data)
        let decoded = try PatchPackageCodec.decode(data, password: nil)
        let existingURL = PatchProjectLibrary.load(fileManager: fileManager)
            .first { $0.id == summary.packageID }?
            .packageURL

        try PatchProjectLibrary.installImportedPackage(
            data: data,
            decoded: decoded,
            summary: summary,
            existingURL: existingURL,
            fileManager: fileManager
        )
    }

    private static func removeBuiltInRemoteDuplicates(fileManager: FileManager) {
        guard let manifest = RemoteContentLibrary.loadManifest(fileManager: fileManager) else { return }
        let groupedRemoteIDs = Set(manifest.files.compactMap { file -> UUID? in
            guard file.isAvailable, isBuiltInRemoteFile(file) else { return nil }
            return remoteProjectID(for: file)
        })
        guard !groupedRemoteIDs.isEmpty else { return }

        for item in PatchProjectLibrary.load(fileManager: fileManager)
            where groupedRemoteIDs.contains(item.id) {
            do {
                try PatchProjectLibrary.delete(item, fileManager: fileManager)
                log("patch: removed duplicate remote file patch \(item.id.uuidString)")
            } catch {
                log("patch: duplicate remote file patch \(item.id.uuidString) could not be removed: \(error.localizedDescription)")
            }
        }
    }

    private static func seed(_ spec: ProjectSpec, fileManager: FileManager) throws {
        let existingItem = PatchProjectLibrary.load(fileManager: fileManager)
            .first { $0.id == spec.id }
        let project = try makeProject(
            spec,
            existingProject: existingItem?.project,
            fileManager: fileManager
        )

        if let existingItem {
            try refreshExistingPackage(existingItem, with: project, fileManager: fileManager)
        } else {
            let encoded = try PatchPackageCodec.encodeLegacyV1(project: project, password: nil)
            _ = try PatchProjectLibrary.save(
                data: encoded.data,
                projectName: project.name,
                fileManager: fileManager
            )
        }

        try? PatchWorkspaceService.deleteWorkspace(projectID: spec.id, fileManager: fileManager)
    }

    private static func makeProject(
        _ spec: ProjectSpec,
        existingProject: PatchProject?,
        fileManager: FileManager
    ) throws -> PatchProject {
        let baseBundleID = effectiveBundleID(for: spec)
        let remoteOverride = spec.payloads.compactMap {
            RemoteContentLibrary.installedFile(
                matching: targetPath(for: $0),
                slugs: $0.remoteSlugs,
                bundleID: baseBundleID,
                fileManager: fileManager
            )?.file
        }.first
        let effectiveBundleID = remoteOverride?.targetBundleID ?? baseBundleID
        let rules = try spec.payloads.map { payload in
            try makeRule(payload, fallbackBundleID: effectiveBundleID, fileManager: fileManager)
        }
        let existingName = existingProject?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name: String
        if spec.payloads.count == 1,
           let remoteName = remoteOverride?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !remoteName.isEmpty {
            name = remoteName
        } else if existingName.isEmpty || spec.legacyDefaultNames.contains(existingName) {
            name = spec.defaultName
        } else {
            name = existingName
        }

        return PatchProject(
            id: spec.id,
            name: name,
            createdAt: existingProject?.createdAt ?? seedDate,
            updatedAt: remoteOverride == nil ? (existingProject?.updatedAt ?? seedDate) : Date(),
            bundleIdentifiers: [effectiveBundleID],
            directories: [],
            rules: rules
        )
    }

    private static func makeRule(_ spec: PayloadSpec, fallbackBundleID: String, fileManager: FileManager) throws -> PatchRule {
        let bundledPayloadURL = try payloadURL(for: spec, fileManager: fileManager)
        let targetPath = targetPath(for: spec)

        let remoteMatch = RemoteContentLibrary.installedFile(
            matching: targetPath,
            slugs: spec.remoteSlugs,
            bundleID: fallbackBundleID,
            fileManager: fileManager
        )
        let payloadURL = remoteMatch?.url ?? bundledPayloadURL
        let data = try Data(contentsOf: payloadURL, options: .mappedIfSafe)
        guard !data.isEmpty else { throw SeedError.emptyPayload(payloadURL.lastPathComponent) }
        let replacementFilename = remoteMatch.map { "Remote v\($0.file.version) - \($0.file.fileName)" }
            ?? payloadURL.lastPathComponent
        let effectiveBundleID = remoteMatch?.file.targetBundleID ?? fallbackBundleID

        return PatchRule(
            bundleID: effectiveBundleID,
            relativePath: targetPath,
            replacementFilename: replacementFilename,
            replacementData: data
        )
    }

    private static func payloadURL(for spec: PayloadSpec, fileManager: FileManager) throws -> URL {
        guard let payloadRoot = Bundle.main.url(
            forResource: payloadDirectoryName,
            withExtension: nil
        ) else {
            throw SeedError.missingPayload(spec.filenameCandidates[0])
        }

        let candidates: [String]
        if spec.directory == assetIndexerDirectory,
           spec.filenameCandidates.contains(AssetIndexerVariant.pen.filename) {
            candidates = [selectedAssetIndexerVariant.filename]
                + spec.filenameCandidates.filter { $0 != selectedAssetIndexerVariant.filename }
        } else {
            candidates = spec.filenameCandidates
        }

        for filename in candidates {
            let candidate = payloadRoot.appendingPathComponent(filename, isDirectory: false)
            if fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        throw SeedError.missingPayload(spec.filenameCandidates[0])
    }

    private static func refreshExistingPackage(
        _ item: PatchLibraryItem,
        with project: PatchProject,
        fileManager: FileManager
    ) throws {
        guard let contentKey = item.contentKey else {
            try PatchProjectLibrary.delete(item, fileManager: fileManager)
            let encoded = try PatchPackageCodec.encodeLegacyV1(project: project, password: nil)
            _ = try PatchProjectLibrary.save(
                data: encoded.data,
                projectName: project.name,
                fileManager: fileManager
            )
            return
        }

        if item.project == project { return }

        let original = try PatchProjectLibrary.readPackage(at: item.packageURL)
        let updated = try PatchPackageCodec.update(
            original,
            project: project,
            contentKey: contentKey,
            schemaVersion: 1
        )
        _ = try PatchProjectLibrary.save(
            data: updated,
            projectName: project.name,
            existingURL: item.packageURL,
            fileManager: fileManager
        )
    }

    private static func seedRemoteProjects(fileManager: FileManager) {
        guard RemoteContentLibrary.loadManifest(fileManager: fileManager) != nil else {
            log("patch: remote records finally shown=0")
            return
        }

        let remoteFiles = standaloneRemotePatchFiles(fileManager: fileManager)
        removeObsoleteRemoteProjects(activeRemoteFiles: remoteFiles, fileManager: fileManager)

        guard !remoteFiles.isEmpty else {
            log("patch: remote records finally shown=0")
            return
        }
        let existingItems = PatchProjectLibrary.load(fileManager: fileManager)
        var preparedCount = 0

        for file in remoteFiles {
            guard let projectID = remoteProjectID(for: file),
                  let payloadURL = RemoteContentLibrary.localFileURL(for: file, fileManager: fileManager) else {
                log("patch: remote discarded \(file.name) reason=missing-project-id-or-local-payload")
                continue
            }

            do {
                if isRemotePatchPackage(file) {
                    try installRemotePatchPackage(
                        from: payloadURL,
                        existingItems: existingItems,
                        fileManager: fileManager
                    )
                    log("patch: remote package \(file.name) is ready")
                    preparedCount += 1
                    continue
                }

                let existingItem = existingItems.first { $0.id == projectID }
                let project = try makeRemoteProject(
                    from: file,
                    projectID: projectID,
                    payloadURL: payloadURL,
                    existingProject: existingItem?.project
                )
                if let existingItem {
                    try refreshExistingPackage(existingItem, with: project, fileManager: fileManager)
                } else {
                    let encoded = try PatchPackageCodec.encodeLegacyV1(project: project, password: nil)
                    _ = try PatchProjectLibrary.save(
                        data: encoded.data,
                        projectName: project.name,
                        fileManager: fileManager
                    )
                }
                try? PatchWorkspaceService.deleteWorkspace(projectID: projectID, fileManager: fileManager)
                log("patch: remote patch \(project.name) is ready")
                preparedCount += 1
            } catch {
                log("patch: remote patch \(file.name) could not be prepared: \(error.localizedDescription)")
            }
        }
        log("patch: remote records finally shown=\(preparedCount)")
    }

    private static func removeObsoleteRemoteProjects(
        activeRemoteFiles: [RemoteContentFile],
        fileManager: FileManager
    ) {
        let activeRemoteIDs = Set(activeRemoteFiles.compactMap(remoteProjectID))
        let activeBuiltInIDs = Set(activeProjects.map(\.id)).union(bundledPackages.map(\.id))

        for item in PatchProjectLibrary.load(fileManager: fileManager) {
            guard let project = item.project,
                  isRemoteManagedProject(project),
                  !activeRemoteIDs.contains(item.id),
                  !activeBuiltInIDs.contains(item.id) else {
                continue
            }

            do {
                try PatchProjectLibrary.delete(item, fileManager: fileManager)
                log("patch: removed obsolete remote patch \(project.name)")
            } catch {
                log("patch: obsolete remote patch \(project.name) could not be removed: \(error.localizedDescription)")
            }
        }
    }

    private static func installRemotePatchPackage(
        from url: URL,
        existingItems: [PatchLibraryItem],
        fileManager: FileManager
    ) throws {
        let data = try PatchProjectLibrary.readPackage(at: url)
        let summary = try PatchPackageCodec.inspect(data)
        let decoded = try PatchPackageCodec.decode(data, password: nil)
        let existingURL = existingItems.first { $0.id == summary.packageID }?.packageURL

        try PatchProjectLibrary.installImportedPackage(
            data: data,
            decoded: decoded,
            summary: summary,
            existingURL: existingURL,
            fileManager: fileManager
        )
    }

    private static func makeRemoteProject(
        from file: RemoteContentFile,
        projectID: UUID,
        payloadURL: URL,
        existingProject: PatchProject?
    ) throws -> PatchProject {
        let data = try Data(contentsOf: payloadURL, options: .mappedIfSafe)
        guard !data.isEmpty else { throw SeedError.emptyPayload(payloadURL.lastPathComponent) }
        let remoteName = file.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectName = remoteName.isEmpty ? file.fileName : remoteName
        let assetVariant = effectiveRemoteAssetVariant(for: file, projectID: projectID)
        let effectiveBundleID = assetVariant?.bundleID
            ?? targetBundleOverride(for: projectID)?.bundleID
            ?? file.targetBundleID
        let effectivePath = assetVariant.map {
            assetIndexerDirectory + "/" + $0.filename
        } ?? file.localRelativePath

        return PatchProject(
            id: projectID,
            name: projectName,
            author: remoteStyleMarker(for: file),
            createdAt: existingProject?.createdAt ?? seedDate,
            updatedAt: Date(),
            bundleIdentifiers: [effectiveBundleID],
            directories: [],
            rules: [
                PatchRule(
                    bundleID: effectiveBundleID,
                    relativePath: effectivePath,
                    replacementFilename: "Remote v\(file.version) - \(file.fileName)",
                    replacementData: data
                )
            ]
        )
    }

    private static func remoteProjectIDs(fileManager: FileManager = .default) -> Set<UUID> {
        Set(standaloneRemotePatchFiles(fileManager: fileManager).compactMap(remoteProjectID))
    }

    private static func sortedRemoteProjectIDs(fileManager: FileManager = .default) -> [UUID] {
        standaloneRemotePatchFiles(fileManager: fileManager)
            .sorted {
                let leftPriority = remoteDisplayPriority(for: $0.name)
                let rightPriority = remoteDisplayPriority(for: $1.name)
                if leftPriority != rightPriority { return leftPriority < rightPriority }
                let leftPublishedAt = $0.publishedAt ?? ""
                let rightPublishedAt = $1.publishedAt ?? ""
                if leftPublishedAt != rightPublishedAt { return leftPublishedAt < rightPublishedAt }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .compactMap(remoteProjectID)
    }

    private static func standaloneRemotePatchFiles(fileManager: FileManager) -> [RemoteContentFile] {
        guard let manifest = RemoteContentLibrary.loadManifest(fileManager: fileManager) else {
            log("registros recibidos de Supabase: 0; motivo del descarte: no-local-manifest")
            return []
        }

        var visibleFiles: [RemoteContentFile] = []
        for file in manifest.files {
            if !file.isAvailable {
                log("registros descartados: \(file.name); motivo del descarte: inactive-or-deleted")
                continue
            }
            if isBuiltInRemoteFile(file) {
                log("registros descartados: \(file.name); motivo del descarte: built-in-route")
                continue
            }
            if RemoteContentLibrary.localFileURL(for: file, fileManager: fileManager) == nil {
                log("registros descartados: \(file.name); motivo del descarte: missing-local-payload")
                continue
            }
            visibleFiles.append(file)
        }

        log("registros recibidos de Supabase: \(manifest.files.count)")
        log("registros finalmente mostrados: \(visibleFiles.count)")
        return visibleFiles
    }

    private static func remoteProjectID(for file: RemoteContentFile) -> UUID? {
        UUID(uuidString: file.id)
    }

    private static func remoteStyleMarker(for file: RemoteContentFile) -> String {
        let category = "[GREEG_CATEGORY:\(file.category.lowercased())]"
        let lowercased = (file.description ?? "").lowercased()
        if lowercased.contains("[greeg_style:antena]") {
            return "[GREEG_STYLE:antena] \(category)"
        }
        if lowercased.contains("[greeg_style:holo]") {
            return "[GREEG_STYLE:holo] \(category)"
        }
        if lowercased.contains("[greeg_style:aimbot-normal]") {
            return "[GREEG_STYLE:aimbot-normal] \(category)"
        }
        return category
    }

    static func isRemoteManagedProject(_ project: PatchProject) -> Bool {
        let author = project.author.lowercased()
        return author.contains("[greeg_category:")
            || author.contains("[greeg_style:")
    }

    private static func isRemotePatchPackage(_ file: RemoteContentFile) -> Bool {
        file.category.lowercased() == "packages"
            || file.fileName.lowercased().hasSuffix(".3105")
            || file.mimeType?.lowercased() == "application/vnd.greeg.3105"
    }

    private static func targetPath(for spec: PayloadSpec) -> String {
        if spec.directory == assetIndexerDirectory,
           spec.filenameCandidates.contains(AssetIndexerVariant.pen.filename) {
            return spec.directory + "/" + selectedAssetIndexerVariant.filename
        }
        return spec.directory + "/" + (spec.targetFilename ?? spec.filenameCandidates[0])
    }

    private static func effectiveBundleID(for spec: ProjectSpec) -> String {
        return spec.id == assetIndexerProjectID ? selectedAssetIndexerVariant.bundleID : spec.bundleID
    }

    private static func effectiveRemoteAssetVariant(
        for file: RemoteContentFile,
        projectID: UUID
    ) -> AssetIndexerVariant? {
        guard isAssetIndexerPath(file.localRelativePath) else { return nil }
        if let override = remoteAssetIndexerVariantOverride(for: projectID) {
            return override
        }
        if normalizedBundleID(file.targetBundleID) == AssetIndexerVariant.pen.bundleID {
            return .pen
        }
        if normalizedBundleID(file.targetBundleID) == AssetIndexerVariant.h5.bundleID {
            return .h5
        }
        if file.localRelativePath.localizedCaseInsensitiveContains(AssetIndexerVariant.pen.filename) {
            return .pen
        }
        return .h5
    }

    private static func targetBundleOverride(for projectID: UUID) -> TargetBundleChoice? {
        guard let raw = UserDefaults.standard.string(forKey: remoteTargetBundleKey(for: projectID)) else {
            return nil
        }
        return TargetBundleChoice(bundleID: raw)
    }

    private static func remoteAssetIndexerVariantOverride(for projectID: UUID) -> AssetIndexerVariant? {
        guard let raw = UserDefaults.standard.string(forKey: remoteAssetIndexerVariantKey(for: projectID)) else {
            return nil
        }
        return AssetIndexerVariant(rawValue: raw)
    }

    private static func remoteTargetBundleKey(for projectID: UUID) -> String {
        remoteTargetBundlePrefix + projectID.uuidString
    }

    private static func remoteAssetIndexerVariantKey(for projectID: UUID) -> String {
        remoteAssetIndexerVariantPrefix + projectID.uuidString
    }

    private static func isAssetIndexerPath(_ value: String) -> Bool {
        value.localizedCaseInsensitiveContains("/assetindexer.")
            || value.localizedCaseInsensitiveContains("assetindexer.")
    }

    private static func normalizedBundleID(_ value: String?) -> String {
        let clean = (value ?? "com.dts.freefireth").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return clean.isEmpty ? "com.dts.freefireth" : clean
    }

    private static func normalizedSlug(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func remoteDisplayPriority(for name: String) -> Int {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("aimbot drag") { return 10 }
        if normalized.contains("aimbot cuello") { return 20 }
        return 100
    }

    private static func remoteSlugMatches(_ actual: String, expected: String) -> Bool {
        let actual = normalizedSlug(actual)
        let expected = normalizedSlug(expected)
        return actual == expected || actual.hasPrefix(expected + "-")
    }
}
