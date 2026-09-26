import SwiftUI
import WebKit

/// Browser con pochi controlli grandi: due capsule Liquid Glass sospese sopra la pagina.
struct BrowserView: View {
    @Environment(AppModel.self) private var app
    @State private var model = BrowserModel()
    @State private var editingAddress = false
    /// Bordo inferiore della barra in alto e bordo superiore di quella in basso, in coordinate della finestra.
    @State private var topBarMaxY: CGFloat = 0
    @State private var bottomBarMinY: CGFloat = 0
    @FocusState private var addressFocused: Bool
    private var tracker = FaceDistanceTracker.shared

    var body: some View {
        let look = app.appearance
        ZStack {
            // La pagina scorre sotto le barre; i margini della webview le tengono libere.
            WebViewContainer(webView: model.webView)
                .ignoresSafeArea()
                .opacity(model.showStart ? 0 : 1)
            if model.showStart {
                StartPage(model: model).environment(app)
            }
            if let error = model.loadError {
                VStack(spacing: 16) {
                    Text(error).font(.ipo(.title3, bold: true)).multilineTextAlignment(.center)
                    BigButton(title: "Pagine salvate", systemImage: "tray.full") { model.goHome() }
                }
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 28).fill(look.card))
                .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(look.hairline))
                .padding()
                .frame(maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar(look)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { topBarMaxY = $0 }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar(look)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { bottomBarMinY = $0 }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .foregroundStyle(look.foreground)
        .background(look.background.ignoresSafeArea())
        .tint(look.accent)
        .onChange(of: topBarMaxY) { _, _ in updateInsets() }
        .onChange(of: bottomBarMinY) { _, _ in updateInsets() }
        .onAppear {
            model.extensionsEnabled = app.postMVPExtensions
            model.update(profile: app.effectiveProfile)
            model.startFollowingDistance()
            updateInsets()
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-offline"), i + 1 < args.count,
               let page = OfflinePage(rawValue: "offline-" + args[i + 1]) {
                model.open(page)
            }
            if let i = args.firstIndex(of: "-url"), i + 1 < args.count, let url = URL(string: args[i + 1]) {
                model.load(url)
            }
            if args.contains("-perMe") { model.adapted = true }
            if args.contains("-reader") {
                Task { try? await Task.sleep(for: .seconds(6)); model.readerOn = true }
            }
            #endif
        }
        .onDisappear { model.stopFollowingDistance() }
        .onChange(of: app.effectiveProfile.map(ProfileStore.json) ?? "") { _, _ in
            model.update(profile: app.effectiveProfile)
        }
        .onChange(of: app.postMVPExtensions) { _, v in model.extensionsEnabled = v }
        .onChange(of: addressFocused) { _, focused in if !focused { editingAddress = false } }
    }

    private func updateInsets() {
        let screenHeight = DeviceDisplay.screenSizePt.height
        model.setObscuredInsets(top: max(0, topBarMaxY),
                                bottom: bottomBarMinY > 0 ? max(0, screenHeight - bottomBarMinY) : 0)
    }

    // MARK: Barra in alto: casa, dominio, altro

    private func topBar(_ look: AppAppearance) -> some View {
        HStack(spacing: 0) {
            iconButton("house.fill", label: "Pagina iniziale") {
                editingAddress = false
                model.goHome()
            }
            if editingAddress {
                TextField("Indirizzo", text: $model.addressText,
                          prompt: Text("Cerca o scrivi un indirizzo").foregroundStyle(look.secondary))
                    .font(.ipo(.title3))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($addressFocused)
                    .onSubmit {
                        model.submit(model.addressText)
                        editingAddress = false
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .onAppear { addressFocused = true }
                iconButton("xmark", label: "Chiudi la ricerca") { editingAddress = false }
            } else {
                Button {
                    model.addressText = model.showStart || model.currentURL?.isFileURL == true
                        ? "" : (model.currentURL?.absoluteString ?? "")
                    editingAddress = true
                } label: {
                    domainLabel
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.showStart || model.domain.isEmpty ? "Cerca o scrivi un indirizzo" : "Pagina \(model.domain)")
                .accessibilityHint("Tocca per cercare o scrivere un indirizzo")

                if !model.showStart { readerButton(look) }

                Menu {
                    Button("Ecco come vedi", systemImage: "eye") { app.route = .results }
                    Button("Testo più grande", systemImage: "plus.magnifyingglass") { adjustText(+0.1) }
                    Button("Testo più piccolo", systemImage: "minus.magnifyingglass") { adjustText(-0.1) }
                    Button("Impostazioni", systemImage: "gearshape") { app.showSettings = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title2.weight(.semibold))
                        .frame(width: 56, height: 56)
                        .contentShape(.circle)
                }
                .accessibilityLabel("Altro")
            }
        }
        .padding(4)
        .glassBar(look, in: .capsule)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// "Reader": un paragrafo alla volta, solo se la persona lo tocca; un secondo tocco torna alla pagina.
    private func readerButton(_ look: AppAppearance) -> some View {
        Button {
            model.readerOn.toggle()
            Haptics.tick()
        } label: {
            Image(systemName: "doc.plaintext")
                .font(.title2.weight(.semibold))
                .foregroundStyle(model.readerOn ? look.onAccent : look.foreground)
                .frame(width: 48, height: 48)
                .background { if model.readerOn { Circle().fill(look.accent) } }
                .frame(width: 56, height: 56)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(!model.adapted)
        .opacity(model.adapted ? 1 : 0.35)
        .accessibilityLabel("Reader, un paragrafo alla volta")
        .accessibilityAddTraits(model.readerOn ? .isSelected : [])
        .accessibilityHint(model.adapted ? "" : "Disponibile con Per me")
    }

    @ViewBuilder private var domainLabel: some View {
        if model.showStart || model.domain.isEmpty {
            Label("Cerca", systemImage: "magnifyingglass")
                .font(.ipo(.title3, bold: true))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Text(model.domain)
                .font(.ipo(.title3, bold: true))
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: Barra in basso: navigazione e interruttore "Originale | Per me"

    private func bottomBar(_ look: AppAppearance) -> some View {
        let showDistance = app.demoMode || app.showDistance
        // Una riga se ci sta, altrimenti l'interruttore va su una seconda riga: niente viene tagliato.
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                navButtons
                if showDistance { distanceLabel(stacked: false).padding(.horizontal, 6) }
                Spacer(minLength: 4)
                modeToggle(look, expand: false)
            }
            .padding(4)
            .glassBar(look, in: .capsule)

            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    navButtons
                    Spacer(minLength: 8)
                    if showDistance { distanceLabel(stacked: true).padding(.trailing, 14) }
                }
                modeToggle(look, expand: true)
            }
            .padding(4)
            .glassBar(look, in: .rect(cornerRadius: 32))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var navButtons: some View {
        HStack(spacing: 0) {
            iconButton("chevron.backward", label: "Indietro",
                       enabled: model.canGoBack || model.showStart && model.webView.url != nil) { model.goBack() }
            iconButton("chevron.forward", label: "Avanti", enabled: model.canGoForward) { model.goForward() }
            iconButton(model.isLoading ? "xmark" : "arrow.clockwise", label: model.isLoading ? "Ferma" : "Ricarica",
                       enabled: !model.showStart) {
                model.isLoading ? model.webView.stopLoading() : model.reload()
            }
        }
    }

    /// "34 cm · 18 pt": distanza e dimensione effettiva del testo del corpo dopo l'adattamento.
    /// Sulla barra a due righe le due parti vanno una sotto l'altra, così i pulsanti restano nella capsula.
    private func distanceLabel(stacked: Bool) -> some View {
        let cm = tracker.faceVisible || !FaceDistanceTracker.isSupported ? "\(Int(tracker.effectiveCM.rounded())) cm" : "– cm"
        let size: String? = model.showStart || !model.adapted ? nil : model.bodyText.map {
            $0.original ? "original size" : "\(Int($0.px.rounded())) pt"
        }
        return Text(size.map { stacked ? "\(cm)\n\($0)" : "\(cm) · \($0)" } ?? cm)
            .multilineTextAlignment(.trailing)
            .font(.ipo(.subheadline, bold: true))
            .monospacedDigit()
            .lineLimit(2)
            .fixedSize()
            .accessibilityLabel("Distanza dal viso e dimensione del testo")
            .accessibilityValue("\(Int(tracker.effectiveCM.rounded())) centimetri" + (size.map { ", testo \($0)" } ?? ""))
    }

    private func modeToggle(_ look: AppAppearance, expand: Bool) -> some View {
        HStack(spacing: 0) {
            segment("Originale", selected: !model.adapted, look: look, expand: expand) { setAdapted(false) }
            segment("Per me", selected: model.adapted, look: look, expand: expand) { setAdapted(true) }
        }
        .background(Capsule().fill(look.foreground.opacity(0.07)))
        .animation(.snappy(duration: 0.2), value: model.adapted)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Aspetto della pagina")
    }

    private func segment(_ title: String, selected: Bool, look: AppAppearance, expand: Bool,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.ipo(.headline, bold: true))
                .lineLimit(1)
                .fixedSize(horizontal: !expand, vertical: false)
                .foregroundStyle(selected ? look.onAccent : look.foreground)
                .padding(.horizontal, 10)
                .frame(maxWidth: expand ? .infinity : nil, minHeight: 56)
                .background { if selected { Capsule().fill(look.accent) } }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func setAdapted(_ value: Bool) {
        guard model.adapted != value else { return }
        model.adapted = value
        Voice.shared.say(value ? "Pagina adattata per te" : "Pagina originale")
        Haptics.tick()
    }

    private func iconButton(_ icon: String, label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    /// R10: correzione manuale a passi di 0,1 logMAR, salvata nel profilo.
    private func adjustText(_ delta: Double) {
        var p = app.profile ?? PresetProfiles.baseline(device: ProfileBuilder.device)
        p.userAdjustments = UserAdjustments(textSizeOffsetLogMAR: ((p.textSizeOffset + delta) * 10).rounded() / 10)
        app.profile = p
        let count = UserDefaults.standard.integer(forKey: "enlargeCount") + (delta > 0 ? 1 : 0)
        UserDefaults.standard.set(count, forKey: "enlargeCount")
        if delta > 0, count >= 4, count % 4 == 0 {
            Voice.shared.say("Ingrandisci spesso il testo. Forse conviene rifare il test.")
        }
    }
}

extension View {
    /// Capsula Liquid Glass delle barre: vetro nativo con una velatura del fondo (testo sempre ≥ 7:1) e bordo sottile.
    func glassBar<S: InsettableShape>(_ look: AppAppearance, in shape: S) -> some View {
        glassEffect(.regular.tint(look.background.opacity(0.8)), in: shape)
            .overlay(shape.strokeBorder(look.hairline, lineWidth: 1))
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
        let look = app.appearance
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dove vuoi andare?")
                    .font(.ipo(.largeTitle, bold: true))
                    .padding(.bottom, 4)
                ForEach(sites, id: \.0) { site in
                    siteCard(site.0, icon: site.1, look: look) {
                        if let url = URL(string: site.2) { model.load(url) }
                    }
                }

                Text("Pagine salvate")
                    .font(.ipo(.subheadline, bold: true))
                    .foregroundStyle(look.secondary)
                    .padding(.top, 16)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(Array(OfflinePage.allCases.enumerated()), id: \.element) { index, page in
                        if index > 0 { Rectangle().fill(look.hairline).frame(height: 1).padding(.leading, 58) }
                        Button { model.open(page) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: page.icon).font(.body.weight(.semibold)).frame(width: 28)
                                Text(page.title).font(.ipo(.body)).multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold))
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Pagina salvata, funziona senza rete")
                    }
                }
                .background(RoundedRectangle(cornerRadius: 20).fill(look.card))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(look.hairline))

                if app.profile == nil {
                    Button { app.startTest() } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "eye.fill").font(.title2.weight(.semibold)).frame(width: 32)
                            Text("Fai il test della vista").font(.ipo(.title3, bold: true)).multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                        }
                        .foregroundStyle(look.onAccent)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(RoundedRectangle(cornerRadius: 20).fill(look.accent))
                        .contentShape(.rect(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(look.startBackground.ignoresSafeArea())
    }

    private func siteCard(_ title: String, icon: String, look: AppAppearance, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.title2.weight(.semibold)).frame(width: 32)
                Text(title).font(.ipo(.title3, bold: true)).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: 20).fill(look.card))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(look.hairline))
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
