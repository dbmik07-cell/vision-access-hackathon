import AVFoundation
import UIKit

/// Sintesi vocale in italiano: tutte le istruzioni vengono lette ad alta voce.
final class Voice {
    static let shared = Voice()

    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "voiceEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "voiceEnabled"); if !newValue { stop() } }
    }

    private let synth = AVSpeechSynthesizer()
    private lazy var voice: AVSpeechSynthesisVoice? = {
        let italian = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "it-IT" }
        return italian.max(by: { $0.quality.rawValue < $1.quality.rawValue })
            ?? AVSpeechSynthesisVoice(language: "it-IT")
    }()

    private init() {
        // Parla anche con l'interruttore silenzioso attivo.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Legge un'istruzione. `interrupt` interrompe la frase in corso.
    func say(_ text: String, interrupt: Bool = true) {
        guard enabled else { return }
        speak(text, rate: AVSpeechUtteranceDefaultSpeechRate, interrupt: interrupt)
    }

    /// Legge un testo alla velocità misurata (parole al minuto), per R9.
    func read(_ text: String, wpm: Double) {
        // Velocità di default di AVSpeech ≈ 180 parole/min: scalo in proporzione.
        let factor = Float(max(0.5, min(1.4, wpm / 180)))
        speak(text, rate: AVSpeechUtteranceDefaultSpeechRate * factor, interrupt: true)
    }

    func stop() { synth.stopSpeaking(at: .immediate) }

    var isSpeaking: Bool { synth.isSpeaking }

    private func speak(_ text: String, rate: Float, interrupt: Bool) {
        if interrupt, synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = rate
        synth.speak(utterance)
    }
}

enum Haptics {
    static func tick() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// Luminosità dello schermo fissa durante i test (SPEC 4, condizioni controllate).
enum ScreenBrightness {
    private static var saved: CGFloat?

    private static var screen: UIScreen? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
    }

    static func lock(_ value: CGFloat) {
        guard let screen else { return }
        if saved == nil { saved = screen.brightness }
        screen.brightness = value
    }

    static func restore() {
        guard let screen, let saved else { return }
        screen.brightness = saved
        Self.saved = nil
    }
}
