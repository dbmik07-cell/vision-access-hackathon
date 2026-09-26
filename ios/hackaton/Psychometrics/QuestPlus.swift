import Foundation

// MARK: - Funzione psicometrica

/// P(giusta | s) = γ + (1 − γ − λ) · 1 / (1 + e^(−β (s − t)))
///
/// - γ (guess): probabilità di indovinare tirando a caso (0,25 con 4 direzioni).
/// - λ (lapse): errori da distrazione anche su stimoli chiaramente visibili.
/// - β (slope): quanto è netto il passaggio da "vedo" a "non vedo".
/// - t: soglia, il punto di metà salita della curva.
nonisolated struct PsychometricFunction: Sendable, Codable, Equatable {
    var guess: Double = 0.25
    var lapse: Double = 0.02
    /// true: stimolo più grande = più facile (acuità in logMAR).
    /// false: stimolo più grande = più difficile (contrasto in log 1/C).
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

    /// Lo stimolo, tra quelli mostrabili adesso, con l'entropia attesa minima.
    func nextStimulus(candidates: [Double]) -> Double? {
        candidates.min { expectedEntropy(stimulus: $0) < expectedEntropy(stimulus: $1) }
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

    /// Quantile della marginale della soglia (con interpolazione lineare nella cella).
    func thresholdQuantile(_ q: Double) -> Double {
        let marginal = thresholdMarginal
        var cumulative = 0.0
        for (i, p) in marginal.enumerated() {
            if cumulative + p >= q {
                let fraction = p > 0 ? (q - cumulative) / p : 0
                let step = i + 1 < thresholds.count ? thresholds[i + 1] - thresholds[i]
                    : (i > 0 ? thresholds[i] - thresholds[i - 1] : 0)
                return thresholds[i] + (fraction - 0.5) * step
            }
            cumulative += p
        }
        return thresholds.last!
    }

    /// Intervallo di credibilità al 95%: quantili 2,5% e 97,5% del posteriore.
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
    /// Confini tra categorie: si continua finché la categoria non è certa al 95%.
    var categoryBoundaries: [Double] = []
    var categoryConfidence: Double = 0.95

    /// Mai prima di minTrials; stop a maxTrials; altrimenti stop quando
    /// DS < obiettivo E la categoria è certa al 95%.
    func shouldStop(_ q: QuestPlus) -> Bool {
        let n = q.trials.count
        if n < minTrials { return false }
        if n >= maxTrials { return true }
        let precise = q.thresholdSD < targetSD
        let certain = categoryBoundaries.isEmpty
            || q.categoryConfidence(boundaries: categoryBoundaries) >= categoryConfidence
        return precise && certain
    }
}

// MARK: - Configurazioni dei test

nonisolated enum QuestConfigs {
    /// Acuità: soglia da −0,3 a 1,8 logMAR (passo 0,02), 5 pendenze.
    static func acuity() -> QuestPlus {
        QuestPlus(thresholds: QuestPlus.grid(from: -0.3, to: 1.8, step: 0.02),
                  slopes: [4, 8, 15, 25, 40],
                  function: PsychometricFunction(guess: 0.25, lapse: 0.02, increasingWithStimulus: true))
    }

    /// Fasce OMS in logMAR (SPEC 5.1).
    static let whoBoundaries = [0.3, 0.48, 1.0, 1.3]

    static func acuityStop(demo: Bool) -> StopRule {
        demo ? StopRule(minTrials: 8, maxTrials: 16, targetSD: 0.08, categoryBoundaries: [0.3])
             : StopRule(minTrials: 12, maxTrials: 30, targetSD: 0.05, categoryBoundaries: whoBoundaries)
    }

    /// Contrasto: log della sensibilità da 0 a 2,1. Lo stimolo è log10(1/C):
    /// più è alto, più la lettera è sbiadita (più difficile).
    static func contrast() -> QuestPlus {
        QuestPlus(thresholds: QuestPlus.grid(from: 0, to: 2.1, step: 0.02),
                  slopes: [4, 8, 15, 25, 40],
                  function: PsychometricFunction(guess: 0.25, lapse: 0.02, increasingWithStimulus: false))
    }

    static let contrastBoundaries = [1.0, 1.5]

    static func contrastStop(demo: Bool) -> StopRule {
        demo ? StopRule(minTrials: 8, maxTrials: 14, targetSD: 0.12, categoryBoundaries: [1.5])
             : StopRule(minTrials: 10, maxTrials: 30, targetSD: 0.08, categoryBoundaries: contrastBoundaries)
    }
}
