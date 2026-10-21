import Foundation
import Security

/// Per-file grants are deliberately kept separate from the membership key.
/// The IPA never contains a master password; Supabase decides whether a key
/// can unlock a specific remote file on this device.
enum ContentLicenseStore {
    private static let prefix = "nexus.content.license."

    static func hasAccess(fileID: String, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: prefix + fileID.lowercased())
    }

    static func grant(fileID: String, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: prefix + fileID.lowercased())
    }

    static func activate(key: String, fileID: String) async throws -> String {
        guard let contentID = UUID(uuidString: fileID) else {
            throw ContentLicenseError.invalidFile
        }
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { throw ContentLicenseError.invalidKey }

        var components = URLComponents(url: SupabaseLicenseConfig.projectURL, resolvingAgainstBaseURL: false)
        components?.path = "/rest/v1/rpc/activate_content_license"
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
            throw ContentLicenseError.server("La key no fue aceptada por el servidor.")
        }
        let result = try JSONDecoder().decode(ContentLicenseResponse.self, from: data)
        guard result.success else { throw ContentLicenseError.server(result.message) }
        grant(fileID: fileID)
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
        case .invalidFile: return "El archivo protegido no tiene un identificador válido."
        case .invalidKey: return "Escribe una key válida."
        case .badURL: return "No se pudo preparar la conexión segura."
        case .server(let message): return message
        }
    }
}
