import SwiftUI

/// Impostazioni: rifare il test, correggere a mano i valori, modalità demo nascosta.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var versionTaps = 0
    @State private var showDemo = false
    @State private var voiceOn = Voice.shared.enabled

    var body: some View {
        @Bindable var app = app
        NavigationStack {
            Form {
                Section {
                    Button("Rifai il test", systemImage: "arrow.counterclockwise") {
                        dismiss(); app.startTest()
                    }
                    Button("Ecco come vedi", systemImage: "eye") { dismiss(); app.route = .results }
                    Toggle("Voce", isOn: $voiceOn).onChange(of: voiceOn) { _, v in Voice.shared.enabled = v }
                }

                Section("Profilo di campo visivo (demo)") {
                    Picker("Profilo", selection: $app.fieldPreset) {
                        ForEach(FieldPreset.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Correzioni manuali") {
                    if let p = app.profile {
                        manualEditors(p)
                    } else {
                        Text("Fai il test per avere un profilo, o scegli un profilo di esempio qui sopra.")
                    }
                }

                if showDemo || app.demoMode {
                    Section("Modalità demo") {
                        Toggle("Test accorciati (circa 3 minuti)", isOn: $app.demoMode)
                        Button("Profilo di esempio: acuità ridotta", systemImage: "person.crop.circle.badge.exclamationmark") {
                            app.profile = SampleProfiles.lowAcuity()
                        }
                        Button("Cancella profilo", systemImage: "trash", role: .destructive) {
                            dismiss(); app.resetAll()
                        }
                    }
                }

                Section {
                    Text("IpoView 1.0 · \(DeviceDisplay.modelName) · \(Int(DeviceDisplay.ppi)) ppi")
                        .font(.ipo(.footnote))
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            versionTaps += 1
                            if versionTaps >= 5 { showDemo = true; Haptics.success() }
                        }
                    Text("Non serve un account, e i dati sulla tua vista non lasciano mai il telefono. Non è una diagnosi medica.")
                        .font(.ipo(.footnote))
                }
            }
            .font(.ipo(.body))
            .navigationTitle("Impostazioni")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fatto", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func manualEditors(_ p: VisualProfile) -> some View {
        if let a = p.acuity {
            VStack(alignment: .leading) {
                Text("Acuità: \(a.logMAR.it()) logMAR")
                Slider(value: Binding(get: { a.logMAR }, set: { v in
                    var np = p
                    let w = (a.ci95[1] - a.ci95[0]) / 2
                    np.acuity?.logMAR = v
                    np.acuity?.ci95 = [v - w, v + w]
                    ProfileBuilder.finalize(&np)
                    app.profile = np
                }), in: -0.2...1.5, step: 0.05)
            }
        }
        if let c = p.contrast {
            VStack(alignment: .leading) {
                Text("Contrasto: \(c.logCS.it()) log")
                Slider(value: Binding(get: { c.logCS }, set: { v in
                    var np = p
                    let w = (c.ci95[1] - c.ci95[0]) / 2
                    np.contrast?.logCS = v
                    np.contrast?.ci95 = [v - w, v + w]
                    ProfileBuilder.finalize(&np)
                    app.profile = np
                }), in: 0.3...2.0, step: 0.05)
            }
        }
        Stepper("Testo: \(p.userAdjustments.textSizeOffsetLogMAR >= 0 ? "+" : "")\(p.userAdjustments.textSizeOffsetLogMAR.it(1)) logMAR",
                value: Binding(get: { p.userAdjustments.textSizeOffsetLogMAR }, set: { v in
                    var np = p
                    np.userAdjustments.textSizeOffsetLogMAR = (v * 10).rounded() / 10
                    app.profile = np
                }), in: -0.5...0.8, step: 0.1)
    }
}

/// Profilo di esempio per provare il browser senza fare il test.
enum SampleProfiles {
    static func lowAcuity() -> VisualProfile {
        var p = VisualProfile()
        p.acuity = AcuityResult(logMAR: 0.35, ci95: [0.28, 0.42], slope: 15, trials: 24, reliability: .affidabile,
                                flags: [], meanDistanceCM: 38, log: [])
        p.contrast = ContrastResult(logCS: 1.35, ci95: [1.25, 1.45], trials: 18, reliability: .affidabile,
                                    flags: [], letterLogMAR: 1.56, log: [])
        ProfileBuilder.finalize(&p)
        return p
    }
}
