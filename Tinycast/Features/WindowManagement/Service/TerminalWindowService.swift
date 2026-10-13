import AppKit

@MainActor
enum TerminalWindowService {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func create(argument: String? = nil) async throws -> UInt32 {
        var command = ""
        if let argument {
            var directory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: argument, isDirectory: &directory),
                directory.boolValue
            else { throw Failure(message: "Terminal layout arguments must be an existing folder path.") }
            command = "cd -- '" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        let literal = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
            with timeout of 10 seconds
                tell application id "com.apple.Terminal"
                    launch
                    set createdTab to do script "\(literal)"
                    set createdTTY to tty of createdTab
                    repeat with candidate in windows
                        repeat with candidateTab in tabs of candidate
                            if tty of candidateTab is createdTTY then return id of candidate
                        end repeat
                    end repeat
                end tell
            end timeout
            """
        return try await Task.detached(priority: .userInitiated) {
            guard let script = NSAppleScript(source: source) else {
                throw Failure(message: "Couldn't prepare Terminal window creation.")
            }
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            if let error {
                let denied = error[NSAppleScript.errorNumber] as? Int == -1743
                throw Failure(message: denied
                    ? "Allow ZLaunch to control Terminal in System Settings → Privacy & Security → Automation."
                    : error[NSAppleScript.errorMessage] as? String ?? "Couldn't open a Terminal window.")
            }
            guard let value = result.stringValue.flatMap(UInt32.init), value > 0 else {
                throw Failure(message: "Terminal didn't identify its new window.")
            }
            return value
        }.value
    }
}
