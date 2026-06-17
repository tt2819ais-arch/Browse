import SwiftUI

struct MenuView: View {
    let onBookmarks: () -> Void
    let onHistory: () -> Void
    let onSettings: () -> Void
    let onToggleBookmark: () -> Void
    let onNewTab: () -> Void
    let onShare: () -> Void
    let isBookmarked: Bool
    let canBookmark: Bool

    var body: some View {
        ZStack {
            SheetBackground()
            VStack(spacing: 14) {
                Capsule().fill(VoidColor.stroke).frame(width: 38, height: 4).padding(.top, 10)

                HStack(spacing: 12) {
                    menuTile(symbol: isBookmarked ? "star.fill" : "star",
                             label: isBookmarked ? "В закладках" : "В закладки",
                             tint: VoidColor.accent, enabled: canBookmark, action: onToggleBookmark)
                    menuTile(symbol: "plus.square.on.square", label: "Новая вкладка",
                             tint: VoidColor.textPrimary, action: onNewTab)
                    menuTile(symbol: "square.and.arrow.up", label: "Поделиться",
                             tint: VoidColor.textPrimary, enabled: canBookmark, action: onShare)
                }
                .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    row(symbol: "star", title: "Закладки", action: onBookmarks)
                    Divider().overlay(VoidColor.stroke)
                    row(symbol: "clock.arrow.circlepath", title: "История", action: onHistory)
                    Divider().overlay(VoidColor.stroke)
                    row(symbol: "gearshape", title: "Настройки", action: onSettings)
                }
                .background(RoundedRectangle(cornerRadius: 18).fill(VoidColor.card))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(VoidColor.stroke, lineWidth: 1))
                .padding(.horizontal, 16)

                Spacer()
            }
        }
    }

    private func menuTile(symbol: String, label: String, tint: Color, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(enabled ? tint : VoidColor.textTertiary)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(enabled ? VoidColor.textSecondary : VoidColor.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(RoundedRectangle(cornerRadius: 16).fill(VoidColor.card))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(VoidColor.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }

    private func row(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(VoidColor.accent)
                    .frame(width: 26)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(VoidColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VoidColor.textTertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.99))
    }
}
