import SwiftUI
import UIKit

enum NexusTheme {
    static let background = Color.black
    static let surface = Color(uiColor: UIColor(red: 0.055, green: 0.055, blue: 0.067, alpha: 1))
    static let elevatedSurface = Color(uiColor: UIColor(red: 0.086, green: 0.086, blue: 0.102, alpha: 1))
    static let border = Color.white.opacity(0.14)
    static let secondaryText = Color(uiColor: UIColor(red: 0.60, green: 0.60, blue: 0.64, alpha: 1))
    static let tertiaryText = Color(uiColor: UIColor(red: 0.36, green: 0.36, blue: 0.40, alpha: 1))
    static let blue = Color(uiColor: UIColor(red: 0.039, green: 0.518, blue: 1.0, alpha: 1))
    static let blueBright = Color(uiColor: UIColor(red: 0.35, green: 0.66, blue: 1.0, alpha: 1))
    static let success = Color(uiColor: UIColor(red: 0.196, green: 0.843, blue: 0.294, alpha: 1))
    static let danger = Color(uiColor: UIColor(red: 1.0, green: 0.271, blue: 0.227, alpha: 1))
    static let cardRadius: CGFloat = 22
    static let rowRadius: CGFloat = 18
    static let contentPadding: CGFloat = 16
}

enum NexusMotionPolicy {
    static func animation(reduceMotion: Bool, normal: Animation = NexusMotion.interaction) -> Animation? {
        reduceMotion ? nil : normal
    }
}

enum NexusHaptics {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

/// Relámpagos con trazos fractales irregulares, bifurcaciones orgánicas,
/// destellos breves de distinta intensidad y cuatro capas de luz.
/// Los rayos son eventos temporales, NO líneas que se deslizan por la pantalla.
/// Se inmovilizan y atenúan al activar «Reducir movimiento» en iOS.
private struct NexusStormBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func noise(_ seed: Double) -> Double {
        let raw = sin(seed * 127.1 + 43.82) * 43758.5453123
        return raw - floor(raw)
    }

    private func makePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func paint(_ path: Path, context: GraphicsContext, intensity: Double, isBranch: Bool) {
        let alpha = max(0.0, min(intensity, 1.0))
        let outerWidth: CGFloat = isBranch ? 10 : 24
        let glowWidth: CGFloat = isBranch ? 5 : 10
        let coreWidth: CGFloat = isBranch ? 0.65 : 1.15
        let join: CGLineJoin = .round

        context.stroke(path,
            with: .color(NexusTheme.blue.opacity(alpha * 0.11)),
            style: StrokeStyle(lineWidth: outerWidth, lineCap: .round, lineJoin: join))
        context.stroke(path,
            with: .color(NexusTheme.blueBright.opacity(alpha * 0.28)),
            style: StrokeStyle(lineWidth: glowWidth, lineCap: .round, lineJoin: join))
        context.stroke(path,
            with: .color(Color(red: 0.47, green: 0.77, blue: 1.0).opacity(alpha * 0.64)),
            style: StrokeStyle(lineWidth: isBranch ? 1.5 : 2.7, lineCap: .round, lineJoin: join))
        context.stroke(path,
            with: .color(Color(red: 0.90, green: 0.97, blue: 1.0).opacity(alpha * 0.92)),
            style: StrokeStyle(lineWidth: coreWidth, lineCap: .round, lineJoin: join))
    }

    private func strike(context: GraphicsContext, width: Double, height: Double, time: Double, index: Int) {
        let i = Double(index)
        let interval = 3.7 + i * 0.87
        let cycle = (time + i * 2.71) / interval
        let event = floor(cycle)
        let age = (cycle - event) * interval

        // A lightning flash lasts only a fraction of a second; sometimes
        // it fires a weaker echo. Most frames show a dark, clean background.
        let strength: Double
        if reduceMotion {
            strength = index == 1 ? 0.045 : 0
        } else if age < 0.36 {
            let firstFlash = exp(-age * 28.0)
            let secondFlash = age > 0.10 ? 0.48 * exp(-(age - 0.10) * 27.0) : 0
            strength = min(0.90, (0.54 + noise(i * 9.17) * 0.29) * (firstFlash + secondFlash))
        } else {
            return
        }

        if strength <= 0.012 { return }

        let originX = width * (0.12 + noise(i * 9.1) * 0.76)
        let originY = height * (0.06 + noise(i * 7.3) * 0.25)
        let length = height * (0.49 + noise(i * 2.9) * 0.36)
        let drift = width * (noise(i * 13.1 + event * 0.71) - 0.5) * 0.45

        var mainPoints: [CGPoint] = []
        var wander = 0.0
        for step in 0...30 {
            let fraction = Double(step) / 30.0
            let jitter = (noise(Double(step) * 2.49 + i * 91.7 + event * 4.33) - 0.5) * 44
            wander = max(-62, min(62, wander * 0.68 + jitter))
            let currentX = originX + drift * fraction + wander
            let currentY = originY + length * fraction
            mainPoints.append(CGPoint(x: currentX, y: currentY))
        }

        paint(makePath(mainPoints), context: context, intensity: strength, isBranch: false)

        // Forks start ON the main channel and diverge at unequal angles,
        // rather than appearing as independent vertical sticks.
        for (branchIndex, originStep) in [8, 15, 23].enumerated() {
            let j = Double(branchIndex)
            let start = mainPoints[originStep]
            var branchPoints: [CGPoint] = [start]
            var x = Double(start.x)
            var y = Double(start.y)
            let direction = noise(i * 17.9 + j * 13.0 + event * 0.17) > 0.5 ? 1.0 : -1.0
            for step in 1...8 {
                let variation = noise(Double(step) * 3.19 + i * 13.7 + j * 47.1 + event)
                x += direction * (4.0 + variation * 8.5)
                y += 8.0 + noise(Double(step) * 7.9 + j * 2.3 + event) * 9.0
                branchPoints.append(CGPoint(x: x, y: y))
            }
            paint(makePath(branchPoints), context: context,
                  intensity: strength * (0.46 + noise(j + i) * 0.16), isBranch: true)
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 : 1.0 / 30.0)) { timeline in
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                let timestamp = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let width = max(1, Double(size.width))
                let height = max(1, Double(size.height))
                for index in 0..<5 {
                    strike(context: context, width: width, height: height,
                           time: timestamp, index: index)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct NexusBackground<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            NexusTheme.background
                .ignoresSafeArea()

            RadialGradient(
                colors: [NexusTheme.blue.opacity(0.085), .clear],
                center: UnitPoint(x: 0.08, y: 0.02),
                startRadius: 10,
                endRadius: 360
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            NexusStormBackground()
            content()
        }
    }
}

struct NexusCard<Content: View>: View {
    let style: Style
    @ViewBuilder let content: () -> Content

    enum Style {
        case solid
        case elevated

        var fill: Color {
            switch self {
            case .solid: return NexusTheme.surface
            case .elevated: return NexusTheme.elevatedSurface
            }
        }
    }

    init(style: Style = .solid, @ViewBuilder content: @escaping () -> Content) {
        self.style = style
        self.content = content
    }

    var body: some View {
        content()
            .padding(NexusTheme.contentPadding)
            .background(
                RoundedRectangle(cornerRadius: NexusTheme.cardRadius, style: .continuous)
                    .fill(style.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NexusTheme.cardRadius, style: .continuous)
                    .stroke(NexusTheme.border, lineWidth: 1)
            )
    }
}

struct NexusIconTile: View {
    let systemName: String
    var tint: Color = NexusTheme.blue
    var size: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(tint.opacity(0.14))
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.43, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct NexusBadge: View {
    let title: String
    var tint: Color = NexusTheme.blue

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold).monospaced())
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.34), lineWidth: 0.8))
    }
}

struct NexusStatusDot: View {
    let isActive: Bool
    var tint: Color = NexusTheme.success
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(isPulsing ? 0.05 : 0.18))
                .frame(width: isPulsing ? 24 : 12, height: isPulsing ? 24 : 12)
            Circle()
                .fill(isActive ? tint : NexusTheme.tertiaryText)
                .frame(width: 8, height: 8)
        }
        .frame(width: 24, height: 24)
        .onAppear {
            guard isActive, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
        .accessibilityLabel(isActive ? "Activo" : "Inactivo")
    }
}

enum NexusMotion {
    static let entrance = Animation.spring(response: 0.52, dampingFraction: 0.86)
    static let interaction = Animation.easeOut(duration: 0.18)
}

struct NexusEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || isVisible ? 1 : 0)
            .offset(y: reduceMotion || isVisible ? 0 : 14)
            .scaleEffect(reduceMotion || isVisible ? 1 : 0.98)
            .onAppear {
                guard !reduceMotion else {
                    isVisible = true
                    return
                }
                let delay = min(Double(index) * 0.045, 0.28)
                withAnimation(NexusMotion.entrance.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

struct NexusPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(NexusMotion.interaction, value: configuration.isPressed)
    }
}

extension View {
    func nexusEntrance(index: Int = 0) -> some View {
        modifier(NexusEntranceModifier(index: index))
    }
}

enum AppTheme {
    static let accent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.20, green: 0.58, blue: 0.95, alpha: 1.00)
                : UIColor(red: 0.08, green: 0.33, blue: 0.68, alpha: 1.00)
        }
    )
    static let pageBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.035, green: 0.047, blue: 0.065, alpha: 1)
            : UIColor(red: 0.96, green: 0.975, blue: 0.995, alpha: 1)
    })
    static let consoleBackground = Color(uiColor: .secondarySystemBackground)
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
    static let contentCardCornerRadius: CGFloat = 20
    static let contentCardInset: CGFloat = 16
    static let contentCardPadding: CGFloat = 16
}

struct AppCardBorder: View {
    var body: some View {
        RoundedRectangle(
            cornerRadius: AppTheme.contentCardCornerRadius,
            style: .continuous
        )
        .strokeBorder(
            Color(uiColor: .separator).opacity(0.22),
            lineWidth: 0.5
        )
        .accessibilityHidden(true)
    }
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 36)
        .background(
            Color(uiColor: .secondarySystemFill),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "NexusWolfLogo") ?? UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}
