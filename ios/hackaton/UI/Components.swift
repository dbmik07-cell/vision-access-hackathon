import SwiftUI

/// E di Snellen/"tumbling E": griglia 5 × 5, tratto = 1/5 dell'altezza.
struct TumblingE: Shape {
    func path(in rect: CGRect) -> Path {
        let u = min(rect.width, rect.height) / 5
        let o = CGPoint(x: rect.midX - 2.5 * u, y: rect.midY - 2.5 * u)
        var p = Path()
        p.addRect(CGRect(x: o.x, y: o.y, width: u, height: 5 * u))             // asta verticale
        p.addRect(CGRect(x: o.x, y: o.y, width: 5 * u, height: u))             // braccio alto
        p.addRect(CGRect(x: o.x, y: o.y + 2 * u, width: 5 * u, height: u))     // braccio centrale
        p.addRect(CGRect(x: o.x, y: o.y + 4 * u, width: 5 * u, height: u))     // braccio basso
        return p
    }
}

/// Intervallo di confidenza che si restringe, su una scala orizzontale.
struct ConfidenceBar: View {
    var estimate: Double
    var ci: ClosedRange<Double>
    var range: ClosedRange<Double>
    var boundaries: [Double] = []
    var lowIsGood = true

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x: (Double) -> CGFloat = { v in
                CGFloat((min(max(v, range.lowerBound), range.upperBound) - range.lowerBound)
                        / (range.upperBound - range.lowerBound)) * w
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.88)).frame(height: 14)
                ForEach(boundaries, id: \.self) { b in
                    Rectangle().fill(Color(white: 0.55)).frame(width: 2, height: 22).offset(x: x(b) - 1)
                }
                Capsule().fill(Color(red: 0.1, green: 0.35, blue: 0.85).opacity(0.55))
                    .frame(width: max(6, x(ci.upperBound) - x(ci.lowerBound)), height: 14)
                    .offset(x: x(ci.lowerBound))
                Circle().fill(Color(red: 0, green: 0.2, blue: 0.6))
                    .frame(width: 22, height: 22)
                    .offset(x: x(estimate) - 11)
            }
            .frame(height: 22)
            .animation(.easeOut(duration: 0.35), value: ci)
            .animation(.easeOut(duration: 0.35), value: estimate)
        }
        .frame(height: 22)
        .accessibilityHidden(true)
    }
}

/// Indicatore della distanza del viso.
struct DistanceBadge: View {
    var tracker = FaceDistanceTracker.shared

    var body: some View {
        let status = DistanceStatus.of(tracker)
        HStack(spacing: 6) {
            Image(systemName: status == .ok ? "face.smiling" : "exclamationmark.triangle.fill")
            if FaceDistanceTracker.isSupported {
                Text(tracker.faceVisible ? "\(Int(tracker.effectiveCM.rounded())) cm" : "– cm")
                    .monospacedDigit()
            } else {
                Text("40 cm (simulata)")
            }
        }
        .font(.ipo(.headline, bold: true))
        .foregroundStyle(status == .ok ? Color(red: 0, green: 0.4, blue: 0.1) : Color(red: 0.7, green: 0.1, blue: 0))
        .padding(.horizontal, 12).padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
}

/// Superficie dei gesti dei test: swipe con un dito (direzione) e tocco con due dita ("non vedo").
struct GestureSurface: UIViewRepresentable {
    var onSwipe: (Direction) -> Void
    var onTwoFingerTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 1
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.numberOfTouchesRequired = 2
        v.addGestureRecognizer(pan)
        v.addGestureRecognizer(tap)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.parent = self }
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject {
        var parent: GestureSurface
        init(parent: GestureSurface) { self.parent = parent }
        @objc func pan(_ g: UIPanGestureRecognizer) {
            guard g.state == .ended else { return }
            let t = g.translation(in: g.view)
            if let d = Direction.of(translation: CGSize(width: t.x, height: t.y)) { parent.onSwipe(d) }
        }
        @objc func tap(_ g: UITapGestureRecognizer) {
            if g.state == .ended { parent.onTwoFingerTap() }
        }
    }
}

/// Indicatore di avanzamento grande e semplice.
struct BigProgressBar: View {
    var value: Double
    var label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.ipo(.title3, bold: true)).foregroundStyle(.black)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.85))
                    Capsule().fill(Color(red: 0, green: 0.3, blue: 0.8))
                        .frame(width: max(18, geo.size.width * min(1, max(0, value))))
                }
            }
            .frame(height: 18)
            .animation(.easeOut(duration: 0.3), value: value)
        }
        .dynamicTypeSize(.xLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

/// Pulsante grande e ad alto contrasto.
struct BigButton: View {
    var title: String
    var systemImage: String?
    var prominent = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.ipo(.title2, bold: true))
            .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(prominent ? AnyButtonStyle(.glassProminent) : AnyButtonStyle(.glass))
        .controlSize(.extraLarge)
    }
}

struct AnyButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: PrimitiveButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

extension Double {
    /// Numero con la virgola decimale italiana.
    func it(_ digits: Int = 2) -> String {
        String(format: "%.\(digits)f", self).replacingOccurrences(of: ".", with: ",")
    }
}
