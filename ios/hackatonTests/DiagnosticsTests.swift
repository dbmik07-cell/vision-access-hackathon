import Testing
import Foundation
@testable import hackaton

@MainActor
struct DiagnosticsTests {
    @Test func inconsistentAnswersAreFlagged() {
        // SPEC 6 (post-MVP, solo informativo): errori su lettere grandi con risposte giuste su lettere piccole.
        var q = QuestConfigs.acuity()
        var records: [TrialRecord] = []
        let pattern: [(Double, Bool)] = [
            (0.8, true), (0.5, true), (0.3, true), (0.2, true), (0.1, false), (0.2, true), (0.1, true),
            (1.2, false), (0.0, true), (0.1, true), (1.0, false), (0.0, false), (0.1, true), (1.1, false),
            (0.05, true), (0.9, false), (0.1, true), (0.0, true), (1.2, false), (0.1, true),
        ]
        for (s, ok) in pattern {
            q.update(stimulus: s, correct: ok)
            records.append(TrialRecord(stimulus: s, correct: ok, distanceCM: 40, responseTimeMs: ok ? 1500 : 300,
                                       shown: "right", answered: ok ? "right" : "up",
                                       estimateAfter: q.thresholdMedian, sdAfter: q.thresholdSD))
        }
        let notes = Diagnostics.assess(quest: q, records: records)
        // Con la mediana alta, lo schema viene intercettato dalla coerenza con la curva.
        #expect(!notes.isEmpty, "mediana \(q.thresholdMedian) note \(notes)")
    }

    @Test func bradleyTerryRanksConsistentWinner() {
        let wins: [(winner: Int, loser: Int)] = [(2, 0), (2, 1), (2, 3), (0, 1), (3, 1), (0, 3)]
        let p = LightTestView.bradleyTerry(n: 4, wins: wins)
        #expect(p.indices.max { p[$0] < p[$1] } == 2)
    }

    @Test func amslerSummary() {
        var cells = Array(repeating: Array(repeating: 0, count: 10), count: 10)
        cells[4][4] = 2; cells[4][5] = 2; cells[5][5] = 1
        let e = AmslerTestView.summarize(cells)
        #expect(e.missingAreaDeg2 == 2 && e.distortedAreaDeg2 == 1 && e.centralInvolved)
    }
}
