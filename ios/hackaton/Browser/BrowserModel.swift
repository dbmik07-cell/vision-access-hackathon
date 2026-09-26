import SwiftUI
import WebKit
import Observation

enum BrowserContext {
    /// ppi dalla tabella e nativeScale letto a runtime (contratto, sezione 7).
    static func current() -> ViewingContext {
        ViewingContext(ppi: DeviceDisplay.ppi ?? 460, nativeScale: DeviceDisplay.nativeScale)
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
        case .trenitalia: "Orari dei treni"
        case .articolo: "Articolo di giornale"
        case .ricerca: "Risultati di una ricerca"
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
    var adapted = true {
        didSet {
            if !adapted { readerOn = false; bodyText = nil }
            refreshScripts(); applyToCurrentPage()
        }
    }
    /// "Reader": un paragrafo alla volta, solo se la persona lo accende. Si spegne cambiando pagina.
    var readerOn = false {
        didSet {
            guard readerOn != oldValue, adapted, !showStart else { return }
            js("typeof IpoView!=='undefined' && IpoView.setReader(\(readerOn))")
        }
    }
    /// Dimensione effettiva del testo del corpo dopo l'adattamento (da adapter.js); original = il sito era già più grande.
    private(set) var bodyText: (px: Double, original: Bool)?
    /// Estensioni post-MVP (R5 un paragrafo alla volta, R9 lettura grande) sopra il piano del contratto.
    var extensionsEnabled = true { didSet { if oldValue != extensionsEnabled { rebuildPlan() } } }
    var addressText = ""
    var pageTitle = ""
    /// Indirizzo della pagina mostrata, per il dominio nella barra in alto.
    var currentURL: URL?
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
        // Le barre sono sospese sopra la pagina: i margini li imposta setObscuredInsets.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        config.userContentController.add(WeakHandler(self), name: "ipoview")
        observations = [
            webView.observe(\.canGoBack) { [weak self] wv, _ in MainActor.assumeIsolated { self?.canGoBack = wv.canGoBack } },
            webView.observe(\.canGoForward) { [weak self] wv, _ in MainActor.assumeIsolated { self?.canGoForward = wv.canGoForward } },
            webView.observe(\.isLoading) { [weak self] wv, _ in MainActor.assumeIsolated { self?.isLoading = wv.isLoading } },
        ]
    }

    /// Dominio senza "www." ("google.com"); "Pagina salvata" per i file del bundle.
    var domain: String {
        guard let url = currentURL else { return "" }
        if url.isFileURL { return "Pagina salvata" }
        let host = url.host() ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// La pagina scorre sotto le barre ma inizia e finisce fuori da esse.
    func setObscuredInsets(top: CGFloat, bottom: CGFloat) {
        let insets = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
        guard webView.obscuredContentInsets != insets else { return }
        webView.obscuredContentInsets = insets
        // obscuredContentInsets non allunga lo scorrimento: servono anche i margini della scroll view,
        // altrimenti dopo uno scroll della pagina (es. scrollTo(0,0)) l'inizio resta sotto la barra
        webView.scrollView.contentInset = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
        webView.scrollView.verticalScrollIndicatorInsets = insets
    }

    // MARK: Profilo e piano

    @ObservationIgnored private var didChooseInitialMode = false

    func update(profile: VisualProfile?) {
        self.profile = profile
        rebuildPlan()
    }

    private func rebuildPlan() {
        let profile = self.profile
        // Vista nella norma (SPEC 6, caso A): nessun adattamento di default, resta disponibile "Per me".
        if !didChooseInitialMode, let profile {
            didChooseInitialMode = true
            if profile.summary.normalVision && profile.visualField?.source != .preset && profile.amsler?.source != .preset {
                adapted = false
            }
        }
        let base = profile ?? PresetProfiles.baseline(device: ProfileBuilder.device)
        var newPlan = RulesEngine.plan(profile: base, context: BrowserContext.current())
        if extensionsEnabled { Self.applyPostMVPExtensions(&newPlan, profile: base) }
        guard newPlan != plan else { return }
        plan = newPlan
        appliedFontPx = RulesEngine.fontSizeAtDistance(plan: newPlan, distanceMm: FaceDistanceTracker.shared.effectiveMM)
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
            js("typeof IpoView!=='undefined' && (IpoView.apply(\(plan.json())), IpoView.setFontSizePx(\(appliedFontPx)), IpoView.setReader(\(readerOn)))")
            if let b = plan.screen.brightness { ScreenBrightness.lock(b) }
        } else {
            js("typeof IpoView!=='undefined' && IpoView.reset()")
            ScreenBrightness.restore()
        }
    }

    /// Estensione post-MVP (fuori dai casi golden): R9 con meno di 12 caratteri per riga sullo schermo →
    /// nel Reader si tocca il paragrafo per ascoltarlo. Non cambia mai layout.mode: resta "normal" (contratto).
    static func applyPostMVPExtensions(_ plan: inout AdaptationPlan, profile: VisualProfile) {
        let screenCh = (Double(DeviceDisplay.screenSizePt.width) - 24)
            / (plan.text.fontSizeCssPx * (ContractParameters.fontZeroWidthEm + plan.text.letterSpacingEm))
        if screenCh < 12 {
            plan.speech.tapToSpeak = true
            if let wpm = profile.reading?.maxReadingSpeedWpm, profile.reading?.measured == true {
                plan.speech.rateWpm = min(220, max(80, wpm))
            }
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
                // ADR 0003: il piano è a 400 mm; a runtime si riscala per d / 400.
                let px = RulesEngine.fontSizeAtDistance(plan: plan, distanceMm: tracker.effectiveMM)
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
        currentURL = url
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
    }

    func open(_ page: OfflinePage) { if let url = page.url { load(url) } }

    func goHome() { readerOn = false; showStart = true; loadError = nil }
    func goBack() { if showStart { showStart = false } else { webView.goBack() } }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }

    // MARK: WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            self.currentURL = webView.url
            self.readerOn = false
            self.bodyText = nil
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
            case "bodyText":
                if let px = body["px"] as? Double, adapted {
                    bodyText = (px, body["original"] as? Bool ?? false)
                }
            case "readerUnavailable":
                readerOn = false
                Voice.shared.say("Su questa pagina il Reader non è disponibile.")
            case "pageshow":
                // Pagina tornata dalla cache avanti/indietro: stato di adapter.js vecchio → reset + apply una volta sola
                readerOn = false
                applyToCurrentPage()
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
