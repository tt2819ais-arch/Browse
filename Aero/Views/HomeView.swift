import SwiftUI

struct HomeView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var browser: BrowserStore
    @EnvironmentObject var favorites: FavoriteStore
    @EnvironmentObject var history: HistoryStore

    let onOpen: (String) -> Void
    var onSearch: () -> Void = {}
    var onBookmarks: () -> Void = {}
    var onHistory: () -> Void = {}
    var onSettings: () -> Void = {}
    var onTabs: () -> Void = {}

    @State private var showAddFav = false

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    header
                    searchPill
                    favoritesSection
                    if !browser.recentlyClosed.isEmpty { recentlyClosedSection }
                    if !frequentHosts.isEmpty { frequentSection }
                    quickActions
                    Spacer(minLength: 24)
                }
                .padding(.top, 64)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showAddFav) {
            AddFavoriteView { title, url in favorites.add(title: title, url: url) }
        }
    }

    // MARK: - Background
    private var background: some View {
        Group {
            if settings.showWallpaper {
                ZStack {
                    WallpaperView(name: settings.wallpaper).ignoresSafeArea()
                    Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                    AeroColor.bg.opacity(0.35).ignoresSafeArea()
                }
            } else {
                AeroColor.bg.ignoresSafeArea()
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(AeroColor.accent, lineWidth: 4.5).frame(width: 54, height: 54)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AeroColor.accent)
                    .rotationEffect(.degrees(45))
            }
            Text(browser.incognito ? "Инкогнито" : "Aero")
                .font(.system(size: 26, weight: .bold)).foregroundStyle(AeroColor.textPrimary)
        }
    }

    // MARK: - Search pill (taps focus the real address bar)
    private var searchPill: some View {
        Button { Haptics.tap(); onSearch() } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .medium)).foregroundStyle(AeroColor.textTertiary)
                Text("Поиск или адрес сайта").font(.system(size: 16)).foregroundStyle(AeroColor.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 18).frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AeroColor.field))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AeroColor.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        }
        .buttonStyle(PressableStyle(scale: 0.99))
        .padding(.horizontal, 20)
    }

    // MARK: - Favorites
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Избранное")
            LazyVGrid(columns: cols, spacing: 18) {
                ForEach(favorites.items) { fav in
                    favTile(fav)
                }
                addTile
            }
            .padding(.horizontal, 18)
        }
    }

    private func favTile(_ fav: Favorite) -> some View {
        let brand = Brand.match(fav.url)
        return Button { Haptics.tap(); onOpen(fav.url) } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(brand.tint.opacity(0.16))
                        .frame(width: 62, height: 62)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AeroColor.stroke, lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                    if let symbol = brand.symbol {
                        Image(systemName: symbol).font(.system(size: 25, weight: .medium)).foregroundStyle(brand.tint)
                    } else {
                        Text(monogram(fav.title)).font(.system(size: 25, weight: .bold, design: .rounded)).foregroundStyle(brand.tint)
                    }
                }
                Text(fav.title).font(.system(size: 11, weight: .medium)).foregroundStyle(AeroColor.textSecondary).lineLimit(1)
            }
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            Button(role: .destructive) { favorites.remove(fav) } label: { Label("Удалить", systemImage: "trash") }
        }
    }

    private var addTile: some View {
        Button { Haptics.tap(); showAddFav = true } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AeroColor.card)
                        .frame(width: 62, height: 62)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AeroColor.stroke, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    Image(systemName: "plus").font(.system(size: 24, weight: .medium)).foregroundStyle(AeroColor.textTertiary)
                }
                Text("Добавить").font(.system(size: 11, weight: .medium)).foregroundStyle(AeroColor.textTertiary).lineLimit(1)
            }
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Recently closed
    private var recentlyClosedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Недавно закрытые")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(browser.recentlyClosed) { tab in
                        Button { Haptics.tap(); onOpen(tab.url) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill").font(.system(size: 15)).foregroundStyle(AeroColor.accent)
                                    Text(URLBuilder.prettyHost(tab.url)).font(.system(size: 11)).foregroundStyle(AeroColor.textTertiary).lineLimit(1)
                                }
                                Text(tab.title).font(.system(size: 13, weight: .medium)).foregroundStyle(AeroColor.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(12).frame(width: 168, height: 84, alignment: .topLeading)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AeroColor.card))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AeroColor.stroke, lineWidth: 1))
                        }
                        .buttonStyle(PressableStyle(scale: 0.98))
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    // MARK: - Frequently visited (top hosts from history)
    private var frequentHosts: [(host: String, url: String)] {
        var counts: [String: (count: Int, url: String)] = [:]
        for item in history.items.prefix(120) {
            let h = URLBuilder.prettyHost(item.url)
            guard !h.isEmpty else { continue }
            if let existing = counts[h] { counts[h] = (existing.count + 1, existing.url) }
            else { counts[h] = (1, item.url) }
        }
        return counts.sorted { $0.value.count > $1.value.count }.prefix(8).map { ($0.key, $0.value.url) }
    }

    private var frequentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Часто посещаемые")
            LazyVGrid(columns: cols, spacing: 18) {
                ForEach(frequentHosts, id: \.host) { item in
                    let brand = Brand.match(item.url)
                    Button { Haptics.tap(); onOpen(item.url) } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(brand.tint.opacity(0.16)).frame(width: 62, height: 62)
                                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AeroColor.stroke, lineWidth: 0.5))
                                if let s = brand.symbol { Image(systemName: s).font(.system(size: 24)).foregroundStyle(brand.tint) }
                                else { Text(monogram(item.host)).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(brand.tint) }
                            }
                            Text(item.host).font(.system(size: 11, weight: .medium)).foregroundStyle(AeroColor.textSecondary).lineLimit(1)
                        }
                    }.buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 18)
        }
    }

    // MARK: - Quick actions
    private var quickActions: some View {
        HStack(spacing: 10) {
            actionChip("star", "Закладки", onBookmarks)
            actionChip("clock", "История", onHistory)
            actionChip("square.on.square", "Вкладки", onTabs)
            actionChip("gearshape", "Настройки", onSettings)
        }
        .padding(.horizontal, 18)
    }

    private func actionChip(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 18, weight: .medium)).foregroundStyle(AeroColor.accent)
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(AeroColor.textSecondary)
            }
            .frame(maxWidth: .infinity).frame(height: 64)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AeroColor.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AeroColor.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(AeroColor.textPrimary).padding(.horizontal, 20)
    }

    private func monogram(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "?" : String(t.first!).uppercased()
    }
}

// MARK: - Brand mapping for tiles
struct Brand {
    let symbol: String?
    let tint: Color

    static func match(_ url: String) -> Brand {
        let host = URLBuilder.prettyHost(url).lowercased()
        switch true {
        case host.contains("google") && !host.contains("maps"): return Brand(symbol: "magnifyingglass", tint: Color(red: 0.26, green: 0.52, blue: 0.96))
        case host.contains("maps"):     return Brand(symbol: "map.fill", tint: Color(red: 0.25, green: 0.7, blue: 0.45))
        case host.contains("youtube"):  return Brand(symbol: "play.rectangle.fill", tint: Color(red: 0.9, green: 0.2, blue: 0.2))
        case host.contains("wikipedia"):return Brand(symbol: "book.fill", tint: Color(red: 0.4, green: 0.42, blue: 0.48))
        case host.contains("github"):   return Brand(symbol: "chevron.left.forwardslash.chevron.right", tint: Color(red: 0.3, green: 0.32, blue: 0.4))
        case host.contains("reddit"):   return Brand(symbol: "bubble.left.and.bubble.right.fill", tint: Color(red: 0.95, green: 0.4, blue: 0.15))
        case host == "x.com" || host.contains("twitter"): return Brand(symbol: "xmark", tint: Color(red: 0.2, green: 0.2, blue: 0.24))
        case host.contains("telegram"): return Brand(symbol: "paperplane.fill", tint: Color(red: 0.2, green: 0.6, blue: 0.92))
        case host.contains("instagram"):return Brand(symbol: "camera.fill", tint: Color(red: 0.83, green: 0.18, blue: 0.42))
        case host.contains("yandex"):   return Brand(symbol: "y.circle.fill", tint: Color(red: 0.9, green: 0.2, blue: 0.1))
        default:
            // deterministic color by host hash
            let palette: [Color] = [
                Color(red: 0.26, green: 0.52, blue: 0.96), Color(red: 0.55, green: 0.35, blue: 0.9),
                Color(red: 0.95, green: 0.45, blue: 0.2), Color(red: 0.2, green: 0.7, blue: 0.55),
                Color(red: 0.9, green: 0.3, blue: 0.45), Color(red: 0.3, green: 0.62, blue: 0.85)
            ]
            let idx = abs(host.hashValue) % palette.count
            return Brand(symbol: nil, tint: palette[idx])
        }
    }
}

// MARK: - Add favorite sheet
struct AddFavoriteView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (String, String) -> Void
    @State private var title = ""
    @State private var url = ""
    private var valid: Bool { !url.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                SheetBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        GroupCard(title: "Сайт") {
                            HStack { TextField("Адрес (example.com)", text: $url).font(.system(size: 15))
                                .keyboardType(.URL).autocorrectionDisabled().textInputAutocapitalization(.never) }
                                .foregroundStyle(AeroColor.textPrimary).padding(.vertical, 12).padding(.horizontal, 14)
                            RowDivider()
                            HStack { TextField("Название (необязательно)", text: $title).font(.system(size: 15)) }
                                .foregroundStyle(AeroColor.textPrimary).padding(.vertical, 12).padding(.horizontal, 14)
                        }
                        Button {
                            onAdd(title, url); Haptics.success(); dismiss()
                        } label: {
                            Text("Добавить").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(RoundedRectangle(cornerRadius: 14).fill(valid ? AeroColor.accent : AeroColor.textTertiary))
                        }.buttonStyle(PressableStyle()).disabled(!valid).padding(.horizontal, 16)
                        Spacer()
                    }.padding(.top, 10)
                }
                .navigationTitle("В избранное").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
            }
        }
    }
}
