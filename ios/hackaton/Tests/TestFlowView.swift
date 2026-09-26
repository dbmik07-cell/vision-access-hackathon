import SwiftUI
import Observation

/// I test nell'ordine di SPEC 3: prima quelli a due occhi, poi quelli con un occhio coperto.
enum TestStep: String, CaseIterable, Identifiable {
    case acuity, contrast, reading, amsler, field, light
    var id: String { rawValue }

    var title: String {
        switch self {
        case .acuity: "Acuità"
        case .contrast: "Contrasto"
        case .reading: "Lettura"
        case .amsler: "Griglia di Amsler"
        case .field: "Campo visivo"
        case .light: "Luce"
        }
    }

    var instructions: String {
        switch self {
        case .acuity:
            "Vedrai una E. Scorri il dito verso il lato in cui la E è aperta. La lettera diventa sempre più piccola."
        case .contrast:
            "Stessa E, stesso gesto. Ora la lettera resta grande ma diventa sempre più chiara."
        case .reading:
            "Leggerai ad alta voce alcune frasi brevi, sempre più piccole, il più veloce possibile. Il microfono serve solo a capire quando hai finito."
        case .amsler:
            "Un occhio alla volta, l'altro coperto. Guarda il punto al centro della griglia e passa il dito dove le linee sono storte, poi dove mancano o sono sfocate."
        case .light:
            "Vedrai lo stesso testo in due versioni. Tocca quella che leggi meglio. Sono sei confronti."
        case .field:
            "Un occhio alla volta. Guarderai un punto nero in un angolo dello schermo e toccherai lo schermo ogni volta che vedi un piccolo lampo di luce, anche debole."
        }
    }

    /// Frase detta all'inizio di ogni test con la E.
    var guessHint: String? {
        switch self {
        case .acuity, .contrast:
            "Se non sei sicuro, prova a indovinare: fa parte del test. Se non vedi proprio niente, tocca lo schermo con due dita."
        default: nil
        }
    }

    var icon: String {
        switch self {
        case .acuity: "textformat.size"
        case .contrast: "circle.lefthalf.filled"
        case .reading: "text.book.closed"
        case .amsler: "grid"
        case .field: "circle.dotted"
        case .light: "sun.max"
        }
    }
}

@Observable
final class TestSession {
    enum Stage: Equatable { case prep, intro, running, done }

    let steps: [TestStep]
    let demo: Bool
    var index = 0
    var stage: Stage = .prep
    // Blocchi raccolti durante i test; il profilo si costruisce alla fine.
    var acuity: AcuityBlock?
    var contrast: ContrastBlock?
    var reading: ReadingBlock?
    var amsler: AmslerBlock?
    var visualField: VisualFieldBlock?
    var light: LightBlock?
    var diagnostics: [String] = []
    private(set) var profile: VisualProfile?

    init(demo: Bool) {
        self.demo = demo
        // Demo (~3 minuti): Amsler e campo visivo si mostrano con i profili predefiniti.
        steps = demo ? [.acuity, .contrast, .reading, .light] : TestStep.allCases
    }

    var step: TestStep { steps[min(index, steps.count - 1)] }

    func advance() {
        if index + 1 < steps.count {
            index += 1
            stage = .intro
        } else {
            // Acuità e contrasto sono obbligatori nel contratto: se mancano (demo interrotta) restano preset.
            let base = PresetProfiles.baseline(device: ProfileBuilder.device)
            var p = VisualProfile(device: ProfileBuilder.device, acuity: acuity ?? base.acuity,
                                  contrast: contrast ?? base.contrast)
            p.reading = reading; p.amsler = amsler; p.visualField = visualField; p.light = light
            ProfileBuilder.finalize(&p)
            profile = p
            stage = .done
        }
    }
}

struct TestFlowView: View {
    @Environment(AppModel.self) private var app
    @State private var session: TestSession?

    var body: some View {
        Group {
            if let session {
                content(session)
            } else {
                Color.white
            }
        }
        .onAppear {
            if session == nil { session = TestSession(demo: app.demoMode) }
            FaceDistanceTracker.shared.start()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            FaceDistanceTracker.shared.stop()
            ScreenBrightness.restore()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    @ViewBuilder
    private func content(_ s: TestSession) -> some View {
        if !DeviceDisplay.isSupportedModel {
            // Contratto, sezione 7: modello assente dalla tabella → nessun ppi stimato, il test non parte.
            VStack(spacing: 24) {
                Image(systemName: "iphone.slash").font(.system(size: 80))
                Text("Questo modello di iPhone (\(DeviceDisplay.modelIdentifier)) non è ancora nella tabella degli schermi: senza la densità esatta il test non sarebbe corretto.")
                    .font(.ipo(.title2, bold: true)).multilineTextAlignment(.center)
                BigButton(title: "Torna indietro", systemImage: "chevron.backward") { quit() }
            }
            .padding(24).foregroundStyle(.black).background(Color.white.ignoresSafeArea())
            .onAppear { Voice.shared.say("Questo modello di iPhone non è ancora supportato dal test.") }
        } else {
            stageContent(s)
        }
    }

    @ViewBuilder
    private func stageContent(_ s: TestSession) -> some View {
        switch s.stage {
        case .prep:
            PrepView { s.stage = .intro }
        case .intro:
            IntroView(step: s.step, number: s.index + 1, total: s.steps.count) { s.stage = .running }
        case .running:
            running(s).id(s.index)
        case .done:
            ProgressView().onAppear {
                Voice.shared.say("Test finito. Ecco come vedi.")
                Haptics.success()
                if let p = s.profile { app.finishTest(with: p, diagnostics: s.diagnostics) }
            }
        }
    }

    @ViewBuilder
    private func running(_ s: TestSession) -> some View {
        switch s.step {
        case .acuity:
            ETestView(engine: ETestEngine(kind: .acuity, demo: s.demo), onFinish: { engine in
                s.acuity = ProfileBuilder.acuityBlock(engine)
                s.diagnostics += Diagnostics.assess(quest: engine.quest, records: engine.records).map { "Acuità: \($0)" }
                if engine.censor == .aboveLimit { s.diagnostics.append("Acuità: vista nella norma, oltre il limite misurabile dallo schermo") }
                if engine.censor == .belowLimit { s.diagnostics.append("Acuità sotto il limite misurabile: adattamento al massimo") }
                s.advance()
            }, onQuit: quit)
        case .contrast:
            let letter = ProfileBuilder.contrastLetterArcmin(acuity: s.acuity)
            ETestView(engine: ETestEngine(kind: .contrast(letterArcmin: letter.arcmin), demo: s.demo), onFinish: { engine in
                s.contrast = ProfileBuilder.contrastBlock(engine, letterCapped: letter.capped)
                if engine.censor == .aboveLimit { s.diagnostics.append("Contrasto nella norma, oltre il limite misurabile dallo schermo") }
                if engine.censor == .belowLimit { s.diagnostics.append("Contrasto sotto il limite misurabile: adattamento al massimo") }
                s.advance()
            }, onQuit: quit)
        case .reading:
            // Si parte da una dimensione scelta in base all'acuità: 0,5 logMAR sopra la soglia.
            ReadingTestView(startLogMAR: (s.acuity?.logMAR ?? 0.3) + 0.5, demo: s.demo, onFinish: { result in
                s.reading = result
                s.advance()
            }, onQuit: quit)
        case .amsler:
            AmslerTestView(onFinish: { result in
                s.amsler = result
                s.advance()
            }, onQuit: quit)
        case .light:
            LightTestView(onFinish: { result in
                s.light = result
                s.advance()
            }, onQuit: quit)
        case .field:
            FieldTestView(demo: s.demo, onFinish: { result in
                s.visualField = result
                s.advance()
            }, onQuit: quit)
        }
    }

    private func quit() {
        Voice.shared.stop()
        app.route = app.profile == nil ? .welcome : .browser
    }
}

/// Preparazione: la TrueDepth controlla la distanza e la voce guida (circa 20 secondi).
struct PrepView: View {
    var onReady: () -> Void
    private var tracker = FaceDistanceTracker.shared
    @State private var okSince: Date?
    @State private var done = false

    init(onReady: @escaping () -> Void) { self.onReady = onReady }

    var body: some View {
        let status = DistanceStatus.of(tracker)
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "iphone.gen3").font(.system(size: 90))
            Text("Tieni il telefono come quando leggi, con i tuoi soliti occhiali.")
                .font(.ipo(.title, bold: true)).multilineTextAlignment(.center)
            DistanceBadge().scaleEffect(1.4)
            Text(status.message).font(.ipo(.title2)).multilineTextAlignment(.center)
            if let light = tracker.ambientIntensity {
                if light < 250 {
                    Label("La stanza è un po' buia: accendi una luce se puoi.", systemImage: "moon.fill").font(.ipo(.headline))
                } else if light > 2500 {
                    Label("C'è molta luce: evita i riflessi sullo schermo.", systemImage: "sun.max.fill").font(.ipo(.headline))
                }
            }
            Spacer()
            BigButton(title: "Continua", systemImage: "arrow.right") { finish() }
        }
        .padding(24)
        .foregroundStyle(.black)
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            Voice.shared.say("Tieni il telefono come quando leggi, con i tuoi soliti occhiali. La fotocamera frontale serve solo a misurare la distanza del tuo viso.")
        }
        .onChange(of: status) { _, new in
            if new == .ok { okSince = .now } else { okSince = nil; Voice.shared.say(new.message, interrupt: false) }
        }
        .task {
            // Si parte da soli dopo 2 secondi continui alla distanza giusta.
            while !done {
                try? await Task.sleep(for: .milliseconds(300))
                if !FaceDistanceTracker.isSupported, !done {
                    try? await Task.sleep(for: .seconds(3)); finish()
                } else if let since = okSince, Date.now.timeIntervalSince(since) > 2 {
                    finish()
                }
            }
        }
    }

    private func finish() {
        guard !done else { return }
        done = true
        Voice.shared.say("Perfetto.")
        onReady()
    }
}

/// Breve pausa tra un test e l'altro: "test 2 di 6", istruzioni a voce.
struct IntroView: View {
    var step: TestStep
    var number: Int
    var total: Int
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Test \(number) di \(total)").font(.ipo(.title2, bold: true)).foregroundStyle(Color(white: 0.3))
            Image(systemName: step.icon).font(.system(size: 72, weight: .semibold))
            Text(step.title).font(.ipo(.largeTitle, bold: true))
            Text(step.instructions).font(.ipo(.title3)).multilineTextAlignment(.center)
            if let hint = step.guessHint {
                Label(hint, systemImage: "hand.tap").font(.ipo(.title3, bold: true)).multilineTextAlignment(.leading)
            }
            Spacer()
            BigButton(title: "Inizia", systemImage: "play.fill", action: onStart)
        }
        .padding(24)
        .padding(.top, 30)
        .foregroundStyle(.black)
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            Voice.shared.say("Test \(number) di \(total): \(step.title). \(step.instructions) \(step.guessHint ?? "") Tocca Inizia quando sei pronto.")
        }
    }
}
