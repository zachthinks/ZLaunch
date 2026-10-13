import SwiftUI

struct WindowLayoutDestinationFields: View {
    let draft: WindowLayoutDraft
    let screens: [WindowLayoutScreen]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Screen and Space").font(.callout.weight(.medium))
            WindowLayoutDestinationPicker(
                title: entry.display.name, selectedID: entry.display.uuid,
                choices: displays.map { .init(id: $0.uuid, title: $0.name) }
            ) { id in
                if let display = displays.first(where: { $0.uuid == id }) { draft.setDisplay(display) }
            }
            .accessibilityLabel("Preferred screen")
            spacePicker(number: entry.space, screen: preferredScreen, allowsCurrent: true,
                        select: draft.setSpace)
                .accessibilityLabel("Preferred Space")
            Toggle("Use fallback when screen is disconnected", isOn: Binding(
                get: { entry.fallbackSpace != nil }, set: { draft.setFallback(enabled: $0) }))
                .font(.caption)
                .toggleStyle(.switch)
                .controlSize(.small)
            if entry.fallbackSpace != nil {
                WindowLayoutDestinationPicker(
                    title: entry.fallbackDisplay?.name ?? "Built-in screen, or first available",
                    selectedID: entry.fallbackDisplay?.uuid ?? "automatic",
                    choices: [.init(id: "automatic", title: "Built-in screen, or first available")]
                        + displays.map { .init(id: $0.uuid, title: $0.name) }
                ) { id in
                    draft.setFallbackDisplay(displays.first { $0.uuid == id })
                }
                .accessibilityLabel("Fallback screen")
                spacePicker(number: entry.fallbackSpace, screen: fallbackScreen, allowsCurrent: false) {
                    if let number = $0 { draft.setFallbackSpace(number) }
                }
                .accessibilityLabel("Fallback Space")
            }
            Text("Spaces are regular Desktops in Mission Control. Create them there before running a layout.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !WindowSpaceAccess.isAvailable {
                Text("Moving between Spaces is unavailable on this macOS build.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func spacePicker(
        number: Int?, screen: WindowLayoutScreen?, allowsCurrent: Bool,
        select: @escaping (Int?) -> Void
    ) -> some View {
        let count = max(8, screen?.desktopIDs.count ?? 0, min(32, number ?? 1))
        let choices = (1...count).map {
            WindowLayoutDestinationPicker.Choice(id: String($0), title: spaceTitle($0, screen: screen))
        }
        return WindowLayoutDestinationPicker(
            title: number.map { spaceTitle($0, screen: screen) } ?? "Current Space",
            selectedID: number.map(String.init) ?? "current",
            choices: (allowsCurrent ? [.init(id: "current", title: "Current Space")] : []) + choices
        ) { select(Int($0)) }
    }

    private func spaceTitle(_ number: Int, screen: WindowLayoutScreen?) -> String {
        guard let screen else { return "Space \(number)" }
        return screen.desktopIDs.indices.contains(number - 1)
            ? "Space \(number)" : "Space \(number) · unavailable"
    }

    private var entry: WindowLayoutEntry {
        draft.selectedEntry ?? WindowLayoutEntry(bundleID: "", display: .init(uuid: "", name: ""))
    }

    private var displays: [WindowLayoutDisplay] {
        var result = draft.tabs(connected: screens.map(\.display))
        if let fallback = entry.fallbackDisplay, !result.contains(where: { $0.uuid == fallback.uuid }) {
            result.append(fallback)
        }
        return result
    }

    private var preferredScreen: WindowLayoutScreen? {
        screens.first { $0.display.uuid.lowercased() == entry.display.uuid.lowercased() }
    }

    private var fallbackScreen: WindowLayoutScreen? {
        screens.first { $0.display.uuid.lowercased() == entry.fallbackDisplay?.uuid.lowercased() }
            ?? screens.first(where: \.isBuiltin) ?? screens.first
    }
}
