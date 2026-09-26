import SwiftUI

@main struct MyApp: App {
    @State private var app = AppModel()

    init() {
        AppModel.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
    }
}

/// Radice: l'aspetto (dimensione del testo, tema, contrasto) segue il profilo.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        let look = app.appearance
        Group {
            switch app.route {
            case .welcome: WelcomeView()
            case .test: TestFlowView()
            case .results: ResultsView()
            case .browser: BrowserView()
            }
        }
        .dynamicTypeSize(look.typeSize)
        .preferredColorScheme(look.scheme)
        .animation(.easeInOut(duration: 0.3), value: app.route)
        .onAppear {
            // Contratto, sezione 14: verifica di nativeScale (cambia con lo Zoom schermo).
            let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
            print("[IpoView] modello \(DeviceDisplay.modelIdentifier) · nativeScale \(screen?.nativeScale ?? 0) · scale \(screen?.scale ?? 0) · schermo \(screen?.bounds.size ?? .zero) pt · pixel \(screen?.nativeBounds.size ?? .zero)")
        }
        .sheet(isPresented: $app.showSettings) {
            SettingsView().environment(app)
                .dynamicTypeSize(look.typeSize)
        }
    }
}
