import Foundation

/// Regole R0–R8 esattamente come nel contratto (docs/data-contracts.md, sezione 9).
/// VisualProfile + contesto (ppi, nativeScale) → AdaptationPlan alla distanza di riferimento di 400 mm.
nonisolated enum RulesEngine {
    typealias P = ContractParameters

    // MARK: R0 — Limite prudente

    /// Acuità: estremo superiore di ci95, +0,1 logMAR se doubtful o unreliable.
    static func prudentAcuity(_ a: AcuityBlock) -> Double {
        (a.ci95.last ?? a.logMAR) + (a.reliability == .reliable ? 0 : P.r0PrudentShift)
    }

    /// Contrasto: estremo inferiore di ci95, −0,1 logCS se doubtful o unreliable.
    static func prudentContrast(_ c: ContrastBlock) -> Double {
        (c.ci95.first ?? c.logCS) - (c.reliability == .reliable ? 0 : P.r0PrudentShift)
    }

    // MARK: R1 — Dimensione del testo

    /// s_target: base = dimensione critica di stampa + 0,1 se la lettura è misurata e affidabile,
    /// altrimenti acuità prudente + 0,4 (la riserva è già il margine). Più la correzione manuale.
    static func targetLogMAR(_ p: VisualProfile) -> Double {
        let base: Double
        if let r = p.reading, r.measured, r.source == .measured, r.reliability == .reliable {
            base = r.criticalPrintSizeLogMAR + P.r1ReadingMarginLogMAR
        } else {
            base = prudentAcuity(p.acuity) + P.r1AcuityReserveLogMAR
        }
        return base + p.textSizeOffset
    }

    /// θ = 5′·10^s (altezza della x, MNREAD); h_x = 400 mm · θ_rad; font_mm = h_x / r_x.
    static func fontSizeMm(targetLogMAR s: Double, distanceMm: Double = P.referenceDistanceMm) -> Double {
        let thetaRad = P.xHeightArcminAtZero * pow(10, s) / 60 * .pi / 180   // 5′·10^s in radianti
        return distanceMm * thetaRad / P.fontXHeightRatio
    }

    /// fontSizeCssPx = (h_x / r_x) · ppi / (25,4 · nativeScale), alla distanza di riferimento.
    static func fontSizeCssPx(targetLogMAR s: Double, context: ViewingContext) -> Double {
        context.cssPx(mm: fontSizeMm(targetLogMAR: s))
    }

    /// A runtime (ADR 0003): riscalata per d / 400, esatto perché R1 è lineare nella distanza.
    static func fontSizeAtDistance(plan: AdaptationPlan, distanceMm: Double) -> Double {
        plan.text.fontSizeCssPx * distanceMm / plan.context.referenceDistanceMm
    }

    // MARK: Piano completo

    static func plan(profile p: VisualProfile, context: ViewingContext) -> AdaptationPlan {
        let s = targetLogMAR(p)
        let fontMm = fontSizeMm(targetLogMAR: s)
        let font = context.cssPx(mm: fontMm)

        // R2: base WCAG 1.4.12; coinvolgimento centrale in almeno un occhio → spaziature ampie.
        let central = p.amsler?.centralInvolved ?? false
        let text = AdaptationPlan.Text(
            fontFamily: P.fontFamily, fontSizeCssPx: font,
            lineHeight: central ? P.centralLineHeight : P.wcagLineHeight,
            letterSpacingEm: central ? P.centralLetterSpacingEm : P.wcagLetterSpacingEm,
            wordSpacingEm: central ? P.centralWordSpacingEm : P.wcagWordSpacingEm,
            paragraphSpacingEm: central ? P.centralParagraphSpacingEm : P.wcagParagraphSpacingEm, align: "left")

        // R2: lunghezza della riga in ch, indipendente dalla distanza.
        // R = raggio dell'occhio migliore; L_max = 2 · 400 · tan(R) · 0,8; ch = L_max / (font_mm · zeroWidthEm).
        var maxCh = P.maxLineWidthCh
        if let field = p.visualField, field.hasProblem, let r = field.eyes.map(\.fieldRadiusDeg).max() {
            let lMaxMm = 2 * P.referenceDistanceMm * tan(r * .pi / 180) * P.lineLengthFieldFactor
            maxCh = min(max(lMaxMm / (fontMm * P.fontZeroWidthEm), P.minLineWidthCh), P.maxLineWidthCh)
        }
        let layout = AdaptationPlan.Layout(singleColumn: true, maxLineWidthCh: maxCh, mode: "normal",
                                           moveEdgeElements: p.visualField?.hasProblem ?? false)

        // R3: contrasto minimo del testo dal limite prudente della sensibilità.
        let x = prudentContrast(p.contrast)
        let minText = minTextContrast(logCS: x)

        // R4: tema e luce.
        var theme = "original"
        var brightness: Double?
        let photophobia = p.light?.photophobia ?? false
        if let light = p.light {
            if let pref = light.preferredTheme { theme = pref.rawValue } else { theme = photophobia ? "dark" : "original" }
            brightness = light.preferredBrightness
        }
        let (bg, fg): (String?, String?) = switch theme {
        case "dark": (P.darkBackground, P.darkText)
        case "light": (P.lightBackground, P.lightText)
        default: (nil, nil)
        }
        let color = AdaptationPlan.Color(
            theme: theme, background: bg, text: fg, minTextContrast: minText,
            minUIContrast: max(P.minUIContrastFloor, minText * P.minUIContrastScale), preserveHue: true,
            imageBrightness: (photophobia || theme == "dark") ? P.dimmedImageBrightness : 1)

        // R5–R8 e campi restanti.
        let controls = AdaptationPlan.Controls(
            underlineLinks: true,
            minTargetPt: min(max(P.minTargetPtBase * font / P.minTargetReferenceCssPx, P.minTargetPtBase), P.minTargetPtMax),
            focusOutlinePx: P.focusOutlinePx)

        return AdaptationPlan(
            context: .init(referenceDistanceMm: P.referenceDistanceMm, ppi: context.ppi, nativeScale: context.nativeScale),
            text: text, layout: layout, color: color, controls: controls,
            cleanup: .init(removeCookieBanners: true, stopAnimations: true, useReadability: true),
            speech: .init(tapToSpeak: false, rateWpm: nil),
            screen: .init(brightness: brightness))
    }

    /// Tabella R3.
    static func minTextContrast(logCS x: Double) -> Double {
        if x >= P.contrastNormalMin { return P.textContrastNormal }
        if x >= P.contrastBorderlineMin { return P.textContrastBorderline }
        if x >= P.contrastReducedMin {
            // Lineare nella fascia ridotta: 12 a 1,0 → 7 a 1,5, cioè 12 − 10 (x − 1,0).
            let slope = (P.textContrastReducedUpper - P.textContrastReducedLower) / (P.contrastBorderlineMin - P.contrastReducedMin)
            return P.textContrastReducedLower + slope * (x - P.contrastReducedMin)
        }
        return P.textContrastSeverelyReduced
    }

    // MARK: Spiegazioni per la schermata dei risultati

    static func explanations(profile p: VisualProfile, plan: AdaptationPlan, distanceMm: Double) -> [String] {
        var notes: [String] = []
        let base = (p.reading?.measured == true && p.reading?.reliability == .reliable)
            ? "dimensione critica di stampa + 0,1" : "acuità prudente \(prudentAcuity(p.acuity).it()) + riserva 0,4"
        notes.append("R1: testo di almeno \(Int(fontSizeAtDistance(plan: plan, distanceMm: distanceMm).rounded())) pt a \(Int(distanceMm / 10)) cm (\(base)), cresce se allontani il telefono")
        notes.append("R2: una colonna, righe di al massimo \(Int(plan.layout.maxLineWidthCh.rounded())) caratteri, interlinea \(plan.text.lineHeight.it(1))")
        notes.append("R3: contrasto del testo almeno \(plan.color.minTextContrast.it(1)):1")
        notes.append("R4: tema \(plan.color.theme == "original" ? "del sito" : (plan.color.theme == "dark" ? "scuro" : "chiaro"))")
        if plan.layout.moveEdgeElements { notes.append("R5: niente elementi importanti ai bordi") }
        notes.append("R6–R8: niente animazioni, popup e pubblicità; link sottolineati e pulsanti di almeno \(Int(plan.controls.minTargetPt)) punti")
        return notes
    }
}
