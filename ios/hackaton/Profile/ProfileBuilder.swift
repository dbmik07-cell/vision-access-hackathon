import Foundation

/// Dai motori dei test ai blocchi del VisualProfile, con affidabilità (SPEC 6).
enum ProfileBuilder {
    // MARK: Acuità e contrasto

    static func acuityResult(_ e: ETestEngine) -> AcuityResult {
        var (rel, flags) = Reliability.assess(quest: e.quest, records: e.records, easierIsHigher: true)
        var r = AcuityResult(logMAR: e.estimate, ci95: [e.ci95.lowerBound, e.ci95.upperBound],
                             slope: e.quest.slopeMean, trials: e.trialCount, reliability: rel, flags: flags,
                             meanDistanceCM: e.meanDistanceCM, log: e.records)
        switch e.censor {
        case .none: break
        case .aboveLimit:
            // Vista migliore della E più piccola disegnabile: sappiamo solo che la soglia è sotto quel valore.
            let limit = e.hardLimitValue
            r.logMAR = limit; r.ci95 = [-0.3, limit]; r.censored = "oltre-limite"
            flags = ["vista nella norma, oltre il limite misurabile dallo schermo"]; rel = .affidabile
        case .belowLimit:
            // La E più grande non viene vista: soglia sopra quel valore, adattamento al massimo.
            let limit = e.easyLimitValue
            r.logMAR = limit; r.ci95 = [limit, 1.8]; r.censored = "sotto-limite"
            flags = ["acuità sotto il limite misurabile"]; rel = .affidabile
        }
        r.flags = flags; r.reliability = rel
        return r
    }

    static func contrastResult(_ e: ETestEngine) -> ContrastResult {
        let (rel, flags) = Reliability.assess(quest: e.quest, records: e.records, easierIsHigher: false)
        var letter = 1.556
        if case .contrast(let l) = e.kind { letter = l }
        var r = ContrastResult(logCS: e.estimate, ci95: [e.ci95.lowerBound, e.ci95.upperBound],
                               trials: e.trialCount, reliability: rel, flags: flags, letterLogMAR: letter, log: e.records)
        switch e.censor {
        case .none: break
        case .aboveLimit:
            let limit = e.hardLimitValue   // contrasto più basso disegnabile (~2,05 log)
            r.logCS = limit; r.ci95 = [limit, 2.1]; r.censored = "oltre-limite"
            r.flags = ["contrasto nella norma, oltre il limite misurabile dallo schermo"]; r.reliability = .affidabile
        case .belowLimit:
            r.logCS = 0; r.ci95 = [0, 0]; r.censored = "sotto-limite"
            r.flags = ["contrasto sotto il limite misurabile"]; r.reliability = .affidabile
        }
        return r
    }

    /// Dimensione della lettera del test del contrasto: il valore più grande tra
    /// ~3 gradi (Pelli-Robson: 180' di altezza → tratto 36' → logMAR log10(36) ≈ 1,556)
    /// e 4 volte la soglia di acuità (+ log10(4) ≈ 0,602 logMAR).
    static func contrastLetterLogMAR(_ profile: VisualProfile) -> Double {
        let pelliRobson = log10(36.0)
        guard let a = profile.acuity else { return pelliRobson }
        return max(pelliRobson, a.logMAR + log10(4))
    }

    // MARK: Sintesi

    static func finalize(_ p: inout VisualProfile) {
        var reasons: [String] = []
        let level = p.acuity.map { VisionLevel.from(logMAR: $0.logMAR) } ?? .moderato

        // Caso A (SPEC 6): nella norma solo se TUTTO l'intervallo al 95% è nella fascia normale.
        var normal = true
        if let a = p.acuity { normal = normal && (a.ci95.last ?? a.logMAR) < 0.3 } else { normal = false }
        if let c = p.contrast { normal = normal && (c.ci95.first ?? c.logCS) > 1.5 }
        if let am = p.amsler { normal = normal && am.centralSeverity == "no" }
        if let f = p.visualField, !f.isPreset { normal = normal && f.patterns.allSatisfy { $0 == .nessuna } }

        // Caso B punto 4: coerenza tra i test (contrasto molto ridotto con acuità ottima è raro).
        if let a = p.acuity, let c = p.contrast, a.logMAR < 0.1, c.logCS < 1.0 {
            reasons.append("Contrasto molto ridotto con acuità ottima: combinazione rara, conviene ripetere.")
        }

        var all: [Reliability] = []
        if let a = p.acuity { all.append(a.reliability); reasons += a.flags.map { "Acuità: \($0)" } }
        if let c = p.contrast { all.append(c.reliability); reasons += c.flags.map { "Contrasto: \($0)" } }
        if let r = p.reading, r.measured { all.append(r.reliability); reasons += r.flags.map { "Lettura: \($0)" } }
        for (name, eye) in [("destro", p.visualField?.right), ("sinistro", p.visualField?.left)] where p.visualField?.isPreset == false {
            guard let eye else { continue }
            all.append(eye.reliability)
            if eye.fixationLossRate > 0.2 { reasons.append("Campo visivo \(name): perdite di fissazione \(Int(eye.fixationLossRate * 100))% (oltre 20%)") }
            if eye.falsePositiveRate > 0.15 { reasons.append("Campo visivo \(name): falsi positivi \(Int(eye.falsePositiveRate * 100))% (oltre 15%)") }
            if eye.falseNegativeRate > 0.33 { reasons.append("Campo visivo \(name): falsi negativi \(Int(eye.falseNegativeRate * 100))%") }
        }
        var overall: Reliability = .affidabile
        if all.contains(.nonAffidabile) { overall = .nonAffidabile }
        else if all.contains(.dubbio) || reasons.contains(where: { $0.contains("combinazione rara") }) { overall = .dubbio }

        p.summary = ProfileSummary(level: level, normalVision: normal, overallReliability: overall, reasons: reasons)
    }
}

extension Reliability {
    /// Affidabilità di un test con QUEST+ (SPEC 6, caso B, punti 1-3).
    nonisolated static func assess(quest: QuestPlus, records: [TrialRecord], easierIsHigher: Bool) -> (Reliability, [String]) {
        var flags: [String] = []
        var severe = false
        let t = quest.thresholdMean, b = quest.slopeMean
        let f = quest.function

        // 1. Coerenza con il modello: la log-verosimiglianza osservata confrontata con quella attesa.
        //    Per ogni prova con probabilità p: E[log L] = p·log p + (1−p)·log(1−p),
        //    Var = p(1−p)·(log(p/(1−p)))². z = (osservata − attesa) / √Var.
        var observed = 0.0, expected = 0.0, variance = 0.0
        for r in records {
            let p = min(max(f.pCorrect(stimulus: r.stimulus, threshold: t, slope: b), 1e-6), 1 - 1e-6)
            observed += log(r.correct ? p : 1 - p)
            expected += p * log(p) + (1 - p) * log(1 - p)
            let l = log(p / (1 - p))
            variance += p * (1 - p) * l * l
        }
        if variance > 0, records.count >= 8 {
            let z = (observed - expected) / sqrt(variance)
            if z < -3 { flags.append("risposte molto incoerenti con la curva stimata"); severe = true }
            else if z < -2 { flags.append("risposte poco coerenti con la curva stimata") }
        }

        // 2. Errori su stimoli facili: almeno 0,3 unità più facili della soglia.
        let errors = records.filter { !$0.correct }
        let easyErrors = errors.filter { easierIsHigher ? $0.stimulus >= t + 0.3 : $0.stimulus <= t - 0.3 }
        if errors.count >= 3, Double(easyErrors.count) / Double(errors.count) > 0.2 {
            flags.append("\(easyErrors.count) errori su lettere facili")
        }

        // 3. Tempi di risposta: errori velocissimi (< 400 ms) su lettere facili sono sospetti.
        let fastEasy = easyErrors.filter { $0.responseTimeMs < 400 }
        if fastEasy.count >= 2 { flags.append("risposte sbagliate troppo veloci su lettere facili") }

        // 3b. Schema dei tempi: vicino alla soglia si risponde più lentamente (incertezza).
        //     Correlazione di Pearson tra tempo di risposta e distanza dalla soglia |s − t|:
        //     attesa negativa (più lontano dalla soglia → più veloce). Se è chiaramente positiva, è sospetto.
        if records.count >= 12 {
            let xs = records.map { abs($0.stimulus - t) }, ys = records.map { min($0.responseTimeMs, 8000) }
            let mx = xs.reduce(0, +) / Double(xs.count), my = ys.reduce(0, +) / Double(ys.count)
            let cov = zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
            let vx = xs.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }, vy = ys.reduce(0) { $0 + ($1 - my) * ($1 - my) }
            if vx > 0, vy > 0, cov / sqrt(vx * vy) > 0.4 {
                flags.append("tempi di risposta anomali: più lenti sulle lettere facili")
            }
        }

        // Distanza: quanto si è mossa la persona durante il test.
        let d = records.map(\.distanceCM)
        if let lo = d.min(), let hi = d.max(), hi - lo > 20 {
            flags.append("distanza molto variabile (\(Int(lo))–\(Int(hi)) cm)")
        }

        let rel: Reliability = severe || flags.count >= 3 ? .nonAffidabile : (flags.isEmpty ? .affidabile : .dubbio)
        return (rel, flags)
    }
}
