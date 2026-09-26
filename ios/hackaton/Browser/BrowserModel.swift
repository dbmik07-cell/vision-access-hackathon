import SwiftUI
import WebKit
import Observation

enum BrowserContext {
    static func current(distanceMM: Double? = nil) -> ViewingContext {
        ViewingContext(distanceMM: distanceMM ?? FaceDistanceTracker.shared.effectiveMM,
                       ppi: DeviceDisplay.ppi,
                       scale: DeviceDisplay.nativeScale,
                       screenWidthPt: Double(DeviceDisplay.screenSizePt.width))
    }
}

/// Pagine salvate nel bundle, per la demo senza Wi-Fi.
enum OfflinePage: String, CaseIterable, Identifiable {
    case trenitalia = "offline-trenitalia"
    case articolo = "offline-articolo"
    case ricerca = "offline-ricerca"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .trenitalia: "Orari treni (salvata)"
        case .articolo: "Articolo (salvato)"
        case .ricerca: "Ricerca (salvata)"
        }
    }
    var icon: String {
        switch self {
        case .trenitalia: "tram.fill"
        case .articolo: "newspaper.fill"
        case .ricerca: "magnifyingglass"
        }
    }
    var url: URL? { Bundle.main.url(forResource: rawValue, withExtension: "html") }
}

/// Browser: WKWebView + strato di adattamento (adapter.js).
@Observable
final class BrowserModel: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    @ObservationIgnored let webView: WKWebView
    var adapted = true { didSet { refreshScripts(); applyToCurrentPage() } }
    var addressText = ""
    var pageTitle = ""
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var showStart = true
    var loadError: String?
    /// Dimensione del testo applicata adesso (px CSS), per l'indicatore a schermo.
    private(set) var appliedFontPx: Double = 0
    private(set) var plan: AdaptationPlan?

    @ObservationIgnored private var profile: VisualProfile?
    @ObservationIgnored private var fontLoopTask: Task<Void, Never>?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    @ObservationIgnored private lazy var fontScript: WKUserScript = {
        func dataURL(_ name: String) -> String {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf"),
                  let data = try? Data(contentsOf: url) else { return "" }
            return "data:font/ttf;base64," + data.base64EncodedString()
        }
        let js = "window.__ipoFontDataURL='\(dataURL("AtkinsonHyperlegible-Regular"))';window.__ipoFontBoldDataURL='\(dataURL("AtkinsonHyperlegible-Bold"))';"
        return WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }()

    @ObservationIgnored private lazy var libraryScript: WKUserScript = {
        let names = ["Readability", "Readability-readerable", "adapter"]
        let js = names.compactMap { name -> String? in
            guard let url = Bundle.main.url(forResource: name, withExtension: "js") else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }.joined(separator: "\n;\n")
        return WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }()

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = true
        config.userContentController.add(WeakHandler(self), name: "ipoview")
        observations = [
            webView.observe(\.canGoBack) { [weak self] wv, _ in MainActor.assumeIsolated { self?.canGoBack = wv.canGoBack } },
            webView.observe(\.canGoForward) { [weak self] wv, _ in MainActor.assumeIsolated { self?.canGoForward = wv.canGoForward } },
            webView.observe(\.isLoading) { [weak self] wv, _ in MainActor.assumeIsolated { self?.isLoading = wv.isLoading } },
        ]
    }

    // MARK: Profilo e piano

    @ObservationIgnored private var didChooseInitialMode = false

    func update(profile: VisualProfile?) {
        self.profile = profile
        // Vista nella norma (SPEC 6, caso A): nessun adattamento di default, resta disponibile "Per me".
        if !didChooseInitialMode, let profile {
            didChooseInitialMode = true
            if profile.summary.normalVision && profile.visualField?.isPreset != true { adapted = false }
        }
        let newPlan = RulesEngine.plan(profile: profile, context: BrowserContext.current())
        guard newPlan != plan else { return }
        plan = newPlan
        appliedFontPx = newPlan.text.fontSizePx
        refreshScripts()
        applyToCurrentPage()
        if adapted, let b = newPlan.screen.brightness { ScreenBrightness.lock(b) }
    }

    /// Script iniettati in ogni pagina: font, librerie, e applicazione automatica del piano.
    private func refreshScripts() {
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.addUserScript(fontScript)
        ucc.addUserScript(libraryScript)
        if adapted, let plan {
            let auto = "try{IpoView.apply(\(plan.json()));IpoView.setFontSizePx(\(appliedFontPx));}catch(e){}"
            ucc.addUserScript(WKUserScript(source: auto, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
    }

    private func applyToCurrentPage() {
        guard !showStart, webView.url != nil else { return }
        if adapted, let plan {
            js("typeof IpoView!=='undefined' && (IpoView.apply(\(plan.json())), IpoView.setFontSizePx(\(appliedFontPx)))")
            if let b = plan.screen.brightness { ScreenBrightness.lock(b) }
        } else {
            js("typeof IpoView!=='undefined' && IpoView.reset()")
            ScreenBrightness.restore()
        }
    }

    // MARK: R1 in tempo reale: il testo segue la distanza del viso

    /// Ogni 100 ms ricalcola la dimensione dalla distanza filtrata.
    /// Isteresi: si ridisegna solo se la variazione supera l'8%.
    func startFollowingDistance() {
        FaceDistanceTracker.shared.start()
        fontLoopTask?.cancel()
        fontLoopTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, self.adapted, !self.showStart, let plan = self.plan else { continue }
                let tracker = FaceDistanceTracker.shared
                guard tracker.faceVisible || !FaceDistanceTracker.isSupported else { continue }
                let px = RulesEngine.fontSizePx(profile: self.profile, context: BrowserContext.current())
                _ = plan
                if self.appliedFontPx > 0, abs(px - self.appliedFontPx) / self.appliedFontPx > 0.08 {
                    self.appliedFontPx = px
                    self.js("typeof IpoView!=='undefined' && IpoView.setFontSizePx(\(px))")
                }
            }
        }
    }

    func stopFollowingDistance() {
        fontLoopTask?.cancel()
        FaceDistanceTracker.shared.stop()
        ScreenBrightness.restore()
    }

    private func js(_ source: String) { webView.evaluateJavaScript(source, completionHandler: nil) }

    // MARK: Navigazione

    func submit(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let url: URL?
        if text.contains(".") && !text.contains(" ") {
            url = URL(string: text.hasPrefix("http") ? text : "https://\(text)")
        } else {
            var comps = URLComponents(string: "https://www.google.com/search")!
            comps.queryItems = [URLQueryItem(name: "q", value: text)]
            url = comps.url
        }
        if let url { load(url) }
    }

    func load(_ url: URL) {
        showStart = false
        loadError = nil
        addressText = url.isFileURL ? "" : url.absoluteString
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
    }

    func open(_ page: OfflinePage) { if let url = page.url { load(url) } }

    func goHome() { showStart = true; loadError = nil }
    func goBack() { if showStart { showStart = false } else { webView.goBack() } }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }

    // MARK: WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            self.addressText = webView.url?.isFileURL == true ? "Pagina salvata" : (webView.url?.absoluteString ?? "")
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            self.pageTitle = webView.title ?? ""
            self.loadError = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        MainActor.assumeIsolated {
            let e = error as NSError
            if e.code != NSURLErrorCancelled {
                self.loadError = "La pagina non si carica (sei senza rete?). Puoi aprire una delle pagine salvate."
            }
        }
    }

    /// Link con target=_blank: aperti nella stessa vista.
    nonisolated func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                             for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }

    // MARK: Messaggi da adapter.js

    nonisolated func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            switch type {
            case "speak":
                let text = body["text"] as? String ?? ""
                let wpm = body["rateWpm"] as? Double ?? plan?.speech.rateWpm ?? 140
                Voice.shared.read(text, wpm: wpm)
            case "log":
                print("[adapter.js]", body["message"] ?? "")
            default:
                break
            }
        }
    }
}

/// Evita il ciclo di riferimenti tra WKUserContentController e il modello.
final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    nonisolated func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated { target?.userContentController(ucc, didReceive: message) }
    }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
