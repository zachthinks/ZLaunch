import Foundation

@MainActor final class AppCore {
    let palette = TestSecurePalette()
    let paletteCoordinator = TestSecurePaletteCoordinator()
    var messages: [String] = []
    func showMessage(_ message: String, tone: TestSecureTone = .neutral) { messages.append(message) }
    func confirm(title: String, message: String, symbol: String, confirmTitle: String,
                 tone: TestSecureTone, confirmRole: TestSecureRole) async -> Bool { true }
}
enum TestSecureTone { case neutral, danger }
enum TestSecureRole { case destructive }
enum TestSecureMode { case secureItems, secureItemEditor }
@MainActor final class TestSecurePalette {
    var mode: TestSecureMode = .secureItems
    var query = ""
    func replace(mode: TestSecureMode) { self.mode = mode }
}
@MainActor final class TestSecurePaletteCoordinator {
    func showPalette(mode: TestSecureMode) {}
    func hidePalette() {}
}
