import SwiftUI
import Observation
import CoreText

/// Profilo di campo visivo predefinito, selezionabile per la demo (MVP punto 5).
enum FieldPreset: String, CaseIterable, Identifiable, Codable {
    case nessuno, tunnel, centrale
    var id: String { rawValue }
    var label: String {
        switch self {
        case .nessuno: "Nessuno (usa i test)"
        case .tunnel: "Visione a tunnel (5°)"
        case .centrale: "Macchia centrale"
        }
    }
}

enum Route: Equatable {
    case welcome, test, results, browser
}

/// Stato globale dell'app. Il profilo resta sul telefono (file JSON in Application Support).
@Observable
final class AppModel {
    var route: Route = .welcome
    var showSettings = false

    /// Profilo misurato con i test.
    var profile: VisualProfile? {
        didSet { ProfileStore.save(profile) }
    }

    var demoMode: Bool {
        didSet { UserDefaults.standard.set(demoMode, forKey: "demoMode") }
    }

    var fieldPreset: FieldPreset {
        didSet { UserDefaults.standard.set(fieldPreset.rawValue, forKey: "fieldPreset") }
    }

    /// Estensioni post-MVP sopra il piano del contratto: un paragrafo alla volta (R5) e lettura grande (R9).
    var postMVPExtensions: Bool {
        didSet { UserDefaults.standard.set(postMVPExtensions, forKey: "postMVPExtensions") }
    }

    /// Indicatore della distanza nella barra del browser (sempre visibile in modalità demo).
    var showDistance: Bool {
        didSet { UserDefaults.standard.set(showDistance, forKey: "showDistance") }
    }

    /// Controlli di affidabilità avanzata dell'ultimo test (fuori dal profilo del contratto).
    var diagnostics: [String] {
        didSet { UserDefaults.standard.set(diagnostics, forKey: "diagnostics") }
    }

    init() {
        profile = ProfileStore.load()
        demoMode = UserDefaults.standard.bool(forKey: "demoMode")
        fieldPreset = FieldPreset(rawValue: UserDefaults.standard.string(forKey: "fieldPreset") ?? "") ?? .nessuno
        postMVPExtensions = UserDefaults.standard.object(forKey: "postMVPExtensions") as? Bool ?? true
        diagnostics = UserDefaults.standard.stringArray(forKey: "diagnostics") ?? []
        showDistance = UserDefaults.standard.bool(forKey: "showDistance")
        route = profile == nil ? .welcome : .browser
        #if DEBUG
        // Argomenti di avvio per le prove nel simulatore.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-sampleProfile") { profile = SampleProfiles.lowAcuity(); route = .browser }
        if args.contains("-results") { route = .results }
        if args.contains("-noProfile") { profile = nil; route = .browser }
        if let i = args.firstIndex(of: "-preset"), i + 1 < args.count, let p = FieldPreset(rawValue: args[i + 1]) {
            fieldPreset = p; route = .browser
        }
        if args.contains("-welcome") { route = .welcome }
        if args.contains("-showDistance") { showDistance = true }
        #endif
    }

    /// Profilo usato dalle regole: quello misurato, con sopra l'eventuale campo visivo predefinito.
    var effectiveProfile: VisualProfile? {
        guard fieldPreset != .nessuno else { return profile }
        var p = profile ?? PresetProfiles.baseline(device: ProfileBuilder.device)
        PresetProfiles.apply(fieldPreset, to: &p)
        return p
    }

    var appearance: AppAppearance { AppAppearance(profile: effectiveProfile) }

    func startTest() {
        route = .test
    }

    func finishTest(with newProfile: VisualProfile, diagnostics: [String] = []) {
        self.diagnostics = diagnostics
        var p = newProfile
        // Conservo le correzioni manuali della persona.
        if let old = profile { p.userAdjustments = old.userAdjustments }
        profile = p
        route = .results
    }

    func resetAll() {
        profile = nil
        fieldPreset = .nessuno
        route = .welcome
    }

    static func registerFonts() {
        for name in ["AtkinsonHyperlegible-Regular", "AtkinsonHyperlegible-Bold"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}

enum ProfileStore {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("visual-profile.json")
    }

    static func save(_ profile: VisualProfile?) {
        guard let profile else { try? FileManager.default.removeItem(at: url); return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(profile) { try? data.write(to: url, options: .atomic) }
    }

    static func load() -> VisualProfile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(VisualProfile.self, from: data)
    }

    /// JSON del profilo, da mostrare o condividere.
    static func json(_ profile: VisualProfile) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? String(data: encoder.encode(profile), encoding: .utf8)) ?? ""
    }
}

// MARK: - Aspetto dell'app che si adatta al profilo

/// Senza profilo l'app parte leggibile: testo grande, contrasto alto.
/// Dopo il test dimensione, tema e contrasto seguono il profilo (SPEC 3).
struct AppAppearance: Equatable {
    var typeSize: DynamicTypeSize
    var scheme: ColorScheme
    var highContrast: Bool

    init(profile: VisualProfile?) {
        guard let profile else {
            typeSize = .accessibility1; scheme = .light; highContrast = true
            return
        }
        switch profile.acuity.whoCategory {
        case .none: typeSize = profile.summary.normalVision ? .large : .xxLarge
        case .mild: typeSize = .xxxLarge
        case .moderate: typeSize = .accessibility2
        case .severe, .blindness: typeSize = .accessibility3
        }
        let dark = profile.light?.preferredTheme == .dark || (profile.light?.preferredTheme == nil && profile.light?.photophobia == true)
        scheme = dark ? .dark : .light
        highContrast = RulesEngine.prudentContrast(profile.contrast) < 1.5 || profile.acuity.whoCategory >= .moderate
    }

    var background: Color { scheme == .dark ? (highContrast ? .black : Color(white: 0.07)) : (highContrast ? .white : Color(red: 1, green: 0.985, blue: 0.95)) }
    var foreground: Color { scheme == .dark ? Color(red: 0.91, green: 0.9, blue: 0.89) : (highContrast ? .black : Color(white: 0.1)) }
    var secondary: Color { scheme == .dark ? Color(white: 0.75) : Color(white: 0.28) }
    /// Accento #FF8A4C, sempre con testo #141414 sopra (7,9:1).
    var accent: Color { .ipoAccent }
    var onAccent: Color { .ipoOnAccent }
    /// Fondo delle schede: leggermente staccato dal fondo della pagina iniziale.
    var card: Color { scheme == .dark ? Color(white: 0.12) : .white }
    var startBackground: Color { scheme == .dark ? background : Color(white: 0.955) }
    var hairline: Color { foreground.opacity(scheme == .dark ? 0.22 : 0.16) }
}

extension Color {
    static let ipoAccent = Color(red: 1, green: 0x8A / 255, blue: 0x4C / 255)
    static let ipoOnAccent = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255)
}

extension Font {
    /// Atkinson Hyperlegible, scalata con Dynamic Type.
    static func ipo(_ style: Font.TextStyle, bold: Bool = false) -> Font {
        let size: CGFloat = switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .subheadline: 15
        case .footnote: 13
        case .caption, .caption2: 12
        default: 17
        }
        return .custom(bold ? "AtkinsonHyperlegible-Bold" : "AtkinsonHyperlegible-Regular", size: size, relativeTo: style)
    }
}
