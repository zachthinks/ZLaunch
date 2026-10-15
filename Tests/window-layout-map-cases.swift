import CoreGraphics
import Foundation

extension WindowLayoutTests {
    static func mapArrangements() {
        let laptop = WindowLayoutDisplaySnapshot(display: display(1), frame: mainScreen.frame,
            visibleFrame: mainScreen.visibleFrame, desktopCount: 2)
        let monitor = WindowLayoutDisplaySnapshot(display: display(2), frame: rightScreen.frame,
            visibleFrame: rightScreen.visibleFrame, desktopCount: 4)
        let first = entry(bundleID: "com.example.same", display: 1)
        var second = entry(bundleID: "com.example.same", display: 2)
        second.space = 4
        second.fallbackSpace = 2
        var value = layout("Configurations", entries: [first, second])
        let laptopOnly = WindowLayoutArrangement(name: "Laptop only", displayIDs: ["UUID-1"],
            displays: [laptop], entries: [first], frontmostEntryID: first.id)
        let docked = WindowLayoutArrangement(name: "Docked", displayIDs: ["uuid-1", "uuid-2"],
            displays: [laptop, monitor], entries: [first, second])
        value.arrangements = [laptopOnly, docked]
        value.displaySnapshots = [laptop, monitor]
        expect(value.selectingArrangement(connectedDisplayIDs: ["uuid-1"]).layout.entries == [first],
               "exact laptop setup selects its own entries")
        expect(value.selectingArrangement(connectedDisplayIDs: ["UUID-2", "UUID-1"]).arrangementID == docked.id,
               "setup matching ignores order and UUID casing")
        expect(value.selectingArrangement(connectedDisplayIDs: ["different"]).arrangementID == nil,
               "same display count with different identities does not match")
        expect(value.selectingArrangement(connectedDisplayIDs: ["different"]).layout.entries == value.entries,
               "unmatched setup uses the preserved default")
        let encoded = try? JSONEncoder().encode(value)
        let decoded = encoded.flatMap { try? JSONDecoder().decode(WindowLayout.self, from: $0) }
        expect(decoded == value, "all setups, snapshots and entry IDs survive native persistence")
        var oldObject = (try? JSONSerialization.jsonObject(with: encoded ?? Data())) as? [String: Any] ?? [:]
        oldObject.removeValue(forKey: "arrangements")
        oldObject.removeValue(forKey: "displaySnapshots")
        let oldData = try? JSONSerialization.data(withJSONObject: oldObject)
        let legacy = oldData.flatMap { try? JSONDecoder().decode(WindowLayout.self, from: $0) }
        expect(legacy?.entries == value.entries && legacy?.arrangements.isEmpty == true,
               "old layouts decode unchanged with no migration")

        let draft = WindowLayoutDraft(layout: value, displays: [display(1), display(2)])
        expect(draft.layout() == value, "opening the draft does not change saved setups")
        draft.selectArrangement(laptopOnly.id)
        draft.setWidthPercent(40)
        draft.selectArrangement(docked.id)
        expect(draft.entries.count == 2, "switching to docked restores both duplicate app entries")
        draft.select(entryID: second.id)
        expect(draft.selectedDisplayUUID == display(2).uuid && draft.previewSpace == 4,
               "duplicate app selection uses entry identity and its display/Space")
        draft.setSpace(3)
        draft.selectArrangement(laptopOnly.id)
        expect(draft.entries[0].widthFraction == 0.4, "unsaved laptop edits survive arrangement switching")
        expect(draft.layout().arrangements.last?.entries.last?.space == 3,
               "edits to one arrangement survive switching away")
        expect(value.arrangements.last?.entries.last?.space == 4, "draft editing preserves the source")
        expect(draft.displaySnapshots == [laptop], "laptop map uses its own stored display geometry")
        draft.selectArrangement(docked.id)
        expect(draft.displaySnapshots.contains { $0.id == monitor.id }, "offline dock retains its saved frame")

        var restored = value.selectingArrangement(connectedDisplayIDs: ["uuid-1"]).layout
        restored.entries[0].terminalWindowID = 55
        let reconciled = value.restoringRuntime(restored, arrangementID: laptopOnly.id)
        expect(reconciled.entries == value.entries && reconciled.arrangements.last == docked,
               "runtime reconciliation preserves default and other arrangements")
        expect(reconciled.arrangements.first?.entries.first?.terminalWindowID == 55,
               "runtime reconciliation updates only the selected arrangement")
        let duplicate = docked.copy
        expect(duplicate.id != docked.id && duplicate.entries.map(\.id) != docked.entries.map(\.id),
               "duplicating an arrangement creates fresh independent identities")
        expect(duplicate.entries.allSatisfy { $0.terminalWindowID == nil }, "duplicates clear Terminal ownership")
        let fresh = WindowLayoutDraft(layout: layout(entries: [first, second]), displays: [display(1)])
        fresh.rememberDisplays([laptop, monitor])
        fresh.createArrangement(displays: [laptop])
        expect(fresh.arrangements.count == 1 && fresh.selectedArrangementID != nil,
               "Save setup creates and selects the current connected-display variant")
        expect(fresh.displaySnapshots.contains { $0.id == monitor.id },
               "new laptop setup retains known geometry for offline preferred destinations")
        expect(fresh.layout().entries == [first, second], "Save setup preserves the original default")
        fresh.createArrangement(displays: [laptop])
        expect(fresh.arrangements.count == 1, "Save setup selects an existing exact match without duplicating it")
        fresh.createArrangement(displays: [monitor, laptop])
        expect(fresh.arrangements.count == 2, "another connected-display set creates an independent variant")
                value.arrangements.append(laptopOnly.copy)
        expect(value.hasDuplicateArrangements, "duplicate exact setup matches are rejected")
        expect(value.selectingArrangement(connectedDisplayIDs: ["uuid-1"]).arrangementID == nil,
               "ambiguous imported setups never choose arbitrarily")

        let map = WindowLayoutMapGeometry(frames: [leftScreen.frame, mainScreen.frame, rightScreen.frame],
                                         canvas: CGSize(width: 640, height: 400))
        let a = map.map(mainScreen.frame)
        let b = map.map(rightScreen.frame)
        expect(abs(a.width / b.width - mainScreen.frame.width / rightScreen.frame.width) < 0.0001,
               "map preserves relative display sizes")
        expect(b.minX > a.minX && b.minY < a.minY, "map preserves relative position and negative origins")
        let point = map.desktopPoint(CGPoint(x: a.minX, y: a.minY))
        expect(abs(point.x - mainScreen.frame.minX) < 0.001 && abs(point.y - mainScreen.frame.minY) < 0.001,
               "map conversion is invertible for gesture placement")
        let capture = WindowLayoutGeometry.describe(CGRect(x: 50, y: 60, width: 400, height: 300),
                                                   on: mainScreen, gap: 0)
        draft.selectArrangement(laptopOnly.id)
        draft.placeSelected(frame: .zero, display: display(1), capture: capture)
        expectRect(WindowLayoutGeometry.resolve(draft.entries[0], on: mainScreen, gap: 0),
                   CGRect(x: 50, y: 60, width: 400, height: 300), "drag/resize describes a reproducible frame")
        let connected = target(mainScreen, 1)
        let plan = WindowLayoutPlan.make(layout: layout(entries: [second]), screens: [
            WindowLayoutScreen(display: connected.display, screen: connected.screen,
                               desktopIDs: [101, 103], isBuiltin: true)], windows: [], preferredGap: 0)
        expect(plan.placements.first?.spaceID == 103, "offline monitor uses explicit fallback on laptop Space 2")
        var missingSpace = second
        missingSpace.display = display(1)
        let absent = WindowLayoutPlan.make(layout: layout(entries: [missingSpace]), screens: [
            WindowLayoutScreen(display: display(1), screen: mainScreen, desktopIDs: [101, 103])],
            windows: [], preferredGap: 0)
        expect(absent.placements.isEmpty, "different Space counts report unavailable targets rather than remapping")
    }
}
