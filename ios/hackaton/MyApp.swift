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
        .sheet(isPresented: $app.showSettings) {
            SettingsView().environment(app)
                .dynamicTypeSize(look.typeSize)
        }
    }
}
