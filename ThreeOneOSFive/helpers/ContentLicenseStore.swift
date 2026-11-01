import Foundation
import Security

/// Access is per category and lasts only during this app process.
/// Avoid persisting a naked boolean that survives a revoke/restart.
enum ContentLicenseStore {
    private static let guardLock = NSLock()
    private static var unlockedCategories = Set<String>()
    private static var sessionKeys: [String: String] = [:]

    static func hasAccess(category: String) -> Bool {
        guardLock.lock()
        defer { guardLock.unlock() }
        return unlockedCategories.contains(category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    static func sessionKey(for category: String) -> String? {
        guardLock.lock()
        defer { guardLock.unlock() }
        return sessionKeys[category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    private static func grant(category: String, key: String) {
        guardLock.lock()
        let id = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        unlockedCategories.insert(id)
        sessionKeys[id] = key // Memory only: never persisted in UserDefaults or app binary.
        guardLock.unlock()
    }

    static func activate(key: String, fileID: String, category: String) async throws -> String {
        guard let contentID = UUID(uuidString: fileID), !category.isEmpty else {
            throw ContentLicenseError.invalidFile
        }
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { throw ContentLicenseError.invalidKey }
        var components = URLComponents(url: SupabaseLicenseConfig.projectURL, resolvingAgainstBaseURL: false)
        components?.path = "/rest/v1/rpc/activate_nexus_category_key"
        guard let url = components?.url else { throw ContentLicenseError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue(SupabaseLicenseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseLicenseConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "p_license_key": normalized,
            "p_device_id": UserDefaults.standard.string(forKey: "greeg.license.device") ?? "",
            "p_content_id": contentID.uuidString
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ContentLicenseError.server("No se pudo validar la categoría. Ejecuta primero el SQL NEXUS V3 en Supabase.")
        }
        let result = try JSONDecoder().decode(ContentLicenseResponse.self, from: data)
        guard result.success else { throw ContentLicenseError.server(result.message) }
        grant(category: category, key: normalized)
        return result.message
    }
}

private struct ContentLicenseResponse: Decodable {
    let success: Bool
    let message: String
}

enum ContentLicenseError: LocalizedError {
    case invalidFile
    case invalidKey
    case badURL
    case server(String)
    var errorDescription: String? {
        switch self {
        case .invalidFile: return "Este archivo no tiene una categoría válida."
        case .invalidKey: return "Escribe una key válida para esta categoría."
        case .badURL: return "No se pudo preparar la conexión segura."
        case .server(let message): return message
        }
    }
}
