import AppKit
import SwiftUI

// MARK: - Review des changements

final class ReviewModel: ObservableObject {
    @Published var actions: [PlannedAction]

    init(actions: [PlannedAction]) { self.actions = actions }

    var count: Int { actions.filter { $0.enabled }.count }

    func setAll(_ enabled: Bool) {
        for index in actions.indices { actions[index].enabled = enabled }
    }
}

struct ActionRow: View {
    @Binding var action: PlannedAction

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: $action.enabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
            VStack(alignment: .leading, spacing: 4) {
                Text(action.source.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(action.detail)
                    .foregroundStyle(.secondary)
                if action.kind != .delete {
                    TextField("Nom du fichier", text: $action.newName)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!action.enabled)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(action.enabled ? 1 : 0.5)
    }
}

/// Rien n'est touché avant « Valider » : chaque ligne se décoche, chaque nom se modifie.
struct ReviewView: View {
    @ObservedObject var model: ReviewModel
    let onValidate: ([PlannedAction]) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            List {
                section("À supprimer", kind: .delete)
                section("À déplacer", kind: .move)
                section("À renommer", kind: .rename)
            }
            Divider()
            HStack {
                Button("Tout cocher") { model.setAll(true) }
                Button("Tout décocher") { model.setAll(false) }
                Spacer()
                Button("Annuler", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Valider (\(model.count))") { onValidate(model.actions.filter { $0.enabled }) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.count == 0)
            }
            .padding(16)
        }
        .frame(minWidth: 620, minHeight: 480)
    }

    @ViewBuilder
    private func section(_ title: String, kind: ActionKind) -> some View {
        if model.actions.contains(where: { $0.kind == kind }) {
            Section(title) {
                ForEach($model.actions) { $action in
                    if action.kind == kind {
                        ActionRow(action: $action)
                    }
                }
            }
        }
    }
}

// MARK: - Réglages

struct SettingsView: View {
    @ObservedObject var store: Store

    var body: some View {
        Form {
            Section("Routine") {
                Picker("Heure", selection: $store.config.hour) {
                    ForEach(0..<24, id: \.self) { Text("\($0) h").tag($0) }
                }
                Picker("Minutes", selection: $store.config.minute) {
                    ForEach([0, 15, 30, 45], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }
                Stepper("Conservation dans Fichiers temporaires : \(store.config.retentionDays) jours",
                        value: $store.config.retentionDays, in: 1...60)
                Toggle("Lancer Yokuro à l’ouverture de session", isOn: $store.config.launchAtLogin)
            }

            Section("À l’arrivée d’un fichier") {
                Toggle("Demander le projet dans la pop-in", isOn: $store.config.askOnArrival)
                Toggle("Préfixer sans demander quand un mot-clé est reconnu", isOn: $store.config.renameOnArrival)
                Picker("Durée de « Renommer avec la même catégorie »", selection: $store.config.stickyMinutes) {
                    ForEach([30, 60, 120, 240, 480], id: \.self) { minutes in
                        Text(minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h").tag(minutes)
                    }
                }
                .disabled(store.config.stickyUnlimited)
                Toggle("Renommer jusqu’à désactivation", isOn: $store.config.stickyUnlimited)
                Toggle("Ne pas ouvrir la pop-in en mode Concentration ou Ne pas déranger", isOn: $store.config.respectFocus)
                if store.config.respectFocus && Focus.isActive() == nil {
                    HStack {
                        Text("Pour lire l’état de Concentration, Yokuro a besoin de l’accès complet au disque.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Ouvrir les réglages") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }

            Section("Projets : préfixe, nom du dossier, mots-clés facultatifs séparés par des virgules") {
                ForEach(store.config.projects) { project in
                    HStack {
                        TextField("Préfixe", text: binding(project.id).prefix, prompt: Text("Préfixe"))
                            .frame(width: 70)
                        TextField("Nom du projet", text: binding(project.id).name, prompt: Text("Nom du dossier"))
                            .frame(width: 160)
                        TextField("Mots-clés", text: binding(project.id).keywords, prompt: Text("Mots-clés"))
                        Button {
                            let id = project.id
                            store.config.projects.removeAll { $0.id == id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                    .labelsHidden()
                }
                Button("Ajouter un projet") {
                    store.config.projects.append(Project(name: "", prefix: ""))
                }
            }

            Section("Couleur des dossiers de Yokuro et des fichiers rangés") {
                HStack(spacing: 10) {
                    ForEach(FolderColors.presets) { preset in
                        Button { store.config.folderColor = preset.id } label: {
                            Circle()
                                .fill(Color(red: preset.red, green: preset.green, blue: preset.blue))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(Color.primary,
                                                               lineWidth: store.config.folderColor == preset.id ? 2 : 0))
                        }
                        .buttonStyle(.plain)
                        .help(preset.name)
                    }
                    Spacer()
                    ColorPicker("Autre couleur", selection: customColor, supportsOpacity: false)
                }
                Text("Les fichiers gardent le tag du Finder le plus proche de cette couleur.")
                    .foregroundStyle(.secondary)
            }

            Section("Routines actives") {
                ForEach(Routine.allCases, id: \.self) { routine in
                    Toggle(routine.label, isOn: Binding(
                        get: { store.config.isOn(routine) },
                        set: { store.config.set(routine, $0) }
                    ))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 660, height: 720)
    }

    /// Couleur libre du sélecteur, enregistrée en « #RRGGBB ».
    private var customColor: Binding<Color> {
        Binding(
            get: {
                let rgb = FolderColors.rgb(store.config.folderColor)
                return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
            },
            set: { color in
                guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
                store.config.folderColor = FolderColors.hex(red: Double(srgb.redComponent), green: Double(srgb.greenComponent),
                                                            blue: Double(srgb.blueComponent))
            }
        )
    }

    /// Liaison par identifiant : reste valide quand un projet est supprimé pendant la saisie.
    private func binding(_ id: UUID) -> Binding<Project> {
        Binding(
            get: { store.config.projects.first { $0.id == id } ?? Project(name: "", prefix: "") },
            set: { newValue in
                if let index = store.config.projects.firstIndex(where: { $0.id == id }) {
                    store.config.projects[index] = newValue
                }
            }
        )
    }
}
