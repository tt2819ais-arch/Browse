import SwiftUI

@main
struct VoidBrowserApp: App {
    @StateObject private var browser = BrowserStore()
    @StateObject private var bookmarks = BookmarkStore()
    @StateObject private var history = HistoryStore()
    @StateObject private var settings = SettingsStore()
    @State private var launched = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(browser)
                    .environmentObject(bookmarks)
                    .environmentObject(history)
                    .environmentObject(settings)
                    .opacity(launched ? 1 : 0)
                if !launched {
                    LaunchView()
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeInOut(duration: 0.55)) { launched = true }
                }
            }
        }
    }
}
