import SwiftUI

/// Test della luce (SPEC 5.6): lo stesso paragrafo in 4 versioni, confrontate a coppie (6 confronti),
/// più una domanda sul fastidio della luce. Classifica con il modello di Bradley-Terry.
struct LightTestView: View {
    var onFinish: (LightResult) -> Void
    var onQuit: () -> Void

    struct Version: Hashable {
        let key: String
        let dark: Bool
        let bright: Bool
    }
    static let versions = [
        Version(key: "chiaro-alta", dark: false, bright: true),
        Version(key: "chiaro-bassa", dark: false, bright: false),
        Version(key: "scuro-alta", dark: true, bright: true),
        Version(key: "scuro-bassa", dark: true, bright: false),
    ]
    /// Tutte le 6 coppie, in ordine casuale e con lato casuale.
    @State private var pairs: [(Int, Int)] = {
        var p: [(Int, Int)] = []
        for i in 0..<4 { for j in (i + 1)..<4 { p.append(Bool.random() ? (i, j) : (j, i)) } }
        return p.shuffled()
    }()
    @State private var index = 0
    @State private var wins: [(winner: Int, loser: Int)] = []
    @State private var askingGlare = false

    init(onFinish: @escaping (LightResult) -> Void, onQuit: @escaping () -> Void) {
        self.onFinish = onFinish
        self.onQuit = onQuit
    }

    private let sample = "Il treno regionale per Firenze parte alle 10 e 25 dal binario 7. Ricordati di convalidare il biglietto prima di salire."

    var body: some View {
        VStack(spacing: 12) {
            if askingGlare {
                Spacer()
                Text("La luce forte, come il sole o uno schermo molto luminoso, ti dà fastidio?")
                    .font(.ipo(.title, bold: true)).multilineTextAlignment(.center)
                Spacer()
                BigButton(title: "Sì, mi dà fastidio", systemImage: "sun.max.trianglebadge.exclamationmark") { finish(glare: true) }
                BigButton(title: "No", systemImage: "hand.thumbsup", prominent: false) { finish(glare: false) }
            } else {
                Text("Quale leggi meglio? (\(index + 1) di 6)").font(.ipo(.title2, bold: true))
                let pair = pairs[index]
                option(pair.0, other: pair.1)
                option(pair.1, other: pair.0)
            }
        }
        .padding(16)
        .foregroundStyle(.black)
        .background(Color(white: 0.85).ignoresSafeArea())
        .dynamicTypeSize(.xLarge)
        .onAppear {
            Voice.shared.say("Ultimo test, la luce. Vedrai due versioni dello stesso testo. Tocca quella che leggi meglio.")
        }
    }

    private func option(_ i: Int, other: Int) -> some View {
        let v = Self.versions[i]
        return Button {
            wins.append((i, other))
            Haptics.tick()
            if index + 1 < pairs.count { index += 1 } else {
                askingGlare = true
                Voice.shared.say("La luce forte ti dà fastidio? Rispondi sì o no.")
            }
        } label: {
            Text(sample)
                .font(.ipo(.title3))
                .foregroundStyle(v.dark ? Color(red: 0.91, green: 0.9, blue: 0.89) : Color(white: 0.1))
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(v.dark ? Color(white: 0.07) : Color(red: 1, green: 0.985, blue: 0.95))
                // Luminosità bassa simulata scurendo tutta la versione.
                .overlay(Color.black.opacity(v.bright ? 0 : 0.45))
                .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Versione \(v.dark ? "scura" : "chiara"), luminosità \(v.bright ? "alta" : "bassa")")
    }

    private func finish(glare: Bool) {
        let scores = Self.bradleyTerry(n: 4, wins: wins)
        let best = scores.indices.max { scores[$0] < scores[$1] } ?? 0
        let v = Self.versions[best]
        var dict: [String: Double] = [:]
        for (i, s) in scores.enumerated() { dict[Self.versions[i].key] = s }
        onFinish(LightResult(preferredTheme: v.dark ? .scuro : .chiaro,
                             preferredBrightness: v.bright ? 0.85 : 0.5,
                             photophobia: glare || (v.dark && !v.bright),
                             scores: dict,
                             ambientLux: FaceDistanceTracker.shared.ambientIntensity))
    }

    /// Modello di Bradley-Terry: P(i batte j) = p_i / (p_i + p_j).
    /// Stima con l'algoritmo MM (Hunter, 2004): p_i ← W_i / Σ_j n_ij / (p_i + p_j),
    /// con mezza vittoria "virtuale" contro ogni altra versione perché nessun punteggio sia zero.
    nonisolated static func bradleyTerry(n: Int, wins: [(winner: Int, loser: Int)], iterations: Int = 200) -> [Double] {
        var w = Array(repeating: Array(repeating: 0.0, count: n), count: n)   // w[i][j] = vittorie di i su j
        for (a, b) in wins { w[a][b] += 1 }
        for i in 0..<n { for j in 0..<n where i != j { w[i][j] += 0.5 } }
        var p = Array(repeating: 1.0, count: n)
        for _ in 0..<iterations {
            var next = p
            for i in 0..<n {
                let wi = w[i].reduce(0, +)
                var den = 0.0
                for j in 0..<n where j != i { den += (w[i][j] + w[j][i]) / (p[i] + p[j]) }
                next[i] = wi / den
            }
            let s = next.reduce(0, +)
            p = next.map { $0 / s }
        }
        return p
    }
}
