import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var browser: BrowserStore
    @EnvironmentObject var bookmarks: BookmarkStore
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var adblock: AdBlockStore
    @State private var clearedToast = false

    var body: some View {
        NavigationStack {
            ZStack {
                SheetBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        // Search engine
                        GroupCard(title: "Поисковик") {
                            ForEach(Array(SearchEngine.allCases.enumerated()), id: \.element) { idx, eng in
                                Button { Haptics.tap(); settings.engine = eng } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: eng.symbol).font(.system(size: 17)).foregroundStyle(AeroColor.accent).frame(width: 26)
                                        Text(eng.title).font(.system(size: 15, weight: .medium)).foregroundStyle(AeroColor.textPrimary)
                                        Spacer()
                                        if settings.engine == eng { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(AeroColor.accent) }
                                    }
                                    .padding(.vertical, 12).padding(.horizontal, 14).contentShape(Rectangle())
                                }
                                .buttonStyle(PressableStyle(scale: 0.99))
                                if idx < SearchEngine.allCases.count - 1 { RowDivider() }
                            }
                        }

                        // Appearance
                        GroupCard(title: "Оформление") {
                            HStack(spacing: 12) {
                                Image(systemName: "circle.lefthalf.filled").font(.system(size: 16)).foregroundStyle(AeroColor.accent).frame(width: 26)
                                Text("Тема").font(.system(size: 15, weight: .medium)).foregroundStyle(AeroColor.textPrimary)
                                Spacer()
                                Picker("", selection: $settings.theme) {
                                    ForEach(ThemeMode.allCases) { Text($0.title).tag($0) }
                                }.pickerStyle(.menu).tint(AeroColor.accent)
                            }
                            .padding(.vertical, 6).padding(.horizontal, 14)
                            RowDivider()
                            ToggleRow(symbol: "photo", title: "Обои на главной", isOn: $settings.showWallpaper)
                            if settings.showWallpaper {
                                RowDivider()
                                wallpaperPicker.padding(.vertical, 10)
                            }
                            RowDivider()
                            ToggleRow(symbol: "desktopcomputer", title: "Версия для ПК", subtitle: "Запрашивать десктоп-сайты", isOn: Binding(
                                get: { settings.desktopMode },
                                set: { settings.desktopMode = $0; browser.current?.applyDesktop($0) }))
                        }

                        // Privacy + ad block navigation
                        GroupCard(title: "Приватность и защита") {
                            NavigationLink { PrivacyView().environmentObject(settings) } label: {
                                navLabel("hand.raised.fill", "Приватность", value: settings.anyPrivacyOn ? "вкл" : "выкл")
                            }
                            RowDivider()
                            NavigationLink { AdBlockView().environmentObject(settings).environmentObject(adblock) } label: {
                                navLabel("shield.lefthalf.filled", "Блокировка рекламы", value: settings.adBlockEnabled ? "вкл" : "выкл")
                            }
                        }

                        // Data
                        GroupCard(title: "Данные") {
                            actionRow("trash", "Очистить кеш и куки", tint: AeroColor.textPrimary) {
                                browser.clearWebsiteData { withAnimation { clearedToast = true }; Haptics.success() }
                            }
                            RowDivider()
                            actionRow("clock.arrow.circlepath", "Очистить историю", tint: AeroColor.textPrimary) { history.clear(); Haptics.success() }
                            RowDivider()
                            actionRow("star.slash", "Очистить закладки", tint: AeroColor.danger) { bookmarks.clear(); Haptics.success() }
                        }

                        // About
                        GroupCard(title: "О приложении") {
                            NavigationLink { HelpView() } label: { navLabel("info.circle", "Справка и о приложении", value: "v1.1") }
                        }

                        Spacer().frame(height: 30)
                    }
                    .padding(.top, 8)
                }
                .navigationTitle("Настройки")
                .navigationBarTitleDisplayMode(.inline)

                if clearedToast { toast("Данные очищены") }
            }
        }
    }

    private var wallpaperPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(WallpaperLibrary.names, id: \.self) { name in
                    Button { Haptics.tap(); settings.wallpaper = name } label: {
                        WallpaperView(name: name).frame(width: 50, height: 86).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(settings.wallpaper == name ? AeroColor.accent : AeroColor.stroke, lineWidth: settings.wallpaper == name ? 2.5 : 1))
                    }.buttonStyle(PressableStyle())
                }
            }.padding(.horizontal, 14)
        }
    }

    private func navLabel(_ symbol: String, _ title: String, value: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 16, weight: .medium)).foregroundStyle(AeroColor.accent).frame(width: 26)
            Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(AeroColor.textPrimary)
            Spacer()
            if let value { Text(value).font(.system(size: 13)).foregroundStyle(AeroColor.textTertiary) }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(AeroColor.textTertiary)
        }
        .padding(.vertical, 12).padding(.horizontal, 14).contentShape(Rectangle())
    }

    private func actionRow(_ symbol: String, _ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 16, weight: .medium)).foregroundStyle(tint).frame(width: 26)
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(tint)
                Spacer()
            }
            .padding(.vertical, 12).padding(.horizontal, 14).contentShape(Rectangle())
        }.buttonStyle(PressableStyle(scale: 0.99))
    }

    private func toast(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Capsule().fill(AeroColor.success)).padding(.bottom, 40)
        }
        .transition(.opacity)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { clearedToast = false } } }
    }
}
