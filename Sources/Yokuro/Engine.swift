import Foundation

enum ActionKind { case delete, move, rename }

/// Une action proposée dans la review. Rien n'est touché tant qu'elle n'est pas validée.
struct PlannedAction: Identifiable {
    let id = UUID()
    let source: URL
    let kind: ActionKind
    var folder: URL? = nil // dossier d'arrivée d'un déplacement ou d'un renommage
    var newName: String
    var reason = ""        // pourquoi le fichier est supprimé ou renommé
    var enabled = true

    var detail: String {
        kind == .move ? "Vers « \(Engine.display(folder)) »" : reason
    }
}

struct ExecutionResult {
    var deleted: [String] = []
    var moved: [String] = []
    var renamed: [String] = []
    var errors: [String] = []
}

struct ArrivalResult {
    var renamed: [String] = []     // préfixes ajoutés d'office (mot-clé reconnu)
    var known = Set<UInt64>()      // fichiers déjà vus dans Téléchargements
    var ask: [String] = []         // nouveaux fichiers dont le projet est à demander
}

struct Item {
    let url: URL
    let name: String
    let base: String   // nom sans extension
    let ext: String    // extension en minuscules, vide pour un dossier
    let isDir: Bool
    let size: Int
    let modified: Date
    let created: Date
    let added: Date    // arrivée dans le dossier
    let id: UInt64     // identité du fichier : ne change pas quand il est renommé
}

/// Toute la logique de tri. Aucune interface ici : uniquement des fichiers.
enum Engine {
    static let fm = FileManager.default

    static let inProgress: Set<String> = ["crdownload", "download", "part", "partial", "opdownload", "tmp"]
    static let audio: Set<String> = ["mp3", "wav", "m4a", "aac", "aif", "aiff", "flac", "ogg", "wma"]
    static let images: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tif", "tiff", "bmp", "avif"]
    static let documents: Set<String> = ["pptx", "docx", "pdf", "xlsx", "txt", "rtf"]
    static let videos: Set<String> = ["mp4", "mov", "webm"]
    static let installers: Set<String> = ["dmg", "exe", "pkg"]
    static let fonts: Set<String> = ["ttf", "otf"]
    /// Ce qui accompagne les polices dans un dossier d'installation : licences, notices, formats web.
    static let fontCompanions: Set<String> = ["", "txt", "md", "pdf", "rtf", "html", "htm", "url", "webloc",
                                              "css", "woff", "woff2", "eot"]

    /// Routine de suppression qui concerne ce type de fichier, et la raison affichée dans la review.
    static func deletion(for item: Item) -> (routine: Routine, reason: String)? {
        if item.isDir { return nil }
        if item.ext.isEmpty { return (.noExtension, "Fichier sans extension") }
        if isCopy(item.base) { return (.copies, "Copie") }
        if isScreenshot(item.name) { return (.screenshotDelete, "Capture d’écran") }
        if item.ext == "md" { return (.markdown, "Fichier .md") }
        if item.ext == "eps" { return (.eps, "Fichier .eps") }
        if item.ext == "svg" { return (.svgDelete, "Fichier .svg") }
        if installers.contains(item.ext) { return (.installers, "Fichier d'installation") }
        if audio.contains(item.ext) { return (.audioDelete, "Fichier audio") }
        return nil
    }

    /// « logo copie », « logo copie 2 » : duplication faite dans le Finder.
    static func isCopy(_ base: String) -> Bool {
        normalize(base).split(separator: " ").contains("copie")
    }

    static func isScreenshot(_ name: String) -> Bool {
        let lowered = name.precomposedStringWithCanonicalMapping.lowercased()
        return ["capture d’écran", "capture d'écran", "capture d’ecran", "capture d'ecran", "screenshot", "screen shot"]
            .contains { lowered.contains($0) }
    }

    /// Vrai si la routine supprime ce fichier : inutile alors de demander son projet.
    static func isDeleted(_ item: Item, config: Config) -> Bool {
        deletion(for: item).map { config.isOn($0.routine) } ?? false
    }

    // MARK: Lecture d'un dossier

    /// Premier niveau du dossier, sans les fichiers cachés, les téléchargements en cours
    /// et les dossiers gérés par Yokuro.
    static func scan(in folder: URL = Paths.downloads) -> [Item] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
                                         .creationDateKey, .addedToDirectoryDateKey]
        guard let urls = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys),
                                                     options: [.skipsHiddenFiles]) else { return [] }
        var items: [Item] = []
        for url in urls {
            let name = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            // « Icon\r » : fichier invisible qui porte l'icône personnalisée d'un dossier
            if Paths.managed.contains(name) || inProgress.contains(ext) || name == "Icon\r" { continue }
            let values = try? url.resourceValues(forKeys: keys)
            let isDir = values?.isDirectory ?? false
            let modified = values?.contentModificationDate ?? Date()
            let created = values?.creationDate ?? modified
            let inode = (try? fm.attributesOfItem(atPath: url.path))?[.systemFileNumber] as? NSNumber
            items.append(Item(
                url: url,
                name: name,
                base: isDir ? name : url.deletingPathExtension().lastPathComponent,
                ext: isDir ? "" : ext,
                isDir: isDir,
                size: values?.fileSize ?? 0,
                modified: modified,
                created: created,
                added: values?.addedToDirectoryDate ?? created,
                id: inode?.uint64Value ?? 0
            ))
        }
        return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func canRead(_ folder: URL) -> Bool {
        (try? fm.contentsOfDirectory(atPath: folder.path)) != nil
    }

    // MARK: Outils

    static func match(_ pattern: String, _ string: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let text = string as NSString
        guard let found = regex.firstMatch(in: string, range: NSRange(location: 0, length: text.length)) else {
            return nil
        }
        return (0..<found.numberOfRanges).map {
            found.range(at: $0).location == NSNotFound ? "" : text.substring(with: found.range(at: $0))
        }
    }

    /// Chemin court pour l'affichage : relatif à Téléchargements si possible, sinon avec « ~ ».
    static func display(_ url: URL?) -> String {
        guard let url = url else { return "" }
        let downloads = Paths.downloads.path + "/"
        if url.path.hasPrefix(downloads) { return String(url.path.dropFirst(downloads.count)) }
        return (url.path as NSString).abbreviatingWithTildeInPath
    }

    /// Nom utilisable pour un fichier ou un dossier.
    static func safeName(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Projets

    static func hasPrefix(_ name: String, of project: Project) -> Bool {
        !project.prefix.isEmpty && name.hasPrefix(project.prefix + " - ")
    }

    static func isPrefixed(_ name: String, config: Config) -> Bool {
        config.projects.contains { hasPrefix(name, of: $0) }
    }

    static func stripPrefix(_ name: String, config: Config) -> String {
        guard let project = config.projects.first(where: { hasPrefix(name, of: $0) }) else { return name }
        return String(name.dropFirst(project.prefix.count + 3))
    }

    static func normalize(_ string: String) -> String {
        var text = string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        for separator in ["-", "_", ".", "(", ")"] { text = text.replacingOccurrences(of: separator, with: " ") }
        return text
    }

    /// Projets dont un mot-clé apparaît dans le nom.
    static func keywordMatches(_ name: String, config: Config) -> [Project] {
        let normalized = normalize(name)
        let words = Set(normalized.split(separator: " ").map(String.init))
        let compact = normalized.replacingOccurrences(of: " ", with: "")
        return config.projects.filter { project in
            guard !project.prefix.isEmpty else { return false }
            let keywords = project.keywords.split(separator: ",")
                .map { normalize(String($0)).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return keywords.contains { keyword in
                // Un mot-clé court doit être un mot entier, pour ne pas le trouver au milieu d'un autre.
                if !keyword.contains(" ") && keyword.count <= 4 { return words.contains(keyword) }
                return normalized.contains(keyword) || compact.contains(keyword.replacingOccurrences(of: " ", with: ""))
            }
        }
    }

    /// Projet d'un fichier : par son préfixe, sinon par mot-clé s'il n'y a aucun doute.
    static func project(for name: String, config: Config) -> Project? {
        if let project = config.projects.first(where: { hasPrefix(name, of: $0) }) { return project }
        let found = keywordMatches(name, config: config)
        return found.count == 1 ? found[0] : nil
    }

    // MARK: Versions

    /// « site-v3 » et « site-v3 (1) » donnent (« site », 3) ; « site » donne (« site », 0) :
    /// un fichier sans numéro est le plus ancien de sa série.
    /// Un numéro de version a 1 à 3 chiffres : une année ou une date n'en est pas un.
    static func versionKey(_ base: String) -> (stem: String, version: Int) {
        var name = base
        if let copy = match(#"^(.*) \(\d+\)$"#, name) { name = copy[1] } // copie « (1) » du navigateur
        if let found = match(#"^(.*?)(?:[\s_\-\.]+[vV]?)?(?<!\d)(\d{1,3})$"#, name), let version = Int(found[2]) {
            let stem = found[1].trimmingCharacters(in: .whitespaces)
            if !stem.isEmpty { return (stem.lowercased(), version) }
        }
        return (name.lowercased(), 0)
    }

    /// Dans chaque série, tout sauf la version la plus récente : (ancienne, dernière).
    /// À numéro égal, le fichier créé le plus tard l'emporte.
    static func olderVersions(_ items: [Item]) -> [(older: Item, latest: Item)] {
        var series: [String: [(item: Item, version: Int)]] = [:]
        for item in items {
            let key = versionKey(item.base)
            series[key.stem, default: []].append((item, key.version))
        }
        var result: [(older: Item, latest: Item)] = []
        for members in series.values where members.count > 1 {
            let sorted = members.sorted { ($0.version, $0.item.created) < ($1.version, $1.item.created) }
            guard let latest = sorted.last else { continue }
            for member in sorted.dropLast() { result.append((member.item, latest.item)) }
        }
        return result.sorted { $0.older.url.path < $1.older.url.path }
    }

    // MARK: Polices et archives

    /// Vrai si la liste ne contient que des polices et ce qui les accompagne (licence, notice…).
    /// Un dossier de projet qui contient des polices parmi d'autres fichiers n'est donc jamais concerné.
    static func isFontSet(_ paths: [String]) -> Bool {
        var fontCount = 0
        for path in paths where !path.hasSuffix("/") && !path.hasPrefix("__MACOSX/") {
            let name = (path as NSString).lastPathComponent
            if name.hasPrefix(".") { continue }
            let ext = (name as NSString).pathExtension.lowercased()
            if fonts.contains(ext) {
                fontCount += 1
            } else if !fontCompanions.contains(ext) {
                return false
            }
        }
        return fontCount > 0
    }

    /// Contenu d'une archive, un chemin par ligne.
    static func zipEntries(_ url: URL) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z1", url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
    }

    /// Fichiers d'un dossier, sous-dossiers compris. Vide au-delà de 3 000 : ce n'est pas un dossier de polices.
    static func folderEntries(_ url: URL) -> [String] {
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey],
                                             options: [.skipsHiddenFiles]) else { return [] }
        var names: [String] = []
        for case let file as URL in enumerator {
            let isFile = (try? file.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
            if isFile { names.append(file.lastPathComponent) }
            if names.count > 3000 { return [] }
        }
        return names
    }

    /// Ce qu'Archive Utility crée en dézippant : l'élément unique du premier niveau s'il n'y en a qu'un,
    /// sinon un dossier au nom de l'archive.
    static func unzippedName(of zip: Item, entries: [String]) -> String {
        let tops = Set(entries.compactMap { $0.split(separator: "/").first.map(String.init) }
            .filter { $0 != "__MACOSX" && !$0.hasPrefix(".") })
        if tops.count == 1, let only = tops.first { return only }
        return zip.base
    }

    // MARK: Images

    /// Capture d'écran, IMG_1234, suite de chiffres… : un nom qui ne dit rien du contenu.
    static func isGenericImageName(_ base: String) -> Bool {
        var name = base.precomposedStringWithCanonicalMapping.lowercased()
        if match(#"^[0-9a-f\-_]{12,}$"#, name) != nil { return true }
        let generic = ["capture d’écran", "capture d'écran", "screenshot", "screen shot", "image", "img",
                       "dsc", "pxl", "photo", "unnamed", "download", "téléchargement", "untitled",
                       "sans titre", "pasted", " à ", " at "]
        for word in generic { name = name.replacingOccurrences(of: word, with: "") }
        return name.filter { $0.isLetter }.count < 3
    }

    // MARK: Plan de la routine

    /// Liste ce que la routine ferait, sans rien toucher.
    /// - `root` : dossier trié (Téléchargements, ou un dossier choisi pour un tri ponctuel).
    /// - `destination` : où créer les dossiers de rangement (par défaut dans `root`).
    /// - `prefix` : préfixe projet à ajouter à tous les fichiers conservés (tri ponctuel uniquement).
    static func plan(config: Config, root: URL = Paths.downloads, destination: URL? = nil,
                     prefix: String? = nil) -> [PlannedAction] {
        let items = scan(in: root)
        let files = items.filter { !$0.isDir }
        let base = destination ?? root
        var actions: [PlannedAction] = []
        var taken = Set<String>() // chemins déjà traités : une seule action par fichier

        func add(_ item: Item, _ kind: ActionKind, _ routine: Routine, _ reason: String = "",
                 to folder: URL? = nil, name: String? = nil) {
            guard config.isOn(routine), taken.insert(item.url.path).inserted else { return }
            actions.append(PlannedAction(source: item.url, kind: kind, folder: folder,
                                         newName: name ?? item.name, reason: reason))
        }
        // Range le fichier dans `folder`, sauf si le même y est déjà : c'est alors un doublon.
        func stow(_ item: Item, _ routine: Routine, in folder: URL, as name: String? = nil) {
            if fm.contentsEqual(atPath: item.url.path, andPath: folder.appendingPathComponent(item.name).path) {
                add(item, .delete, routine, "Déjà rangé dans « \(display(folder)) »")
            } else {
                add(item, .move, routine, to: folder, name: name)
            }
        }
        func free(_ extensions: Set<String>) -> [Item] {
            files.filter { extensions.contains($0.ext) && !taken.contains($0.url.path) }
        }

        // 1. Polices : dossiers qui ne contiennent que des polices et leurs notices
        if config.isOn(.fonts) {
            for item in items where item.isDir && isFontSet(folderEntries(item.url)) {
                add(item, .delete, .fonts, "Dossier de polices")
            }
        }

        // 2. Archives : polices, ou déjà dézippées (ce qui en est sorti est dans le dossier)
        if config.isOn(.fonts) || config.isOn(.zips) {
            let present = Set(items.map { stripPrefix($0.name, config: config).lowercased() })
            for item in files where item.ext == "zip" {
                let entries = zipEntries(item.url)
                if config.isOn(.fonts) && isFontSet(entries) {
                    add(item, .delete, .fonts, "Archive de polices")
                    continue
                }
                let outputs = [unzippedName(of: item, entries: entries), item.base]
                if outputs.contains(where: { present.contains(stripPrefix($0, config: config).lowercased()) }) {
                    add(item, .delete, .zips, "Archive déjà dézippée")
                }
            }
        }

        // 3. Doublons : « nom (1).ext » strictement identique à « nom.ext ».
        //    Si le contenu diffère, ce n'est pas un doublon : le fichier suit les autres règles.
        if config.isOn(.duplicates) {
            let byName = Dictionary(files.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
            for item in files {
                guard let copy = match(#"^(.*) \(\d+\)$"#, item.base) else { continue }
                let ext = item.url.pathExtension
                let originalName = ext.isEmpty ? copy[1] : "\(copy[1]).\(ext)"
                guard let original = byName[originalName.lowercased()],
                      fm.contentsEqual(atPath: item.url.path, andPath: original.url.path) else { continue }
                add(item, .delete, .duplicates, "Doublon de « \(original.name) »")
            }
        }

        // 4. Suppressions par type. Routine désactivée : le fichier suit les règles de rangement.
        for item in files {
            if let deletion = deletion(for: item) { add(item, .delete, deletion.routine, deletion.reason) }
        }

        // 5. HTML : on ne garde que la dernière version, sur place
        for pair in olderVersions(free(["html", "htm"])) {
            add(pair.older, .delete, .html, "Version antérieure de « \(pair.latest.name) »")
        }

        // 6. JSON : la dernière version est rangée par projet ; les versions antérieures sont supprimées,
        //    y compris celles déjà rangées
        let forcedProject = config.projects.first { !$0.prefix.isEmpty && $0.prefix == prefix }
        let jsonRoot = base.appendingPathComponent(Paths.json)
        let jsonsByFolder = Dictionary(grouping: free(["json"])) { item -> URL in
            guard let project = project(for: item.name, config: config) ?? forcedProject,
                  !safeName(project.name).isEmpty else { return jsonRoot }
            return jsonRoot.appendingPathComponent(safeName(project.name))
        }
        for (folder, arriving) in jsonsByFolder.sorted(by: { $0.key.path < $1.key.path }) {
            for item in arriving where fm.contentsEqual(atPath: item.url.path,
                                                        andPath: folder.appendingPathComponent(item.name).path) {
                add(item, .delete, .json, "Déjà rangé dans « \(display(folder)) »")
            }
            let fresh = arriving.filter { !taken.contains($0.url.path) }
            let stored = scan(in: folder).filter { $0.ext == "json" }
            let storedPaths = Set(stored.map { $0.url.path })
            for pair in olderVersions(fresh + stored) {
                var reason = "Version antérieure de « \(pair.latest.name) »"
                if storedPaths.contains(pair.older.url.path) {
                    reason += ", dans « \(display(folder)) »"
                } else if storedPaths.contains(pair.latest.url.path) {
                    reason += ", déjà rangé dans « \(display(folder)) »"
                }
                add(pair.older, .delete, .json, reason)
            }
            for item in fresh { add(item, .move, .json, to: folder) }
        }

        // 7. Rangement par type. Une image au nom générique devient « Image 1126 - 01 » : mois, jour, numéro.
        let imagesFolder = base.appendingPathComponent(Paths.images)
        var imageCounters: [String: Int] = [:]
        func nextImageNumber(_ day: String) -> Int {
            if imageCounters[day] == nil {
                // On reprend la numérotation du jour là où le dossier Images s'est arrêté.
                let existing = (try? fm.contentsOfDirectory(atPath: imagesFolder.path)) ?? []
                imageCounters[day] = existing.compactMap { match("Image \(day) - (\\d+)", $0).flatMap { Int($0[1]) } }.max() ?? 0
            }
            let next = (imageCounters[day] ?? 0) + 1
            imageCounters[day] = next
            return next
        }
        let shelves: [(extensions: Set<String>, routine: Routine, folder: String)] = [
            (documents, .documents, Paths.documents), (videos, .videos, Paths.videos),
            (audio, .audioKeep, Paths.audio), (["svg"], .svgKeep, Paths.svg), (["psd"], .psd, Paths.psd),
            (["aep"], .aep, Paths.aep), (["zip"], .zipKeep, Paths.zip) // les .zip qui restent une fois le tri fait
        ]
        for item in files {
            if isScreenshot(item.name) && config.isOn(.screenshotKeep) {
                stow(item, .screenshotKeep, in: base.appendingPathComponent(Paths.screenshots))
            } else if images.contains(item.ext) {
                var name = item.name
                let bare = stripPrefix(item.base, config: config)
                if isGenericImageName(bare) {
                    let head = String(item.base.dropLast(bare.count)) // « BNP PF - », ou rien
                    let day = Fmt.monthDay.string(from: item.created)
                    let number = String(format: "%02d", nextImageNumber(day))
                    name = "\(head)Image \(day) - \(number).\(item.url.pathExtension)"
                }
                stow(item, .images, in: imagesFolder, as: name)
            } else if let shelf = shelves.first(where: { $0.extensions.contains(item.ext) }) {
                stow(item, shelf.routine, in: base.appendingPathComponent(shelf.folder))
            }
        }

        // 8. Préfixe projet demandé (tri ponctuel) : fichiers déplacés, et fichiers qui restent sur place
        if let prefix = prefix, !prefix.isEmpty {
            for index in actions.indices where actions[index].kind == .move
                && !isPrefixed(actions[index].newName, config: config) {
                actions[index].newName = "\(prefix) - \(actions[index].newName)"
            }
            for item in files where !taken.contains(item.url.path) && !isPrefixed(item.name, config: config) {
                actions.append(PlannedAction(source: item.url, kind: .rename, folder: root,
                                             newName: "\(prefix) - \(item.name)",
                                             reason: "Ajout du préfixe \(prefix)"))
            }
        }

        return actions
    }

    // MARK: Exécution

    /// Premier nom libre dans le dossier : « nom », puis « nom 2 », « nom 3 »…
    static func uniqueURL(in folder: URL, name: String) -> URL {
        var url = folder.appendingPathComponent(name)
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var index = 2
        while fm.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)")
            index += 1
        }
        return url
    }

    /// Nom saisi dans la review, nettoyé ; l'extension d'origine est remise si elle a été effacée.
    static func cleanName(_ proposed: String, original: URL) -> String {
        var name = safeName(proposed)
        if name.isEmpty { return original.lastPathComponent }
        let ext = original.pathExtension
        if !ext.isEmpty && (name as NSString).pathExtension.isEmpty { name += "." + ext }
        return name
    }

    /// Applique les actions cochées. Une suppression est un déplacement dans Fichiers temporaires, daté du jour.
    static func execute(_ actions: [PlannedAction]) -> ExecutionResult {
        var result = ExecutionResult()
        var folders = Set<URL>() // dossiers de Yokuro qui ont reçu quelque chose : pastille verte eux aussi
        let todayTemp = Paths.temp.appendingPathComponent(Fmt.day.string(from: Date()))
        for action in actions where action.enabled {
            let oldName = action.source.lastPathComponent
            guard fm.fileExists(atPath: action.source.path) else {
                result.errors.append("\(oldName) : introuvable, déplacé ou renommé entre-temps")
                continue
            }
            do {
                switch action.kind {
                case .delete:
                    try fm.createDirectory(at: todayTemp, withIntermediateDirectories: true)
                    try fm.moveItem(at: action.source, to: uniqueURL(in: todayTemp, name: oldName))
                    result.deleted.append("\(oldName) (\(action.reason))")
                    folders.insert(Paths.yokuro)
                case .move, .rename:
                    guard let folder = action.folder else { continue }
                    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                    let target = uniqueURL(in: folder, name: cleanName(action.newName, original: action.source))
                    try fm.moveItem(at: action.source, to: target)
                    if action.kind == .rename {
                        result.renamed.append("\(oldName) > \(target.lastPathComponent)")
                    } else {
                        result.moved.append("\(oldName) > \(display(target))")
                        mark(target)
                        folders.insert(folder)
                        // Sous-dossier de projet : « Fichiers JSON » lui-même est aussi un dossier de Yokuro.
                        let parent = folder.deletingLastPathComponent()
                        if Paths.managed.contains(parent.lastPathComponent) { folders.insert(parent) }
                    }
                }
            } catch {
                result.errors.append("\(oldName) : \(error.localizedDescription)")
            }
        }
        folders.forEach(mark)
        return result
    }

    /// Envoie à la corbeille les dossiers datés de Fichiers temporaires qui ont dépassé le délai de conservation.
    static func purge(retentionDays: Int) -> [String] {
        guard let folders = try? fm.contentsOfDirectory(at: Paths.temp, includingPropertiesForKeys: nil,
                                                        options: [.skipsHiddenFiles]) else { return [] }
        let today = Calendar.current.startOfDay(for: Date())
        var lines: [String] = []
        for folder in folders {
            guard let date = Fmt.day.date(from: String(folder.lastPathComponent.prefix(10))),
                  let age = Calendar.current.dateComponents([.day], from: date, to: today).day,
                  age >= retentionDays else { continue }
            let count = (try? fm.contentsOfDirectory(atPath: folder.path).count) ?? 0
            do {
                try fm.trashItem(at: folder, resultingItemURL: nil)
                lines.append("Suppressions du \(folder.lastPathComponent) (\(count == 1 ? "1 élément" : "\(count) éléments"))")
            } catch {
                lines.append("Échec pour \(folder.lastPathComponent) : \(error.localizedDescription)")
            }
        }
        return lines
    }

    /// Couleur sur les dossiers de Yokuro déjà présents dans Téléchargements et sur ce qu'ils contiennent.
    static func markManagedFolders() {
        for name in Paths.managed {
            let folder = Paths.downloads.appendingPathComponent(name)
            guard fm.fileExists(atPath: folder.path) else { continue }
            mark(folder)
            if name == "Yokuro" { continue } // rapports et fichiers temporaires : seul le dossier est marqué
            for item in scan(in: folder) {
                mark(item.url)
                // Sous-dossiers de projet de « Fichiers JSON »
                if item.isDir && name == Paths.json { scan(in: item.url).forEach { mark($0.url) } }
            }
        }
    }

    /// Noms des tags de couleur du Finder dans la langue du Mac, par numéro (2 : « Vert »).
    /// Renseignés par l'app au lancement.
    static var labelNames: [String] = []
    /// Numéro du tag posé sur les fichiers rangés : celui de la couleur choisie dans les réglages.
    static var tagNumber = 2

    /// Teinte l'icône d'un dossier. Fournie par l'app (AppKit) ; absente dans les tests.
    static var colorFolder: ((URL) -> Void)?

    /// Tag de couleur du Finder sur un fichier, et icône teintée pour un dossier. Le tag est écrit
    /// tel que le Finder l'écrit lui-même : son nom suivi de son numéro. Après un changement de couleur,
    /// l'ancien tag de couleur est remplacé ; les tags sans couleur sont conservés.
    static func mark(_ url: URL) {
        #if os(macOS)
        let key = "com.apple.metadata:_kMDItemUserTags"
        let names = labelNames.count == 8 ? labelNames : ["", "Gris", "Vert", "Violet", "Bleu", "Jaune", "Rouge", "Orange"]
        let number = (1...7).contains(tagNumber) ? tagNumber : 2
        let entry = names[number] + "\n\(number)"

        var tags: [String] = []
        let size = getxattr(url.path, key, nil, 0, 0, 0)
        if size > 0 {
            var stored = Data(count: size)
            let read = stored.withUnsafeMutableBytes { getxattr(url.path, key, $0.baseAddress, size, 0, 0) }
            if read == size,
               let list = try? PropertyListSerialization.propertyList(from: stored, options: [], format: nil) as? [String] {
                tags = list
            }
        }
        var isFolder: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isFolder), isFolder.boolValue { colorFolder?(url) }
        // Tags de couleur, et poses sans couleur des 0.10 et 0.11 : ceux que Yokuro remplace.
        let colors = Set((1...7).map { names[$0] + "\n\($0)" } + names.filter { !$0.isEmpty } + ["Green"])
        if tags.contains(entry) && !tags.contains(where: { $0 != entry && colors.contains($0) }) { return }

        // L'ancienne étiquette de couleur d'abord : le Finder la tient à jour avec le tag.
        var labelled = url
        var values = URLResourceValues()
        values.labelNumber = number
        try? labelled.setResourceValues(values)

        // Puis le tag de la couleur choisie, à la place des autres tags de couleur.
        tags.removeAll { colors.contains($0) }
        tags.append(entry)
        guard let data = try? PropertyListSerialization.data(fromPropertyList: tags, format: .binary, options: 0) else {
            return
        }
        _ = data.withUnsafeBytes { setxattr(url.path, key, $0.baseAddress, data.count, 0, 0) }
        #endif
    }

    /// Reprend le dossier « Temporaire » des versions précédentes sous son nouveau nom.
    static func adoptOldTemp() {
        let old = Paths.yokuro.appendingPathComponent("Temporaire")
        guard let children = try? fm.contentsOfDirectory(at: old, includingPropertiesForKeys: nil) else { return }
        try? fm.createDirectory(at: Paths.temp, withIntermediateDirectories: true)
        for child in children {
            try? fm.moveItem(at: child, to: uniqueURL(in: Paths.temp, name: child.lastPathComponent))
        }
        try? fm.removeItem(at: old)
    }

    // MARK: Arrivée des fichiers

    /// Repère les fichiers qui viennent d'arriver dans Téléchargements : préfixe ceux qu'un mot-clé
    /// rattache à un projet, et liste ceux dont le projet est à demander.
    /// `known` vaut nil au premier passage : tout ce qui est déjà là est considéré comme vu.
    static func processArrivals(config: Config, known: Set<UInt64>?) -> ArrivalResult {
        var result = ArrivalResult()
        for item in scan() {
            // Fichier encore en cours d'écriture : on y reviendra au passage suivant.
            let notReady = Date().timeIntervalSince(item.modified) < 1
                || (!item.isDir && item.size == 0)
                || fm.fileExists(atPath: item.url.path + ".part")
            if notReady {
                if known?.contains(item.id) == true { result.known.insert(item.id) }
                continue
            }
            let isNew = known.map { !$0.contains(item.id) } ?? false
            result.known.insert(item.id)
            if isPrefixed(item.name, config: config) { continue }

            let found = keywordMatches(item.name, config: config)
            if config.renameOnArrival, found.count == 1 {
                let target = uniqueURL(in: Paths.downloads, name: "\(found[0].prefix) - \(item.name)")
                if (try? fm.moveItem(at: item.url, to: target)) != nil {
                    result.renamed.append("\(item.name) > \(target.lastPathComponent)")
                    continue
                }
            }
            if isNew && config.askOnArrival && !item.isDir && !isDeleted(item, config: config) {
                result.ask.append(item.name)
            }
        }
        return result
    }

    /// Fichiers sans préfixe arrivés dans Téléchargements depuis moins de `minutes`.
    static func recentUnassigned(config: Config, minutes: Double = 30) -> [String] {
        let limit = Date().addingTimeInterval(-minutes * 60)
        return scan().filter {
            !$0.isDir && $0.added >= limit && !isDeleted($0, config: config) && !isPrefixed($0.name, config: config)
        }.map { $0.name }
    }

    /// Renomme un fichier de Téléchargements depuis la pop-in. L'extension est remise si elle a été effacée.
    static func rename(name: String, to proposed: String) -> String? {
        let source = Paths.downloads.appendingPathComponent(name)
        let wanted = cleanName(proposed, original: source)
        guard wanted != name, fm.fileExists(atPath: source.path) else { return nil }
        let target = uniqueURL(in: Paths.downloads, name: wanted)
        guard (try? fm.moveItem(at: source, to: target)) != nil else { return nil }
        return target.lastPathComponent
    }

    /// Ajoute le préfixe choisi dans la pop-in. Renvoie le nouveau nom.
    static func assign(name: String, prefix: String) -> String? {
        let source = Paths.downloads.appendingPathComponent(name)
        guard fm.fileExists(atPath: source.path) else { return nil }
        if name.hasPrefix(prefix + " - ") { return name } // déjà préfixé à la main
        let target = uniqueURL(in: Paths.downloads, name: "\(prefix) - \(name)")
        guard (try? fm.moveItem(at: source, to: target)) != nil else { return nil }
        return target.lastPathComponent
    }

    // MARK: Rapport

    /// Écrit le rapport daté dans Yokuro > Rapport. Rien n'est écrit s'il ne s'est rien passé.
    static func writeReport(result: ExecutionResult, renames: [String], purged: [String], retentionDays: Int,
                            folder: URL? = nil) {
        let sections: [(String, [String])] = [
            ("Supprimés, gardés \(retentionDays) jours dans Yokuro > Fichiers temporaires", result.deleted),
            ("Déplacés", result.moved),
            ("Renommés", result.renamed + renames),
            ("Envoyés à la corbeille", purged),
            ("Erreurs", result.errors)
        ]
        guard sections.contains(where: { !$0.1.isEmpty }) else { return }
        let now = Date()
        var text = "Yokuro : rapport du \(Fmt.long.string(from: now))\n"
        if let folder = folder { text += "Tri ponctuel du dossier : \(folder.path)\n" }
        for (title, lines) in sections where !lines.isEmpty {
            text += "\n\(title) (\(lines.count))\n"
            for line in lines { text += "  - \(line)\n" }
        }
        try? fm.createDirectory(at: Paths.reports, withIntermediateDirectories: true)
        let url = uniqueURL(in: Paths.reports, name: "Rapport \(Fmt.stamp.string(from: now)).txt")
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
