import SwiftUI

struct MenuView: View {
    let onBookmarks: () -> Void
    let onHistory: () -> Void
    let onSettings: () -> Void
    let onToggleBookmark: () -> Void
    let onNewTab: () -> Void
    let onShare: () -> Void
    let onFind: () -> Void
    let onReportAd: () -> Void
    let onToggleIncognito: () -> Void
    let isIncognito: Bool
    let isBookmarked: Bool
    let canBookmark: Bool
    let canFind: Bool
    let canReport: Bool

    var body: some View {
        ZStack {
            SheetBackground()
            VStack(spacing: 16) {
                Capsule().fill(AeroColor.stroke).frame(width: 38, height: 4).padding(.top, 10)

                HStack(spacing: 12) {
                    menuTile(symbol: isBookmarked ? "star.fill" : "star",
                             label: isBookmarked ? "В закладках" : "В закладки",
                             tint: AeroColor.accent, enabled: canBookmark, action: onToggleBookmark)
                    menuTile(symbol: "plus.square.on.square", label: "Новая вкладка", tint: AeroColor.textPrimary, action: onNewTab)
                    menuTile(symbol: "square.and.arrow.up", label: "Поделиться", tint: AeroColor.textPrimary, enabled: canBookmark, action: onShare)
                }
                .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    row(symbol: "text.magnifyingglass", title: "Найти на странице", enabled: canFind, action: onFind)
                    RowDivider()
                    row(symbol: isIncognito ? "eyeglasses" : "eyeglasses",
                        title: isIncognito ? "Выйти из инкогнито" : "Режим инкогнито",
                        tint: isIncognito ? AeroColor.accent : AeroColor.textPrimary, action: onToggleIncognito)
                    RowDivider()
                    row(symbol: "flag", title: "Пожаловаться на рекламу", tint: AeroColor.danger, enabled: canReport, action: onReportAd)
                }
                .background(RoundedRectangle(cornerRadius: 18).fill(AeroColor.card))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AeroColor.stroke, lineWidth: 1))
                .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    row(symbol: "star", title: "Закладки", action: onBookmarks)
                    RowDivider()
                    row(symbol: "clock.arrow.circlepath", title: "История", action: onHistory)
                    RowDivider()
                    row(symbol: "gearshape", title: "Настройки", action: onSettings)
                }
                .background(RoundedRectangle(cornerRadius: 18).fill(AeroColor.card))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AeroColor.stroke, lineWidth: 1))
                .padding(.horizontal, 16)

                Spacer()
            }
        }
    }

    private func menuTile(symbol: String, label: String, tint: Color, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 22, weight: .medium)).foregroundStyle(enabled ? tint : AeroColor.textTertiary)
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(enabled ? AeroColor.textSecondary : AeroColor.textTertiary).lineLimit(1)
            }
            .frame(maxWidth: .infinity).frame(height: 80)
            .background(RoundedRectangle(cornerRadius: 16).fill(AeroColor.card))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AeroColor.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }

    private func row(symbol: String, title: String, tint: Color = AeroColor.accent, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 17, weight: .medium)).foregroundStyle(enabled ? tint : AeroColor.textTertiary).frame(width: 26)
                Text(title).font(.system(size: 16)).foregroundStyle(enabled ? AeroColor.textPrimary : AeroColor.textTertiary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(AeroColor.textTertiary)
            }
            .padding(.horizontal, 16).frame(height: 54).contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.99))
        .disabled(!enabled)
    }
}
