import SwiftUI

@main
struct AeroApp: App {
    @StateObject private var browser = BrowserStore()
    @StateObject private var bookmarks = BookmarkStore()
    @StateObject private var history = HistoryStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var adblock = AdBlockStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(browser)
                .environmentObject(bookmarks)
                .environmentObject(history)
                .environmentObject(settings)
                .environmentObject(adblock)
                .preferredColorScheme(settings.theme.colorScheme)
                .onAppear { browser.attach(settings: settings, adblock: adblock) }
        }
    }
}
