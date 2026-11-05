import SwiftUI

struct MouseWindowSettingsSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(MouseWindowCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var settings = settings
        Section {
            Toggle(isOn: Binding(get: { settings.mouseWindowEnabled }, set: { coordinator.setEnabled($0) })) {
                SettingsRowTitle(.windowManagementMouse, "Enable mouse controls")
                Text("Move and resize windows from anywhere inside them.")
            }
            Group {
                trigger(.move, title: "Move window", encoded: settings.mouseWindowMoveTrigger)
                trigger(.resize, title: "Resize window", encoded: settings.mouseWindowResizeTrigger)
                Toggle(isOn: $settings.mouseWindowQuadrants) {
                    SettingsRowTitle(.windowManagementMouse, "Use quadrants")
                    Text("Resize from the nearest edge or corner, or symmetrically from the center.")
                }
                Toggle(isOn: $settings.mouseWindowFocus) {
                    SettingsRowTitle(.windowManagementMouse, "Focus on window")
                }
                Toggle(isOn: $settings.mouseWindowSnap) {
                    SettingsRowTitle(.windowManagementMouse, "Snap to nearby windows")
                }
                if let message = coordinator.message {
                    Text(message).foregroundStyle(.secondary)
                }
            }
            .settingsEnabled(settings.mouseWindowEnabled)
        } header: {
            SettingsSectionHeader(.windowManagementMouse)
        } footer: {
            Text("Hold a shortcut while moving the pointer. Mouse-only gestures require both buttons.")
        }
        DisabledApplicationsSection(bundleIDs: $settings.mouseWindowExcludedApps,
            anchor: .windowManagementMouseExcluded,
            footer: String(localized: "Mouse controls ignore these apps."))
            .settingsEnabled(settings.mouseWindowEnabled)
    }

    private func trigger(
        _ action: MouseWindowGeometry.Action, title: LocalizedStringResource, encoded: [Int]
    ) -> some View {
        SettingsRow(title: String(localized: title)) {
            HStack {
                MouseWindowShortcutRecorder(encoded: encoded,
                    onChange: { coordinator.setTrigger($0, for: action) },
                    onRecording: { coordinator.setRecording($0) })
                    .frame(width: 120)
                    .accessibilityLabel(Text(title))
                Picker("Mouse button", selection: Binding(
                    get: { encoded.count == 3 ? encoded[2] : 0 },
                    set: { buttons in
                        let value = encoded.count == 3 ? [encoded[0], encoded[1], buttons] : [0, -1, buttons]
                        coordinator.setTrigger(value, for: action)
                    })) {
                    Text("None").tag(0)
                    Text("Left").tag(1)
                    Text("Right").tag(2)
                    Text("Both").tag(3)
                }
                .labelsHidden()
                .fixedSize()
                .help("Mouse button")
                Button("Clear") { coordinator.setTrigger([], for: action) }
            }
            .fixedSize()
        }
    }
}
