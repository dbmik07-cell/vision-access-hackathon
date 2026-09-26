import SwiftUI

/// "Ecco come vedi": i valori spiegati in parole semplici, con l'affidabilità del test.
struct ResultsView: View {
    @Environment(AppModel.self) private var app
    var showsContinue = true

    var body: some View {
        let look = app.appearance
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Here's how you see").font(.ipo(.largeTitle, bold: true))
                if let p = app.effectiveProfile {
                    summaryCard(p)
                    acuityCard(p.acuity)
                    contrastCard(p.contrast)
                    if let r = app.readingMeasurement, r.measured { readingCard(r) }
                    if let am = p.amsler { amslerCard(am) }
                    if let f = p.visualField { FieldResultCard(field: f) }
                    if let l = p.light { lightCard(l) }
                    adaptationCard(p)
                    Text("This is a profile of your functional vision, not a medical diagnosis: it doesn't replace an eye doctor. The data stays on your phone.")
                        .font(.ipo(.footnote)).foregroundStyle(look.secondary)
                } else {
                    Text("No test yet.").font(.ipo(.title2))
                }
                if showsContinue {
                    BigButton(title: "Start browsing", systemImage: "safari") { app.route = .browser }
                    BigButton(title: "Retake the test", systemImage: "arrow.counterclockwise", prominent: false) { app.startTest() }
                }
            }
            .padding(20)
        }
        .foregroundStyle(look.foreground)
        .background(look.background.ignoresSafeArea())
        .tint(look.accent)
        .onAppear { if showsContinue { speakSummary() } }
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.ipo(.title2, bold: true))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func presetTag(_ source: BlockSource) -> some View {
        Group {
            if source == .preset {
                Text("example value, not measured").font(.ipo(.footnote, bold: true)).foregroundStyle(.orange)
            }
        }
    }

    private func summaryCard(_ p: VisualProfile) -> some View {
        card(p.summary.normalVision ? "Normal vision" : "Summary", icon: "eye") {
            if p.summary.normalVision {
                // Frase riscritta (contratto, sezione 13): nessun caso speciale nel piano.
                Text("Your vision is within the normal range for these tests. Pages still adapt slightly; you can always switch back to the original.")
                    .font(.ipo(.title3))
            } else {
                Text("Near acuity: \(p.acuity.whoCategory.label). Contrast: \(p.contrast.band.label).").font(.ipo(.title3))
            }
            if let r = p.summary.overallReliability { reliabilityRow(r) }
            ForEach(app.diagnostics, id: \.self) { Text("• \($0)").font(.ipo(.body)) }
            if p.summary.overallReliability == .unreliable {
                BigButton(title: "Repeat the test", systemImage: "arrow.counterclockwise") { app.startTest() }
            }
        }
    }

    private func acuityCard(_ a: AcuityBlock) -> some View {
        card("Acuity", icon: "textformat.size") {
            presetTag(a.source)
            if a.censoredAtDisplayLimit == true, let limit = a.displayLimitLogMAR {
                Text("You can even see the smallest letter this screen can draw: acuity ≤ \(limit.it()) logMAR.")
                    .font(.ipo(.title3, bold: true))
            } else {
                Text("Up close you see like \(Acuity.decimi(a.logMAR).it(1))/10, that is \(Acuity.snellen(a.logMAR)).")
                    .font(.ipo(.title3, bold: true))
            }
            Text("Median \(a.logMAR.it()) logMAR, 95% interval \(a.ci95[0].it())–\(a.ci95[1].it()). WHO category: \(a.whoCategory.label).\(a.trials.map { " \($0) responses." } ?? "")")
                .font(.ipo(.body))
            ConfidenceBar(estimate: a.logMAR, ci: a.ci95[0]...a.ci95[1], range: -0.3...1.8, boundaries: [0.3, 0.48, 1.0, 1.3])
            Text("WHO categories are for distance vision; here we measure near vision.")
                .font(.ipo(.footnote)).foregroundStyle(app.appearance.secondary)
            reliabilityRow(a.reliability, flags: a.flags)
        }
    }

    private func contrastCard(_ c: ContrastBlock) -> some View {
        card("Contrast", icon: "circle.lefthalf.filled") {
            presetTag(c.source)
            if c.censoredAtCeiling == true, let ceil = c.ceilingLogCS {
                Text("You can even see the lowest contrast this screen can show: ≥ \(ceil.it()) log.").font(.ipo(.title3, bold: true))
            } else {
                Text("Contrast sensitivity \(c.band.label).").font(.ipo(.title3, bold: true))
            }
            Text("Median \(c.logCS.it()) log, 95% interval \(c.ci95[0].it())–\(c.ci95[1].it()). You can see letters down to \((100 * pow(10, -c.logCS)).it(1))% contrast.")
                .font(.ipo(.body))
            ConfidenceBar(estimate: c.logCS, ci: c.ci95[0]...c.ci95[1], range: 0...2.1, boundaries: [1.0, 1.5, 1.65])
            reliabilityRow(c.reliability, flags: c.flags)
        }
    }

    private func readingCard(_ r: ReadingMeasurement) -> some View {
        card("Reading", icon: "text.book.closed") {
            Text("You read up to \(Int(r.maxReadingSpeedWpm)) words per minute.").font(.ipo(.title3, bold: true))
            Text("Critical print size \(r.criticalPrintSizeLogMAR.it()) logMAR (below this you slow down). Reading acuity \(r.readingAcuityLogMAR.it()) logMAR.")
                .font(.ipo(.body))
            reliabilityRow(r.reliability, flags: r.flags)
        }
    }

    private func amslerCard(_ a: AmslerBlock) -> some View {
        card("Amsler grid", icon: "grid") {
            presetTag(a.source)
            HStack(spacing: 16) {
                if let r = a.right { AmslerMiniMap(eye: r, label: "Right") }
                if let l = a.left { AmslerMiniMap(eye: l, label: "Left") }
            }
            Text(!a.hasProblem ? "No crooked or missing areas."
                 : (a.centralInvolved ? "Central area with crooked or missing lines: involves the central 2 degrees." : "Crooked or missing lines outside the center."))
                .font(.ipo(.body))
        }
    }

    private func lightCard(_ l: LightBlock) -> some View {
        card("Light", icon: "sun.max") {
            presetTag(l.source)
            if let t = l.preferredTheme {
                Text("You prefer the \(t == .dark ? "dark" : "light") theme\(l.preferredBrightness.map { ", \(Int($0 * 100))% brightness" } ?? "").")
                    .font(.ipo(.title3, bold: true))
            }
            Text(l.photophobia ? "Bright light bothers you." : "Bright light doesn't particularly bother you.").font(.ipo(.body))
        }
    }

    private func adaptationCard(_ p: VisualProfile) -> some View {
        let plan = RulesEngine.plan(profile: p, context: BrowserContext.current())
        let notes = RulesEngine.explanations(profile: p, plan: plan, distanceMm: FaceDistanceTracker.shared.effectiveMM)
        return card("How pages change", icon: "wand.and.stars") {
            ForEach(notes, id: \.self) { Text("• \($0)").font(.ipo(.body)) }
        }
    }

    private func reliabilityRow(_ r: ContractReliability, flags: [String] = []) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("\(r.label.capitalized) test", systemImage: r == .reliable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.ipo(.headline, bold: true))
                .foregroundStyle(r == .reliable ? Color.green : (r == .doubtful ? Color.orange : Color.red))
            ForEach(flags, id: \.self) { Text("– \(Self.flagLabel($0))").font(.ipo(.footnote)) }
        }
    }

    static func flagLabel(_ f: String) -> String {
        switch f {
        case "wideInterval": "wide 95% interval (over 0.30)"
        case "maxTrialsReached": "reached 30 responses without the desired precision"
        case "contrastLetterSizeCapped": "contrast letter capped at 8°"
        default: f
        }
    }

    private func speakSummary() {
        guard let p = app.effectiveProfile else { return }
        var text = "Here's how you see. "
        if p.summary.normalVision {
            text += "Your vision is within the normal range for these tests. "
        } else {
            text += "Up close you see like \(Acuity.decimi(p.acuity.logMAR).it(1).replacingOccurrences(of: ".0", with: "")) out of 10. "
        }
        text += p.contrast.logCS >= 1.5 ? "Your contrast is normal. " : "Your contrast is reduced. "
        text += "Web pages now adapt to your eyes. Tap Start browsing."
        Voice.shared.say(text)
    }
}

struct AmslerMiniMap: View {
    var eye: AmslerEye
    var label: String
    var body: some View {
        VStack {
            Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                ForEach(0..<10, id: \.self) { r in
                    GridRow {
                        ForEach(0..<10, id: \.self) { c in
                            let v = eye.cells?[r][c] ?? 0
                            Rectangle().fill(v == 0 ? Color(white: 0.92) : (v == 1 ? Color.orange : Color.black))
                                .frame(width: 11, height: 11)
                        }
                    }
                }
            }
            Text(label).font(.ipo(.footnote, bold: true))
        }
    }
}

/// Mappa di calore del campo visivo per occhio.
struct FieldResultCard: View {
    var field: VisualFieldBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(field.source == .preset ? "Visual field (example profile)" : "Visual field", systemImage: "circle.dotted")
                .font(.ipo(.title2, bold: true))
            HStack(alignment: .top, spacing: 12) {
                if let r = field.right { eyeView(r, label: "Right") }
                if let l = field.left { eyeView(l, label: "Left") }
            }
            if let e = field.right ?? field.left {
                Text("\(e.pattern.label.capitalized), radius \(Int(e.fieldRadiusDeg))°.\(e.meanDefect.map { " Mean defect \($0.it(1)) levels." } ?? "")")
                    .font(.ipo(.title3, bold: true))
                if let fl = e.fixationLossRate, let fp = e.falsePositiveRate, let fn = e.falseNegativeRate {
                    Text("Fixation losses \(Int(fl * 100))% · false positives \(Int(fp * 100))% · false negatives \(Int(fn * 100))%.\(e.reliability.map { " \($0.label.capitalized) test." } ?? "")")
                        .font(.ipo(.body))
                }
                Text("Relative screen intensities (10 levels), not decibels from a clinical perimeter.")
                    .font(.ipo(.footnote)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func eyeView(_ eye: FieldEye, label: String) -> some View {
        VStack {
            FieldHeatmap(eye: eye).frame(height: 130)
            Text(label).font(.ipo(.footnote, bold: true))
        }
        .frame(maxWidth: .infinity)
    }
}

struct FieldHeatmap: View {
    var eye: FieldEye

    var body: some View {
        Canvas { ctx, size in
            let pts = eye.points ?? []
            let xs = pts.map(\.x), ys = pts.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return }
            let spanX = max(maxX - minX, 1), spanY = max(maxY - minY, 1)
            let scale = min(size.width / (spanX + 6), size.height / (spanY + 6))
            let cell = 6 * scale
            let cx = size.width / 2 - (minX + maxX) / 2 * scale
            let cy = size.height / 2 + (minY + maxY) / 2 * scale
            // Interpolazione per distanza inversa: una mappa continua dai punti misurati.
            let step: CGFloat = max(3, cell / 4)
            var y = cy - maxY * scale - cell / 2
            while y < cy - minY * scale + cell / 2 {
                var x = cx + minX * scale - cell / 2
                while x < cx + maxX * scale + cell / 2 {
                    let gx = (x - cx) / scale, gy = (cy - y) / scale
                    var num = 0.0, den = 0.0
                    for p in pts {
                        let d2 = (p.x - gx) * (p.x - gx) + (p.y - gy) * (p.y - gy) + 1
                        let w = 1 / (d2 * d2)
                        num += w * p.sensitivity; den += w
                    }
                    let s = den > 0 ? num / den : 0
                    ctx.fill(Path(CGRect(x: x, y: y, width: step + 0.5, height: step + 0.5)), with: .color(Self.color(s)))
                    x += step
                }
                y += step
            }
            // Punto di fissazione e macchia cieca.
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 3, y: cy - 3, width: 6, height: 6)), with: .color(.white))
            if let bs = eye.blindSpot, bs.count == 2 {
                let r = CGRect(x: cx + bs[0] * scale - 4, y: cy - bs[1] * scale - 4, width: 8, height: 8)
                ctx.stroke(Path(ellipseIn: r), with: .color(.white), lineWidth: 1.5)
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("Visual field heat map")
    }

    /// 0 = non visto (nero), 10 = sensibilità piena (giallo chiaro).
    static func color(_ s: Double) -> Color {
        let t = max(0, min(1, s / 10))
        return Color(hue: 0.02 + 0.13 * t, saturation: 0.9 - 0.3 * t, brightness: 0.1 + 0.9 * t)
    }
}
