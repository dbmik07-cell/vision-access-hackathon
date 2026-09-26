import SwiftUI
import WebKit

/// Browser con pochi controlli grandi: barra indirizzo in alto, barra Liquid Glass in basso.
struct BrowserView: View {
    @Environment(AppModel.self) private var app
    @State private var model = BrowserModel()
    @FocusState private var addressFocused: Bool
    private var tracker = FaceDistanceTracker.shared

    var body: some View {
        let look = app.appearance
        VStack(spacing: 0) {
            topBar(look)
            ZStack(alignment: .topTrailing) {
                WebViewContainer(webView: model.webView)
                    .opacity(model.showStart ? 0 : 1)
                if model.showStart {
                    StartPage(model: model).environment(app)
                }
                if !model.showStart, model.adapted {
                    // Indicatore per la demo: distanza e dimensione del testo in tempo reale.
                    Text("\(Int(tracker.effectiveCM.rounded())) cm · \(Int(model.appliedFontPx.rounded())) pt")
                        .font(.ipo(.footnote, bold: true)).monospacedDigit()
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .glassEffect(.regular, in: .capsule)
                        .padding(8)
                        .allowsHitTesting(false)
                }
                if let error = model.loadError {
                    VStack(spacing: 16) {
                        Text(error).font(.ipo(.title3, bold: true)).multilineTextAlignment(.center)
                        BigButton(title: "Pagine salvate", systemImage: "tray.full") { model.goHome() }
                    }
                    .padding(24)
                    .glassEffect(.regular, in: .rect(cornerRadius: 28))
                    .padding()
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar(look) }
        .foregroundStyle(look.foreground)
        .background(look.background.ignoresSafeArea())
        .tint(look.accent)
        .onAppear {
            model.update(profile: app.effectiveProfile)
            model.startFollowingDistance()
            #if DEBUG
            if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-offline"),
               i + 1 < ProcessInfo.processInfo.arguments.count,
               let page = OfflinePage(rawValue: "offline-" + ProcessInfo.processInfo.arguments[i + 1]) {
                model.open(page)
            }
            #endif
        }
        .onDisappear { model.stopFollowingDistance() }
        .onChange(of: app.effectiveProfile.map(ProfileStore.json) ?? "") { _, _ in
            model.update(profile: app.effectiveProfile)
        }
    }

    private func topBar(_ look: AppAppearance) -> some View {
        HStack(spacing: 10) {
            Button { model.goHome() } label: {
                Image(systemName: "house.fill").font(.title2).frame(width: 50, height: 50)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Pagina iniziale")

            TextField("Cerca o scrivi un indirizzo", text: $model.addressText)
                .font(.ipo(.title3))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .focused($addressFocused)
                .onSubmit { model.submit(model.addressText) }
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .glassEffect(.regular.interactive(), in: .capsule)

            Menu {
                Button("Ecco come vedi", systemImage: "eye") { app.route = .results }
                Button("Testo più grande", systemImage: "plus.magnifyingglass") { adjustText(+0.1) }
                Button("Testo più piccolo", systemImage: "minus.magnifyingglass") { adjustText(-0.1) }
                Button("Impostazioni", systemImage: "gearshape") { app.showSettings = true }
            } label: {
                Image(systemName: "ellipsis").font(.title2).frame(width: 50, height: 50)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Altro")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func bottomBar(_ look: AppAppearance) -> some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                barButton("chevron.backward", label: "Indietro", enabled: model.canGoBack || model.showStart && model.webView.url != nil) { model.goBack() }
                barButton("chevron.forward", label: "Avanti", enabled: model.canGoForward) { model.goForward() }
                barButton(model.isLoading ? "xmark" : "arrow.clockwise", label: "Ricarica", enabled: !model.showStart) {
                    model.isLoading ? model.webView.stopLoading() : model.reload()
                }
                Button {
                    model.adapted.toggle()
                    Voice.shared.say(model.adapted ? "Pagina adattata per te" : "Pagina originale")
                    Haptics.tick()
                } label: {
                    Text(model.adapted ? "Per me" : "Originale")
                        .font(.ipo(.title3, bold: true))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(minWidth: 110, minHeight: 56)
                }
                .buttonStyle(.glassProminent)
                .tint(model.adapted ? look.accent : .gray)
                .accessibilityLabel(model.adapted ? "Pagina adattata. Tocca per l'originale" : "Pagina originale. Tocca per adattarla")
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 4)
    }

    private func barButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title2.bold()).frame(width: 56, height: 56)
        }
        .buttonStyle(.glass)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// R10: correzione manuale a passi di 0,1 logMAR, salvata nel profilo.
    private func adjustText(_ delta: Double) {
        var p = app.profile ?? VisualProfile()
        p.userAdjustments.textSizeOffsetLogMAR = ((p.userAdjustments.textSizeOffsetLogMAR + delta) * 10).rounded() / 10
        app.profile = p
        let count = UserDefaults.standard.integer(forKey: "enlargeCount") + (delta > 0 ? 1 : 0)
        UserDefaults.standard.set(count, forKey: "enlargeCount")
        if delta > 0, count >= 4, count % 4 == 0 {
            Voice.shared.say("Ingrandisci spesso il testo. Forse conviene rifare il test.")
        }
    }
}

/// Pagina iniziale: siti di esempio e pagine salvate per la demo senza rete.
struct StartPage: View {
    @Environment(AppModel.self) private var app
    var model: BrowserModel

    private let sites: [(String, String, String)] = [
        ("Google", "magnifyingglass", "https://www.google.com"),
        ("Corriere", "newspaper", "https://www.corriere.it"),
        ("Trenitalia", "tram", "https://www.trenitalia.com"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Dove vuoi andare?").font(.ipo(.largeTitle, bold: true))
                ForEach(sites, id: \.0) { site in
                    BigButton(title: site.0, systemImage: site.1, prominent: false) {
                        if let url = URL(string: site.2) { model.load(url) }
                    }
                }
                Text("Pagine salvate (funzionano senza rete)").font(.ipo(.title3, bold: true)).padding(.top, 8)
                ForEach(OfflinePage.allCases) { page in
                    BigButton(title: page.title, systemImage: page.icon, prominent: false) { model.open(page) }
                }
                if app.profile == nil {
                    BigButton(title: "Fai il test della vista", systemImage: "eye.fill") { app.startTest() }
                        .padding(.top, 8)
                }
            }
            .padding(20)
        }
    }
}
