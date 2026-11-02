import AppKit

@MainActor
final class SupportCoordinator {
    func showSupport() {
        NSWorkspace.shared.open(URL(string: "https://tinycast.dev/support")!)
    }
}
