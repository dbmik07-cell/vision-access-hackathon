import Foundation
import Speech
import AVFoundation
import Observation

/// Frasi italiane semplici, circa 60 caratteri e 10 parole ciascuna (ispirate a MNREAD).
nonisolated enum ReadingSentences {
    static let all = [
        "La mamma prepara il pranzo per tutta la famiglia ogni domenica",
        "Il cane del vicino abbaia sempre quando passa il postino",
        "Domani mattina andiamo al mercato a comprare frutta fresca",
        "Mio fratello gioca a calcio con gli amici dopo la scuola",
        "La nonna racconta storie bellissime ai suoi nipoti la sera",
        "Il treno per Milano parte alle nove dal primo binario",
        "In estate andiamo al mare e facciamo lunghe passeggiate",
        "Il gatto dorme tranquillo sul divano vicino alla finestra",
        "Ogni mattina bevo un caffè caldo prima di uscire di casa",
        "La biblioteca del paese apre alle dieci e chiude alle sei",
        "Il medico dice che camminare ogni giorno fa molto bene",
        "Mia sorella ha comprato un vestito rosso per la festa",
        "Il panettiere sforna il pane caldo prima dell'alba",
        "Abbiamo piantato pomodori e basilico nel piccolo orto",
        "Il sole tramonta dietro le colline e il cielo diventa rosa",
        "La radio suona una canzone che mi piace molto ascoltare",
        "Il bambino ha disegnato una casa con un grande albero verde",
        "Stasera guardiamo un film insieme e mangiamo la pizza",
        "Il postino porta le lettere tutti i giorni tranne la domenica",
        "La farmacia in piazza resta aperta anche il sabato sera",
        "Il fiume scorre lento sotto il vecchio ponte di pietra",
        "Mio padre legge il giornale seduto in poltrona dopo cena",
        "Le rondini tornano ogni primavera sotto il tetto della casa",
        "Il fruttivendolo vende mele pere e arance molto dolci",
        "La maestra ha portato la classe a visitare il museo",
        "Quando piove prendo sempre l'ombrello e gli stivali",
        "Il mio amico abita in una casa gialla vicino alla chiesa",
        "La zia ha preparato una torta al cioccolato per il compleanno",
        "Il vento forte ha fatto cadere le foglie degli alberi",
        "Il pullman per il centro passa ogni quindici minuti",
    ]
}

/// Analisi della lettura: parole corrette, velocità, curva a due tratti.
nonisolated enum ReadingAnalysis {
    /// Parole normalizzate: minuscole, senza punteggiatura né accenti.
    static func words(_ text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .replacingOccurrences(of: "'", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Distanza di Levenshtein sulle parole: numero minimo di parole da inserire, togliere o cambiare.
    static func wordLevenshtein(_ a: [String], _ b: [String]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[b.count]
    }

    /// Parole corrette = parole della frase − errori (distanza di Levenshtein), mai sotto zero.
    static func correctWords(sentence: String, transcript: String) -> Int {
        let s = words(sentence), t = words(transcript)
        return max(0, s.count - wordLevenshtein(s, t))
    }

    /// Curva a due tratti (approssimazione del metodo di Cheung e altri, 2008):
    /// log10(velocità) piatto per le dimensioni grandi (s ≥ b) e in discesa lineare sotto b.
    /// Provo ogni punto di rottura b tra le dimensioni misurate e tengo quello con l'errore quadratico minimo.
    /// Restituisce (dimensione critica di stampa b, velocità massima 10^plateau).
    static func twoLimbFit(_ samples: [ReadingSample]) -> (cps: Double, mrs: Double)? {
        let pts = samples.filter { $0.wpm > 0 }.map { ($0.logMAR, log10($0.wpm)) }
        guard pts.count >= 2 else { return nil }
        var best: (sse: Double, b: Double, plateau: Double)?
        for b in Set(pts.map(\.0)).sorted() {
            let flat = pts.filter { $0.0 >= b - 1e-9 }
            let plateau = flat.map(\.1).reduce(0, +) / Double(flat.count)
            // Tratto in discesa: y = plateau − k·(b − s), pendenza k ai minimi quadrati (k ≥ 0).
            let steep = pts.filter { $0.0 < b - 1e-9 }
            let num = steep.reduce(0) { $0 + (plateau - $1.1) * (b - $1.0) }
            let den = steep.reduce(0) { $0 + (b - $1.0) * (b - $1.0) }
            let k = den > 0 ? max(0, num / den) : 0
            let sse = flat.reduce(0) { $0 + pow($1.1 - plateau, 2) }
                + steep.reduce(0) { $0 + pow($1.1 - (plateau - k * (b - $1.0)), 2) }
            // A parità di errore preferisco la dimensione più piccola (plateau più lungo).
            if best == nil || sse < best!.sse - 1e-6 || (abs(sse - best!.sse) <= 1e-6 && b < best!.b) {
                best = (sse, b, plateau)
            }
        }
        guard let best else { return nil }
        return (best.b, pow(10, best.plateau))
    }

    /// Acuità di lettura: la dimensione più piccola letta con almeno metà delle parole giuste.
    static func readingAcuity(_ samples: [ReadingSample]) -> Double? {
        samples.filter { $0.wordsTotal > 0 && Double($0.wordsCorrect) / Double($0.wordsTotal) >= 0.5 }.map(\.logMAR).min()
    }
}

/// Riconoscimento vocale in italiano sul telefono (senza rete).
@Observable
final class SpeechListener {
    private(set) var transcript = ""
    private(set) var available = false
    private(set) var onDevice = false

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "it-IT"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored var onUpdate: ((String) -> Void)?

    /// Chiede i permessi di microfono e riconoscimento vocale.
    func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        onDevice = recognizer?.supportsOnDeviceRecognition ?? false
        available = speech && mic && (recognizer?.isAvailable ?? false) && onDevice
        return available
    }

    func start() {
        guard available, let recognizer else { return }
        stop()
        transcript = ""
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
        try? session.setActive(true)
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true   // niente rete, niente server
        request = req
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in req.append(buffer) }
        engine.prepare()
        try? engine.start()
        task = recognizer.recognitionTask(with: req) { [weak self] result, _ in
            guard let text = result?.bestTranscription.formattedString else { return }
            DispatchQueue.main.async {
                self?.transcript = text
                self?.onUpdate?(text)
            }
        }
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }
}
