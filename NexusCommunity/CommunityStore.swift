import Foundation
import Combine

@MainActor
final class CommunityStore: ObservableObject {
    @Published private(set) var categories: [CommunityCategory] = []
    @Published private(set) var posts: [CommunityPost] = []
    @Published private(set) var settings = CommunitySettings.fallback
    @Published private(set) var isLoading = false
    @Published private(set) var lastSynced: Date?
    @Published var errorMessage: String?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
        }
        return decoder
    }()

    func sync() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let categoryData = request("nexus_categories?select=id,name,icon,parent_id,sort_order&is_active=eq.true&order=sort_order.asc,name.asc")
            async let postData = request("nexus_posts?select=id,category_id,kind,title,body,image_url,created_at&is_published=eq.true&order=created_at.desc")
            async let settingData = request("nexus_settings?select=brand_name,tagline,discord_url,tiktok_url&id=eq.1&limit=1")

            let (categoriesData, postsData, settingsData) = try await (categoryData, postData, settingData)
            categories = try decoder.decode([CommunityCategory].self, from: categoriesData)
            posts = try decoder.decode([CommunityPost].self, from: postsData)
            if let first = try decoder.decode([CommunitySettings].self, from: settingsData).first {
                settings = first
            }
            lastSynced = Date()
        } catch {
            errorMessage = "No se pudo actualizar. Revisa tu conexión e inténtalo otra vez."
        }
    }

    private func request(_ path: String) async throws -> Data {
        guard let url = URL(string: "rest/v1/\(path)", relativeTo: AppConfig.supabaseURL)?.absoluteURL else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue(AppConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
