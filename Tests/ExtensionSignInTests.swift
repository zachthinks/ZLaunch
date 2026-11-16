import AppKit

@main
@MainActor
struct ExtensionSignInTests {
    static var passes = 0
    static var failures = 0
    static let url = URL(string: "https://example.test/authorize?state=expected")!

    static func expect(_ condition: Bool, _ message: String) {
        if condition { passes += 1 } else { failures += 1; print("FAIL: \(message)") }
    }

    static func main() async {
        await failedStart()
        await browserCompletion()
        await cancellationBeforeStart()
        await cancellationDuringSignIn()
        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func failedStart() async {
        let signIn = ExtensionOAuthSession { _ in false }
        do {
            _ = try await signIn.authorize(url: url)
            expect(false, "a refused browser start must throw")
        } catch {
            expect(!signIn.isAuthorizing, "a refused start finishes without waiting for a callback")
        }
    }

    static func browserCompletion() async {
        let callbacks: [(String, String?)] = [
            ("?code=fixture&state=expected", nil),
            ("#code=fixture&state=expected", nil),
            ("?code=fixture&state=%65xpected", nil),
            ("?code=fixture", "state"),
            ("?code=fixture&state=wrong", "state"),
            ("?code=fixture&state=expected&state=expected", "state"),
            ("?code=fixture&state=wrong&state=expected", "state"),
            ("?code=fixture&state=expected#state=expected", "state"),
            ("#code=fixture&state=wrong&state=expected", "state"),
            ("?error=access_denied&error_description=Denied", "Denied"),
        ]
        for (suffix, failure) in callbacks {
            let signIn = ExtensionOAuthSession { opened in
                expect(opened == url, "opens the requested authorization URL")
                Task { @MainActor in
                    let redirect = URL(string: "zlaunch-dev://oauth" + suffix)!
                    expect(ExtensionOAuthSession.handleCallbackURL(redirect) == .delivered,
                           "the active session receives its callback")
                    expect(ExtensionOAuthSession.handleCallbackURL(redirect) == .expired,
                           "a late callback cannot complete the session twice")
                }
                return true
            }
            do {
                let result = try await signIn.authorize(url: url, expectedState: "expected")
                expect(failure == nil && result["code"] == "fixture", "valid callbacks return the code")
            } catch {
                if failure == "state", let oauthError = error as? ExtensionOAuthSession.OAuthError,
                    case .stateMismatch = oauthError
                {
                    expect(true, "missing, wrong and duplicate state are rejected")
                } else {
                    expect(failure == "Denied" && error.localizedDescription == "Denied",
                           "provider failures reach the caller")
                }
            }
        }
    }

    static func cancellationBeforeStart() async {
        var opened = false
        let signIn = ExtensionOAuthSession { _ in opened = true; return true }
        let task = Task { try await signIn.authorize(url: url) }
        task.cancel()
        do {
            _ = try await task.value
            expect(false, "an already cancelled task must throw")
        } catch {
            expect(error is CancellationError && !opened, "cancelled work never opens a browser")
        }
    }

    static func cancellationDuringSignIn() async {
        let signIn = ExtensionOAuthSession { _ in true }
        let task = Task { try await signIn.authorize(url: url) }
        while !signIn.isAuthorizing { await Task.yield() }
        task.cancel()
        do {
            _ = try await task.value
            expect(false, "cancelling an active sign-in must throw")
        } catch {
            expect(error is CancellationError, "task cancellation reaches the caller")
        }
        expect(!signIn.isAuthorizing, "cancellation clears the active session")
        let redirect = URL(string: "zlaunch-dev://oauth?code=late")!
        expect(ExtensionOAuthSession.handleCallbackURL(redirect) == .expired,
               "a late callback cannot resume cancelled work")
    }
}
