import SwiftUI
import UIKit

@main struct NexusApp: App {
    var body: some Scene { WindowGroup { Group { if FullReferenceView.available { FullReferenceView() } else { NexusHome() } }.preferredColorScheme(.dark) } }
}

private enum NexusTheme: String, CaseIterable {
    case blue, red
    var title: String { self == .blue ? "FREE FIRE NORMAL" : "FREE FIRE MAX" }
    var accent: Color { self == .blue ? Color(red: 0, green: 0.48, blue: 1) : .red }
    var portrait: String { self == .blue ? "Blue" : "Red" }
}
private enum NexusSection: String, CaseIterable, Identifiable {
    case visuales = "Visuales", texturas = "Texturas", aimbots = "Aimbots", combinado = "Combinado", soporte = "Soporte", configurar = "Configurar", personaje = "Personaje"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .visuales: return "eye.fill"
        case .texturas: return "tshirt.fill"
        case .aimbots: return "scope"
        case .combinado: return "square.grid.2x2.fill"
        case .soporte: return "star.fill"
        case .configurar, .personaje: return "cube.fill"
        }
    }
}
struct NexusHome: View {
    @State private var theme: NexusTheme?
    @State private var section: NexusSection?
    var body: some View {
        ZStack {
            EnergyBackdrop(accent: theme?.accent ?? .blue)
            if let theme = theme {
                dashboard(theme)
            } else {
                selector
            }
        }
        .foregroundStyle(.white)
        .animation(.easeInOut(duration: 0.2), value: theme)
        .sheet(item: $section) { item in
            SectionScreen(section: item, accent: theme?.accent ?? .blue)
                .preferredColorScheme(.dark)
        }
    }
    private var selector: some View {
        GeometryReader { geo in
            VStack(spacing: 24) {
                Spacer()
                if geo.size.width > 550 {
                    HStack(spacing: 24) { ForEach(NexusTheme.allCases, id: \.self) { choice in choiceButton(choice) } }
                } else {
                    HStack(spacing: 12) { ForEach(NexusTheme.allCases, id: \.self) { choice in choiceButton(choice) } }
                }
                Spacer()
            }.padding(12).frame(maxWidth: .infinity)
        }
        .background(Color.black)
    }
    private func choiceButton(_ choice: NexusTheme) -> some View {
        Button { theme = choice } label: {
            Text(choice == .blue ? "FREE FIRE\nNORMAL" : "FREE FIRE\nMAX")
                .font(.system(size: 24, weight: .black, design: .default))
                .minimumScaleFactor(0.45)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.vertical, 25).padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .overlay(Octagon().stroke(choice.accent, lineWidth: 4).shadow(color: choice.accent, radius: 10))
                .overlay(Octagon().inset(by: 7).stroke(choice.accent.opacity(0.8), lineWidth: 1))
        }.buttonStyle(.plain)
        .accessibilityLabel(choice.title)
    }
    private func dashboard(_ theme: NexusTheme) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled").font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white).shadow(color: theme.accent, radius: 9)
                Rectangle().fill(.white).frame(width: 2, height: 45)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nexus Hack").font(.system(size: 24, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.65)
                    Text("Personaliza tu experiencia").font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 2)
                Button { section = nil; self.theme = nil } label: { chip("Salir", theme.accent) }.buttonStyle(.plain)
                chip("● EN VIVO", theme.accent)
            }.padding(.horizontal, 12)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    Button { section = .personaje } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("VISUAL • PERSONAJE").font(.caption.bold())
                            Text("VER OPCIONES DE PERSONAJE").font(.subheadline.bold())
                            ZStack(alignment: .bottomTrailing) {
                                ZStack {
                                    Circle().stroke(theme.accent, lineWidth: 3).blur(radius: 4).padding(20)
                                    Circle().stroke(theme.accent.opacity(0.8), lineWidth: 2).padding(24)
                                    if CharacterViewer.available {
                                        CharacterViewer(accent: theme == .blue ? .systemBlue : .red)
                                            .frame(height: 210).allowsHitTesting(false)
                                    } else {
                                        Image(theme.portrait).resizable().scaledToFit().frame(maxHeight: 210).clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                }.frame(maxWidth: .infinity).frame(height: 214)
                                Image(systemName: "cube.fill").font(.title2).padding(12).background(.black, in: Circle()).overlay(Circle().stroke(.white, lineWidth: 1.5)).padding(7)
                            }
                        }.padding(12).modifier(NeonFrame(accent: theme.accent))
                    }.buttonStyle(.plain)
                    HStack(spacing: 8) {
                        Capsule().fill(theme.accent).frame(width: 5, height: 19)
                        Text("ARCHIVOS").font(.headline.bold())
                    }
                    ForEach([NexusSection.visuales, .texturas, .aimbots, .combinado]) { item in
                        Button { section = item } label: {
                            HStack(spacing: 14) {
                                Image(systemName: item.icon).font(.system(size: 29, weight: .semibold))
                                    .frame(width: 48, height: 48)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: 2))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.rawValue).font(.title3.bold())
                                    Text("Abrir apartado").font(.subheadline)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.title3.bold())
                            }.padding(10).modifier(NeonFrame(accent: theme.accent))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 12).padding(.vertical, 5)
            }
            HStack(spacing: 0) {
                tab("Inicio", "house.fill", theme.accent, active: true) { section = nil }
                tab("Soporte", "star.fill", theme.accent) { section = .soporte }
                tab("Aimbots", "scope", theme.accent) { section = .aimbots }
                tab("Skins", "tshirt.fill", theme.accent) { section = .texturas }
                tab("Configurar", "cube.fill", theme.accent) { section = .configurar }
            }.padding(6).modifier(NeonFrame(accent: theme.accent)).padding(.horizontal, 12)
        }.padding(.vertical, 6)
    }
    private func chip(_ title: String, _ accent: Color) -> some View {
        Text(title).font(.system(size: 11, weight: .bold)).lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 9)
            .background(Color.black, in: Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: 1.4))
            .shadow(color: accent, radius: 4)
    }
    private func tab(_ title: String, _ symbol: String, _ accent: Color, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 22, weight: .bold))
                Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }.frame(maxWidth: .infinity).frame(height: 48)
             .background(active ? accent.opacity(0.35) : .clear, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}
private struct SectionScreen: View {
    let section: NexusSection
    let accent: Color
    @Environment(\.dismiss) private var dismiss
    @State private var preview = false
    var body: some View {
        ZStack {
            EnergyBackdrop(accent: accent)
            VStack(spacing: 20) {
                HStack {
                    Button { dismiss() } label: { Label("Volver", systemImage: "chevron.left") }
                    Spacer()
                }.padding()
                Image(systemName: section.icon).font(.system(size: 52)).shadow(color: accent, radius: 10)
                Text(section.rawValue).font(.largeTitle.bold())
                Text("Vista previa de interfaz").foregroundStyle(.secondary)
                Toggle("Vista previa visual", isOn: $preview).tint(accent).padding().modifier(NeonFrame(accent: accent))
                if preview {
                    Text("Vista previa activada").foregroundStyle(.white).padding().modifier(NeonFrame(accent: accent))
                }
                Spacer()
            }.padding()
        }.foregroundStyle(.white)
    }
}
private struct NeonFrame: ViewModifier {
    let accent: Color
    func body(content: Content) -> some View {
        content.background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(accent, lineWidth: 3).shadow(color: accent, radius: 6))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.8), lineWidth: 0.7))
    }
}
private struct EnergyBackdrop: View {
    let accent: Color
    var body: some View {
        GeometryReader { g in
            ZStack {
                Color.black
                RadialGradient(colors: [accent.opacity(0.4), .black], center: .center, startRadius: 12, endRadius: max(g.size.width, g.size.height) * 0.7)
                ForEach(0..<9) { i in
                    Ellipse().stroke(accent.opacity(0.17), lineWidth: 2)
                        .frame(width: g.size.width * (0.55 + CGFloat(i) * 0.12), height: g.size.height * 0.36)
                        .rotationEffect(.degrees(Double(i) * 20 - 55))
                        .blur(radius: i.isMultiple(of: 2) ? 1 : 4)
                }
                Canvas { context, size in
                    for i in 0..<36 {
                        let x = CGFloat((i * 91 + 17) % 1000) / 1000 * size.width
                        let y = CGFloat((i * 173 + 23) % 1000) / 1000 * size.height
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(0.38)))
                    }
                }
            }
        }.ignoresSafeArea()
    }
}
private struct Octagon: InsettableShape {
    var insetAmount: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let c: CGFloat = min(16, min(r.width, r.height) / 4)
        var p = Path()
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - c))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.closeSubpath()
        return p
    }
    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self; copy.insetAmount += amount; return copy
    }
}
