#!/usr/bin/env python3
"""Aplica mejoras visuales, keys por categoria y acceso por contrasena a NEXUS-HACK.
No modifica otro repositorio ni publica ni ejecuta SQL. Crea respaldos fuera de Git.
"""
from __future__ import annotations
import argparse, os, pathlib, shutil, sys, datetime, json, re
ROOT = pathlib.Path(__file__).resolve().parent

def replace_one(content, old, new, name):
    if old == new:
        return content
    n=content.count(old)
    if n != 1:
        raise RuntimeError(f'{name}: se esperaba 1 coincidencia; hay {n}: {old[:90]!r}')
    return content.replace(old,new,1)

def replace_all(content, old, new, name, minimum=1):
    n=content.count(old)
    if n < minimum:
        raise RuntimeError(f'{name}: falta el texto {old[:85]!r}')
    return content.replace(old,new)

def verify_repo(repo):
    required=['ThreeOneOSFive/App.swift','ThreeOneOSFive/ContentView.swift','ThreeOneOSFive/helpers/ContentLicenseStore.swift', 'ThreeOneOSFive/helpers/RemoteContentSyncService.swift','ThreeOneOSFive/views/DesignSystem.swift','ThreeOneOSFive.xcodeproj/project.pbxproj','admin/app.js','admin/index.html','.git']
    absent=[x for x in required if not (repo/x).exists()]
    if absent:
        raise RuntimeError('No es una copia local completa de NEXUS-HACK; faltan: '+', '.join(absent))
    # Dejar de aplicar si se escogio otra app duplicada.
    if not (repo/'supabase/secure_patch_keys_setup.sql').exists():
        raise RuntimeError('No se encontro la migracion base de NEXUS-HACK')

def plan(repo):
    updated={}
    def edit(p,fn):
        target=repo/p
        src=target.read_text(encoding='utf-8-sig')
        result=fn(src)
        if result!=src: updated[p]=result.encode('utf-8')

    def app_mod(s):
        s=replace_one(s,'import AVFoundation\n','import AVFoundation\nimport WebKit\n','App.swift')
        start=s.index('private struct NexusLaunchExperience: View {')
        end=s.index('private struct LicenseCheckingView: View {',start)
        splash=r'''private struct NexusIntroWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        web.scrollView.backgroundColor = .black
        if let url = Bundle.main.url(forResource: "nexus_intro_animation", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct NexusLaunchExperience: View {
    let onFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didFinish = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if reduceMotion {
                VStack(spacing: 12) {
                    AppLogo(size: 112)
                    Text("NEXUS").font(.largeTitle.bold()).foregroundStyle(.white)
                }
            } else {
                NexusIntroWebView().ignoresSafeArea()
            }
        }
        .onAppear {
            // Recurso suministrado por el propietario, reproducido una sola vez.
            NexusAudioPlayer.shared.play(named: "nexus_intro")
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.6 : 4.35)) {
                guard !didFinish else { return }
                didFinish = true
                onFinished()
            }
        }
    }
}

'''
        s=s[:start]+splash+s[end:]
        s=s.replace('Text("NEXUS HACK")','Text("NEXUS")')
        return s
    edit('ThreeOneOSFive/App.swift', app_mod)

    def theme_mod(s):
        s=replace_one(s,'struct NexusBackground<Content: View>: View {',r'''/// Rayos discretos al fondo; no interceptan toques y respetan Reduce Motion.
private struct NexusStormBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            Canvas { context, size in
                let t = reduceMotion ? 0.0 : timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<7 {
                    let seed = Double(index)
                    let fall = (t * (14.0 + seed * 2.3) + seed * 151.0)
                        .truncatingRemainder(dividingBy: Double(max(size.height, 1)) + 190)
                    let top = fall - 160.0
                    let startX = Double(size.width) * (0.1 + seed * 0.13)
                    var bolt = Path()
                    for step in 0...7 {
                        let y = top + Double(step) * 30
                        let x = startX + sin(seed * 3.1 + Double(step) * 1.9 + t * 0.22) * 13
                        let point = CGPoint(x: x, y: y)
                        if step == 0 { bolt.move(to: point) }
                        else { bolt.addLine(to: point) }
                    }
                    context.stroke(
                        bolt,
                        with: .color(NexusTheme.blueBright.opacity(index.isMultiple(of: 2) ? 0.10 : 0.06)),
                        style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct NexusBackground<Content: View>: View {''','DesignSystem.swift')
        s=replace_one(s,'            content()\n        }\n    }\n}\n\nstruct NexusCard', '            NexusStormBackground()\n            content()\n        }\n    }\n}\n\nstruct NexusCard','DesignSystem.swift')
        s=replace_one(s,'if let icon = UIImage(named: "AppIcon60x60")','if let icon = UIImage(named: "NexusWolfLogo") ?? UIImage(named: "AppIcon60x60")','DesignSystem.swift')
        return s
    edit('ThreeOneOSFive/views/DesignSystem.swift',theme_mod)

    def content_mod(s):
        # Compatible with original: permissions are by category, not file.
        s=replace_all(s,'ContentLicenseStore.hasAccess(fileID: file.id)','ContentLicenseStore.hasAccess(category: file.category)','ContentView.swift')
        s=replace_one(s,'private struct ContentKeyUnlockView: View {','private struct ContentKeyUnlockView: View {','ContentView.swift') if False else s
        i=s.index('private struct ContentKeyUnlockView: View {')
        j=s.index('private func remotePatchErrorMessage(',i)
        view=s[i:j]
        view=replace_one(view,'    @State private var key = ""\n', '    @State private var key = ""\n    @State private var categoryPassword = ""\n','ContentKeyUnlockView')
        view=replace_one(view,'Text(file.name).font(.headline)','Text("Categoría: \\(file.category)").font(.headline)','ContentKeyUnlockView')
        view=replace_one(view,'Text("Este contenido está protegido. Precio de referencia:', 'Text("La key desbloquea todos los patches de esta categoría. Precio de referencia:','ContentKeyUnlockView')
        view=replace_one(view,'Section("Key de acceso") {','Section("Key de categoría") {','ContentKeyUnlockView')
        view=replace_one(view,'                    if !message.isEmpty {','''                    SecureField("Contraseña de la categoría", text: $categoryPassword)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    Text("Esta contraseña la configura el administrador y es diferente de la key.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !message.isEmpty {''','ContentKeyUnlockView')
        view=replace_one(view,'Text("Desbloquear patch")','Text("Desbloquear categoría")','ContentKeyUnlockView')
        view=replace_one(view,'ContentLicenseStore.activate(key: key, fileID: file.id)','ContentLicenseStore.activate(key: key, fileID: file.id, category: file.category, password: categoryPassword)','ContentKeyUnlockView')
        s=s[:i]+view+s[j:]
        s=s.replace('NEXUS HACK [REMOTE]', 'NEXUS [REMOTE]')
        return s
    edit('ThreeOneOSFive/ContentView.swift',content_mod)

    def license_mod(s):
        replacement='''import Foundation
import Security

/// Access is per category and lasts only during this app process.
/// Avoid persisting a naked boolean that survives a revoke/restart.
enum ContentLicenseStore {
    private static let guardLock = NSLock()
    private static var unlockedCategories = Set<String>()

    static func hasAccess(category: String) -> Bool {
        guardLock.lock()
        defer { guardLock.unlock() }
        return unlockedCategories.contains(category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func grant(category: String) {
        guardLock.lock()
        unlockedCategories.insert(category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        guardLock.unlock()
    }

    static func activate(key: String, fileID: String, category: String, password: String) async throws -> String {
        guard let contentID = UUID(uuidString: fileID), !category.isEmpty else {
            throw ContentLicenseError.invalidFile
        }
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { throw ContentLicenseError.invalidKey }
        var components = URLComponents(url: SupabaseLicenseConfig.projectURL, resolvingAgainstBaseURL: false)
        components?.path = "/rest/v1/rpc/activate_nexus_category"
        guard let url = components?.url else { throw ContentLicenseError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue(SupabaseLicenseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \\(SupabaseLicenseConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "p_license_key": normalized,
            "p_device_id": UserDefaults.standard.string(forKey: "greeg.license.device") ?? "",
            "p_content_id": contentID.uuidString,
            "p_password": password
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ContentLicenseError.server("No se pudo validar la categoría. Ejecuta primero el SQL V2 en Supabase.")
        }
        let result = try JSONDecoder().decode(ContentLicenseResponse.self, from: data)
        guard result.success else { throw ContentLicenseError.server(result.message) }
        grant(category: category)
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
'''
        assert 'enum ContentLicenseStore' in s
        return replacement
    edit('ThreeOneOSFive/helpers/ContentLicenseStore.swift',license_mod)

    def sync_mod(s):
        s=replace_all(s,'ContentLicenseStore.hasAccess(fileID: file.id)','ContentLicenseStore.hasAccess(category: file.category)','RemoteContentSyncService.swift',minimum=4)
        s=s.replace('Este archivo requiere una key individual.','Esta categoría requiere una key y contraseña.')
        return s
    def enforce_all_remote_patch_locks(source):
        old = 'requiresKey = (try? container.decode(Bool.self, forKey: .requiresKey)) ?? true'
        new = 'requiresKey = contentType != "text" // Bloqueo por categoría de todos los patches, incluso los antiguos'
        return replace_one(source, old, new, 'RemoteContentSyncService.swift')
    original_sync_mod = sync_mod
    def sync_mod(source):
        return enforce_all_remote_patch_locks(original_sync_mod(source))
    edit('ThreeOneOSFive/helpers/RemoteContentSyncService.swift',sync_mod)

    def admin_html(s):
        s=s.replace('NEXUS HACK','NEXUS')
        s=replace_one(s,'Proteger este archivo con key individual', 'Requerir key y contraseña de su categoría','admin/index.html')
        s=replace_one(s,'La app no descargará ni aplicará el archivo hasta validar su key en el servidor.', 'Una key desbloquea todos los archivos de esta categoría. Las categorías requieren contraseña configurada desde este panel.','admin/index.html')
        s=replace_one(s,'<option value="">Key general / sin patch específico</option>', '<option value="">Selecciona una categoría</option>','admin/index.html')
        s=replace_one(s,'La key quedará limitada al patch elegido. Precio de referencia: $15.00 USD.', 'La key desbloqueará todos los patches de la categoría elegida. Precio de referencia: $15.00 USD.','admin/index.html')
        slot='<div id="categoryList" class="categoryList"></div>'
        extra='''<div class="categoryPasswordBox">
                <h3>Contraseña de acceso por categoría</h3>
                <p class="muted">Obligatoria para cada categoría con patches; se guarda como hash en Supabase, nunca en la página ni en el manifiesto.</p>
                <label>Categoría<select id="passwordCategorySelect"></select></label>
                <label>Nueva contraseña (mínimo 12 caracteres)<input id="categoryAccessPassword" type="password" minlength="12" maxlength="128" autocomplete="new-password" /></label>
                <button id="saveCategoryPassword" type="button" class="primary">Guardar contraseña de categoría</button>
                <p id="categoryPasswordStatus" class="notice" role="status"></p>
              </div>'''
        s=replace_one(s,slot,slot+'\n'+extra,'admin/index.html')
        return s
    edit('admin/index.html',admin_html)

    def admin_js(s):
        s=s.replace('NEXUS HACK','NEXUS')
        s=replace_one(s,'const capabilities = els.specialAssetIndexerInput.checked ? ["special_assetindexer"] : [];\n  if (els.keyContentInput.value) capabilities.push(`content:${els.keyContentInput.value.toLowerCase()}`);',
        '''const categoryID = els.keyContentInput.value.trim().toLowerCase();
  if (!categoryID) {
    els.keysStatusText.textContent = "Selecciona la categoría que quieres desbloquear.";
    return;
  }
  const capabilities = els.specialAssetIndexerInput.checked ? ["special_assetindexer"] : [];
  capabilities.push(`category:${categoryID}`);''','admin/app.js')
        i=s.index('function refreshKeyContentOptions() {')
        j=s.index('async function copyGeneratedKeys()',i)
        s=s[:i]+'''function refreshKeyContentOptions() {
  if (!els.keyContentInput) return;
  const selected = els.keyContentInput.value;
  const categories = allCategoryChoices().filter(cat => categoryContentType(cat) === "patch");
  els.keyContentInput.replaceChildren(new Option("Selecciona categoría", ""));
  for (const cat of categories) {
    els.keyContentInput.add(new Option(categoryPath(cat.id, allCategoryChoices()), cat.id));
  }
  if (categories.some(cat => cat.id === selected)) els.keyContentInput.value = selected;
  const pwdSelect = document.querySelector("#passwordCategorySelect");
  if (pwdSelect) {
    const old = pwdSelect.value;
    pwdSelect.replaceChildren(new Option("Selecciona categoría", ""));
    for (const cat of categories) pwdSelect.add(new Option(categoryPath(cat.id, allCategoryChoices()), cat.id));
    if (categories.some(cat => cat.id === old)) pwdSelect.value = old;
  }
}

async function saveNexusCategoryPassword() {
  const categoryID = document.querySelector("#passwordCategorySelect")?.value.trim().toLowerCase();
  const passwordInput = document.querySelector("#categoryAccessPassword");
  const status = document.querySelector("#categoryPasswordStatus");
  const password = passwordInput?.value || "";
  if (!categoryID || password.length < 12) {
    if (status) status.textContent = "Selecciona una categoría y escribe al menos 12 caracteres.";
    return;
  }
  if (status) status.textContent = "Guardando de forma segura...";
  const { data, error } = await supabaseClient.rpc("admin_set_nexus_category_password", {
    p_category_id: categoryID, p_password: password
  });
  if (passwordInput) passwordInput.value = "";
  if (status) status.textContent = error ? adminErrorMessage(error) : (data?.message || "Contraseña actualizada. No se guardó en el navegador.");
}

''' +s[j:]
        # Add listener to existing initialization; not leaking password to localStorage
        s=replace_one(s,'  els.keyForm.addEventListener("submit", createKeys);',
         '  els.keyForm.addEventListener("submit", createKeys);\n  document.querySelector("#saveCategoryPassword")?.addEventListener("click", saveNexusCategoryPassword);',
         'admin/app.js')
        s=replace_one(s,'p_requires_key: els.requiresKeyInput.checked,','p_requires_key: true,','admin/app.js')
        s=replace_one(s,'function renderCategoryEditor() {','function renderCategoryEditor() {\n  refreshKeyContentOptions();','admin/app.js')
        return s
    edit('admin/app.js',admin_js)

    def pbx_mod(s):
        s=replace_all(s,'INFOPLIST_KEY_CFBundleDisplayName = "NEXUS HACK";','INFOPLIST_KEY_CFBundleDisplayName = "NEXUS";','project.pbxproj',minimum=2)
        s=replace_all(s,'PRODUCT_NAME = NexusHack;','PRODUCT_NAME = NEXUS;','project.pbxproj',minimum=2)
        # Register html offline resource (this is a resource file, not Swift source).
        s=replace_one(s,'3105N200 /* nexus_intro.mp3 in Resources */ = {isa = PBXBuildFile; fileRef = 3105N100; };',
          '3105N200 /* nexus_intro.mp3 in Resources */ = {isa = PBXBuildFile; fileRef = 3105N100; };\n\t\t3105N203 /* nexus_intro_animation.html in Resources */ = {isa = PBXBuildFile; fileRef = 3105N103; };','project.pbxproj')
        s=replace_one(s,'3105N100 /* nexus_intro.mp3 */ = {isa = PBXFileReference; lastKnownFileType = audio.mp3; path = nexus_intro.mp3; sourceTree = "<group>"; };',
           '3105N100 /* nexus_intro.mp3 */ = {isa = PBXFileReference; lastKnownFileType = audio.mp3; path = nexus_intro.mp3; sourceTree = "<group>"; };\n\t\t3105N103 /* nexus_intro_animation.html */ = {isa = PBXFileReference; lastKnownFileType = text.html; path = nexus_intro_animation.html; sourceTree = "<group>"; };','project.pbxproj')
        s=replace_one(s,'3105N100 /* nexus_intro.mp3 */,','3105N100 /* nexus_intro.mp3 */,\n\t\t\t\t3105N103 /* nexus_intro_animation.html */,','project.pbxproj')
        s=replace_one(s,'\t\t\t\t3105N200,','\t\t\t\t3105N200,\n\t\t\t\t3105N203,','project.pbxproj')
        return s
    edit('ThreeOneOSFive.xcodeproj/project.pbxproj',pbx_mod)
    def plist_mod(s):
        s=re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>).*?(</string>)',r'\1NEXUS\2',s)
        s=re.sub(r'(<key>CFBundleName</key>\s*<string>).*?(</string>)',r'\1NEXUS\2',s)
        return s
    edit('ThreeOneOSFive/Info.plist',plist_mod)
    # Binary and new resources, preserving original assets as backup.
    for path,file in {
        'ThreeOneOSFive/nexus_intro.mp3':'assets/nexus_intro.mp3',
        'ThreeOneOSFive/nexus_intro_animation.html':'assets/nexus_intro_animation.html',
        'ThreeOneOSFive/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png':'assets/nexus_icon_1024.png',
        'ThreeOneOSFive/Assets.xcassets/NexusWolfLogo.imageset/NexusWolfLogo.png':'assets/nexus_wolf_1024.png',
    }.items():
        updated[path]=(ROOT/file).read_bytes()
    updated['ThreeOneOSFive/Assets.xcassets/NexusWolfLogo.imageset/Contents.json'] = (json.dumps({
        'images':[{'filename':'NexusWolfLogo.png','idiom':'universal'}],
        'info':{'author':'xcode','version':1}},indent=2)+'\n').encode()
    return updated

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--repo',type=pathlib.Path)
    parser.add_argument('--dry-run',action='store_true')
    args=parser.parse_args()
    repo=args.repo
    if not repo:
        candidates=[
            pathlib.Path(os.environ.get('LOCALAPPDATA',''))/'MisReposGitHub'/'NEXUS-HACK',
            pathlib.Path.home()/'Documents'/'GitHub'/'NEXUS-HACK',
            pathlib.Path.home()/'Downloads'/'NEXUS-HACK',
        ]
        repo=next((p for p in candidates if (p/'.git').exists()),None)
        if repo is None:
            raise RuntimeError('No encontré NEXUS-HACK. Ejecuta --repo "RUTA_DE_TU_CLON_DE_NEXUS-HACK"')
    repo=repo.resolve()
    verify_repo(repo)
    changes=plan(repo)
    print(f'Repositorio: {repo}\nArchivos preparados: {len(changes)}')
    for p in changes: print('  -',p)
    if args.dry_run: return
    dest=(pathlib.Path(os.environ.get('LOCALAPPDATA',str(pathlib.Path.home())))/'NexusBackups'/datetime.datetime.now().strftime('%Y%m%d_%H%M%S'))
    dest.mkdir(parents=True,exist_ok=True)
    for p in changes:
        target=repo/p
        if target.is_file():
            backup=dest/p
            backup.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(target,backup)
    for p,data in changes.items():
        target=repo/p
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(data)
    print(f'OK: actualizado. Respaldos: {dest}')
    print('Siguiente: ejecutar SQL primero en el Supabase NEXUS, commit/push y compilar IPA en GitHub Actions.')

if __name__=='__main__':
    try: main()
    except Exception as exc:
        print('ERROR:',exc,file=sys.stderr)
        sys.exit(1)
