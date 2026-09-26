import Testing
import Foundation
@testable import hackaton

@MainActor
struct ReadingTests {
    @Test func wordNormalizationAndLevenshtein() {
        #expect(ReadingAnalysis.words("Il panettiere sforna il pane caldo prima dell'alba") ==
                ["il", "panettiere", "sforna", "il", "pane", "caldo", "prima", "dell", "alba"])
        #expect(ReadingAnalysis.words("Ogni mattina bevo un caffè") == ["ogni", "mattina", "bevo", "un", "caffe"])
        let s = "Il treno per Milano parte alle nove dal primo binario"
        #expect(ReadingAnalysis.correctWords(sentence: s, transcript: s) == 10)
        // Una parola sbagliata e una mancante → 2 errori.
        #expect(ReadingAnalysis.correctWords(sentence: s, transcript: "il treno per Torino parte alle nove dal binario") == 8)
    }

    @Test func sentencesAreAboutSixtyCharacters() {
        #expect(ReadingSentences.all.count == 30)
        for s in ReadingSentences.all {
            #expect((45...70).contains(s.count), "\(s) → \(s.count)")
            #expect((8...12).contains(ReadingAnalysis.words(s).count), "\(s)")
        }
    }

    @Test func twoLimbFitFindsCriticalPrintSize() {
        // Piatto a 150 parole/min fino a 0,4 logMAR, poi in discesa.
        let sizes = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1]
        let samples = sizes.map { s -> ReadingSample in
            let wpm = s >= 0.4 ? 150 : 150 * pow(10, -3 * (0.4 - s))
            return ReadingSample(logMAR: s, seconds: 4, wordsCorrect: 10, wordsTotal: 10, wpm: wpm)
        }
        let fit = ReadingAnalysis.twoLimbFit(samples)!
        #expect(abs(fit.cps - 0.4) < 0.051)
        #expect(abs(fit.mrs - 150) < 5)
        #expect(ReadingAnalysis.readingAcuity(samples) == 0.1)
    }
}
