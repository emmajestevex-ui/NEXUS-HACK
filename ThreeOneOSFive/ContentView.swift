import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var remoteContentStore: RemoteContentStore
    @State private var tabNavigation = AppTabNavigationState()
    @State private var showingMoreTabs = false
    @Namespace private var dockNamespace
    let onSignOut: () -> Void
    let onLicenseActivated: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: tabSelection) {
                ForEach(Array(visibleTabs.enumerated()), id: \.element.id) { offset, tab in
                    tabView(for: tab)
                        .tag(offset)
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 92)
            }

            NexusDock(
                tabs: visibleTabs,
                selection: tabSelection,
                namespace: dockNamespace,
                onMore: { showingMoreTabs = true }
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .animation(.easeInOut(duration: 0.22), value: tabNavigation.selectedTab)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil, let index = visibleTabs.firstIndex(where: { $0.kind == "files" }) { tabNavigation.select(index) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil, let index = visibleTabs.firstIndex(where: { $0.kind == "files" }) { tabNavigation.select(index) }
        }
        .sheet(isPresented: $showingMoreTabs) {
            NexusMoreTabsSheet(tabs: Array(visibleTabs.dropFirst(4)), baseIndex: 4, selection: tabSelection)
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var visibleTabs: [NexusAppTab] {
        let configured = remoteContentStore.appContent.tabs
        if configured.isEmpty { return NexusAppContent.defaultTabs }

        let configuredIDs = Set(configured.map(\.id))
        let builtInAdditions = NexusAppContent.defaultTabs.filter {
            ($0.kind == "membership" || $0.kind == "support") && !configuredIDs.contains($0.id)
        }
        return (configured + builtInAdditions)
            .filter(\.enabled)
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    @ViewBuilder
    private func tabView(for tab: NexusAppTab) -> some View {
        switch tab.kind {
        case "home":
            GreegHomeView(onSignOut: onSignOut) {
                if let index = visibleTabs.firstIndex(where: { $0.kind == "files" }) { tabNavigation.select(index) }
            }
        case "files":
            GreegPatchLibraryView()
        case "installation":
            GreegInstallationView()
        case "socials":
            GreegSocialView()
        case "membership":
            NexusMembershipView(onSignOut: onSignOut, onLicenseActivated: onLicenseActivated)
        case "support":
            NexusSupportView(socials: remoteContentStore.appContent.socials)
        default:
            if let category = remoteContentStore.appContent.categories.first(where: { $0.id == tab.id }) {
                NexusCategoryTabView(category: category)
            } else {
                EmptyView()
            }
        }
    }
}

private struct NexusMembershipView: View {
    @AppStorage("greeg.license.key") private var storedKey = ""
    @AppStorage("greeg.license.supabaseUnlocked") private var isUnlocked = false
    @State private var showingDeactivateConfirmation = false
    @State private var showingLicenseSheet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onSignOut: () -> Void
    let onLicenseActivated: () -> Void

    private var maskedKey: String {
        let clean = storedKey.normalizedLicenseKey
        guard clean.count > 8 else { return clean.isEmpty ? "Sin key activa" : "••••••••" }
        return "\(clean.prefix(4))••••\(clean.suffix(4))"
    }

    private var expirationText: String {
        guard let date = LicenseEntitlements.storedExpirationDate() else { return "Sin fecha definida" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("MEMBRESÍA")
                        .font(.caption.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(NexusTheme.secondaryText)
                        .padding(.leading, 4)

                    NexusCard(style: .elevated) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                NexusIconTile(
                                    systemName: isUnlocked ? "checkmark.seal.fill" : "lock.fill",
                                    tint: isUnlocked ? NexusTheme.success : NexusTheme.secondaryText,
                                    size: 48
                                )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(isUnlocked ? "Membresía activa" : "Sin membresía")
                                        .font(.title3.weight(.black))
                                    Text(isUnlocked ? "Acceso verificado a NEXUS HACK" : "Activa tu key para desbloquear funciones privadas")
                                        .font(.subheadline)
                                        .foregroundStyle(NexusTheme.secondaryText)
                                }
                                Spacer()
                                NexusBadge(title: isUnlocked ? "PRO" : "LOCKED", tint: isUnlocked ? NexusTheme.success : NexusTheme.secondaryText)
                            }

                            Divider().overlay(Color.white.opacity(0.08))

                            MembershipDetailRow(icon: "key.fill", title: "Clave", value: maskedKey, tint: NexusTheme.blueBright)
                            MembershipDetailRow(icon: "clock.fill", title: "Estado", value: isUnlocked ? "Activa" : "Inactiva", tint: isUnlocked ? NexusTheme.success : NexusTheme.secondaryText)
                            MembershipDetailRow(icon: "calendar", title: "Expiración", value: expirationText, tint: NexusTheme.blueBright)

                            Button {
                                showingDeactivateConfirmation = true
                            } label: {
                                Label("Desactivar key", systemImage: "xmark.circle.fill")
                                    .font(.headline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(NexusTheme.danger)
                            .buttonBorderShape(.roundedRectangle(radius: 16))
                            .disabled(!isUnlocked)
                        }
                    }
                    .nexusEntrance(index: 0)
                    .animation(
                        NexusMotionPolicy.animation(reduceMotion: reduceMotion, normal: .spring(response: 0.38, dampingFraction: 0.82)),
                        value: isUnlocked
                    )

                    if !isUnlocked {
                        NexusCard {
                            HStack(spacing: 12) {
                                NexusIconTile(systemName: "key.fill", tint: NexusTheme.blue, size: 42)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Activar membresía")
                                        .font(.headline.weight(.bold))
                                    Text("Escribe tu código de acceso seguro")
                                        .font(.subheadline)
                                        .foregroundStyle(NexusTheme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(NexusTheme.secondaryText)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { showingLicenseSheet = true }
                        .transition(
                            NexusMotionPolicy.animation(reduceMotion: reduceMotion, normal: .spring(response: 0.38, dampingFraction: 0.82)) == nil
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity)
                        )
                        .nexusEntrance(index: 1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .background(NexusBackground { Color.clear }.ignoresSafeArea())
            .navigationTitle("Membresía")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingLicenseSheet) {
                GreegLicenseView {
                    NexusHaptics.notification(.success)
                    withAnimation(NexusMotionPolicy.animation(reduceMotion: reduceMotion, normal: .spring(response: 0.42, dampingFraction: 0.84))) {
                        onLicenseActivated()
                        showingLicenseSheet = false
                    }
                }
            }
            .alert("Desactivar key", isPresented: $showingDeactivateConfirmation) {
                Button("Cancelar", role: .cancel) {}
                Button("Desactivar", role: .destructive) {
                    NexusHaptics.notification(.warning)
                    withAnimation(NexusMotionPolicy.animation(reduceMotion: reduceMotion, normal: .easeInOut(duration: 0.24))) {
                        onSignOut()
                    }
                }
            } message: {
                Text("Se eliminará la key guardada en este dispositivo y tendrás que activarla de nuevo.")
            }
        }
    }
}

private struct MembershipDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(NexusTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold).monospaced())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct NexusSupportView: View {
    let socials: [NexusAppSocial]

    private var supportLinks: [NexusAppSocial] {
        if !socials.isEmpty { return socials }
        return [
            NexusAppSocial(title: "Discord", subtitle: "Soporte y comunidad NEXUS HACK", url: "https://discord.gg/9NUBpqNGQ", icon: "bubble.left.and.bubble.right.fill", color: "blue"),
            NexusAppSocial(title: "TikTok", subtitle: "Novedades y contenido", url: "https://www.tiktok.com/@tumbado_sensi7", icon: "music.note", color: "black")
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "headphones.circle.fill")
                            .font(.system(size: 64, weight: .medium))
                            .foregroundStyle(.white)
                        Text("Centro de soporte")
                            .font(.largeTitle.weight(.black))
                        Text("Ayuda, anuncios y comunidad NEXUS HACK")
                            .font(.subheadline)
                            .foregroundStyle(NexusTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 18)
                    .nexusEntrance(index: 0)

                    ForEach(Array(supportLinks.enumerated()), id: \.element.id) { index, social in
                        if let url = URL(string: social.url) {
                            Link(destination: url) {
                                NexusCard {
                                    HStack(spacing: 12) {
                                        NexusIconTile(systemName: social.icon, tint: social.color.lowercased() == "black" ? .white : NexusTheme.blue, size: 44)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(social.title).font(.headline.weight(.bold))
                                            Text(social.subtitle).font(.subheadline).foregroundStyle(NexusTheme.secondaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(NexusTheme.blueBright)
                                    }
                                }
                            }
                            .buttonStyle(NexusPressStyle())
                            .nexusEntrance(index: index + 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .background(NexusBackground { Color.clear }.ignoresSafeArea())
            .navigationTitle("Soporte")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct NexusDock: View {
    let tabs: [NexusAppTab]
    @Binding var selection: Int
    let namespace: Namespace.ID
    let onMore: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsMore: Bool { tabs.count > 5 }
    private var displayedTabs: ArraySlice<NexusAppTab> { tabs.prefix(showsMore ? 4 : 5) }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(displayedTabs.enumerated()), id: \.element.id) { index, tab in
                dockButton(tab: tab, index: index)
            }

            if showsMore {
                Button(action: onMore) {
                    VStack(spacing: 4) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                        Text("Más")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(NexusTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .buttonStyle(NexusPressStyle())
                .accessibilityLabel("Más pestañas")
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(NexusTheme.surface.opacity(0.78), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
    }

    @ViewBuilder
    private func dockButton(tab: NexusAppTab, index: Int) -> some View {
        let isSelected = selection == index
        Button {
            if selection != index { NexusHaptics.selection() }
            selection = index
        } label: {
            VStack(spacing: 4) {
                NexusDockIcon(tab: tab, isSelected: isSelected)
                Text(tab.title)
                    .font(.caption2.weight(isSelected ? .bold : .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? NexusTheme.blueBright : NexusTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(NexusTheme.elevatedSurface)
                        .overlay(Capsule().stroke(NexusTheme.blue.opacity(0.42), lineWidth: 1))
                        .matchedGeometryEffect(id: "nexus-dock-selection", in: namespace)
                }
            }
        }
        .buttonStyle(NexusPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(NexusMotionPolicy.animation(reduceMotion: reduceMotion, normal: .spring(response: 0.38, dampingFraction: 0.8)), value: selection)
    }
}

private struct NexusDockIcon: View {
    let tab: NexusAppTab
    let isSelected: Bool

    var body: some View {
        Group {
            if let iconURL = tab.iconURL, let url = URL(string: iconURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Image(systemName: tab.icon)
                    }
                }
            } else {
                Image(systemName: tab.icon)
            }
        }
        .font(.system(size: 19, weight: isSelected ? .bold : .medium))
        .frame(height: 21)
    }
}

private struct NexusMoreTabsSheet: View {
    let tabs: [NexusAppTab]
    let baseIndex: Int
    @Binding var selection: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(Array(tabs.enumerated()), id: \.element.id) { offset, tab in
                Button {
                    selection = baseIndex + offset
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: tab.icon)
                            .frame(width: 26)
                            .foregroundStyle(NexusTheme.blue)
                        Text(tab.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selection == baseIndex + offset {
                            Image(systemName: "checkmark")
                                .foregroundStyle(NexusTheme.success)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Más secciones")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct NexusCategoryTabView: View {
    @EnvironmentObject private var remoteContentStore: RemoteContentStore
    let category: NexusAppCategory

    private var files: [RemoteContentFile] {
        remoteContentStore.installedFiles.filter {
            $0.category.caseInsensitiveCompare(category.id) == .orderedSame
                || $0.category.caseInsensitiveCompare(category.title) == .orderedSame
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GreegPanel {
                        HStack(spacing: 12) {
                            AppRowIcon(systemName: category.icon, tint: AppTheme.accent, symbolSize: 20, frameSize: 48)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(category.title).font(.title3.weight(.black))
                                Text(category.subtitle.isEmpty ? "Contenido remoto de NEXUS HACK" : category.subtitle)
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .nexusEntrance(index: 0)

                    if files.isEmpty {
                        GreegPanel {
                            VStack(spacing: 10) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                                Text("Sin contenido todavía")
                                    .font(.headline.weight(.bold))
                                Text("Publica archivos en esta categoría y pulsa Sincronizar.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                        }
                        .nexusEntrance(index: 1)
                    } else {
                        ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                            GreegPanel {
                                RemoteFileMiniRow(file: file, tint: AppTheme.accent)
                            }
                            .nexusEntrance(index: index + 1)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
            .background(NexusBackground { Color.clear }.ignoresSafeArea())
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String
    var iconURL: String? = nil

    @ViewBuilder
    var body: some View {
        if let iconURL, let url = URL(string: iconURL) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Image(systemName: systemImage)
                }
            }
        } else if let image = UIImage(
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
    let onSignOut: () -> Void
    let onOpenFiles: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var logoIsBreathing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    heroCard.nexusEntrance(index: 0)
                    if let announcement = remoteContentStore.appContent.announcement {
                        announcementCard(announcement).nexusEntrance(index: 1)
                    }
                    remoteCategoriesCard.nexusEntrance(index: 2)
                    sectionTitle("ARCHIVOS PRINCIPALES").nexusEntrance(index: 3)
                    mainFilesCard.nexusEntrance(index: 4)
                    sectionTitle("REDES").nexusEntrance(index: 5)
                    compactSocialCard.nexusEntrance(index: 6)
                    sectionTitle("ACTUALIZACIONES").nexusEntrance(index: 7)
                    updatesCard.nexusEntrance(index: 8)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
            .background(NexusBackground { Color.clear }.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onSignOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.headline.weight(.black))
                    }
                    .accessibilityLabel("Cerrar sesión")
                }
            }
            .onAppear {
                remoteContentStore.loadLocalState()
                store.reload()
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    logoIsBreathing = true
                }
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
                        .scaleEffect(logoIsBreathing ? 1.035 : 1)
                        .shadow(color: AppTheme.accent.opacity(0.28), radius: 10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("NEXUS HACK")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                        Text("Control privado")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 4) {
                        NexusStatusDot(isActive: appState.isSupported, tint: appState.isSupported ? NexusTheme.success : NexusTheme.danger)
                        Text(appState.isSupported ? "Listo" : "Revisar")
                            .font(.caption.weight(.black))
                            .foregroundStyle(appState.isSupported ? NexusTheme.success : NexusTheme.danger)
                    }
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
                .buttonStyle(NexusPressStyle())

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
            VStack(spacing: 8) {
                ForEach(displaySocials) { social in
                    if let url = URL(string: social.url) {
                        Link(destination: url) {
                            RemoteSocialRow(social: social)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var displaySocials: [NexusAppSocial] {
        if !remoteContentStore.appContent.socials.isEmpty { return remoteContentStore.appContent.socials }
        return [
            NexusAppSocial(title: "Discord", subtitle: "Comunidad NEXUS HACK", url: "https://discord.gg/9NUBpqNGQ", icon: "bubble.left.and.bubble.right.fill", color: "blue"),
            NexusAppSocial(title: "TikTok", subtitle: "@tumbado_sensi7", url: "https://www.tiktok.com/@tumbado_sensi7", icon: "music.note", color: "black")
        ]
    }

    private func announcementCard(_ announcement: NexusAppAnnouncement) -> some View {
        GreegPanel {
            HStack(alignment: .top, spacing: 12) {
                AppRowIcon(systemName: announcement.icon, tint: themeColor(announcement.color), symbolSize: 17, frameSize: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(announcement.title).font(.headline.weight(.bold))
                    Text(announcement.body).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var remoteCategoriesCard: some View {
        let categories = remoteContentStore.appContent.categories.sorted { $0.sortOrder < $1.sortOrder }
        return Group {
            if !categories.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    sectionTitle("CATEGORÍAS")
                    ForEach(categories) { category in
                        let files = remoteContentStore.installedFiles.filter { file in
                            file.category.caseInsensitiveCompare(category.id) == .orderedSame
                                || file.category.caseInsensitiveCompare(category.title) == .orderedSame
                        }
                        GreegPanel {
                            HStack(spacing: 12) {
                                AppRowIcon(systemName: category.icon, tint: themeColor(category.color), symbolSize: 17, frameSize: 42)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(category.title).font(.headline.weight(.bold))
                                    Text(category.subtitle.isEmpty ? "Contenido actualizado por sincronización" : category.subtitle)
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer()
                                Text("\(files.count)")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(themeColor(category.color))
                            }
                            if !files.isEmpty {
                                Divider().padding(.vertical, 2)
                                ForEach(files.prefix(4)) { file in
                                    RemoteFileMiniRow(file: file, tint: themeColor(category.color))
                                }
                            }
                        }
                        .padding(.leading, category.parentID == nil ? 0 : 16)
                    }
                }
            }
        }
    }

    private func themeColor(_ value: String) -> Color {
        switch value.lowercased() {
        case "black": return Color.primary
        case "gray", "grey": return Color.secondary
        default: return AppTheme.accent
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

private struct RemoteSocialRow: View {
    let social: NexusAppSocial

    var body: some View {
        HStack(spacing: 12) {
            AppRowIcon(systemName: social.icon, tint: social.color.lowercased() == "black" ? .primary : AppTheme.accent, symbolSize: 17, frameSize: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(social.title).font(.headline.weight(.bold))
                Text(social.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.accent)
        }
        .padding(.vertical, 3)
    }
}

private struct RemoteFileMiniRow: View {
    let file: RemoteContentFile
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            RemoteFileArtwork(file: file, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name).font(.subheadline.weight(.bold)).lineLimit(1)
                Text(file.description?.nexusCleanDescription ?? "Disponible después de sincronizar")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").foregroundStyle(tint)
        }
        .padding(.vertical, 2)
    }
}

private struct RemoteFileArtwork: View {
    let file: RemoteContentFile
    let tint: Color

    var body: some View {
        Group {
            if let url = file.nexusThumbnailURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { fallback }
                }
            } else { fallback }
        }
        .frame(width: 38, height: 38)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var fallback: some View {
        Image(systemName: "shippingbox.fill")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension String {
    var nexusCleanDescription: String {
        replacingOccurrences(of: #"\s*\[GREEG_STYLE:[^\]]+\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\[GREEG_CATEGORY:[^\]]+\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\[NEXUS_IMAGE:[^\]]+\]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension RemoteContentFile {
    var nexusThumbnailURL: URL? {
        guard let description,
              let match = description.range(of: #"\[NEXUS_IMAGE:([^\]]+)\]"#, options: .regularExpression) else { return nil }
        let token = String(String(description[match]).replacingOccurrences(of: "[NEXUS_IMAGE:", with: "").dropLast())
        guard !token.isEmpty else { return nil }
        return URL(string: "\(SupabaseLicenseConfig.projectURL.absoluteString)/storage/v1/object/public/nexus-hack-content/\(token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token)")
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
            .background(AppTheme.pageBackground.ignoresSafeArea())
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
                    Text("Centro NEXUS HACK")
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
            return "sin-metadatos-nexus"
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
            return Color.secondary
        case .aimbotNormal:
            return AppTheme.accent.opacity(0.76)
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
                    Text(project?.name ?? "Archivo NEXUS HACK")
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
        let name = (project?.name ?? "Archivo NEXUS HACK").lowercased()
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
        .background(AppTheme.pageBackground.ignoresSafeArea())
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
                        Text(project?.name ?? "Archivo NEXUS HACK")
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
            .background(AppTheme.pageBackground.ignoresSafeArea())
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
            .background(AppTheme.pageBackground.ignoresSafeArea())
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
                        Text("Canal privado de NEXUS HACK.")
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
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Redes")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private enum GreegSocialLink {
    case tiktok

    var title: String { "TikTok" }
    var subtitle: String { "@tumbado_sensi7" }
    var systemImage: String { "music.note" }
    var url: URL {
        URL(string: "https://www.tiktok.com/@tumbado_sensi7")!
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
        NexusCard(style: .solid) {
            content()
        }
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
