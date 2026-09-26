import Foundation

/// Profili predefiniti per la demo (contratto: blocchi con source "preset").
nonisolated enum PresetProfiles {
    typealias P = ContractParameters

    /// Profilo di partenza quando non c'è ancora nessun test: acuità e contrasto preset.
    static func baseline(device: DeviceBlock) -> VisualProfile {
        var p = VisualProfile(
            device: device,
            // Vista nella norma: così i preset di campo visivo e Amsler si vedono da soli.
            acuity: AcuityBlock(source: .preset, logMAR: 0.0, ci95: [-0.1, 0.1], reliability: .reliable, flags: [],
                                whoCategory: .none),
            contrast: ContrastBlock(source: .preset, logCS: 1.8, ci95: [1.7, 1.9], reliability: .reliable, flags: [],
                                    band: .normal))
        ProfileBuilder.finalizeNonisolated(&p)
        return p
    }

    static func apply(_ preset: FieldPreset, to profile: inout VisualProfile) {
        switch preset {
        case .nessuno:
            return
        case .tunnel:
            // Tunnel a 5° (contratto): punti visti solo entro 5°.
            let r = P.tunnelPresetRadiusDeg
            let eye = FieldEye(fieldRadiusDeg: r, pattern: .tunnel,
                               points: grid { x, y in hypot(x, y) <= r ? 8.5 : (hypot(x, y) <= r + 3 ? 3 : 0) })
            profile.visualField = VisualFieldBlock(source: .preset, right: eye, left: eye)
        case .centrale:
            // Perdita centrale: Amsler preset con coinvolgimento dei 2° centrali.
            var cells = Array(repeating: Array(repeating: 0, count: 10), count: 10)
            for row in 2..<8 { for c in 2..<8 { cells[row][c] = 1 } }
            for row in 3..<7 { for c in 3..<7 { cells[row][c] = 2 } }
            let a = AmslerEye(distortedAreaDeg2: 20, missingAreaDeg2: 16, centralInvolved: true, cells: cells)
            profile.amsler = AmslerBlock(source: .preset, right: a, left: a)
        }
        ProfileBuilder.finalizeNonisolated(&profile)
    }

    /// Griglia ogni 6° entro ±21° orizzontali e ±9° verticali (come il test).
    private static func grid(_ sensitivity: (Double, Double) -> Double) -> [FieldPoint] {
        var points: [FieldPoint] = []
        for y in stride(from: -9.0, through: 9.0, by: 6) {
            for x in stride(from: -21.0, through: 21.0, by: 6) {
                let s = sensitivity(x, y)
                points.append(FieldPoint(x: x, y: y, sensitivity: s, sd: 0.8, seen: s >= 3))
            }
        }
        return points
    }
}
