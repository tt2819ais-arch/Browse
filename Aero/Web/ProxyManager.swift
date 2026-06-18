import Foundation
import Network
import WebKit

/// Routes WKWebView (and test) traffic through a user-supplied proxy.
///
/// Honest note: Apple only exposes per-WebView proxying via `ProxyConfiguration`
/// on iOS 17+. On iOS 16 there is no public API to proxy WKWebView traffic, so
/// the feature degrades gracefully and the UI tells the user it needs iOS 17.
enum ProxyManager {

    /// Whether the current OS can route WKWebView traffic through a proxy.
    static var isSupported: Bool {
        if #available(iOS 17.0, *) { return true }
        return false
    }

    /// Apply (or clear) a proxy on a website data store. No-op on iOS 16.
    static func apply(_ entry: ProxyEntry?, to store: WKWebsiteDataStore) {
        if #available(iOS 17.0, *) {
            if let entry, let cfg = makeConfig(entry) {
                store.proxyConfigurations = [cfg]
            } else {
                store.proxyConfigurations = []
            }
        }
    }

    @available(iOS 17.0, *)
    static func makeConfig(_ e: ProxyEntry) -> ProxyConfiguration? {
        guard e.isValid, let port = NWEndpoint.Port(rawValue: UInt16(e.port)) else { return nil }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(e.host), port: port)
        var cfg: ProxyConfiguration
        switch e.type {
        case .socks5:
            cfg = ProxyConfiguration(socksv5Proxy: endpoint)
        case .http, .https:
            cfg = ProxyConfiguration(httpCONNECTProxy: endpoint)
        }
        if !e.username.isEmpty {
            cfg.applyCredential(username: e.username, password: e.password)
        }
        return cfg
    }

    struct TestResult {
        var ok: Bool
        var ip: String?
        var ms: Int?
        var error: String?
    }

    /// Test a proxy by fetching the public IP through it. Reports the resulting IP + latency.
    static func test(_ e: ProxyEntry) async -> TestResult {
        guard #available(iOS 17.0, *) else {
            return TestResult(ok: false, ip: nil, ms: nil, error: "Требуется iOS 17 или новее")
        }
        guard let cfg = makeConfig(e) else {
            return TestResult(ok: false, ip: nil, ms: nil, error: "Неверный адрес прокси")
        }
        let conf = URLSessionConfiguration.ephemeral
        conf.proxyConfigurations = [cfg]
        conf.requestCachePolicy = .reloadIgnoringLocalCacheData
        conf.timeoutIntervalForRequest = 12
        conf.timeoutIntervalForResource = 14
        let session = URLSession(configuration: conf)
        guard let url = URL(string: "https://api.ipify.org?format=json") else {
            return TestResult(ok: false, ip: nil, ms: nil, error: "Внутренняя ошибка")
        }
        let start = Date()
        do {
            let (data, response) = try await session.data(from: url)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return TestResult(ok: false, ip: nil, ms: ms, error: "HTTP \(http.statusCode)")
            }
            var ip: String? = nil
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                ip = obj["ip"] as? String
            }
            return TestResult(ok: true, ip: ip, ms: ms, error: nil)
        } catch {
            return TestResult(ok: false, ip: nil, ms: nil, error: error.localizedDescription)
        }
    }
}
