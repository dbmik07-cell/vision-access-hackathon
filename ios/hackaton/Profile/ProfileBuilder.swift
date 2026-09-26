import Foundation

/// Dai motori dei test ai blocchi del VisualProfile (contratto, sezioni 5, 6 e 8).
enum ProfileBuilder {
    typealias P = ContractParameters

    static var device: DeviceBlock {
        DeviceBlock(modelIdentifier: DeviceDisplay.modelIdentifier, ppi: DeviceDisplay.ppi ?? 0,
                    nativeScale: DeviceDisplay.nativeScale)
    }

    // MARK: Acuità e contrasto

    static func acuityBlock(_ e: ETestEngine) -> AcuityBlock {
        let q = e.quest
        let (rel, flags) = QuestConfigs.reliability(q, maxCiWidth: P.acuityReliableMaxCiWidth, stopSd: P.acuityTargetSd)
        let median = q.thresholdMedian
        let ci = [q.ci95.lowerBound, q.ci95.upperBound]
        let limit = e.displayLimit   // il più piccolo stimolo ammissibile durante il test
        return AcuityBlock(source: .measured, logMAR: median, ci95: ci, reliability: rel, flags: flags,
                           whoCategory: WHOCategory.from(logMAR: median), trials: e.trialCount,
                           displayLimitLogMAR: limit,
                           // Censura: la mediana è sotto il limite dello schermo → si mostra "≤ limite".
                           censoredAtDisplayLimit: limit.map { median < $0 } ?? false)
    }

    static func contrastBlock(_ e: ETestEngine, letterCapped: Bool) -> ContrastBlock {
        let q = e.quest
        var (rel, flags) = QuestConfigs.reliability(q, maxCiWidth: P.contrastReliableMaxCiWidth, stopSd: P.contrastTargetSd)
        if letterCapped { flags.append("contrastLetterSizeCapped") }
        // logCS = −t: la conversione avviene solo qui, e gli estremi di ci95 si scambiano.
        let median = -q.thresholdMedian
        let ci = [-q.ci95.upperBound, -q.ci95.lowerBound]
        let ceiling = e.displayLimit.map { -$0 }   // livello ammissibile più alto in logCS
        return ContrastBlock(source: .measured, logCS: median, ci95: ci, reliability: rel, flags: flags,
                             band: ContrastBand.from(logCS: median), trials: e.trialCount,
                             ceilingLogCS: ceiling, censoredAtCeiling: ceiling.map { median > $0 } ?? false)
    }

    /// Lettera del contrasto: max(3°, 5′·10^(ci95 alto + 0,6)), al massimo 8° (in minuti d'arco di altezza).
    static func contrastLetterArcmin(acuity: AcuityBlock?) -> (arcmin: Double, capped: Bool) {
        let minArcmin = P.contrastLetterMinDeg * 60, maxArcmin = P.contrastLetterMaxDeg * 60
        guard let a = acuity else { return (minArcmin, false) }
        let wanted = max(minArcmin, 5 * pow(10, (a.ci95.last ?? a.logMAR) + P.contrastLetterAcuityOffsetLogMAR))
        return (min(wanted, maxArcmin), wanted > maxArcmin)
    }

    // MARK: Sintesi (sezione 8)


    static func finalize(_ p: inout VisualProfile) { finalizeNonisolated(&p) }

    nonisolated static func finalizeNonisolated(_ p: inout VisualProfile) {
        // normalVision (informativo): ci95 alto dell'acuità < 0,3, ci95 basso del contrasto ≥ 1,5,
        // e nessun blocco opzionale che segnala un problema (un blocco assente non blocca).
        var normal = (p.acuity.ci95.last ?? p.acuity.logMAR) < P.normalVisionAcuityMax
            && (p.contrast.ci95.first ?? p.contrast.logCS) >= P.normalVisionContrastMin
        if let am = p.amsler, am.hasProblem { normal = false }
        if let f = p.visualField, f.hasProblem { normal = false }

        // overallReliability: la peggiore tra i blocchi misurati; i preset non contano.
        var measured: [ContractReliability] = []
        if p.acuity.source == .measured { measured.append(p.acuity.reliability) }
        if p.contrast.source == .measured { measured.append(p.contrast.reliability) }
        if let f = p.visualField, f.source == .measured { measured += f.eyes.compactMap(\.reliability) }
        p.summary = SummaryBlock(normalVision: normal, overallReliability: measured.max())
    }
}

/// Controlli di affidabilità avanzata (SPEC 6, post-MVP nel contratto): solo informativi,
/// mostrati nei risultati ma fuori dal VisualProfile e senza effetto sul piano.
enum Diagnostics {
    nonisolated static func assess(quest: QuestPlus, records: [TrialRecord]) -> [String] {
        var notes: [String] = []
        let t = quest.thresholdMedian, b = quest.slopeMean, f = quest.function

        // Coerenza con il modello: z = (log-verosimiglianza osservata − attesa) / √varianza.
        var observed = 0.0, expected = 0.0, variance = 0.0
        for r in records {
            let p = min(max(f.pCorrect(stimulus: r.stimulus, threshold: t, slope: b), 1e-6), 1 - 1e-6)
            observed += log(r.correct ? p : 1 - p)
            expected += p * log(p) + (1 - p) * log(1 - p)
            let l = log(p / (1 - p))
            variance += p * (1 - p) * l * l
        }
        if variance > 0, records.count >= 8, (observed - expected) / sqrt(variance) < -2 {
            notes.append("responses not very consistent with the estimated curve")
        }
        // Errori su stimoli facili (almeno 0,3 unità più facili della soglia).
        let errors = records.filter { !$0.correct }
        let easy = errors.filter { $0.stimulus >= t + 0.3 }
        if errors.count >= 3, Double(easy.count) / Double(errors.count) > 0.2 {
            notes.append("\(easy.count) errors on easy letters")
        }
        if easy.filter({ $0.responseTimeMs < 400 }).count >= 2 {
            notes.append("wrong answers too fast on easy letters")
        }
        let d = records.map(\.distanceCM)
        if let lo = d.min(), let hi = d.max(), hi - lo > 10 {
            notes.append("variable distance (\(Int(lo))–\(Int(hi)) cm)")
        }
        return notes
    }
}
