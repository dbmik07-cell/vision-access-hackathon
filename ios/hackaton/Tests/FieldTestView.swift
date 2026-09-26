import SwiftUI
import Observation

/// Esecuzione del test del campo visivo (SPEC 5.5).
/// Telefono in orizzontale (fotocamera a sinistra), fondo grigio, punto di fissazione negli angoli:
/// fissando l'angolo in basso a sinistra, lo schermo copre la zona in alto a destra del campo.
@Observable
final class FieldTestRunner {
    enum Phase: Equatable { case intro(FieldSession.Eye), running, done }

    let demo: Bool
    var phase: Phase = .intro(.right)
    var fixation: CGPoint?          // coordinate nella tela orizzontale (punti)
    var stimulus: (point: CGPoint, diameter: CGFloat, gray: Int)?
    var status = ""
    var progress = 0.0
    private(set) var results: [FieldSession.Eye: FieldEye] = [:]

    @ObservationIgnored var canvas = CGSize(width: 852, height: 393)
    @ObservationIgnored private var taps: [Date] = []
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let tracker = FaceDistanceTracker.shared
    @ObservationIgnored var paused = false

    static let backgroundGray = 128
    private let margin: CGFloat = 16

    init(demo: Bool) { self.demo = demo }

    func tap() { taps.append(.now) }

    func cancel() { task?.cancel() }

    // MARK: Intensità

    /// 10 livelli di contrasto relativi al fondo, in scala logaritmica:
    /// difficoltà 1 → pallino bianco (Weber ≈ 3,6), difficoltà 10 → Weber 0,04.
    static func gray(difficulty x: Double) -> Int {
        let lBg = SRGB.toLinear(Double(backgroundGray) / 255)
        let cMax = (1 - lBg) / lBg, cMin = 0.04
        let step = (log10(cMax) - log10(cMin)) / 9
        let c = pow(10, log10(cMax) - (x - 1) * step)
        let l = min(1, lBg * (1 + c))
        return Int((SRGB.toEncoded(l) * 255).rounded())
    }

    // MARK: Geometria

    private var ptPerMM: Double { (DeviceDisplay.ppi ?? 460) / 25.4 / DeviceDisplay.nativeScale }

    /// Angolo → punti sullo schermo alla distanza attuale (tangente: angoli fino a ~30°).
    private func offsetPt(_ deg: Double) -> CGFloat {
        CGFloat(tracker.effectiveMM * tan(deg * .pi / 180) * ptPerMM)
    }

    /// Fissazione nell'angolo opposto al quadrante da testare.
    private func fixationFor(quadrant q: (Double, Double)) -> CGPoint {
        CGPoint(x: q.0 > 0 ? margin : canvas.width - margin, y: q.1 > 0 ? canvas.height - margin : margin)
    }

    private func screenPoint(x: Double, y: Double, fixation f: CGPoint) -> CGPoint? {
        let p = CGPoint(x: f.x + offsetPt(x), y: f.y - offsetPt(y))
        guard p.x >= 6, p.x <= canvas.width - 6, p.y >= 6, p.y <= canvas.height - 6 else { return nil }
        return p
    }

    // MARK: Ciclo del test

    func startEye(_ eye: FieldSession.Eye) {
        phase = .running
        task = Task { await runEye(eye) }
    }

    private func runEye(_ eye: FieldSession.Eye) async {
        var s = FieldSession(eye: eye, demo: demo)
        let blindSign: Double = eye == .right ? 1 : -1
        // Quadranti: prima quello con la macchia cieca (in basso, verso la tempia).
        let quadrants: [(Double, Double)] = [(blindSign, -1), (blindSign, 1), (-blindSign, 1), (-blindSign, -1)]
        func name(_ q: (Double, Double)) -> String {
            (q.1 > 0 ? "in basso" : "in alto") + (q.0 > 0 ? " a sinistra" : " a destra")
        }

        for (qi, q) in quadrants.enumerated() {
            if Task.isCancelled { return }
            let f = fixationFor(quadrant: q)
            fixation = f
            status = "Guarda il punto \(name(q))"
            Voice.shared.say("Guarda sempre il punto nero \(name(q)). Tocca lo schermo quando vedi un lampo.")
            try? await Task.sleep(for: .seconds(3.5))

            // Macchia cieca: la localizzo con stimoli forti all'inizio.
            if qi == 0 {
                var unseen: [(Double, Double)] = []
                for probe in s.blindSpotProbes {
                    guard let p = screenPoint(x: probe.0, y: probe.1, fixation: f) else { continue }
                    let r = await present(at: p, difficulty: FieldSession.strongDifficulty)
                    if !r.seen { unseen.append(probe) }
                }
                if unseen.count < s.blindSpotProbes.count { s.setBlindSpot(unseen: unseen) }
            }

            let ids = s.points.indices.filter { s.points[$0].x * q.0 > 0 && s.points[$0].y * q.1 > 0 }
            var allowed = Set<Int>()

            // Fase 1: screening, un solo stimolo "abbastanza forte" per punto.
            for i in ids.shuffled() {
                if Task.isCancelled { return }
                await maybeCatchTrial(&s, fixation: f, blindSpotQuadrant: qi == 0)
                guard let p = screenPoint(x: s.points[i].x, y: s.points[i].y, fixation: f) else { continue }
                allowed.insert(i)
                let r = await present(at: p, difficulty: FieldSession.screeningDifficulty)
                if r.fast { s.fastTaps += 1 }
                s.recordScreening(i, seen: r.seen)
                progress = (Double(qi) + 0.5 * Double(allowed.count) / Double(max(1, ids.count))) / 4
            }

            // Fase 2: ZEST sui punti non visti e sui vicini, il più incerto per primo.
            var guardCount = 0
            while let i = s.nextZestPoint(allowed: allowed), guardCount < 60, !Task.isCancelled {
                guardCount += 1
                await maybeCatchTrial(&s, fixation: f, blindSpotQuadrant: qi == 0)
                guard let p = screenPoint(x: s.points[i].x, y: s.points[i].y, fixation: f) else {
                    s.points[i].done = true; continue
                }
                let x = s.points[i].nextDifficulty
                let r = await present(at: p, difficulty: x)
                if r.fast { s.fastTaps += 1 }
                s.recordZest(i, difficulty: x, seen: r.seen)
            }
            progress = Double(qi + 1) / 4
        }
        fixation = nil
        results[eye] = s.result()
        Voice.shared.say(eye == .right ? "Occhio destro finito." : "Occhio sinistro finito.")
        Haptics.success()
        phase = eye == .right ? .intro(.left) : .done
    }

    /// Prove trappola: macchia cieca (fissazione), senza stimolo (falsi positivi),
    /// stimolo forte dove si è già visto uno più debole (falsi negativi).
    private func maybeCatchTrial(_ s: inout FieldSession, fixation f: CGPoint, blindSpotQuadrant: Bool) async {
        let r = Double.random(in: 0..<1)
        if blindSpotQuadrant, s.blindSpotFound, r < 0.10,
           let p = screenPoint(x: s.blindSpot.x, y: s.blindSpot.y, fixation: f) {
            s.blindSpotCatches += 1
            if await present(at: p, difficulty: FieldSession.strongDifficulty).seen { s.blindSpotSeen += 1 }
        } else if r < 0.18 {
            s.fpCatches += 1
            if await present(at: nil, difficulty: 1).seen { s.fpTapped += 1 }
        } else if r < 0.24,
                  let i = s.points.indices.first(where: { (s.points[$0].seenDifficulties.max() ?? 0) >= 3 && Bool.random() }),
                  let p = screenPoint(x: s.points[i].x, y: s.points[i].y, fixation: f) {
            s.fnCatches += 1
            if !(await present(at: p, difficulty: FieldSession.strongDifficulty).seen) { s.fnMissed += 1 }
        }
    }

    /// Una presentazione: intervallo casuale, pallino di 0,43° per 200 ms, finestra di risposta di 1,5 s.
    /// Tocchi entro 150 ms dallo stimolo sono troppo veloci per essere veri (falsi positivi).
    private func present(at point: CGPoint?, difficulty: Double) async -> (seen: Bool, fast: Bool) {
        await waitWhilePaused()
        try? await Task.sleep(for: .milliseconds(Int.random(in: 600...1400)))
        await waitWhilePaused()
        taps.removeAll()
        let onset = Date.now
        if let point {
            let diameter = max(3, offsetPt(0.43))
            stimulus = (point, diameter, Self.gray(difficulty: difficulty))
        }
        try? await Task.sleep(for: .milliseconds(200))
        stimulus = nil
        try? await Task.sleep(for: .milliseconds(1300))
        let delays = taps.map { $0.timeIntervalSince(onset) }
        let fast = delays.contains { $0 >= 0 && $0 < 0.15 }
        let seen = delays.contains { $0 >= 0.15 && $0 <= 1.5 }
        return (seen, fast && !seen)
    }

    private func waitWhilePaused() async {
        while paused, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(200)) }
    }

    var fieldResult: VisualFieldBlock {
        VisualFieldBlock(source: .measured, right: results[.right], left: results[.left])
    }
}

struct FieldTestView: View {
    @State private var runner: FieldTestRunner
    var onFinish: (VisualFieldBlock) -> Void
    var onQuit: () -> Void
    private var tracker = FaceDistanceTracker.shared

    init(demo: Bool, onFinish: @escaping (VisualFieldBlock) -> Void, onQuit: @escaping () -> Void) {
        _runner = State(initialValue: FieldTestRunner(demo: demo))
        self.onFinish = onFinish
        self.onQuit = onQuit
    }

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size
            let landscape = CGSize(width: portrait.height, height: portrait.width)
            ZStack {
                Color(.sRGB, white: Double(FieldTestRunner.backgroundGray) / 255).ignoresSafeArea()
                // Tela orizzontale ruotata di 90°: il telefono si tiene con la fotocamera a sinistra.
                canvas(size: landscape)
                    .frame(width: landscape.width, height: landscape.height)
                    .rotationEffect(.degrees(90))
                    .position(x: portrait.width / 2, y: portrait.height / 2)
            }
            .onAppear { runner.canvas = landscape }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { runner.tap() }
        .onChange(of: DistanceStatus.of(tracker)) { _, new in
            runner.paused = new != .ok
            if new != .ok { Voice.shared.say(new.message) }
        }
        .onChange(of: runner.phase) { _, p in
            if p == .done { onFinish(runner.fieldResult) }
            if case .intro(let eye) = p { speakIntro(eye) }
        }
        .onAppear { ScreenBrightness.lock(0.8); speakIntro(.right) }
        .onDisappear { runner.cancel() }
    }

    @ViewBuilder
    private func canvas(size: CGSize) -> some View {
        let gray = Color(.sRGB, white: Double(FieldTestRunner.backgroundGray) / 255)
        ZStack {
            gray
            switch runner.phase {
            case .intro(let eye):
                VStack(spacing: 14) {
                    Text("Campo visivo · occhio \(eye == .right ? "destro" : "sinistro")").font(.ipo(.title, bold: true))
                    Text("Copri l'occhio \(eye == .right ? "sinistro" : "destro") con la mano. Gira il telefono in orizzontale, fotocamera a sinistra, a circa 25 cm. Guarda sempre il punto nero e tocca lo schermo ovunque quando vedi un lampo.")
                        .font(.ipo(.title3)).multilineTextAlignment(.center)
                    HStack(spacing: 16) {
                        DistanceBadge()
                        Button("Inizia") { runner.startEye(eye) }
                            .font(.ipo(.title2, bold: true)).buttonStyle(.glassProminent).controlSize(.extraLarge)
                        Button("Esci") { onQuit() }.font(.ipo(.title3)).buttonStyle(.glass)
                    }
                }
                .foregroundStyle(.black)
                .padding(30)
                .dynamicTypeSize(.large)
            case .running, .done:
                if let f = runner.fixation {
                    Circle().fill(.black).frame(width: 12, height: 12).position(f)
                }
                if let s = runner.stimulus {
                    Circle().fill(Color(.sRGB, white: Double(s.gray) / 255))
                        .frame(width: s.diameter, height: s.diameter).position(s.point)
                }
                if runner.paused {
                    Text(DistanceStatus.of(tracker).message).font(.ipo(.title, bold: true)).foregroundStyle(.black)
                        .padding().glassEffect(.regular, in: .capsule)
                }
                VStack {
                    Spacer()
                    BigProgressBar(value: runner.progress, label: "Avanzamento \(Int(runner.progress * 100))%")
                        .frame(width: 280)
                        .padding(.bottom, 10)
                        .opacity(0.55)
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func speakIntro(_ eye: FieldSession.Eye) {
        Voice.shared.say("Campo visivo, occhio \(eye == .right ? "destro" : "sinistro"). Copri l'occhio \(eye == .right ? "sinistro" : "destro") con la mano. Gira il telefono in orizzontale, con la fotocamera a sinistra, a circa venticinque centimetri. Guarda sempre il punto nero e tocca lo schermo ovunque quando vedi un lampo di luce. Poi tocca Inizia.")
    }
}
