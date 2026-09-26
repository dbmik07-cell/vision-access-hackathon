import Testing
import Foundation
@testable import hackaton

@MainActor
struct ReliabilityTests {
    /// Simula un test di acuità e restituisce QUEST+ e le risposte registrate.
    private func simulate(seed: UInt64, answer: (Double, inout SeededRNG) -> Bool) -> (QuestPlus, [TrialRecord]) {
        var rng = SeededRNG(state: seed)
        var q = QuestConfigs.acuity()
        var records: [TrialRecord] = []
        let stop = QuestConfigs.acuityStop(demo: false)
        while !stop.shouldStop(q) {
            let cands = QuestPlus.grid(from: -0.2, to: 1.6, step: 0.02)
            let easy = q.thresholdMean + 0.4
            let s = ETestEngine.isCatchTrial(q.trials.count)
                ? cands.min { abs($0 - easy) < abs($1 - easy) }! : q.nextStimulus(candidates: cands)!
            let ok = answer(s, &rng)
            q.update(stimulus: s, correct: ok)
            records.append(TrialRecord(stimulus: s, correct: ok, distanceCM: 40,
                                       responseTimeMs: 900 + 1500 * exp(-abs(s - q.thresholdMean) * 8),
                                       shown: "right", answered: ok ? "right" : "left",
                                       estimateAfter: q.thresholdMean, sdAfter: q.thresholdSD))
        }
        return (q, records)
    }

    @Test func honestObserverIsReliable() {
        let (q, r) = simulate(seed: 5) { s, rng in
            Double.random(in: 0..<1, using: &rng) < PsychometricFunction().pCorrect(stimulus: s, threshold: 0.4, slope: 15)
        }
        let (rel, flags) = Reliability.assess(quest: q, records: r, easierIsHigher: true)
        #expect(rel != .nonAffidabile, "flags: \(flags)")
    }

    @Test func inconsistentAnswersAreFlagged() {
        // Schema della SPEC 6: errori su lettere grandi insieme a risposte giuste su lettere piccole.
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
                                       estimateAfter: q.thresholdMean, sdAfter: q.thresholdSD))
        }
        let (rel, flags) = Reliability.assess(quest: q, records: records, easierIsHigher: true)
        #expect(rel == .nonAffidabile, "flags: \(flags)")
        #expect(flags.contains { $0.contains("lettere facili") })
    }

    @Test func normalVisionNeedsWholeIntervalInRange() {
        var p = VisualProfile()
        p.acuity = AcuityResult(logMAR: 0.05, ci95: [-0.02, 0.12], slope: 15, trials: 20, reliability: .affidabile,
                                flags: [], meanDistanceCM: 40, log: [])
        p.contrast = ContrastResult(logCS: 1.8, ci95: [1.7, 1.9], trials: 15, reliability: .affidabile,
                                    flags: [], letterLogMAR: 1.56, log: [])
        ProfileBuilder.finalize(&p)
        #expect(p.summary.normalVision)
        // Intervallo a cavallo di 0,3: non "nella norma" anche se la stima lo è.
        p.acuity?.logMAR = 0.25; p.acuity?.ci95 = [0.18, 0.34]
        ProfileBuilder.finalize(&p)
        #expect(!p.summary.normalVision)
    }

    @Test func crossTestInconsistencyFlagged() {
        var p = VisualProfile()
        p.acuity = AcuityResult(logMAR: 0.0, ci95: [-0.05, 0.05], slope: 15, trials: 20, reliability: .affidabile,
                                flags: [], meanDistanceCM: 40, log: [])
        p.contrast = ContrastResult(logCS: 0.7, ci95: [0.6, 0.8], trials: 15, reliability: .affidabile,
                                    flags: [], letterLogMAR: 1.56, log: [])
        ProfileBuilder.finalize(&p)
        #expect(p.summary.overallReliability == .dubbio)
    }
}
