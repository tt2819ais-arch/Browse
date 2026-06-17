import Foundation
import WebKit
import Combine

// MARK: - Block list manifest models
struct BlockFileRef: Decodable, Hashable { let file: String; let rules: Int }
struct BlockGroup: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let desc: String
    let rules: Int
    let files: [BlockFileRef]
}
struct BlockManifest: Decodable { let groups: [BlockGroup]; let total: Int }

/// Comprehensive, configurable ad/tracker blocking.
///  • Bundled filter lists (EasyList + EasyPrivacy + Annoyances + RU AdList),
///    converted to WKContentRuleList JSON and compiled on device (cached).
///  • Per-list toggles.
///  • Cosmetic CSS injection for base selectors + user "Report ad" rules.
final class AdBlockStore: ObservableObject {
    // Compiled network/cosmetic rule lists currently active
    @Published private(set) var ruleLists: [WKContentRuleList] = []
    @Published private(set) var compiling: Bool = false
    @Published private(set) var groups: [BlockGroup] = []
    @Published private(set) var totalRules: Int = 0
    @Published private(set) var activeRules: Int = 0

    // User "Report ad" selectors
    @Published var reported: [ReportedAd] = []

    private let key = "reportedAds.v1"
    static let version = "v12"   // bump to force recompile after list updates

    init() {
        loadManifest()
        loadReported()
    }

    // MARK: - Manifest
    private func loadManifest() {
        guard let url = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "Blocklists"),
              let data = try? Data(contentsOf: url),
              let m = try? JSONDecoder().decode(BlockManifest.self, from: data) else { return }
        groups = m.groups
        totalRules = m.total
    }

    // MARK: - Compile / rebuild active lists
    /// Compile (or load cached) the rule lists for the enabled groups, sequentially.
    func rebuild(masterEnabled: Bool, enabledGroups: Set<String>, completion: @escaping () -> Void = {}) {
        guard masterEnabled else {
            DispatchQueue.main.async { self.ruleLists = []; self.activeRules = 0; self.compiling = false; completion() }
            return
        }
        let active = groups.filter { enabledGroups.contains($0.id) }
        let files = active.flatMap { $0.files }
        let ruleCount = active.reduce(0) { $0 + $1.rules }
        guard !files.isEmpty, let store = WKContentRuleListStore.default() else {
            DispatchQueue.main.async { self.ruleLists = []; self.activeRules = 0; self.compiling = false; completion() }
            return
        }
        DispatchQueue.main.async { self.compiling = true }
        var collected: [WKContentRuleList] = []

        func step(_ i: Int) {
            if i >= files.count {
                DispatchQueue.main.async {
                    self.ruleLists = collected
                    self.activeRules = ruleCount
                    self.compiling = false
                    completion()
                }
                return
            }
            let ref = files[i]
            let base = (ref.file as NSString).deletingPathExtension
            let identifier = "aero-\(base)-\(Self.version)"
            store.lookUpContentRuleList(forIdentifier: identifier) { list, _ in
                if let list { collected.append(list); step(i + 1); return }
                guard let url = Bundle.main.url(forResource: base, withExtension: "json", subdirectory: "Blocklists"),
                      let json = try? String(contentsOf: url, encoding: .utf8) else { step(i + 1); return }
                store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json) { compiled, _ in
                    if let compiled { collected.append(compiled) }
                    step(i + 1)
                }
            }
        }
        step(0)
    }

    // MARK: - Reported rules persistence
    func loadReported() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ReportedAd].self, from: data) {
            reported = decoded
        }
    }
    func saveReported() {
        if let data = try? JSONEncoder().encode(reported) { UserDefaults.standard.set(data, forKey: key) }
    }
    func addReported(host: String, selector: String, note: String = "") {
        let clean = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard !reported.contains(where: { $0.host == host && $0.selector == clean }) else { return }
        reported.insert(ReportedAd(host: host, selector: clean, note: note), at: 0)
        saveReported()
    }
    func removeReported(at offsets: IndexSet) { reported.remove(atOffsets: offsets); saveReported() }
    func clearReported() { reported.removeAll(); saveReported() }

    // MARK: - Cosmetic filtering JS (base selectors + reported)
    func cosmeticJS(enabled: Bool, cosmetic: Bool) -> String {
        guard enabled && cosmetic else { return "" }
        var global = Self.baseSelectors
        var hostMap: [String: [String]] = [:]
        for r in reported {
            if r.host == "*" { global.append(r.selector) }
            else { hostMap[r.host, default: []].append(r.selector) }
        }
        let globalJSON = jsonStringArray(global)
        let hostJSON = jsonHostMap(hostMap)
        return """
        (function(){
          try {
            var GLOBAL = \(globalJSON);
            var HOSTMAP = \(hostJSON);
            var host = location.hostname.replace(/^www\\./,'');
            var sels = GLOBAL.slice();
            for (var k in HOSTMAP){ if(host.indexOf(k)>=0){ sels = sels.concat(HOSTMAP[k]); } }
            if(!sels.length) return;
            var css = sels.join(',') + '{display:none !important;visibility:hidden !important;height:0 !important;min-height:0 !important;}';
            var apply = function(){
              var s = document.getElementById('__aero_cosmetic__');
              if(!s){ s=document.createElement('style'); s.id='__aero_cosmetic__'; (document.head||document.documentElement).appendChild(s); }
              s.textContent = css;
            };
            apply();
            if(document.readyState==='loading'){ document.addEventListener('DOMContentLoaded', apply); }
          } catch(e){}
        })();
        """
    }

    private func jsonStringArray(_ arr: [String]) -> String {
        let items = arr.map { "\"" + $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
        return "[" + items.joined(separator: ",") + "]"
    }
    private func jsonHostMap(_ map: [String: [String]]) -> String {
        var parts: [String] = []
        for (k, v) in map {
            let key = "\"" + k.replacingOccurrences(of: "\"", with: "\\\"") + "\""
            parts.append(key + ":" + jsonStringArray(v))
        }
        return "{" + parts.joined(separator: ",") + "}"
    }

    // High-precision base cosmetic selectors (always-on supplement to the lists)
    static let baseSelectors: [String] = [
        "ins.adsbygoogle", ".adsbygoogle", "[id^=\"google_ads\"]", "[id^=\"div-gpt-ad\"]",
        "iframe[src*=\"doubleclick\"]", "iframe[src*=\"googlesyndication\"]", "iframe[src*=\"/ads/\"]",
        "iframe[id^=\"google_ads\"]", "[data-ad-slot]", "[data-ad-client]", "[data-adunit]",
        ".ad-banner", ".ad-container", ".ad-wrapper", ".ad-slot", ".ad-unit", ".ad-placeholder",
        ".advertisement", ".advert", ".adsbox", ".sponsored-content", ".banner-ads", ".outbrain",
        ".taboola", "[id^=\"taboola\"]", "[class^=\"trc_\"]", ".OUTBRAIN", "#ad_position_box",
        "ins.adsbygoogle[data-ad-status]", "div[aria-label=\"Реклама\"]", "div[aria-label=\"Advertisement\"]"
    ]
}
