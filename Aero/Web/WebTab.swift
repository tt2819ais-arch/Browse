import SwiftUI
import WebKit
import Combine

/// Forwards script messages to a target without creating a retain cycle.
final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(uc, didReceive: message)
    }
}

/// A single browser tab backed by its own WKWebView.
final class WebTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let id = UUID()
    let incognito: Bool

    @Published var title: String = "Новая вкладка"
    @Published var urlString: String = ""
    @Published var isLoading: Bool = false
    @Published var progress: Double = 0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isHome: Bool = true
    @Published var snapshot: UIImage? = nil
    var desktopWanted: Bool = false

    private(set) var webView: WKWebView!
    private let ucc = WKUserContentController()
    private var observers: [NSKeyValueObservation] = []

    // Cached config so newly added scripts survive reloads
    private var privacyConfig = PrivacyConfig()
    private var cosmeticScript: String = ""
    private var adblockEnabled = true
    private var currentRuleLists: [WKContentRuleList] = []

    // Callbacks
    var onCommit: ((WebTab) -> Void)?
    var onCreateTab: ((URL) -> Void)?
    var onReportPick: ((_ host: String, _ selector: String, _ text: String) -> Void)?

    init(incognito: Bool = false, desktopMode: Bool = false) {
        self.incognito = incognito
        self.desktopWanted = desktopMode
        super.init()

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.websiteDataStore = incognito ? .nonPersistent() : .default()
        config.userContentController = ucc

        // Report-ad message handler (weak, no retain cycle)
        ucc.add(WeakScriptHandler(self), name: PrivacyScripts.reportHandler)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.customUserAgent = desktopMode ? Self.desktopUA : nil
        webView.isOpaque = true
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground

        setupObservers()
    }

    static let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15"

    private func setupObservers() {
        observers = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in self?.progress = wv.estimatedProgress },
            webView.observe(\.isLoading, options: [.new]) { [weak self] wv, _ in self?.isLoading = wv.isLoading },
            webView.observe(\.title, options: [.new]) { [weak self] wv, _ in if let t = wv.title, !t.isEmpty { self?.title = t } },
            webView.observe(\.url, options: [.new]) { [weak self] wv, _ in if let u = wv.url { self?.urlString = u.absoluteString } },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in self?.canGoBack = wv.canGoBack },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] wv, _ in self?.canGoForward = wv.canGoForward },
        ]
    }

    // MARK: - Privacy / Ad-block configuration
    func configure(privacy: PrivacyConfig, ruleLists: [WKContentRuleList], cosmeticJS: String, adblockEnabled: Bool) {
        self.privacyConfig = privacy
        self.cosmeticScript = cosmeticJS
        self.adblockEnabled = adblockEnabled
        self.currentRuleLists = ruleLists
        rebuildUserContent()
    }

    private func rebuildUserContent() {
        ucc.removeAllUserScripts()
        ucc.removeAllContentRuleLists()
        if adblockEnabled { currentRuleLists.forEach { ucc.add($0) } }

        let privJS = PrivacyScripts.buildJS(privacyConfig)
        if !privJS.isEmpty {
            ucc.addUserScript(WKUserScript(source: privJS, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }
        if !cosmeticScript.isEmpty {
            ucc.addUserScript(WKUserScript(source: cosmeticScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }
    }

    // MARK: - Report-ad mode
    func enterReportMode() { webView.evaluateJavaScript(PrivacyScripts.reportPickerJS, completionHandler: nil) }
    func exitReportMode() { webView.evaluateJavaScript(PrivacyScripts.reportExitJS, completionHandler: nil) }
    func hideSelector(_ selector: String) { webView.evaluateJavaScript(PrivacyScripts.hideSelectorJS(selector), completionHandler: nil) }

    func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == PrivacyScripts.reportHandler,
              let body = message.body as? [String: Any] else { return }
        let host = body["host"] as? String ?? "*"
        let selector = body["selector"] as? String ?? ""
        let text = body["text"] as? String ?? ""
        DispatchQueue.main.async { [weak self] in self?.onReportPick?(host, selector, text) }
    }

    // MARK: - Navigation API
    func load(_ url: URL) { isHome = false; webView.load(URLRequest(url: url)) }
    func loadRaw(_ raw: String, engine: SearchEngine) {
        guard let url = URLBuilder.make(from: raw, engine: engine) else { return }
        load(url)
    }
    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }
    func stop() { webView.stopLoading() }

    func goHome() {
        stop(); isHome = true; title = "Новая вкладка"; urlString = ""; progress = 0
    }

    func applyDesktop(_ on: Bool) {
        desktopWanted = on
        webView.customUserAgent = on ? Self.desktopUA : nil
        if !isHome, webView.url != nil { webView.reload() }
    }

    func captureSnapshot() {
        guard !isHome else { snapshot = nil; return }
        let cfg = WKSnapshotConfiguration()
        cfg.afterScreenUpdates = false
        webView.takeSnapshot(with: cfg) { [weak self] img, _ in if let img { self?.snapshot = img } }
    }

    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        if let u = webView.url { urlString = u.absoluteString }
        onCommit?(self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.captureSnapshot() }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, let scheme = url.scheme,
           !["http", "https", "about", "file"].contains(scheme.lowercased()) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    // MARK: - WKUIDelegate (target=_blank → new tab)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { onCreateTab?(url) }
        return nil
    }

    deinit {
        observers.forEach { $0.invalidate() }
        ucc.removeScriptMessageHandler(forName: PrivacyScripts.reportHandler)
    }
}

/// SwiftUI wrapper that hosts a tab's WKWebView with pull-to-refresh.
struct WebContainer: UIViewRepresentable {
    let tab: WebTab
    let onPull: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let wv = tab.webView!
        let rc = UIRefreshControl()
        rc.addTarget(context.coordinator, action: #selector(Coordinator.refresh(_:)), for: .valueChanged)
        wv.scrollView.refreshControl = rc
        context.coordinator.onPull = onPull
        return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) { context.coordinator.onPull = onPull }
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var onPull: (() -> Void)?
        @objc func refresh(_ rc: UIRefreshControl) {
            onPull?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { rc.endRefreshing() }
        }
    }
}
