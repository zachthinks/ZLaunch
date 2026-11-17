import AppKit
import SwiftUI

struct SecureItemEditor: View {
    @Environment(SecureItemsCoordinator.self) private var coordinator
    @Environment(PaletteState.self) private var palette
    @Environment(\.metrics) private var metrics
    @State private var tagsText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.spacing.md) {
            Text("Name").font(metrics.typography.rowTitle)
            field(text: coordinator.draft?.name ?? "", label: String(localized: "Name"), index: 0,
                  singleLine: true, changed: { coordinator.updateDraft(name: $0) })
                .frame(height: metrics.size.dialogButtonHeight)
            Text("Value").font(metrics.typography.rowTitle)
            field(text: coordinator.draft?.value ?? "", label: String(localized: "Value"), index: 1,
                  changed: { coordinator.updateDraft(value: $0) })
                .frame(minHeight: 100)
            Text("Tags").font(metrics.typography.rowTitle)
            field(text: tagsText, label: String(localized: "Tags"), index: 2, singleLine: true,
                  changed: { tagsText = $0; coordinator.updateTags($0) })
                .frame(height: metrics.size.dialogButtonHeight)
            Text("Separate tags with commas, for example: work, hosting.")
                .font(metrics.typography.rowTrailing).foregroundStyle(Theme.Colors.textSecondary)
            HStack {
                Button("Cancel") { coordinator.cancelEditing() }
                Spacer()
                Button("Save") { coordinator.save() }
                    .buttonStyle(.borderedProminent).disabled(coordinator.draft?.isValid != true)
            }
        }
        .padding(metrics.spacing.xl)
        .disabled(coordinator.isBusy)
        .onAppear {
            tagsText = coordinator.draft?.tags.joined(separator: ", ") ?? ""
            palette.noteEditingField(true)
        }
        .onDisappear { palette.noteEditingField(false) }
    }

    private func field(text: String, label: String, index: Int, singleLine: Bool = false,
                       changed: @escaping (String) -> Void) -> some View {
        SecureItemTextArea(
            text: text, label: label, singleLine: singleLine, focused: coordinator.editorField == index,
            gainedFocus: { coordinator.editorField = index },
            moveFocus: { backwards in coordinator.editorField = (index + (backwards ? 2 : 1)) % 3 },
            changed: changed, copy: { coordinator.copyText($0) })
            .padding(metrics.spacing.sm)
            .background(Theme.Colors.controlSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.formField))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.formField).stroke(
                coordinator.editorField == index ? Theme.Colors.textSecondary : Theme.Colors.separator))
    }
}

private struct SecureItemTextArea: NSViewRepresentable {
    let text: String
    let label: String
    var singleLine = false
    let focused: Bool
    let gainedFocus: () -> Void
    let moveFocus: (Bool) -> Void
    let changed: (String) -> Void
    let copy: (String) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        let editor = SecureValueTextView()
        editor.isRichText = false
        editor.drawsBackground = false
        editor.singleLine = singleLine
        editor.setAccessibilityLabel(label)
        editor.allowsUndo = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticDataDetectionEnabled = false
        editor.writingToolsBehavior = .none
        editor.isGrammarCheckingEnabled = false
        editor.font = singleLine ? .systemFont(ofSize: NSFont.systemFontSize)
            : .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.isEditable = context.environment.isEnabled
        editor.wantsFocus = focused
        editor.gainedFocus = gainedFocus
        editor.moveFocus = moveFocus
        editor.changed = changed
        editor.secureCopy = copy
        editor.string = text
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? SecureValueTextView else { return }
        editor.isEditable = context.environment.isEnabled
        editor.wantsFocus = focused
        editor.gainedFocus = gainedFocus
        editor.moveFocus = moveFocus
        editor.changed = changed
        editor.secureCopy = copy
        if editor.string != text { editor.string = text }
        editor.updateFocus()
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

    var wantsFocus = false
    var gainedFocus: (() -> Void)?
    var moveFocus: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        gainedFocus?()
        return true
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); updateFocus() }
    func updateFocus() {
        if wantsFocus, isEditable, window?.firstResponder !== self { window?.makeFirstResponder(self) }
    }
    override func insertTab(_ sender: Any?) { moveFocus?(false) }
    override func insertBacktab(_ sender: Any?) { moveFocus?(true) }
    override func insertNewline(_ sender: Any?) {
        if singleLine { moveFocus?(false) } else { super.insertNewline(sender) }
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
