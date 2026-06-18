import SwiftUI

@main
struct AeroApp: App {
    @StateObject private var browser = BrowserStore()
    @StateObject private var bookmarks = BookmarkStore()
    @StateObject private var history = HistoryStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var adblock = AdBlockStore()
    @StateObject private var proxies = ProxyStore()
    @StateObject private var favorites = FavoriteStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(browser)
                .environmentObject(bookmarks)
                .environmentObject(history)
                .environmentObject(settings)
                .environmentObject(adblock)
                .environmentObject(proxies)
                .environmentObject(favorites)
                .preferredColorScheme(settings.theme.colorScheme)
                .onAppear { browser.attach(settings: settings, adblock: adblock, proxies: proxies) }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive { browser.saveSession() }
        }
    }
}
