import Foundation

/// Regole di adattamento R0–R10 (SPEC sezione 8): VisualProfile + distanza → AdaptationPlan.
nonisolated enum RulesEngine {
    /// Rapporto altezza della x / corpo del font per Atkinson Hyperlegible:
    /// sxHeight 496 / unitsPerEm 1000 (letto dalla tabella OS/2 del font incluso).
    static let xHeightRatio = 0.496
    /// Larghezza media di un carattere in em (Atkinson Hyperlegible, testo italiano).
    static let avgCharWidthEm = 0.55
    /// Acuità ipotizzata quando non c'è ancora nessun test (vedi DECISIONS.md).
    static let defaultAcuityLogMAR = 0.2
    /// Dimensione del testo "originale" di riferimento dei siti, in px CSS.
    static let referenceSitePx = 16.0

    // MARK: R0 — Nel dubbio, più leggibile

    /// Acuità dal lato prudente: limite peggiore (alto) dell'intervallo al 95%,
    /// +0,1 logMAR se il test è dubbio o non affidabile.
    static func prudentAcuity(_ profile: VisualProfile?) -> Double? {
        guard let a = profile?.acuity else { return nil }
        let worst = a.ci95.last ?? a.logMAR
        return worst + (a.reliability == .affidabile ? 0 : 0.1)
    }

    /// Sensibilità al contrasto dal lato prudente: limite basso dell'intervallo, −0,1 se dubbio.
    static func prudentContrast(_ profile: VisualProfile?) -> Double? {
        guard let c = profile?.contrast else { return nil }
        let worst = c.ci95.first ?? c.logCS
        return worst - (c.reliability == .affidabile ? 0 : 0.1)
    }

    /// Dimensione critica di stampa dal lato prudente (R0 + R1).
    /// Base: test di lettura. Riserva: acuità + 0,4 logMAR ("riserva di acuità", ~2,5×).
    static func criticalPrintSize(_ profile: VisualProfile?) -> (value: Double, source: String) {
        if let r = profile?.reading, r.measured, r.reliability != .nonAffidabile {
            let worst = r.ci95.last ?? r.criticalPrintSizeLogMAR
            return (worst + (r.reliability == .affidabile ? 0 : 0.1), "test di lettura")
        }
        if let acuity = prudentAcuity(profile) {
            return (acuity + 0.4, "acuità + riserva 0,4")
        }
        return (defaultAcuityLogMAR + 0.4, "valore predefinito")
    }

    // MARK: R1 — Dimensione del testo

    /// s_obiettivo = s_critica + 0,1 + correzione manuale (R10)
    static func targetLogMAR(_ profile: VisualProfile?) -> Double {
        criticalPrintSize(profile).value + 0.1 + (profile?.userAdjustments.textSizeOffsetLogMAR ?? 0)
    }

    /// h_x = d · θ(s): la x minuscola sottende 5' · 10^s (convenzione MNREAD).
    /// font = h_x / r_x, poi da mm a px CSS con la densità dello schermo.
    /// Proporzionale alla distanza: telefono più lontano del 20% → testo più grande del 20%.
    static func fontSizePx(targetLogMAR s: Double, context: ViewingContext) -> Double {
        let xHeightArcmin = 5 * pow(10, s)
        let hxMM = VisualAngle.mm(arcmin: xHeightArcmin, distanceMM: context.distanceMM)
        let fontMM = hxMM / xHeightRatio
        return context.cssPx(mm: fontMM)
    }

    static func fontSizePx(profile: VisualProfile?, context: ViewingContext) -> Double {
        fontSizePx(targetLogMAR: targetLogMAR(profile), context: context)
    }

    // MARK: Piano completo

    static func plan(profile: VisualProfile?, context: ViewingContext) -> AdaptationPlan {
        var notes: [String] = []
        let target = targetLogMAR(profile)
        let cps = criticalPrintSize(profile)
        let font = fontSizePx(targetLogMAR: target, context: context)
        notes.append(String(format: "R1: testo %.0f px (dimensione critica %.2f logMAR da %@, +0,1 di margine, a %.0f cm)",
                            font, cps.value, cps.source, context.distanceMM / 10))

        var plan = AdaptationPlan(text: .init(fontSizePx: font), layout: .init(maxLineWidthPx: context.screenWidthPt - 24))

        // --- R2: impaginazione e spaziatura (base WCAG 1.4.12 per tutti) ---
        let field = profile?.visualField
        let radius = field?.worstRadius
        let fieldReduced = (radius.map { $0 < 20 } ?? false)
            || (field?.patterns.contains(where: { $0 == .tunnel || $0 == .periferica }) ?? false)
        let central = (profile?.amsler.map { $0.centralSeverity != "no" } ?? false)
            || (field?.patterns.contains(.centrale) ?? false)
        if central {
            // Zona cieca al centro: spaziatura più ampia per non perdere la riga.
            plan.text.lineHeight = 2.0
            plan.text.letterSpacingEm = 0.18
            plan.text.wordSpacingEm = 0.24
            notes.append("R2: zona centrale compromessa → interlinea 2, spaziature ampie")
        }
        let charPx = font * (avgCharWidthEm + plan.text.letterSpacingEm)
        plan.layout.singleColumn = font > 1.5 * referenceSitePx || fieldReduced || central
        let screenLine = context.screenWidthPt - 24
        if fieldReduced, let radius {
            // L_max = 2 · d · tan(R_campo) · 0,8: la riga resta dentro la zona che si vede.
            let lMaxMM = 2 * context.distanceMM * tan(radius * .pi / 180) * 0.8
            plan.layout.maxLineWidthPx = min(screenLine, max(15 * charPx, context.cssPx(mm: lMaxMM)))
            notes.append(String(format: "R2: campo di %.0f° → righe larghe al massimo %.0f mm", radius, lMaxMM))
        } else {
            plan.layout.maxLineWidthPx = min(screenLine, 60 * charPx)
        }

        // --- R3: contrasto minimo del testo dalla sensibilità al contrasto ---
        if let cs = prudentContrast(profile) {
            plan.color.minTextContrast = minTextContrast(logCS: cs)
            notes.append(String(format: "R3: contrasto %.2f log → testo almeno %.1f:1", cs, plan.color.minTextContrast))
        }
        // Bordi dei controlli: almeno 3:1, alzati in proporzione all'obiettivo del testo.
        plan.color.minUIContrast = max(3, 3 * plan.color.minTextContrast / 4.5)

        // --- R4: luce e tema ---
        let level = profile?.summary.level ?? .lieve
        let theme: Theme
        if let light = profile?.light {
            theme = light.preferredTheme
            plan.screen.brightness = light.preferredBrightness
        } else {
            let lowContrast = (prudentContrast(profile) ?? 2) < 1.5
            theme = (level > .normale || lowContrast) ? .chiaro : .originale
        }
        plan.color.theme = theme
        switch theme {
        case .scuro:
            plan.color.background = "#121212"; plan.color.text = "#E8E6E3"; plan.color.imageBrightness = 0.85
        case .chiaro:
            plan.color.background = "#FFFBF2"; plan.color.text = "#1A1A1A"
        case .originale:
            break
        }
        notes.append("R4: tema \(theme.rawValue)")

        // --- R5: campo visivo e controlli ---
        plan.layout.moveEdgeElements = fieldReduced
        if let radius, radius < 10 {
            plan.layout.mode = "paragrafo"
            notes.append("R5: campo sotto 10° → un paragrafo alla volta")
        }

        // --- R6 e R8: per tutti ---
        plan.cleanup = .init(removeCookieBanners: true, stopAnimations: true, useReadability: true)

        // --- R7: link e pulsanti, area di tocco da 44 a 64 punti in proporzione al testo ---
        plan.controls.minTargetPt = min(64, max(44, 44 * font / 17))
        plan.controls.focusOutlinePx = level >= .moderato ? 4 : 3

        // --- R9: se restano meno di 12 caratteri per riga → modalità lettura grande ---
        let charsPerLine = plan.layout.maxLineWidthPx / charPx
        if charsPerLine < 12 {
            plan.layout.mode = "lettura-grande"
            plan.speech.tapToSpeak = true
            notes.append(String(format: "R9: solo %.0f caratteri per riga → lettura grande con voce", charsPerLine))
        }
        if let wpm = profile?.reading?.maxReadingSpeedWpm, profile?.reading?.measured == true {
            plan.speech.rateWpm = min(220, max(80, wpm))
        } else {
            plan.speech.rateWpm = 140
        }

        plan.explanations = notes
        return plan
    }

    /// Tabella R3: sensibilità al contrasto (log) → contrasto minimo del testo.
    static func minTextContrast(logCS cs: Double) -> Double {
        switch cs {
        case 1.65...: 4.5                         // AA del W3C
        case 1.5..<1.65: 7                        // AAA
        case 1.0..<1.5: 7 + (1.5 - cs) / 0.5 * 5  // da 7:1 a 12:1 in proporzione
        default: 15
        }
    }
}
