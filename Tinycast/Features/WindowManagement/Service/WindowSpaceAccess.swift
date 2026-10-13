import AppKit
import Darwin
import MachO
import ObjectiveC

@MainActor
enum WindowSpaceAccess {
    struct Desktop: Identifiable, Sendable {
        let id: UInt64
        let number: Int
    }

    struct Display: Sendable {
        let uuid: String
        let desktops: [Desktop]
        let currentID: UInt64?
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private typealias Connection = @convention(c) () -> Int32
    private typealias CopyDisplays = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CopySpaces = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias Perform = @convention(c) (UnsafeRawPointer) -> Int64
    private typealias Allocate = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>
    private typealias Initialize = @convention(c) (AnyObject, Selector, NSArray, UInt64) -> Unmanaged<AnyObject>

    private static let image = "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight"
    private static let library = dlopen(image, RTLD_NOW)
    private static let performSymbol =
        "__ZL54SLSPerformAsynchronousBridgedWindowManagementOperation"
        + "P47SLSAsynchronousBridgedWindowManagementOperation"
    private static let bridgedMove: UnsafeMutableRawPointer? = {
        guard library != nil else { return nil }
        return localSymbol(performSymbol)
    }()

    static var isAvailable: Bool {
        library != nil && bridgedMove != nil
            && NSClassFromString("SLSBridgedMoveWindowsToManagedSpaceOperation") != nil
    }

    static func displays() -> [Display] {
        guard let library, let connectionSymbol = dlsym(library, "SLSMainConnectionID"),
            let copySymbol = dlsym(library, "SLSCopyManagedDisplaySpaces")
        else { return [] }
        let connection = unsafeBitCast(connectionSymbol, to: Connection.self)()
        let copy = unsafeBitCast(copySymbol, to: CopyDisplays.self)
        guard let records = copy(connection)?.takeRetainedValue() as? [[String: Any]] else { return [] }
        return records.compactMap { record in
            guard let uuid = record["Display Identifier"] as? String,
                let spaces = record["Spaces"] as? [[String: Any]]
            else { return nil }
            let regular = spaces.filter { ($0["type"] as? NSNumber)?.intValue == 0 }
            let desktops = regular.enumerated().compactMap { index, space -> Desktop? in
                guard let id = (space["id64"] as? NSNumber)?.uint64Value else { return nil }
                return Desktop(id: id, number: index + 1)
            }
            let current = record["Current Space"] as? [String: Any]
            return Display(uuid: uuid.lowercased(), desktops: desktops,
                           currentID: (current?["id64"] as? NSNumber)?.uint64Value)
        }
    }

    static func spaces(of windowID: UInt32) -> [UInt64] {
        guard let library, let connectionSymbol = dlsym(library, "SLSMainConnectionID"),
            let copySymbol = dlsym(library, "SLSCopySpacesForWindows")
        else { return [] }
        let connection = unsafeBitCast(connectionSymbol, to: Connection.self)()
        let copy = unsafeBitCast(copySymbol, to: CopySpaces.self)
        let windows = [NSNumber(value: windowID)] as CFArray
        let values = copy(connection, 7, windows)?.takeRetainedValue() as? [NSNumber]
        return values?.map(\.uint64Value) ?? []
    }

    static func move(windowID: UInt32, to spaceID: UInt64) async throws {
        guard !Task.isCancelled else { throw CancellationError() }
        if spaces(of: windowID).contains(spaceID) { return }
        guard isAvailable, let symbol = bridgedMove,
            let cls = NSClassFromString("SLSBridgedMoveWindowsToManagedSpaceOperation"),
            let allocateMethod = class_getClassMethod(cls, NSSelectorFromString("alloc")),
            let initializeMethod = class_getInstanceMethod(cls, NSSelectorFromString("initWithWindows:spaceID:"))
        else { throw Failure(message: "Moving windows between Spaces is unavailable on this macOS build.") }
        let allocate = unsafeBitCast(method_getImplementation(allocateMethod), to: Allocate.self)
        let initialize = unsafeBitCast(method_getImplementation(initializeMethod), to: Initialize.self)
        let allocated = allocate(cls as AnyObject, NSSelectorFromString("alloc"))
        let operation = initialize(allocated.takeUnretainedValue(),
                                   NSSelectorFromString("initWithWindows:spaceID:"),
                                   [NSNumber(value: windowID)] as NSArray, spaceID).takeRetainedValue()
        let perform = unsafeBitCast(symbol, to: Perform.self)
        _ = perform(UnsafeRawPointer(Unmanaged.passUnretained(operation).toOpaque()))
        let deadline = ContinuousClock.now + .seconds(3)
        while !spaces(of: windowID).contains(spaceID) {
            guard !Task.isCancelled else { throw CancellationError() }
            guard ContinuousClock.now < deadline else {
                throw Failure(message: "macOS didn't move a window to its requested Space.")
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private static func localSymbol(_ name: String) -> UnsafeMutableRawPointer? {
        for index in 0..<_dyld_image_count() {
            guard let path = _dyld_get_image_name(index), String(cString: path) == image,
                let header = _dyld_get_image_header(index)
            else { continue }
            let base = UnsafeRawPointer(header)
            let header64 = base.load(as: mach_header_64.self)
            guard header64.magic == MH_MAGIC_64 else { return nil }
            var offset = MemoryLayout<mach_header_64>.size
            var linkedit: segment_command_64?
            var symbols: symtab_command?
            for _ in 0..<header64.ncmds {
                let pointer = base.advanced(by: offset)
                let command = pointer.load(as: load_command.self)
                guard command.cmdsize >= MemoryLayout<load_command>.size else { return nil }
                if command.cmd == LC_SEGMENT_64 {
                    var segment = pointer.load(as: segment_command_64.self)
                    let segmentName = withUnsafePointer(to: &segment.segname) {
                        $0.withMemoryRebound(to: CChar.self, capacity: 16) { String(cString: $0) }
                    }
                    if segmentName == "__LINKEDIT" { linkedit = segment }
                } else if command.cmd == LC_SYMTAB {
                    symbols = pointer.load(as: symtab_command.self)
                }
                offset += Int(command.cmdsize)
            }
            guard let linkedit, let symbols else { return nil }
            let slide = _dyld_get_image_vmaddr_slide(index)
            let address = Int(linkedit.vmaddr - linkedit.fileoff) + slide
            guard let strings = UnsafeRawPointer(bitPattern: address + Int(symbols.stroff)),
                let table = UnsafeRawPointer(bitPattern: address + Int(symbols.symoff))
            else { return nil }
            for symbolIndex in 0..<Int(symbols.nsyms) {
                let symbol = table.advanced(by: symbolIndex * MemoryLayout<nlist_64>.size).load(as: nlist_64.self)
                let stringOffset = symbol.n_un.n_strx
                guard stringOffset < symbols.strsize, symbol.n_value > 0 else { continue }
                if String(cString: strings.advanced(by: Int(stringOffset)).assumingMemoryBound(to: CChar.self)) == name {
                    return UnsafeMutableRawPointer(bitPattern: Int(symbol.n_value) + slide)
                }
            }
        }
        return nil
    }
}
