import Foundation

@main
struct SignatureTests {
    static func main() throws {
        let custom = URL(fileURLWithPath: CommandLine.arguments[1])
        let official = URL(fileURLWithPath: CommandLine.arguments[2])
        precondition(BundleSignature.isTrusted(custom), "Custom Developer ID build must be trusted")
        precondition(!BundleSignature.isTrusted(official), "Official Tinycast must not be trusted as a custom update")
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let tampered = temporary.appendingPathComponent("Tampered.app")
        try FileManager.default.copyItem(at: custom, to: tampered)
        try Data("tampered".utf8).write(to: tampered.appendingPathComponent("Contents/Info.plist"))
        precondition(!BundleSignature.isTrusted(tampered), "A broken bundle seal must be rejected")
        print("Custom signing trusted; upstream signer and tampered bundle rejected.")
    }
}
