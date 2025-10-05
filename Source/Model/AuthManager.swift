import Foundation
import OluttaShared
import OSLog

enum AuthStatus: Equatable, Sendable {
    case authenticated
    case unauthenticated
}

enum AuthManagerError: Error {
    case refreshTokenExpired
    case notAuthenticated
    case tokenRefreshFailed(Error)
}

@Observable
final class AuthManager {
    private let storage: SessionStorage
    private let rpcClient: RPCClientProtocol
    private let logger = Logger(subsystem: "", category: "AuthenticationManager")
    // session
    private var currentSession: TokenSession?
    private var inFlightRefreshTask: Task<TokenSession?, Error>?
    private var autoRefreshTask: Task<Void, Never>?
    // auto-refresh
    private let autoRefreshTickDuration: TimeInterval = 10.0
    private let autoRefreshTickThreshold = 3
    // status
    private(set) var authStatus: AuthStatus = .unauthenticated

    init(storage: SessionStorage, rpcClient: RPCClientProtocol) {
        self.storage = storage
        self.rpcClient = rpcClient
    }

    // TODO: make this real
    let deviceId = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!

    func initialize() async {
        do {
            if let storedSession = try await storage.load() {
                if storedSession.isRefreshTokenExpired {
                    logger.info("stored session refresh token expired, clearing")
                    await clear()
                } else {
                    currentSession = storedSession
                    authStatus = .authenticated
                    logger.info("session restored from storage")
                    await startAutoRefresh()
                }
            } else {
                authStatus = .unauthenticated
                logger.info("no stored session found")
            }
        } catch {
            logger.error("failed to load session: \(error.localizedDescription)")
            authStatus = .unauthenticated
        }
    }

    // public
    func signIn(authenticationType: AuthenticateCommand.AuthenticationType) async throws(RPCError) {
        let response = try await rpcClient.call(
            AuthenticateCommand.self,
            with: .init(authenticationType: authenticationType, deviceId: deviceId),
        )
        await setSession(
            accessToken: response.accessToken,
            accessTokenExpiresAt: response.accessTokenExpiresAt,
            refreshToken: response.refreshToken,
            refreshTokenExpiresAt: response.refreshTokenExpiresAt,
        )
    }

    func signOut() async {
        await clear()
    }

    func getValidAccessToken() async throws(AuthManagerError) -> String? {
        guard let session = currentSession else {
            return nil
        }
        if session.isRefreshTokenExpired {
            await clear()
            throw AuthManagerError.refreshTokenExpired
        }
        if session.isExpired {
            logger.info("access token expired, needs refresh")
            return nil
        }
        return session.accessToken
    }

    func forceRefresh() async throws -> TokenSession? {
        guard let session = currentSession else {
            throw AuthManagerError.notAuthenticated
        }
        return try await refreshSession(session.refreshToken)
    }

    func handleAuthenticationFailure() async {
        logger.warning("authentication failure detected, clearing session")
        await clear()
    }

    // private
    private func setSession(
        accessToken: String,
        accessTokenExpiresAt: Date,
        refreshToken: String,
        refreshTokenExpiresAt: Date,
    ) async {
        let session = TokenSession(
            accessToken: accessToken,
            accessTokenExpiresAt: accessTokenExpiresAt,
            refreshToken: refreshToken,
            refreshTokenExpiresAt: refreshTokenExpiresAt,
        )
        currentSession = session
        do {
            try await storage.save(session)
            authStatus = .authenticated
            logger.info("Session saved and authenticated")
        } catch {
            logger.error("Failed to save session: \(error.localizedDescription)")
            authStatus = .authenticated
        }
        await startAutoRefresh()
    }

    private func clear() async {
        currentSession = nil
        stopAutoRefresh()
        do {
            try await storage.delete()
        } catch {
            logger.error("failed to delete session from storage: \(error.localizedDescription)")
        }
        authStatus = .unauthenticated
        logger.info("session cleared")
    }

    private func refreshSession(_ refreshToken: String) async throws -> TokenSession? {
        if let inFlightRefreshTask {
            logger.info("refresh already in progress, waiting...")
            return try await inFlightRefreshTask.value
        }
        inFlightRefreshTask = Task {
            defer { inFlightRefreshTask = nil }
            do {
                let newSession = try await performTokenRefresh(refreshToken: refreshToken)
                currentSession = newSession
                try? await storage.save(newSession)
                authStatus = .authenticated
                logger.info("token refresh successful")
                return newSession
            } catch {
                logger.error("token refresh failed: \(error.localizedDescription)")
                await clear()
                throw AuthManagerError.tokenRefreshFailed(error)
            }
        }
        return try await inFlightRefreshTask?.value
    }

    private func performTokenRefresh(refreshToken: String) async throws(RPCError) -> TokenSession {
        let refreshRequest = RefreshTokensCommand.RequestType(refreshToken: refreshToken)
        let response: RefreshTokensCommand.ResponseType = try await rpcClient.call(
            RefreshTokensCommand.self,
            with: refreshRequest,
        )
        return TokenSession(
            accessToken: response.accessToken,
            accessTokenExpiresAt: response.accessTokenExpiresAt,
            refreshToken: response.refreshToken,
            refreshTokenExpiresAt: response.refreshTokenExpiresAt,
        )
    }

    private func startAutoRefresh() async {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            guard let self else { return }
            logger.info("auto-refresh started")
            while !Task.isCancelled {
                await autoRefreshTick()
                try? await Task.sleep(for: .seconds(autoRefreshTickDuration))
            }
            logger.info("auto-refresh stopped")
        }
    }

    private func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func autoRefreshTick() async {
        guard let session = currentSession else { return }
        let now = Date().timeIntervalSince1970
        let expiresInTicks = Int((session.accessTokenExpiresAt.timeIntervalSince1970 - now) / autoRefreshTickDuration)
        if expiresInTicks <= autoRefreshTickThreshold {
            logger.info("token expiring soon (in \(expiresInTicks) ticks), refreshing...")
            _ = try? await refreshSession(session.refreshToken)
        }
    }
}

struct TokenSession: Sendable, Codable {
    let accessToken: String
    let accessTokenExpiresAt: Date
    let refreshToken: String
    let refreshTokenExpiresAt: Date

    var isExpired: Bool {
        Date() >= accessTokenExpiresAt
    }

    var isRefreshTokenExpired: Bool {
        Date() >= refreshTokenExpiresAt
    }
}

protocol SessionStorage: Sendable {
    func save(_ session: TokenSession) async throws
    func load() async throws -> TokenSession?
    func delete() async throws
}

actor KeychainSessionStorage: SessionStorage {
    private let keychain: Keychain
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(service: String, key: String = "session", accessGroup: String? = nil) {
        keychain = Keychain(service: service, accessGroup: accessGroup)
        self.key = key
    }

    func save(_ session: TokenSession) async throws {
        let data = try encoder.encode(session)
        try keychain.set(data, forKey: key)
    }

    func load() async throws -> TokenSession? {
        do {
            let data = try keychain.data(forKey: key)
            return try decoder.decode(TokenSession.self, from: data)
        } catch let error as KeychainError where error.code == .itemNotFound {
            return nil
        }
    }

    func delete() async throws {
        do {
            try keychain.deleteItem(forKey: key)
        } catch let error as KeychainError where error.code == .itemNotFound {}
    }
}
