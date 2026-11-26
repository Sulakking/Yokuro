import SwiftUI

// MARK: - État et actions de la pop-in

enum Snooze {
    case hours(Int)
    case tomorrow
}

/// La case de « Quelle catégorie projet ? ».
struct AssignOptions {
    var sticky = false // « Renommer avec la même catégorie », pour la durée réglée ou jusqu'à désactivation
}

/// Pause ou renommage d'office en cours, et le libellé du bouton qui l'arrête.
struct Pause {
    let text: String
    let stop: String
}

/// Tout ce que la pop-in peut demander à l'app.
enum PopoverAction {
    case choose(Project?) // projet du fichier en attente ; nil : aucun projet
    case addProject(String)
    case deleteProject(UUID)
    case renameRecent
    case cancelBatch
    case run
    case snooze(Snooze)
    case renameFile // renomme le fichier affiché avec le nom saisi
    case pause // met la pop-in en pause jusqu'à la reprise, ou la reprend
    case resume
    case sortFolder
    case open(URL)
    case settings
    case quit
}

/// Routine planifiée arrivée à son heure, en attente d'une réponse.
struct Due {
    let deletes: Int
    let moves: Int
}

final class PopoverModel: ObservableObject {
    /// Fichiers arrivés dont le projet est à choisir. Le premier est affiché, son nom est modifiable.
    @Published var pending: [String] = [] {
        didSet { if pending.first != oldValue.first { fileName = pending.first ?? "" } }
    }
    @Published var fileName = ""
    @Published var stickyEnd: Date?        // fin du renommage d'office s'il était lancé maintenant
    @Published var batch: [String]?       // « Renommer les derniers fichiers » : un seul choix pour tous
    @Published var due: Due?
    @Published var options = AssignOptions()

    // Rafraîchi à chaque ouverture
    @Published var fileCount = 0
    @Published var nextRun = ""
    @Published var pause: Pause?
    @Published var paused = false
    @Published var lastPrefix: String?    // dernière catégorie choisie, gardée en mémoire
    @Published var recentCount = 0
    @Published var canRead = true
}

// MARK: - Boutons

enum Palette {
    static let blue = Color(red: 0, green: 0.49, blue: 1)                // #007DFF
    static let fieldDark = Color(red: 0.32, green: 0.33, blue: 0.34)     // #525357
    static let fieldLight = Color(red: 0.90, green: 0.90, blue: 0.92)
}

extension View {
    /// Liquid Glass natif à partir de macOS 26 (Tahoe) ; matériau translucide classique avant.
    func glass(cornerRadius: CGFloat) -> AnyView {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            return AnyView(glassEffect(.regular.interactive(), in: shape))
        }
        #endif
        return AnyView(background(.ultraThinMaterial, in: shape))
    }
}

/// Bouton de la pop-in : 44 pt de haut, coins de 12 pt.
/// Principal : fond bleu. Secondaire : Liquid Glass, avec un fin contour pour rester bien visible.
struct PillButton<Content: View>: View {
    var primary = false
    var height: CGFloat? = 44
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let button = Button(action: action) {
            HStack(spacing: 6) { content() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(primary ? Color.white : Color.primary)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if primary {
            return AnyView(button.background(Palette.blue, in: shape))
        }
        return AnyView(button.glass(cornerRadius: 12)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.35), lineWidth: 0.5)))
    }
}

/// Champ de saisie de la pop-in : 44 pt, fond gris, fin contour.
struct InputField: View {
    let placeholder: String
    @Binding var text: String
    let onSubmit: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(scheme == .dark ? Palette.fieldDark : Palette.fieldLight, in: shape)
            .overlay(shape.strokeBorder(scheme == .dark ? Color.white : Color.black, lineWidth: 0.5))
            .onSubmit(onSubmit)
    }
}

/// Titre de la pop-in, avec Réglages et Quitter à droite.
struct Header: View {
    let title: String
    var onBack: (() -> Void)? = nil
    let paused: Bool
    let act: (PopoverAction) -> Void

    var body: some View {
        HStack(spacing: 16) {
            if let onBack = onBack {
                Button(action: onBack) { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                    .help("Revenir")
            }
            Text(title).font(.system(size: 16, weight: .bold))
            Spacer()
            Button { act(.pause) } label: { Image(systemName: paused ? "play" : "pause") }
                .buttonStyle(.borderless)
                .help(paused ? "Reprendre" : "Pause de 30 minutes")
            Button { act(.settings) } label: { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("Réglages")
            Button { act(.quit) } label: { Image(systemName: "power") }
                .buttonStyle(.borderless)
                .help("Quitter Yokuro")
        }
    }
}

/// Texte secondaire : 13 pt, demi-opacité.
struct Note: View {
    let text: Text
    init(_ text: Text) { self.text = text }
    init(_ string: String) { self.text = Text(string) }

    var body: some View {
        text.font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primary.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Pop-in

/// Trois états, du plus prioritaire au moins prioritaire : renommage groupé, fichier à classer, raccourcis.
struct PopoverRoot: View {
    @ObservedObject var model: PopoverModel
    @ObservedObject var store: Store
    let act: (PopoverAction) -> Void

    private var projects: [Project] { store.config.projects.filter { !$0.prefix.isEmpty } }

    var body: some View {
        Group {
            if let batch = model.batch {
                AssignView(model: model,
                           subtitle: batch.count == 1 ? "1 fichier arrivé ces 30 dernières minutes"
                                                      : "\(batch.count) fichiers arrivés ces 30 dernières minutes",
                           isBatch: true, projects: projects, act: act)
            } else if let file = model.pending.first {
                AssignView(model: model, subtitle: file, isBatch: false, projects: projects, act: act)
            } else {
                ShortcutsView(model: model, act: act)
            }
        }
        .padding(16)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// « Quelle catégorie projet ? » : pour le fichier qui vient d'arriver, ou pour tous les fichiers récents d'un coup.
/// Fermer la pop-in sans choisir laisse le fichier sans projet, sauf si une case est cochée.
struct AssignView: View {
    @ObservedObject var model: PopoverModel
    let subtitle: String
    let isBatch: Bool
    let projects: [Project]
    let act: (PopoverAction) -> Void

    @State private var newProject = ""

    private var trimmed: String { newProject.trimmingCharacters(in: .whitespaces) }

    /// Ce qui est tapé dans « Nouveau Projet » filtre aussi la liste.
    private var shown: [Project] {
        guard !trimmed.isEmpty else { return projects }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return projects.filter {
            $0.prefix.range(of: trimmed, options: options) != nil || $0.name.range(of: trimmed, options: options) != nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header(title: "Quelle catégorie projet ?", onBack: isBatch ? { act(.cancelBatch) } : nil,
                   paused: model.paused, act: act)
            if isBatch {
                Note(subtitle)
            } else {
                // Nom du fichier modifiable : Entrée renomme tout de suite, un choix de catégorie aussi.
                InputField(placeholder: "Nom du fichier", text: $model.fileName) { act(.renameFile) }
            }

            // Liste compacte et défilante : six lignes et demie visibles, la demie signale qu'il y en a d'autres.
            if !shown.isEmpty {
                let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(shown) { project in
                            ProjectRow(project: project, act: act)
                            if project.id != shown.last?.id { Divider() }
                        }
                    }
                }
                .frame(height: min(CGFloat(shown.count), 6.5) * 37)
                .clipShape(shape)
                .glass(cornerRadius: 12)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.35), lineWidth: 0.5))
            }

            HStack(spacing: 16) {
                InputField(placeholder: "Nouveau Projet", text: $newProject) { add() }
                PillButton(primary: true, action: add) { Text("Ajouter") }
                    .fixedSize()
                    .disabled(trimmed.isEmpty)
            }

            if !isBatch {
                Toggle(isOn: $model.options.sticky) {
                    Note(model.stickyEnd.map { "Renommer avec la même catégorie jusqu’à \(Fmt.time.string(from: $0))" }
                         ?? "Renommer avec la même catégorie")
                }
                .toggleStyle(.checkbox)
                // Une case cochée s'applique aussi en fermant la pop-in sans rien choisir.
                if model.options.sticky {
                    Note(model.lastPrefix.map { "Sans choix, la dernière catégorie s’appliquera : \($0)" }
                         ?? "Choisis une catégorie pour lancer le renommage")
                }
            }
        }
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        act(.addProject(trimmed))
        newProject = ""
    }
}

/// Une catégorie de la liste : un clic la choisit, le « - » la supprime.
struct ProjectRow: View {
    let project: Project
    let act: (PopoverAction) -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button { act(.choose(project)) } label: {
                HStack {
                    Text(project.prefix)
                    Spacer()
                    if project.name != project.prefix {
                        Text(project.name).foregroundStyle(Color.primary.opacity(0.5))
                    }
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { act(.deleteProject(project.id)) } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .help("Supprimer la catégorie")
        }
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(hovering ? Color.primary.opacity(0.08) : Color.clear, in: Rectangle())
        .onHover { hovering = $0 }
    }
}

/// Raccourcis, et demande de validation quand la routine est arrivée à son heure.
struct ShortcutsView: View {
    @ObservedObject var model: PopoverModel
    let act: (PopoverAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header(title: "Yokuro", paused: model.paused, act: act)

            if !model.canRead {
                Text("Yokuro n’a pas accès à Téléchargements. Autorise-le dans Réglages Système > Confidentialité et sécurité > Fichiers et dossiers")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.red)
            } else if let due = model.due {
                Note("C’est l’heure du rangement : \(due.deletes) à supprimer, \(due.moves) à déplacer")
            } else {
                VStack(spacing: 0) {
                    Note(Text(model.fileCount == 1 ? "1 élément dans " : "\(model.fileCount) éléments dans ")
                         + Text("Téléchargements").italic())
                    Note("Prochaine routine : \(model.nextRun)")
                }
            }

            if let pause = model.pause {
                Note(pause.text)
                PillButton(action: { act(.resume) }) { Text(pause.stop) }
            }

            HStack(spacing: 16) {
                tile("Téléchargements", "arrow.down.circle", .open(Paths.downloads))
                tile("Trier autre dossier", "folder", .sortFolder)
            }

            PillButton(primary: true, action: { act(.run) }) {
                Image(systemName: "wand.and.stars")
                Text(model.due == nil ? "Ranger maintenant" : "Voir et valider")
            }

            // On ne peut reporter que ce qui est dû : hors de l'heure de routine, la ligne n'a pas de sens.
            if model.due != nil {
                Note("Reporter")
                HStack(spacing: 8) {
                    PillButton(action: { act(.snooze(.hours(1))) }) { Text("1 h") }
                    PillButton(action: { act(.snooze(.hours(2))) }) { Text("2 h") }
                    PillButton(action: { act(.snooze(.hours(3))) }) { Text("3 h") }
                    PillButton(action: { act(.snooze(.tomorrow)) }) { Text("Demain") }
                }
            }

            PillButton(action: { act(.renameRecent) }) {
                Text("Renommer les derniers fichiers")
                Spacer()
                Text("\(model.recentCount)").font(.system(size: 14, weight: .semibold))
            }
            .disabled(model.recentCount == 0)
            .opacity(model.recentCount == 0 ? 0.5 : 1)
        }
    }

    private func tile(_ title: String, _ symbol: String, _ action: PopoverAction) -> some View {
        PillButton(height: nil, action: { act(action) }) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 18))
                Text(title).lineLimit(1)
            }
            .padding(.vertical, 12)
        }
    }
}
