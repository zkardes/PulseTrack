import Foundation
import AuthenticationServices

/// Verwaltet OAuth2-Login, Token-Refresh und Roh-Requests gegen die Withings API.
@MainActor
final class WithingsClient: NSObject, ObservableObject {

    @Published var isConnected = false
    @Published var lastError: String?

    private let session = URLSession.shared
    private var authSession: ASWebAuthenticationSession?

    // Tokens werden im Keychain gespeichert (siehe TokenStore).
    private var accessToken: String? { TokenStore.shared.accessToken }
    private var refreshToken: String? { TokenStore.shared.refreshToken }
    private var expiry: Date? { TokenStore.shared.expiry }

    override init() {
        super.init()
        isConnected = TokenStore.shared.refreshToken != nil
    }

    // MARK: - OAuth Login

    func connect() async {
        guard WithingsConfig.isConfigured else {
            lastError = "Bitte trage zuerst Client ID & Secret in WithingsConfig.swift ein."
            return
        }
        let state = UUID().uuidString
        var comps = URLComponents(string: WithingsConfig.authorizeURL)!
        comps.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: WithingsConfig.clientID),
            .init(name: "redirect_uri", value: WithingsConfig.redirectURI),
            .init(name: "scope", value: WithingsConfig.scope),
            .init(name: "state", value: state)
        ]
        guard let url = comps.url else { return }

        do {
            let callback = try await startAuthSession(url: url)
            guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value else {
                lastError = "Kein Autorisierungscode erhalten."
                return
            }
            try await exchangeCode(code)
            isConnected = true
        } catch {
            lastError = "Login abgebrochen: \(error.localizedDescription)"
        }
    }

    func disconnect() {
        TokenStore.shared.clear()
        isConnected = false
    }

    private func startAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let scheme = "pulsetrack"
            let s = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callbackURL, error in
                if let callbackURL { cont.resume(returning: callbackURL) }
                else { cont.resume(throwing: error ?? URLError(.userCancelledAuthentication)) }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            self.authSession = s
            s.start()
        }
    }

    // MARK: - Token Exchange & Refresh

    private func exchangeCode(_ code: String) async throws {
        try await postToken(params: [
            "action": "requesttoken",
            "grant_type": "authorization_code",
            "client_id": WithingsConfig.clientID,
            "client_secret": WithingsConfig.clientSecret,
            "code": code,
            "redirect_uri": WithingsConfig.redirectURI
        ])
    }

    func refreshIfNeeded() async throws {
        guard let expiry, let refreshToken else {
            if refreshToken == nil { throw WithingsError.notConnected }
            return
        }
        if Date() < expiry.addingTimeInterval(-60) { return } // noch gültig
        try await postToken(params: [
            "action": "requesttoken",
            "grant_type": "refresh_token",
            "client_id": WithingsConfig.clientID,
            "client_secret": WithingsConfig.clientSecret,
            "refresh_token": refreshToken
        ])
    }

    private func postToken(params: [String: String]) async throws {
        var req = URLRequest(url: URL(string: WithingsConfig.tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? $0.value)" }
            .joined(separator: "&").data(using: .utf8)

        let (data, _) = try await session.data(for: req)
        let resp = try JSONDecoder().decode(WithingsTokenResponse.self, from: data)
        guard resp.status == 0, let body = resp.body else {
            throw WithingsError.api("Token-Fehler (status \(resp.status))")
        }
        TokenStore.shared.save(
            access: body.access_token,
            refresh: body.refresh_token,
            expiry: Date().addingTimeInterval(TimeInterval(body.expires_in))
        )
    }

    // MARK: - Authenticated Request

    /// Führt einen POST gegen einen Withings-Endpoint aus und decodiert `T`.
    func request<T: Decodable>(path: String, params: [String: String], as type: T.Type) async throws -> T {
        try await refreshIfNeeded()
        guard let token = accessToken else { throw WithingsError.notConnected }

        var req = URLRequest(url: URL(string: WithingsConfig.apiBase + path)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? $0.value)" }
            .joined(separator: "&").data(using: .utf8)

        let (data, _) = try await session.data(for: req)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - ASWebAuthenticationSession presentation

extension WithingsClient: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        return ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

// MARK: - Errors

enum WithingsError: LocalizedError {
    case notConnected
    case api(String)
    var errorDescription: String? {
        switch self {
        case .notConnected: return "Nicht mit Withings verbunden."
        case .api(let m):   return m
        }
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&=+")
        return cs
    }()
}
