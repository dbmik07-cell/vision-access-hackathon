import Foundation

/// Lettore di shared/parameters.json e shared/devices.json, inclusi come risorse nell'app
/// (contratto, sezione 2: "nessuno ricopia i numeri nel codice").
nonisolated enum SharedContract {
    /// parameters.json come dizionario.
    static let parameters: [String: Any] = load("parameters")
    /// devices.json → modelIdentifier → (nome, ppi).
    static let devices: [String: (name: String, ppi: Double)] = {
        let root = load("devices")
        guard let list = root["devices"] as? [String: [String: Any]] else { return [:] }
        return list.compactMapValues { entry in
            guard let ppi = (entry["ppi"] as? NSNumber)?.doubleValue else { return nil }
            return (entry["name"] as? String ?? "", ppi)
        }
    }()

    private static func load(_ name: String) -> [String: Any] {
        let bundles = [Bundle.main] + Bundle.allBundles
        for b in bundles {
            if let url = b.url(forResource: name, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return obj
            }
        }
        assertionFailure("shared/\(name).json mancante nel bundle")
        return [:]
    }

    /// Il campo "value" di un parametro, dato il percorso (es. "acuity", "stopSd").
    static func value(_ path: String...) -> Any? {
        var node: Any? = parameters
        for key in path { node = (node as? [String: Any])?[key] }
        return (node as? [String: Any])?["value"]
    }

    static func number(_ path: String...) -> Double {
        var node: Any? = parameters
        for key in path { node = (node as? [String: Any])?[key] }
        guard let n = ((node as? [String: Any])?["value"] as? NSNumber)?.doubleValue else {
            fatalError("parametro mancante in parameters.json: \(path.joined(separator: "."))")
        }
        return n
    }

    /// Campo di un valore oggetto, es. number("geometry", "testBandMm", field: "min").
    static func field(_ path: [String], _ key: String) -> Double {
        var node: Any? = parameters
        for k in path { node = (node as? [String: Any])?[k] }
        guard let n = (((node as? [String: Any])?["value"] as? [String: Any])?[key] as? NSNumber)?.doubleValue else {
            fatalError("parametro mancante in parameters.json: \(path.joined(separator: ".")).\(key)")
        }
        return n
    }

    static func numbers(_ path: String...) -> [Double] {
        var node: Any? = parameters
        for key in path { node = (node as? [String: Any])?[key] }
        return ((node as? [String: Any])?["value"] as? [NSNumber])?.map(\.doubleValue) ?? []
    }

    static func string(_ path: String...) -> String? {
        var node: Any? = parameters
        for key in path { node = (node as? [String: Any])?[key] }
        return (node as? [String: Any])?["value"] as? String
    }
}

/// Parametri del contratto con nomi Swift stabili; i valori arrivano da shared/parameters.json.
nonisolated enum ContractParameters {
    typealias S = SharedContract

    static let schemaVersion = (S.parameters["schemaVersion"] as? String) ?? "1.0"

    // MARK: Geometria (sezione 7) e distanza di riferimento (sezione 9, ADR 0003)
    static let referenceDistanceMm = S.number("geometry", "referenceDistanceMm")
    static let testDistanceMinMm = S.field(["geometry", "testBandMm"], "min")
    static let testDistanceMaxMm = S.field(["geometry", "testBandMm"], "max")
    static let mmPerInch = S.number("geometry", "mmPerInch")
    static let minStrokeDevicePx = S.number("acuity", "minStrokeDevicePx")
    static let letterHeightArcminAtZero = S.number("acuity", "letterHeightArcminAtZero")

    // MARK: QUEST+ (sezione 5)
    static let guessRate = S.number("psychometric", "gamma")
    static let lapseRate = S.number("psychometric", "lambda")
    static let acuityThresholdMin = S.field(["acuity", "thresholdGrid"], "min")
    static let acuityThresholdMax = S.field(["acuity", "thresholdGrid"], "max")
    static let acuityThresholdStep = S.field(["acuity", "thresholdGrid"], "step")
    static let contrastThresholdMin = S.field(["contrast", "thresholdGrid"], "min")
    static let contrastThresholdMax = S.field(["contrast", "thresholdGrid"], "max")
    static let contrastThresholdStep = S.field(["contrast", "thresholdGrid"], "step")
    static let thresholdStep = acuityThresholdStep
    static let acuityBetas = S.numbers("acuity", "betaGrid")
    static let contrastBetas = S.numbers("contrast", "betaGrid")
    static let minTrials = Int(S.number("quest", "minTrials"))
    static let maxTrials = Int(S.number("quest", "maxTrials"))
    static let acuityTargetSd = S.number("acuity", "stopSd")
    static let contrastTargetSd = S.number("contrast", "stopSd")
    static let tieTolerance = S.number("quest", "tieEpsilon")
    static let acuityReliableMaxCiWidth = S.number("acuity", "reliableMaxCiWidth")
    static let contrastReliableMaxCiWidth = S.number("contrast", "reliableMaxCiWidth")
    static let reliabilityMaxCiWidth = acuityReliableMaxCiWidth
    static let ciQuantiles = S.numbers("quest", "ciQuantiles")

    // MARK: Contrasto (sezione 6)
    static let contrastLetterMinDeg = S.number("contrast", "letterMinDeg")
    static let contrastLetterMaxDeg = S.number("contrast", "letterMaxDeg")
    static let contrastLetterAcuityOffsetLogMAR = S.number("contrast", "letterAcuityOffsetLogMAR")

    // MARK: Categorie (sezione 6)
    static let whoMildAbove = S.field(["acuity", "whoCategoryLowerBoundsExclusive"], "mild")
    static let whoModerateAbove = S.field(["acuity", "whoCategoryLowerBoundsExclusive"], "moderate")
    static let whoSevereAbove = S.field(["acuity", "whoCategoryLowerBoundsExclusive"], "severe")
    static let whoBlindnessAbove = S.field(["acuity", "whoCategoryLowerBoundsExclusive"], "blindness")
    static let contrastNormalMin = S.field(["contrast", "bandLowerBoundsInclusive"], "normal")
    static let contrastBorderlineMin = S.field(["contrast", "bandLowerBoundsInclusive"], "borderline")
    static let contrastReducedMin = S.field(["contrast", "bandLowerBoundsInclusive"], "reduced")
    static let normalVisionAcuityMax = S.number("summary", "normalVisionAcuityUpperBelow")
    static let normalVisionContrastMin = S.number("summary", "normalVisionContrastLowerAtLeast")

    // MARK: Regole (sezione 9)
    static let r0PrudentShift = S.number("rules", "prudentShiftWhenNotReliable")
    static let r1AcuityReserveLogMAR = S.number("rules", "acuityReserveLogMAR")
    static let r1ReadingMarginLogMAR = S.number("rules", "criticalPrintSizeMarginLogMAR")
    static let xHeightArcminAtZero = S.number("rules", "xHeightArcminAtZero")
    static let fontXHeightRatio = S.number("font", "xHeightRatio")
    static let fontZeroWidthEm = S.number("font", "zeroWidthEm")
    static let fontFamily = S.string("font", "family") ?? "Atkinson Hyperlegible"
    static let fontVersion = S.string("font", "version") ?? ""

    static let wcagLineHeight = S.field(["rules", "spacingBase"], "lineHeight")
    static let wcagParagraphSpacingEm = S.field(["rules", "spacingBase"], "paragraphSpacingEm")
    static let wcagLetterSpacingEm = S.field(["rules", "spacingBase"], "letterSpacingEm")
    static let wcagWordSpacingEm = S.field(["rules", "spacingBase"], "wordSpacingEm")
    static let centralLineHeight = S.field(["rules", "spacingCentralLoss"], "lineHeight")
    static let centralParagraphSpacingEm = S.field(["rules", "spacingCentralLoss"], "paragraphSpacingEm")
    static let centralLetterSpacingEm = S.field(["rules", "spacingCentralLoss"], "letterSpacingEm")
    static let centralWordSpacingEm = S.field(["rules", "spacingCentralLoss"], "wordSpacingEm")
    static let lineLengthFieldFactor = S.number("rules", "lineLengthFieldFactor")
    static let minLineWidthCh = S.field(["rules", "maxLineWidthCh"], "min")
    static let maxLineWidthCh = S.field(["rules", "maxLineWidthCh"], "max")

    static let textContrastNormal = S.field(["rules", "minTextContrastByBand"], "normal")
    static let textContrastBorderline = S.field(["rules", "minTextContrastByBand"], "borderline")
    static let textContrastReducedLower = S.field(["rules", "minTextContrastByBand"], "reducedAtLowerEdge")
    static let textContrastReducedUpper = S.field(["rules", "minTextContrastByBand"], "reducedAtUpperEdge")
    static let textContrastSeverelyReduced = S.field(["rules", "minTextContrastByBand"], "severelyReduced")
    static let minUIContrastFloor = S.field(["rules", "minUIContrast"], "floor")
    static let minUIContrastScale = S.field(["rules", "minUIContrast"], "scaleFromText")

    static let darkBackground = ((S.value("rules", "darkTheme") as? [String: String])?["background"]) ?? "#121212"
    static let darkText = ((S.value("rules", "darkTheme") as? [String: String])?["text"]) ?? "#E8E6E3"
    /// Tema chiaro: in parameters.json è ancora null (da scegliere, sezione 14). Proposta di Rocco: #FAF7F0.
    static let lightBackground = ((S.value("rules", "lightTheme") as? [String: String])?["background"]) ?? "#FAF7F0"
    static let lightText = ((S.value("rules", "lightTheme") as? [String: String])?["text"]) ?? "#1A1A1A"
    static let dimmedImageBrightness = S.number("rules", "imageBrightnessDimmed")

    static let minTargetPtBase = S.field(["rules", "minTargetPt"], "base")
    static let minTargetPtMax = S.field(["rules", "minTargetPt"], "max")
    static let minTargetReferenceCssPx = S.field(["rules", "minTargetPt"], "referenceFontCssPx")
    static let focusOutlinePx = S.number("rules", "focusOutlinePx")

    // MARK: Preset dell'app (non in parameters.json; contratto sezione 13: tunnel a 5°)
    static let tunnelPresetRadiusDeg = 5.0
}
