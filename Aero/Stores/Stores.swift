import SwiftUI
import WebKit
import Combine

// MARK: - Settings store (UserDefaults-backed, granular privacy toggles)
final class SettingsStore: ObservableObject {
    private let d = UserDefaults.standard

    @Published var engine: SearchEngine { didSet { d.set(engine.rawValue, forKey: "searchEngine") } }
    @Published var theme: ThemeMode { didSet { d.set(theme.rawValue, forKey: "theme") } }
    @Published var desktopMode: Bool { didSet { d.set(desktopMode, forKey: "desktopMode") } }
    @Published var forceDark: Bool { didSet { d.set(forceDark, forKey: "forceDark") } }
    @Published var wallpaper: String { didSet { d.set(wallpaper, forKey: "wallpaper") } }
    @Published var showWallpaper: Bool { didSet { d.set(showWallpaper, forKey: "showWallpaper") } }

    // Ad blocking
    @Published var adBlockEnabled: Bool { didSet { d.set(adBlockEnabled, forKey: "adBlock") } }
    @Published var cosmeticEnabled: Bool { didSet { d.set(cosmeticEnabled, forKey: "cosmetic") } }
    @Published var enabledLists: Set<String> { didSet { d.set(Array(enabledLists), forKey: "enabledLists") } }

    // Privacy / anti-fingerprint (each independently toggleable)
    @Published var pCanvas: Bool { didSet { d.set(pCanvas, forKey: "pCanvas") } }
    @Published var pWebGL: Bool { didSet { d.set(pWebGL, forKey: "pWebGL") } }
    @Published var pAudio: Bool { didSet { d.set(pAudio, forKey: "pAudio") } }
    @Published var pFonts: Bool { didSet { d.set(pFonts, forKey: "pFonts") } }
    @Published var pRects: Bool { didSet { d.set(pRects, forKey: "pRects") } }
    @Published var pTiming: Bool { didSet { d.set(pTiming, forKey: "pTiming") } }
    @Published var pMedia: Bool { didSet { d.set(pMedia, forKey: "pMedia") } }
    @Published var pBattery: Bool { didSet { d.set(pBattery, forKey: "pBattery") } }
    @Published var pSensors: Bool { didSet { d.set(pSensors, forKey: "pSensors") } }
    @Published var pLanguage: Bool { didSet { d.set(pLanguage, forKey: "pLanguage") } }
    @Published var language: String { didSet { d.set(language, forKey: "language") } }
    @Published var pTimezone: Bool { didSet { d.set(pTimezone, forKey: "pTimezone") } }
    @Published var timezone: String { didSet { d.set(timezone, forKey: "timezone") } }
    @Published var pScreen: Bool { didSet { d.set(pScreen, forKey: "pScreen") } }
    @Published var pGeo: Bool { didSet { d.set(pGeo, forKey: "pGeo") } }
    @Published var geoDeny: Bool { didSet { d.set(geoDeny, forKey: "geoDeny") } }
    @Published var pWebRTC: Bool { didSet { d.set(pWebRTC, forKey: "pWebRTC") } }
    @Published var pNavigator: Bool { didSet { d.set(pNavigator, forKey: "pNavigator") } }

    init() {
        engine = SearchEngine(rawValue: d.string(forKey: "searchEngine") ?? "") ?? .google
        theme = ThemeMode(rawValue: d.string(forKey: "theme") ?? "") ?? .system
        desktopMode = d.bool(forKey: "desktopMode")
        forceDark = d.bool(forKey: "forceDark")
        wallpaper = d.string(forKey: "wallpaper") ?? "aero-01"
        showWallpaper = d.object(forKey: "showWallpaper") as? Bool ?? true
        adBlockEnabled = d.object(forKey: "adBlock") as? Bool ?? true
        cosmeticEnabled = d.object(forKey: "cosmetic") as? Bool ?? true
        if let arr = d.array(forKey: "enabledLists") as? [String] { enabledLists = Set(arr) }
        else { enabledLists = ["easylist", "easyprivacy", "annoyance", "ru"] }
        pCanvas = d.bool(forKey: "pCanvas")
        pWebGL = d.bool(forKey: "pWebGL")
        pAudio = d.bool(forKey: "pAudio")
        pFonts = d.bool(forKey: "pFonts")
        pRects = d.bool(forKey: "pRects")
        pTiming = d.bool(forKey: "pTiming")
        pMedia = d.bool(forKey: "pMedia")
        pBattery = d.bool(forKey: "pBattery")
        pSensors = d.bool(forKey: "pSensors")
        pLanguage = d.bool(forKey: "pLanguage")
        language = d.string(forKey: "language") ?? "en-US"
        pTimezone = d.bool(forKey: "pTimezone")
        timezone = d.string(forKey: "timezone") ?? "UTC"
        pScreen = d.bool(forKey: "pScreen")
        pGeo = d.bool(forKey: "pGeo")
        geoDeny = d.object(forKey: "geoDeny") as? Bool ?? true
        pWebRTC = d.bool(forKey: "pWebRTC")
        pNavigator = d.bool(forKey: "pNavigator")
    }

    /// Build a privacy config; `force` enables hardening regardless (used in incognito).
    func privacyConfig(incognito: Bool) -> PrivacyConfig {
        var c = PrivacyConfig()
        c.canvasNoise = pCanvas || incognito
        c.webglSpoof = pWebGL || incognito
        c.audioNoise = pAudio || incognito
        c.limitFonts = pFonts || incognito
        c.rectsNoise = pRects                       // can affect layout-sensitive sites → manual only
        c.reduceTiming = pTiming || incognito
        c.hideMedia = pMedia || incognito
        c.hideBattery = pBattery || incognito
        c.blockSensors = pSensors || incognito
        c.spoofLanguage = pLanguage; c.language = language
        c.spoofTimezone = pTimezone; c.timezone = timezone
        c.spoofScreen = pScreen || incognito
        c.spoofGeo = pGeo; c.geoDeny = geoDeny
        c.blockWebRTC = pWebRTC || incognito
        c.hardenNavigator = pNavigator || incognito
        c.enabled = c.canvasNoise || c.webglSpoof || c.audioNoise || c.limitFonts || c.rectsNoise ||
                    c.reduceTiming || c.hideMedia || c.hideBattery || c.blockSensors || c.spoofLanguage ||
                    c.spoofTimezone || c.spoofScreen || c.spoofGeo || c.blockWebRTC || c.hardenNavigator
        return c
    }

    var anyPrivacyOn: Bool {
        pCanvas || pWebGL || pAudio || pFonts || pRects || pTiming || pMedia || pBattery || pSensors ||
        pLanguage || pTimezone || pScreen || pGeo || pWebRTC || pNavigator
    }

    /// Count of enabled fingerprint protections (for the UI summary).
    var privacyOnCount: Int {
        [pCanvas, pWebGL, pAudio, pFonts, pRects, pTiming, pMedia, pBattery, pSensors,
         pLanguage, pTimezone, pScreen, pGeo, pWebRTC, pNavigator].filter { $0 }.count
    }
    static let privacyTotal = 15

    /// Enable/disable every protection at once. `rects` stays off by default (layout-sensitive).
    func setAllPrivacy(_ on: Bool, includeRects: Bool = false) {
        pCanvas = on; pWebGL = on; pAudio = on; pFonts = on
        pTiming = on; pMedia = on; pBattery = on; pSensors = on
        pScreen = on; pWebRTC = on; pNavigator = on
        pLanguage = on; pTimezone = on; pGeo = on
        pRects = on && includeRects
    }

    static let languageOptions = ["en-US", "en-GB", "de-DE", "fr-FR", "es-ES", "it-IT", "ja-JP", "ru-RU"]
    static let timezoneOptions = ["UTC", "America/New_York", "America/Los_Angeles", "Europe/London", "Europe/Berlin", "Europe/Moscow", "Asia/Tokyo"]
}

// MARK: - Bookmarks store
final class BookmarkStore: ObservableObject {
    @Published var items: [Bookmark] = []
    private let key = "bookmarks.v1"
    init() { load() }
    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) { items = decoded }
    }
    func save() { if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: key) } }
    func contains(_ url: String) -> Bool { items.contains { $0.url == url } }
    func toggle(title: String, url: String) {
        if let idx = items.firstIndex(where: { $0.url == url }) { items.remove(at: idx) }
        else { items.insert(Bookmark(title: title.isEmpty ? URLBuilder.prettyHost(url) : title, url: url), at: 0) }
        save()
    }
    func remove(at offsets: IndexSet) { items.remove(atOffsets: offsets); save() }
    func clear() { items.removeAll(); save() }

    /// Bulk-add imported entries (skips duplicates). Returns number added.
    @discardableResult
    func addMany(_ entries: [(title: String, url: String)]) -> Int {
        var added = 0
        for e in entries.reversed() {
            guard let u = URL(string: e.url), u.scheme?.hasPrefix("http") == true else { continue }
            if contains(e.url) { continue }
            let t = e.title.trimmingCharacters(in: .whitespacesAndNewlines)
            items.insert(Bookmark(title: t.isEmpty ? URLBuilder.prettyHost(e.url) : t, url: e.url), at: 0)
            added += 1
        }
        save()
        return added
    }
}

// MARK: - Favorites store (start page tiles)
final class FavoriteStore: ObservableObject {
    @Published var items: [Favorite] = []
    private let key = "favorites.v1"
    private let seededKey = "favorites.seeded"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Favorite].self, from: data) {
            items = decoded
        }
        if !UserDefaults.standard.bool(forKey: seededKey) {
            UserDefaults.standard.set(true, forKey: seededKey)
            if items.isEmpty {
                items = [
                    Favorite(title: "Google", url: "https://google.com"),
                    Favorite(title: "YouTube", url: "https://youtube.com"),
                    Favorite(title: "Wikipedia", url: "https://wikipedia.org"),
                    Favorite(title: "GitHub", url: "https://github.com"),
                    Favorite(title: "Reddit", url: "https://reddit.com"),
                    Favorite(title: "X", url: "https://x.com"),
                    Favorite(title: "Telegram", url: "https://web.telegram.org"),
                    Favorite(title: "Карты", url: "https://maps.google.com"),
                ]
                save()
            }
        }
    }

    private func save() { if let d = try? JSONEncoder().encode(items) { UserDefaults.standard.set(d, forKey: key) } }

    func add(title: String, url: String) {
        guard let u = URL(string: url.hasPrefix("http") ? url : "https://\(url)"), u.host != nil else { return }
        let final = u.absoluteString
        if items.contains(where: { $0.url == final }) { return }
        let t = title.trimmingCharacters(in: .whitespaces)
        items.insert(Favorite(title: t.isEmpty ? URLBuilder.prettyHost(final) : t, url: final), at: 0)
        save()
    }

    func remove(_ fav: Favorite) { items.removeAll { $0.id == fav.id }; save() }
    func remove(at offsets: IndexSet) { items.remove(atOffsets: offsets); save() }
}

// MARK: - History store
final class HistoryStore: ObservableObject {
    @Published var items: [HistoryItem] = []
    private let key = "history.v1"
    private let limit = 500
    init() { load() }
    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) { items = decoded }
    }
    func save() { if let data = try? JSONEncoder().encode(Array(items.prefix(limit))) { UserDefaults.standard.set(data, forKey: key) } }
    func record(title: String, url: String) {
        guard let u = URL(string: url), u.scheme?.hasPrefix("http") == true else { return }
        if items.first?.url == url { return }
        items.insert(HistoryItem(title: title.isEmpty ? URLBuilder.prettyHost(url) : title, url: url), at: 0)
        if items.count > limit { items = Array(items.prefix(limit)) }
        save()
    }
    func remove(at offsets: IndexSet) { items.remove(atOffsets: offsets); save() }
    func clear() { items.removeAll(); save() }

    /// Merge imported history entries (dedupe by url, newest kept, capped).
    func addMany(_ entries: [HistoryItem]) {
        var urls = Set(items.map { $0.url })
        var merged = items
        for e in entries where !urls.contains(e.url) {
            merged.append(e); urls.insert(e.url)
        }
        merged.sort { $0.date > $1.date }
        items = Array(merged.prefix(limit))
        save()
    }
}

// MARK: - Recently closed tab
struct ClosedTab: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let url: String
}

// MARK: - Pending ad report (awaiting user confirmation)
struct PendingReport: Identifiable, Equatable {
    let id = UUID()
    let host: String
    let selector: String
    let text: String
}

// MARK: - Browser store (tabs + incognito + config wiring)
final class BrowserStore: ObservableObject {
    @Published var tabs: [WebTab] = []
    @Published var currentID: UUID? { didSet { observeCurrent() } }
    @Published var showTabsOverview = false
    @Published var incognito = false
    @Published var reportMode = false
    @Published var pendingReport: PendingReport?
    @Published var recentlyClosed: [ClosedTab] = []

    private var tabObserver: AnyCancellable?
    weak var settings: SettingsStore?
    weak var adblock: AdBlockStore?
    weak var proxies: ProxyStore?

    var current: WebTab? { tabs.first { $0.id == currentID } }

    init() { newTab(select: true) }

    func attach(settings: SettingsStore, adblock: AdBlockStore, proxies: ProxyStore) {
        self.settings = settings
        self.adblock = adblock
        self.proxies = proxies
        recompileAndReconfigure(reload: false)
        applyProxyToAll(reload: false)
    }

    /// Re-apply the active proxy to every tab (and optionally reload).
    func applyProxyToAll(reload: Bool) {
        let active = proxies?.active
        for tab in tabs {
            tab.applyProxy(active)
            if reload, !tab.isHome { tab.reload() }
        }
    }

    private func observeCurrent() {
        tabObserver = current?.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.objectWillChange.send() }
        }
    }

    // MARK: - Configuration
    private func applyConfig(to tab: WebTab) {
        guard let settings else { return }
        let cfg = settings.privacyConfig(incognito: incognito)
        let cosmetic = adblock?.cosmeticJS(enabled: settings.adBlockEnabled, cosmetic: settings.cosmeticEnabled) ?? ""
        tab.configure(privacy: cfg, ruleLists: adblock?.ruleLists ?? [], cosmeticJS: cosmetic, adblockEnabled: settings.adBlockEnabled, forceDark: settings.forceDark)
        tab.applyProxy(proxies?.active)
    }

    /// Re-apply current privacy/adblock config to all tabs (no recompile).
    func reapplyConfig(reload: Bool) {
        for tab in tabs { applyConfig(to: tab); if reload, !tab.isHome { tab.reload() } }
    }

    /// Recompile the ad-block rule list, then re-apply config to all tabs.
    func recompileAndReconfigure(reload: Bool) {
        guard let settings, let adblock else { return }
        adblock.rebuild(masterEnabled: settings.adBlockEnabled, enabledGroups: settings.enabledLists) { [weak self] in
            guard let self else { return }
            for tab in self.tabs {
                self.applyConfig(to: tab)
                if reload, !tab.isHome { tab.reload() }
            }
        }
    }

    @discardableResult
    func newTab(select: Bool = true, load url: URL? = nil) -> WebTab {
        let tab = WebTab(incognito: incognito, desktopMode: settings?.desktopMode ?? false)
        tab.onCreateTab = { [weak self] u in self?.newTab(select: true, load: u) }
        tab.onReportPick = { [weak self] host, selector, text in
            self?.pendingReport = PendingReport(host: host, selector: selector, text: text)
        }
        applyConfig(to: tab)
        tabs.append(tab)
        if select { currentID = tab.id }
        if let url { tab.load(url) }
        return tab
    }

    func select(_ tab: WebTab) { current?.captureSnapshot(); currentID = tab.id }

    /// URLs of currently open (non-home) tabs — used by export.
    var openTabURLs: [String] {
        tabs.compactMap { t in
            guard !t.isHome, let u = URL(string: t.urlString), u.scheme?.hasPrefix("http") == true else { return nil }
            return t.urlString
        }
    }

    /// Open a batch of URLs as new tabs (used by import).
    @discardableResult
    func openURLs(_ urls: [URL]) -> Int {
        guard !urls.isEmpty else { return 0 }
        for (i, u) in urls.enumerated() {
            newTab(select: i == urls.count - 1, load: u)
        }
        showTabsOverview = false
        return urls.count
    }

    func close(_ tab: WebTab) {
        tab.stop()
        if !tab.isHome, let u = URL(string: tab.urlString), u.scheme?.hasPrefix("http") == true {
            recentlyClosed.removeAll { $0.url == tab.urlString }
            recentlyClosed.insert(ClosedTab(title: tab.title, url: tab.urlString), at: 0)
            if recentlyClosed.count > 10 { recentlyClosed = Array(recentlyClosed.prefix(10)) }
        }
        guard let idx = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: idx)
        if tabs.isEmpty { newTab(select: true) }
        else if currentID == tab.id { currentID = tabs[max(0, idx - 1)].id }
    }

    func closeAll() {
        tabs.forEach { $0.stop() }
        tabs.removeAll()
        newTab(select: true)
        showTabsOverview = false
    }

    // MARK: - Incognito
    func setIncognito(_ on: Bool) {
        guard on != incognito else { return }
        tabs.forEach { $0.stop() }
        tabs.removeAll()
        incognito = on
        newTab(select: true)
    }

    // MARK: - Report mode
    func setReportMode(_ on: Bool) {
        reportMode = on
        if on { current?.enterReportMode() } else { current?.exitReportMode() }
    }

    func confirmPendingReport() {
        guard let p = pendingReport, let adblock else { return }
        adblock.addReported(host: p.host, selector: p.selector, note: p.text)
        current?.hideSelector(p.selector)
        pendingReport = nil
        setReportMode(false)
        // Refresh cosmetic script so the rule persists on future loads
        if let settings {
            let cosmetic = adblock.cosmeticJS(enabled: settings.adBlockEnabled, cosmetic: settings.cosmeticEnabled)
            for tab in tabs { tab.configure(privacy: settings.privacyConfig(incognito: incognito), ruleLists: adblock.ruleLists, cosmeticJS: cosmetic, adblockEnabled: settings.adBlockEnabled, forceDark: settings.forceDark) }
        }
    }

    func cancelPendingReport() { pendingReport = nil }

    // MARK: - Data clearing
    func clearWebsiteData(completion: @escaping () -> Void) {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast) { completion() }
    }
}
