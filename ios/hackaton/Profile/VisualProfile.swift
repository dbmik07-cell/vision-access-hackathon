import Foundation

// Profilo funzionale della vista (SPEC sezione 11). Non è una diagnosi medica.
// Unità: logMAR, log della sensibilità al contrasto, gradi (x a destra, y in alto), cm.

nonisolated enum Reliability: String, Codable, Sendable {
    case affidabile, dubbio
    case nonAffidabile = "non-affidabile"

    var label: String {
        switch self {
        case .affidabile: "affidabile"
        case .dubbio: "dubbio"
        case .nonAffidabile: "non affidabile"
        }
    }
}

nonisolated enum VisionLevel: String, Codable, Sendable, Comparable {
    case normale, lieve, moderato, grave

    private var rank: Int { [.normale: 0, .lieve: 1, .moderato: 2, .grave: 3][self]! }
    static func < (a: Self, b: Self) -> Bool { a.rank < b.rank }

    /// Fasce OMS sull'acuità in logMAR (cecità conteggiata come grave).
    static func from(logMAR: Double) -> VisionLevel {
        switch logMAR {
        case ...0.3: .normale
        case ...0.48: .lieve
        case ...1.0: .moderato
        default: .grave
        }
    }
}

/// Una risposta registrata durante un test (per l'affidabilità e per la verifica con Python).
nonisolated struct TrialRecord: Codable, Sendable, Equatable {
    var stimulus: Double          // logMAR effettivo o log(1/C) effettivo
    var correct: Bool
    var distanceCM: Double
    var responseTimeMs: Double
    var shown: String             // direzione mostrata
    var answered: String          // direzione risposta
    var estimateAfter: Double
    var sdAfter: Double
}

nonisolated struct DeviceInfo: Codable, Sendable {
    var model: String
    var ppi: Double
}

nonisolated struct AcuityResult: Codable, Sendable {
    var logMAR: Double
    var ci95: [Double]            // [basso, alto]
    var slope: Double
    var trials: Int
    var reliability: Reliability
    var flags: [String]
    var meanDistanceCM: Double
    var log: [TrialRecord]
    /// "oltre-limite" / "sotto-limite" se il test si è fermato al limite dello schermo.
    var censored: String? = nil
}

nonisolated struct ContrastResult: Codable, Sendable {
    var logCS: Double
    var ci95: [Double]
    var trials: Int
    var reliability: Reliability
    var flags: [String]
    var letterLogMAR: Double
    var log: [TrialRecord]
    var censored: String? = nil
}

nonisolated struct ReadingSample: Codable, Sendable {
    var logMAR: Double
    var seconds: Double
    var wordsCorrect: Int
    var wordsTotal: Int
    var wpm: Double
}

nonisolated struct ReadingResult: Codable, Sendable {
    var measured: Bool
    var criticalPrintSizeLogMAR: Double
    var ci95: [Double]
    var maxReadingSpeedWpm: Double
    var readingAcuityLogMAR: Double
    var reliability: Reliability
    var flags: [String]
    var samples: [ReadingSample]
}

nonisolated struct AmslerEye: Codable, Sendable {
    /// Matrice 10 × 10: 0 normale, 1 distorta, 2 mancante. cells[riga][colonna], riga 0 in alto.
    var cells: [[Int]]
    var distortedAreaDeg2: Double
    var missingAreaDeg2: Double
    var centralInvolved: Bool
    /// Distanza (gradi) e direzione (gradi, 0 = destra, 90 = alto) del baricentro della zona.
    var centroidDistanceDeg: Double?
    var centroidDirectionDeg: Double?
}

nonisolated struct AmslerResult: Codable, Sendable {
    var right: AmslerEye?
    var left: AmslerEye?

    /// Zona centrale: no / piccola / grande (per R2).
    var centralSeverity: String {
        let eyes = [right, left].compactMap { $0 }
        let worst = eyes.map { $0.distortedAreaDeg2 + $0.missingAreaDeg2 }.max() ?? 0
        if worst == 0 { return "no" }
        return worst >= 6 || eyes.contains(where: { $0.centralInvolved }) ? "grande" : "piccola"
    }
}

nonisolated struct FieldPoint: Codable, Sendable, Equatable {
    var x: Double                 // gradi, positivo a destra
    var y: Double                 // gradi, positivo in alto
    var sensitivity: Double       // livelli 0...10 (relativi, non dB Humphrey)
    var sd: Double
    var seen: Bool
}

nonisolated enum FieldPattern: String, Codable, Sendable {
    case nessuna = "nessuna-riduzione"
    case periferica = "riduzione-periferica"
    case tunnel = "visione-a-tunnel"
    case sparse = "zone-cieche-sparse"
    case centrale = "perdita-centrale"

    var label: String {
        switch self {
        case .nessuna: "nessuna riduzione"
        case .periferica: "riduzione periferica"
        case .tunnel: "visione a tunnel"
        case .sparse: "zone cieche sparse"
        case .centrale: "perdita centrale"
        }
    }
}

nonisolated struct FieldEye: Codable, Sendable {
    var points: [FieldPoint]
    var fieldRadiusDeg: Double
    var meanDefect: Double
    var pattern: FieldPattern
    var fixationLossRate: Double
    var falsePositiveRate: Double
    var falseNegativeRate: Double
    var reliability: Reliability
    var blindSpot: [Double]?      // [x, y] in gradi
}

nonisolated struct VisualFieldResult: Codable, Sendable {
    var right: FieldEye?
    var left: FieldEye?
    /// true se viene da un profilo predefinito della demo, non da un test.
    var isPreset: Bool = false

    var worstRadius: Double? { [right, left].compactMap { $0?.fieldRadiusDeg }.min() }
    var patterns: [FieldPattern] { [right, left].compactMap { $0?.pattern } }
}

nonisolated enum Theme: String, Codable, Sendable {
    case originale, chiaro, scuro
}

nonisolated struct LightResult: Codable, Sendable {
    var preferredTheme: Theme
    var preferredBrightness: Double   // 0...1
    var photophobia: Bool
    var scores: [String: Double]      // punteggi Bradley-Terry delle 4 versioni
    var ambientLux: Double?
}

nonisolated struct ProfileSummary: Codable, Sendable {
    var level: VisionLevel
    var normalVision: Bool
    var overallReliability: Reliability
    var reasons: [String] = []
}

nonisolated struct UserAdjustments: Codable, Sendable {
    /// Correzione manuale della dimensione del testo, a passi di 0,1 logMAR (R10).
    var textSizeOffsetLogMAR: Double = 0
}

nonisolated struct VisualProfile: Codable, Sendable {
    var version = 1
    var createdAt = Date()
    var device = DeviceInfo(model: DeviceDisplay.modelIdentifier, ppi: DeviceDisplay.ppi)
    var acuity: AcuityResult?
    var contrast: ContrastResult?
    var reading: ReadingResult?
    var amsler: AmslerResult?
    var visualField: VisualFieldResult?
    var light: LightResult?
    var summary = ProfileSummary(level: .normale, normalVision: false, overallReliability: .dubbio)
    var userAdjustments = UserAdjustments()
}
