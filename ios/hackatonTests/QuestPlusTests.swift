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

/// Contesto usato nei test delle regole: iPhone 15 (460 ppi, nativeScale 3).
let ctx15 = ViewingContext(ppi: 460, nativeScale: 3)

func acuity(_ m: Double, _ lo: Double, _ hi: Double, _ rel: ContractReliability = .reliable, source: BlockSource = .measured) -> AcuityBlock {
    AcuityBlock(source: source, logMAR: m, ci95: [lo, hi], reliability: rel, flags: [], whoCategory: WHOCategory.from(logMAR: m))
}
func contrast(_ m: Double, _ lo: Double, _ hi: Double, _ rel: ContractReliability = .reliable) -> ContrastBlock {
    ContrastBlock(source: .measured, logCS: m, ci95: [lo, hi], reliability: rel, flags: [], band: ContrastBand.from(logCS: m))
}
func profile(_ a: AcuityBlock, _ c: ContrastBlock) -> VisualProfile {
    var p = VisualProfile(device: DeviceBlock(modelIdentifier: "iPhone15,4", ppi: 460, nativeScale: 3), acuity: a, contrast: c)
    ProfileBuilder.finalizeNonisolated(&p)
    return p
}

@MainActor
struct QuestPlusTests {
    @Test func psychometricFunctionLimits() {
        let f = PsychometricFunction(guess: 0.25, lapse: 0.02)
        #expect(abs(f.pCorrect(stimulus: 5, threshold: 0, slope: 20) - 0.98) < 1e-6)
        #expect(abs(f.pCorrect(stimulus: -5, threshold: 0, slope: 20) - 0.25) < 1e-6)
        // Alla soglia: γ + (1 − γ − λ)/2 = 0,615 (≈ 61,5%, contratto sezione 5).
        #expect(abs(f.pCorrect(stimulus: 0.4, threshold: 0.4, slope: 20) - 0.615) < 1e-12)
    }

    @Test func contractGrids() {
        let a = QuestConfigs.acuity(), c = QuestConfigs.contrast()
        #expect(a.thresholds.count == 106 && c.thresholds.count == 106)
        #expect(abs(c.thresholds.first! + 2.1) < 1e-9 && abs(c.thresholds.last!) < 1e-9)
        #expect(a.slopes == [6, 10, 15, 24, 35] && c.slopes == [5, 7, 10, 14, 20])
        #expect(abs(a.posterior.reduce(0, +) - 1) < 1e-9)
    }

    @Test func binQuantilesOnUniformPrior() {
        // Priore uniforme su 106 bin da 0,02 che coprono [−0,31, 1,81]: la mediana è il centro 0,75,
        // q2,5% = −0,31 + 0,025 · 2,12 = −0,257 (poi limitato alla griglia).
        let q = QuestConfigs.acuity()
        #expect(abs(q.thresholdMedian - 0.75) < 1e-9)
        #expect(abs(q.ci95.lowerBound - (-0.31 + 0.025 * 2.12)) < 1e-9)
        #expect(abs(q.ci95.upperBound - (-0.31 + 0.975 * 2.12)) < 1e-9)
    }

    @Test func tieBreakPicksLowestIndex() {
        let q = QuestConfigs.acuity()
        // Stimoli uguali: entropie identiche → vince il primo.
        #expect(q.nextStimulusIndex(candidates: [0.5, 0.5, 0.5]) == 0)
        // Lettere enormi e identiche in coda non vincono su uno stimolo informativo.
        #expect(q.nextStimulusIndex(candidates: [3.0, 0.75, 3.0]) == 1)
    }

    @Test func bayesUpdateMovesEstimate() {
        var q = QuestConfigs.acuity()
        let before = q.thresholdMedian
        q.update(stimulus: 0.2, correct: true)
        #expect(q.thresholdMedian < before)
        var q2 = QuestConfigs.acuity()
        q2.update(stimulus: 1.2, correct: false)
        #expect(q2.thresholdMedian > before)
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
            #expect(abs(q.thresholdMedian - trueT) < 0.15, "mediana \(q.thresholdMedian) per soglia vera \(trueT)")
            #expect(q.ci95.contains(q.thresholdMedian))
        }
    }

    @Test func contrastUsesLogWeberEasiness() {
        // Risposte giuste ad alto contrasto e sbagliate a basso: deve convergere a un logCS plausibile,
        // non allo speculare (intercetta un segno invertito, come il golden contrast-reaches-sd).
        var rng = SeededRNG(state: 3)
        var q = QuestConfigs.contrast()
        let stop = QuestConfigs.contrastStop(demo: false)
        let levels = ETestEngine.contrastLevels.map(\.x)
        #expect(levels == levels.sorted() && levels.first! >= -2.1 && abs(levels.last!) < 1e-9)
        while !stop.shouldStop(q) {
            let s = q.nextStimulus(candidates: levels)!
            let p = q.function.pCorrect(stimulus: s, threshold: -1.2, slope: 10)   // logCS vero 1,2
            q.update(stimulus: s, correct: Double.random(in: 0..<1, using: &rng) < p)
        }
        #expect(abs(-q.thresholdMedian - 1.2) < 0.2)
    }

    @Test func stopRuleContract() {
        var q = QuestConfigs.acuity()
        let stop = QuestConfigs.acuityStop(demo: false)
        for _ in 0..<11 { q.update(stimulus: 0.5, correct: true) }
        #expect(!stop.shouldStop(q))
        for _ in 0..<19 { q.update(stimulus: 0.5, correct: true) }
        #expect(stop.shouldStop(q))
    }

    @Test func reliabilityFromIntervalWidth() {
        var q = QuestConfigs.acuity()
        #expect(QuestConfigs.reliability(q, maxCiWidth: 0.30, stopSd: 0.05).0 == .doubtful)
        #expect(QuestConfigs.reliability(q, maxCiWidth: 0.30, stopSd: 0.05).1.contains("wideInterval"))
        var rng = SeededRNG(state: 1)
        for _ in 0..<30 {
            let s = q.nextStimulus(candidates: q.thresholds)!
            q.update(stimulus: s, correct: Double.random(in: 0..<1, using: &rng) < q.function.pCorrect(stimulus: s, threshold: 0.4, slope: 35))
        }
        let w = q.ci95.upperBound - q.ci95.lowerBound
        #expect(QuestConfigs.reliability(q, maxCiWidth: 0.30, stopSd: 0.05).0 == (w <= 0.30 ? .reliable : .doubtful))
    }
}

@MainActor
struct GeometryAndRulesTests {
    @Test func angleToCssPx() {
        let mm = VisualAngle.mm(arcmin: 5, distanceMM: 400)
        #expect(abs(mm - 0.58178) < 1e-4)
        // cssPx = mm · ppi / (25,4 · nativeScale), anche con nativeScale 2,88 (mini).
        #expect(abs(ctx15.cssPx(mm: 25.4) - 460.0 / 3) < 1e-9)
        #expect(abs(ViewingContext(ppi: 476, nativeScale: 2.88).cssPx(mm: 25.4) - 476 / 2.88) < 1e-9)
    }

    @Test func srgbGamma() {
        #expect(abs(SRGB.toLinear(0.5) - 0.214) < 1e-3)
        // Senza dithering, vicino al bianco 8 bit danno 2,05 / 1,75 / 1,58 / 1,45 logCS.
        let top = [254, 253, 252, 251].map { -log10(SRGB.weberContrastOnWhite(gray: $0)) }
        for (a, b) in zip(top, [2.05, 1.75, 1.58, 1.45]) { #expect(abs(a - b) < 0.01) }
    }

    @Test func r1FontAtReferenceAndRescaling() {
        // acuità ci95 alto 0,1 → s = 0,5 → θ = 5′·10^0,5; h_x = 400·θ; font = h_x/0,496 → css px.
        let p = profile(acuity(0.05, 0.0, 0.1), contrast(1.8, 1.7, 1.9))
        let plan = RulesEngine.plan(profile: p, context: ctx15)
        let theta = 5 * pow(10, 0.5) / 60 * Double.pi / 180
        let expected = 400 * theta / 0.496 * 460 / (25.4 * 3)
        #expect(abs(plan.text.fontSizeCssPx - expected) < 1e-6)
        #expect(abs(plan.text.fontSizeCssPx - 22.37) < 0.05)
        #expect(abs(RulesEngine.fontSizeAtDistance(plan: plan, distanceMm: 480) / plan.text.fontSizeCssPx - 1.2) < 1e-12)
    }

    @Test func r0DoubtfulAddsExactlyPointOne() {
        let a = RulesEngine.plan(profile: profile(acuity(0.4, 0.3, 0.5), contrast(1.8, 1.7, 1.9)), context: ctx15)
        let b = RulesEngine.plan(profile: profile(acuity(0.4, 0.3, 0.5, .doubtful), contrast(1.8, 1.7, 1.9)), context: ctx15)
        #expect(abs(b.text.fontSizeCssPx / a.text.fontSizeCssPx - pow(10, 0.1)) < 1e-9)
    }

    @Test func r1UsesReadingOnlyWhenMeasuredAndReliable() {
        var p = profile(acuity(0.4, 0.3, 0.5), contrast(1.8, 1.7, 1.9))
        p.reading = ReadingBlock(source: .measured, measured: true, criticalPrintSizeLogMAR: 0.6, ci95: [0.5, 0.7],
                                 maxReadingSpeedWpm: 150, readingAcuityLogMAR: 0.3, reliability: .reliable, flags: [])
        #expect(abs(RulesEngine.targetLogMAR(p) - 0.7) < 1e-12)
        p.reading?.reliability = .doubtful
        #expect(abs(RulesEngine.targetLogMAR(p) - 0.9) < 1e-12)
    }

    @Test func r3ContrastTable() {
        #expect(RulesEngine.minTextContrast(logCS: 1.65) == 4.5)
        #expect(RulesEngine.minTextContrast(logCS: 1.5) == 7)
        #expect(abs(RulesEngine.minTextContrast(logCS: 1.25) - 9.5) < 1e-12)
        #expect(abs(RulesEngine.minTextContrast(logCS: 1.0) - 12) < 1e-12)
        #expect(RulesEngine.minTextContrast(logCS: 0.99) == 15)
        let plan = RulesEngine.plan(profile: profile(acuity(0.4, 0.3, 0.5), contrast(1.3, 1.2, 1.4, .doubtful)), context: ctx15)
        #expect(abs(plan.color.minTextContrast - (12 - 10 * 0.1)) < 1e-9)   // x = 1,2 − 0,1
        #expect(abs(plan.color.minUIContrast - max(3, plan.color.minTextContrast * 3 / 4.5)) < 1e-12)
    }

    @Test func r4ThemeDefaultsAndPhotophobia() {
        var p = profile(acuity(0.4, 0.3, 0.5), contrast(1.8, 1.7, 1.9))
        var plan = RulesEngine.plan(profile: p, context: ctx15)
        #expect(plan.color.theme == "original" && plan.color.background == nil && plan.screen.brightness == nil)
        #expect(plan.json().contains("\"background\":null"))
        p.light = LightBlock(source: .preset, photophobia: true)
        plan = RulesEngine.plan(profile: p, context: ctx15)
        #expect(plan.color.theme == "dark" && plan.color.background == "#121212" && plan.color.imageBrightness == 0.85)
    }

    @Test func tunnelPresetLineLength() {
        var p = profile(acuity(0.4, 0.3, 0.5), contrast(1.8, 1.7, 1.9))
        PresetProfiles.apply(.tunnel, to: &p)
        let plan = RulesEngine.plan(profile: p, context: ctx15)
        let fontMm = RulesEngine.fontSizeMm(targetLogMAR: 0.9)
        let ch = 2 * 400 * tan(5 * Double.pi / 180) * 0.8 / (fontMm * 0.648)
        #expect(abs(plan.layout.maxLineWidthCh - min(max(ch, 15), 60)) < 1e-9)
        #expect(plan.layout.moveEdgeElements && plan.layout.mode == "normal" && plan.layout.singleColumn)
        #expect(!p.summary.normalVision)
    }

    @Test func centralLossSpacing() {
        var p = profile(acuity(0.4, 0.3, 0.5), contrast(1.8, 1.7, 1.9))
        PresetProfiles.apply(.centrale, to: &p)
        let plan = RulesEngine.plan(profile: p, context: ctx15)
        #expect(plan.text.lineHeight == 2 && plan.text.letterSpacingEm == 0.18 && plan.text.wordSpacingEm == 0.24)
        #expect(plan.layout.maxLineWidthCh == 60)
    }

    @Test func minTargetClamp() {
        let small = RulesEngine.plan(profile: profile(acuity(-0.2, -0.3, -0.25), contrast(1.8, 1.7, 1.9)), context: ctx15)
        #expect(small.controls.minTargetPt == 44)
        let big = RulesEngine.plan(profile: profile(acuity(1.0, 0.9, 1.1), contrast(1.8, 1.7, 1.9)), context: ctx15)
        #expect(big.controls.minTargetPt == 64)
    }

    @Test func summaryAndCategories() {
        #expect(WHOCategory.from(logMAR: 0.3) == .none && WHOCategory.from(logMAR: 0.31) == .mild)
        #expect(WHOCategory.from(logMAR: 0.48) == .mild && WHOCategory.from(logMAR: 1.31) == .blindness)
        #expect(ContrastBand.from(logCS: 1.65) == .normal && ContrastBand.from(logCS: 1.5) == .borderline)
        #expect(ContrastBand.from(logCS: 1.0) == .reduced && ContrastBand.from(logCS: 0.99) == .severelyReduced)
        // normalVision: ci95 alto < 0,3 (0,3 esatto non basta) e ci95 basso del contrasto ≥ 1,5.
        #expect(profile(acuity(0.1, 0.0, 0.29), contrast(1.8, 1.5, 1.9)).summary.normalVision)
        #expect(!profile(acuity(0.1, 0.0, 0.3), contrast(1.8, 1.5, 1.9)).summary.normalVision)
        let p = profile(acuity(0.1, 0.0, 0.2, .doubtful), contrast(1.8, 1.7, 1.9))
        #expect(p.summary.overallReliability == .doubtful)
        let preset = PresetProfiles.baseline(device: p.device)
        #expect(preset.summary.overallReliability == nil)
    }

    @Test func profileJSONUsesContractNames() throws {
        let data = try JSONEncoder().encode(profile(acuity(0.4, 0.3, 0.5), contrast(1.3, 1.2, 1.4)))
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["schemaVersion"] as? String == "1.0")
        let a = obj["acuity"] as! [String: Any]
        #expect(a["whoCategory"] as? String == "mild" && a["reliability"] as? String == "reliable")
        #expect((obj["contrast"] as! [String: Any])["band"] as? String == "reduced")
        #expect((obj["summary"] as! [String: Any]).keys.contains("overallReliability"))
    }

    @Test func contrastLetterSize() {
        // max(3°, 5′·10^(ci95 alto + 0,6)) limitata a 8°.
        #expect(ProfileBuilder.contrastLetterArcmin(acuity: acuity(0.0, -0.1, 0.1)).arcmin == 180)
        let big = ProfileBuilder.contrastLetterArcmin(acuity: acuity(1.4, 1.3, 1.5))
        #expect(big.arcmin == 480 && big.capped)
        let mid = ProfileBuilder.contrastLetterArcmin(acuity: acuity(1.0, 0.9, 1.1))
        #expect(abs(mid.arcmin - 5 * pow(10, 1.7)) < 1e-9 && !mid.capped)
    }
}
