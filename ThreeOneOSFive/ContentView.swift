import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation = AppTabNavigationState()

    var body: some View {
        TabView(selection: tabSelection) {
            GreegHomeView {
                withAnimation(.easeInOut(duration: 0.18)) {
                    tabNavigation.select(AppSection.archivos.rawValue)
                }
            }
            .tabItem { CompactTabLabel(title: "Inicio", systemImage: "house.fill") }
            .tag(AppSection.home.rawValue)

            GreegPatchLibraryView()
                .tabItem { CompactTabLabel(title: "Archivos", systemImage: "shippingbox.fill") }
                .tag(AppSection.archivos.rawValue)

            GreegInstallationView()
                .tabItem { CompactTabLabel(title: "Instalación", systemImage: "wrench.and.screwdriver.fill") }
                .tag(AppSection.instalacion.rawValue)

            GreegSocialView()
                .tabItem { CompactTabLabel(title: "Redes", systemImage: "link.circle.fill") }
                .tag(AppSection.redes.rawValue)
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.archivos.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.archivos.rawValue) }
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private struct GreegHomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var remoteContentStore: RemoteContentStore
    @EnvironmentObject private var store: PatchProjectStore
    @State private var showsSettings = false
    let onOpenFiles: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    heroCard
                    sectionTitle("ARCHIVOS PRINCIPALES")
                    mainFilesCard
                    sectionTitle("ACTUALIZACIONES")
                    updatesCard
                    sectionTitle("REDES")
                    compactSocialCard
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.headline.weight(.black))
                    }
                    .accessibilityLabel("Configuración")
                }
            }
            .sheet(isPresented: $showsSettings) {
                GreegSettingsSheetView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                remoteContentStore.loadLocalState()
                store.reload()
            }
            .onChange(of: remoteContentStore.remoteVersion) { _ in
                store.reload()
            }
        }
    }

    private var heroCard: some View {
        GreegPanel {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 12) {
                    AppLogo(size: 48)
                        .shadow(color: AppTheme.accent.opacity(0.28), radius: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("GREEG APP")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                        Text("Control privado")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Label(appState.isSupported ? "Listo" : "Revisar", systemImage: appState.isSupported ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.caption.weight(.black))
                        .foregroundColor(appState.isSupported ? .green : AppTheme.accent)
                        .labelStyle(.titleAndIcon)
                }

                Divider().overlay(Color.white.opacity(0.08))

                HStack(spacing: 0) {
                    HomeMetric(value: "AIM", title: "Archivos")
                    HomeMetric(value: "FF", title: "Destino")
                    HomeMetric(value: appState.isSupported ? "OK" : "WAIT", title: "Estado")
                }
            }
        }
    }

    private var mainFilesCard: some View {
        GreegPanel {
            VStack(spacing: 9) {
                Button(action: onOpenFiles) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.headline.weight(.black))
                        Text("Abrir archivos")
                            .font(.subheadline.weight(.black))
                        Spacer()
                    }
                    .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.white.opacity(0.08))

                if homePreviewProjects.isEmpty {
                    HomePatchRow(icon: "shippingbox.fill", title: "Sin archivos", subtitle: "Sincroniza para cargar", tint: AppTheme.accent)
                } else {
                    ForEach(homePreviewProjects.prefix(3), id: \.id) { project in
                        let kind = GreegPatchKind(project: project)
                        HomePatchRow(
                            icon: kind.iconName,
                            title: project.name,
                            subtitle: "Listo",
                            tint: kind.tint
                        )
                    }
                }
            }
        }
    }

    private var homePreviewProjects: [PatchProject] {
        store.items
            .compactMap(\.project)
            .filter(GreegPatchLibraryView.shouldShow)
            .sorted { left, right in
                let leftKind = GreegPatchKind(project: left)
                let rightKind = GreegPatchKind(project: right)
                if leftKind.rank != rightKind.rank { return leftKind.rank < rightKind.rank }
                return left.name.localizedStandardCompare(right.name) == .orderedAscending
            }
    }

    private var updatesCard: some View {
        GreegPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    AppRowIcon(
                        systemName: remoteContentStore.isBusy ? "arrow.triangle.2.circlepath" : "icloud.fill",
                        tint: Color(red: 0.27, green: 0.71, blue: 1),
                        symbolSize: 16,
                        frameSize: 38
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(remoteContentStore.installedFiles.isEmpty ? "Sincronizar" : "Actualizado")
                            .font(.headline.weight(.black))
                        Text(remoteContentStore.detailText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("v\(remoteContentStore.remoteVersion)")
                            .font(.headline.weight(.black))
                            .foregroundColor(AppTheme.accent)
                        Text("\(remoteContentStore.installedFiles.count) files")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    BundledPatchSeeder.seedIfNeeded()
                    remoteContentStore.syncIfPossible(force: true)
                } label: {
                    Label(remoteContentStore.isBusy ? "Sincronizando" : "Sincronizar", systemImage: "arrow.clockwise.circle.fill")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .disabled(remoteContentStore.isBusy)

                if let progress = remoteContentStore.progress, remoteContentStore.isBusy {
                    ProgressView(value: progress)
                        .tint(AppTheme.accent)
                }
            }
        }
    }

    private var compactSocialCard: some View {
        GreegPanel {
            Link(destination: GreegSocialLink.tiktok.url) {
                SocialRow(link: .tiktok)
            }
        }
    }

    private func sectionTitle(_ value: String) -> some View {
        Text(value)
            .font(.caption.weight(.black))
            .foregroundStyle(.secondary)
            .tracking(1.2)
            .padding(.leading, 4)
    }
}

private struct GreegPatchLibraryView: View {
    @EnvironmentObject private var store: PatchProjectStore

    private static let featuredDisplayOrder = [
        "Pecho + ANTENA",
        "Drag + ANTENA",
        "Magic + ANTENA",
        "Cuello + ANTENA",
        "HOLO RGB",
        "HOLO FF NORMAL PJ",
        "Balas Magicas FF NORMAL",
        "Aimbot Cuello FF Normal",
        "Aimbot Pecho FF Normal"
    ]

    private static let normalizedFeaturedDisplayOrder: [String] = featuredDisplayOrder.map(normalize)
    private var visibleItems: [PatchLibraryItem] {
        store.items
            .filter { item in
                guard let project = item.project else { return false }
                return Self.shouldShow(project)
            }
            .sorted { left, right in
                let leftKind = GreegPatchKind(project: left.project)
                let rightKind = GreegPatchKind(project: right.project)
                if leftKind.rank != rightKind.rank { return leftKind.rank < rightKind.rank }
                let leftIndex = Self.rank(for: left.project?.name)
                let rightIndex = Self.rank(for: right.project?.name)
                if leftIndex != rightIndex { return leftIndex < rightIndex }
                return (left.project?.name ?? "").localizedStandardCompare(right.project?.name ?? "") == .orderedAscending
            }
    }

    private var groupedItems: [GreegPatchSection] {
        let kinds = Array(Set(visibleItems.map { GreegPatchKind(project: $0.project) }))
            .sorted { left, right in
                if left.rank != right.rank { return left.rank < right.rank }
                return left.sectionTitle.localizedStandardCompare(right.sectionTitle) == .orderedAscending
            }

        return kinds.compactMap { kind in
            let items = visibleItems.filter { kind == GreegPatchKind(project: $0.project) }
            return items.isEmpty ? nil : GreegPatchSection(kind: kind, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard

                    if visibleItems.isEmpty {
                        emptyCard
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(groupedItems) { section in
                                VStack(alignment: .leading, spacing: 9) {
                                    Text(section.kind.sectionTitle)
                                        .font(.caption.weight(.black))
                                        .foregroundStyle(section.kind.tint)
                                        .tracking(1.1)
                                        .padding(.leading, 4)

                                    VStack(spacing: 9) {
                                        ForEach(section.items) { item in
                                            NavigationLink {
                                                GreegPatchDetailView(projectID: item.id)
                                            } label: {
                                                GreegPatchRow(item: item)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Archivos")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: reloadPrivatePatches)
        }
    }

    private var headerCard: some View {
        GreegPanel {
            HStack(spacing: 12) {
                AppLogo(size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Centro GREEG")
                        .font(.headline.weight(.black))
                    Text("\(visibleItems.count) archivos privados")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.green)
            }
        }
    }

    private var emptyCard: some View {
        GreegPanel {
            VStack(spacing: 13) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                Text("Preparando archivos")
                    .font(.title3.weight(.black))
                Text("Toca actualizar en Inicio y vuelve aqui si todavia no aparecen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Recargar") {
                    reloadPrivatePatches()
                }
                .font(.headline.weight(.bold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func reloadPrivatePatches() {
        BundledPatchSeeder.seedIfNeeded()
        store.reload()
        logVisiblePatchAudit(items: store.items)
    }

    private static func rank(for name: String?) -> Int {
        let normalized = normalize(name ?? "")
        return normalizedFeaturedDisplayOrder.firstIndex(of: normalized) ?? Int.max
    }

    fileprivate static func shouldShow(_ project: PatchProject) -> Bool {
        isGreegManaged(project)
            && BundledPatchSeeder.projectIDs.contains(project.id)
            && (!project.rules.isEmpty || !project.directories.isEmpty)
    }

    private static func discardReason(for project: PatchProject) -> String? {
        if !isGreegManaged(project) {
            return "sin-metadatos-greeg"
        }
        if project.rules.isEmpty && project.directories.isEmpty {
            return "sin-reglas-o-rutas"
        }
        return nil
    }

    private static func isGreegManaged(_ project: PatchProject) -> Bool {
        let author = project.author.lowercased()
        return author.contains("[greeg_category:")
            || author.contains("[greeg_style:")
    }

    private func logVisiblePatchAudit(items: [PatchLibraryItem]) {
        var shownCount = 0
        var discardedCount = 0
        log("registros recibidos de Supabase: \(items.count) (biblioteca local)")
        for item in items {
            guard let project = item.project else {
                discardedCount += 1
                log("registros descartados: <sin proyecto>; motivo del descarte: no-decodificado")
                continue
            }
            if let reason = Self.discardReason(for: project) {
                discardedCount += 1
                log("registros descartados: \(project.name); motivo del descarte: \(reason)")
            } else {
                shownCount += 1
            }
        }
        log("registros finalmente mostrados: \(shownCount); registros descartados: \(discardedCount)")
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

private struct GreegPatchSection: Identifiable {
    let kind: GreegPatchKind
    let items: [PatchLibraryItem]

    var id: String { kind.id }
}

private struct GreegPatchKind: Hashable, Identifiable {
    let id: String
    let sectionTitle: String
    let style: GreegPatchStyle
    let rank: Int

    init(project: PatchProject?) {
        let author = project?.author.lowercased() ?? ""
        let category = Self.metadataValue("greeg_category", in: author)
        let style = Self.style(author: author, category: category, name: project?.name ?? "")
        self.init(style: style, category: category)
    }

    private init(style: GreegPatchStyle, category: String?) {
        self.style = style
        switch style {
        case .antena:
            id = "style-antena"
            sectionTitle = "ANTENA"
            rank = 0
        case .holo:
            id = "style-holo"
            sectionTitle = "HOLO"
            rank = 1
        case .aimbotNormal:
            id = "style-aimbot-normal"
            sectionTitle = "AIMBOT NORMAL"
            rank = 2
        case .category:
            let title = Self.sectionTitle(for: category)
            id = "category-\(Self.slug(for: title))"
            sectionTitle = title
            rank = 3
        }
    }

    private static func style(author: String, category: String?, name: String) -> GreegPatchStyle {
        if author.contains("[greeg_style:antena]") { return .antena }
        if author.contains("[greeg_style:holo]") { return .holo }
        if author.contains("[greeg_style:aimbot-normal]") { return .aimbotNormal }

        let normalizedName = name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        if normalizedName.contains("antena") { return .antena }
        if normalizedName.contains("holo") { return .holo }
        if category == "shaders" { return .holo }
        if category == "aimbots" || category == "patches" || category == "files" { return .aimbotNormal }
        return .category
    }

    private static func metadataValue(_ key: String, in text: String) -> String? {
        let pattern = "\\[\(key):([^\\]]+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let value = String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var tint: Color {
        style.tint
    }

    var iconName: String {
        style.iconName
    }

    private static func sectionTitle(for category: String?) -> String {
        guard let category, !category.isEmpty else { return "REMOTOS" }
        return category
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
    }

    private static func slug(for value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

private enum GreegPatchStyle: String, Hashable {
    case antena
    case holo
    case aimbotNormal
    case category

    var tint: Color {
        switch self {
        case .antena:
            return AppTheme.accent
        case .holo:
            return Color(red: 0.19, green: 0.84, blue: 0.38)
        case .aimbotNormal:
            return Color(red: 1.0, green: 0.78, blue: 0.16)
        case .category:
            return AppTheme.accent
        }
    }

    var iconName: String {
        switch self {
        case .antena:
            return "antenna.radiowaves.left.and.right"
        case .holo:
            return "sparkles"
        case .aimbotNormal:
            return "scope"
        case .category:
            return "shippingbox.fill"
        }
    }
}

private struct GreegPatchRow: View {
    let item: PatchLibraryItem

    private var project: PatchProject? { item.project }
    private var isApplied: Bool { DevicePatchService.latestReceipt(projectID: item.id) != nil }
    private var kind: GreegPatchKind { GreegPatchKind(project: project) }

    var body: some View {
        GreegPanel {
            HStack(spacing: 11) {
                AppRowIcon(
                    systemName: iconName,
                    tint: kind.tint,
                    symbolSize: 15,
                    frameSize: 36
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(project?.name ?? "Archivo GREEG")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(isApplied ? "Activo" : "Listo para aplicar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: isApplied ? "checkmark.seal.fill" : "chevron.right")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(isApplied ? .green : kind.tint)
            }
        }
    }

    private var iconName: String {
        let name = (project?.name ?? "Archivo GREEG").lowercased()
        if name.contains("cuello") {
            return "link.circle.fill"
        }
        if name.contains("pecho") {
            return "target"
        }
        return kind.iconName
    }
}

private struct GreegPatchDetailView: View {
    @EnvironmentObject private var store: PatchProjectStore
    let projectID: UUID
    @State private var isWorking = false
    @State private var actionAlert: GreegPatchActionAlert?

    private var item: PatchLibraryItem? {
        store.items.first(where: { $0.id == projectID })
    }

    private var project: PatchProject? {
        item?.project
    }

    private var receipt: PatchTransactionReceipt? {
        DevicePatchService.latestReceipt(projectID: projectID)
    }

    private var isApplied: Bool {
        receipt != nil
    }

    private var kind: GreegPatchKind {
        GreegPatchKind(project: project)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statusCard

                Link(destination: GreegSocialLink.tiktok.url) {
                    GreegPanel {
                        SocialRow(link: .tiktok)
                    }
                }

                actionButton(
                    title: isWorking ? "Aplicando" : "Aplicar",
                    subtitle: "Activar archivo",
                    systemImage: "checkmark.shield.fill",
                    isPrimary: true,
                    isDisabled: isWorking || isApplied,
                    action: apply
                )

                actionButton(
                    title: isWorking ? "Restaurando" : "Original",
                    subtitle: "Volver al original",
                    systemImage: "arrow.counterclockwise.circle.fill",
                    isPrimary: false,
                    isDisabled: isWorking || !isApplied,
                    action: restore
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 36)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(project?.name ?? "Archivo")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            BundledPatchSeeder.seedIfNeeded()
            store.reload()
        }
        .alert(item: $actionAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var statusCard: some View {
        GreegPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    AppRowIcon(systemName: kind.iconName, tint: kind.tint, symbolSize: 16, frameSize: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(project?.name ?? "Archivo GREEG")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                        Text("Control privado")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                }

                HStack {
                    Label(isApplied ? "Activo" : "Listo", systemImage: isApplied ? "checkmark.seal.fill" : "circle.dotted")
                        .font(.headline.weight(.black))
                        .foregroundStyle(isApplied ? .green : kind.tint)
                    Spacer()
                    Text(isApplied ? "ON" : "OK")
                        .font(.headline.weight(.black))
                        .foregroundStyle(isApplied ? .green : kind.tint)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func actionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        isPrimary: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.black))
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.black))
                    Text(subtitle)
                        .font(.caption.weight(.bold))
                        .opacity(0.82)
                }
                Spacer()
                if isWorking {
                    ProgressView()
                        .tint(.white)
                }
            }
            .foregroundColor(isPrimary ? .white : .secondary)
            .padding(.horizontal, 16)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isPrimary ? AppTheme.accent : Color(red: 0.07, green: 0.065, blue: 0.075))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.accent.opacity(isPrimary ? 0 : 0.2), lineWidth: 1)
                    )
            )
            .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func apply() {
        guard let item, let baseProject = item.project else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                let project = item.summary.schemaVersion >= 2 && item.canInspectContents
                    ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                    : baseProject
                _ = try DevicePatchService.apply(project: project)
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    actionAlert = GreegPatchActionAlert(title: "Listo", message: "Archivo aplicado correctamente.")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = GreegPatchActionAlert(title: "Failed", message: message(for: error))
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = GreegPatchActionAlert(title: "Failed", message: "No se pudo aplicar el archivo.")
                }
            }
        }
    }

    private func restore() {
        guard let receipt else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    actionAlert = GreegPatchActionAlert(title: "Listo", message: "Archivo original restaurado.")
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    actionAlert = GreegPatchActionAlert(title: "Failed", message: message(for: error))
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    actionAlert = GreegPatchActionAlert(title: "Failed", message: "No se pudo restaurar el original.")
                }
            }
        }
    }

    private func message(for error: PatchPackageError) -> String {
        switch error {
        case .targetAppUnavailable(let bundleID):
            return "La app destino no esta instalada o no se puede abrir: \(bundleID)."
        case .projectAlreadyApplied:
            return "Este archivo ya esta activo. Usa Original si quieres volver atras."
        default:
            return error.localizedDescription
        }
    }
}

private struct GreegPatchActionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct GreegInstallationView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instalación")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                        Text("Solo prepara el VPN antes de usar la app.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 14)

                    GreegPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                AppRowIcon(systemName: "network", tint: AppTheme.accent, symbolSize: 18, frameSize: 46)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("VPN")
                                        .font(.title3.weight(.black))
                                    Text("Instala LocalDevVPN y luego entra para activar o revisar el túnel.")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Button(action: { open("https://apps.apple.com/search?term=LocalDevVPN") }) {
                                installButtonLabel("Descargar VPN", icon: "arrow.down.circle.fill")
                            }
                            .buttonStyle(.plain)

                            Button(action: { open("App-Prefs:root=General&path=VPN") }) {
                                installButtonLabel("Entrar en VPN", icon: "lock.shield.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 36)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Instalación")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func installButtonLabel(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            Image(systemName: "arrow.up.right")
        }
        .font(.subheadline.weight(.black))
        .foregroundStyle(.black)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.accent)
        )
    }

    private func open(_ value: String) {
        guard let url = URL(string: value) else { return }
        openURL(url)
    }
}

private struct GreegSettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    settingsSection("Information") {
                        statusRow("Current version", value: "Supported", valueColor: .green)
                        divider
                        statusRow("Hardware model", value: UIDevice.current.model)
                        divider
                        statusRow("iOS Version", value: UIDevice.current.systemVersion)
                    }

                    settingsSection("Connection") {
                        statusRow("Tunnel connection", value: "Not connected")
                        divider
                        statusRow("Pairing", value: "Not configured")
                        divider
                        actionRow(
                            title: "Pair on this iPhone",
                            icon: "link.badge.plus",
                            action: { open("App-Prefs:root=Privacy&path=DEVELOPER_MODE") }
                        )
                        divider
                        actionRow(
                            title: "Import pairing file",
                            icon: "square.and.arrow.down",
                            action: { open("shareddocuments://") }
                        )
                    }

                    Text("AirLift versions require pairing. On iOS below 27, import a pairing file from a computer. Passcode and Apple Wallet always require AirLift.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }
                .padding(.horizontal, 14)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.headline.weight(.bold))
                }
            }
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
            GreegPanel {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    private func statusRow(_ title: String, value: String, valueColor: Color = .secondary) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private func actionRow(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28)
                Text(title)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(AppTheme.accent)
                Spacer()
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
    }

    private func open(_ value: String) {
        guard let url = URL(string: value) else { return }
        openURL(url)
    }
}

private struct GreegSocialView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Redes oficiales")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                        Text("Canal privado de GREEG APP.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 14)

                    GreegPanel {
                        Link(destination: GreegSocialLink.tiktok.url) {
                            SocialRow(link: .tiktok)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 36)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Redes")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private enum GreegSocialLink {
    case tiktok

    var title: String { "TikTok" }
    var subtitle: String { "@gregg_top" }
    var systemImage: String { "play.rectangle.fill" }
    var url: URL {
        URL(string: "https://www.tiktok.com/@gregg_top?is_from_webapp=1&sender_device=pc")!
    }
}

private struct SocialRow: View {
    let link: GreegSocialLink

    var body: some View {
        HStack(spacing: 16) {
            AppRowIcon(systemName: link.systemImage, tint: AppTheme.accent, symbolSize: 17, frameSize: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(link.title)
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppTheme.accent)
                Text(link.subtitle)
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent.opacity(0.72))
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.headline.weight(.black))
                .foregroundStyle(AppTheme.accent.opacity(0.8))
        }
        .contentShape(Rectangle())
    }
}

private struct GreegPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color(red: 0.09, green: 0.085, blue: 0.095))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(AppTheme.accent.opacity(0.28), lineWidth: 1)
                    )
            )
    }
}

private struct HomePatchRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            AppRowIcon(systemName: icon, tint: tint, symbolSize: 14, frameSize: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.green)
        }
    }
}

private struct HomeMetric: View {
    let value: String
    let title: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.headline.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
