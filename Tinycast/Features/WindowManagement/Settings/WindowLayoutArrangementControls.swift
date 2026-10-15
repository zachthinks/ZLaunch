import SwiftUI

struct WindowLayoutArrangementControls: View {
    let draft: WindowLayoutDraft
    let screens: [WindowLayoutScreen]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Picker("Arrangement", selection: Binding(
                    get: { draft.selectedArrangementID }, set: { draft.selectArrangement($0) }
                )) {
                    Text("Default").tag(UUID?.none)
                    ForEach(draft.arrangements) { arrangement in
                        Text(arrangement.name).tag(Optional(arrangement.id))
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Arrangement")
                Button("Save setup") { draft.createArrangement(displays: screens.map(\.snapshot)) }
                    .disabled(draft.entries.isEmpty || screens.isEmpty)
                    .help("Copy this arrangement for exactly the currently connected displays")
            }
            if draft.selectedArrangementID != nil {
                HStack {
                    TextField("Arrangement name", text: Binding(
                        get: { draft.arrangementName }, set: { draft.arrangementName = $0 }))
                    Button("Remove", role: .destructive) { draft.removeArrangement() }
                }
                Text("Matches: \(matchNames). Selected only when you run this layout.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Default is used when no saved setup matches the connected displays.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var matchNames: String {
        guard let value = draft.arrangements.first(where: { $0.id == draft.selectedArrangementID }) else { return "" }
        return value.displayIDs.map { id in value.displays.first { $0.id == id.lowercased() }?.display.name ?? id }
            .joined(separator: ", ")
    }
}
