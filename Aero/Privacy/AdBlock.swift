import Foundation
import WebKit
import Combine

/// Aggressive but configurable ad/tracker blocking:
///  • WKContentRuleList — blocks network requests to known ad/tracker domains + ad URL paths
///  • Cosmetic filtering — injected CSS hides ad containers that slip through
///  • User-reported rules — selectors captured via "Report ad" are hidden forever
final class AdBlockStore: ObservableObject {
    @Published var reported: [ReportedAd] = []
    @Published private(set) var ruleList: WKContentRuleList?
    @Published private(set) var blockedSession: Int = 0   // soft counter (cosmetic hits)

    private let key = "reportedAds.v1"
    private let listID = "aero-adblock-v1"

    init() { loadReported() }

    // MARK: - Reported rules persistence
    func loadReported() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ReportedAd].self, from: data) {
            reported = decoded
        }
    }
    func saveReported() {
        if let data = try? JSONEncoder().encode(reported) {
            UserDefaults.standard.set(data, forKey: key)
        }
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

    // MARK: - Content rule list
    func compile(enabled: Bool, completion: @escaping () -> Void) {
        guard enabled else { ruleList = nil; completion(); return }
        let json = Self.buildRulesJSON()
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: listID, encodedContentRuleList: json
        ) { [weak self] list, error in
            DispatchQueue.main.async {
                if let list { self?.ruleList = list }
                completion()
            }
        }
    }

    /// Build the WKContentRuleList JSON from ad domains + ad URL path patterns.
    static func buildRulesJSON() -> String {
        var rules: [String] = []
        for d in adDomains {
            let esc = d.replacingOccurrences(of: ".", with: "\\\\.")
            // ^https?://(sub.)?domain  — blocks the domain and any subdomain
            let f = "^https?://([^/]+\\\\.)?\(esc)"
            rules.append("{\"action\":{\"type\":\"block\"},\"trigger\":{\"url-filter\":\"\(f)\",\"url-filter-is-case-sensitive\":false}}")
        }
        for p in pathPatterns {
            rules.append("{\"action\":{\"type\":\"block\"},\"trigger\":{\"url-filter\":\"\(p)\",\"url-filter-is-case-sensitive\":false}}")
        }
        return "[" + rules.joined(separator: ",") + "]"
    }

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

    // MARK: - High-precision base cosmetic selectors
    static let baseSelectors: [String] = [
        "ins.adsbygoogle", ".adsbygoogle", "[id^=\"google_ads\"]", "[id^=\"div-gpt-ad\"]",
        "iframe[src*=\"doubleclick\"]", "iframe[src*=\"googlesyndication\"]", "iframe[src*=\"/ads/\"]",
        "iframe[id^=\"google_ads\"]", "[data-ad-slot]", "[data-ad-client]", "[data-adunit]",
        ".ad-banner", ".ad-container", ".ad-wrapper", ".ad-slot", ".ad-unit", ".ad-placeholder",
        ".advertisement", ".advert", ".adsbox", ".sponsored-content", ".banner-ads", ".outbrain",
        ".taboola", "[id^=\"taboola\"]", "[class^=\"trc_\"]", ".OUTBRAIN", "#ad_position_box",
        "ins.adsbygoogle[data-ad-status]", "div[aria-label=\"Реклама\"]", "div[aria-label=\"Advertisement\"]"
    ]

    // MARK: - Ad URL path patterns
    static let pathPatterns: [String] = [
        "/pagead/", "/adservice/", "/adsystem/", "/adserver", "/banners?/", "/sponsorads/",
        "/doubleclick/", "/ad-iframe", "/adframe", "/popunder", "/pop-under"
    ]

    // MARK: - Curated ad/tracker domains (blocked entirely)
    static let adDomains: [String] = [
        "doubleclick.net", "googlesyndication.com", "googleadservices.com", "google-analytics.com",
        "googletagmanager.com", "googletagservices.com", "adservice.google.com", "pagead2.googlesyndication.com",
        "adsystem.com", "adnxs.com", "advertising.com", "adcolony.com", "adform.net", "adroll.com",
        "adsrvr.org", "amazon-adsystem.com", "criteo.com", "criteo.net", "outbrain.com", "taboola.com",
        "taboolasyndication.com", "rubiconproject.com", "pubmatic.com", "openx.net", "casalemedia.com",
        "moatads.com", "scorecardresearch.com", "quantserve.com", "quantcast.com", "exelator.com",
        "bluekai.com", "mathtag.com", "bidswitch.net", "smartadserver.com", "yieldmo.com",
        "contextweb.com", "gumgum.com", "sharethrough.com", "spotxchange.com", "spotx.tv",
        "teads.tv", "districtm.io", "indexww.com", "3lift.com", "triplelift.com", "media.net",
        "mgid.com", "revcontent.com", "propellerads.com", "popads.net", "popcash.net", "adsterra.com",
        "exoclick.com", "juicyads.com", "trafficjunky.com", "hilltopads.net", "yllix.com",
        "onclickads.net", "clickadu.com", "admaven.com", "mediavine.com", "ezoic.net", "ezoic.com",
        "sovrn.com", "lijit.com", "districtm.ca", "rfihub.com", "rlcdn.com", "agkn.com",
        "demdex.net", "everesttech.net", "adsymptotic.com", "tapad.com", "crwdcntrl.net",
        "turn.com", "mookie1.com", "adtechus.com", "adtech.de", "yieldlab.net", "improvedigital.com",
        "stickyadstv.com", "1rx.io", "loopme.com", "inmobi.com", "applovin.com", "unityads.unity3d.com",
        "chartboost.com", "vungle.com", "supersonicads.com", "ironsrc.com", "mopub.com",
        "facebook.com/tr", "connect.facebook.net", "ads-twitter.com", "analytics.twitter.com",
        "ads.yahoo.com", "advertising.yahoo.com", "adtago.s3.amazonaws.com", "amplitude.com",
        "mixpanel.com", "segment.com", "segment.io", "fullstory.com", "hotjar.com", "mouseflow.com",
        "crazyegg.com", "optimizely.com", "newrelic.com", "nr-data.net", "branch.io", "appsflyer.com",
        "kochava.com", "adjust.com", "singular.net", "yandex.ru/ads", "an.yandex.ru", "mc.yandex.ru",
        "top-fwz1.mail.ru", "ad.mail.ru", "rambler.ru/ads", "vk.com/rtrg", "ads.vk.com",
        "matomo.cloud", "chartbeat.com", "parsely.com", "permutive.com", "onesignal.com",
        "pushwoosh.com", "pushcrew.com", "izooto.com", "sendpulse.com", "carbonads.com",
        "buysellads.com", "adblade.com", "adsupply.com", "bidvertiser.com", "infolinks.com",
        "vidoomy.com", "smartyads.com", "adpushup.com", "adingo.jp", "cxense.com", "zergnet.com"
    ]
}
