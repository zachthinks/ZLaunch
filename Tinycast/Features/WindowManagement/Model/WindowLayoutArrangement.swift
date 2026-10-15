import CoreGraphics
import Foundation

/// Last authored display geometry; an offline map never invents a live monitor position.
struct WindowLayoutDisplaySnapshot: Codable, Hashable, Identifiable, Sendable {
    var display: WindowLayoutDisplay
    var frame: CGRect
    var visibleFrame: CGRect
    var desktopCount: Int
    var id: String { display.uuid.lowercased() }

    var isValid: Bool {
        [frame.minX, frame.minY, frame.width, frame.height,
         visibleFrame.minX, visibleFrame.minY, visibleFrame.width, visibleFrame.height].allSatisfy(\.isFinite)
            && frame.width > 0 && frame.height > 0 && visibleFrame.width > 0 && visibleFrame.height > 0
            && frame.width <= 100_000 && frame.height <= 100_000
            && abs(frame.minX) <= 1_000_000 && abs(frame.minY) <= 1_000_000
    }
}

/// An authored variant selected by an exact connected-display set, only at explicit Run.
struct WindowLayoutArrangement: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String
    var displayIDs: [String]
    var displays: [WindowLayoutDisplaySnapshot]
    var entries: [WindowLayoutEntry]
    var frontmostEntryID: UUID?

    var displaySet: Set<String> { Set(displayIDs.map { $0.lowercased() }) }

    var copy: Self {
        var value = self
        value.id = UUID()
        value.entries = entries.map(\.copy)
        value.frontmostEntryID = entries.firstIndex { $0.id == frontmostEntryID }.map { value.entries[$0].id }
        return value
    }

    mutating func sanitize() {
        displayIDs = Array(displaySet.filter { !$0.isEmpty }).sorted()
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        displays = displays.filter(\.isValid)
        entries = WindowLayoutEntry.sanitized(entries)
        if !entries.contains(where: { $0.id == frontmostEntryID }) { frontmostEntryID = nil }
    }
}

extension WindowLayout {
    struct ArrangementSelection {
        var layout: WindowLayout
        var arrangementID: UUID?
    }

    func selectingArrangement(connectedDisplayIDs: [String]) -> ArrangementSelection {
        let connected = Set(connectedDisplayIDs.map { $0.lowercased() })
        let matches = arrangements.filter { $0.displaySet == connected }
        guard matches.count == 1, let match = matches.first else {
            return ArrangementSelection(layout: self, arrangementID: nil)
        }
        var value = self
        value.entries = match.entries
        value.frontmostEntryID = match.frontmostEntryID
        return ArrangementSelection(layout: value, arrangementID: match.id)
    }

    /// Reconcile the runner's window bindings into exactly the variant it ran.
    func restoringRuntime(_ restored: WindowLayout, arrangementID: UUID?) -> WindowLayout {
        var value = self
        if let arrangementID {
            guard let index = arrangements.firstIndex(where: { $0.id == arrangementID }) else { return self }
            value.arrangements[index].entries = restored.entries
        } else {
            value.entries = restored.entries
        }
        return value
    }

    var hasDuplicateArrangements: Bool {
        let keys = arrangements.map { $0.displaySet.sorted().joined(separator: "\0") }
        return Set(keys).count != keys.count
    }
}
