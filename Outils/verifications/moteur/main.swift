import Foundation

let fm = FileManager.default
var failures = 0
var checks = 0

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    checks += 1
    if !condition {
        failures += 1
        print("  ECHEC ligne \(line) : \(message)")
    }
}

func section(_ title: String) { print("\n== \(title)") }

// MARK: Outils de mise en place

let sandbox = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("yk-\(UUID().uuidString)")

func reset() -> URL {
    try? fm.removeItem(at: sandbox)
    let downloads = sandbox.appendingPathComponent("Downloads")
    try! fm.createDirectory(at: downloads, withIntermediateDirectories: true)
    Paths.downloads = downloads
    return downloads
}

/// Crée un fichier. `age` : ancienneté en secondes (date de modification, donc de création sous Linux).
@discardableResult
func touch(_ path: String, _ content: String = "x", age: TimeInterval = 3600, in root: URL? = nil) -> URL {
    let url = (root ?? Paths.downloads).appendingPathComponent(path)
    try! fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! content.data(using: .utf8)!.write(to: url)
    try! fm.setAttributes([.modificationDate: Date().addingTimeInterval(-age)], ofItemAtPath: url.path)
    return url
}

func makeZip(_ name: String, entries: [String], in root: URL? = nil) {
    let staging = sandbox.appendingPathComponent("staging-\(UUID().uuidString)")
    for entry in entries { touch(entry, "z", in: staging) }
    let target = (root ?? Paths.downloads).appendingPathComponent(name)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    process.currentDirectoryURL = staging
    process.arguments = ["-rq", target.path, "."]
    try! process.run()
    process.waitUntilExit()
    try? fm.removeItem(at: staging)
    try! fm.setAttributes([.modificationDate: Date().addingTimeInterval(-3600)], ofItemAtPath: target.path)
}

func exists(_ path: String, in root: URL? = nil) -> Bool {
    fm.fileExists(atPath: (root ?? Paths.downloads).appendingPathComponent(path).path)
}

extension Array where Element == PlannedAction {
    func action(for name: String) -> PlannedAction? { first { $0.source.lastPathComponent == name } }
    func deleted(_ name: String) -> Bool { action(for: name)?.kind == .delete }
    func movedTo(_ name: String) -> String? {
        guard let a = action(for: name), a.kind == .move else { return nil }
        return Engine.display(a.folder) + "/" + a.newName
    }
    func untouched(_ name: String) -> Bool { action(for: name) == nil }
}

func dump(_ actions: [PlannedAction]) {
    for a in actions {
        print("   \(a.kind) \(a.source.lastPathComponent) | \(a.detail) | \(a.newName)")
    }
}

var config = Config()
config.projects = [
    Project(name: "La Glass Factory", prefix: "LGF", keywords: "glass factory, lgf"),
    Project(name: "BNP", prefix: "BNP PF")
]
let day = Fmt.monthDay.string(from: Date().addingTimeInterval(-3600))
let today = Fmt.day.string(from: Date())

// MARK: 1. Fonctions pures

section("Versions")
func vk(_ s: String) -> String { let k = Engine.versionKey(s); return "\(k.stem)|\(k.version)" }
expect(vk("site-v3") == "site|3", vk("site-v3"))
expect(vk("site v12") == "site|12", vk("site v12"))
expect(vk("site2") == "site|2", vk("site2"))
expect(vk("Site_V4") == "site|4", vk("Site_V4"))
expect(vk("site") == "site|0", vk("site"))
expect(vk("site (1)") == "site|0", vk("site (1)"))
expect(vk("site-v3 (2)") == "site|3", vk("site-v3 (2)"))
expect(vk("bilan-2026") == "bilan-2026|0", vk("bilan-2026"))
expect(vk("export 20261126") == "export 20261126|0", vk("export 20261126"))
expect(vk("LGF - tokens-v2") == "lgf - tokens|2", vk("LGF - tokens-v2"))
expect(vk("7") == "7|0", vk("7"))
expect(vk("data.v2") == "data|2", vk("data.v2"))

section("Images génériques")
for name in ["Capture d’écran 2026-11-26 à 10.32.11", "Screenshot 2026-11-26 at 10.32.11", "IMG_1234",
             "image (3)", "DSC00123", "unnamed", "téléchargement (2)", "3f2a9c1e-77ab-4c1d-9a10", "Sans titre-1"] {
    expect(Engine.isGenericImageName(name), "devrait être générique : \(name)")
}
for name in ["hero-banner", "photo-equipe", "logo onepoint", "maquette accueil v2"] {
    expect(!Engine.isGenericImageName(name), "ne devrait pas être générique : \(name)")
}

section("Polices")
expect(Engine.isFontSet(["Inter/Inter-Regular.ttf", "Inter/OFL.txt", "Inter/README", "__MACOSX/._x"]), "police + notices")
expect(Engine.isFontSet(["a.otf"]), "une police seule")
expect(!Engine.isFontSet(["a.ttf", "maquette.psd"]), "projet avec une police")
expect(!Engine.isFontSet(["OFL.txt", "README.md"]), "aucune police")
expect(!Engine.isFontSet([]), "vide")

section("Mots-clés")
func kw(_ s: String) -> [String] { Engine.keywordMatches(s, config: config).map { $0.prefix } }
expect(kw("glass-factory-v2.html") == ["LGF"], "\(kw("glass-factory-v2.html"))")
expect(kw("Glass_Factory export.json") == ["LGF"], "underscore")
expect(kw("pitch lgf.pdf") == ["LGF"], "mot court entier")
expect(kw("algfoo.pdf").isEmpty, "mot court au milieu d'un autre")
expect(kw("rapport.pdf").isEmpty, "aucun")
expect(Engine.project(for: "BNP PF - truc.pdf", config: config)?.name == "BNP", "projet par préfixe")
expect(Engine.stripPrefix("BNP PF - truc.pdf", config: config) == "truc.pdf", "stripPrefix")

section("Réglages")
let partial = #"{"hour": 9, "projects": [{"id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "name": "A", "prefix": "A", "keywords": ""}]}"#
let decoded = try? JSONDecoder().decode(Config.self, from: partial.data(using: .utf8)!)
expect(decoded?.hour == 9 && decoded?.minute == 0 && decoded?.retentionDays == 7 && decoded?.projects.count == 1,
       "décodage tolérant")
let roundTrip = try? JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
expect(roundTrip?.projects == config.projects, "aller-retour")
var toggled = Config()
toggled.set(.eps, false)
expect(!toggled.isOn(.eps) && toggled.isOn(.markdown), "routine désactivée")
toggled.set(.eps, true)
expect(toggled.isOn(.eps), "routine réactivée")
expect(toggled.isOn(.audioKeep) && !toggled.isOn(.audioDelete) && toggled.isOn(.svgKeep) && !toggled.isOn(.svgDelete), "par défaut : audios et SVG rangés")
toggled.set(.audioDelete, true)
expect(toggled.isOn(.audioDelete) && !toggled.isOn(.audioKeep), "supprimer les audios désactive leur rangement")
toggled.set(.audioKeep, true)
expect(toggled.isOn(.audioKeep) && !toggled.isOn(.audioDelete), "et inversement")
let legacy = try? JSONDecoder().decode(Config.self, from: #"{"disabledRoutines": ["fonts"]}"#.data(using: .utf8)!)
expect(legacy?.isOn(.fonts) == false && legacy?.isOn(.zips) == true, "réglages de la 0.7 repris")

section("Couleur des dossiers")
expect(FolderColors.tagNumber("green") == 2 && FolderColors.tagNumber("red") == 6 && FolderColors.tagNumber("gray") == 1, "tags des couleurs prédéfinies")
expect(FolderColors.hex(red: 1, green: 0.5, blue: 0) == "#FF8000", FolderColors.hex(red: 1, green: 0.5, blue: 0))
let pink = FolderColors.rgb("#FF8000")
expect(abs(pink.red - 1) < 0.01 && abs(pink.green - 0.502) < 0.01 && pink.blue == 0, "lecture #RRGGBB")
expect(FolderColors.tagNumber("#FF8000") == 7, "orange personnalisé : tag orange")
expect(FolderColors.tagNumber("#1060F0") == 4, "bleu personnalisé : tag bleu")
expect(FolderColors.rgb("n'importe quoi") == FolderColors.rgb("green"), "valeur illisible : vert")
expect(Config().folderColor == "green" && decoded?.folderColor == "green", "vert par défaut, y compris depuis une ancienne version")

section("Planification")
var at17 = Config()
let next = Schedule.next(after: Date(), config: at17)
let comps = Calendar.current.dateComponents([.hour, .minute], from: next)
expect(comps.hour == 17 && comps.minute == 0 && next > Date(), "prochaine routine à 17:00")
let tomorrow = Schedule.tomorrow(config: at17)
expect(Calendar.current.isDateInTomorrow(tomorrow), "demain : \(tomorrow)")
at17.hour = 9
expect(Schedule.next(after: Date(), config: at17) > Date(), "toujours dans le futur")

// MARK: 2. Plan sur un dossier Téléchargements simulé

section("Plan : polices et archives")
var downloads = reset()
touch("Inter/Inter-Regular.ttf"); touch("Inter/static/Inter-Bold.otf"); touch("Inter/OFL.txt"); touch("Inter/README")
touch("Projet Design/font.ttf"); touch("Projet Design/maquette.psd")
touch("Notes/a.txt")
makeZip("Roboto.zip", entries: ["Roboto/Roboto-Regular.ttf", "Roboto/LICENSE.txt"])
makeZip("site.zip", entries: ["index.html", "assets/style.css"]); touch("site/index.html")
makeZip("download-123.zip", entries: ["MonProjet/a.txt", "MonProjet/b.txt"]); touch("MonProjet/a.txt")
makeZip("export.zip", entries: ["export-data.csv"]); touch("export-data.csv")
makeZip("autre.zip", entries: ["x.txt", "y.txt"])
makeZip("LGF - kit.zip", entries: ["kit/a.txt"]); touch("LGF - kit/a.txt")
var actions = Engine.plan(config: config)
expect(actions.action(for: "Inter")?.reason == "Dossier de polices", "dossier de polices")
expect(actions.untouched("Projet Design"), "projet avec police intouché")
expect(actions.untouched("Notes"), "dossier sans police intouché")
expect(actions.action(for: "Roboto.zip")?.reason == "Archive de polices", "zip de polices")
expect(actions.action(for: "site.zip")?.reason == "Archive déjà dézippée", "zip dézippé, dossier au nom du zip")
expect(actions.action(for: "download-123.zip")?.reason == "Archive déjà dézippée", "zip dézippé, dossier interne")
expect(actions.action(for: "export.zip")?.reason == "Archive déjà dézippée", "zip dézippé, fichier unique")
expect(actions.movedTo("autre.zip") == "Fichiers ZIP/autre.zip", "zip restant rangé")
expect(actions.deleted("LGF - kit.zip"), "zip préfixé dézippé")
expect(actions.untouched("site") && actions.untouched("MonProjet"), "dossiers dézippés intouchés")

var noFonts = config
noFonts.set(.fonts, false)
actions = Engine.plan(config: noFonts)
expect(actions.untouched("Inter") && actions.movedTo("Roboto.zip") == "Fichiers ZIP/Roboto.zip", "routine polices désactivée")
expect(actions.deleted("site.zip"), "zip dézippé toujours supprimé")

section("Plan : doublons, types, documents, vidéos")
downloads = reset()
touch("rapport.pdf", "A"); touch("rapport (1).pdf", "A")
touch("notes.pdf", "A"); touch("notes (1).pdf", "B")
touch("readme.md"); touch("son.mp3"); touch("icon.svg")
touch("deck.pptx"); touch("doc.docx"); touch("clip.mp4"); touch("installeur.dmg")
touch("a.pdf", "meme"); touch("Documents de travail/a.pdf", "meme")
touch("b.pdf", "nouveau"); touch("Documents de travail/b.pdf", "ancien")
actions = Engine.plan(config: config)
expect(actions.action(for: "rapport (1).pdf")?.reason == "Doublon de « rapport.pdf »", "doublon identique")
expect(actions.movedTo("rapport.pdf") == "Documents de travail/rapport.pdf", "original rangé")
expect(actions.movedTo("notes (1).pdf") == "Documents de travail/notes (1).pdf", "contenu différent : rangé, pas supprimé")
expect(actions.deleted("readme.md") && actions.movedTo("son.mp3") == "Audios en cours/son.mp3" && actions.movedTo("icon.svg") == "SVG Images/icon.svg", "md supprimé, audio et svg rangés")
expect(actions.movedTo("deck.pptx") == "Documents de travail/deck.pptx", "pptx")
expect(actions.movedTo("doc.docx") == "Documents de travail/doc.docx", "docx")
expect(actions.movedTo("clip.mp4") == "Vidéos en cours/clip.mp4", "mp4")
expect(actions.action(for: "installeur.dmg")?.reason == "Fichier d'installation", "dmg supprimé")
expect(actions.action(for: "a.pdf")?.reason == "Déjà rangé dans « Documents de travail »", "déjà rangé à l'identique")
expect(actions.movedTo("b.pdf") == "Documents de travail/b.pdf", "même nom, autre contenu : rangé")

var result = Engine.execute(actions)
expect(result.errors.isEmpty, "exécution sans erreur : \(result.errors)")
expect(exists("Yokuro/Fichiers temporaires/\(today)/rapport (1).pdf"), "doublon dans Temporaire")
expect(exists("Yokuro/Fichiers temporaires/\(today)/readme.md") && exists("Yokuro/Fichiers temporaires/\(today)/a.pdf"), "supprimés dans Temporaire")
expect(exists("Documents de travail/rapport.pdf") && exists("Documents de travail/notes (1).pdf"), "documents rangés")
expect(exists("Documents de travail/b.pdf") && exists("Documents de travail/b 2.pdf"), "collision : « b 2.pdf »")
expect(exists("Vidéos en cours/clip.mp4") && exists("Yokuro/Fichiers temporaires/\(today)/installeur.dmg"), "vidéo rangée, dmg supprimé")
expect(!exists("rapport.pdf") && !exists("son.mp3"), "plus rien à la racine")
expect(Engine.plan(config: config).isEmpty, "deuxième passage : plus rien à faire")

section("Plan : versions HTML")
downloads = reset()
touch("site-v1.html", "1"); touch("site-v2.html", "2"); touch("site-v3.html", "3")
touch("page.html", "ancien", age: 7200); touch("page (1).html", "nouveau", age: 60)
touch("demo.html", "0"); touch("demo-v2.html", "2")
touch("bilan.html", "a"); touch("bilan-2026.html", "b")
touch("solo.html")
touch("idx.html", "pareil"); touch("idx (1).html", "pareil")
touch("LGF - accueil-v1.html", "1"); touch("accueil-v2.html", "2")
actions = Engine.plan(config: config)
expect(actions.deleted("site-v1.html") && actions.deleted("site-v2.html") && actions.untouched("site-v3.html"), "v1 et v2 supprimées")
expect(actions.action(for: "page.html")?.reason == "Version antérieure de « page (1).html »", "(1) plus récent = dernière version")
expect(actions.untouched("page (1).html"), "la copie récente reste")
expect(actions.deleted("demo.html") && actions.untouched("demo-v2.html"), "sans numéro = plus ancien")
expect(actions.untouched("bilan.html") && actions.untouched("bilan-2026.html"), "une année n'est pas une version")
expect(actions.untouched("solo.html"), "fichier seul")
expect(actions.action(for: "idx (1).html")?.reason == "Doublon de « idx.html »" && actions.untouched("idx.html"), "doublon html identique")
expect(actions.untouched("LGF - accueil-v1.html") && actions.untouched("accueil-v2.html"), "projets différents : pas la même série")

section("Plan : JSON")
downloads = reset()
touch("LGF - tokens-v1.json", "1"); touch("LGF - tokens-v2.json", "2")
touch("Fichiers JSON/La Glass Factory/LGF - tokens.json", "0", age: 90000)
touch("glass factory data.json", "d")
touch("random.json", "r")
touch("same.json", "pareil"); touch("Fichiers JSON/same.json", "pareil", age: 90000)
touch("cfg-v3.json", "3"); touch("Fichiers JSON/cfg-v5.json", "5", age: 90000)
touch("data.json", "nouveau", age: 60); touch("Fichiers JSON/data.json", "ancien", age: 90000)
actions = Engine.plan(config: config)
expect(actions.action(for: "LGF - tokens-v1.json")?.reason == "Version antérieure de « LGF - tokens-v2.json »", "v1 supprimée")
expect(actions.movedTo("LGF - tokens-v2.json") == "Fichiers JSON/La Glass Factory/LGF - tokens-v2.json", "v2 rangée par projet")
expect(actions.action(for: "LGF - tokens.json")?.reason
        == "Version antérieure de « LGF - tokens-v2.json », dans « Fichiers JSON/La Glass Factory »", "ancienne version déjà rangée")
expect(actions.movedTo("glass factory data.json") == "Fichiers JSON/La Glass Factory/glass factory data.json", "projet par mot-clé")
expect(actions.movedTo("random.json") == "Fichiers JSON/random.json", "sans projet")
expect(actions.first { $0.source.path.hasSuffix("Downloads/same.json") }?.reason == "Déjà rangé dans « Fichiers JSON »", "identique déjà rangé")
expect(actions.action(for: "cfg-v3.json")?.reason == "Version antérieure de « cfg-v5.json », déjà rangé dans « Fichiers JSON »", "plus récent déjà rangé")
let dataActions = actions.filter { $0.source.lastPathComponent == "data.json" }
expect(dataActions.count == 2 && dataActions[0].kind == .delete && dataActions[0].source.path.contains("Fichiers JSON")
        && dataActions[1].kind == .move, "même nom : l'ancien rangé part, le nouveau prend sa place")
result = Engine.execute(actions)
expect(result.errors.isEmpty, "exécution JSON : \(result.errors)")
expect((try? String(contentsOf: downloads.appendingPathComponent("Fichiers JSON/data.json"))) == "nouveau", "data.json remplacé")
expect(!exists("Fichiers JSON/data 2.json"), "pas de « data 2.json »")
expect(exists("Fichiers JSON/La Glass Factory/LGF - tokens-v2.json") && !exists("Fichiers JSON/La Glass Factory/LGF - tokens.json"), "dossier projet à jour")
expect(exists("Fichiers JSON/cfg-v5.json") && !exists("cfg-v3.json") && exists("Fichiers JSON/same.json"), "versions rangées conservées")
expect(Engine.plan(config: config).isEmpty, "deuxième passage JSON : rien")

section("Plan : images")
downloads = reset()
touch("Capture d’écran 2026-11-26 à 10.32.11.png", "1")
touch("IMG_1234.JPG", "2")
touch("hero-banner.png", "3")
touch("LGF - IMG_0001.png", "4")
touch("Images/Image \(day) - 04.png", "x")
actions = Engine.plan(config: config)
expect(actions.movedTo("Capture d’écran 2026-11-26 à 10.32.11.png") == "Captures d’écran/Capture d’écran 2026-11-26 à 10.32.11.png", "\(actions.movedTo("Capture d’écran 2026-11-26 à 10.32.11.png") ?? "nil")")
expect(actions.movedTo("IMG_1234.JPG") == "Images/Image \(day) - 05.JPG", "\(actions.movedTo("IMG_1234.JPG") ?? "nil")")
expect(actions.movedTo("hero-banner.png") == "Images/hero-banner.png", "nom parlant conservé")
expect(actions.movedTo("LGF - IMG_0001.png") == "Images/LGF - Image \(day) - 06.png", "\(actions.movedTo("LGF - IMG_0001.png") ?? "nil")")

section("Review : décocher et renommer")
actions[actions.firstIndex { $0.source.lastPathComponent == "hero-banner.png" }!].newName = "Bannière accueil"
actions[actions.firstIndex { $0.source.lastPathComponent == "IMG_1234.JPG" }!].enabled = false
result = Engine.execute(actions)
expect(exists("Images/Bannière accueil.png"), "renommé, extension remise")
expect(exists("IMG_1234.JPG") && !exists("Images/Image \(day) - 05.JPG"), "décoché : pas touché")
expect(result.moved.count == 3 && result.errors.isEmpty, "\(result)")

section("Fichier disparu entre le plan et la validation")
downloads = reset()
touch("x.pdf")
actions = Engine.plan(config: config)
try! fm.removeItem(at: downloads.appendingPathComponent("x.pdf"))
result = Engine.execute(actions)
expect(result.errors.count == 1 && result.errors[0].contains("introuvable"), "\(result.errors)")

section("Noms inhabituels et routines désactivées")
downloads = reset()
let odd = ["sans extension", "é à ü ñ.pdf", "a.b.c.tar.gz", "(1).pdf", " (2).html", "v2.html", "2.json",
           "x (1) (1).pdf", String(repeating: "long", count: 40) + ".png", "LGF - .pdf", "fichier.", "🙂.svg",
           "Capture d’écran.PNG", "données (10).json", "données.json"]
for name in odd { touch(name, name) }
actions = Engine.plan(config: config)
result = Engine.execute(actions)
expect(result.errors.isEmpty, "noms inhabituels : \(result.errors)")
expect(exists("a.b.c.tar.gz") && exists("Yokuro/Fichiers temporaires/\(today)/sans extension"), "hors règles conservé, sans extension supprimé")
expect(exists("Documents de travail/é à ü ñ.pdf") && exists("SVG Images/🙂.svg"), "accents et emoji")
expect(Engine.plan(config: config).isEmpty, "stable après un passage")

downloads = reset()
for name in ["a.md", "b.mp3", "c.svg", "d-v1.html", "d-v2.html", "e.json", "f.png", "g.pdf", "h.mp4", "i (1).pdf", "i.pdf"] { touch(name, "x") }
touch("Polices/a.ttf"); makeZip("z.zip", entries: ["z/a.txt"]); touch("z/a.txt")
var allOff = Config()
for routine in Routine.allCases { allOff.set(routine, false) }
expect(Engine.plan(config: allOff).isEmpty, "toutes routines désactivées : rien")
expect(Engine.plan(config: Config()).count == 12, "toutes routines actives : \(Engine.plan(config: Config()).count) actions")

touch("logo.png", "L"); touch("Images/logo.png", "L")
actions = Engine.plan(config: config)
expect(actions.action(for: "logo.png")?.reason == "Déjà rangé dans « Images »", "image déjà rangée")

section("Rangements et suppressions ajoutés en 0.8")
downloads = reset()
for name in ["a.psd", "b.aep", "c.xlsx", "d.txt", "e.rtf", "f.mov", "g.webm", "hero.webp", "i.eps", "j.exe", "k.pkg",
             "l.wav", "m.svg", "sansext", "n.zip"] { touch(name, name) }
actions = Engine.plan(config: config)
let expected = ["a.psd": "PSD Photoshop", "b.aep": "AEP After Effect", "c.xlsx": "Documents de travail",
                "d.txt": "Documents de travail", "e.rtf": "Documents de travail", "f.mov": "Vidéos en cours",
                "g.webm": "Vidéos en cours", "hero.webp": "Images", "l.wav": "Audios en cours", "m.svg": "SVG Images",
                "n.zip": "Fichiers ZIP"]
for (name, folder) in expected {
    expect(actions.movedTo(name) == "\(folder)/\(name)", "\(name) : \(actions.movedTo(name) ?? "nil")")
}
for name in ["i.eps", "j.exe", "k.pkg", "sansext"] { expect(actions.deleted(name), "\(name) supprimé") }
var deleting = config
deleting.set(.audioDelete, true)
deleting.set(.svgDelete, true)
actions = Engine.plan(config: deleting)
expect(actions.deleted("l.wav") && actions.deleted("m.svg"), "audios et SVG supprimés sur demande")
var neither = config
neither.set(.audioKeep, false)
expect(Engine.plan(config: neither).untouched("l.wav"), "ni rangé ni supprimé")
result = Engine.execute(Engine.plan(config: config))
expect(result.errors.isEmpty && Engine.plan(config: config).isEmpty, "stable après un passage : \(result.errors)")

section("Ancien dossier Temporaire")
downloads = reset()
let oldDay = Fmt.day.string(from: Date().addingTimeInterval(-9 * 86_400))
touch("Yokuro/Temporaire/\(oldDay)/x.txt"); touch("Yokuro/Fichiers temporaires/\(oldDay)/y.txt")
Engine.adoptOldTemp()
expect(!exists("Yokuro/Temporaire") && exists("Yokuro/Fichiers temporaires/\(oldDay)/y.txt")
        && exists("Yokuro/Fichiers temporaires/\(oldDay) 2/x.txt"), "contenu repris")
expect(Engine.purge(retentionDays: 7).count == 2, "les deux dossiers datés sont purgés")
trashed.removeAll()

section("Copies et captures d’écran (0.12)")
downloads = reset()
for name in ["logo copie.png", "logo copie 2.png", "Contrat - copie.pdf", "copieur.pdf", "photocopie.pdf",
             "Capture d’écran 2026-11-26 à 14.05.24.png", "Screenshot 2026-11-26 at 14.05.png", "Capture d’écran copie.png"] {
    touch(name, name)
}
touch("Icon\r", "icone")
actions = Engine.plan(config: config)
for name in ["logo copie.png", "logo copie 2.png", "Contrat - copie.pdf", "Capture d’écran copie.png"] {
    expect(actions.action(for: name)?.reason == "Copie", "\(name) supprimé comme copie")
}
expect(actions.movedTo("copieur.pdf") == "Documents de travail/copieur.pdf" && actions.movedTo("photocopie.pdf") != nil, "« copie » au milieu d’un mot : rangé")
expect(actions.movedTo("Capture d’écran 2026-11-26 à 14.05.24.png") == "Captures d’écran/Capture d’écran 2026-11-26 à 14.05.24.png", "capture rangée")
expect(actions.movedTo("Screenshot 2026-11-26 at 14.05.png") == "Captures d’écran/Screenshot 2026-11-26 at 14.05.png", "screenshot rangé")
expect(actions.untouched("Icon\r"), "fichier d’icône de dossier ignoré")
var dropShots = config
dropShots.set(.screenshotDelete, true)
expect(!dropShots.isOn(.screenshotKeep), "supprimer les captures désactive leur rangement")
actions = Engine.plan(config: dropShots)
expect(actions.action(for: "Screenshot 2026-11-26 at 14.05.png")?.reason == "Capture d’écran", "captures supprimées sur demande")
touch("x copie.pdf", age: 5)
expect(Engine.processArrivals(config: config, known: []).ask.allSatisfy { !Engine.isCopy(($0 as NSString).deletingPathExtension) }, "pas de question pour une copie")

section("Date de la routine")
expect(Fmt.routine(Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: Date())!) == "aujourd’hui à 23h59", Fmt.routine(Date()))
expect(Fmt.routine(Schedule.tomorrow(config: Config())) == "demain à 17h00", Fmt.routine(Schedule.tomorrow(config: Config())))

// MARK: 3. Tri ponctuel

section("Tri ponctuel avec préfixe, rangement dans Téléchargements")
downloads = reset()
let other = sandbox.appendingPathComponent("Bureau/Vrac")
touch("brief.pdf", in: other); touch("notes.fig", in: other); touch("BNP PF - deja.fig", in: other)
touch("tokens.json", in: other); touch("IMG_7.png", in: other); touch("vieux.md", in: other)
touch("sous-dossier/x.txt", in: other)
actions = Engine.plan(config: config, root: other, destination: downloads, prefix: "BNP PF")
expect(actions.movedTo("brief.pdf") == "Documents de travail/BNP PF - brief.pdf", "\(actions.movedTo("brief.pdf") ?? "nil")")
expect(actions.movedTo("tokens.json") == "Fichiers JSON/BNP/BNP PF - tokens.json", "\(actions.movedTo("tokens.json") ?? "nil")")
expect(actions.movedTo("IMG_7.png") == "Images/BNP PF - Image \(day) - 01.png", "\(actions.movedTo("IMG_7.png") ?? "nil")")
expect(actions.action(for: "notes.fig")?.kind == .rename && actions.action(for: "notes.fig")?.newName == "BNP PF - notes.fig", "renommé sur place")
expect(actions.untouched("BNP PF - deja.fig") && actions.untouched("sous-dossier"), "déjà préfixé et dossiers intouchés")
expect(actions.deleted("vieux.md"), "md supprimé")
result = Engine.execute(actions)
expect(result.errors.isEmpty, "\(result.errors)")
expect(exists("Documents de travail/BNP PF - brief.pdf") && exists("Fichiers JSON/BNP/BNP PF - tokens.json"), "rangés dans Téléchargements")
expect(fm.fileExists(atPath: other.appendingPathComponent("BNP PF - notes.fig").path), "renommé dans le dossier trié")
expect(exists("Yokuro/Fichiers temporaires/\(today)/vieux.md"), "supprimé vers Temporaire")
expect(result.renamed == ["notes.fig > BNP PF - notes.fig"], "\(result.renamed)")

section("Tri ponctuel, rangement dans le dossier trié")
touch("plan.pdf", in: other)
actions = Engine.plan(config: config, root: other)
expect(actions.count == 1 && actions[0].folder?.path == other.appendingPathComponent("Documents de travail").path, "dossier de rangement local")
expect(actions[0].detail.hasPrefix("Vers « ") && actions[0].detail.contains("Bureau/Vrac/Documents de travail"), actions[0].detail)

// MARK: 4. Arrivées

section("Arrivées")
downloads = reset()
touch("ancien.pdf")
var arrivals = Engine.processArrivals(config: config, known: nil)
expect(arrivals.ask.isEmpty && arrivals.known.count == 1, "premier passage : tout est connu")
var known = arrivals.known
touch("nouveau.pdf", age: 5)
touch("glass-factory-maquette.html", age: 5)
touch("memo.md", age: 5)
touch("app.dmg", age: 5); touch("sansext", age: 5); touch("son.mp3", age: 5)
touch("vide.pdf", "", age: 5)
touch("ecrit.pdf", age: 0)
touch("firefox.zip", age: 5); touch("firefox.zip.part", age: 5)
touch("LGF - deja.pdf", age: 5)
try! fm.createDirectory(at: downloads.appendingPathComponent("Dossier"), withIntermediateDirectories: true)
arrivals = Engine.processArrivals(config: config, known: known)
expect(arrivals.ask == ["nouveau.pdf", "son.mp3"], "pas de question pour ce qui sera supprimé : \(arrivals.ask)")
expect(arrivals.renamed == ["glass-factory-maquette.html > LGF - glass-factory-maquette.html"], "\(arrivals.renamed)")
expect(exists("LGF - glass-factory-maquette.html"), "préfixé par mot-clé")
known = arrivals.known
arrivals = Engine.processArrivals(config: config, known: known)
expect(arrivals.ask.isEmpty && arrivals.renamed.isEmpty, "pas de seconde question")
try! fm.moveItem(at: downloads.appendingPathComponent("nouveau.pdf"), to: downloads.appendingPathComponent("renommé à la main.pdf"))
arrivals = Engine.processArrivals(config: config, known: arrivals.known)
expect(arrivals.ask.isEmpty, "un renommage manuel ne relance pas la question : \(arrivals.ask)")
try! fm.setAttributes([.modificationDate: Date().addingTimeInterval(-5)], ofItemAtPath: downloads.appendingPathComponent("ecrit.pdf").path)
arrivals = Engine.processArrivals(config: config, known: arrivals.known)
expect(arrivals.ask == ["ecrit.pdf"], "fichier terminé : question posée : \(arrivals.ask)")

var silent = config
silent.askOnArrival = false
silent.renameOnArrival = false
touch("glass factory 2.pdf", age: 5); touch("plus tard.pdf", age: 5)
arrivals = Engine.processArrivals(config: silent, known: arrivals.known)
expect(arrivals.ask.isEmpty && arrivals.renamed.isEmpty && exists("glass factory 2.pdf"), "tout désactivé")

section("Derniers fichiers et choix du projet")
touch("vieux.pdf", age: 3 * 3600)
let recent = Engine.recentUnassigned(config: config)
expect(recent.contains("plus tard.pdf") && recent.contains("glass factory 2.pdf"), "\(recent)")
expect(!recent.contains("vieux.pdf") && !recent.contains("LGF - deja.pdf") && !recent.contains("memo.md") && !recent.contains("Dossier"), "\(recent)")
expect(Engine.assign(name: "plus tard.pdf", prefix: "BNP PF") == "BNP PF - plus tard.pdf" && exists("BNP PF - plus tard.pdf"), "préfixe choisi")
expect(Engine.assign(name: "absent.pdf", prefix: "BNP PF") == nil, "fichier absent")
expect(Engine.assign(name: "BNP PF - plus tard.pdf", prefix: "BNP PF") == "BNP PF - plus tard.pdf", "déjà préfixé : inchangé")

section("Renommer depuis la pop-in")
touch("brouillon.pdf")
expect(Engine.rename(name: "brouillon.pdf", to: "Devis final") == "Devis final.pdf" && exists("Devis final.pdf"), "extension remise")
expect(Engine.rename(name: "Devis final.pdf", to: "Devis final.pdf") == nil, "même nom : rien")
expect(Engine.rename(name: "Devis final.pdf", to: "  ") == nil && exists("Devis final.pdf"), "nom vide : rien")
expect(Engine.rename(name: "Devis final.pdf", to: "a/b") == "a-b.pdf", "caractère interdit remplacé")
var timed = Config()
expect(abs(timed.stickyEnd(from: Date(timeIntervalSince1970: 0))!.timeIntervalSince1970 - 1800) < 1, "30 min par défaut")
timed.stickyMinutes = 120
expect(abs(timed.stickyEnd(from: Date(timeIntervalSince1970: 0))!.timeIntervalSince1970 - 7200) < 1, "durée réglée")
timed.stickyUnlimited = true
expect(timed.stickyEnd() == nil, "jusqu’à désactivation")

// MARK: 5. Purge et rapport

section("Purge de Temporaire")
downloads = reset()
let old = Fmt.day.string(from: Date().addingTimeInterval(-8 * 86_400))
let young = Fmt.day.string(from: Date().addingTimeInterval(-2 * 86_400))
let limit = Fmt.day.string(from: Calendar.current.date(byAdding: .day, value: -7, to: Date())!)
touch("Yokuro/Fichiers temporaires/\(old)/a.txt"); touch("Yokuro/Fichiers temporaires/\(old)/b.txt")
touch("Yokuro/Fichiers temporaires/\(young)/c.txt")
touch("Yokuro/Fichiers temporaires/\(limit)/d.txt")
touch("Yokuro/Fichiers temporaires/autre chose/e.txt")
let purged = Engine.purge(retentionDays: 7)
expect(purged.count == 2 && purged.contains("Suppressions du \(old) (2 éléments)"), "\(purged)")
expect(purged.contains("Suppressions du \(limit) (1 élément)"), "singulier : \(purged)")
expect(Set(trashed) == [old, limit], "\(trashed)")
expect(exists("Yokuro/Fichiers temporaires/\(young)/c.txt") && exists("Yokuro/Fichiers temporaires/autre chose/e.txt"), "le reste est conservé")

section("Rapport")
var report = ExecutionResult()
Engine.writeReport(result: report, renames: [], purged: [], retentionDays: 7)
expect(!exists("Yokuro/Rapport"), "rien à dire : pas de rapport")
report.deleted = ["a.md (Fichier .md)"]; report.moved = ["b.pdf > Documents de travail/b.pdf"]
Engine.writeReport(result: report, renames: ["c.pdf > LGF - c.pdf"], purged: purged, retentionDays: 7, folder: other)
let reports = (try? fm.contentsOfDirectory(atPath: Paths.reports.path)) ?? []
expect(reports.count == 1 && reports[0].hasPrefix("Rapport \(today)") && reports[0].hasSuffix(".txt"), "\(reports)")
let text = (try? String(contentsOf: Paths.reports.appendingPathComponent(reports.first ?? ""))) ?? ""
for needle in ["Yokuro : rapport du", "Tri ponctuel du dossier :", "Supprimés, gardés 7 jours", "Déplacés (1)", "Renommés (1)", "Envoyés à la corbeille (2)"] {
    expect(text.contains(needle), "rapport sans « \(needle) »")
}
expect(!text.contains("Erreurs"), "pas de section vide")
print(text)

try? fm.removeItem(at: sandbox)
print("\n\(checks - failures)/\(checks) vérifications réussies")
exit(failures == 0 ? 0 : 1)
