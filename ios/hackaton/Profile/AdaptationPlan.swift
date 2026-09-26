import Foundation

/// AdaptationPlan secondo il contratto (docs/data-contracts.md, sezione 9), schemaVersion "1.0".
/// Solo numeri pronti per adapter.js. I campi che significano "non toccare" sono null espliciti.
nonisolated struct AdaptationPlan: Codable, Sendable, Equatable {
    struct Context: Codable, Sendable, Equatable {
        var referenceDistanceMm: Double
        var ppi: Double
        var nativeScale: Double
    }
    struct Text: Codable, Sendable, Equatable {
        var fontFamily: String
        /// Dimensione minima del testo del corpo a 400 mm; a runtime si riscala per d/400.
        var fontSizeCssPx: Double
        var lineHeight: Double
        var letterSpacingEm: Double
        var wordSpacingEm: Double
        var paragraphSpacingEm: Double
        var align: String
    }
    struct Layout: Codable, Sendable, Equatable {
        var singleColumn: Bool
        var maxLineWidthCh: Double
        var mode: String                 // "normal" nell'MVP
        var moveEdgeElements: Bool
    }
    struct Color: Codable, Sendable, Equatable {
        var theme: String                // original | light | dark
        var background: String?
        var text: String?
        var minTextContrast: Double
        var minUIContrast: Double
        var preserveHue: Bool
        var imageBrightness: Double

        enum CodingKeys: String, CodingKey {
            case theme, background, text, minTextContrast, minUIContrast, preserveHue, imageBrightness
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(theme, forKey: .theme)
            try c.encode(background, forKey: .background)
            try c.encode(text, forKey: .text)
            try c.encode(minTextContrast, forKey: .minTextContrast)
            try c.encode(minUIContrast, forKey: .minUIContrast)
            try c.encode(preserveHue, forKey: .preserveHue)
            try c.encode(imageBrightness, forKey: .imageBrightness)
        }
    }
    struct Controls: Codable, Sendable, Equatable {
        var underlineLinks: Bool
        var minTargetPt: Double
        var focusOutlinePx: Double
    }
    struct Cleanup: Codable, Sendable, Equatable {
        var removeCookieBanners: Bool
        var stopAnimations: Bool
        var useReadability: Bool
    }
    struct Speech: Codable, Sendable, Equatable {
        var tapToSpeak: Bool
        var rateWpm: Double?

        enum CodingKeys: String, CodingKey { case tapToSpeak, rateWpm }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(tapToSpeak, forKey: .tapToSpeak)
            try c.encode(rateWpm, forKey: .rateWpm)
        }
    }
    struct Screen: Codable, Sendable, Equatable {
        var brightness: Double?

        enum CodingKeys: String, CodingKey { case brightness }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(brightness, forKey: .brightness)
        }
    }

    var schemaVersion = ContractParameters.schemaVersion
    var context: Context
    var text: Text
    var layout: Layout
    var color: Color
    var controls: Controls
    var cleanup: Cleanup
    var speech: Speech
    var screen: Screen

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? String(data: encoder.encode(self), encoding: .utf8)) ?? "{}"
    }
}

/// Contesto del calcolo: densità dello schermo e nativeScale letto a runtime.
nonisolated struct ViewingContext: Sendable, Equatable {
    var ppi: Double
    var nativeScale: Double

    /// Millimetri → CSS px (= punti iOS): mm · ppi / (25,4 · nativeScale).
    func cssPx(mm: Double) -> Double { mm * ppi / (ContractParameters.mmPerInch * nativeScale) }
}
