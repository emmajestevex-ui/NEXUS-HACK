import Foundation

struct CommunityCategory: Decodable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let parentID: UUID?
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, icon
        case parentID = "parent_id"
        case sortOrder = "sort_order"
    }
}

struct CommunityPost: Decodable, Identifiable, Hashable {
    let id: UUID
    let categoryID: UUID?
    let kind: String
    let title: String
    let body: String
    let imageURL: URL?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kind, title, body
        case categoryID = "category_id"
        case imageURL = "image_url"
        case createdAt = "created_at"
    }
}

struct CommunitySettings: Decodable {
    let brandName: String
    let tagline: String
    let discordURL: URL?
    let tiktokURL: URL?

    enum CodingKeys: String, CodingKey {
        case brandName = "brand_name"
        case tagline
        case discordURL = "discord_url"
        case tiktokURL = "tiktok_url"
    }

    static let fallback = CommunitySettings(
        brandName: "NEXUS HACK",
        tagline: "Comunidad, novedades y guias",
        discordURL: URL(string: AppConfig.discordFallback),
        tiktokURL: nil
    )
}
