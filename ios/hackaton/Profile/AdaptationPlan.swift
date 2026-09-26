import Foundation

/// Piano di adattamento: solo numeri pronti per adapter.js (SPEC 11). Nessuna scienza della vista qui.
nonisolated struct AdaptationPlan: Codable, Sendable, Equatable {
    struct Text: Codable, Sendable, Equatable {
        var fontFamily = "Atkinson Hyperlegible"
        var fontSizePx: Double
        var lineHeight = 1.5
        var letterSpacingEm = 0.12
        var wordSpacingEm = 0.16
        var paragraphSpacingEm = 2.0
        var align = "left"
    }
    struct Layout: Codable, Sendable, Equatable {
        var singleColumn = false
        var maxLineWidthPx: Double
        var mode = "normale"          // normale | paragrafo | lettura-grande
        var moveEdgeElements = false
    }
    struct Color: Codable, Sendable, Equatable {
        var theme: Theme = .originale
        var background = "#FFFFFF"
        var text = "#1A1A1A"
        var minTextContrast = 4.5
        var minUIContrast = 3.0
        var preserveHue = true
        var imageBrightness = 1.0
    }
    struct Controls: Codable, Sendable, Equatable {
        var underlineLinks = true
        var minTargetPt = 44.0
        var focusOutlinePx = 3.0
    }
    struct Cleanup: Codable, Sendable, Equatable {
        var removeCookieBanners = true
        var stopAnimations = true
        var useReadability = true
    }
    struct Speech: Codable, Sendable, Equatable {
        var tapToSpeak = false
        var rateWpm = 160.0
    }
    struct Screen: Codable, Sendable, Equatable {
        var brightness: Double?
    }

    var text: Text
    var layout: Layout
    var color = Color()
    var controls = Controls()
    var cleanup = Cleanup()
    var speech = Speech()
    var screen = Screen()

    /// Spiegazione leggibile di cosa fa ogni regola (per le impostazioni e la demo).
    var explanations: [String] = []

    func json() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? String(data: encoder.encode(self), encoding: .utf8)) ?? "{}"
    }
}

/// Condizioni di visione del momento: distanza e schermo.
nonisolated struct ViewingContext: Sendable {
    var distanceMM: Double
    var ppi: Double
    var scale: Double
    var screenWidthPt: Double

    /// Millimetri → px CSS (= punti iOS).
    func cssPx(mm: Double) -> Double { mm * ppi / 25.4 / scale }
}
