import Foundation

// VisualProfile secondo il contratto dati (docs/data-contracts.md, sezione 8), schemaVersion "1.0".
// Profilo funzionale della vista, non una diagnosi medica.
// Blocchi obbligatori: device, acuity, contrast, summary. Opzionali (assenti se non misurati):
// reading, amsler, visualField, light, userAdjustments. Ogni blocco di risultato ha source.

nonisolated enum ContractReliability: String, Codable, Sendable, Comparable {
    case reliable, doubtful, unreliable

    private var rank: Int { [.reliable: 0, .doubtful: 1, .unreliable: 2][self]! }
    static func < (a: Self, b: Self) -> Bool { a.rank < b.rank }

    var label: String {
        switch self {
        case .reliable: "reliable"
        case .doubtful: "doubtful"
        case .unreliable: "unreliable"
        }
    }
}

nonisolated enum BlockSource: String, Codable, Sendable { case measured, preset }

/// Categoria OMS (ICD-11) dalla mediana dell'acuità.
nonisolated enum WHOCategory: String, Codable, Sendable, Comparable {
    case none, mild, moderate, severe, blindness

    private var rank: Int { [.none: 0, .mild: 1, .moderate: 2, .severe: 3, .blindness: 4][self]! }
    static func < (a: Self, b: Self) -> Bool { a.rank < b.rank }

    static func from(logMAR m: Double) -> WHOCategory {
        typealias P = ContractParameters
        if m > P.whoBlindnessAbove { return .blindness }
        if m > P.whoSevereAbove { return .severe }
        if m > P.whoModerateAbove { return .moderate }
        if m > P.whoMildAbove { return .mild }
        return .none
    }

    var label: String {
        switch self {
        case .none: "no deficit"
        case .mild: "mild"
        case .moderate: "moderate"
        case .severe: "severe"
        case .blindness: "blindness"
        }
    }
}

/// Fascia del contrasto dalla mediana (stesse soglie di R3, estremo inferiore incluso).
nonisolated enum ContrastBand: String, Codable, Sendable {
    case normal, borderline, reduced, severelyReduced

    static func from(logCS x: Double) -> ContrastBand {
        typealias P = ContractParameters
        if x >= P.contrastNormalMin { return .normal }
        if x >= P.contrastBorderlineMin { return .borderline }
        if x >= P.contrastReducedMin { return .reduced }
        return .severelyReduced
    }

    var label: String {
        switch self {
        case .normal: "normal"
        case .borderline: "borderline"
        case .reduced: "reduced"
        case .severelyReduced: "severely reduced"
        }
    }
}

nonisolated struct DeviceBlock: Codable, Sendable, Equatable {
    var modelIdentifier: String
    var ppi: Double
    var nativeScale: Double
}

nonisolated struct AcuityBlock: Codable, Sendable, Equatable {
    var source: BlockSource
    var logMAR: Double                 // mediana
    var ci95: [Double]                 // [basso, alto]
    var reliability: ContractReliability
    var flags: [String]
    var whoCategory: WHOCategory
    var trials: Int?
    var displayLimitLogMAR: Double?
    var censoredAtDisplayLimit: Bool?
}

nonisolated struct ContrastBlock: Codable, Sendable, Equatable {
    var source: BlockSource
    var logCS: Double                  // mediana
    var ci95: [Double]
    var reliability: ContractReliability
    var flags: [String]
    var band: ContrastBand
    var trials: Int?
    var ceilingLogCS: Double?
    var censoredAtCeiling: Bool?
}

nonisolated struct AmslerEye: Codable, Sendable, Equatable {
    var distortedAreaDeg2: Double
    var missingAreaDeg2: Double
    var centralInvolved: Bool
    /// Matrice 10 × 10: 0 normale, 1 distorta, 2 mancante. cells[riga][colonna], riga 0 in alto.
    var cells: [[Int]]?

    var hasProblem: Bool { distortedAreaDeg2 + missingAreaDeg2 > 0 || centralInvolved }
}

nonisolated struct AmslerBlock: Codable, Sendable, Equatable {
    var source: BlockSource
    var right: AmslerEye?
    var left: AmslerEye?

    var eyes: [AmslerEye] { [right, left].compactMap { $0 } }
    var centralInvolved: Bool { eyes.contains { $0.centralInvolved } }
    var hasProblem: Bool { eyes.contains { $0.hasProblem } }
}

nonisolated struct FieldPoint: Codable, Sendable, Equatable {
    var x: Double                 // gradi, positivo a destra
    var y: Double                 // gradi, positivo in alto
    var sensitivity: Double       // livelli 0...10 (relativi, non dB Humphrey)
    var sd: Double
    var seen: Bool

    // Nomi del contratto (sezione 8): xDeg, yDeg.
    enum CodingKeys: String, CodingKey {
        case x = "xDeg", y = "yDeg", sensitivity, sd, seen
    }
}

nonisolated enum FieldPattern: String, Codable, Sendable {
    case none, peripheral, tunnel, scattered

    var label: String {
        switch self {
        case .none: "no reduction"
        case .peripheral: "peripheral reduction"
        case .tunnel: "tunnel vision"
        case .scattered: "scattered blind spots"
        }
    }
}

nonisolated struct FieldEye: Codable, Sendable, Equatable {
    var fieldRadiusDeg: Double
    var pattern: FieldPattern
    // Dati grezzi e indici di affidabilità: opzionali.
    var points: [FieldPoint]?
    var meanDefect: Double?
    var fixationLossRate: Double?
    var falsePositiveRate: Double?
    var falseNegativeRate: Double?
    var reliability: ContractReliability?
    var blindSpot: [Double]?
}

nonisolated struct VisualFieldBlock: Codable, Sendable, Equatable {
    var source: BlockSource
    var right: FieldEye?
    var left: FieldEye?

    var eyes: [FieldEye] { [right, left].compactMap { $0 } }
    var hasProblem: Bool { eyes.contains { $0.pattern != .none } }
}

nonisolated enum PreferredTheme: String, Codable, Sendable { case light, dark }

nonisolated struct LightBlock: Codable, Sendable, Equatable {
    var source: BlockSource
    var photophobia: Bool
    var preferredTheme: PreferredTheme?
    var preferredBrightness: Double?
}

/// Lettura: blocco riservato nel contratto (post-MVP, campi da definire): solo `source`.
/// I dati misurati veri e propri sono in `ReadingMeasurement`, fuori dal `VisualProfile`
/// esportato (non fanno parte dello schema condiviso).
nonisolated struct ReadingBlock: Codable, Sendable, Equatable {
    var source: BlockSource
}

nonisolated struct ReadingSample: Codable, Sendable, Equatable {
    var logMAR: Double
    var seconds: Double
    var wordsCorrect: Int
    var wordsTotal: Int
    var wpm: Double
}

/// Risultato del test di lettura (post-MVP, fuori dal contratto): dati dell'app, non del VisualProfile.
nonisolated struct ReadingMeasurement: Codable, Sendable, Equatable {
    var source: BlockSource
    var measured: Bool
    var criticalPrintSizeLogMAR: Double
    var ci95: [Double]
    var maxReadingSpeedWpm: Double
    var readingAcuityLogMAR: Double
    var reliability: ContractReliability
    var flags: [String]
    var samples: [ReadingSample]?
}

nonisolated struct SummaryBlock: Codable, Sendable, Equatable {
    var normalVision: Bool
    /// Peggiore tra i blocchi misurati; null se nessun blocco è misurato.
    var overallReliability: ContractReliability?

    enum CodingKeys: String, CodingKey { case normalVision, overallReliability }

    init(normalVision: Bool, overallReliability: ContractReliability?) {
        self.normalVision = normalVision
        self.overallReliability = overallReliability
    }

    // null esplicito per overallReliability (il campo c'è sempre).
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(normalVision, forKey: .normalVision)
        try c.encode(overallReliability, forKey: .overallReliability)
    }
}

nonisolated struct UserAdjustments: Codable, Sendable, Equatable {
    /// Correzione manuale della dimensione del testo, a passi di 0,1 logMAR (R10).
    var textSizeOffsetLogMAR: Double = 0
}

nonisolated struct VisualProfile: Codable, Sendable, Equatable {
    var schemaVersion = ContractParameters.schemaVersion
    var device: DeviceBlock
    var acuity: AcuityBlock
    var contrast: ContrastBlock
    var summary = SummaryBlock(normalVision: false, overallReliability: nil)
    var reading: ReadingBlock?
    var amsler: AmslerBlock?
    var visualField: VisualFieldBlock?
    var light: LightBlock?
    var userAdjustments: UserAdjustments?

    var textSizeOffset: Double { userAdjustments?.textSizeOffsetLogMAR ?? 0 }
}

/// Una risposta registrata durante un test (dati dell'app, fuori dal profilo del contratto).
nonisolated struct TrialRecord: Codable, Sendable, Equatable {
    var stimulus: Double
    var correct: Bool
    var distanceCM: Double
    var responseTimeMs: Double
    var shown: String
    var answered: String
    var estimateAfter: Double
    var sdAfter: Double
}
