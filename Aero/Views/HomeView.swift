import SwiftUI

struct HomeView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var browser: BrowserStore
    let onOpen: (String) -> Void

    private let links: [QuickLink] = [
        QuickLink(title: "Google",    url: "https://google.com",       symbol: "magnifyingglass", tint: Color(red:0.26,green:0.52,blue:0.96)),
        QuickLink(title: "YouTube",   url: "https://youtube.com",      symbol: "play.rectangle.fill", tint: Color(red:0.9,green:0.2,blue:0.2)),
        QuickLink(title: "Wikipedia", url: "https://wikipedia.org",    symbol: "book.fill", tint: Color(red:0.4,green:0.42,blue:0.48)),
        QuickLink(title: "GitHub",    url: "https://github.com",       symbol: "chevron.left.forwardslash.chevron.right", tint: Color(red:0.18,green:0.2,blue:0.24)),
        QuickLink(title: "Reddit",    url: "https://reddit.com",       symbol: "bubble.left.and.bubble.right.fill", tint: Color(red:0.95,green:0.4,blue:0.15)),
        QuickLink(title: "X",         url: "https://x.com",            symbol: "xmark", tint: Color(red:0.1,green:0.1,blue:0.12)),
        QuickLink(title: "Telegram",  url: "https://web.telegram.org", symbol: "paperplane.fill", tint: Color(red:0.2,green:0.6,blue:0.92)),
        QuickLink(title: "Карты",     url: "https://maps.google.com",  symbol: "map.fill", tint: Color(red:0.25,green:0.7,blue:0.45)),
    ]

    var body: some View {
        ZStack {
            if settings.showWallpaper {
                WallpaperView(name: settings.wallpaper).ignoresSafeArea()
            } else {
                AeroColor.bg.ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: 30) {
                    Spacer().frame(height: 76)

                    VStack(spacing: 10) {
                        ZStack {
                            Circle().stroke(AeroColor.accent, lineWidth: 5).frame(width: 64, height: 64)
                            Image(systemName: "location.north.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(AeroColor.accent)
                                .rotationEffect(.degrees(45))
                        }
                        Text("Aero").font(.system(size: 30, weight: .bold)).foregroundStyle(AeroColor.textPrimary)
                        Text(browser.incognito ? "режим инкогнито" : "быстрый и приватный браузер")
                            .font(.system(size: 13)).foregroundStyle(AeroColor.textSecondary)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 20) {
                        ForEach(links) { link in
                            Button { Haptics.tap(); onOpen(link.url) } label: {
                                VStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                                            .fill(AeroColor.card)
                                            .frame(width: 60, height: 60)
                                            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(AeroColor.stroke, lineWidth: 1))
                                            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                                        Image(systemName: link.symbol).font(.system(size: 22, weight: .medium)).foregroundStyle(link.tint)
                                    }
                                    Text(link.title).font(.system(size: 11, weight: .medium)).foregroundStyle(AeroColor.textSecondary).lineLimit(1)
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
