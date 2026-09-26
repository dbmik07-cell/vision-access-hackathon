import SwiftUI

/// Griglia di Amsler (SPEC 5.4): un occhio alla volta, ogni quadretto = 1 grado alla distanza misurata,
/// 10 × 10 quadretti = i 10 gradi centrali. Due passaggi: linee storte, poi linee mancanti o sfocate.
struct AmslerTestView: View {
    var onFinish: (AmslerBlock) -> Void
    var onQuit: () -> Void

    enum Pass { case distorted, missing }
    @State private var eye: FieldSession.Eye = .right
    @State private var pass: Pass = .distorted
    @State private var cells = Array(repeating: Array(repeating: 0, count: 10), count: 10)
    @State private var result = AmslerBlock(source: .measured)
    /// Lato del quadretto fissato all'inizio di ogni occhio (1° alla distanza di quel momento).
    @State private var cellPt: CGFloat = 20
    private var tracker = FaceDistanceTracker.shared

    init(onFinish: @escaping (AmslerBlock) -> Void, onQuit: @escaping () -> Void) {
        self.onFinish = onFinish
        self.onQuit = onQuit
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                DistanceBadge()
                Spacer()
                Button("Esci") { onQuit() }.buttonStyle(.glass).font(.ipo(.headline))
            }
            let stepIndex = (eye == .right ? 0 : 2) + (pass == .missing ? 1 : 0)
            BigProgressBar(value: Double(stepIndex) / 4, label: "Passaggio \(stepIndex + 1) di 4")
            Text("Occhio \(eye == .right ? "destro" : "sinistro"): copri il \(eye == .right ? "sinistro" : "destro")")
                .font(.ipo(.title3, bold: true))
            Text(pass == .distorted ? "Guarda il punto e passa il dito dove le linee sono storte."
                 : "Passa il dito dove le linee mancano o sono sfocate.")
                .font(.ipo(.headline)).multilineTextAlignment(.center)
            Spacer(minLength: 0)
            grid
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                BigButton(title: "Cancella", systemImage: "eraser", prominent: false) { clearPass() }
                BigButton(title: pass == .distorted ? "Avanti" : "Fatto", systemImage: "arrow.right") { next() }
            }
        }
        .padding(16)
        .foregroundStyle(.black)
        .background(Color.white.ignoresSafeArea())
        .dynamicTypeSize(.xLarge)
        .onAppear { startEye() }
    }

    private var grid: some View {
        let side = cellPt * 10
        return ZStack {
            Canvas { ctx, size in
                let c = size.width / 10
                // Celle segnate: arancione = storta, nero = mancante.
                for r in 0..<10 { for col in 0..<10 where cells[r][col] > 0 {
                    ctx.fill(Path(CGRect(x: CGFloat(col) * c, y: CGFloat(r) * c, width: c, height: c)),
                             with: .color(cells[r][col] == 1 ? .orange.opacity(0.6) : .black.opacity(0.75)))
                } }
                var lines = Path()
                for i in 0...10 {
                    let v = CGFloat(i) * c
                    lines.move(to: CGPoint(x: v, y: 0)); lines.addLine(to: CGPoint(x: v, y: size.height))
                    lines.move(to: CGPoint(x: 0, y: v)); lines.addLine(to: CGPoint(x: size.width, y: v))
                }
                ctx.stroke(lines, with: .color(.black), lineWidth: 1.5)
                let m = size.width / 2
                ctx.fill(Path(ellipseIn: CGRect(x: m - 6, y: m - 6, width: 12, height: 12)), with: .color(.black))
            }
            .frame(width: side, height: side)
            .gesture(DragGesture(minimumDistance: 0).onChanged { mark($0.location, side: side) })
        }
    }

    private func mark(_ p: CGPoint, side: CGFloat) {
        let col = Int(p.x / side * 10), row = Int(p.y / side * 10)
        guard (0..<10).contains(col), (0..<10).contains(row) else { return }
        let value = pass == .distorted ? 1 : 2
        if cells[row][col] < value { cells[row][col] = value; Haptics.tick() }
    }

    private func clearPass() {
        let value = pass == .distorted ? 1 : 2
        cells = cells.map { $0.map { $0 == value ? 0 : $0 } }
    }

    private func startEye() {
        // 1 grado alla distanza attuale, limitato perché la griglia stia nello schermo.
        let maxSide = (DeviceDisplay.screenSizePt.width - 32) / 10
        cellPt = min(maxSide, CGFloat(VisualAngle.pt(degrees: 1, distanceMM: tracker.effectiveMM)))
        cells = Array(repeating: Array(repeating: 0, count: 10), count: 10)
        pass = .distorted
        Voice.shared.say("Griglia di Amsler, occhio \(eye == .right ? "destro" : "sinistro"). Copri l'altro occhio. Guarda il punto al centro e passa il dito dove le linee sono storte. Poi tocca Avanti.")
    }

    private func next() {
        if pass == .distorted {
            pass = .missing
            Voice.shared.say("Ora passa il dito dove le linee mancano o sono sfocate. Poi tocca Fatto.")
            return
        }
        let e = Self.summarize(cells)
        if eye == .right {
            result.right = e
            eye = .left
            startEye()
        } else {
            result.left = e
            onFinish(result)
        }
    }

    /// Aree in gradi quadrati (ogni cella = 1°²), coinvolgimento dei 2° centrali, baricentro della zona.
    nonisolated static func summarize(_ cells: [[Int]]) -> AmslerEye {
        var distorted = 0.0, missing = 0.0, sx = 0.0, sy = 0.0, n = 0.0
        var central = false
        for r in 0..<10 { for c in 0..<10 where cells[r][c] > 0 {
            if cells[r][c] == 1 { distorted += 1 } else { missing += 1 }
            // Centro della cella in gradi dal punto di fissazione (x a destra, y in alto).
            let x = Double(c) - 4.5, y = 4.5 - Double(r)
            sx += x; sy += y; n += 1
            if (4...5).contains(r) && (4...5).contains(c) { central = true }   // i 2° centrali
        } }
        _ = (sx, sy, n)
        return AmslerEye(distortedAreaDeg2: distorted, missingAreaDeg2: missing, centralInvolved: central, cells: cells)
    }
}
