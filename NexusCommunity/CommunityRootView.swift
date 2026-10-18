import SwiftUI

private enum NexusStyle {
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.15)
    static let muted = Color(red: 0.43, green: 0.47, blue: 0.52)
    static let line = Color(red: 0.88, green: 0.90, blue: 0.92)
    static let paper = Color(red: 0.97, green: 0.975, blue: 0.98)
    static let cyan = Color(red: 0.02, green: 0.62, blue: 0.77)
    static let green = Color(red: 0.11, green: 0.55, blue: 0.39)
}

private enum CommunityTab: Hashable {
    case home, explore, community
}

struct CommunityRootView: View {
    @EnvironmentObject private var store: CommunityStore
    @State private var selectedTab: CommunityTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem { Label("Inicio", systemImage: "house") }
                .tag(CommunityTab.home)
            ExploreView()
                .tabItem { Label("Explorar", systemImage: "square.grid.2x2") }
                .tag(CommunityTab.explore)
            CommunityLinksView()
                .tabItem { Label("Comunidad", systemImage: "person.2") }
                .tag(CommunityTab.community)
        }
        .tint(NexusStyle.ink)
        .toolbarBackground(.white, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(NexusStyle.paper)
        .alert("No se pudo actualizar", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("Entendido", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var store: CommunityStore
    @Binding var selectedTab: CommunityTab

    private var announcements: [CommunityPost] { store.posts.filter { $0.kind == "announcement" } }
    private var featured: [CommunityPost] { store.posts.filter { $0.kind != "announcement" }.prefix(4).map { $0 } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let latest = announcements.first { announcement(latest) }
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Explora", action: "Ver todo") { selectedTab = .explore }
                        if store.categories.isEmpty {
                            emptyState("Todavía no hay categorías publicadas.")
                        } else {
                            categoryGrid
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Lo nuevo", action: "Explorar") { selectedTab = .explore }
                        if featured.isEmpty {
                            emptyState("Las novedades aparecerán aquí.")
                        } else {
                            ForEach(featured) { post in PostCard(post: post, category: store.categories.first { $0.id == post.categoryID }) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(NexusStyle.paper)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await store.sync() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("NexusWolf")
                .resizable().scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(store.settings.brandName).font(.system(size: 19, weight: .bold)).foregroundStyle(NexusStyle.ink)
                Text(store.settings.tagline).font(.system(size: 13)).foregroundStyle(NexusStyle.muted)
            }
            Spacer(minLength: 8)
            Button { Task { await store.sync() } } label: {
                Image(systemName: store.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NexusStyle.ink)
                    .frame(width: 42, height: 42)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(NexusStyle.line))
            }
            .disabled(store.isLoading)
            .accessibilityLabel("Sincronizar contenido")
        }
        .padding(.vertical, 8)
    }

    private func announcement(_ post: CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "megaphone.fill").foregroundStyle(NexusStyle.cyan)
                Text("ANUNCIO").font(.system(size: 11, weight: .bold)).tracking(0.5).foregroundStyle(NexusStyle.muted)
            }
            Text(post.title).font(.system(size: 20, weight: .bold)).foregroundStyle(NexusStyle.ink)
            if !post.body.isEmpty { Text(post.body).font(.system(size: 15)).foregroundStyle(NexusStyle.muted).fixedSize(horizontal: false, vertical: true) }
            Text(post.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 12, weight: .medium)).foregroundStyle(NexusStyle.muted)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(NexusStyle.cyan).frame(width: 3).padding(.vertical, 10) }
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(NexusStyle.line))
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(store.categories.filter { $0.parentID == nil }) { category in
                Button { selectedTab = .explore } label: {
                    HStack(spacing: 12) {
                        Image(systemName: category.icon.isEmpty ? "square.grid.2x2" : category.icon)
                            .font(.system(size: 17, weight: .semibold)).foregroundStyle(NexusStyle.cyan)
                            .frame(width: 38, height: 38).background(NexusStyle.paper, in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(NexusStyle.ink).lineLimit(1)
                            Text("\(store.posts.filter { $0.categoryID == category.id }.count) publicaciones").font(.system(size: 11)).foregroundStyle(NexusStyle.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(NexusStyle.line))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionHeader(_ title: String, action: String, onTap: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(NexusStyle.ink)
            Spacer()
            Button(action, action: onTap).font(.system(size: 13, weight: .semibold)).foregroundStyle(NexusStyle.cyan)
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).foregroundStyle(NexusStyle.muted)
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(NexusStyle.line))
    }
}

private struct ExploreView: View {
    @EnvironmentObject private var store: CommunityStore
    @State private var selectedCategory: UUID?

    private var visiblePosts: [CommunityPost] {
        store.posts.filter { selectedCategory == nil || $0.categoryID == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Explorar contenido").font(.system(size: 27, weight: .bold)).foregroundStyle(NexusStyle.ink)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip("Todo", id: nil)
                            ForEach(store.categories) { category in filterChip(category.name, id: category.id) }
                        }
                    }
                    if visiblePosts.isEmpty {
                        Text("No hay publicaciones en esta categoría todavía.").font(.system(size: 14)).foregroundStyle(NexusStyle.muted).padding(.top, 14)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(visiblePosts) { post in PostCard(post: post, category: store.categories.first { $0.id == post.categoryID }) }
                        }
                    }
                }
                .padding(20)
            }
            .background(NexusStyle.paper)
            .navigationBarHidden(true)
            .refreshable { await store.sync() }
        }
    }

    private func filterChip(_ title: String, id: UUID?) -> some View {
        Button { selectedCategory = id } label: {
            Text(title).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selectedCategory == id ? .white : NexusStyle.ink)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(selectedCategory == id ? NexusStyle.ink : .white, in: Capsule())
                .overlay(Capsule().stroke(selectedCategory == id ? NexusStyle.ink : NexusStyle.line))
        }
        .buttonStyle(.plain)
    }
}

private struct PostCard: View {
    let post: CommunityPost
    let category: CommunityCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL = post.imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill().frame(height: 174).clipped()
                    } else {
                        Rectangle().fill(NexusStyle.paper).frame(height: 174)
                            .overlay(Image(systemName: "photo").foregroundStyle(NexusStyle.muted))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(category?.name ?? (post.kind == "tutorial" ? "Tutorial" : "Comunidad"))
                    Text("·")
                    Text(post.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(NexusStyle.muted)
                Text(post.title).font(.system(size: 17, weight: .bold)).foregroundStyle(NexusStyle.ink)
                if !post.body.isEmpty { Text(post.body).font(.system(size: 14)).foregroundStyle(NexusStyle.muted).lineLimit(4).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(NexusStyle.line))
    }
}

private struct CommunityLinksView: View {
    @EnvironmentObject private var store: CommunityStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Comunidad").font(.system(size: 27, weight: .bold)).foregroundStyle(NexusStyle.ink)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Conecta con NEXUS").font(.system(size: 19, weight: .bold)).foregroundStyle(NexusStyle.ink)
                        Text("Canales oficiales y novedades de la comunidad.").font(.system(size: 14)).foregroundStyle(NexusStyle.muted)
                    }
                    VStack(spacing: 0) {
                        if let url = store.settings.discordURL { linkRow("Discord", detail: "Servidor de la comunidad", icon: "bubble.left.and.bubble.right.fill", url: url) }
                        if let url = store.settings.tiktokURL { Divider().padding(.leading, 58); linkRow("TikTok", detail: "Videos y actualizaciones", icon: "play.rectangle.fill", url: url) }
                    }
                    .padding(.horizontal, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(NexusStyle.line))
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Cuenta y seguridad", systemImage: "lock.shield")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(NexusStyle.ink)
                        Text("Esta app solo muestra contenido comunitario publicado. No solicita contraseñas de juegos.")
                            .font(.system(size: 13)).foregroundStyle(NexusStyle.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(NexusStyle.line))
                }
                .padding(20)
            }
            .background(NexusStyle.paper)
            .navigationBarHidden(true)
        }
    }

    private func linkRow(_ name: String, detail: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(NexusStyle.ink)
                    .frame(width: 40, height: 40).background(NexusStyle.paper, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.system(size: 15, weight: .semibold)).foregroundStyle(NexusStyle.ink)
                    Text(detail).font(.system(size: 12)).foregroundStyle(NexusStyle.muted)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(NexusStyle.muted)
            }
            .padding(.vertical, 12)
        }
    }
}
