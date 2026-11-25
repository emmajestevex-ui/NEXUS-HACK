import SwiftUI
import UIKit

struct FullReferenceView: View {
    static var available: Bool {
        ["Selector", "FullBlue", "FullRed"].allSatisfy { UIImage(named: $0) != nil }
    }
    private enum Theme { case blue, red
        var art: String { self == .blue ? "FullBlue" : "FullRed" }
        var accent: Color { self == .blue ? .cyan : .red }
    }
    @State private var theme: Theme?
    @State private var section: String?
    var body: some View {
        GeometryReader { proxy in
            let ratio: CGFloat = theme == nil ? 1280.0/720 : 720.0/1280
            let w = min(proxy.size.width, proxy.size.height * ratio)
            let h = w / ratio
            ZStack {
                Color.black
                ZStack(alignment: .topLeading) {
                    Image(theme?.art ?? "Selector").resizable()
                        .frame(width: w, height: h).accessibilityHidden(true)
                    if let theme = theme {
                        let red = theme == .red
                        if CharacterViewer.available {
                            ZStack {
                                Color.black
                                RadialGradient(colors: [theme.accent.opacity(0.65), .black], center: .center, startRadius: 4, endRadius: w * 0.52)
                                Circle().stroke(theme.accent, lineWidth: 2).shadow(color: theme.accent, radius: 9).padding(12)
                                CharacterViewer(accent: red ? .red : .systemBlue)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .frame(width: w * 0.88, height: h * (red ? 0.30 : 0.255))
                            .position(x: w * 0.5, y: h * (red ? 0.265 : 0.296))
                            .allowsHitTesting(false)
                        }
                        hit("Salir", 0.65, 0.015, 0.16, 0.06, w, h) { self.theme = nil }
                        hit("Personaje", 0.035, 0.105, 0.93, red ? 0.33 : 0.345, w, h) { section = "Personaje" }
                        ForEach(Array(["Visuales", "Texturas", "Aimbots", "Combinado"].enumerated()), id: \.offset) { i, title in
                            hit(title, 0.035, (red ? 0.489 : 0.503) + Double(i) * (red ? 0.089 : 0.092), 0.93, 0.076, w, h) { section = title }
                        }
                        ForEach(Array(["Inicio", "Soporte", "Aimbots", "Skins", "Configurar"].enumerated()), id: \.offset) { i, title in
                            hit(title, 0.025 + Double(i) * 0.19, red ? 0.862 : 0.89, 0.19, 0.085, w, h) { if i != 0 { section = title } }
                        }
                    } else {
                        hit("Free Fire Normal", 0.025, 0.33, 0.45, 0.32, w, h) { theme = .blue }
                        hit("Free Fire Max", 0.53, 0.33, 0.45, 0.32, w, h) { theme = .red }
                    }
                }.frame(width: w, height: h)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: Binding(get: { section != nil }, set: { if !$0 { section = nil } })) {
            VStack(spacing: 24) {
                Capsule().fill(Color.secondary).frame(width: 36, height: 4).padding(.top, 12)
                Text(section ?? "").font(.largeTitle.bold())
                Text("Vista previa visual").foregroundStyle(.secondary)
                Text("Este apartado no modifica otras aplicaciones.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Volver") { section = nil }.buttonStyle(.borderedProminent).tint(theme?.accent ?? .cyan)
                Spacer()
            }.padding().frame(maxWidth: .infinity).background(Color.black).preferredColorScheme(.dark)
        }
    }
    private func hit(_ title: String, _ x: Double, _ y: Double, _ width: Double, _ height: Double, _ w: CGFloat, _ h: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) { Color.clear.contentShape(Rectangle()) }
            .buttonStyle(.plain)
            .frame(width: w * CGFloat(width), height: h * CGFloat(height))
            .position(x: w * CGFloat(x + width/2), y: h * CGFloat(y + height/2))
            .accessibilityLabel(title)
    }
}
