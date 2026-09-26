import Foundation

/// Profili di campo visivo predefiniti per la demo: tunnel e perdita centrale.
/// Generano una mappa di punti realistica, così la mappa di calore si può mostrare.
nonisolated enum PresetProfiles {
    static func apply(_ preset: FieldPreset, to profile: inout VisualProfile) {
        switch preset {
        case .nessuno:
            return
        case .tunnel:
            let eye = field(radius: 8) { x, y in hypot(x, y) <= 8 ? 8.5 : (hypot(x, y) <= 11 ? 3 : 0) }
            var eyeT = eye
            eyeT.fieldRadiusDeg = 8
            eyeT.pattern = .tunnel
            profile.visualField = VisualFieldResult(right: eyeT, left: eyeT, isPreset: true)
        case .centrale:
            let eye = field(radius: 27) { x, y in
                let r = hypot(x, y)
                return r <= 4 ? 0 : (r <= 7 ? 4 : 9)
            }
            var eyeC = eye
            eyeC.pattern = .centrale
            profile.visualField = VisualFieldResult(right: eyeC, left: eyeC, isPreset: true)
            // Amsler coerente: 4 × 4 celle centrali mancanti, bordo distorto.
            var cells = Array(repeating: Array(repeating: 0, count: 10), count: 10)
            for r in 2..<8 { for c in 2..<8 { cells[r][c] = 1 } }
            for r in 3..<7 { for c in 3..<7 { cells[r][c] = 2 } }
            let a = AmslerEye(cells: cells, distortedAreaDeg2: 20, missingAreaDeg2: 16, centralInvolved: true,
                              centroidDistanceDeg: 0, centroidDirectionDeg: 0)
            profile.amsler = AmslerResult(right: a, left: a)
        }
        if profile.acuity == nil {
            // Senza test di acuità: livello moderato, tipico di queste condizioni.
            profile.summary.level = .moderato
        }
    }

    /// Griglia ogni 6° entro ±27° orizzontali e ±21° verticali.
    private static func field(radius: Double, sensitivity: (Double, Double) -> Double) -> FieldEye {
        var points: [FieldPoint] = []
        for y in stride(from: -21.0, through: 21.0, by: 6) {
            for x in stride(from: -27.0, through: 27.0, by: 6) {
                let s = sensitivity(x, y)
                points.append(FieldPoint(x: x, y: y, sensitivity: s, sd: 0.8, seen: s >= 3))
            }
        }
        let md = points.map { $0.sensitivity - 9 }.reduce(0, +) / Double(points.count)
        return FieldEye(points: points, fieldRadiusDeg: radius, meanDefect: md, pattern: .nessuna,
                        fixationLossRate: 0.05, falsePositiveRate: 0.03, falseNegativeRate: 0.04,
                        reliability: .affidabile, blindSpot: [15, -2])
    }
}
