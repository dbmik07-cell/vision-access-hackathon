import Foundation

/// Tutti i parametri numerici del contratto dati (docs/data-contracts.md, versione 1.0).
/// shared/parameters.json non esiste ancora: i nomi qui sono quelli previsti per quel file,
/// così che si possano sostituire con la lettura della risorsa senza toccare il resto del codice.
nonisolated enum ContractParameters {
    static let schemaVersion = "1.0"

    // MARK: Geometria (sezione 7) e distanza di riferimento del piano (sezione 9, ADR 0003)
    static let referenceDistanceMm = 400.0
    /// Fascia di test per acuità e contrasto: 35–45 cm.
    static let testDistanceMinMm = 350.0
    static let testDistanceMaxMm = 450.0
    /// Tratto minimo della E in pixel del dispositivo.
    static let minStrokeDevicePx = 2.0

    // MARK: QUEST+ (sezione 5)
    static let guessRate = 0.25          // gamma
    static let lapseRate = 0.02          // lambda
    static let acuityThresholdMin = -0.30
    static let acuityThresholdMax = 1.80
    static let contrastThresholdMin = -2.10   // log10(C di Weber)
    static let contrastThresholdMax = 0.00
    static let thresholdStep = 0.02
    static let acuityBetas: [Double] = [6, 10, 15, 24, 35]
    static let contrastBetas: [Double] = [5, 7, 10, 14, 20]
    static let minTrials = 12
    static let maxTrials = 30
    static let acuityTargetSd = 0.05
    static let contrastTargetSd = 0.08
    /// Stimoli con entropia attesa entro questa tolleranza dal minimo sono pari: vince l'indice più basso.
    static let tieTolerance = 1e-12
    /// Affidabilità: reliable se la larghezza di ci95 è al massimo W.
    static let reliabilityMaxCiWidth = 0.30

    // MARK: Contrasto (sezione 6)
    static let contrastLetterMinDeg = 3.0
    static let contrastLetterMaxDeg = 8.0
    static let contrastLetterAcuityOffsetLogMAR = 0.6

    // MARK: Categorie (sezione 6)
    /// Soglie ICD-11 sulla mediana in logMAR: none ≤ 0,3 < mild ≤ 0,48 < moderate ≤ 1,0 < severe ≤ 1,3 < blindness.
    static let whoMildAbove = 0.30
    static let whoModerateAbove = 0.48
    static let whoSevereAbove = 1.00
    static let whoBlindnessAbove = 1.30
    /// Fasce di contrasto in logCS (estremo inferiore incluso).
    static let contrastNormalMin = 1.65
    static let contrastBorderlineMin = 1.50
    static let contrastReducedMin = 1.00
    /// Limiti di summary.normalVision.
    static let normalVisionAcuityMax = 0.30
    static let normalVisionContrastMin = 1.50

    // MARK: Regole (sezione 9)
    static let r0PrudentShift = 0.1
    static let r1AcuityReserveLogMAR = 0.4
    static let r1ReadingMarginLogMAR = 0.1
    static let xHeightArcminAtZero = 5.0          // altezza della x = 5′·10^s (MNREAD)
    /// Atkinson Hyperlegible 1.006: sxHeight 496 / unitsPerEm 1000.
    static let fontXHeightRatio = 0.496
    /// Atkinson Hyperlegible 1.006: avanzamento del glifo "0" 648 / unitsPerEm 1000.
    static let fontZeroWidthEm = 0.648
    static let fontFamily = "Atkinson Hyperlegible"
    static let fontVersion = "1.006"

    static let wcagLineHeight = 1.5
    static let wcagParagraphSpacingEm = 2.0
    static let wcagLetterSpacingEm = 0.12
    static let wcagWordSpacingEm = 0.16
    static let centralLineHeight = 2.0
    static let centralLetterSpacingEm = 0.18
    static let centralWordSpacingEm = 0.24
    static let lineLengthFieldFactor = 0.8
    static let minLineWidthCh = 15.0
    static let maxLineWidthCh = 60.0

    static let darkBackground = "#121212"
    static let darkText = "#E8E6E3"
    /// Tema chiaro: bianco caldo (scelta di Rocco, sezione 14).
    static let lightBackground = "#FAF7F0"
    static let lightText = "#1A1A1A"
    static let dimmedImageBrightness = 0.85

    static let minTargetPtBase = 44.0
    static let minTargetPtMax = 64.0
    static let minTargetReferenceCssPx = 16.0
    static let focusOutlinePx = 3.0

    // MARK: Preset
    static let tunnelPresetRadiusDeg = 5.0
}
