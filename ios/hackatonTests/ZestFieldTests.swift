import Testing
import Foundation
@testable import hackaton

@MainActor
struct ZestFieldTests {
    @Test func neighborWeights() {
        let a = ZestPoint(id: 0, x: 3, y: 3), b = ZestPoint(id: 1, x: 9, y: 3), c = ZestPoint(id: 2, x: 21, y: 9)
        // d = 6° = σ → W = e^(−1/2)
        #expect(abs(FieldMath.weight(a, b) - exp(-0.5)) < 1e-9)
        #expect(FieldMath.weight(a, c) < 0.01)
    }

    @Test func zestConvergesPerPoint() {
        var rng = SeededRNG(state: 11)
        let model = FieldModel()
        for trueS in [2.0, 8.0] {
            var p = ZestPoint(id: 0, x: 9, y: 9)
            while !p.finished {
                let x = p.nextDifficulty
                let seen = Double.random(in: 0..<1, using: &rng) < model.pSeen(difficulty: x, sensitivity: trueS)
                p.presentations += 1
                p.update(difficulty: x, seen: seen, model: model)
            }
            #expect(p.presentations <= 4)
            #expect(abs(p.mean - trueS) < 3.5)
        }
    }

    @Test func blindPointPullsNeighborsDown() {
        var s = FieldSession(eye: .right, demo: false)
        let i = s.points.firstIndex { $0.x == 9 && $0.y == 3 }!
        let j = s.points.firstIndex { $0.x == 15 && $0.y == 3 }!
        let before = s.points[j].mean
        // Il punto i non viene mai visto: finisce con sensibilità bassa e sposta il priore del vicino j.
        s.recordScreening(i, seen: false)
        for _ in 0..<4 { s.recordZest(i, difficulty: 1, seen: false) }
        #expect(s.points[i].done)
        #expect(s.points[j].mean < before - 1)
        #expect(s.points[j].queued)
    }

    @Test func tunnelClassification() {
        var s = FieldSession(eye: .right, demo: false)
        for i in s.points.indices {
            let e = hypot(s.points[i].x, s.points[i].y)
            s.recordScreening(i, seen: e < 10)
            if e >= 10 { for _ in 0..<4 { s.recordZest(i, difficulty: 1, seen: false) } }
        }
        s.setBlindSpot(unseen: [(15, -1.5)])
        let r = s.result()
        #expect(r.pattern == .tunnel)
        #expect(r.fieldRadiusDeg < 20)
    }

    @Test func fieldGrayLevelsAreDistinct() {
        let grays = (1...10).map { FieldTestRunner.gray(difficulty: Double($0)) }
        #expect(Set(grays).count == 10)
        #expect(grays.first == 255)
        #expect(grays.last! > FieldTestRunner.backgroundGray)
    }
}
