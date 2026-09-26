import SwiftUI

/// Prima schermata: un solo pulsante grande "Avvia test". Una voce spiega cosa fare.
struct WelcomeView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let look = app.appearance
        VStack(spacing: 20) {
            HStack {
                Text("IpoView").font(.ipo(.title, bold: true))
                Spacer()
                Button { app.showSettings = true } label: {
                    Image(systemName: "gearshape.fill").font(.title2).frame(width: 52, height: 52)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Impostazioni")
            }
            Button {
                Voice.shared.stop()
                app.startTest()
            } label: {
                VStack(spacing: 24) {
                    Image(systemName: "eye.fill").font(.system(size: 96, weight: .bold))
                    Text("Avvia test").font(.ipo(.largeTitle, bold: true))
                    Text("circa \(app.demoMode ? "3" : "6") minuti").font(.ipo(.title3))
                }
                .foregroundStyle(look.scheme == .dark ? Color.black : Color.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.roundedRectangle(radius: 44))
            .tint(look.accent)
            .accessibilityHint("Inizia il test della vista")

            if app.profile != nil || app.fieldPreset != .nessuno {
                BigButton(title: "Vai al browser", systemImage: "safari", prominent: false) { app.route = .browser }
            }
        }
        .padding(20)
        .foregroundStyle(look.foreground)
        .background(look.background.ignoresSafeArea())
        .onAppear {
            Voice.shared.say("Benvenuto in IpoView. Tocca il pulsante grande al centro dello schermo per iniziare il test della vista. Dura pochi minuti, e poi ogni pagina web si adatterà ai tuoi occhi.")
        }
    }
}
