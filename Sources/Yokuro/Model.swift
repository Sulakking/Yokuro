import Foundation

// MARK: - Projets et réglages

struct Project: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String     // nom du sous-dossier dans « Fichiers JSON »
    var prefix: String   // début des noms de fichiers : « BNP PF - … »
    var keywords = ""    // facultatifs, séparés par des virgules : préfixe ajouté sans demander
}

enum Routine: String, CaseIterable {
    // Suppressions
    case fonts, zips, duplicates, copies, markdown, installers, eps, noExtension
    // Une seule version conservée
    case html, json
    // Rangements
    case images, documents, videos, psd, aep, zipKeep
    // Ranger ou supprimer : l'un ou l'autre
    case audioKeep, audioDelete, svgKeep, svgDelete, screenshotKeep, screenshotDelete

    var label: String {
        switch self {
        case .fonts: return "Supprimer les dossiers et archives de polices (ttf, otf)"
        case .zips: return "Supprimer les .zip déjà dézippés"
        case .duplicates: return "Supprimer les doublons (1), (2)…"
        case .copies: return "Supprimer les fichiers « copie »"
        case .markdown: return "Supprimer les .md"
        case .installers: return "Supprimer les .dmg, .exe, .pkg"
        case .eps: return "Supprimer les .eps"
        case .noExtension: return "Supprimer les fichiers sans extension"
        case .html: return "Ne garder que la dernière version des .html"
        case .json: return "Ranger la dernière version des .json dans « Fichiers JSON »"
        case .images: return "Renommer et ranger les images dans « Images »"
        case .documents: return "Ranger pptx, docx, pdf, xlsx, txt, rtf dans « Documents de travail »"
        case .videos: return "Ranger mp4, mov, webm dans « Vidéos en cours »"
        case .psd: return "Ranger les .psd dans « PSD Photoshop »"
        case .aep: return "Ranger les .aep dans « AEP After Effect »"
        case .zipKeep: return "Ranger les .zip restants dans « Fichiers ZIP »"
        case .audioKeep: return "Ranger les audios dans « Audios en cours »"
        case .audioDelete: return "Supprimer les audios"
        case .svgKeep: return "Ranger les .svg dans « SVG Images »"
        case .svgDelete: return "Supprimer les .svg"
        case .screenshotKeep: return "Ranger les captures d’écran dans « Captures d’écran »"
        case .screenshotDelete: return "Supprimer les captures d’écran"
        }
    }

    /// Par défaut, audios, SVG et captures d'écran sont rangés, pas supprimés.
    var isOnByDefault: Bool { ![.audioDelete, .svgDelete, .screenshotDelete].contains(self) }

    /// Routine qui ne peut pas être active en même temps que celle-ci.
    var opposite: Routine? {
        switch self {
        case .audioKeep: return .audioDelete
        case .audioDelete: return .audioKeep
        case .svgKeep: return .svgDelete
        case .svgDelete: return .svgKeep
        case .screenshotKeep: return .screenshotDelete
        case .screenshotDelete: return .screenshotKeep
        default: return nil
        }
    }
}

struct Config: Codable {
    var hour = 17
    var minute = 0
    var retentionDays = 7
    var launchAtLogin = true
    var askOnArrival = true
    var renameOnArrival = true
    var respectFocus = true
    var stickyMinutes = 30          // durée de « Renommer avec la même catégorie »
    var stickyUnlimited = false     // « Renommer jusqu’à désactivation »
    var projects: [Project] = []
    var folderColor = "green"           // couleur prédéfinie (« green »…) ou personnalisée (« #4CC761 »)
    var routines: [String: Bool] = [:] // uniquement les choix qui s'écartent du réglage par défaut

    init() {}

    private enum LegacyKeys: String, CodingKey { case disabledRoutines }

    /// Décodage tolérant : un réglage ajouté dans une version suivante garde sa valeur par défaut
    /// au lieu de remettre tous les réglages à zéro.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hour = try c.decodeIfPresent(Int.self, forKey: .hour) ?? 17
        minute = try c.decodeIfPresent(Int.self, forKey: .minute) ?? 0
        retentionDays = try c.decodeIfPresent(Int.self, forKey: .retentionDays) ?? 7
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        askOnArrival = try c.decodeIfPresent(Bool.self, forKey: .askOnArrival) ?? true
        renameOnArrival = try c.decodeIfPresent(Bool.self, forKey: .renameOnArrival) ?? true
        respectFocus = try c.decodeIfPresent(Bool.self, forKey: .respectFocus) ?? true
        stickyMinutes = try c.decodeIfPresent(Int.self, forKey: .stickyMinutes) ?? 30
        stickyUnlimited = try c.decodeIfPresent(Bool.self, forKey: .stickyUnlimited) ?? false
        projects = try c.decodeIfPresent([Project].self, forKey: .projects) ?? []
        folderColor = try c.decodeIfPresent(String.self, forKey: .folderColor) ?? "green"
        routines = try c.decodeIfPresent([String: Bool].self, forKey: .routines) ?? [:]
        // Routines désactivées dans les réglages d'une version antérieure à la 0.8
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        for name in try legacy.decodeIfPresent([String].self, forKey: .disabledRoutines) ?? [] {
            routines[name] = false
        }
    }

    /// Fin de « Renommer avec la même catégorie » lancé maintenant ; nil : jusqu'à désactivation.
    func stickyEnd(from now: Date = Date()) -> Date? {
        stickyUnlimited ? nil : now.addingTimeInterval(Double(stickyMinutes) * 60)
    }

    func isOn(_ routine: Routine) -> Bool { routines[routine.rawValue] ?? routine.isOnByDefault }

    mutating func set(_ routine: Routine, _ on: Bool) {
        routines[routine.rawValue] = on
        if on, let opposite = routine.opposite { routines[opposite.rawValue] = false }
    }
}

// MARK: - Couleur des dossiers

/// Une couleur des tags du Finder. `label` est son numéro dans le Finder.
struct FolderColor: Identifiable {
    let id: String
    let name: String
    let label: Int
    let red, green, blue: Double
}

enum FolderColors {
    static let presets = [
        FolderColor(id: "red", name: "Rouge", label: 6, red: 1.00, green: 0.27, blue: 0.23),
        FolderColor(id: "orange", name: "Orange", label: 7, red: 1.00, green: 0.62, blue: 0.04),
        FolderColor(id: "yellow", name: "Jaune", label: 5, red: 1.00, green: 0.84, blue: 0.04),
        FolderColor(id: "green", name: "Vert", label: 2, red: 0.30, green: 0.78, blue: 0.38),
        FolderColor(id: "blue", name: "Bleu", label: 4, red: 0.04, green: 0.52, blue: 1.00),
        FolderColor(id: "purple", name: "Violet", label: 3, red: 0.75, green: 0.35, blue: 0.95),
        FolderColor(id: "gray", name: "Gris", label: 1, red: 0.56, green: 0.56, blue: 0.58)
    ]

    /// Composantes d'une couleur prédéfinie ou « #RRGGBB » ; vert si la valeur est illisible.
    static func rgb(_ value: String) -> (red: Double, green: Double, blue: Double) {
        if let preset = presets.first(where: { $0.id == value }) { return (preset.red, preset.green, preset.blue) }
        let digits = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard digits.count == 6, let number = UInt32(digits, radix: 16) else { return rgb("green") }
        return (Double((number >> 16) & 0xFF) / 255, Double((number >> 8) & 0xFF) / 255, Double(number & 0xFF) / 255)
    }

    static func hex(red: Double, green: Double, blue: Double) -> String {
        let byte = { (value: Double) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    /// Tag du Finder pour les fichiers : la couleur prédéfinie, ou la plus proche d'une couleur personnalisée.
    static func tagNumber(_ value: String) -> Int {
        let color = rgb(value)
        let nearest = presets.min { a, b in
            func distance(_ p: FolderColor) -> Double {
                pow(p.red - color.red, 2) + pow(p.green - color.green, 2) + pow(p.blue - color.blue, 2)
            }
            return distance(a) < distance(b)
        }
        return presets.first(where: { $0.id == value })?.label ?? nearest?.label ?? 2
    }
}

// MARK: - Chemins

enum Paths {
    /// Dossier surveillé. Variable uniquement pour pouvoir le remplacer dans les tests.
    static var downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    static var yokuro: URL { downloads.appendingPathComponent("Yokuro") }
    static var temp: URL { yokuro.appendingPathComponent("Fichiers temporaires") }
    static var reports: URL { yokuro.appendingPathComponent("Rapport") }

    // Dossiers de rangement, créés dans Téléchargements ou dans le dossier trié ponctuellement
    static let images = "Images"
    static let documents = "Documents de travail"
    static let videos = "Vidéos en cours"
    static let json = "Fichiers JSON"
    static let audio = "Audios en cours"
    static let svg = "SVG Images"
    static let psd = "PSD Photoshop"
    static let aep = "AEP After Effect"
    static let zip = "Fichiers ZIP"
    static let screenshots = "Captures d’écran"

    /// Dossiers gérés par Yokuro, jamais analysés.
    static let managed: Set<String> = ["Yokuro", images, documents, videos, json, audio, svg, psd, aep, zip, screenshots]
}

// MARK: - Dates

enum Fmt {
    static func make(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = format
        return formatter
    }
    static let day = make("yyyy-MM-dd")
    static let stamp = make("yyyy-MM-dd HH'h'mm")
    static let monthDay = make("MMdd")
    static let time = make("HH:mm")
    static let long = make("d MMMM yyyy 'à' HH:mm")

    static let hourMinute = make("HH'h'mm")
    static let dayMonth = make("d MMMM")

    /// « aujourd’hui à 17h00 », « demain à 17h00 », « le 3 décembre à 17h00 ».
    static func routine(_ date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.isDateInToday(date) ? "aujourd’hui"
            : calendar.isDateInTomorrow(date) ? "demain" : "le \(dayMonth.string(from: date))"
        return "\(day) à \(hourMinute.string(from: date))"
    }
}

enum Schedule {
    /// Prochaine occurrence de l'heure de routine après `date`.
    static func next(after date: Date, config: Config) -> Date {
        var time = DateComponents()
        time.hour = config.hour
        time.minute = config.minute
        return Calendar.current.nextDate(after: date, matching: time, matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(86_400)
    }

    /// Heure de routine du lendemain, même si celle d'aujourd'hui n'est pas encore passée.
    static func tomorrow(config: Config) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        return next(after: tomorrow.addingTimeInterval(-1), config: config)
    }
}
