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
                    Toggle("Mostra distanza", isOn: $app.showDistance)
                }

                Section("Profilo di campo visivo (demo)") {
                    Picker("Profilo", selection: $app.fieldPreset) {
                        ForEach(FieldPreset.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Toggle("Estensione post-MVP: nel Reader tocca il paragrafo per ascoltarlo (R9)", isOn: $app.postMVPExtensions)
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
                    Text("IpoView 1.0 · \(DeviceDisplay.modelName) · \(DeviceDisplay.ppi.map { "\(Int($0))" } ?? "modello non in tabella") ppi")
                        .font(.ipo(.footnote))
                        .foregroundStyle(app.appearance.secondary)
                        .onTapGesture {
                            versionTaps += 1
                            if versionTaps >= 5 { showDemo = true; Haptics.success() }
                        }
                    Text("Non serve un account, e i dati sulla tua vista non lasciano mai il telefono. Non è una diagnosi medica.")
                        .font(.ipo(.footnote))
                }
            }
            .font(.ipo(.body))
            // Testo dei pulsanti nel colore del testo (≥ 7:1); l'accento solo sugli interruttori.
            .tint(app.appearance.foreground)
            .toggleStyle(SwitchToggleStyle(tint: .ipoAccent))
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
        VStack(alignment: .leading) {
            Text("Acuità: \(p.acuity.logMAR.it()) logMAR")
            Slider(value: Binding(get: { p.acuity.logMAR }, set: { v in
                var np = p
                let w = (p.acuity.ci95[1] - p.acuity.ci95[0]) / 2
                np.acuity.logMAR = v
                np.acuity.ci95 = [v - w, v + w]
                np.acuity.whoCategory = WHOCategory.from(logMAR: v)
                ProfileBuilder.finalize(&np)
                app.profile = np
            }), in: -0.2...1.5, step: 0.05)
        }
        VStack(alignment: .leading) {
            Text("Contrasto: \(p.contrast.logCS.it()) log")
            Slider(value: Binding(get: { p.contrast.logCS }, set: { v in
                var np = p
                let w = (p.contrast.ci95[1] - p.contrast.ci95[0]) / 2
                np.contrast.logCS = v
                np.contrast.ci95 = [v - w, v + w]
                np.contrast.band = ContrastBand.from(logCS: v)
                ProfileBuilder.finalize(&np)
                app.profile = np
            }), in: 0.3...2.0, step: 0.05)
        }
        Stepper("Testo: \(p.textSizeOffset >= 0 ? "+" : "")\(p.textSizeOffset.it(1)) logMAR",
                value: Binding(get: { p.textSizeOffset }, set: { v in
                    var np = p
                    np.userAdjustments = UserAdjustments(textSizeOffsetLogMAR: (v * 10).rounded() / 10)
                    app.profile = np
                }), in: -0.5...0.8, step: 0.1)
    }
}

/// Profilo di esempio per provare il browser senza fare il test (valori misurati finti, source "measured").
enum SampleProfiles {
    static func lowAcuity() -> VisualProfile {
        var p = VisualProfile(
            device: ProfileBuilder.device,
            acuity: AcuityBlock(source: .measured, logMAR: 0.35, ci95: [0.28, 0.42], reliability: .reliable, flags: [],
                                whoCategory: .mild, trials: 24, displayLimitLogMAR: -0.02, censoredAtDisplayLimit: false),
            contrast: ContrastBlock(source: .measured, logCS: 1.35, ci95: [1.25, 1.45], reliability: .reliable, flags: [],
                                    band: .reduced, trials: 18, ceilingLogCS: 2.05, censoredAtCeiling: false))
        ProfileBuilder.finalize(&p)
        return p
    }
}
