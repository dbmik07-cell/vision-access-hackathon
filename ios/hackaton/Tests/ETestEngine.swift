import SwiftUI
import Observation

/// Direzione in cui sono aperte le "gambe" della E.
enum Direction: String, CaseIterable, Codable {
    case right, down, left, up

    /// Rotazione in senso orario a partire dalla E normale (aperta a destra).
    var rotation: Angle {
        switch self {
        case .right: .degrees(0)
        case .down: .degrees(90)
        case .left: .degrees(180)
        case .up: .degrees(270)
        }
    }

    var italian: String {
        switch self {
        case .right: "destra"
        case .down: "basso"
        case .left: "sinistra"
        case .up: "alto"
        }
    }

    /// Direzione di uno swipe dalla traslazione (asse dominante).
    static func of(translation t: CGSize) -> Direction? {
        guard max(abs(t.width), abs(t.height)) > 25 else { return nil }
        if abs(t.width) > abs(t.height) { return t.width > 0 ? .right : .left }
        return t.height > 0 ? .down : .up
    }
}

/// Stimolo sullo schermo in questo momento.
struct EStimulus: Equatable {
    var target: Double        // valore scelto da QUEST+ (logMAR o log 1/C)
    var heightPx: Double      // altezza della E in pixel fisici
    var gray: Int             // valore sRGB 0...255 della lettera (0 = nero)
    var direction: Direction
    var shownAt: Date
    /// Stimolo più difficile disegnabile (E più piccola o contrasto più basso).
    var atHardLimit = false
    /// Stimolo più facile disegnabile (E più grande o nero pieno).
    var atEasyLimit = false
}

/// Risultato censurato al limite dello schermo.
enum ScreenCensor: String, Codable {
    case none
    /// Risposte giuste allo stimolo più difficile disegnabile: vista oltre il limite misurabile.
    case aboveLimit
    /// Lo stimolo più facile non viene visto: sotto il limite misurabile.
    case belowLimit
}

enum ETestKind: Equatable {
    case acuity
    /// Contrasto con lettera di dimensione fissa (in logMAR).
    case contrast(letterArcmin: Double)
}

/// Motore comune ad acuità e contrasto: stessa E, stesso gesto, QUEST+ sotto.
@Observable
final class ETestEngine {
    let kind: ETestKind
    private(set) var quest: QuestPlus
    let stopRule: StopRule
    private(set) var current: EStimulus?
    private(set) var records: [TrialRecord] = []
    private(set) var finished = false
    private(set) var censor: ScreenCensor = .none
    /// Risposte giuste consecutive allo stimolo più difficile disegnabile.
    @ObservationIgnored private var hardLimitStreak = 0
    /// Contratto: displayLimitLogMAR = il più piccolo stimolo ammissibile durante il test (acuità);
    /// per il contrasto il log10(C) più basso ammissibile (→ ceilingLogCS = −valore).
    private(set) var displayLimit: Double?
    /// Volte in cui lo stimolo più facile non è stato visto.
    @ObservationIgnored private var easyLimitMisses = 0
    /// Pausa automatica (distanza fuori 25–60 cm) o chiesta dalla persona.
    private(set) var autoPaused = false
    private(set) var manualPaused = false
    var paused: Bool { autoPaused || manualPaused }

    @ObservationIgnored private let tracker = FaceDistanceTracker.shared
    @ObservationIgnored private var lastDirection: Direction?
    @ObservationIgnored private var generation = 0

    init(kind: ETestKind, demo: Bool) {
        self.kind = kind
        switch kind {
        case .acuity:
            quest = QuestConfigs.acuity()
            stopRule = QuestConfigs.acuityStop(demo: demo)
        case .contrast:
            quest = QuestConfigs.contrast()
            stopRule = QuestConfigs.contrastStop(demo: demo)
        }
    }

    var trialCount: Int { quest.trials.count }
    /// Stima pubblicata (mediana) nella scala del risultato: logMAR, oppure logCS = −t per il contrasto.
    var estimate: Double { kind == .acuity ? quest.thresholdMedian : -quest.thresholdMedian }
    var ci95: ClosedRange<Double> {
        let c = quest.ci95
        return kind == .acuity ? c : (-c.upperBound)...(-c.lowerBound)
    }
    var sd: Double { quest.thresholdSD }

    // MARK: Stimoli possibili adesso

    /// Lettera interamente nello schermo: lato corto in pixel del dispositivo.
    private var maxLetterPx: Double {
        Double(min(DeviceDisplay.screenSizePt.width, DeviceDisplay.screenSizePt.height)) * DeviceDisplay.nativeScale
    }

    /// Acuità: dimensioni ricalcolate alla distanza attuale.
    /// Vincoli: tratto della E di almeno 2 pixel, lettera interamente nello schermo.
    private func acuityCandidates(distanceMM: Double) -> [Double] {
        // Stessa griglia di t, filtrata: tratto ≥ 2 px del dispositivo e lettera nello schermo.
        let all = quest.thresholds
        let ok = VisualAngle.admissibleAcuityIndices(grid: all, distanceMm: distanceMM, ppi: DeviceDisplay.ppi ?? 460,
                                                    screenShortSideDevicePx: maxLetterPx).map { all[$0] }
        if !ok.isEmpty { return ok }
        return [VisualAngle.logMAR(letterHeightPx: maxLetterPx, distanceMM: distanceMM)]
    }

    /// Contrasto: i grigi a 8 bit mostrabili davvero (senza dithering), come x = log10(C di Weber)
    /// sulla luminanza fisica, in ordine crescente e dentro la griglia [−2,1, 0].
    static let contrastLevels: [(gray: Int, x: Double)] = {
        var levels: [(Int, Double)] = []
        var seen = Set<Int>()
        for v in 0...254 {
            let x = log10(SRGB.weberContrastOnWhite(gray: v))
            guard x >= ContractParameters.contrastThresholdMin else { continue }
            let key = Int((x * 1000).rounded())
            if seen.insert(key).inserted { levels.append((v, x)) }
        }
        return levels.sorted { $0.1 < $1.1 }
    }()

    private func candidates(distanceMM: Double) -> [Double] {
        switch kind {
        case .acuity: acuityCandidates(distanceMM: distanceMM)
        case .contrast: Self.contrastLevels.map(\.x)
        }
    }

    // MARK: Ciclo del test

    func start() { presentNext() }

    /// Prove di controllo (affidabilità avanzata, post-MVP nel contratto): disattivate.
    nonisolated static let catchTrialsEnabled = false

    /// Prove di controllo: la 5ª, 10ª, 15ª... (dopo le prime risposte).
    nonisolated static func isCatchTrial(_ completed: Int) -> Bool { completed >= 4 && (completed + 1) % 5 == 0 }

    func presentNext() {
        guard !finished, !paused else { return }
        generation += 1
        let gen = generation
        let q = quest
        let d = tracker.effectiveMM
        let cands = candidates(distanceMM: d)
        // L'entropia attesa si calcola fuori dal thread principale.
        // Prova di controllo (SPEC 6, caso B): una lettera ogni 5 è facile, 0,4 unità sopra la stima.
        // Chi vede davvero non sbaglia queste; chi finge o è distratto sì.
        let isCatch = Self.catchTrialsEnabled && Self.isCatchTrial(q.trials.count)
        let easy = q.thresholdMean + 0.4
        Task {
            let next = await Task.detached(priority: .userInitiated) {
                isCatch ? cands.min { abs($0 - easy) < abs($1 - easy) } : q.nextStimulus(candidates: cands)
            }.value
            guard gen == self.generation, !self.paused, !self.finished, let next else { return }
            self.show(target: next, distanceMM: self.tracker.effectiveMM)
        }
    }

    private func show(target: Double, distanceMM: Double) {
        let cands = candidates(distanceMM: distanceMM)
        // Limiti dello schermo: con la variabile di facilità il più difficile è sempre il valore più piccolo.
        let hardest = cands.min()
        let easiest = cands.max()
        if let hardest { displayLimit = min(displayLimit ?? hardest, hardest) }
        let atHard = hardest.map { abs($0 - target) < 0.011 } ?? false
        let atEasy = easiest.map { abs($0 - target) < 0.011 } ?? false
        var direction = Direction.allCases.randomElement()!
        if direction == lastDirection { direction = Direction.allCases.randomElement()! }
        lastDirection = direction
        switch kind {
        case .acuity:
            let h = min(maxLetterPx, VisualAngle.letterHeightPx(logMAR: target, distanceMM: distanceMM))
            current = EStimulus(target: target, heightPx: h, gray: 0, direction: direction, shownAt: .now,
                                atHardLimit: atHard, atEasyLimit: atEasy)
        case .contrast(let letterArcmin):
            let h = min(maxLetterPx, VisualAngle.px(mm: VisualAngle.mm(arcmin: letterArcmin, distanceMM: distanceMM)))
            let gray = Self.contrastLevels.min { abs($0.x - target) < abs($1.x - target) }?.gray ?? 0
            current = EStimulus(target: target, heightPx: h, gray: gray, direction: direction, shownAt: .now,
                                atHardLimit: atHard, atEasyLimit: atEasy)
        }
    }

    /// Risposta con uno swipe. La distanza registrata è quella dell'istante della risposta.
    func respond(_ answer: Direction) { record(answer: answer) }

    /// Gesto "non vedo" (tocco con due dita): contato come risposta sbagliata.
    func respondNotSeen() {
        guard current != nil, !paused, !finished else { return }
        Voice.shared.say("Ok, passiamo alla prossima.")
        record(answer: nil)
    }

    private func record(answer: Direction?) {
        guard let stim = current, !paused, !finished else { return }
        let distanceMM = tracker.effectiveMM
        let rt = Date.now.timeIntervalSince(stim.shownAt) * 1000
        let actual: Double
        switch kind {
        case .acuity:
            // logMAR effettivo: dimensione in pixel mostrata e distanza reale al momento della risposta.
            actual = VisualAngle.logMAR(letterHeightPx: stim.heightPx, distanceMM: distanceMM)
        case .contrast:
            actual = log10(SRGB.weberContrastOnWhite(gray: stim.gray))
        }
        let correct = answer == stim.direction
        quest.update(stimulus: actual, correct: correct)
        records.append(TrialRecord(stimulus: actual, correct: correct, distanceCM: distanceMM / 10,
                                   responseTimeMs: rt, shown: stim.direction.rawValue, answered: answer?.rawValue ?? "non-vedo",
                                   estimateAfter: quest.thresholdMedian, sdAfter: quest.thresholdSD))
        current = nil
        Haptics.tick()
        // Limite dello schermo: 3 risposte giuste di fila allo stimolo più difficile → stop, oltre il limite.
        if stim.atHardLimit { hardLimitStreak = correct ? hardLimitStreak + 1 : 0 }
        // Stimolo più facile non visto 3 volte → stop, sotto il limite misurabile.
        if stim.atEasyLimit, !correct { easyLimitMisses += 1 }
        if hardLimitStreak >= 3 {
            censor = .aboveLimit
            finished = true
        } else if easyLimitMisses >= 3 {
            censor = .belowLimit
            finished = true
        } else if stopRule.shouldStop(quest) {
            finished = true
        } else {
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                self.presentNext()
            }
        }
    }

    func setAutoPaused(_ value: Bool) {
        guard value != autoPaused else { return }
        autoPaused = value
        if value { current = nil; generation += 1 } else { presentNext() }
    }

    func setManualPaused(_ value: Bool) {
        guard value != manualPaused else { return }
        manualPaused = value
        if value { current = nil; generation += 1 } else { presentNext() }
    }

    /// Avanzamento 0...1 per l'indicatore: risposte date sul massimo previsto.
    var progress: Double { finished ? 1 : min(1, Double(trialCount) / Double(stopRule.maxTrials)) }

    /// Stimolo più facile/difficile disegnabile adesso (per registrare i risultati censurati).
    var hardLimitValue: Double { candidates(distanceMM: tracker.effectiveMM).min() ?? 0 }
    var easyLimitValue: Double { candidates(distanceMM: tracker.effectiveMM).max() ?? 0 }

    var meanDistanceCM: Double {
        records.isEmpty ? tracker.effectiveCM : records.map(\.distanceCM).reduce(0, +) / Double(records.count)
    }
}

/// Conversioni sRGB ↔ luminanza lineare (IEC 61966-2-1).
nonisolated enum SRGB {
    /// Valore sRGB codificato (0...1) → luminanza lineare (0...1): curva di gamma.
    static func toLinear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// Luminanza lineare → valore sRGB codificato (inversa).
    static func toEncoded(_ l: Double) -> Double {
        l <= 0.0031308 ? l * 12.92 : 1.055 * pow(l, 1 / 2.4) - 0.055
    }

    /// Contrasto di Weber di una lettera grigia su bianco: C = (L_fondo − L_lettera) / L_fondo,
    /// calcolato sulla luminanza fisica, non sul valore del colore.
    static func weberContrastOnWhite(gray: Int) -> Double {
        1 - toLinear(Double(gray) / 255)
    }

    /// Grigio a 8 bit per ottenere il contrasto di Weber `c` su bianco.
    static func gray(forContrast c: Double) -> Int {
        Int((toEncoded(max(0, 1 - c)) * 255).rounded())
    }
}
