import Foundation
import SwiftUI

// MARK: - Search engines
enum SearchEngine: String, CaseIterable, Codable, Identifiable {
    case google, duckduckgo, yandex, bing
    var id: String { rawValue }

    var title: String {
        switch self {
        case .google: return "Google"
        case .duckduckgo: return "DuckDuckGo"
        case .yandex: return "Яндекс"
        case .bing: return "Bing"
        }
    }

    var symbol: String {
        switch self {
        case .google: return "magnifyingglass.circle.fill"
        case .duckduckgo: return "shield.lefthalf.filled"
        case .yandex: return "y.circle.fill"
        case .bing: return "b.circle.fill"
        }
    }

    func searchURL(for query: String) -> URL? {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        switch self {
        case .google: return URL(string: "https://www.google.com/search?q=\(q)")
        case .duckduckgo: return URL(string: "https://duckduckgo.com/?q=\(q)")
        case .yandex: return URL(string: "https://yandex.ru/search/?text=\(q)")
        case .bing: return URL(string: "https://www.bing.com/search?q=\(q)")
        }
    }
}

// MARK: - Theme mode
enum ThemeMode: String, CaseIterable, Codable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "Системная"
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Bookmark
struct Bookmark: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var url: String
    var dateAdded = Date()
}

// MARK: - History
struct HistoryItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var url: String
    var date = Date()
}

// MARK: - User-reported ad rule (persisted)
struct ReportedAd: Identifiable, Codable, Equatable {
    var id = UUID()
    var host: String          // page host where reported (or "*")
    var selector: String      // CSS selector to hide
    var date = Date()
    var note: String = ""
}

// MARK: - Quick link (home screen)
struct QuickLink: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let symbol: String
    let tint: Color
}

// MARK: - Favorite (start page tile)
struct Favorite: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var url: String
}

// MARK: - Proxy
enum ProxyType: String, Codable, CaseIterable, Identifiable {
    case http, https, socks5
    var id: String { rawValue }
    var title: String {
        switch self {
        case .http: return "HTTP"
        case .https: return "HTTPS"
        case .socks5: return "SOCKS5"
        }
    }
}

/// A user-supplied proxy server. Routes WKWebView traffic on iOS 17+.
struct ProxyEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var label: String = ""
    var type: ProxyType = .http
    var host: String
    var port: Int
    var username: String = ""
    var password: String = ""

    var name: String { label.isEmpty ? "\(host):\(port)" : label }
    var display: String { "\(type.title) · \(host):\(port)" }
    var isValid: Bool { !host.isEmpty && port > 0 && port <= 65535 }

    /// Parse one line into a ProxyEntry. Accepts:
    ///  scheme://user:pass@host:port  |  scheme://host:port
    ///  host:port:user:pass           |  host:port
    static func parse(_ raw: String) -> ProxyEntry? {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !line.hasPrefix("#") else { return nil }

        var type: ProxyType = .http
        // scheme prefix
        if let r = line.range(of: "://") {
            let scheme = line[line.startIndex..<r.lowerBound].lowercased()
            switch scheme {
            case "socks5", "socks", "socks5h": type = .socks5
            case "https": type = .https
            default: type = .http
            }
            line = String(line[r.upperBound...])
        }

        var user = "", pass = "", host = "", portStr = ""

        if line.contains("@") {
            // user:pass@host:port
            let parts = line.split(separator: "@", maxSplits: 1).map(String.init)
            let creds = parts[0].split(separator: ":", maxSplits: 1).map(String.init)
            user = creds.first ?? ""
            pass = creds.count > 1 ? creds[1] : ""
            let hp = parts.count > 1 ? parts[1] : ""
            let hpParts = hp.split(separator: ":").map(String.init)
            host = hpParts.first ?? ""
            portStr = hpParts.count > 1 ? hpParts[1] : ""
        } else {
            // host:port[:user:pass]
            let parts = line.split(separator: ":").map(String.init)
            guard parts.count >= 2 else { return nil }
            host = parts[0]
            portStr = parts[1]
            if parts.count >= 4 { user = parts[2]; pass = parts[3] }
        }

        guard !host.isEmpty, let port = Int(portStr), port > 0, port <= 65535 else { return nil }
        return ProxyEntry(type: type, host: host, port: port, username: user, password: pass)
    }
}

// MARK: - URL helpers
enum URLBuilder {
    /// Turn raw user input into a URL: detect if it's a URL or a search query.
    static func make(from raw: String, engine: SearchEngine) -> URL? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if text.hasPrefix("http://") || text.hasPrefix("https://") {
            return URL(string: text)
        }

        let looksLikeDomain = !text.contains(" ")
            && text.contains(".")
            && !text.hasPrefix(".")
            && !text.hasSuffix(".")
        if looksLikeDomain {
            if let u = URL(string: "https://\(text)"), u.host != nil {
                return u
            }
        }

        if text == "localhost" || text.range(of: #"^\d{1,3}(\.\d{1,3}){3}"#, options: .regularExpression) != nil {
            return URL(string: "http://\(text)")
        }

        return engine.searchURL(for: text)
    }

    static func prettyHost(_ urlString: String) -> String {
        guard let u = URL(string: urlString), let host = u.host else { return urlString }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
