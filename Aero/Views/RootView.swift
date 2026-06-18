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
    @EnvironmentObject var adblock: AdBlockStore
    @EnvironmentObject var proxies: ProxyStore

    @State private var sheet: ActiveSheet?
    @State private var addressText = ""
    @FocusState private var addressFocused: Bool
    @State private var shareItem: ShareItem?

    private var currentIndex: Int { browser.tabs.firstIndex { $0.id == browser.currentID } ?? 0 }

    var body: some View {
        ZStack {
            AeroColor.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Content area (web / home) — always sits ABOVE the toolbar
                ZStack {
                    ZStack {
                        ForEach(Array(browser.tabs.enumerated()), id: \.element.id) { idx, tab in
                            Group {
                                if tab.isHome {
                                    HomeView(onOpen: { open($0) },
                                             onSearch: { beginEditing() },
                                             onBookmarks: { sheet = .bookmarks },
                                             onHistory: { sheet = .history },
                                             onSettings: { sheet = .settings },
                                             onTabs: { browser.current?.captureSnapshot(); browser.showTabsOverview = true })
                                        .environmentObject(settings).environmentObject(browser)
                                } else {
                                    WebContainer(tab: tab, onPull: { tab.reload() })
                                }
                            }
                            .opacity(tab.id == browser.currentID ? 1 : 0)
                            .offset(x: CGFloat(idx - currentIndex) * UIScreen.main.bounds.width)
                            .allowsHitTesting(tab.id == browser.currentID)
                        }
                    }
                    .animation(AeroAnim.snappy, value: browser.currentID)

                    // Tap / drag anywhere on the page to close the keyboard
                    if addressFocused {
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture { dismissKeyboard() }
                            .highPriorityGesture(DragGesture(minimumDistance: 8).onChanged { _ in dismissKeyboard() })
                    }

                    VStack(spacing: 0) { progressBar; Spacer() }

                    if browser.reportMode { reportBanner }
                    if let p = browser.pendingReport { reportConfirmBar(p) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                bottomBar
            }
        }
        .onAppear { wireCurrentTab() }
        .onChange(of: browser.currentID) { _ in wireCurrentTab() }
        .sheet(item: $sheet) { which in
            sheetView(which)
                .presentationDetents(which == .menu ? [.height(470)] : [.large, .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $browser.showTabsOverview) {
            TabsOverviewView(onNew: { withAnimation(AeroAnim.spring) { browser.newTab() }; browser.showTabsOverview = false })
                .environmentObject(browser)
        }
        .sheet(item: $shareItem) { item in ShareSheet(items: [item.url]) }
    }

    // MARK: - Progress bar
    private var progressBar: some View {
        GeometryReader { geo in
            let p = browser.current?.progress ?? 0
            let loading = browser.current?.isLoading ?? false
            Rectangle()
                .fill(AeroColor.accent)
                .frame(width: geo.size.width * CGFloat(p))
                .opacity(loading && p < 1 ? 1 : 0)
                .animation(.easeOut(duration: 0.25), value: p)
        }
        .frame(height: 2.5)
    }

    // MARK: - Bottom bar
    private var bottomBar: some View {
        VStack(spacing: 9) {
            if browser.incognito { incognitoPill }
            addressBar
            toolbar
        }
        .padding(.horizontal, 12)
        .padding(.top, 9)
        .padding(.bottom, 4)
        .background(
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea(edges: .bottom)
        )
        .overlay(Rectangle().fill(AeroColor.stroke).frame(height: 1), alignment: .top)
        .gesture(
            DragGesture(minimumDistance: 24, coordinateSpace: .local)
                .onEnded { value in
                    let dx = value.translation.width, dy = value.translation.height
                    if dy < -50 && abs(dx) < 70 {
                        // Swipe up → open tab switcher
                        Haptics.soft()
                        browser.current?.captureSnapshot()
                        browser.showTabsOverview = true
                    } else if abs(dx) > 60 && abs(dy) < 45 {
                        // Horizontal swipe → switch tabs (Safari-like)
                        if dx < 0 { switchTab(1) } else { switchTab(-1) }
                    }
                }
        )
    }

    private func switchTab(_ delta: Int) {
        let target = currentIndex + delta
        guard target >= 0, target < browser.tabs.count else { return }
        Haptics.soft()
        browser.current?.captureSnapshot()
        withAnimation(AeroAnim.snappy) { browser.currentID = browser.tabs[target].id }
    }

    private var incognitoPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "eyeglasses").font(.system(size: 12, weight: .semibold))
            Text("Инкогнито").font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(AeroColor.accent)
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Capsule().fill(AeroColor.accentSoft))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var addressBar: some View {
        HStack(spacing: 10) {
            Image(systemName: addressLeadingSymbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(addressFocused ? AeroColor.accent : AeroColor.textTertiary)

            ZStack(alignment: .leading) {
                TextField("", text: $addressText)
                    .font(.system(size: 16))
                    .foregroundStyle(AeroColor.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($addressFocused)
                    .tint(AeroColor.accent)
                    .onSubmit { commitAddress() }
                    .opacity(addressFocused ? 1 : 0)

                if !addressFocused {
                    Text(displayURL.isEmpty ? "Поиск или адрес сайта" : displayURL)
                        .font(.system(size: 16))
                        .foregroundStyle(displayURL.isEmpty ? AeroColor.textTertiary : AeroColor.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { beginEditing() }
                }
            }

            if addressFocused {
                Button { addressText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AeroColor.textTertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AeroColor.field))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(addressFocused ? AeroColor.accent.opacity(0.6) : AeroColor.stroke, lineWidth: 1)
        )
        .animation(AeroAnim.snappy, value: addressFocused)
    }

    private func beginEditing() {
        addressText = browser.current?.urlString ?? ""
        addressFocused = true
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            toolbarButton("chevron.left", enabled: browser.current?.canGoBack ?? false) { browser.current?.goBack() }
            toolbarButton("chevron.right", enabled: browser.current?.canGoForward ?? false) { browser.current?.goForward() }
            if browser.current?.isLoading == true {
                toolbarButton("xmark", tint: AeroColor.accent) { browser.current?.stop() }
            } else {
                toolbarButton("arrow.clockwise", enabled: !(browser.current?.isHome ?? true)) { browser.current?.reload() }
            }
            toolbarButton("square.and.arrow.up", enabled: !(browser.current?.isHome ?? true)) {
                if let s = browser.current?.urlString, let u = URL(string: s) { shareItem = ShareItem(url: u) }
            }
            tabsButton
            toolbarButton("gearshape") { dismissKeyboard(); sheet = .settings }
            toolbarButton("ellipsis") { dismissKeyboard(); sheet = .menu }
        }
    }

    private func toolbarButton(_ symbol: String, enabled: Bool = true, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(enabled ? (tint ?? AeroColor.textPrimary) : AeroColor.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
    }

    private var tabsButton: some View {
        Button {
            Haptics.tap(); dismissKeyboard()
            browser.current?.captureSnapshot(); browser.showTabsOverview = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7).strokeBorder(AeroColor.textPrimary, lineWidth: 2).frame(width: 23, height: 23)
                Text("\(browser.tabs.count)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(AeroColor.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private func dismissKeyboard() {
        if addressFocused { addressFocused = false }
    }

    // MARK: - Report-ad UI
    private var reportBanner: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "hand.tap.fill").foregroundStyle(.white)
                Text("Нажмите на рекламу, которую нужно убрать").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Button { browser.setReportMode(false) } label: {
                    Text("Отмена").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Capsule().fill(AeroColor.accent))
            .padding(.horizontal, 14).padding(.top, 8)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(AeroAnim.spring, value: browser.reportMode)
    }

    private func reportConfirmBar(_ p: PendingReport) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.fill").foregroundStyle(AeroColor.accent)
                    Text("Пожаловаться на этот элемент?").font(.system(size: 15, weight: .semibold)).foregroundStyle(AeroColor.textPrimary)
                    Spacer()
                }
                if !p.text.isEmpty {
                    Text("«\(p.text)»").font(.system(size: 13)).foregroundStyle(AeroColor.textSecondary)
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(p.selector).font(.system(size: 11, design: .monospaced)).foregroundStyle(AeroColor.textTertiary)
                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 10) {
                    Button { browser.cancelPendingReport() } label: {
                        Text("Отмена").font(.system(size: 15, weight: .semibold)).foregroundStyle(AeroColor.textPrimary)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(AeroColor.field))
                    }.buttonStyle(PressableStyle())
                    Button { Haptics.success(); browser.confirmPendingReport() } label: {
                        Text("Пожаловаться").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(AeroColor.accent))
                    }.buttonStyle(PressableStyle())
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AeroColor.card))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AeroColor.stroke, lineWidth: 1))
            .padding(.horizontal, 14).padding(.bottom, 24)
            .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(AeroAnim.spring, value: browser.pendingReport)
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
            tab.onCommit = { [weak history, weak browser] t in
                if browser?.incognito == false { history?.record(title: t.title, url: t.urlString) }
                browser?.saveSession()
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
            BookmarksView(onOpen: { open($0); sheet = nil }).environmentObject(bookmarks)
        case .history:
            HistoryView(onOpen: { open($0); sheet = nil }).environmentObject(history)
        case .settings:
            SettingsView().environmentObject(settings).environmentObject(browser)
                .environmentObject(bookmarks).environmentObject(history).environmentObject(adblock)
                .environmentObject(proxies)
        case .menu:
            MenuView(
                onBookmarks: { sheet = .bookmarks },
                onHistory: { sheet = .history },
                onSettings: { sheet = .settings },
                onToggleBookmark: {
                    if let t = browser.current, !t.isHome { bookmarks.toggle(title: t.title, url: t.urlString); Haptics.success() }
                    sheet = nil
                },
                onNewTab: { withAnimation(AeroAnim.spring) { browser.newTab() }; sheet = nil },
                onShare: {
                    if let s = browser.current?.urlString, let u = URL(string: s) { shareItem = ShareItem(url: u) }
                    sheet = nil
                },
                onFind: {
                    sheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { browser.current?.presentFind() }
                },
                onReportAd: { sheet = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { browser.setReportMode(true) } },
                onToggleIncognito: { browser.setIncognito(!browser.incognito); sheet = nil },
                isIncognito: browser.incognito,
                isBookmarked: browser.current.map { bookmarks.contains($0.urlString) } ?? false,
                canBookmark: !(browser.current?.isHome ?? true),
                canFind: !(browser.current?.isHome ?? true),
                canReport: !(browser.current?.isHome ?? true)
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

struct ShareItem: Identifiable { let id = UUID(); let url: URL }
