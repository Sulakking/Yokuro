import Combine
import Foundation

/// Réglages et état conservés d'un lancement à l'autre.
final class Store: ObservableObject {
    @Published var config: Config {
        didSet {
            if let data = try? JSONEncoder().encode(config) {
                UserDefaults.standard.set(data, forKey: "config")
            }
            if config.hour != oldValue.hour || config.minute != oldValue.minute {
                nextRun = Schedule.next(after: Date(), config: config)
            }
            if config.folderColor != oldValue.folderColor { onFolderColorChange?() }
            if config.launchAtLogin != oldValue.launchAtLogin {
                LoginItem.sync(enabled: config.launchAtLogin)
            }
        }
    }

    /// Appelé quand la couleur des dossiers change dans les réglages.
    var onFolderColorChange: (() -> Void)?

    /// Prochaine routine planifiée. Dans le passé au lancement : elle a été manquée et sera proposée aussitôt.
    var nextRun: Date {
        didSet { UserDefaults.standard.set(nextRun, forKey: "nextRun") }
    }

    init() {
        var saved = Config()
        if let data = UserDefaults.standard.data(forKey: "config"),
           let decoded = try? JSONDecoder().decode(Config.self, from: data) {
            saved = decoded
        }
        config = saved
        nextRun = (UserDefaults.standard.object(forKey: "nextRun") as? Date)
            ?? Schedule.next(after: Date(), config: saved)
    }

    /// Dernière catégorie choisie : elle s'applique quand la case « Renommer dans la même catégorie »
    /// est cochée et la pop-in fermée sans rien choisir.
    var lastPrefix: String? {
        get { UserDefaults.standard.string(forKey: "lastPrefix") }
        set { UserDefaults.standard.set(newValue, forKey: "lastPrefix") }
    }

    // Préfixes ajoutés à l'arrivée des fichiers, en attente du prochain rapport

    func appendRenameLog(_ lines: [String]) {
        let current = UserDefaults.standard.stringArray(forKey: "renameLog") ?? []
        UserDefaults.standard.set(current + lines, forKey: "renameLog")
    }

    func takeRenameLog() -> [String] {
        let current = UserDefaults.standard.stringArray(forKey: "renameLog") ?? []
        UserDefaults.standard.removeObject(forKey: "renameLog")
        return current
    }
}

// MARK: - Mode Concentration / Ne pas déranger

enum Focus {
    /// Fichier où macOS note les modes Concentration actifs. Non documenté par Apple,
    /// et lisible seulement si Yokuro a l'accès complet au disque.
    static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")
    }

    /// true ou false si l'état est lisible, nil sinon.
    static func isActive() -> Bool? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data),
              let json = object as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else { return nil }
        return entries.contains { entry in
            let records = entry["storeAssertionRecords"] as? [Any] ?? []
            return !records.isEmpty
        }
    }
}

// MARK: - Lancement à l'ouverture de session

enum LoginItem {
    static let label = "com.yokuro.app"

    static var plist: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// Installe ou retire l'agent qui ouvre Yokuro à chaque ouverture de session.
    static func sync(enabled: Bool) {
        // Hors de l'app installée (lancement depuis Xcode), on ne touche à rien.
        guard Bundle.main.bundlePath.hasSuffix(".app"), let executable = Bundle.main.executablePath else { return }
        let fm = FileManager.default
        guard enabled else {
            try? fm.removeItem(at: plist)
            return
        }
        let agent: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "AssociatedBundleIdentifiers": [label]
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: agent, format: .xml, options: 0),
              (try? Data(contentsOf: plist)) != data else { return } // déjà en place : on ne réécrit pas
        try? fm.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: plist)
    }
}
