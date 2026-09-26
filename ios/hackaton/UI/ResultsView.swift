import SwiftUI

/// "Ecco come vedi": i valori spiegati in parole semplici, con l'affidabilità del test.
struct ResultsView: View {
    @Environment(AppModel.self) private var app
    var showsContinue = true

    var body: some View {
        let look = app.appearance
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ecco come vedi").font(.ipo(.largeTitle, bold: true))
                if let p = app.effectiveProfile {
                    summaryCard(p)
                    if let a = p.acuity { acuityCard(a) }
                    if let c = p.contrast { contrastCard(c) }
                    if let r = p.reading, r.measured { readingCard(r) }
                    if let am = p.amsler { amslerCard(am) }
                    if let f = p.visualField { FieldResultCard(field: f) }
                    if let l = p.light { lightCard(l) }
                    adaptationCard(p)
                    Text("Questo è un profilo della tua vista funzionale, non una diagnosi medica: non sostituisce l'oculista. I dati restano sul telefono.")
                        .font(.ipo(.footnote)).foregroundStyle(look.secondary)
                } else {
                    Text("Nessun test ancora.").font(.ipo(.title2))
                }
                if showsContinue {
                    BigButton(title: "Inizia a navigare", systemImage: "safari") { app.route = .browser }
                    BigButton(title: "Rifai il test", systemImage: "arrow.counterclockwise", prominent: false) { app.startTest() }
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

    private func summaryCard(_ p: VisualProfile) -> some View {
        card(p.summary.normalVision ? "Vista nella norma" : "In sintesi", icon: "eye") {
            if p.summary.normalVision {
                Text("La tua vista risulta nella norma per questi test, non serve nessun adattamento.").font(.ipo(.title3))
            } else {
                Text("Livello complessivo: \(p.summary.level.rawValue).").font(.ipo(.title3))
            }
            reliabilityRow(p.summary.overallReliability)
            ForEach(p.summary.reasons, id: \.self) { Text("• \($0)").font(.ipo(.body)) }
            if p.summary.overallReliability == .nonAffidabile {
                BigButton(title: "Ripeti il test", systemImage: "arrow.counterclockwise") { app.startTest() }
            }
        }
    }

    private func acuityCard(_ a: AcuityResult) -> some View {
        card("Acuità", icon: "textformat.size") {
            Text("Da vicino vedi come \(Acuity.decimi(a.logMAR).it(1))/10, cioè \(Acuity.snellen(a.logMAR)).")
                .font(.ipo(.title3, bold: true))
            Text("Soglia \(a.logMAR.it()) logMAR, intervallo al 95% \(a.ci95[0].it())–\(a.ci95[1].it()). Categoria OMS: \(whoCategory(a.logMAR)). \(a.trials) risposte a circa \(Int(a.meanDistanceCM)) cm.")
                .font(.ipo(.body))
            ConfidenceBar(estimate: a.logMAR, ci: a.ci95[0]...a.ci95[1], range: -0.3...1.8, boundaries: [0.3, 0.48, 1.0, 1.3])
            Text("Le fasce OMS riguardano la vista da lontano; qui misuriamo quella da vicino.")
                .font(.ipo(.footnote)).foregroundStyle(app.appearance.secondary)
            reliabilityRow(a.reliability, flags: a.flags)
        }
    }

    private func contrastCard(_ c: ContrastResult) -> some View {
        card("Contrasto", icon: "circle.lefthalf.filled") {
            let band = c.logCS >= 1.5 ? "normale" : (c.logCS >= 1.0 ? "ridotta" : "molto ridotta")
            Text("Sensibilità al contrasto \(band).").font(.ipo(.title3, bold: true))
            Text("\(c.logCS.it()) log, intervallo al 95% \(c.ci95[0].it())–\(c.ci95[1].it()). Vedi lettere fino al \((100 * pow(10, -c.logCS)).it(1))% di contrasto.")
                .font(.ipo(.body))
            ConfidenceBar(estimate: c.logCS, ci: c.ci95[0]...c.ci95[1], range: 0...2.1, boundaries: [1.0, 1.5])
            reliabilityRow(c.reliability, flags: c.flags)
        }
    }

    private func readingCard(_ r: ReadingResult) -> some View {
        card("Lettura", icon: "text.book.closed") {
            Text("Leggi al massimo \(Int(r.maxReadingSpeedWpm)) parole al minuto.").font(.ipo(.title3, bold: true))
            Text("Dimensione critica di stampa \(r.criticalPrintSizeLogMAR.it()) logMAR (sotto questa rallenti). Acuità di lettura \(r.readingAcuityLogMAR.it()) logMAR.")
                .font(.ipo(.body))
            reliabilityRow(r.reliability, flags: r.flags)
        }
    }

    private func amslerCard(_ a: AmslerResult) -> some View {
        card("Griglia di Amsler", icon: "grid") {
            HStack(spacing: 16) {
                if let r = a.right { AmslerMiniMap(eye: r, label: "Destro") }
                if let l = a.left { AmslerMiniMap(eye: l, label: "Sinistro") }
            }
            Text(a.centralSeverity == "no" ? "Nessuna zona storta o mancante."
                 : "Zona centrale \(a.centralSeverity == "grande" ? "ampia" : "piccola") con linee storte o mancanti.")
                .font(.ipo(.body))
        }
    }

    private func lightCard(_ l: LightResult) -> some View {
        card("Luce", icon: "sun.max") {
            Text("Preferisci il tema \(l.preferredTheme.rawValue), luminosità \(Int(l.preferredBrightness * 100))%.")
                .font(.ipo(.title3, bold: true))
            Text(l.photophobia ? "La luce forte ti dà fastidio." : "La luce non ti dà particolare fastidio.").font(.ipo(.body))
        }
    }

    private func adaptationCard(_ p: VisualProfile) -> some View {
        let plan = RulesEngine.plan(profile: p, context: BrowserContext.current())
        return card("Come cambiano le pagine", icon: "wand.and.stars") {
            Text("Testo di \(Int(plan.text.fontSizePx)) punti a \(Int(FaceDistanceTracker.shared.effectiveCM)) cm, che cresce se allontani il telefono.")
                .font(.ipo(.title3, bold: true))
            ForEach(plan.explanations, id: \.self) { Text("• \($0)").font(.ipo(.body)) }
        }
    }

    private func reliabilityRow(_ r: Reliability, flags: [String] = []) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Test \(r.label)", systemImage: r == .affidabile ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.ipo(.headline, bold: true))
                .foregroundStyle(r == .affidabile ? Color.green : (r == .dubbio ? Color.orange : Color.red))
            ForEach(flags, id: \.self) { Text("– \($0)").font(.ipo(.footnote)) }
        }
    }

    private func whoCategory(_ l: Double) -> String {
        switch l {
        case ...0.3: "normale"
        case ...0.48: "lieve"
        case ...1.0: "moderata"
        case ...1.3: "grave"
        default: "cecità"
        }
    }

    private func speakSummary() {
        guard let p = app.effectiveProfile else { return }
        var text = "Ecco come vedi. "
        if p.summary.normalVision {
            text += "La tua vista risulta nella norma per questi test, non serve nessun adattamento. "
        } else if let a = p.acuity {
            text += "Da vicino vedi come \(Acuity.decimi(a.logMAR).it(1).replacingOccurrences(of: ",0", with: "")) decimi. "
        }
        if let c = p.contrast {
            text += c.logCS >= 1.5 ? "Il contrasto è normale. " : "Il contrasto è ridotto. "
        }
        text += "Le pagine web adesso si adattano ai tuoi occhi. Tocca Inizia a navigare."
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
                            let v = eye.cells[r][c]
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
    var field: VisualFieldResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(field.isPreset ? "Campo visivo (profilo di esempio)" : "Campo visivo", systemImage: "circle.dotted")
                .font(.ipo(.title2, bold: true))
            HStack(alignment: .top, spacing: 12) {
                if let r = field.right { eyeView(r, label: "Destro") }
                if let l = field.left { eyeView(l, label: "Sinistro") }
            }
            if let e = field.right ?? field.left {
                Text("\(e.pattern.label.capitalized), raggio \(Int(e.fieldRadiusDeg))°. Difetto medio \(e.meanDefect.it(1)) livelli.")
                    .font(.ipo(.title3, bold: true))
                Text("Perdite di fissazione \(Int(e.fixationLossRate * 100))% · falsi positivi \(Int(e.falsePositiveRate * 100))% · falsi negativi \(Int(e.falseNegativeRate * 100))%. Test \(e.reliability.label).")
                    .font(.ipo(.body))
                Text("Intensità relative dello schermo (10 livelli), non decibel di un perimetro clinico.")
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
            let xs = eye.points.map(\.x), ys = eye.points.map(\.y)
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
                    for p in eye.points {
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
        .accessibilityLabel("Mappa di calore del campo visivo")
    }

    /// 0 = non visto (nero), 10 = sensibilità piena (giallo chiaro).
    static func color(_ s: Double) -> Color {
        let t = max(0, min(1, s / 10))
        return Color(hue: 0.02 + 0.13 * t, saturation: 0.9 - 0.3 * t, brightness: 0.1 + 0.9 * t)
    }
}
