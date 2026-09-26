import ARKit
import Observation

/// Distanza occhi–schermo con ARKit (TrueDepth), circa 60 volte al secondo.
///
/// Filtro: media mobile esponenziale con costante di tempo `tau`.
/// α = 1 − e^(−Δt/τ): più il frame è lontano nel tempo, più pesa la nuova misura.
/// Toglie il tremolio della mano senza introdurre troppo ritardo.
@Observable
final class FaceDistanceTracker: NSObject, ARSessionDelegate {
    static let shared = FaceDistanceTracker()

    /// Distanza filtrata in cm (nil finché non si vede un viso).
    private(set) var distanceCM: Double?
    /// Ultima misura grezza in cm.
    private(set) var rawCM: Double?
    /// Il viso è tracciato adesso.
    private(set) var faceVisible = false
    /// Luce ambiente stimata da ARKit (lumen, ~1000 = stanza ben illuminata).
    private(set) var ambientIntensity: Double?
    private(set) var isRunning = false

    /// Distanza di riserva quando la TrueDepth non c'è (simulatore): 40 cm.
    static let fallbackCM = 40.0

    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    /// Distanza da usare nei calcoli: filtrata, o riserva.
    var effectiveCM: Double { distanceCM ?? Self.fallbackCM }
    var effectiveMM: Double { effectiveCM * 10 }

    @ObservationIgnored private let session = ARSession()
    @ObservationIgnored private var lastTimestamp: TimeInterval = 0
    @ObservationIgnored private var lastFaceTimestamp: TimeInterval = 0
    @ObservationIgnored private let tau = 0.15   // secondi
    @ObservationIgnored private var users = 0

    override private init() {
        super.init()
        session.delegate = self   // callback sulla coda principale (delegateQueue nil)
    }

    /// Avvia il tracciamento (conteggio dei "clienti": test e browser).
    func start() {
        users += 1
        guard !isRunning, Self.isSupported else { return }
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        config.maximumNumberOfTrackedFaces = 1
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
    }

    func stop() {
        users = max(0, users - 1)
        guard users == 0, isRunning else { return }
        session.pause()
        isRunning = false
        faceVisible = false
    }

    /// Riavvia dopo un'interruzione (app in background).
    func resumeIfNeeded() {
        guard users > 0, Self.isSupported else { return }
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        session.run(config)
        isRunning = true
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Estraggo solo numeri: non tengo riferimenti all'ARFrame.
        let timestamp = frame.timestamp
        let light = frame.lightEstimate.map { Double($0.ambientIntensity) }
        var meters: Double?
        if let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked {
            // Punto medio tra i due occhi, in coordinate mondo.
            let left = face.transform * face.leftEyeTransform.columns.3
            let right = face.transform * face.rightEyeTransform.columns.3
            let mid = (left + right) / 2
            let cam = frame.camera.transform.columns.3
            meters = Double(simd_distance(SIMD3(mid.x, mid.y, mid.z), SIMD3(cam.x, cam.y, cam.z)))
        }
        MainActor.assumeIsolated {
            self.ingest(meters: meters, timestamp: timestamp, light: light)
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        MainActor.assumeIsolated { self.resumeIfNeeded() }
    }

    private func ingest(meters: Double?, timestamp: TimeInterval, light: Double?) {
        if let light { ambientIntensity = light }
        let dt = lastTimestamp == 0 ? 1.0 / 60 : max(0.001, timestamp - lastTimestamp)
        lastTimestamp = timestamp
        if let meters, meters > 0.08, meters < 1.5 {
            let cm = meters * 100
            rawCM = cm
            lastFaceTimestamp = timestamp
            if !faceVisible { faceVisible = true }
            if let previous = distanceCM {
                let alpha = 1 - exp(-dt / tau)
                distanceCM = previous + alpha * (cm - previous)
            } else {
                distanceCM = cm
            }
        } else if faceVisible, timestamp - lastFaceTimestamp > 0.5 {
            faceVisible = false
        }
    }
}

/// Stato della distanza rispetto all'intervallo valido del test (25–60 cm).
enum DistanceStatus: Equatable {
    case ok, tooClose, tooFar, noFace

    /// Intervallo generale (campo visivo, Amsler, lettura).
    static let validRange = 25.0...60.0
    /// Fascia di test del contratto per acuità e contrasto: 35–45 cm.
    static let eTestRange = (ContractParameters.testDistanceMinMm / 10)...(ContractParameters.testDistanceMaxMm / 10)

    static func of(_ tracker: FaceDistanceTracker, range: ClosedRange<Double> = validRange) -> DistanceStatus {
        guard FaceDistanceTracker.isSupported else { return .ok }   // simulatore: distanza fissa
        guard tracker.faceVisible, let d = tracker.distanceCM else { return .noFace }
        if d < range.lowerBound { return .tooClose }
        if d > range.upperBound { return .tooFar }
        return .ok
    }

    var message: String {
        switch self {
        case .ok: "Distanza giusta"
        case .tooClose: "Allontana un po' il telefono"
        case .tooFar: "Avvicina un po' il telefono"
        case .noFace: "Guarda lo schermo, non vedo il tuo viso"
        }
    }
}
