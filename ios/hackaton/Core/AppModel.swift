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
        case .tunnel: "Visione a tunnel (8°)"
        case .centrale: "Perdita centrale"
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

    init() {
        profile = ProfileStore.load()
        demoMode = UserDefaults.standard.bool(forKey: "demoMode")
        fieldPreset = FieldPreset(rawValue: UserDefaults.standard.string(forKey: "fieldPreset") ?? "") ?? .nessuno
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
        #endif
    }

    /// Profilo usato dalle regole: quello misurato, con sopra l'eventuale campo visivo predefinito.
    var effectiveProfile: VisualProfile? {
        guard fieldPreset != .nessuno else { return profile }
        var p = profile ?? VisualProfile()
        PresetProfiles.apply(fieldPreset, to: &p)
        return p
    }

    var appearance: AppAppearance { AppAppearance(profile: effectiveProfile) }

    func startTest() {
        route = .test
    }

    func finishTest(with newProfile: VisualProfile) {
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
        guard let profile, profile.acuity != nil || profile.visualField != nil else {
            typeSize = .accessibility1; scheme = .light; highContrast = true
            return
        }
        switch profile.summary.level {
        case .normale: typeSize = profile.summary.normalVision ? .large : .xxLarge
        case .lieve: typeSize = .xxxLarge
        case .moderato: typeSize = .accessibility2
        case .grave: typeSize = .accessibility3
        }
        let theme = profile.light?.preferredTheme
        scheme = theme == .scuro ? .dark : .light
        highContrast = (RulesEngine.prudentContrast(profile) ?? 2) < 1.5 || profile.summary.level >= .moderato
    }

    var background: Color { scheme == .dark ? (highContrast ? .black : Color(white: 0.07)) : (highContrast ? .white : Color(red: 1, green: 0.985, blue: 0.95)) }
    var foreground: Color { scheme == .dark ? Color(red: 0.91, green: 0.9, blue: 0.89) : (highContrast ? .black : Color(white: 0.1)) }
    var secondary: Color { scheme == .dark ? Color(white: 0.75) : Color(white: 0.28) }
    var accent: Color { scheme == .dark ? Color(red: 1, green: 0.84, blue: 0.04) : Color(red: 0, green: 0.25, blue: 0.75) }
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
