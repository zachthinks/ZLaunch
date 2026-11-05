import AppKit
import Foundation

struct ExtensionOAuthAuthorizeOptions: Sendable {
    let url: URL
    let state: String?
}

struct ExtensionOAuthAuthorizeResult: Sendable {
    let authorizationCode: String
    let accessToken: String?
    let state: String?
}

/// An OAuth 2.0 PKCE session: the browser authorizes and an `oauth` callback completes it.
@MainActor
final class ExtensionOAuthSession {
    private var continuation: CheckedContinuation<[String: String], Error>?
    private var expectedState: String?
    private var timeoutTimer: Timer?
    private var operationID: UUID?
    private let openURL: (URL) -> Bool

    init(openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }) {
        self.openURL = openURL
    }

    private static weak var activeSession: ExtensionOAuthSession?

    /// True while this session is waiting for the browser to come back.
    var isAuthorizing: Bool {
        continuation != nil
    }

    enum OAuthError: LocalizedError {
        case canceled
        case failed(String)
        case stateMismatch

        var errorDescription: String? {
            switch self {
            case .canceled: return "Authentication was canceled."
            case .failed(let message): return message
            case .stateMismatch: return "OAuth state mismatch. Please try authenticating again."
            }
        }
    }

    /// What a deep link turned out to be, so the caller can tell "not ours" from "too late".
    enum Callback {
        case delivered
        case expired
        case ignored
    }

    /// Deep links from the app delegate, such as `raycast://oauth?code=…`.
    static func handleCallbackURL(_ url: URL) -> Callback {
        guard let scheme = url.scheme?.lowercased(),
            ["raycast", "tinycast", "com.raycast", "zlaunch", "zlaunch-dev"].contains(scheme)
        else { return .ignored }

        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        guard
            host == "oauth" || host == "redirect"
                || path == "/oauth" || path == "/redirect"
                || path.hasPrefix("/oauth/") || path.hasPrefix("/redirect/")
        else {
            return .ignored
        }

        // The browser can come back after the session is gone: quit, timed out, or torn down.
        guard let active = activeSession else { return .expired }
        active.receiveCallback(url: url)
        return .delivered
    }

    func authorize(options: ExtensionOAuthAuthorizeOptions) async throws -> ExtensionOAuthAuthorizeResult {
        let params = try await authorize(url: options.url, expectedState: options.state)
        let code = params["code"] ?? ""
        let token = params["access_token"]
        let state = params["state"]
        return ExtensionOAuthAuthorizeResult(authorizationCode: code, accessToken: token, state: state)
    }

    func authorize(
        url: URL,
        expectedState: String? = nil
    ) async throws -> [String: String] {
        try Task.checkCancellation()
        if continuation != nil {
            cancel()
        }

        let operationID = UUID()
        self.operationID = operationID
        self.expectedState = expectedState
        Self.activeSession = self

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation

                self.timeoutTimer?.invalidate()
                self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard self?.operationID == operationID else { return }
                        self?.finish(error: OAuthError.failed("Authentication timed out."))
                    }
                }

                let opened = openURL(url)
                if !opened {
                    self.finish(error: OAuthError.failed("Failed to open authorization URL in default browser."))
                }
            }
        } onCancel: {
            Task { @MainActor in
                guard self.operationID == operationID else { return }
                self.finish(error: CancellationError())
            }
        }
    }

    private func receiveCallback(url: URL) {
        let params = Self.parseCallback(url: url)
        if let error = params["error"] {
            let desc = params["error_description"] ?? error
            finish(error: OAuthError.failed(desc))
            return
        }

        if let expected = expectedState {
            let states = Self.callbackItems(url: url).filter { $0.name == "state" }
            guard states.count == 1, states[0].value == expected else {
                finish(error: OAuthError.stateMismatch)
                return
            }
        }

        finish(result: params)
    }

    private func finish(result: [String: String]? = nil, error: Error? = nil) {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        operationID = nil

        if Self.activeSession === self {
            Self.activeSession = nil
        }

        if let continuation = self.continuation {
            self.continuation = nil
            if let error {
                continuation.resume(throwing: error)
            } else if let result {
                continuation.resume(returning: result)
            } else {
                continuation.resume(throwing: OAuthError.canceled)
            }
        }
    }

    func cancel() {
        finish(error: OAuthError.canceled)
    }

    // MARK: - URL Parsing

    static func parseCallback(url: URL) -> [String: String] {
        var result: [String: String] = [:]
        for item in callbackItems(url: url) {
            result[item.name] = item.value ?? ""
        }
        return result
    }

    private static func callbackItems(url: URL) -> [URLQueryItem] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return []
        }
        var items = components.queryItems ?? []
        if let fragment = components.percentEncodedFragment, !fragment.isEmpty {
            items += URLComponents(string: "?" + fragment)?.queryItems ?? []
        }
        return items
    }
}
