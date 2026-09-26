import Testing
import Foundation
@testable import hackaton

@MainActor
struct Phase6Tests {
    @Test func bradleyTerryRanksConsistentWinner() {
        // La versione 2 vince tutti i suoi confronti, la 1 li perde tutti.
        let wins: [(winner: Int, loser: Int)] = [(2, 0), (2, 1), (2, 3), (0, 1), (3, 1), (0, 3)]
        let p = LightTestView.bradleyTerry(n: 4, wins: wins)
        #expect(abs(p.reduce(0, +) - 1) < 1e-9)
        #expect(p.indices.max { p[$0] < p[$1] } == 2)
        #expect(p.indices.min { p[$0] < p[$1] } == 1)
    }

    @Test func amslerSummary() {
        var cells = Array(repeating: Array(repeating: 0, count: 10), count: 10)
        cells[4][4] = 2; cells[4][5] = 2; cells[5][5] = 1
        let e = AmslerTestView.summarize(cells)
        #expect(e.missingAreaDeg2 == 2 && e.distortedAreaDeg2 == 1)
        #expect(e.centralInvolved)
        let empty = AmslerTestView.summarize(Array(repeating: Array(repeating: 0, count: 10), count: 10))
        #expect(!empty.centralInvolved && empty.centroidDistanceDeg == nil)
    }

    private let ctx = ViewingContext(distanceMM: 350, ppi: 460, scale: 3, screenWidthPt: 393)

    @Test func tunnelPresetGivesNarrowLinesAndParagraphMode() {
        var p = VisualProfile()
        PresetProfiles.apply(.tunnel, to: &p)
        let plan = RulesEngine.plan(profile: p, context: ctx)
        #expect(plan.layout.singleColumn)
        #expect(plan.layout.moveEdgeElements)
        #expect(plan.layout.mode != "normale")   // campo 8° < 10° → paragrafo (o lettura grande)
        // L_max = 2 · 350 · tan(8°) · 0,8 ≈ 78,7 mm
        let lmax = ctx.cssPx(mm: 2 * 350 * tan(8 * Double.pi / 180) * 0.8)
        #expect(plan.layout.maxLineWidthPx <= max(lmax, 15 * plan.text.fontSizePx * 0.67) + 1)
    }

    @Test func centralLossWidensSpacing() {
        var p = VisualProfile()
        PresetProfiles.apply(.centrale, to: &p)
        let plan = RulesEngine.plan(profile: p, context: ctx)
        #expect(plan.text.lineHeight == 2 && plan.text.letterSpacingEm == 0.18 && plan.text.wordSpacingEm == 0.24)
    }

    @Test func lightPreferenceSetsThemeAndBrightness() {
        var p = SampleProfiles.lowAcuity()
        p.light = LightResult(preferredTheme: .scuro, preferredBrightness: 0.5, photophobia: true, scores: [:], ambientLux: nil)
        let plan = RulesEngine.plan(profile: p, context: ctx)
        #expect(plan.color.theme == .scuro && plan.color.background == "#121212" && plan.screen.brightness == 0.5)
    }

    @Test func hugeTextTriggersLargeReadingMode() {
        var p = VisualProfile()
        p.acuity = AcuityResult(logMAR: 1.1, ci95: [1.0, 1.2], slope: 15, trials: 20, reliability: .affidabile,
                                flags: [], meanDistanceCM: 35, log: [])
        let plan = RulesEngine.plan(profile: p, context: ctx)
        #expect(plan.layout.mode == "lettura-grande" && plan.speech.tapToSpeak)
        #expect(plan.controls.minTargetPt == 64)
    }
}
