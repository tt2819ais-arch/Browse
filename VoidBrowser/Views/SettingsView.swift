import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var browser: BrowserStore
    @EnvironmentObject var bookmarks: BookmarkStore
    @EnvironmentObject var history: HistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var showCleared = false
    @State private var showHelp = false

    var body: some View {
        ZStack {
            SheetBackground()
            ScrollView {
                VStack(spacing: 20) {
                    SheetHeader(title: "Настройки")

                    // Search engine
                    section("Поисковая система") {
                        VStack(spacing: 0) {
                            ForEach(Array(SearchEngine.allCases.enumerated()), id: \.element) { idx, eng in
                                Button { Haptics.tap(); settings.engine = eng } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: eng.symbol)
                                            .font(.system(size: 17)).frame(width: 26)
                                            .foregroundStyle(VoidColor.accent)
                                        Text(eng.title).font(.system(size: 16)).foregroundStyle(VoidColor.textPrimary)
                                        Spacer()
                                        if settings.engine == eng {
                                            Image(systemName: "checkmark").foregroundStyle(VoidColor.accent)
                                        }
                                    }
                                    .padding(.horizontal, 16).frame(height: 50).contentShape(Rectangle())
                                }
                                .buttonStyle(PressableStyle(scale: 0.99))
                                if idx < SearchEngine.allCases.count - 1 {
                                    Divider().overlay(VoidColor.stroke)
                                }
                            }
                        }
                    }

                    // Browsing toggles
                    section("Просмотр") {
                        VStack(spacing: 0) {
                            toggleRow("desktopcomputer", "Версия для ПК", $settings.desktopMode) {
                                browser.current?.applyDesktop(settings.desktopMode)
                            }
                            Divider().overlay(VoidColor.stroke)
                            toggleRow("photo", "Фон новой вкладки", $settings.showWallpaper, action: {})
                        }
                    }

                    // Wallpaper picker
                    if settings.showWallpaper && !WallpaperLibrary.names.isEmpty {
                        section("Обои (\(WallpaperLibrary.names.count))") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(WallpaperLibrary.names, id: \.self) { name in
                                        Button { Haptics.tap(); settings.wallpaper = name } label: {
                                            ZStack {
                                                if let img = WallpaperLibrary.image(name) {
                                                    Image(uiImage: img).resizable().scaledToFill()
                                                }
                                            }
                                            .frame(width: 64, height: 110)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(settings.wallpaper == name ? VoidColor.accent : VoidColor.stroke,
                                                                  lineWidth: settings.wallpaper == name ? 2.5 : 1))
                                        }
                                        .buttonStyle(PressableStyle())
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                        }
                    }

                    // Data
                    section("Данные") {
                        VStack(spacing: 0) {
                            actionRow("trash", "Очистить кеш и куки", tint: VoidColor.textPrimary) {
                                browser.clearWebsiteData {
                                    showCleared = true
                                    Haptics.success()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { showCleared = false }
                                }
                            }
                            Divider().overlay(VoidColor.stroke)
                            actionRow("clock.badge.xmark", "Очистить историю", tint: VoidColor.textPrimary) {
                                history.clear(); Haptics.success()
                            }
                            Divider().overlay(VoidColor.stroke)
                            actionRow("star.slash", "Удалить все закладки", tint: VoidColor.danger) {
                                bookmarks.clear(); Haptics.success()
                            }
                        }
                    }

                    // About
                    section("О приложении") {
                        VStack(spacing: 0) {
                            actionRow("questionmark.circle", "Справка", tint: VoidColor.textPrimary) {
                                showHelp = true
                            }
                            Divider().overlay(VoidColor.stroke)
                            HStack {
                                Text("Версия").font(.system(size: 16)).foregroundStyle(VoidColor.textPrimary)
                                Spacer()
                                Text(appVersion).font(.system(size: 15)).foregroundStyle(VoidColor.textSecondary)
                            }
                            .padding(.horizontal, 16).frame(height: 50)
                        }
                    }

                    Text("VOID BROWSER · сделано с ♥")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(VoidColor.textTertiary)
                        .padding(.bottom, 30)
                }
            }

            if showCleared {
                toast("Данные очищены")
            }
        }
        .sheet(isPresented: $showHelp) { HelpView() }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold)).tracking(1)
                .foregroundStyle(VoidColor.textTertiary)
                .padding(.horizontal, 20)
            content()
                .background(RoundedRectangle(cornerRadius: 18).fill(VoidColor.card))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(VoidColor.stroke, lineWidth: 1))
                .padding(.horizontal, 16)
        }
    }

    private func toggleRow(_ symbol: String, _ title: String, _ binding: Binding<Bool>, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17)).frame(width: 26).foregroundStyle(VoidColor.accent)
            Text(title).font(.system(size: 16)).foregroundStyle(VoidColor.textPrimary)
            Spacer()
            Toggle("", isOn: binding).labelsHidden().tint(VoidColor.accent)
                .onChange(of: binding.wrappedValue) { _ in action() }
        }
        .padding(.horizontal, 16).frame(height: 52)
    }

    private func actionRow(_ symbol: String, _ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 17)).frame(width: 26).foregroundStyle(tint)
                Text(title).font(.system(size: 16)).foregroundStyle(tint)
                Spacer()
            }
            .padding(.horizontal, 16).frame(height: 52).contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.99))
    }

    private func toast(_ text: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(VoidColor.accent)
                Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(VoidColor.textPrimary)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Capsule().fill(VoidColor.bgRaised))
            .overlay(Capsule().strokeBorder(VoidColor.stroke, lineWidth: 1))
            .padding(.bottom, 50)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
