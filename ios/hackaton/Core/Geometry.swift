import Foundation
import UIKit

// MARK: - Schermo del dispositivo

/// Densità dello schermo per modello di iPhone con Face ID.
/// iOS non fornisce i ppi fisici: serve una tabella per identificatore di modello.
nonisolated enum DeviceDisplay {
    /// Identificatore hardware, es. "iPhone15,4" (iPhone 15). Nel simulatore usa quello simulato.
    static let modelIdentifier: String = {
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return sim }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }()

    /// ppi fisici (pixel reali per pollice) dei modelli con TrueDepth.
    static let ppiTable: [String: (name: String, ppi: Double)] = [
        "iPhone10,3": ("iPhone X", 458), "iPhone10,6": ("iPhone X", 458),
        "iPhone11,2": ("iPhone XS", 458), "iPhone11,4": ("iPhone XS Max", 458),
        "iPhone11,6": ("iPhone XS Max", 458), "iPhone11,8": ("iPhone XR", 326),
        "iPhone12,1": ("iPhone 11", 326), "iPhone12,3": ("iPhone 11 Pro", 458),
        "iPhone12,5": ("iPhone 11 Pro Max", 458),
        "iPhone13,1": ("iPhone 12 mini", 476), "iPhone13,2": ("iPhone 12", 460),
        "iPhone13,3": ("iPhone 12 Pro", 460), "iPhone13,4": ("iPhone 12 Pro Max", 458),
        "iPhone14,4": ("iPhone 13 mini", 476), "iPhone14,5": ("iPhone 13", 460),
        "iPhone14,2": ("iPhone 13 Pro", 460), "iPhone14,3": ("iPhone 13 Pro Max", 458),
        "iPhone14,7": ("iPhone 14", 460), "iPhone14,8": ("iPhone 14 Plus", 458),
        "iPhone15,2": ("iPhone 14 Pro", 460), "iPhone15,3": ("iPhone 14 Pro Max", 460),
        "iPhone15,4": ("iPhone 15", 460), "iPhone15,5": ("iPhone 15 Plus", 460),
        "iPhone16,1": ("iPhone 15 Pro", 460), "iPhone16,2": ("iPhone 15 Pro Max", 460),
        "iPhone17,3": ("iPhone 16", 460), "iPhone17,4": ("iPhone 16 Plus", 460),
        "iPhone17,1": ("iPhone 16 Pro", 460), "iPhone17,2": ("iPhone 16 Pro Max", 460),
        "iPhone17,5": ("iPhone 16e", 460),
        "iPhone18,3": ("iPhone 17", 460), "iPhone18,1": ("iPhone 17 Pro", 460),
        "iPhone18,2": ("iPhone 17 Pro Max", 460), "iPhone18,4": ("iPhone Air", 460),
    ]

    static var modelName: String { ppiTable[modelIdentifier]?.name ?? modelIdentifier }
    /// Modelli sconosciuti (più recenti): 460 ppi, il valore di tutti gli iPhone recenti.
    static var ppi: Double { ppiTable[modelIdentifier]?.ppi ?? 460 }

    /// Pixel fisici per punto iOS (3 sulla maggior parte dei modelli, 2,88 sui mini).
    @MainActor static var nativeScale: Double {
        let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
        return Double(screen?.nativeScale ?? 3)
    }

    @MainActor static var screenSizePt: CGSize {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.size
            ?? CGSize(width: 390, height: 844)
    }
}

// MARK: - Angolo visivo → millimetri → pixel

/// Conversioni della sezione 4 di SPEC.md.
nonisolated enum VisualAngle {
    static let arcminPerRad = 180.0 * 60.0 / .pi

    /// logMAR → tratto della E in minuti d'arco. logMAR 0 = tratto di 1', lettera di 5'.
    static func strokeArcmin(logMAR: Double) -> Double { pow(10, logMAR) }

    /// Tratto in minuti d'arco → logMAR (inversa).
    static func logMAR(strokeArcmin: Double) -> Double { log10(strokeArcmin) }

    /// h_mm = d_mm · θ_rad (approssimazione dei piccoli angoli, come in SPEC).
    static func mm(arcmin: Double, distanceMM: Double) -> Double {
        distanceMM * (arcmin / arcminPerRad)
    }

    /// θ in minuti d'arco di un oggetto alto `mm` alla distanza `distanceMM` (inversa).
    static func arcmin(mm: Double, distanceMM: Double) -> Double {
        (mm / distanceMM) * arcminPerRad
    }

    /// px = h_mm · ppi / 25,4
    static func px(mm: Double, ppi: Double = DeviceDisplay.ppi) -> Double { mm * ppi / 25.4 }
    static func mm(px: Double, ppi: Double = DeviceDisplay.ppi) -> Double { px * 25.4 / ppi }

    /// Pixel fisici → punti iOS (= px CSS nel WKWebView con viewport device-width).
    static func pt(px: Double, scale: Double) -> Double { px / scale }
    static func px(pt: Double, scale: Double) -> Double { pt * scale }

    /// Gradi di angolo visivo → punti iOS alla distanza data.
    @MainActor static func pt(degrees: Double, distanceMM: Double) -> Double {
        pt(px: px(mm: mm(arcmin: degrees * 60, distanceMM: distanceMM)), scale: DeviceDisplay.nativeScale)
    }

    /// Altezza della E (5 tratti) in pixel per un logMAR alla distanza data.
    static func letterHeightPx(logMAR: Double, distanceMM: Double) -> Double {
        px(mm: mm(arcmin: 5 * strokeArcmin(logMAR: logMAR), distanceMM: distanceMM))
    }

    /// logMAR effettivo di una E alta `heightPx` vista da `distanceMM`.
    static func logMAR(letterHeightPx: Double, distanceMM: Double) -> Double {
        logMAR(strokeArcmin: arcmin(mm: mm(px: letterHeightPx), distanceMM: distanceMM) / 5)
    }
}

// MARK: - Scala logMAR

nonisolated enum Acuity {
    /// Decimi: 10 / 10^logMAR (logMAR 0 = 10/10).
    static func decimi(_ logMAR: Double) -> Double { 10 / pow(10, logMAR) }
    /// Snellen 6/x con x = 6 · 10^logMAR.
    static func snellen(_ logMAR: Double) -> String {
        "6/\(Int((6 * pow(10, logMAR)).rounded()))"
    }
}
