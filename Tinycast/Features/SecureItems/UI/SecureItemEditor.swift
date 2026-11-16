import AppKit
import SwiftUI

struct SecureItemEditor: View {
    @Environment(SecureItemsCoordinator.self) private var coordinator
    @Environment(\.metrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.spacing.lg) {
            Text("Name")
            SecureItemTextArea(
                text: coordinator.draft?.name ?? "", singleLine: true,
                changed: { coordinator.updateDraft(name: $0) },
                copy: { coordinator.clipboard.copy($0); coordinator.touch() })
                .frame(height: 28)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.formField).stroke(Theme.Colors.separator))
            Text("Value")
            SecureItemTextArea(
                text: coordinator.draft?.value ?? "",
                changed: { coordinator.updateDraft(value: $0) },
                copy: { coordinator.clipboard.copy($0); coordinator.touch() })
                .frame(minHeight: 100)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.formField).stroke(Theme.Colors.separator))
            HStack {
                Button("Cancel") { coordinator.cancelEditing() }
                Spacer()
                Button("Save") { coordinator.save() }.disabled(coordinator.draft?.isValid != true)
            }
        }
        .padding(metrics.spacing.xl)
        .disabled(coordinator.isBusy)
    }
}

private struct SecureItemTextArea: NSViewRepresentable {
    let text: String
    var singleLine = false
    let changed: (String) -> Void
    let copy: (String) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        let editor = SecureValueTextView()
        editor.isRichText = false
        editor.singleLine = singleLine
        editor.setAccessibilityLabel(singleLine ? String(localized: "Name") : String(localized: "Value"))
        editor.allowsUndo = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticDataDetectionEnabled = false
        editor.writingToolsBehavior = .none
        editor.isGrammarCheckingEnabled = false
        editor.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.isEditable = context.environment.isEnabled
        editor.changed = changed
        editor.secureCopy = copy
        editor.string = text
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? SecureValueTextView else { return }
        editor.isEditable = context.environment.isEnabled
        editor.changed = changed
        editor.secureCopy = copy
        if editor.string != text { editor.string = text }
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: ()) {
        guard let editor = scroll.documentView as? SecureValueTextView else { return }
        editor.string = ""
        editor.changed = nil
        editor.secureCopy = nil
    }
}

private final class SecureValueTextView: NSTextView {
    var singleLine = false
    var changed: ((String) -> Void)?
    var secureCopy: ((String) -> Void)?

    override func insertNewline(_ sender: Any?) {
        if singleLine { window?.selectNextKeyView(sender) } else { super.insertNewline(sender) }
    }
    override func didChangeText() { super.didChangeText(); changed?(string) }
    override func copy(_ sender: Any?) {
        secureCopy?((string as NSString).substring(with: selectedRange()))
    }
    override func cut(_ sender: Any?) { copy(sender); delete(sender) }
    override func menu(for event: NSEvent) -> NSMenu? { nil }
    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool { false }
    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?,
                                 returnType: NSPasteboard.PasteboardType?) -> Any? { nil }
}
