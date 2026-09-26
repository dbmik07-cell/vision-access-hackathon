import Testing
import Foundation
@testable import hackaton

/// Generatore pseudo-casuale con seme fisso (test deterministici, come richiesto da SPEC 11).
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

@MainActor
struct QuestPlusTests {
    @Test func psychometricFunctionLimits() {
        let f = PsychometricFunction(guess: 0.25, lapse: 0.02, increasingWithStimulus: true)
        // Lettera enorme: P → 1 − λ. Lettera minuscola: P → γ. Alla soglia: metà salita.
        #expect(abs(f.pCorrect(stimulus: 5, threshold: 0, slope: 20) - 0.98) < 1e-6)
        #expect(abs(f.pCorrect(stimulus: -5, threshold: 0, slope: 20) - 0.25) < 1e-6)
        #expect(abs(f.pCorrect(stimulus: 0.4, threshold: 0.4, slope: 20) - (0.25 + 0.73 / 2)) < 1e-9)
        // Contrasto: stimolo più alto = più difficile.
        let c = PsychometricFunction(guess: 0.25, lapse: 0.02, increasingWithStimulus: false)
        #expect(c.pCorrect(stimulus: 0.5, threshold: 1.5, slope: 10) > c.pCorrect(stimulus: 1.8, threshold: 1.5, slope: 10))
    }

    @Test func gridAndUniformPrior() {
        let q = QuestConfigs.acuity()
        #expect(q.thresholds.count == 106)
        #expect(abs(q.thresholds.first! + 0.3) < 1e-9 && abs(q.thresholds.last! - 1.8) < 1e-9)
        #expect(abs(q.posterior.reduce(0, +) - 1) < 1e-9)
        // Priore uniforme: media al centro della griglia.
        #expect(abs(q.thresholdMean - 0.75) < 1e-6)
    }

    @Test func bayesUpdateMovesEstimate() {
        var q = QuestConfigs.acuity()
        let before = q.thresholdMean
        // Risposta giusta a una lettera piccola: la soglia stimata scende (vista migliore).
        q.update(stimulus: 0.2, correct: true)
        #expect(q.thresholdMean < before)
        #expect(abs(q.posterior.reduce(0, +) - 1) < 1e-9)
        var q2 = QuestConfigs.acuity()
        // Risposta sbagliata a una lettera grande: la soglia sale.
        q2.update(stimulus: 1.2, correct: false)
        #expect(q2.thresholdMean > before)
    }

    @Test func expectedEntropyPrefersInformativeStimuli() {
        let q = QuestConfigs.acuity()
        // Una lettera enorme (sempre vista) non insegna nulla: entropia attesa ≈ attuale.
        let hHuge = q.expectedEntropy(stimulus: 3.0)
        let hMid = q.expectedEntropy(stimulus: 0.75)
        #expect(hMid < hHuge)
        let best = q.nextStimulus(candidates: QuestPlus.grid(from: -0.3, to: 1.8, step: 0.02))!
        #expect(best > 0.2 && best < 1.3)
    }

    @Test func convergesOnSimulatedObserver() {
        var rng = SeededRNG(state: 42)
        for trueT in [0.0, 0.5, 1.0] {
            var q = QuestConfigs.acuity()
            let stop = QuestConfigs.acuityStop(demo: false)
            let candidates = QuestPlus.grid(from: -0.2, to: 1.6, step: 0.02)
            while !stop.shouldStop(q) {
                let s = q.nextStimulus(candidates: candidates)!
                let p = q.function.pCorrect(stimulus: s, threshold: trueT, slope: 15)
                q.update(stimulus: s, correct: Double.random(in: 0..<1, using: &rng) < p)
            }
            #expect(q.trials.count >= 12 && q.trials.count <= 30)
            #expect(abs(q.thresholdMean - trueT) < 0.15, "stima \(q.thresholdMean) per soglia vera \(trueT)")
            #expect(q.ci95.lowerBound < q.thresholdMean && q.thresholdMean < q.ci95.upperBound)
        }
    }

    @Test func confidenceIntervalShrinks() {
        var rng = SeededRNG(state: 7)
        var q = QuestConfigs.acuity()
        let width0 = q.ci95.upperBound - q.ci95.lowerBound
        for _ in 0..<20 {
            let s = q.nextStimulus(candidates: QuestPlus.grid(from: -0.2, to: 1.6, step: 0.04))!
            let p = q.function.pCorrect(stimulus: s, threshold: 0.4, slope: 15)
            q.update(stimulus: s, correct: Double.random(in: 0..<1, using: &rng) < p)
        }
        #expect(q.ci95.upperBound - q.ci95.lowerBound < width0 / 3)
        #expect(q.thresholdSD < 0.15)
    }

    @Test func stopRuleNeverBeforeMinimum() {
        var q = QuestConfigs.acuity()
        let stop = QuestConfigs.acuityStop(demo: false)
        for _ in 0..<11 { q.update(stimulus: 0.5, correct: true) }
        #expect(!stop.shouldStop(q))
        for _ in 0..<19 { q.update(stimulus: 0.5, correct: true) }
        #expect(stop.shouldStop(q))   // 30 risposte: stop comunque
    }

    @Test func contrastConvergence() {
        var rng = SeededRNG(state: 3)
        var q = QuestConfigs.contrast()
        let stop = QuestConfigs.contrastStop(demo: false)
        let levels = ETestEngine.contrastLevels.map(\.x)
        while !stop.shouldStop(q) {
            let s = q.nextStimulus(candidates: levels)!
            let p = q.function.pCorrect(stimulus: s, threshold: 1.2, slope: 15)
            q.update(stimulus: s, correct: Double.random(in: 0..<1, using: &rng) < p)
        }
        #expect(abs(q.thresholdMean - 1.2) < 0.2)
    }
}

@MainActor
struct GeometryAndRulesTests {
    @Test func angleToPixels() {
        // logMAR 0 a 40 cm: lettera di 5' → 400 mm · 5/3437,75 = 0,5818 mm → 10,54 px a 460 ppi.
        let mm = VisualAngle.mm(arcmin: 5, distanceMM: 400)
        #expect(abs(mm - 0.58178) < 1e-4)
        #expect(abs(VisualAngle.px(mm: mm, ppi: 460) - 10.536) < 1e-2)
        // Andata e ritorno logMAR → px → logMAR.
        let h = VisualAngle.letterHeightPx(logMAR: 0.7, distanceMM: 350)
        #expect(abs(VisualAngle.logMAR(letterHeightPx: h, distanceMM: 350) - 0.7) < 1e-9)
    }

    @Test func srgbGamma() {
        #expect(abs(SRGB.toLinear(1) - 1) < 1e-12)
        #expect(abs(SRGB.toLinear(0.5) - 0.214) < 1e-3)
        #expect(abs(SRGB.toEncoded(SRGB.toLinear(0.37)) - 0.37) < 1e-9)
        // Il grigio più chiaro (254) dà circa 2,0 unità logaritmiche di sensibilità.
        let cMin = SRGB.weberContrastOnWhite(gray: 254)
        #expect(abs(log10(1 / cMin) - 2.05) < 0.05)
    }

    @Test func textSizeFollowsDistance() {
        let near = ViewingContext(distanceMM: 300, ppi: 460, scale: 3, screenWidthPt: 390)
        let far = ViewingContext(distanceMM: 360, ppi: 460, scale: 3, screenWidthPt: 390)
        let a = RulesEngine.fontSizePx(targetLogMAR: 0.8, context: near)
        let b = RulesEngine.fontSizePx(targetLogMAR: 0.8, context: far)
        #expect(abs(b / a - 1.2) < 1e-9)   // telefono più lontano del 20% → testo più grande del 20%
    }

    @Test func r0UsesPrudentSide() {
        var p = VisualProfile()
        p.acuity = AcuityResult(logMAR: 0.5, ci95: [0.4, 0.6], slope: 15, trials: 20, reliability: .affidabile,
                                flags: [], meanDistanceCM: 40, log: [])
        #expect(abs(RulesEngine.prudentAcuity(p)! - 0.6) < 1e-9)
        p.acuity?.reliability = .dubbio
        #expect(abs(RulesEngine.prudentAcuity(p)! - 0.7) < 1e-9)
        // R1 senza test di lettura: acuità prudente + 0,4, poi +0,1 di margine.
        #expect(abs(RulesEngine.targetLogMAR(p) - 1.2) < 1e-9)
    }

    @Test func r3ContrastTable() {
        #expect(RulesEngine.minTextContrast(logCS: 1.8) == 4.5)
        #expect(RulesEngine.minTextContrast(logCS: 1.6) == 7)
        #expect(abs(RulesEngine.minTextContrast(logCS: 1.25) - 9.5) < 1e-9)
        #expect(RulesEngine.minTextContrast(logCS: 0.8) == 15)
    }
}
