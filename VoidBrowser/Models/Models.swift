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
        case .google: return "magnifyingglass.circle"
        case .duckduckgo: return "shield.lefthalf.filled"
        case .yandex: return "y.circle"
        case .bing: return "b.circle"
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

    var homeHost: String {
        switch self {
        case .google: return "google.com"
        case .duckduckgo: return "duckduckgo.com"
        case .yandex: return "yandex.ru"
        case .bing: return "bing.com"
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

// MARK: - Quick link (home screen)
struct QuickLink: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let symbol: String
    let tint: Color
}

// MARK: - URL helpers
enum URLBuilder {
    /// Turn raw user input into a URL: detect if it's a URL or a search query.
    static func make(from raw: String, engine: SearchEngine) -> URL? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Already has a scheme
        if text.hasPrefix("http://") || text.hasPrefix("https://") {
            return URL(string: text)
        }

        // Looks like a domain: contains a dot, no spaces, valid host chars
        let looksLikeDomain = !text.contains(" ")
            && text.contains(".")
            && !text.hasPrefix(".")
            && !text.hasSuffix(".")
        if looksLikeDomain {
            if let u = URL(string: "https://\(text)"), u.host != nil {
                return u
            }
        }

        // localhost / IP
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
