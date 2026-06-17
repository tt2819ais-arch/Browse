import SwiftUI
import WebKit
import Combine

// MARK: - Settings store (UserDefaults-backed, granular privacy toggles)
final class SettingsStore: ObservableObject {
    private let d = UserDefaults.standard

    @Published var engine: SearchEngine { didSet { d.set(engine.rawValue, forKey: "searchEngine") } }
    @Published var theme: ThemeMode { didSet { d.set(theme.rawValue, forKey: "theme") } }
    @Published var desktopMode: Bool { didSet { d.set(desktopMode, forKey: "desktopMode") } }
    @Published var wallpaper: String { didSet { d.set(wallpaper, forKey: "wallpaper") } }
    @Published var showWallpaper: Bool { didSet { d.set(showWallpaper, forKey: "showWallpaper") } }

    // Ad blocking
    @Published var adBlockEnabled: Bool { didSet { d.set(adBlockEnabled, forKey: "adBlock") } }
    @Published var cosmeticEnabled: Bool { didSet { d.set(cosmeticEnabled, forKey: "cosmetic") } }

    // Privacy / anti-fingerprint (each independently toggleable)
    @Published var pCanvas: Bool { didSet { d.set(pCanvas, forKey: "pCanvas") } }
    @Published var pWebGL: Bool { didSet { d.set(pWebGL, forKey: "pWebGL") } }
    @Published var pAudio: Bool { didSet { d.set(pAudio, forKey: "pAudio") } }
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
        wallpaper = d.string(forKey: "wallpaper") ?? "aero-01"
        showWallpaper = d.object(forKey: "showWallpaper") as? Bool ?? true
        adBlockEnabled = d.object(forKey: "adBlock") as? Bool ?? true
        cosmeticEnabled = d.object(forKey: "cosmetic") as? Bool ?? true
        pCanvas = d.bool(forKey: "pCanvas")
        pWebGL = d.bool(forKey: "pWebGL")
        pAudio = d.bool(forKey: "pAudio")
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
        c.spoofLanguage = pLanguage; c.language = language
        c.spoofTimezone = pTimezone; c.timezone = timezone
        c.spoofScreen = pScreen || incognito
        c.spoofGeo = pGeo; c.geoDeny = geoDeny
        c.blockWebRTC = pWebRTC || incognito
        c.hardenNavigator = pNavigator || incognito
        c.enabled = c.canvasNoise || c.webglSpoof || c.audioNoise || c.spoofLanguage ||
                    c.spoofTimezone || c.spoofScreen || c.spoofGeo || c.blockWebRTC || c.hardenNavigator
        return c
    }

    var anyPrivacyOn: Bool {
        pCanvas || pWebGL || pAudio || pLanguage || pTimezone || pScreen || pGeo || pWebRTC || pNavigator
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

    private var tabObserver: AnyCancellable?
    weak var settings: SettingsStore?
    weak var adblock: AdBlockStore?

    var current: WebTab? { tabs.first { $0.id == currentID } }

    init() { newTab(select: true) }

    func attach(settings: SettingsStore, adblock: AdBlockStore) {
        self.settings = settings
        self.adblock = adblock
        recompileAndReconfigure(reload: false)
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
        tab.configure(privacy: cfg, ruleList: adblock?.ruleList, cosmeticJS: cosmetic, adblockEnabled: settings.adBlockEnabled)
    }

    /// Re-apply current privacy/adblock config to all tabs (no recompile).
    func reapplyConfig(reload: Bool) {
        for tab in tabs { applyConfig(to: tab); if reload, !tab.isHome { tab.reload() } }
    }

    /// Recompile the ad-block rule list, then re-apply config to all tabs.
    func recompileAndReconfigure(reload: Bool) {
        guard let settings, let adblock else { return }
        adblock.compile(enabled: settings.adBlockEnabled) { [weak self] in
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

    func close(_ tab: WebTab) {
        tab.stop()
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
            for tab in tabs { tab.configure(privacy: settings.privacyConfig(incognito: incognito), ruleList: adblock.ruleList, cosmeticJS: cosmetic, adblockEnabled: settings.adBlockEnabled) }
        }
    }

    func cancelPendingReport() { pendingReport = nil }

    // MARK: - Data clearing
    func clearWebsiteData(completion: @escaping () -> Void) {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(ofTypes: types, modifiedSince: .distantPast) { completion() }
    }
}
