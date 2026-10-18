import SwiftUI
import UIKit
import Security
import Combine

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var fileOperationCoordinator = FileOperationCoordinator()
    @StateObject private var remoteContentStore = RemoteContentStore()
    @StateObject private var patchStore = PatchProjectStore()
    @StateObject private var repositoryStore = PackageRepositoryStore()
    @State private var showOnboarding = false
    @AppStorage("greeg.license.supabaseUnlocked") private var licenseUnlocked = false
    @State private var licenseMessage = ""
    @State private var licenseCheckInFlight = false
    @State private var licenseValidationPending = true
    @State private var showAttribution = false
    @State private var updateOffer: AppUpdateChecker.Offer?
    @Environment(\.scenePhase) private var scenePhase
    private let licenseGateEnabled = true
    private let licensePoller = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init() {
        configureTabBarAppearance()
        setupLogCapture()
        log("app: 3105 launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.machineName)")
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.028, green: 0.037, blue: 0.052, alpha: 0.97)
                : UIColor(red: 0.97, green: 0.98, blue: 0.995, alpha: 0.97)
        }
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.18)
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    private var language: AppLanguage {
        .english
    }

    private func checkForUpdate() {
        Task {
            guard let offer = await AppUpdateChecker.check() else { return }
            await MainActor.run { updateOffer = offer }
        }
    }

    private func refreshLicenseStatus() {
        guard licenseGateEnabled else {
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: "greeg.license.supabaseUnlocked")
            defaults.set(DeviceInstallationID.current(), forKey: "greeg.license.device")
            licenseMessage = ""
            licenseValidationPending = false
            licenseUnlocked = true
            prepareUnlockedApp()
            return
        }

        let deviceID = DeviceInstallationID.current()
        let storedKey = UserDefaults.standard.string(forKey: "greeg.license.key")?.normalizedLicenseKey ?? ""
        guard !storedKey.isEmpty else {
            licenseValidationPending = false
            if licenseUnlocked {
                lockStoredLicense(message: "Enter a valid key to continue.")
            }
            return
        }

        guard !licenseCheckInFlight else { return }
        licenseCheckInFlight = true

        Task {
            do {
                let response = try await SupabaseLicenseClient().check(licenseKey: storedKey, deviceID: deviceID)
                await MainActor.run {
                    licenseCheckInFlight = false
                    licenseValidationPending = false
                    if response.success {
                        let defaults = UserDefaults.standard
                        defaults.set(storedKey, forKey: "greeg.license.key")
                        defaults.set(deviceID, forKey: "greeg.license.device")
                        defaults.set(true, forKey: "greeg.license.supabaseUnlocked")
                        licenseMessage = ""
                        licenseUnlocked = true
                        LicenseEntitlements.store(response.capabilities, expiresAt: response.expiresAt)
                        prepareUnlockedApp()
                    } else {
                        lockStoredLicense(message: response.message)
                    }
                }
            } catch {
                await MainActor.run {
                    licenseCheckInFlight = false
                    licenseValidationPending = false
                    keepStoredLicenseAfterTemporaryCheckFailure()
                }
            }
        }
    }

    private func keepStoredLicenseAfterTemporaryCheckFailure() {
        licenseMessage = ""
        prepareUnlockedApp()
    }

    private func lockStoredLicense(message: String) {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "greeg.license.supabaseUnlocked")
        LicenseEntitlements.clear()
        licenseMessage = message
        licenseValidationPending = false
        licenseUnlocked = false
    }

    private func signOutLicense() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "greeg.license.key")
        defaults.removeObject(forKey: "greeg.license.device")
        defaults.set(false, forKey: "greeg.license.supabaseUnlocked")
        LicenseEntitlements.clear()
        licenseMessage = "Sesion cerrada. Introduce una key para continuar."
        licenseValidationPending = false
        licenseUnlocked = false
    }

    private func prepareUnlockedApp() {
        BundledPatchSeeder.seedIfNeeded()
        patchStore.reload()
        appState.detectSupport()
        remoteContentStore.loadLocalState()
        remoteContentStore.syncIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !licenseGateEnabled || licenseUnlocked {
                    if licenseGateEnabled && licenseValidationPending {
                        LicenseCheckingView()
                    } else {
                        ContentView(onSignOut: signOutLicense)
                        .environmentObject(appState)
                        .environmentObject(patchDraftCoordinator)
                        .environmentObject(fileOperationCoordinator)
                        .environmentObject(remoteContentStore)
                        .environmentObject(patchStore)
                        .environmentObject(repositoryStore)
                        .environment(\.appLanguage, language)
                        .environment(\.locale, language.locale)
                        .patchStorePresentation(patchStore)
                        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
                        .opacity(showOnboarding ? 0 : 1)
                        .allowsHitTesting(!showOnboarding)

                        if showOnboarding {
                        OnboardingView {
                            OnboardingStore.markCompleted()
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                showOnboarding = false
                            }
                            appState.detectSupport()
                        }
                        .environment(\.appLanguage, language)
                        .environment(\.locale, language.locale)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .zIndex(1)
                        }
                    }
                } else {
                    GreegLicenseView(initialMessage: licenseMessage) {
                        licenseValidationPending = false
                        licenseUnlocked = true
                        prepareUnlockedApp()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .displayIdentityAttribution(isPresented: $showAttribution, enabled: (!licenseGateEnabled || licenseUnlocked) && !showOnboarding)
            .sheet(isPresented: $showAttribution) {
                DisplayAttributionSheet()
            }
            .alert(item: $updateOffer) { offer in
                Alert(
                    title: Text(language.text("update.title")),
                    message: Text(language.text("update.message", offer.version)),
                    primaryButton: .default(Text(language.text("update.agree"))) {
                        UIApplication.shared.open(offer.url)
                    },
                    secondaryButton: .cancel(Text(language.text("update.dismiss"))) {
                        AppUpdateChecker.dismiss(version: offer.version)
                    }
                )
            }
            .onAppear {
                refreshLicenseStatus()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                refreshLicenseStatus()
            }
            .onReceive(licensePoller) { _ in
                guard scenePhase == .active else { return }
                refreshLicenseStatus()
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        let applicable = KernelExploit.isApplicable(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        guard applicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        // iOS < 26: kernel R/W success persists (no sandbox probe)
        // iOS >= 26: verify full sandbox escape is still active
        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("app: existing sandbox access is still active; skipping kernel exploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("app: sandbox access is no longer active")
            }
        }
    }

    func runKernelExploitIfNeeded() {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed else { return }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log("app: running kernel exploit on background...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "kexploit")
                    if KernelExploit.requiresSandboxEscape {
                        log("app: kernel exploit success — sandbox access verified")
                    } else {
                        log("app: kernel exploit success — kernel access active")
                    }
                } else {
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    log("app: kernel exploit failed — relaunch the app before retrying")
                }
            }
        }
    }
}


private struct LicenseCheckingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                AppLogo(size: 82)
                    .shadow(color: AppTheme.accent.opacity(0.45), radius: 18)
                ProgressView()
                    .tint(AppTheme.accent)
                Text("Verificando acceso")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Comprobando tu key segura")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}


private struct GreegLicenseView: View {
    @State private var key: String
    @State private var messageText = ""
    @State private var didActivate = false
    @State private var isLoading = false
    @State private var revealContent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let client = SupabaseLicenseClient()
    let onSuccess: () -> Void

    init(initialMessage: String = "", onSuccess: @escaping () -> Void) {
        _key = State(initialValue: UserDefaults.standard.string(forKey: "greeg.license.key")?.normalizedLicenseKey ?? "")
        _messageText = State(initialValue: initialMessage)
        self.onSuccess = onSuccess
    }

    var body: some View {
        NexusBackground {
            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 44)

                    ZStack {
                        Circle()
                            .stroke(NexusTheme.blue.opacity(0.16), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: revealContent ? 1 : 0)
                            .stroke(
                                AngularGradient(colors: [NexusTheme.blue, NexusTheme.blueBright, .white], center: .center),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(NexusMotionPolicy.animation(reduceMotion: reduceMotion, normal: .easeInOut(duration: 0.8)), value: revealContent)
                        AppLogo(size: 104)
                            .shadow(color: NexusTheme.blue.opacity(0.38), radius: 24)
                    }
                    .frame(width: 132, height: 132)
                    .nexusEntrance(index: 0)

                    VStack(spacing: 7) {
                        Text("NEXUS HACK")
                            .font(.system(size: 31, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.white, NexusTheme.blueBright], startPoint: .leading, endPoint: .trailing)
                            )
                        Text("Acceso privado")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(NexusTheme.secondaryText)
                    }
                    .nexusEntrance(index: 1)

                    NexusCard(style: .solid) {
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                NexusIconTile(systemName: "key.fill", tint: NexusTheme.blue, size: 38)
                                TextField("NEXUS-ABCD-EF12-3456", text: $key)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .foregroundStyle(.white)
                                    .disabled(isLoading || didActivate)
                            }

                            Button(action: primaryAction) {
                                HStack(spacing: 10) {
                                    if isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: didActivate ? "checkmark.circle.fill" : "arrow.right")
                                    }
                                    Text(didActivate ? "Continuar" : "Activar key")
                                        .font(.headline.weight(.bold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(NexusTheme.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(NexusPressStyle())
                            .disabled(isLoading)

                            if !messageText.isEmpty {
                                Text(messageText)
                                    .font(.footnote)
                                    .foregroundStyle(messageText.lowercased().contains("error") ? NexusTheme.danger : NexusTheme.blueBright)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .nexusEntrance(index: 2)

                    Text("Activación segura con Supabase")
                        .font(.caption2.monospaced())
                        .foregroundStyle(NexusTheme.tertiaryText)
                        .nexusEntrance(index: 3)

                    Text("NEXUS HACK · ACCESO PRIVADO")
                        .font(.caption2.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(NexusTheme.tertiaryText)
                        .padding(.top, 24)
                        .padding(.bottom, 18)
                }
                .padding(.horizontal, 20)
            }
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if reduceMotion {
                revealContent = true
            } else {
                withAnimation(.easeInOut(duration: 0.8).delay(0.15)) {
                    revealContent = true
                }
            }
        }
    }

    private func primaryAction() {
        if didActivate {
            onSuccess()
            return
        }

        Task {
            await validateWithSupabase()
        }
    }

    @MainActor
    private func validateWithSupabase() async {
        let normalized = key.normalizedLicenseKey
        guard !normalized.isEmpty else {
            messageText = "Introduce una key para continuar."
            return
        }

        key = normalized
        isLoading = true
        defer { isLoading = false }

        do {
            let deviceID = DeviceInstallationID.current()
            let response = try await client.activate(licenseKey: normalized, deviceID: deviceID)
            messageText = response.message

            if response.success {
                let defaults = UserDefaults.standard
                defaults.set(normalized, forKey: "greeg.license.key")
                defaults.set(deviceID, forKey: "greeg.license.device")
                defaults.set(true, forKey: "greeg.license.supabaseUnlocked")
                LicenseEntitlements.store(response.capabilities, expiresAt: response.expiresAt)
                didActivate = true
                onSuccess()
            }
        } catch {
            messageText = error.localizedDescription
        }
    }
}

enum SupabaseLicenseConfig {
    static let projectURL = URL(string: "https://oxtyyazqagmfhkgprpsp.supabase.co")!
    static let publishableKey = "sb_publishable_IEtNXoVHdutPKd4g_ej0MA_IF-yXUR8"
}

enum LicenseEntitlements {
    static let specialAssetIndexer = "special_assetindexer"

    private static let capabilitiesKey = "greeg.license.capabilities"
    private static let expiresAtKey = "greeg.license.expiresAt"

    static func store(_ capabilities: [String], expiresAt: String?, defaults: UserDefaults = .standard) {
        let normalized = capabilities
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        if let encoded = try? JSONEncoder().encode(Array(Set(normalized))) {
            defaults.set(encoded, forKey: capabilitiesKey)
        } else {
            defaults.removeObject(forKey: capabilitiesKey)
        }

        if let expiresAt, !expiresAt.isEmpty {
            defaults.set(expiresAt, forKey: expiresAtKey)
        } else {
            defaults.removeObject(forKey: expiresAtKey)
        }
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: capabilitiesKey)
        defaults.removeObject(forKey: expiresAtKey)
    }

    static func storedExpirationDate(defaults: UserDefaults = .standard) -> Date? {
        guard let value = defaults.string(forKey: expiresAtKey), !value.isEmpty else {
            return nil
        }

        return LicenseDateParser.date(from: value)
    }

    static func isExpiredLocally(now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        guard let expirationDate = storedExpirationDate(defaults: defaults) else {
            return false
        }

        return expirationDate <= now
    }

    static func has(_ capability: String, defaults: UserDefaults = .standard) -> Bool {
        guard let data = defaults.data(forKey: capabilitiesKey),
              let capabilities = try? JSONDecoder().decode([String].self, from: data) else {
            return false
        }

        return capabilities.contains(capability.lowercased())
    }
}

private struct SupabaseLicenseResponse: Decodable {
    let success: Bool
    let message: String
    let capabilities: [String]
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case capabilities
        case expiresAt = "expires_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decode(Bool.self, forKey: .success)) ?? false
        message = (try? container.decode(String.self, forKey: .message)) ?? "License check failed."
        capabilities = (try? container.decode([String].self, forKey: .capabilities)) ?? []
        expiresAt = try? container.decodeIfPresent(String.self, forKey: .expiresAt)
    }
}

private enum LicenseDateParser {
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let internetFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from value: String) -> Date? {
        fractionalFormatter.date(from: value) ?? internetFormatter.date(from: value)
    }
}

private struct SupabaseRPCError: Decodable {
    let message: String?
    let details: String?
    let hint: String?
    let code: String?
}

private enum SupabaseLicenseError: LocalizedError {
    case badURL
    case badResponse
    case server(String)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Could not prepare the Supabase connection."
        case .badResponse:
            return "Supabase did not return a valid response."
        case .server(let message):
            return message
        case .unreadable(let message):
            return message
        }
    }
}

private final class SupabaseLicenseClient {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func activate(licenseKey: String, deviceID: String) async throws -> SupabaseLicenseResponse {
        try await callRPC(name: "activate_license", licenseKey: licenseKey, deviceID: deviceID)
    }

    func check(licenseKey: String, deviceID: String) async throws -> SupabaseLicenseResponse {
        try await callRPC(name: "check_license", licenseKey: licenseKey, deviceID: deviceID)
    }

    private func callRPC(name: String, licenseKey: String, deviceID: String) async throws -> SupabaseLicenseResponse {
        var components = URLComponents(url: SupabaseLicenseConfig.projectURL, resolvingAgainstBaseURL: false)
        components?.path = "/rest/v1/rpc/\(name)"

        guard let url = components?.url else {
            throw SupabaseLicenseError.badURL
        }

        let extendedBody: [String: Any] = [
            "p_license_key": licenseKey,
            "p_device_id": deviceID,
            "p_device_model": AppInfo.displayMachineName,
            "p_ios_version": "\(AppInfo.osVersion) (\(AppInfo.osBuild))",
            "p_app_version": AppInfo.currentVersion
        ]
        let legacyBody: [String: Any] = [
            "p_license_key": licenseKey,
            "p_device_id": deviceID
        ]

        return try await sendRPCRequest(url: url, body: extendedBody, fallbackBody: legacyBody)
    }

    private func sendRPCRequest(url: URL, body: [String: Any], fallbackBody: [String: Any]? = nil) async throws -> SupabaseLicenseResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue(SupabaseLicenseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseLicenseConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseLicenseError.badResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let rpcError = try? decoder.decode(SupabaseRPCError.self, from: data) {
                if rpcError.isSchemaCacheMiss, let fallbackBody {
                    return try await sendRPCRequest(url: url, body: fallbackBody)
                }
                if let message = rpcError.message, !message.isEmpty {
                    throw SupabaseLicenseError.server(message)
                }
            }

            let raw = String(data: data, encoding: .utf8) ?? "Error HTTP \(httpResponse.statusCode)."
            throw SupabaseLicenseError.server(raw)
        }

        do {
            return try decoder.decode(SupabaseLicenseResponse.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "Respuesta vacia."
            throw SupabaseLicenseError.unreadable("Could not read the Supabase response: \(raw)")
        }
    }
}

private extension SupabaseRPCError {
    var isSchemaCacheMiss: Bool {
        if code == "PGRST202" { return true }
        let combined = [message, details, hint]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        return combined.contains("could not find the function")
            || combined.contains("schema cache")
            || combined.contains("perhaps you meant")
    }
}

enum DeviceInstallationID {
    private static let service = "com.apple.mobile.MobileHouseArrest.greeg-license"
    private static let account = "installation-id"
    private static let fallbackKey = "greeg.license.installationID"

    static func current(defaults: UserDefaults = .standard) -> String {
        if let existing = readFromKeychain(), !existing.isEmpty {
            defaults.set(existing, forKey: fallbackKey)
            return existing
        }

        if let fallback = defaults.string(forKey: fallbackKey), !fallback.isEmpty {
            _ = saveToKeychain(fallback)
            return fallback
        }

        let generated = "ios-\(UUID().uuidString.lowercased())"
        defaults.set(generated, forKey: fallbackKey)
        _ = saveToKeychain(generated)
        return generated
    }

    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private static func saveToKeychain(_ value: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var newItem = query
        attributes.forEach { newItem[$0.key] = $0.value }
        return SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess
    }
}

extension String {
    var normalizedLicenseKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }
}
