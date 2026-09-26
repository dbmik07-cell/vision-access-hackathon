import SwiftUI
import Observation

/// I test nell'ordine di SPEC 3: prima quelli a due occhi, poi quelli con un occhio coperto.
enum TestStep: String, CaseIterable, Identifiable {
    case acuity, contrast, reading, amsler, field, light
    var id: String { rawValue }

    var title: String {
        switch self {
        case .acuity: "Acuity"
        case .contrast: "Contrast"
        case .reading: "Reading"
        case .amsler: "Amsler grid"
        case .field: "Visual field"
        case .light: "Light"
        }
    }

    var instructions: String {
        switch self {
        case .acuity:
            "You'll see an E. Slide your finger toward the side the E is open on. The letter gets smaller and smaller."
        case .contrast:
            "Same E, same gesture. Now the letter stays big but gets lighter and lighter."
        case .reading:
            "You'll read a few short sentences out loud, getting smaller each time, as fast as you can. The microphone is only used to tell when you've finished."
        case .amsler:
            "One eye at a time, the other covered. Look at the dot at the center of the grid and slide your finger where the lines look crooked, then where they're missing or blurry."
        case .light:
            "You'll see the same text in two versions. Tap the one you read better. There are six comparisons."
        case .field:
            "One eye at a time. You'll look at a black dot in a corner of the screen and tap the screen every time you see a small flash of light, even a faint one."
        }
    }

    /// Frase detta all'inizio di ogni test con la E.
    var guessHint: String? {
        switch self {
        case .acuity, .contrast:
            "If you're not sure, try to guess: that's part of the test. If you can't see anything at all, tap the screen with two fingers."
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
    var reading: ReadingMeasurement?
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
            p.reading = reading.map { ReadingBlock(source: $0.source) }
            p.amsler = amsler; p.visualField = visualField; p.light = light
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
                Text("This iPhone model (\(DeviceDisplay.modelIdentifier)) isn't in the screen table yet: without the exact pixel density the test wouldn't be accurate.")
                    .font(.ipo(.title2, bold: true)).multilineTextAlignment(.center)
                BigButton(title: "Go back", systemImage: "chevron.backward") { quit() }
            }
            .padding(24).foregroundStyle(.black).background(Color.white.ignoresSafeArea())
            .onAppear { Voice.shared.say("This iPhone model isn't supported by the test yet.") }
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
                Voice.shared.say("Test finished. Here's how you see.")
                Haptics.success()
                if let p = s.profile { app.finishTest(with: p, diagnostics: s.diagnostics, reading: s.reading) }
            }
        }
    }

    @ViewBuilder
    private func running(_ s: TestSession) -> some View {
        switch s.step {
        case .acuity:
            ETestView(engine: ETestEngine(kind: .acuity, demo: s.demo), onFinish: { engine in
                s.acuity = ProfileBuilder.acuityBlock(engine)
                s.diagnostics += Diagnostics.assess(quest: engine.quest, records: engine.records).map { "Acuity: \($0)" }
                if s.acuity?.censoredAtDisplayLimit == true { s.diagnostics.append("Acuity: normal vision, beyond the limit the screen can measure") }
                s.advance()
            }, onQuit: quit)
        case .contrast:
            let letter = ProfileBuilder.contrastLetterArcmin(acuity: s.acuity)
            ETestView(engine: ETestEngine(kind: .contrast(letterArcmin: letter.arcmin), demo: s.demo), onFinish: { engine in
                s.contrast = ProfileBuilder.contrastBlock(engine, letterCapped: letter.capped)
                if s.contrast?.censoredAtCeiling == true { s.diagnostics.append("Contrast: normal, beyond the limit the screen can measure") }
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
            Text("Hold the phone the way you normally do when reading, with your usual glasses.")
                .font(.ipo(.title, bold: true)).multilineTextAlignment(.center)
            DistanceBadge().scaleEffect(1.4)
            Text(status.message).font(.ipo(.title2)).multilineTextAlignment(.center)
            if let light = tracker.ambientIntensity {
                if light < 250 {
                    Label("The room is a bit dark: turn on a light if you can.", systemImage: "moon.fill").font(.ipo(.headline))
                } else if light > 2500 {
                    Label("There's a lot of light: avoid glare on the screen.", systemImage: "sun.max.fill").font(.ipo(.headline))
                }
            }
            Spacer()
            BigButton(title: "Continue", systemImage: "arrow.right") { finish() }
        }
        .padding(24)
        .foregroundStyle(.black)
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            Voice.shared.say("Hold the phone the way you normally do when reading, with your usual glasses. The front camera is only used to measure the distance to your face.")
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
        Voice.shared.say("Perfect.")
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
            Text("Test \(number) of \(total)").font(.ipo(.title2, bold: true)).foregroundStyle(Color(white: 0.3))
            Image(systemName: step.icon).font(.system(size: 72, weight: .semibold))
            Text(step.title).font(.ipo(.largeTitle, bold: true))
            Text(step.instructions).font(.ipo(.title3)).multilineTextAlignment(.center)
            if let hint = step.guessHint {
                Label(hint, systemImage: "hand.tap").font(.ipo(.title3, bold: true)).multilineTextAlignment(.leading)
            }
            Spacer()
            BigButton(title: "Start", systemImage: "play.fill", action: onStart)
        }
        .padding(24)
        .padding(.top, 30)
        .foregroundStyle(.black)
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            Voice.shared.say("Test \(number) of \(total): \(step.title). \(step.instructions) \(step.guessHint ?? "") Tap Start when you're ready.")
        }
    }
}
