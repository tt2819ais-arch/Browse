import Foundation
import Combine

/// Stores the user's proxy list, selection and on/off state (UserDefaults-backed).
final class ProxyStore: ObservableObject {
    @Published var items: [ProxyEntry] = []
    @Published var activeID: UUID? { didSet { d.set(activeID?.uuidString, forKey: activeKey) } }
    @Published var enabled: Bool { didSet { d.set(enabled, forKey: enabledKey) } }

    private let d = UserDefaults.standard
    private let listKey = "proxies.v1"
    private let activeKey = "proxies.active"
    private let enabledKey = "proxies.enabled"

    init() {
        enabled = d.bool(forKey: enabledKey)
        if let data = d.data(forKey: listKey),
           let decoded = try? JSONDecoder().decode([ProxyEntry].self, from: data) {
            items = decoded
        }
        if let s = d.string(forKey: activeKey) { activeID = UUID(uuidString: s) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { d.set(data, forKey: listKey) }
    }

    /// The proxy that should actually route traffic (nil if disabled or none selected).
    var active: ProxyEntry? {
        guard enabled, let id = activeID else { return nil }
        return items.first { $0.id == id }
    }

    func add(_ entry: ProxyEntry) {
        items.insert(entry, at: 0)
        if activeID == nil { activeID = entry.id }
        save()
    }

    func update(_ entry: ProxyEntry) {
        if let i = items.firstIndex(where: { $0.id == entry.id }) { items[i] = entry; save() }
    }

    func remove(at offsets: IndexSet) {
        let removed = offsets.map { items[$0].id }
        items.remove(atOffsets: offsets)
        if let a = activeID, removed.contains(a) { activeID = items.first?.id }
        save()
    }

    func remove(_ entry: ProxyEntry) {
        items.removeAll { $0.id == entry.id }
        if activeID == entry.id { activeID = items.first?.id }
        save()
    }

    func select(_ entry: ProxyEntry) { activeID = entry.id }

    func clear() { items.removeAll(); activeID = nil; save() }

    /// Import a multi-line block of proxies. Returns number of entries added.
    @discardableResult
    func importText(_ text: String) -> Int {
        let lines = text.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
        var added = 0
        for line in lines {
            guard let entry = ProxyEntry.parse(String(line)) else { continue }
            // skip exact duplicates
            if items.contains(where: { $0.host == entry.host && $0.port == entry.port && $0.type == entry.type && $0.username == entry.username }) { continue }
            items.append(entry)
            added += 1
        }
        if activeID == nil { activeID = items.first?.id }
        if added > 0 { save() }
        return added
    }

    func exportText() -> String {
        items.map { e -> String in
            let scheme = e.type.rawValue
            if e.username.isEmpty { return "\(scheme)://\(e.host):\(e.port)" }
            return "\(scheme)://\(e.username):\(e.password)@\(e.host):\(e.port)"
        }.joined(separator: "\n")
    }
}
