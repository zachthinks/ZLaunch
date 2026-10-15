import CoreGraphics
import Foundation

/// One in-flight edit of a layout. Owned by the editor sheet and gone when it closes.
@MainActor
@Observable
final class WindowLayoutDraft {
    /// What the editor's steppers allow; the model itself accepts any fraction in 0…1.
    static let percentRange: ClosedRange<Int> = 5...100
    static let offsetRange: ClosedRange<Int> = -4000...4000

    /// Nil for a new layout; kept so saving an edit keeps the UUID and every reference on it.
    let existingID: UUID?
    let isCapture: Bool
    var name: String
    var iconSymbol: String?
    var usesPreferredGap: Bool
    private(set) var entries: [WindowLayoutEntry]
    private var frontmostEntryID: UUID?
    /// Identity, never an index: removing an entry must not strand a field's binding.
    private(set) var selectedEntryID: UUID?
    private(set) var selectedDisplayUUID: String?
    private(set) var previewSpace: Int?
    private(set) var arrangements: [WindowLayoutArrangement]
    private(set) var selectedArrangementID: UUID?
    private(set) var displaySnapshots: [WindowLayoutDisplaySnapshot]
    private var defaultEntries: [WindowLayoutEntry]
    private var defaultFrontmostEntryID: UUID?
    private var defaultDisplays: [WindowLayoutDisplaySnapshot]

    init(layout: WindowLayout?, isCapture: Bool = false, displays: [WindowLayoutDisplay]) {
        existingID = layout?.id
        self.isCapture = isCapture
        name = layout?.name ?? ""
        iconSymbol = layout?.iconSymbol
        usesPreferredGap = layout?.usesPreferredGap ?? true
        arrangements = layout?.arrangements ?? []
        displaySnapshots = layout?.displaySnapshots ?? []
        defaultDisplays = layout?.displaySnapshots ?? []
        defaultEntries = layout?.entries ?? []
        defaultFrontmostEntryID = layout?.frontmostEntryID
        entries = layout?.entries ?? []
        frontmostEntryID = layout?.frontmostEntryID
        selectedEntryID = entries.first?.id
        previewSpace = entries.first?.space
        selectedDisplayUUID = entries.first?.display.uuid ?? displays.first?.uuid
        let matching = arrangements.filter { $0.displaySet == Set(displays.map { $0.uuid.lowercased() }) }
        if matching.count == 1 { selectArrangement(matching[0].id) }
    }

    var symbol: String { iconSymbol ?? WindowLayout.sfSymbol }
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !entries.isEmpty
            && !previewLayout.entries.isEmpty && !previewLayout.hasDuplicateArrangements
            && previewLayout.arrangements.allSatisfy { !$0.entries.isEmpty }
    }

    var selectedEntry: WindowLayoutEntry? {
        entries.first { $0.id == selectedEntryID }
    }

    /// Marking a second entry moves the mark, so a layout never names two.
    var isSelectedEntryFrontmost: Bool {
        get { selectedEntryID != nil && frontmostEntryID == selectedEntryID }
        set {
            guard let id = selectedEntryID else { return }
            if newValue {
                frontmostEntryID = id
            } else if frontmostEntryID == id {
                frontmostEntryID = nil
            }
        }
    }

    func entries(onDisplay uuid: String) -> [WindowLayoutEntry] {
        entries.filter { $0.display.uuid == uuid }
    }

    func previewEntries(onDisplay uuid: String) -> [WindowLayoutEntry] {
        entries(onDisplay: uuid).filter { $0.space == previewSpace }
    }

    func selectPreviewSpace(_ number: Int?) {
        previewSpace = number
        selectedEntryID = selectedDisplayUUID.flatMap { previewEntries(onDisplay: $0).first?.id }
    }

    /// Every display the sheet must offer a tab for: the connected ones plus any an entry names.
    func tabs(connected: [WindowLayoutDisplay]) -> [WindowLayoutDisplay] {
        var seen = Set(connected.map(\.uuid))
        var result = connected
        for entry in entries where seen.insert(entry.display.uuid).inserted {
            result.append(entry.display)
        }
        return result
    }

    // MARK: - Selection

    /// One selection with two views of it, so the tab and the entry picker can never disagree.
    func select(entryID: UUID) {
        guard let entry = entries.first(where: { $0.id == entryID }) else { return }
        selectedEntryID = entryID
        selectedDisplayUUID = entry.display.uuid
        previewSpace = entry.space
    }

    func select(displayUUID: String) {
        selectedDisplayUUID = displayUUID
        if selectedEntry?.display.uuid != displayUUID {
            selectedEntryID = entries(onDisplay: displayUUID).first?.id
            previewSpace = selectedEntry?.space
        }
    }

    // MARK: - Editing

    func addEntry(bundleID: String, on display: WindowLayoutDisplay) {
        var entry = WindowLayoutEntry(bundleID: bundleID, display: display)
        if display.uuid == selectedDisplayUUID { entry.space = previewSpace }
        entries.append(entry)
        select(entryID: entry.id)
    }

    func removeSelectedEntry() {
        guard let id = selectedEntryID else { return }
        entries.removeAll { $0.id == id }
        if frontmostEntryID == id { frontmostEntryID = nil }
        selectedEntryID =
            selectedDisplayUUID.flatMap { entries(onDisplay: $0).first?.id }
            ?? entries.first?.id
        if let selectedEntry {
            selectedDisplayUUID = selectedEntry.display.uuid
            previewSpace = selectedEntry.space
        }
    }

    func setArgument(_ argument: String?) {
        update {
            let value = argument?.isEmpty == true ? nil : argument
            if $0.argument != value {
                $0.terminalWindowID = nil
                $0.terminalSession = nil
            }
            $0.argument = value
        }
    }

    func setDisplay(_ display: WindowLayoutDisplay) {
        update { $0.display = display }
        selectedDisplayUUID = display.uuid
    }

    func setSpace(_ number: Int?) {
        update { $0.space = number }
        previewSpace = number
    }

    func setFallback(enabled: Bool) {
        update {
            $0.fallbackSpace = enabled ? ($0.fallbackSpace ?? 1) : nil
            if !enabled { $0.fallbackDisplay = nil }
        }
    }

    func setFallbackDisplay(_ display: WindowLayoutDisplay?) {
        update { $0.fallbackDisplay = display }
    }

    func setFallbackSpace(_ number: Int) {
        update { $0.fallbackSpace = number }
    }

    func setAnchor(_ anchor: WindowLayoutAnchor) {
        update { $0.anchor = anchor }
    }

    func setWidthPercent(_ percent: Int) {
        update { $0.widthFraction = Self.fraction(percent) }
    }

    func setHeightPercent(_ percent: Int) {
        update { $0.heightFraction = Self.fraction(percent) }
    }

    func setOffsetX(_ points: Int) {
        update { $0.offset.x = CGFloat(points.clamped(to: Self.offsetRange)) }
    }

    func setOffsetY(_ points: Int) {
        update { $0.offset.y = CGFloat(points.clamped(to: Self.offsetRange)) }
    }

    // MARK: - Arrangements

    func selectArrangement(_ id: UUID?) {
        guard id != selectedArrangementID else { return }
        rememberArrangement()
        selectedArrangementID = id
        if let chosen = arrangements.first(where: { $0.id == id }) {
            entries = chosen.entries
            frontmostEntryID = chosen.frontmostEntryID
            displaySnapshots = chosen.displays
        } else {
            entries = defaultEntries
            frontmostEntryID = defaultFrontmostEntryID
            displaySnapshots = defaultDisplays
        }
        selectedEntryID = entries.first?.id
        selectedDisplayUUID = entries.first?.display.uuid ?? displaySnapshots.first?.display.uuid
        previewSpace = entries.first?.space
    }

    func createArrangement(displays: [WindowLayoutDisplaySnapshot], name: String? = nil) {
        let ids = Set(displays.map(\.id))
        if let existing = arrangements.first(where: { $0.displaySet == ids }) {
            selectArrangement(existing.id)
            return
        }
        rememberDisplays(displays)
        rememberArrangement()
        let copies = entries.map(\.copy)
        let front = entries.firstIndex { $0.id == frontmostEntryID }.map { copies[$0].id }
        let value = WindowLayoutArrangement(name: name ?? (displays.count == 1 ? "Laptop only" : "Docked"),
            displayIDs: ids.sorted(), displays: displaySnapshots, entries: copies, frontmostEntryID: front)
        arrangements.append(value)
        selectArrangement(value.id)
    }

    var arrangementName: String {
        get { arrangements.first { $0.id == selectedArrangementID }?.name ?? "Default" }
        set {
            guard let index = arrangements.firstIndex(where: { $0.id == selectedArrangementID }) else { return }
            arrangements[index].name = newValue
        }
    }

    func removeArrangement() {
        guard let id = selectedArrangementID else { return }
        selectArrangement(nil)
        arrangements.removeAll { $0.id == id }
    }

    func rememberDisplays(_ displays: [WindowLayoutDisplaySnapshot]) {
        for display in displays {
            if let index = displaySnapshots.firstIndex(where: { $0.id == display.id }) {
                displaySnapshots[index] = display
            } else { displaySnapshots.append(display) }
        }
    }

    func placeSelected(frame: CGRect, display: WindowLayoutDisplay, capture: WindowLayoutGeometry.Capture) {
        update {
            $0.display = display
            $0.widthFraction = capture.widthFraction
            $0.heightFraction = capture.heightFraction
            $0.anchor = capture.anchor
            $0.offset = capture.offset
        }
        selectedDisplayUUID = display.uuid
    }

    private func rememberArrangement() {
        if let index = arrangements.firstIndex(where: { $0.id == selectedArrangementID }) {
            arrangements[index].entries = entries
            arrangements[index].frontmostEntryID = frontmostEntryID
            arrangements[index].displays = displaySnapshots
        } else {
            defaultEntries = entries
            defaultFrontmostEntryID = frontmostEntryID
            defaultDisplays = displaySnapshots
        }
    }

    // MARK: - Output

    /// What the preview draws — unvalidated, so an unnamed draft still shows its windows.
    var previewLayout: WindowLayout {
        var variants = arrangements
        let index = variants.firstIndex { $0.id == selectedArrangementID }
        if let index {
            variants[index].entries = entries
            variants[index].frontmostEntryID = frontmostEntryID
            variants[index].displays = displaySnapshots
        }
        return WindowLayout(
            id: existingID ?? UUID(), name: name, iconSymbol: iconSymbol,
            usesPreferredGap: usesPreferredGap, entries: index == nil ? entries : defaultEntries,
            frontmostEntryID: index == nil ? frontmostEntryID : defaultFrontmostEntryID,
            arrangements: variants, displaySnapshots: index == nil ? displaySnapshots : defaultDisplays)
    }

    /// What Save persists; the sheet never assembles a record itself.
    func layout() -> WindowLayout {
        var value = previewLayout
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return value
    }

    // MARK: - Primitives

    static func percent(_ fraction: CGFloat) -> Int {
        guard fraction.isFinite else { return 100 }
        return Int((fraction * 100).rounded()).clamped(to: percentRange)
    }

    private static func fraction(_ percent: Int) -> CGFloat {
        CGFloat(percent.clamped(to: percentRange)) / 100
    }

    private func update(_ change: (inout WindowLayoutEntry) -> Void) {
        guard let index = entries.firstIndex(where: { $0.id == selectedEntryID }) else { return }
        change(&entries[index])
    }
}

extension Int {
    /// Saturating, so a typed-in number is corrected rather than rejected.
    fileprivate func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
