import SwiftUI

/// Test di lettura (SPEC 5.3), ispirato a MNREAD: una frase per dimensione, a passi di 0,1 logMAR,
/// tempo fermato dall'ultima parola riconosciuta a voce (offline) o da un tocco.
struct ReadingTestView: View {
    let startLogMAR: Double
    let demo: Bool
    var onFinish: (ReadingResult) -> Void
    var onQuit: () -> Void

    enum Stage { case permission, ready, reading, done }
    @State private var stage: Stage = .permission
    @State private var listener = SpeechListener()
    @State private var size: Double = 0.6
    @State private var sentenceIndex = 0
    @State private var sentences = ReadingSentences.all.shuffled()
    @State private var shownAt = Date()
    @State private var samples: [ReadingSample] = []
    @State private var finishedSentence = false
    @State private var speechWorks = false
    private var tracker = FaceDistanceTracker.shared

    init(startLogMAR: Double, demo: Bool, onFinish: @escaping (ReadingResult) -> Void, onQuit: @escaping () -> Void) {
        self.startLogMAR = startLogMAR
        self.demo = demo
        self.onFinish = onFinish
        self.onQuit = onQuit
    }

    private var sentence: String { sentences[sentenceIndex % sentences.count] }

    /// Dimensione del font in punti per una frase di `logMAR` alla distanza attuale (x = 5′·10^s).
    private func fontPt(_ logMAR: Double) -> Double {
        RulesEngine.fontSizePx(targetLogMAR: logMAR, context: BrowserContext.current())
    }

    /// Dimensione più grande che sta nello schermo (almeno 14 caratteri per riga).
    private var maxLogMAR: Double {
        let width = Double(DeviceDisplay.screenSizePt.width) - 32
        let maxFont = width / (RulesEngine.avgCharWidthEm * 14)
        let ref = fontPt(0)
        return log10(maxFont / ref)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                DistanceBadge()
                Spacer()
                Button("Esci") { listener.stop(); onQuit() }.buttonStyle(.glass).font(.ipo(.headline))
            }
            .dynamicTypeSize(.large)
            switch stage {
            case .permission:
                Spacer()
                ProgressView()
                Text("Preparo il microfono…").font(.ipo(.title2))
                Spacer()
            case .ready:
                Spacer()
                Text("Leggi ad alta voce la frase, il più veloce possibile. Quando hai finito, tocca lo schermo.")
                    .font(.ipo(.title2, bold: true)).multilineTextAlignment(.center)
                if !speechWorks {
                    Text("Riconoscimento vocale non disponibile: il tempo si ferma con il tocco.")
                        .font(.ipo(.headline)).foregroundStyle(.orange).multilineTextAlignment(.center)
                }
                Spacer()
                BigButton(title: "Mostra la prima frase", systemImage: "text.alignleft") { showSentence() }
            case .reading:
                BigProgressBar(value: Double(samples.count) / Double(demo ? 6 : 16),
                               label: "Frase \(samples.count + 1) · al massimo \(demo ? 6 : 16)")
                Spacer()
                Text(sentence)
                    .font(.custom("AtkinsonHyperlegible-Regular", fixedSize: fontPt(size)))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                Spacer()
                HStack {
                    Text("\(size.it(1)) logMAR · frase \(samples.count + 1)").font(.ipo(.footnote)).foregroundStyle(.gray)
                    Spacer()
                    Button("Non riesco a leggerla") { finish(sentenceRead: false) }
                        .font(.ipo(.headline, bold: true)).buttonStyle(.glass)
                }
                .dynamicTypeSize(.large)
            case .done:
                ProgressView()
            }
        }
        .padding(16)
        .foregroundStyle(.black)
        .background(Color.white.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { if stage == .reading { finish(sentenceRead: true) } }
        .task {
            // Permessi chiesti solo adesso, spiegati a voce un attimo prima (SPEC 3).
            Voice.shared.say("Test di lettura. Ora ti chiedo il microfono: serve solo a capire quando hai finito di leggere, e funziona senza internet.")
            try? await Task.sleep(for: .seconds(4))
            speechWorks = await listener.requestPermissions()
            size = min(startLogMAR, maxLogMAR)
            stage = .ready
            Voice.shared.say("Leggi ad alta voce ogni frase, il più veloce possibile. Le frasi diventano sempre più piccole. Quando hai finito una frase, tocca lo schermo.")
        }
        .onDisappear { listener.stop() }
    }

    private func showSentence() {
        Voice.shared.stop()
        finishedSentence = false
        stage = .reading
        shownAt = .now   // il tempo parte alla comparsa della frase
        if speechWorks {
            listener.onUpdate = { text in
                // Stop all'ultima parola della frase riconosciuta.
                guard !finishedSentence, let last = ReadingAnalysis.words(sentence).last,
                      ReadingAnalysis.words(text).suffix(3).contains(last) else { return }
                finish(sentenceRead: true)
            }
            listener.start()
        }
    }

    private func finish(sentenceRead: Bool) {
        guard stage == .reading, !finishedSentence else { return }
        finishedSentence = true
        let seconds = max(0.5, Date.now.timeIntervalSince(shownAt))
        let transcript = listener.transcript
        listener.stop()
        let total = ReadingAnalysis.words(sentence).count
        let correct: Int
        if !sentenceRead { correct = 0 }
        else if speechWorks, !transcript.isEmpty { correct = ReadingAnalysis.correctWords(sentence: sentence, transcript: transcript) }
        else { correct = total }   // solo tocco: parole considerate corrette
        // Velocità = parole corrette × 60 / secondi.
        let wpm = Double(correct) * 60 / seconds
        samples.append(ReadingSample(logMAR: size, seconds: seconds, wordsCorrect: correct, wordsTotal: total, wpm: wpm))
        Haptics.tick()

        let minLogMAR = VisualAngle.logMAR(strokeArcmin: 1) - 0.2   // limite pratico di pixel
        let tooHard = !sentenceRead || Double(correct) / Double(total) < 0.5 || wpm < 15
        let maxSentences = demo ? 6 : 16
        if tooHard || samples.count >= maxSentences || size - 0.1 < minLogMAR {
            complete()
        } else {
            size = ((size - 0.1) * 10).rounded() / 10
            sentenceIndex += 1
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                showSentence()
            }
        }
    }

    private func complete() {
        stage = .done
        let fit = ReadingAnalysis.twoLimbFit(samples)
        let acuity = ReadingAnalysis.readingAcuity(samples) ?? (samples.map(\.logMAR).max() ?? size)
        var flags: [String] = []
        if !speechWorks { flags.append("tempo misurato con il tocco") }
        if samples.count < 4 { flags.append("poche frasi lette (\(samples.count))") }
        let measured = fit != nil && samples.filter { $0.wpm > 0 }.count >= 3
        let cps = fit?.cps ?? acuity + 0.2
        // Intervallo pratico: ± un passo della prova (0,1 logMAR).
        let rel: Reliability = !measured ? .nonAffidabile : (flags.isEmpty ? .affidabile : .dubbio)
        onFinish(ReadingResult(measured: measured, criticalPrintSizeLogMAR: cps, ci95: [cps - 0.1, cps + 0.1],
                               maxReadingSpeedWpm: fit?.mrs ?? (samples.map(\.wpm).max() ?? 0),
                               readingAcuityLogMAR: acuity, reliability: rel, flags: flags, samples: samples))
    }
}
