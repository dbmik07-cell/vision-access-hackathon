import Foundation

/// Campo visivo: ZEST per punto (King-Smith e altri, 1994) + matrice dei vicini.
///
/// Scala di sensibilità S da 0 a 10: S = livello di difficoltà più alto che la persona vede.
/// Difficoltà dello stimolo x da 1 (pallino chiarissimo) a 10 (appena più chiaro del fondo).
/// Sono livelli relativi dello schermo, non decibel di un perimetro clinico.
nonisolated struct FieldModel: Sendable {
    /// P(visto | x, S) = fp + (1 − fp − fn) / (1 + e^(β (x − S − 0,5)))
    var falsePositive = 0.03
    var falseNegative = 0.03
    var slope = 2.0

    func pSeen(difficulty x: Double, sensitivity s: Double) -> Double {
        falsePositive + (1 - falsePositive - falseNegative) / (1 + exp(slope * (x - s - 0.5)))
    }

    static let grid: [Double] = stride(from: 0.0, through: 10.0, by: 0.5).map { $0 }

    /// Priore: 85% "sano" (gaussiana media 8, DS 2) + 15% uniforme (può esserci una zona cieca).
    static func prior() -> [Double] {
        let p = grid.map { 0.85 * exp(-pow($0 - 8, 2) / (2 * 4)) / sqrt(2 * .pi * 4) + 0.15 / 11 }
        let sum = p.reduce(0, +)
        return p.map { $0 / sum }
    }
}

/// Un punto del campo con la sua distribuzione di probabilità sulla soglia.
nonisolated struct ZestPoint: Sendable, Identifiable {
    let id: Int
    let x: Double          // gradi, positivo a destra
    let y: Double          // gradi, positivo in alto
    var pdf: [Double] = FieldModel.prior()
    var presentations = 0  // presentazioni ZEST (fase 2)
    var screened = false
    var screeningSeen: Bool?
    var queued = false     // in fase 2
    var done = false
    var seenDifficulties: [Double] = []   // livelli visti (per i falsi negativi)

    var mean: Double { zip(FieldModel.grid, pdf).reduce(0) { $0 + $1.0 * $1.1 } }
    var sd: Double {
        let m = mean
        return sqrt(zip(FieldModel.grid, pdf).reduce(0) { $0 + ($1.0 - m) * ($1.0 - m) * $1.1 })
    }

    /// Bayes sul singolo punto.
    mutating func update(difficulty x: Double, seen: Bool, model: FieldModel) {
        var total = 0.0
        for i in pdf.indices {
            let p = model.pSeen(difficulty: x, sensitivity: FieldModel.grid[i])
            pdf[i] *= seen ? p : 1 - p
            total += pdf[i]
        }
        if total > 0 { pdf = pdf.map { $0 / total } }
        if seen { seenDifficulties.append(x) }
    }

    /// ZEST: il prossimo stimolo è la media del posteriore (arrotondata a un livello 1...10).
    var nextDifficulty: Double { min(10, max(1, mean.rounded())) }

    /// Stop per punto: DS sotto 1 livello, oppure 4 presentazioni.
    var finished: Bool { sd < 1 || presentations >= 4 }
}

nonisolated enum FieldMath {
    /// W_ij = e^(−d²/(2σ²)), σ = 6°: i punti vicini sono correlati (le zone cieche sono macchie).
    static func weight(_ a: ZestPoint, _ b: ZestPoint, sigma: Double = 6) -> Double {
        let d2 = (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
        return exp(-d2 / (2 * sigma * sigma))
    }

    /// Quando un punto termina, sposta le probabilità iniziali dei vicini non ancora misurati
    /// in proporzione al peso: prior_j ← (1 − W_ij) · prior_j + W_ij · posteriore_i.
    static func propagate(from i: Int, points: inout [ZestPoint]) {
        let source = points[i]
        for j in points.indices where j != i && points[j].presentations == 0 && !points[j].done {
            let w = weight(source, points[j])
            guard w > 0.05 else { continue }
            let mixed = zip(points[j].pdf, source.pdf).map { (1 - w) * $0 + w * $1 }
            let s = mixed.reduce(0, +)
            // Se il punto è già stato visto nello screening, conservo quell'informazione.
            if points[j].screened, let seen = points[j].screeningSeen {
                var tmp = points[j]
                tmp.pdf = mixed.map { $0 / s }
                tmp.update(difficulty: FieldSession.screeningDifficulty, seen: seen, model: FieldModel())
                tmp.seenDifficulties = points[j].seenDifficulties
                points[j].pdf = tmp.pdf
            } else {
                points[j].pdf = mixed.map { $0 / s }
            }
        }
    }

    /// Sensibilità attesa in un occhio sano: leggero calo con l'eccentricità.
    static func expected(eccentricity e: Double) -> Double { 9 - 0.05 * e }
}

/// Sessione di un occhio: screening, poi ZEST sui punti non visti e sui loro vicini.
nonisolated struct FieldSession: Sendable {
    static let screeningDifficulty = 4.0   // stimolo "abbastanza forte"
    static let strongDifficulty = 1.0      // per macchia cieca e falsi negativi

    enum Eye: String, Sendable { case right, left }

    let eye: Eye
    var points: [ZestPoint]
    let model = FieldModel()
    var blindSpot: (x: Double, y: Double)
    var blindSpotFound = false

    // Contatori di affidabilità
    var blindSpotCatches = 0, blindSpotSeen = 0
    var fpCatches = 0, fpTapped = 0, fastTaps = 0
    var fnCatches = 0, fnMissed = 0

    init(eye: Eye, demo: Bool) {
        self.eye = eye
        // Griglia ogni 6° a ±3, ±9, ... (simile al 24-2), limitata a quello che lo schermo copre.
        let xs: [Double] = demo ? [-15, -9, -3, 3, 9, 15] : [-21, -15, -9, -3, 3, 9, 15, 21]
        let ys: [Double] = demo ? [-3, 3] : [-9, -3, 3, 9]
        var pts: [ZestPoint] = []
        var id = 0
        for y in ys { for x in xs { pts.append(ZestPoint(id: id, x: x, y: y)); id += 1 } }
        points = pts
        // Macchia cieca naturale: ~15° verso l'esterno (tempia), poco sotto l'orizzonte.
        blindSpot = (eye == .right ? 15 : -15, -1.5)
    }

    /// Punti candidati per localizzare la macchia cieca.
    var blindSpotProbes: [(Double, Double)] {
        let s: Double = eye == .right ? 1 : -1
        return [(15 * s, -1.5), (13 * s, -1.5), (17 * s, -1.5), (15 * s, -3.5), (15 * s, 0.5)]
    }

    mutating func setBlindSpot(unseen: [(Double, Double)]) {
        guard !unseen.isEmpty else { return }
        blindSpot = (unseen.map(\.0).reduce(0, +) / Double(unseen.count),
                     unseen.map(\.1).reduce(0, +) / Double(unseen.count))
        blindSpotFound = true
    }

    mutating func recordScreening(_ i: Int, seen: Bool) {
        points[i].screened = true
        points[i].screeningSeen = seen
        points[i].update(difficulty: Self.screeningDifficulty, seen: seen, model: model)
        if !seen {
            // Non visto: il punto e i suoi vicini passano alla misura completa.
            points[i].queued = true
            for j in points.indices where FieldMath.weight(points[i], points[j]) > 0.3 { points[j].queued = true }
        }
    }

    mutating func recordZest(_ i: Int, difficulty: Double, seen: Bool) {
        points[i].presentations += 1
        points[i].update(difficulty: difficulty, seen: seen, model: model)
        if points[i].finished {
            points[i].done = true
            FieldMath.propagate(from: i, points: &points)
        }
    }

    /// Prossimo punto della fase 2 tra quelli ammessi: quello con l'incertezza più alta.
    func nextZestPoint(allowed: Set<Int>) -> Int? {
        points.indices
            .filter { allowed.contains($0) && points[$0].queued && !points[$0].done }
            .max { points[$0].sd < points[$1].sd }
    }

    // MARK: Risultato

    func result() -> FieldEye {
        let tested = points.filter { $0.screened }
        let fieldPoints = tested.map {
            FieldPoint(x: $0.x, y: $0.y, sensitivity: $0.mean, sd: $0.sd, seen: $0.mean >= 3)
        }
        let defects = tested.filter { $0.mean < FieldMath.expected(eccentricity: hypot($0.x, $0.y)) - 3 }
        let md = tested.isEmpty ? 0 : tested.map { $0.mean - FieldMath.expected(eccentricity: hypot($0.x, $0.y)) }
            .reduce(0, +) / Double(tested.count)

        // Raggio del campo: la distanza del primo punto difettoso dal centro (o il punto più esterno testato).
        let maxEcc = tested.map { hypot($0.x, $0.y) }.max() ?? 0
        let radius = defects.map { hypot($0.x, $0.y) }.min().map { max(0, $0 - 3) } ?? maxEcc

        // Classificazione. "Oltre quanto atteso per caso": più dell'8% dei punti (o più di 1).
        let allowed = max(1, Int((0.08 * Double(tested.count)).rounded()))
        let pattern: FieldPattern
        let centralDefects = defects.filter { hypot($0.x, $0.y) <= 5 }
        if defects.count <= allowed {
            pattern = .nessuna
        } else if centralDefects.count >= 2 {
            pattern = .centrale
        } else if radius < 20, Double(defects.filter { hypot($0.x, $0.y) > radius }.count) >= 0.6 * Double(tested.filter { hypot($0.x, $0.y) > radius }.count) {
            pattern = .tunnel
        } else if defects.allSatisfy({ hypot($0.x, $0.y) > 12 }) {
            pattern = .periferica
        } else {
            pattern = .sparse
        }

        let fl = blindSpotCatches > 0 ? Double(blindSpotSeen) / Double(blindSpotCatches) : 0
        let fp = (fpCatches + fastTaps) > 0 ? Double(fpTapped + fastTaps) / Double(fpCatches + fastTaps) : 0
        let fn = fnCatches > 0 ? Double(fnMissed) / Double(fnCatches) : 0
        // Criteri Humphrey: perdite di fissazione > 20% o falsi positivi > 15% → non affidabile.
        let rel: Reliability = (fl > 0.2 || fp > 0.15) ? .nonAffidabile : (fn > 0.33 || !blindSpotFound ? .dubbio : .affidabile)

        return FieldEye(points: fieldPoints, fieldRadiusDeg: pattern == .nessuna ? maxEcc : radius, meanDefect: md,
                        pattern: pattern, fixationLossRate: fl, falsePositiveRate: fp, falseNegativeRate: fn,
                        reliability: rel, blindSpot: [blindSpot.x, blindSpot.y])
    }
}
