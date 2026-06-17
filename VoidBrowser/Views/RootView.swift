import SwiftUI
import WebKit

enum ActiveSheet: Identifiable {
    case bookmarks, history, settings, menu
    var id: Int { hashValue }
}

struct RootView: View {
    @EnvironmentObject var browser: BrowserStore
    @EnvironmentObject var bookmarks: BookmarkStore
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var settings: SettingsStore

    @State private var sheet: ActiveSheet?
    @State private var addressText = ""
    @FocusState private var addressFocused: Bool
    @State private var shareURL: URL?

    var body: some View {
        ZStack {
            VoidBackground()

            // Web area / home
            ZStack {
                ForEach(browser.tabs) { tab in
                    ZStack {
                        if tab.isHome {
                            HomeView(onOpen: { open($0) })
                                .environmentObject(settings)
                        } else {
                            WebContainer(tab: tab, onPull: { tab.reload() })
                                .ignoresSafeArea(edges: .bottom)
                        }
                    }
                    .opacity(tab.id == browser.currentID ? 1 : 0)
                    .allowsHitTesting(tab.id == browser.currentID)
                }
            }
            .padding(.bottom, 92)

            VStack(spacing: 0) {
                progressBar
                Spacer()
                bottomBar
            }
        }
        .onAppear { wireCurrentTab() }
        .onChange(of: browser.currentID) { _ in wireCurrentTab() }
        .sheet(item: $sheet) { which in
            sheetView(which)
                .presentationDetents(which == .menu ? [.height(360)] : [.large, .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $browser.showTabsOverview) {
            TabsOverviewView(onNew: { browser.newTab(); browser.showTabsOverview = false })
                .environmentObject(browser)
        }
        .sheet(item: $shareURL) { url in
            ShareSheet(items: [url])
        }
    }

    // MARK: - Progress bar
    private var progressBar: some View {
        GeometryReader { geo in
            let p = browser.current?.progress ?? 0
            let loading = browser.current?.isLoading ?? false
            Rectangle()
                .fill(VoidColor.accent)
                .frame(width: geo.size.width * CGFloat(p))
                .opacity(loading && p < 1 ? 1 : 0)
                .animation(.easeOut(duration: 0.25), value: p)
                .shadow(color: VoidColor.accent.opacity(0.7), radius: 4)
        }
        .frame(height: 2.5)
    }

    // MARK: - Bottom bar
    private var bottomBar: some View {
        VStack(spacing: 10) {
            addressBar
            toolbar
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            VoidColor.bg.opacity(0.72)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        )
        .overlay(Rectangle().fill(VoidColor.stroke).frame(height: 1), alignment: .top)
    }

    private var addressBar: some View {
        HStack(spacing: 10) {
            Image(systemName: addressLeadingSymbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(addressFocused ? VoidColor.accent : VoidColor.textTertiary)

            ZStack(alignment: .leading) {
                // Editing field (always present so focus works, but visually hidden when not editing)
                TextField("", text: $addressText)
                    .font(.system(size: 16))
                    .foregroundStyle(VoidColor.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($addressFocused)
                    .tint(VoidColor.accent)
                    .onSubmit { commitAddress() }
                    .opacity(addressFocused ? 1 : 0)

                // Display layer (tappable) when not editing
                if !addressFocused {
                    Text(displayURL.isEmpty ? "Поиск или адрес сайта" : displayURL)
                        .font(.system(size: 16))
                        .foregroundStyle(displayURL.isEmpty ? VoidColor.textTertiary : VoidColor.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { beginEditing() }
                }
            }

            if addressFocused {
                Button { addressText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(VoidColor.textTertiary)
                }
            } else if browser.current?.isLoading == true {
                IconButton(symbol: "xmark", size: 14) { browser.current?.stop() }
                    .frame(width: 28, height: 28)
            } else if !(browser.current?.isHome ?? true) {
                IconButton(symbol: "arrow.clockwise", size: 15) { browser.current?.reload() }
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VoidColor.cardStrong)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(addressFocused ? VoidColor.accent.opacity(0.6) : VoidColor.stroke, lineWidth: 1)
        )
    }

    private func beginEditing() {
        addressText = browser.current?.urlString ?? ""
        addressFocused = true
    }

    private var toolbar: some View {
        HStack {
            IconButton(symbol: "chevron.left", enabled: browser.current?.canGoBack ?? false) {
                browser.current?.goBack()
            }
            Spacer()
            IconButton(symbol: "chevron.right", enabled: browser.current?.canGoForward ?? false) {
                browser.current?.goForward()
            }
            Spacer()
            IconButton(symbol: "square.and.arrow.up", enabled: !(browser.current?.isHome ?? true)) {
                if let s = browser.current?.urlString, let u = URL(string: s) { shareURL = u }
            }
            Spacer()
            // tabs button with count
            Button { Haptics.tap(); browser.current?.captureSnapshot(); browser.showTabsOverview = true } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(VoidColor.textPrimary, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    Text("\(browser.tabs.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(VoidColor.textPrimary)
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(PressableStyle())
            Spacer()
            IconButton(symbol: "ellipsis") { sheet = .menu }
        }
    }

    // MARK: - Helpers
    private var displayURL: String {
        guard let t = browser.current else { return "" }
        if t.isHome { return "" }
        return URLBuilder.prettyHost(t.urlString)
    }

    private var addressLeadingSymbol: String {
        if addressFocused { return "magnifyingglass" }
        if let s = browser.current?.urlString, s.hasPrefix("https") { return "lock.fill" }
        if browser.current?.isHome ?? true { return "magnifyingglass" }
        return "globe"
    }

    private func commitAddress() {
        let text = addressText
        addressFocused = false
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        browser.current?.loadRaw(text, engine: settings.engine)
    }

    private func open(_ urlString: String) {
        guard let url = URLBuilder.make(from: urlString, engine: settings.engine) else { return }
        browser.current?.load(url)
    }

    private func wireCurrentTab() {
        for tab in browser.tabs {
            tab.onCommit = { [weak history] t in
                history?.record(title: t.title, url: t.urlString)
            }
        }
        if browser.current?.desktopWanted != settings.desktopMode {
            browser.current?.applyDesktop(settings.desktopMode)
        }
    }

    @ViewBuilder
    private func sheetView(_ which: ActiveSheet) -> some View {
        switch which {
        case .bookmarks:
            BookmarksView(onOpen: { open($0); sheet = nil })
                .environmentObject(bookmarks)
        case .history:
            HistoryView(onOpen: { open($0); sheet = nil })
                .environmentObject(history)
        case .settings:
            SettingsView().environmentObject(settings).environmentObject(browser)
                .environmentObject(bookmarks).environmentObject(history)
        case .menu:
            MenuView(
                onBookmarks: { sheet = .bookmarks },
                onHistory: { sheet = .history },
                onSettings: { sheet = .settings },
                onToggleBookmark: {
                    if let t = browser.current, !t.isHome {
                        bookmarks.toggle(title: t.title, url: t.urlString)
                        Haptics.success()
                    }
                    sheet = nil
                },
                onNewTab: { browser.newTab(); sheet = nil },
                onShare: {
                    if let s = browser.current?.urlString, let u = URL(string: s) { shareURL = u }
                    sheet = nil
                },
                isBookmarked: browser.current.map { bookmarks.contains($0.urlString) } ?? false,
                canBookmark: !(browser.current?.isHome ?? true)
            )
        }
    }
}

// MARK: - Share sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

extension URL: Identifiable { public var id: String { absoluteString } }
