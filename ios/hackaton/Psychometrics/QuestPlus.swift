import Foundation

// MARK: - Funzione psicometrica

/// P(giusta | x) = γ + (1 − γ − λ) · 1 / (1 + e^(−β (x − t)))
///
/// x è la variabile di "facilità" (contratto, sezione 5): cresce con la visibilità dello stimolo.
/// Acuità: x = logMAR della lettera. Contrasto: x = log10(C di Weber), da −2,1 a 0.
///
/// - γ (guess): probabilità di indovinare tirando a caso (0,25 con 4 direzioni).
/// - λ (lapse): errori da distrazione anche su stimoli chiaramente visibili.
/// - β (slope): quanto è netto il passaggio da "vedo" a "non vedo".
/// - t: soglia, il punto di metà salita della curva.
nonisolated struct PsychometricFunction: Sendable, Codable, Equatable {
    var guess: Double = 0.25
    var lapse: Double = 0.02
    /// Sempre true nel contratto (variabile di facilità); false resta solo per compatibilità.
    var increasingWithStimulus: Bool = true

    func pCorrect(stimulus s: Double, threshold t: Double, slope b: Double) -> Double {
        let x = increasingWithStimulus ? (s - t) : (t - s)
        return guess + (1 - guess - lapse) / (1 + exp(-b * x))
    }
}

// MARK: - QUEST+

/// QUEST+ (Watson, 2017) su due parametri: soglia e pendenza.
///
/// Idea: teniamo una griglia di ipotesi (soglia, pendenza), ognuna con una probabilità.
/// 1. Dopo ogni risposta aggiorniamo le probabilità con Bayes:
///    posteriore(h) ∝ priore(h) · P(risposta | stimolo, h)
/// 2. Scegliamo il prossimo stimolo che minimizza l'entropia attesa del posteriore,
///    cioè quello da cui ci aspettiamo di imparare di più.
nonisolated struct QuestPlus: Sendable {
    struct Trial: Sendable, Codable, Equatable {
        var stimulus: Double
        var correct: Bool
    }

    let thresholds: [Double]
    let slopes: [Double]
    let function: PsychometricFunction
    /// Probabilità di ogni ipotesi, indice = iSoglia · slopes.count + iPendenza. Somma 1.
    private(set) var posterior: [Double]
    private(set) var trials: [Trial] = []

    init(thresholds: [Double], slopes: [Double], function: PsychometricFunction, prior: [Double]? = nil) {
        precondition(!thresholds.isEmpty && !slopes.isEmpty)
        self.thresholds = thresholds
        self.slopes = slopes
        self.function = function
        let n = thresholds.count * slopes.count
        if let prior, prior.count == n {
            let sum = prior.reduce(0, +)
            posterior = prior.map { $0 / sum }
        } else {
            // Priore uniforme: nessuna ipotesi preferita all'inizio.
            posterior = Array(repeating: 1.0 / Double(n), count: n)
        }
    }

    /// Griglia regolare inclusiva: da `from` a `to` con passo `step`.
    static func grid(from: Double, to: Double, step: Double) -> [Double] {
        let n = Int(((to - from) / step).rounded())
        return (0...n).map { from + Double($0) * step }
    }

    // MARK: Aggiornamento bayesiano

    /// Formula di Bayes: moltiplico ogni ipotesi per la verosimiglianza della risposta e normalizzo.
    mutating func update(stimulus: Double, correct: Bool) {
        var total = 0.0
        for ti in thresholds.indices {
            for si in slopes.indices {
                let i = ti * slopes.count + si
                let p = function.pCorrect(stimulus: stimulus, threshold: thresholds[ti], slope: slopes[si])
                posterior[i] *= correct ? p : (1 - p)
                total += posterior[i]
            }
        }
        if total > 0 {
            for i in posterior.indices { posterior[i] /= total }
        }
        trials.append(Trial(stimulus: stimulus, correct: correct))
    }

    // MARK: Scelta dello stimolo

    /// Entropia attesa dopo aver mostrato `stimulus`:
    /// E[H] = Σ_r P(r) · H(posteriore | r),  r ∈ {giusta, sbagliata}
    /// con H(p) = −Σ p log p (in nat).
    func expectedEntropy(stimulus: Double) -> Double {
        var pCorrectTotal = 0.0
        var likelihoods = [Double](repeating: 0, count: posterior.count)
        for ti in thresholds.indices {
            for si in slopes.indices {
                let i = ti * slopes.count + si
                let p = function.pCorrect(stimulus: stimulus, threshold: thresholds[ti], slope: slopes[si])
                likelihoods[i] = p
                pCorrectTotal += posterior[i] * p
            }
        }
        let pWrongTotal = 1 - pCorrectTotal
        var hCorrect = 0.0, hWrong = 0.0
        for i in posterior.indices {
            if pCorrectTotal > 0 {
                let q = posterior[i] * likelihoods[i] / pCorrectTotal
                if q > 0 { hCorrect -= q * log(q) }
            }
            if pWrongTotal > 0 {
                let q = posterior[i] * (1 - likelihoods[i]) / pWrongTotal
                if q > 0 { hWrong -= q * log(q) }
            }
        }
        return pCorrectTotal * hCorrect + pWrongTotal * hWrong
    }

    /// Lo stimolo, tra quelli ammissibili adesso, con l'entropia attesa minima.
    /// Spareggio (contratto): stimoli entro 1e-12 dal minimo sono pari, vince l'indice più basso nella lista.
    func nextStimulusIndex(candidates: [Double]) -> Int? {
        guard !candidates.isEmpty else { return nil }
        let h = candidates.map { expectedEntropy(stimulus: $0) }
        let best = h.min()!
        return h.firstIndex { $0 <= best + ContractParameters.tieTolerance }
    }

    func nextStimulus(candidates: [Double]) -> Double? {
        nextStimulusIndex(candidates: candidates).map { candidates[$0] }
    }

    // MARK: Statistiche sul posteriore

    /// Distribuzione marginale della soglia (sommo sulle pendenze).
    var thresholdMarginal: [Double] {
        thresholds.indices.map { ti in
            slopes.indices.reduce(0) { $0 + posterior[ti * slopes.count + $1] }
        }
    }

    var slopeMarginal: [Double] {
        slopes.indices.map { si in
            thresholds.indices.reduce(0) { $0 + posterior[$1 * slopes.count + si] }
        }
    }

    /// Media a posteriori della soglia: la stima.
    var thresholdMean: Double {
        zip(thresholds, thresholdMarginal).reduce(0) { $0 + $1.0 * $1.1 }
    }

    /// Deviazione standard a posteriori della soglia: quanto siamo incerti.
    var thresholdSD: Double {
        let m = thresholdMean
        let v = zip(thresholds, thresholdMarginal).reduce(0) { $0 + ($1.0 - m) * ($1.0 - m) * $1.1 }
        return sqrt(max(0, v))
    }

    var slopeMean: Double {
        zip(slopes, slopeMarginal).reduce(0) { $0 + $1.0 * $1.1 }
    }

    /// Quantile con la convenzione a bin (contratto, sezione 5; ADR 0002):
    /// il punto t_i distribuisce la sua massa uniformemente su [t_i − h/2, t_i + h/2],
    /// quindi la CDF è continua e lineare a tratti. q = min{x : F(x) ≥ q}: primo bin con p_i > 0
    /// in cui la somma cumulata raggiunge q, interpolazione lineare nel bin, limite alla griglia.
    func thresholdQuantile(_ q: Double) -> Double {
        let marginal = thresholdMarginal
        let h = thresholds.count > 1 ? thresholds[1] - thresholds[0] : ContractParameters.thresholdStep
        var cumulative = 0.0
        for (i, p) in marginal.enumerated() where p > 0 {
            if cumulative + p >= q {
                let x = thresholds[i] - h / 2 + h * (q - cumulative) / p
                return min(max(x, thresholds.first!), thresholds.last!)
            }
            cumulative += p
        }
        return thresholds.last!
    }

    /// Stima pubblicata: la mediana della marginale.
    var thresholdMedian: Double { thresholdQuantile(0.5) }

    /// Intervallo al 95%: quantili 2,5% e 97,5% del posteriore.
    var ci95: ClosedRange<Double> {
        let lo = thresholdQuantile(0.025), hi = thresholdQuantile(0.975)
        return min(lo, hi)...max(lo, hi)
    }

    /// P(soglia < x) secondo il posteriore.
    func probability(thresholdBelow x: Double) -> Double {
        zip(thresholds, thresholdMarginal).reduce(0) { $0 + ($1.0 < x ? $1.1 : 0) }
    }

    /// Probabilità che la soglia stia nella stessa fascia della stima,
    /// date le soglie tra fasce (es. OMS: 0,3 / 0,48 / 1,0 / 1,3). Serve alla regola di stop (SPEC 6).
    func categoryConfidence(boundaries: [Double]) -> Double {
        let edges = [-Double.infinity] + boundaries.sorted() + [Double.infinity]
        let m = thresholdMean
        guard let k = (0..<(edges.count - 1)).first(where: { m > edges[$0] && m <= edges[$0 + 1] }) else { return 1 }
        return probability(thresholdBelow: edges[k + 1] + 1e-9) - probability(thresholdBelow: edges[k] + 1e-9)
    }

    /// Log-verosimiglianza delle risposte date le stime a posteriori (per l'affidabilità, SPEC 6).
    func logLikelihoodAtEstimate() -> Double {
        let t = thresholdMean, b = slopeMean
        return trials.reduce(0) { sum, trial in
            let p = function.pCorrect(stimulus: trial.stimulus, threshold: t, slope: b)
            return sum + log(max(1e-9, trial.correct ? p : 1 - p))
        }
    }
}

// MARK: - Regola di stop

nonisolated struct StopRule: Sendable {
    var minTrials: Int
    var maxTrials: Int
    var targetSD: Double

    /// Contratto: stop se (n ≥ 12 e SD < obiettivo) oppure n = 30. SD calcolata sui punti della griglia.
    func shouldStop(_ q: QuestPlus) -> Bool {
        let n = q.trials.count
        if n >= maxTrials { return true }
        return n >= minTrials && q.thresholdSD < targetSD
    }
}

// MARK: - Configurazioni dei test (contratto, sezione 5)

nonisolated enum QuestConfigs {
    typealias P = ContractParameters

    static func acuity() -> QuestPlus {
        QuestPlus(thresholds: QuestPlus.grid(from: P.acuityThresholdMin, to: P.acuityThresholdMax, step: P.thresholdStep),
                  slopes: P.acuityBetas,
                  function: PsychometricFunction(guess: P.guessRate, lapse: P.lapseRate, increasingWithStimulus: true))
    }

    /// Contrasto: t e stimoli su log10(C di Weber) in [−2,1, 0]. logCS = −t.
    static func contrast() -> QuestPlus {
        QuestPlus(thresholds: QuestPlus.grid(from: P.contrastThresholdMin, to: P.contrastThresholdMax, step: P.thresholdStep),
                  slopes: P.contrastBetas,
                  function: PsychometricFunction(guess: P.guessRate, lapse: P.lapseRate, increasingWithStimulus: true))
    }

    /// Modalità demo (fuori contratto, solo per la presentazione): test più corti.
    static func acuityStop(demo: Bool) -> StopRule {
        demo ? StopRule(minTrials: 8, maxTrials: 16, targetSD: 0.08)
             : StopRule(minTrials: P.minTrials, maxTrials: P.maxTrials, targetSD: P.acuityTargetSd)
    }

    static func contrastStop(demo: Bool) -> StopRule {
        demo ? StopRule(minTrials: 8, maxTrials: 14, targetSD: 0.12)
             : StopRule(minTrials: P.minTrials, maxTrials: P.maxTrials, targetSD: P.contrastTargetSd)
    }

    /// Affidabilità MVP: reliable se q97,5 − q2,5 ≤ W, altrimenti doubtful con flag wideInterval.
    static func reliability(_ q: QuestPlus) -> (ContractReliability, [String]) {
        var flags: [String] = []
        let width = q.ci95.upperBound - q.ci95.lowerBound
        let rel: ContractReliability = width <= P.reliabilityMaxCiWidth ? .reliable : .doubtful
        if rel == .doubtful { flags.append("wideInterval") }
        if q.trials.count >= P.maxTrials && q.thresholdSD >= (q.thresholds.first! < -1 ? P.contrastTargetSd : P.acuityTargetSd) {
            flags.append("maxTrialsReached")
        }
        return (rel, flags)
    }
}
