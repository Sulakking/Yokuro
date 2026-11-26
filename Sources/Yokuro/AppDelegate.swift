import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let store = Store()
    let model = PopoverModel()
    /// Analyse, déplacements, purge et rapports se font ici, jamais sur le fil de l'interface.
    let work = DispatchQueue(label: "yokuro.work")

    var statusItem: NSStatusItem!
    let popover = NSPopover()
    var reviewWindow: NSWindow?
    var settingsWindow: NSWindow?

    var timer: Timer?
    var watcher: DispatchSourceFileSystemObject?
    var arrivalCheck: DispatchWorkItem?
    var badge: AnyCancellable?
    var activity: NSObjectProtocol?

    var planning = false
    /// Fichiers déjà vus dans Téléchargements ; nil avant le premier passage.
    var known: Set<UInt64>?
    /// Pop-in en pause jusqu'à cette heure (bouton Pause).
    /// Pop-in en pause jusqu'à la reprise. Conservé d'un lancement à l'autre.
    var paused: Bool {
        get { UserDefaults.standard.bool(forKey: "paused") }
        set { UserDefaults.standard.set(newValue, forKey: "paused") }
    }
    /// Choix appliqué d'office aux nouveaux fichiers (case « Renommer dans la même catégorie »).
    /// Conservé d'un lancement à l'autre ; `until` nil : jusqu'à désactivation.
    var sticky: (prefix: String, until: Date?)? {
        get {
            guard let prefix = UserDefaults.standard.string(forKey: "stickyPrefix") else { return nil }
            let until = UserDefaults.standard.object(forKey: "stickyUntil") as? Date
            if let until = until, until <= Date() { return nil }
            return (prefix, until)
        }
        set {
            UserDefaults.standard.set(newValue?.prefix, forKey: "stickyPrefix")
            UserDefaults.standard.set(newValue?.until, forKey: "stickyUntil")
        }
    }
    /// Vrai quand la pop-in se ferme pour ouvrir les réglages : les fichiers en attente le restent.
    var keepPending = false

    // MARK: Démarrage

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Sans cela, macOS met l'app en sommeil (App Nap) et la pop-in arrive en retard.
        activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                                                         reason: "Surveillance du dossier Téléchargements")
        setupMainMenu()
        setupStatusItem()
        LoginItem.sync(enabled: store.config.launchAtLogin)
        startWatcher()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in self?.tick() }
        checkArrivals()
        Engine.labelNames = NSWorkspace.shared.fileLabels // noms des tags de couleur, par numéro
        Engine.tagNumber = FolderColors.tagNumber(store.config.folderColor)
        Engine.colorFolder = { [weak self] url in DispatchQueue.main.async { self?.tint(url) } }
        adoptTintedFolders()
        store.onFolderColorChange = { [weak self] in self?.scheduleRecolor() }
        work.async {
            Engine.adoptOldTemp()
            Engine.markManagedFolders()
        }
        finish([]) // purge des fichiers temporaires
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            var image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Yokuro")
            if let url = Bundle.main.url(forResource: "YokuroIcon", withExtension: "pdf"),
               let custom = NSImage(contentsOf: url) {
                custom.size = NSSize(width: 22, height: 22)
                image = custom
            }
            image?.isTemplate = true // noir ou blanc selon la barre de menus
            button.image = image
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover)
        }
        popover.behavior = .transient
        popover.delegate = self
        // Nombre de fichiers qui attendent un projet, à côté du picto.
        badge = model.$pending.sink { [weak self] pending in
            self?.statusItem.button?.title = pending.isEmpty ? "" : "\(pending.count)"
        }
    }

    /// Menu Édition invisible : sans lui, copier-coller ne marche pas dans les champs de texte.
    private func setupMainMenu() {
        let edit = NSMenu(title: "Édition")
        edit.addItem(withTitle: "Annuler", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Couper", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Tout sélectionner", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = edit
        let mainMenu = NSMenu()
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    // MARK: Pop-in

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(activate: true)
        }
    }

    /// `activate` : vrai sur un clic. Quand Yokuro ouvre la pop-in de lui-même, il ne prend pas le clavier :
    /// on ne coupe pas la frappe en cours dans une autre app.
    private func showPopover(activate: Bool) {
        guard let button = statusItem.button, button.window != nil, !popover.isShown else { return }
        refreshModel()
        let root = PopoverRoot(model: model, store: store) { [weak self] action in self?.handle(action) }
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        if activate { NSApp.activate(ignoringOtherApps: true) }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if activate { hosting.view.window?.makeKey() }
    }

    private func refreshModel() {
        let names = Set(Engine.scan().map { $0.name })
        model.batch = nil
        model.pending.removeAll { !names.contains($0) }
        model.fileCount = names.count
        model.nextRun = Fmt.routine(store.nextRun)
        model.pause = pauseStatus()
        model.paused = paused
        model.fileName = model.pending.first ?? ""
        model.stickyEnd = store.config.stickyEnd()
        model.options = AssignOptions()
        model.lastPrefix = rememberedPrefix()
        model.recentCount = Engine.recentUnassigned(config: store.config).count
        model.canRead = Engine.canRead(Paths.downloads)
    }

    private func pauseStatus() -> Pause? {
        if let sticky = sticky {
            let end = sticky.until.map { " jusqu’à \(Fmt.time.string(from: $0))" } ?? ""
            return Pause(text: "Nouveaux fichiers renommés en \(sticky.prefix)\(end)", stop: "Arrêter le renommage")
        }
        if paused { return Pause(text: "En pause", stop: "Reprendre") }
        return nil
    }

    /// Dernière catégorie choisie, si son projet existe toujours.
    private func rememberedPrefix() -> String? {
        guard let prefix = store.lastPrefix,
              store.config.projects.contains(where: { $0.prefix == prefix }) else { return nil }
        return prefix
    }

    /// Ferme la pop-in, sauf si la routine attend une réponse : la demande de validation prend le relais.
    private func closeUnlessDue() {
        if model.due == nil { popover.performClose(nil) }
    }

    func popoverDidClose(_ notification: Notification) {
        if model.batch == nil { renameShownFile() } // nom modifié puis pop-in fermée : on le garde
        // Case cochée puis pop-in fermée sans choisir de projet : la case s'applique quand même.
        let options = model.options
        model.options = AssignOptions()
        if options.sticky, let prefix = rememberedPrefix() {
            // « Renommer avec la même catégorie » sans choix : c'est la dernière catégorie utilisée.
            sticky = (prefix: prefix, until: store.config.stickyEnd())
            apply(prefix: prefix, to: model.pending)
            model.pending.removeAll()
        }
        // Fermée sans choix : les fichiers restent sans projet. En pause, ils attendent.
        if !keepPending { model.pending.removeAll() }
        keepPending = false
        // Routine en attente et pop-in fermée sans réponse : on la repropose dans une heure.
        guard model.due != nil else { return }
        model.due = nil
        store.nextRun = Date().addingTimeInterval(3600)
    }

    private func handle(_ action: PopoverAction) {
        switch action {
        case .choose(let project):
            choose(project)
        case .addProject(let name):
            addProject(name)
        case .deleteProject(let id):
            store.config.projects.removeAll { $0.id == id }
        case .renameRecent:
            // La pop-in reste ouverte et bascule sur le choix du projet, pour tous les fichiers d'un coup.
            let names = Engine.recentUnassigned(config: store.config)
            model.batch = names.isEmpty ? nil : names
        case .cancelBatch:
            model.batch = nil
        case .pause:
            if paused {
                paused = false
                refreshModel()
            } else {
                // Plus de pop-in jusqu'à la reprise : les fichiers qui arrivent attendent, leur nombre s'affiche à côté du picto.
                paused = true
                keepPending = true
                popover.performClose(nil)
            }
        case .renameFile:
            renameShownFile()
        case .resume:
            sticky = nil
            paused = false
            model.pause = nil
            model.paused = false
        case .snooze(let snooze):
            model.due = nil
            switch snooze {
            case .hours(let hours): store.nextRun = Date().addingTimeInterval(Double(hours) * 3600)
            case .tomorrow: store.nextRun = Schedule.tomorrow(config: store.config)
            }
            popover.performClose(nil)
        case .run:
            if model.due != nil {
                model.due = nil
                store.nextRun = Schedule.next(after: Date(), config: store.config)
            }
            popover.performClose(nil)
            runNow()
        case .sortFolder:
            popover.performClose(nil)
            sortOtherFolder()
        case .open(let url):
            popover.performClose(nil)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            NSWorkspace.shared.open(url)
        case .settings:
            keepPending = true
            popover.performClose(nil)
            openSettings()
        case .quit:
            NSApp.terminate(nil)
        }
    }

    // MARK: Choix du projet

    /// Classe le fichier en attente, ou tout le lot, dans un projet. `project` nil : pas de préfixe.
    private func choose(_ project: Project?) {
        let options = model.options
        model.options = AssignOptions()
        if let project = project { store.lastPrefix = project.prefix }
        if let batch = model.batch { // « Renommer les derniers fichiers » : un choix pour tous
            model.batch = nil
            model.pending.removeAll { batch.contains($0) }
            apply(prefix: project?.prefix, to: batch)
        } else {
            guard !model.pending.isEmpty else { return }
            renameShownFile() // nom modifié dans la pop-in sans valider par Entrée
            var names = [model.pending.removeFirst()]
            if options.sticky, let prefix = project?.prefix {
                // Même choix pour les fichiers déjà en attente et pour ceux qui arriveront.
                sticky = (prefix: prefix, until: store.config.stickyEnd())
                names += model.pending
                model.pending.removeAll()
            }
            apply(prefix: project?.prefix, to: names)
            model.pause = pauseStatus()
            if !model.pending.isEmpty { return } // fichier suivant
        }
        // La liste ne bouge qu'une fois la série terminée : le dernier projet utilisé remonte en tête.
        if let project = project { promote(project) }
        closeUnlessDue()
    }

    /// Applique le nom saisi au fichier affiché dans la pop-in.
    private func renameShownFile() {
        guard let name = model.pending.first,
              let renamed = Engine.rename(name: name, to: model.fileName) else { return }
        model.pending[0] = renamed
        model.fileName = renamed
        store.appendRenameLog(["\(name) > \(renamed)"])
    }

    private func addProject(_ typed: String) {
        let name = Engine.safeName(typed)
        guard !name.isEmpty else { return }
        if let existing = store.config.projects.first(where: { $0.prefix.caseInsensitiveCompare(name) == .orderedSame }) {
            choose(existing)
        } else {
            let project = Project(name: name, prefix: name)
            store.config.projects.append(project)
            choose(project)
        }
    }

    private func promote(_ project: Project) {
        var projects = store.config.projects
        guard let index = projects.firstIndex(where: { $0.id == project.id }), index > 0 else { return }
        projects.insert(projects.remove(at: index), at: 0)
        store.config.projects = projects
    }

    private func apply(prefix: String?, to names: [String]) {
        guard let prefix = prefix, !prefix.isEmpty else { return }
        let renamed = names.compactMap { name in
            Engine.assign(name: name, prefix: prefix).map { "\(name) > \($0)" }
        }
        if !renamed.isEmpty { store.appendRenameLog(renamed) }
    }

    // MARK: Arrivée des fichiers

    private func startWatcher() {
        let descriptor = open(Paths.downloads.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write,
                                                               queue: .main)
        source.setEventHandler { [weak self] in self?.scheduleArrivalCheck() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watcher = source
    }

    /// Un seul passage, une seconde et demie après le dernier mouvement dans le dossier.
    private func scheduleArrivalCheck() {
        arrivalCheck?.cancel()
        let check = DispatchWorkItem { [weak self] in self?.checkArrivals() }
        arrivalCheck = check
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: check)
    }

    private func checkArrivals() {
        let result = Engine.processArrivals(config: store.config, known: known)
        known = result.known
        if !result.renamed.isEmpty { store.appendRenameLog(result.renamed) }
        let fresh = result.ask.filter { !model.pending.contains($0) }
        guard !fresh.isEmpty else { return }

        if let sticky = sticky {
            apply(prefix: sticky.prefix, to: fresh)
            return
        }
        // En pause ou en mode Concentration, les fichiers attendent : leur nombre s'affiche à côté du picto.
        model.pending.append(contentsOf: fresh)
        if paused { return }
        if store.config.respectFocus, Focus.isActive() == true { return }
        showPopover(activate: false)
    }

    // MARK: Routine

    private func tick() {
        if watcher == nil { startWatcher() } // accès à Téléchargements accordé après le lancement
        checkArrivals()
        guard !planning, model.due == nil, reviewWindow?.isVisible != true, Date() >= store.nextRun else { return }
        if paused { return } // en pause : la routine attend la reprise
        if store.config.respectFocus, Focus.isActive() == true { return } // on attend la fin de la Concentration
        computePlan { [weak self] actions in
            guard let self = self else { return }
            if actions.isEmpty {
                self.store.nextRun = Schedule.next(after: Date(), config: self.store.config)
                self.finish([])
            } else {
                self.model.due = Due(deletes: actions.filter { $0.kind == .delete }.count,
                                     moves: actions.filter { $0.kind == .move }.count)
                self.showPopover(activate: false)
            }
        }
    }

    private func computePlan(root: URL = Paths.downloads, destination: URL? = nil, prefix: String? = nil,
                             then completion: @escaping ([PlannedAction]) -> Void) {
        planning = true
        let config = store.config
        work.async {
            let actions = Engine.plan(config: config, root: root, destination: destination, prefix: prefix)
            DispatchQueue.main.async {
                self.planning = false
                completion(actions)
            }
        }
    }

    private func runNow() {
        if let window = reviewWindow, window.isVisible {
            show(window)
            return
        }
        guard !planning else { return }
        computePlan { [weak self] actions in
            guard let self = self else { return }
            if actions.isEmpty {
                self.finish([])
                self.inform("Rien à ranger", "Téléchargements est déjà propre.")
            } else {
                self.showReview(actions)
            }
        }
    }

    /// Tri ponctuel d'un dossier choisi : mêmes règles, review immédiate, sans toucher à la routine planifiée.
    private func sortOtherFolder() {
        if let window = reviewWindow, window.isVisible {
            show(window)
            return
        }
        guard !planning else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = Paths.downloads
        panel.message = "Choisis le dossier à trier maintenant."
        panel.prompt = "Trier ce dossier"

        // Deux options sous la liste des dossiers : où ranger, et quel préfixe projet appliquer.
        let destinationPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        destinationPopup.addItems(withTitles: ["Dans le dossier choisi", "Dans Téléchargements"])
        destinationPopup.selectItem(at: UserDefaults.standard.bool(forKey: "sortIntoDownloads") ? 1 : 0)
        let prefixes = store.config.projects.map { $0.prefix }.filter { !$0.isEmpty }
        let projectPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        projectPopup.addItem(withTitle: "Aucun préfixe")
        for prefix in prefixes { projectPopup.addItem(withTitle: prefix) }
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Créer les dossiers de rangement :"), destinationPopup],
            [NSTextField(labelWithString: "Préfixe projet :"), projectPopup]
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 80))
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        panel.accessoryView = container
        panel.isAccessoryViewDisclosed = true

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let intoDownloads = destinationPopup.indexOfSelectedItem == 1
        UserDefaults.standard.set(intoDownloads, forKey: "sortIntoDownloads")
        let chosen = projectPopup.indexOfSelectedItem - 1
        let prefix = prefixes.indices.contains(chosen) ? prefixes[chosen] : nil

        if folder.path == Paths.yokuro.path || folder.path.hasPrefix(Paths.yokuro.path + "/") {
            inform("Dossier réservé", "Le dossier Yokuro contient Temporaire et les rapports : il ne se trie pas.")
            return
        }
        computePlan(root: folder, destination: intoDownloads ? Paths.downloads : folder, prefix: prefix) { [weak self] actions in
            guard let self = self else { return }
            if actions.isEmpty {
                self.inform("Rien à ranger", "« \(folder.lastPathComponent) » est déjà propre.")
            } else {
                self.showReview(actions, folder: folder)
            }
        }
    }

    /// Exécute les actions validées, purge Temporaire et écrit le rapport. Les échecs sont signalés.
    private func finish(_ actions: [PlannedAction], folder: URL? = nil) {
        let retentionDays = store.config.retentionDays
        let renames = store.takeRenameLog()
        work.async {
            let result = Engine.execute(actions)
            let purged = Engine.purge(retentionDays: retentionDays)
            Engine.writeReport(result: result, renames: renames, purged: purged,
                               retentionDays: retentionDays, folder: folder)
            guard !result.errors.isEmpty else { return }
            let shown = result.errors.prefix(5).joined(separator: "\n")
            DispatchQueue.main.async {
                self.inform("Certaines actions ont échoué",
                            shown + "\n\nLe détail est dans le rapport, dossier Yokuro > Rapport.")
            }
        }
    }

    // MARK: Couleur des dossiers

    private var icons: [String: NSImage] = [:]
    private var recolor: DispatchWorkItem?

    /// Icône de dossier du système, teintée de la couleur choisie. Calculée une fois par couleur.
    private func folderIcon(_ color: String) -> NSImage? {
        if let icon = icons[color] { return icon }
        guard let base = NSImage(named: NSImage.folderName) else { return nil }
        let size = NSSize(width: 512, height: 512)
        let rect = NSRect(origin: .zero, size: size)
        let image = NSImage(size: size)
        let rgb = FolderColors.rgb(color)
        image.lockFocus()
        base.draw(in: rect)
        // Teinte et saturation de la couleur, luminosité de l'icône d'origine : reliefs et ombres conservés.
        NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1).setFill()
        rect.fill(using: .color)
        base.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
        image.unlockFocus()
        icons[color] = image
        return image
    }

    /// Dossiers dont Yokuro a posé l'icône, avec sa couleur.
    private var tinted: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "tintedFolders") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "tintedFolders") }
    }

    /// Donne au dossier l'icône de la couleur choisie. Un tag ne teinte pas l'icône d'un dossier dans le Finder :
    /// il faut une icône personnalisée. Une icône posée par quelqu'un d'autre que Yokuro n'est pas touchée.
    private func tint(_ folder: URL) {
        let color = store.config.folderColor
        let hasIcon = FileManager.default.fileExists(atPath: folder.appendingPathComponent("Icon\r").path)
        // Icône déjà là : posée par quelqu'un d'autre, ou déjà de la bonne couleur.
        if hasIcon && (tinted[folder.path] ?? color) == color { return }
        guard let icon = folderIcon(color),
              NSWorkspace.shared.setIcon(icon, forFile: folder.path, options: []) else { return }
        tinted[folder.path] = color
    }

    /// Les 0.12 et 0.13 posaient des icônes vertes sans les noter : on les reprend une fois.
    private func adoptTintedFolders() {
        guard UserDefaults.standard.object(forKey: "tintedFolders") == nil else { return }
        var adopted: [String: String] = [:]
        var folders = Paths.managed.map { Paths.downloads.appendingPathComponent($0) }
        folders += Engine.scan(in: Paths.downloads.appendingPathComponent(Paths.json)).filter { $0.isDir }.map { $0.url }
        for folder in folders where FileManager.default.fileExists(atPath: folder.appendingPathComponent("Icon\r").path) {
            adopted[folder.path] = "green"
        }
        tinted = adopted
    }

    /// Nouvelle couleur : dossiers et fichiers rangés sont recolorés, une fois le choix arrêté
    /// (le sélecteur de couleur en envoie une à chaque mouvement).
    private func scheduleRecolor() {
        recolor?.cancel()
        let job = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            Engine.tagNumber = FolderColors.tagNumber(self.store.config.folderColor)
            self.work.async { Engine.markManagedFolders() }
        }
        recolor = job
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: job)
    }

    // MARK: Fenêtres

    private func showReview(_ actions: [PlannedAction], folder: URL? = nil) {
        reviewWindow?.close()
        let view = ReviewView(
            model: ReviewModel(actions: actions),
            onValidate: { [weak self] chosen in
                self?.reviewWindow?.close()
                self?.finish(chosen, folder: folder)
            },
            onCancel: { [weak self] in self?.reviewWindow?.close() }
        )
        let title = folder.map { "Yokuro : tri de « \($0.lastPathComponent) »" } ?? "Yokuro : changements à valider"
        reviewWindow = makeWindow(view, title: title, size: NSSize(width: 720, height: 620), resizable: true)
        show(reviewWindow)
    }

    private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(SettingsView(store: store), title: "Réglages Yokuro",
                                        size: NSSize(width: 660, height: 720), resizable: false)
        }
        show(settingsWindow)
    }

    private func makeWindow<Content: View>(_ view: Content, title: String, size: NSSize, resizable: Bool) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: resizable ? [.titled, .closable, .resizable] : [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: view)
        window.setContentSize(size)
        window.center()
        return window
    }

    private func show(_ window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func inform(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}
