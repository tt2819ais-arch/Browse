import Foundation

// MARK: - Full backup payload (JSON)
struct BrowserBackup: Codable {
    var app: String = "Aero"
    var version: Int = 1
    var exported: Date = Date()
    var bookmarks: [Bookmark]
    var history: [HistoryItem]
    var tabs: [String]
}

// MARK: - Result of parsing an imported file / clipboard
struct ImportResult {
    var bookmarks: [(title: String, url: String)] = []
    var history: [HistoryItem] = []
    var tabs: [URL] = []
    var isBackup: Bool = false
    var summary: String = ""
    var isEmpty: Bool { bookmarks.isEmpty && history.isEmpty && tabs.isEmpty }
}

enum ImportExport {

    // MARK: - Export builders

    /// Netscape bookmark file — importable by Safari, Chrome, Firefox, Edge.
    static func bookmarksHTML(_ bookmarks: [Bookmark]) -> String {
        var s = """
        <!DOCTYPE NETSCAPE-Bookmark-file-1>
        <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
        <TITLE>Bookmarks</TITLE>
        <H1>Aero Bookmarks</H1>
        <DL><p>

        """
        for b in bookmarks {
            let ts = Int(b.dateAdded.timeIntervalSince1970)
            s += "    <DT><A HREF=\"\(escapeAttr(b.url))\" ADD_DATE=\"\(ts)\">\(escapeText(b.title))</A>\n"
        }
        s += "</DL><p>\n"
        return s
    }

    /// Full backup as pretty JSON data.
    static func backupJSON(bookmarks: [Bookmark], history: [HistoryItem], tabs: [String]) -> Data {
        let backup = BrowserBackup(bookmarks: bookmarks, history: history, tabs: tabs)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return (try? enc.encode(backup)) ?? Data()
    }

    /// Write a string/data to a temp file and return its URL (for the share sheet).
    static func writeTemp(name: String, data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }
    static func writeTemp(name: String, string: String) -> URL? {
        writeTemp(name: name, data: Data(string.utf8))
    }

    // MARK: - Import / parsing

    static func parse(url: URL) -> ImportResult {
        let ext = url.pathExtension.lowercased()
        guard let raw = try? Data(contentsOf: url) else { return ImportResult() }
        // Try JSON backup first
        if ext == "json" || looksLikeJSON(raw) {
            if let r = parseBackup(raw) { return r }
        }
        let text = String(data: raw, encoding: .utf8) ?? String(decoding: raw, as: UTF8.self)
        if ext == "html" || ext == "htm" || text.lowercased().contains("<a ") {
            return parseBookmarksHTML(text)
        }
        return parseURLList(text)
    }

    static func parseClipboard(_ text: String) -> ImportResult {
        parseURLList(text)
    }

    private static func looksLikeJSON(_ data: Data) -> Bool {
        guard let first = data.first(where: { !($0 == 0x20 || $0 == 0x0a || $0 == 0x0d || $0 == 0x09) }) else { return false }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }

    private static func parseBackup(_ data: Data) -> ImportResult? {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let b = try? dec.decode(BrowserBackup.self, from: data) else { return nil }
        var r = ImportResult()
        r.isBackup = true
        r.bookmarks = b.bookmarks.map { (title: $0.title, url: $0.url) }
        r.history = b.history
        r.tabs = b.tabs.compactMap { URL(string: $0) }
        r.summary = "Резервная копия: \(b.bookmarks.count) закладок, \(b.history.count) истории, \(b.tabs.count) вкладок"
        return r
    }

    private static func parseBookmarksHTML(_ html: String) -> ImportResult {
        var r = ImportResult()
        let pattern = #"<a[^>]*?href\s*=\s*"([^"]+)"[^>]*>(.*?)</a>"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return r }
        let ns = html as NSString
        let matches = re.matches(in: html, range: NSRange(location: 0, length: ns.length))
        for m in matches where m.numberOfRanges >= 3 {
            let href = unescape(ns.substring(with: m.range(at: 1)))
            var title = unescape(ns.substring(with: m.range(at: 2)))
            title = title.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard href.lowercased().hasPrefix("http") else { continue }
            r.bookmarks.append((title: title, url: href))
        }
        r.summary = "Закладки HTML: найдено \(r.bookmarks.count) ссылок"
        return r
    }

    private static func parseURLList(_ text: String) -> ImportResult {
        var r = ImportResult()
        var seen = Set<String>()
        // grab explicit URLs anywhere, plus bare lines that look like domains
        let detector = try? NSRegularExpression(pattern: #"https?://[^\s"'<>]+"#, options: [.caseInsensitive])
        let ns = text as NSString
        detector?.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            if let m { let u = ns.substring(with: m.range); if seen.insert(u).inserted { r.bookmarks.append((title: "", url: u)) } }
        }
        if r.bookmarks.isEmpty {
            for line in text.split(whereSeparator: { $0.isNewline }) {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.contains("."), !t.contains(" "), let u = URLBuilder.make(from: t, engine: .google),
                   u.scheme?.hasPrefix("http") == true, seen.insert(u.absoluteString).inserted {
                    r.bookmarks.append((title: "", url: u.absoluteString))
                }
            }
        }
        r.summary = "Список ссылок: найдено \(r.bookmarks.count)"
        return r
    }

    // MARK: - HTML escaping helpers
    private static func escapeAttr(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
    private static func escapeText(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
    private static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
         .replacingOccurrences(of: "&lt;", with: "<")
         .replacingOccurrences(of: "&gt;", with: ">")
         .replacingOccurrences(of: "&quot;", with: "\"")
         .replacingOccurrences(of: "&#39;", with: "'")
         .replacingOccurrences(of: "&#x27;", with: "'")
         .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
