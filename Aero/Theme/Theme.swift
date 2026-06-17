import SwiftUI
import UIKit

// MARK: - Aero palette (clean, modern, adaptive light/dark)
enum AeroColor {
    /// Build an adaptive color from light & dark RGBA tuples.
    static func dynamic(light: (Double, Double, Double, Double),
                        dark: (Double, Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
    }

    static let accent = Color(red: 0.145, green: 0.388, blue: 0.922)      // #2563EB
    static let accentSoft = Color(red: 0.145, green: 0.388, blue: 0.922).opacity(0.12)
    static let danger = Color(red: 0.90, green: 0.30, blue: 0.30)
    static let success = Color(red: 0.20, green: 0.72, blue: 0.45)

    static let bg = dynamic(light: (1, 1, 1, 1), dark: (0.07, 0.07, 0.078, 1))
    static let surface = dynamic(light: (0.96, 0.965, 0.975, 1), dark: (0.12, 0.12, 0.13, 1))
    static let card = dynamic(light: (1, 1, 1, 1), dark: (0.145, 0.145, 0.155, 1))
    static let field = dynamic(light: (0.93, 0.937, 0.95, 1), dark: (0.17, 0.17, 0.185, 1))
    static let stroke = dynamic(light: (0, 0, 0, 0.07), dark: (1, 1, 1, 0.09))
    static let textPrimary = dynamic(light: (0.08, 0.08, 0.10, 1), dark: (0.96, 0.96, 0.98, 1))
    static let textSecondary = dynamic(light: (0.36, 0.37, 0.40, 1), dark: (0.62, 0.63, 0.66, 1))
    static let textTertiary = dynamic(light: (0.60, 0.61, 0.64, 1), dark: (0.42, 0.43, 0.46, 1))
}

// MARK: - Smooth animation presets
enum AeroAnim {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.86)
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.85)
    static let press = Animation.spring(response: 0.28, dampingFraction: 0.7)
}

// MARK: - Card surface
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    var radius: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AeroColor.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(AeroColor.stroke, lineWidth: 1)
            )
    }
}

// MARK: - Pressable button style (smooth spring)
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.92
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(AeroAnim.press, value: configuration.isPressed)
    }
}

// MARK: - Minimal round icon button
struct IconButton: View {
    let symbol: String
    var size: CGFloat = 19
    var weight: Font.Weight = .medium
    var enabled: Bool = true
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(enabled ? (tint ?? AeroColor.textPrimary) : AeroColor.textTertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }
}

// MARK: - Haptics
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func rigid() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
