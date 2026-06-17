import SwiftUI
import WebKit
import Combine

// MARK: - Settings store (UserDefaults-backed, reliably published)
final class SettingsStore: ObservableObject {
    private let d = UserDefaults.standard

    @Published var engine: SearchEngine {
        didSet { d.set(engine.rawValue, forKey: "searchEngine") }
    }
    @Published var desktopMode: Bool {
        didSet { d.set(desktopMode, forKey: "desktopMode") }
    }
    @Published var wallpaper: String {
        didSet { d.set(wallpaper, forKey: "wallpaper") }
    }
    @Published var showWallpaper: Bool {
        didSet { d.set(showWallpaper, forKey: "showWallpaper") }
    }

    init() {
        engine = SearchEngine(rawValue: d.string(forKey: "searchEngine") ?? "") ?? .google
        desktopMode = d.bool(forKey: "desktopMode")
        wallpaper = d.string(forKey: "wallpaper") ?? "void-01"
        showWallpaper = d.object(forKey: "showWallpaper") as? Bool ?? true
    }
}

// MARK: - Bookmarks store (persisted to UserDefaults JSON)
final class BookmarkStore: ObservableObject {
    @Published var items: [Bookmark] = []
    private let key = "bookmarks.v1"

    init() { load() }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) {
            items = decoded
        }
    }
    func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    func contains(_ url: String) -> Bool { items.contains { $0.url == url } }
    func toggle(title: String, url: String) {
        if let idx = items.firstIndex(where: { $0.url == url }) {
            items.remove(at: idx)
        } else {
            items.insert(Bookmark(title: title.isEmpty ? URLBuilder.prettyHost(url) : title, url: url), at: 0)
        }
        save()
    }
    func remove(at offsets: IndexSet) { items.remove(atOffsets: offsets); save() }
    func clear() { items.removeAll(); save() }
}

// MARK: - History store
final class HistoryStore: ObservableObject {
    @Published var items: [HistoryItem] = []
    private let key = "history.v1"
    private let limit = 500

    init() { load() }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = decoded
        }
    }
    func save() {
        if let data = try? JSONEncoder().encode(Array(items.prefix(limit))) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    func record(title: String, url: String) {
        guard let u = URL(string: url), u.scheme?.hasPrefix("http") == true else { return }
        // de-dupe consecutive
        if items.first?.url == url { return }
        items.insert(HistoryItem(title: title.isEmpty ? URLBuilder.prettyHost(url) : title, url: url), at: 0)
        if items.count > limit { items = Array(items.prefix(limit)) }
        save()
    }
    func remove(at offsets: IndexSet) { items.remove(atOffsets: offsets); save() }
    func clear() { items.removeAll(); save() }
}

// MARK: - Browser store (tabs)
final class BrowserStore: ObservableObject {
    @Published var tabs: [WebTab] = []
    @Published var currentID: UUID? { didSet { observeCurrent() } }
    @Published var showTabsOverview = false

    private var tabObserver: AnyCancellable?

    var current: WebTab? { tabs.first { $0.id == currentID } }

    init() {
        newTab(select: true)
    }

    /// Forward the current tab's @Published changes (progress, loading, nav state)
    /// so views observing BrowserStore re-render live.
    private func observeCurrent() {
        tabObserver = current?.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.objectWillChange.send() }
        }
    }

    @discardableResult
    func newTab(select: Bool = true, load url: URL? = nil, desktop: Bool = false) -> WebTab {
        let tab = WebTab(desktopMode: desktop)
        tab.onCreateTab = { [weak self] u in self?.newTab(select: true, load: u) }
        tabs.append(tab)
        if select { currentID = tab.id }
        if let url { tab.load(url) }
        return tab
    }

    func select(_ tab: WebTab) {
        current?.captureSnapshot()
        currentID = tab.id
    }

    func close(_ tab: WebTab) {
        tab.stop()
        guard let idx = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: idx)
        if tabs.isEmpty {
            newTab(select: true)
        } else if currentID == tab.id {
            currentID = tabs[max(0, idx - 1)].id
        }
    }

    func closeAll() {
        tabs.forEach { $0.stop() }
        tabs.removeAll()
        newTab(select: true)
        showTabsOverview = false
    }

    // Clear all browsing data (cookies, cache, etc.)
    func clearWebsiteData(completion: @escaping () -> Void) {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(ofTypes: types,
                                                modifiedSince: .distantPast) {
            completion()
        }
    }
}
