import SwiftUI

struct HomeView: View {
    @EnvironmentObject var settings: SettingsStore
    let onOpen: (String) -> Void

    private let links: [QuickLink] = [
        QuickLink(title: "Google",    url: "https://google.com",        symbol: "magnifyingglass", tint: Color(red:0.55,green:0.53,blue:0.96)),
        QuickLink(title: "YouTube",   url: "https://youtube.com",       symbol: "play.rectangle.fill", tint: Color(red:0.9,green:0.3,blue:0.3)),
        QuickLink(title: "Wikipedia", url: "https://wikipedia.org",     symbol: "book.fill", tint: Color(red:0.6,green:0.6,blue:0.66)),
        QuickLink(title: "GitHub",    url: "https://github.com",        symbol: "chevron.left.forwardslash.chevron.right", tint: Color(red:0.5,green:0.5,blue:0.55)),
        QuickLink(title: "Reddit",    url: "https://reddit.com",        symbol: "bubble.left.and.bubble.right.fill", tint: Color(red:0.95,green:0.45,blue:0.2)),
        QuickLink(title: "X",         url: "https://x.com",             symbol: "xmark", tint: Color(white: 0.85)),
        QuickLink(title: "Telegram",  url: "https://web.telegram.org",  symbol: "paperplane.fill", tint: Color(red:0.3,green:0.65,blue:0.95)),
        QuickLink(title: "Maps",      url: "https://maps.google.com",   symbol: "map.fill", tint: Color(red:0.35,green:0.75,blue:0.5)),
    ]

    var body: some View {
        ZStack {
            if settings.showWallpaper {
                WallpaperView(name: settings.wallpaper)
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.35).ignoresSafeArea())
            }

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 70)

                    VStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundStyle(VoidColor.textPrimary)
                        Text("VOID")
                            .font(.system(size: 26, weight: .semibold, design: .monospaced))
                            .tracking(8)
                            .foregroundStyle(VoidColor.textPrimary)
                        Text("минималистичный браузер")
                            .font(.system(size: 12))
                            .foregroundStyle(VoidColor.textSecondary)
                    }

                    // Quick links grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 18) {
                        ForEach(links) { link in
                            Button {
                                Haptics.tap(); onOpen(link.url)
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(VoidColor.card)
                                            .frame(width: 58, height: 58)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .strokeBorder(VoidColor.stroke, lineWidth: 1)
                                            )
                                        Image(systemName: link.symbol)
                                            .font(.system(size: 22, weight: .medium))
                                            .foregroundStyle(link.tint)
                                    }
                                    Text(link.title)
                                        .font(.system(size: 11))
                                        .foregroundStyle(VoidColor.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.horizontal, 18)

                    Spacer()
                }
            }
        }
    }
}
