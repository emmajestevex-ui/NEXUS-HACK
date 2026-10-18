import SwiftUI

@main
struct NexusCommunityApp: App {
    @StateObject private var store = CommunityStore()

    var body: some Scene {
        WindowGroup {
            CommunityRootView()
                .environmentObject(store)
                .task { await store.sync() }
        }
    }
}
