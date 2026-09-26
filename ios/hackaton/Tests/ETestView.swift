import SwiftUI

/// Schermata di test con la E (acuità o contrasto): swipe verso l'apertura della E.
struct ETestView: View {
    @State var engine: ETestEngine
    var onFinish: (ETestEngine) -> Void
    var onQuit: () -> Void

    private var tracker = FaceDistanceTracker.shared
    @State private var lastSpoken: DistanceStatus = .ok

    init(engine: ETestEngine, onFinish: @escaping (ETestEngine) -> Void, onQuit: @escaping () -> Void) {
        _engine = State(initialValue: engine)
        self.onFinish = onFinish
        self.onQuit = onQuit
    }

    private var isAcuity: Bool { engine.kind == .acuity }

    var body: some View {
        let status = DistanceStatus.of(tracker, range: DistanceStatus.eTestRange)
        ZStack {
            Color.white.ignoresSafeArea()
            GestureSurface(onSwipe: { engine.respond($0) }, onTwoFingerTap: { engine.respondNotSeen() })
                .ignoresSafeArea()

            if let stim = engine.current {
                let side = stim.heightPx / DeviceDisplay.nativeScale
                TumblingE()
                    .fill(Color(.sRGB, red: Double(stim.gray) / 255, green: Double(stim.gray) / 255,
                                blue: Double(stim.gray) / 255))
                    .frame(width: side, height: side)
                    .rotationEffect(stim.direction.rotation)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Lettera E")
            }

            VStack {
                HStack {
                    DistanceBadge(range: DistanceStatus.eTestRange)
                    Spacer()
                    Button {
                        engine.setManualPaused(true)
                        Voice.shared.say("Test in pausa.")
                    } label: {
                        Label("Pausa", systemImage: "pause.fill").font(.ipo(.headline, bold: true))
                            .padding(.horizontal, 8).frame(minHeight: 44)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.horizontal)
                BigProgressBar(value: engine.progress,
                               label: "Lettera \(engine.trialCount + 1) · al massimo \(engine.stopRule.maxTrials)")
                    .padding(.horizontal)
                    .allowsHitTesting(false)
                Spacer()
                confidencePanel
            }

            if engine.paused {
                pauseOverlay(status: status)
            }
        }
        .environment(\.colorScheme, .light)
        .onAppear {
            ScreenBrightness.lock(0.8)
            engine.start()
        }
        .onChange(of: status) { _, new in
            engine.setAutoPaused(new != .ok)
            if new != .ok, new != lastSpoken { Voice.shared.say(new.message); Haptics.warning() }
            lastSpoken = new
        }
        .onChange(of: engine.finished) { _, done in
            if done { onFinish(engine) }
        }
    }

    /// Pannello con la stima e l'intervallo al 95% che si restringe a ogni risposta.
    private var confidencePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isAcuity ? "Soglia (logMAR)" : "Sensibilità al contrasto (log)")
                Spacer()
                Text("risposta \(engine.trialCount)")
            }
            .font(.ipo(.footnote, bold: true))
            .foregroundStyle(Color(white: 0.3))
            ConfidenceBar(estimate: engine.estimate, ci: engine.ci95,
                          range: isAcuity ? -0.3...1.8 : 0...2.1,
                          boundaries: isAcuity ? [0.3, 0.48, 1.0, 1.3] : [1.0, 1.5])
            Text("\(engine.estimate.it()) · intervallo 95%: \(engine.ci95.lowerBound.it())–\(engine.ci95.upperBound.it()) · ±\(engine.sd.it())")
                .font(.ipo(.footnote))
                .monospacedDigit()
                .foregroundStyle(Color(white: 0.3))
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .padding(.horizontal)
        .padding(.bottom, 8)
        .dynamicTypeSize(.large)
        .allowsHitTesting(false)
    }

    private func pauseOverlay(status: DistanceStatus) -> some View {
        VStack(spacing: 24) {
            if engine.manualPaused {
                Text("Test in pausa").font(.ipo(.largeTitle, bold: true))
                BigButton(title: "Riprendi", systemImage: "play.fill") { engine.setManualPaused(false) }
                BigButton(title: "Esci dal test", systemImage: "xmark", prominent: false) { onQuit() }
            } else {
                Image(systemName: status == .tooClose ? "arrow.down.forward.and.arrow.up.backward"
                      : status == .tooFar ? "arrow.up.backward.and.arrow.down.forward" : "face.dashed")
                    .font(.system(size: 80, weight: .bold))
                Text(status.message).font(.ipo(.largeTitle, bold: true)).multilineTextAlignment(.center)
                Text("Il test riprende da solo tra 35 e 45 cm.").font(.ipo(.title3))
            }
        }
        .foregroundStyle(.black)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.96))
    }
}
