import SwiftUI

struct ShortcutPaletteActionPicker: View {
    @Environment(\.dismiss) private var dismiss
    let actions: [AppEntry]
    let destination: String
    let capacity: Int
    let onAdd: ([AppEntry]) throws -> Void
    let onWebsite: () -> Void
    @State private var type = ActionType.command
    @State private var search = ""
    @State private var selected: Set<String> = []
    @State private var failure: String?
    enum ActionType: String, CaseIterable, Identifiable {
        case application = "Open an app"
        case website = "Open a website"
        case command = "Run a ZLaunch command"
        case appAction = "Use an app action"
        case workflow = "Run a shortcut or workflow"
        var id: Self { self }
        var searchPrompt: String {
            switch self {
            case .application: "Search apps…"
            case .website: "Website address"
            case .command: "Search commands or categories…"
            case .appAction: "Search app actions…"
            case .workflow: "Search shortcuts and workflows…"
            }
        }

        func includes(_ kind: AppEntry.Kind) -> Bool {
            switch self {
            case .application: kind == .application
            case .website: false
            case .workflow: kind == .appleShortcut || kind == .customCommand
            case .appAction: kind == .extensionCommand || kind == .quicklink
            case .command:
                ![.application, .appleShortcut, .customCommand, .extensionCommand, .quicklink].contains(kind)
            }
        }
    }

    static func sections(
        actions: [AppEntry], type: ActionType, search: String
    ) -> [(kind: AppEntry.Kind, entries: [AppEntry])] {
        let terms = search.split(whereSeparator: \.isWhitespace).map(String.init)
        let filtered = actions.filter { entry in
            let fields = [entry.name, entry.kindLabel, entry.kind.descriptor.sectionTitle]
            return type.includes(entry.kind) && terms.allSatisfy { term in
                fields.contains { $0.localizedCaseInsensitiveContains(term) }
            }
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let grouped = Dictionary(grouping: filtered, by: \.kind)
        return AppEntry.Kind.allCases.compactMap { kind in
            guard let entries = grouped[kind] else { return nil }
            return (kind: kind, entries: entries)
        }
        .sorted {
            $0.kind.descriptor.sectionTitle.localizedCaseInsensitiveCompare(
                $1.kind.descriptor.sectionTitle) == .orderedAscending
        }
    }

    private var sections: [(kind: AppEntry.Kind, entries: [AppEntry])] {
        Self.sections(actions: actions, type: type, search: search)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add actions to \(destination)").font(.title2.bold())
            Text("Choose several actions, then add them together. Unused keys are assigned automatically.")
                .foregroundStyle(.secondary)
            Picker("Browse", selection: $type) {
                ForEach(ActionType.allCases.filter { $0 != .website }) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search actions or categories…", text: $search).textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }
            .padding(10)
            .background(Theme.Colors.controlSurface, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Colors.border))
            List {
                ForEach(sections, id: \.kind) { section in
                    Section(section.kind.descriptor.sectionTitle) {
                        ForEach(section.entries) { entry in
                            Toggle(isOn: Binding(
                                get: { selected.contains(entry.id) },
                                set: { included in
                                    if included { selected.insert(entry.id) } else { selected.remove(entry.id) }
                                    failure = nil
                                })) {
                                HStack(spacing: 10) {
                                    AppIconView(app: entry, pointSize: 24).frame(width: 24, height: 24)
                                    Text(entry.name)
                                    Spacer()
                                }
                            }
                            .toggleStyle(.checkbox)
                            .disabled(!selected.contains(entry.id) && selected.count >= capacity)
                        }
                    }
                }
            }
            .overlay {
                if sections.isEmpty { ContentUnavailableView.search(text: search) }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.Colors.border))
            HStack {
                Text("\(selected.count) selected · \(capacity) available keys")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Clear Selection") { selected.removeAll() }.disabled(selected.isEmpty)
            }
            if let failure {
                Label(failure, systemImage: "exclamationmark.circle").foregroundStyle(Theme.Colors.warning)
            }
            HStack {
                Button("Add Website…") { onWebsite() }.disabled(!selected.isEmpty)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(selected.count == 1 ? "Add 1 Action" : "Add \(selected.count) Actions") {
                    let entries = actions.filter { selected.contains($0.id) }
                        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    do { try onAdd(entries) } catch { failure = error.localizedDescription }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty || selected.count > capacity)
            }
        }
        .padding(24).frame(width: 620, height: 620)
    }
}
