import Foundation
import HTTPTypes
import HTTPTypesFoundation
import OluttaShared
import OSLog

struct TokenSession: Sendable {
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

final class RPCClient {
    private let logger: Logger
    private let baseURL: URL
    private let session: URLSession
    private let signatureService: SignatureService
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let rpcPath: String
    private var defaultHeaders: [HTTPField]
    private let sessionManager: SessionManager

    init(
        baseURL: URL,
        secretKey: String,
        rpcPath: String = "/v1/rpc",
        defaultHeaders: [HTTPField] = [],
        session: URLSession = .shared,
    ) {
        logger = Logger(subsystem: "", category: "RPCClient")
        self.baseURL = baseURL
        self.session = session
        self.rpcPath = rpcPath
        self.defaultHeaders = defaultHeaders
        signatureService = .init(secretKey: secretKey)
        encoder = .init()
        decoder = .init()
        sessionManager = SessionManager()
    }

    @discardableResult
    func call<C: CommandMetadata>(
        _: C.Type,
        with request: C.RequestType,
    ) async throws(RPCError) -> C.ResponseType {
        do {
            let token = try await getValidTokenIfAvailable()
            var headers = defaultHeaders
            if let token {
                headers.append(.init(name: .authorization, value: "Bearer \(token)"))
            }
            return try await post(
                path: "\(rpcPath)/\(C.name.commandName)",
                body: request,
                headers: headers,
            )
        } catch RPCError.httpError(statusCode: 401, _) {
            // on 401 try refreshing token once before removing the session
            guard let currentSession = await sessionManager.currentSession else {
                throw .notAuthenticated
            }
            logger.info("401, attempting token refresh and retry")
            do {
                let newSession = try await sessionManager.refreshSession(
                    currentSession.refreshToken,
                ) { [weak self] refreshToken in
                    guard let self else {
                        throw RPCError.clientDeallocated
                    }
                    return try await performTokenRefresh(refreshToken: refreshToken)
                }
                // retry the request with the new token
                var headers = defaultHeaders
                // we are calling again after 401, token is required
                guard let accessToken = newSession?.accessToken else {
                    throw RPCError.failedToObtainToken
                }
                headers.append(.init(name: .authorization, value: "Bearer \(accessToken)"))
                return try await post(
                    path: "\(rpcPath)/\(C.name.commandName)",
                    body: request,
                    headers: headers,
                )
            } catch let error as RPCError {
                throw error
            } catch {
                throw .tokenRefreshFailed(error)
            }
        }
    }

    private func post<T: Decodable>(
        path: String,
        body: (some Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = [],
    ) async throws(RPCError) -> T {
        let startTime = Date()
        guard let urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true) else {
            throw .invalidURL(path)
        }
        var components = urlComponents
        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw .invalidURL(path)
        }
        var httpFields = HTTPFields()
        httpFields.append(.init(name: .contentType, value: "application/json"))
        httpFields.append(.init(name: .requestId, value: UUID.v7.uuidString))
        for header in headers {
            httpFields.append(header)
        }
        let bodyData: Data?
        if let body {
            do {
                bodyData = try encoder.encode(body)
            } catch {
                throw .encodingFailed(error)
            }
        } else {
            bodyData = nil
        }
        let authority = if let port = url.port, let host = url.host {
            "\(host):\(port)"
        } else {
            url.host
        }
        let signatureResult: (signature: String, bodyHash: String?)
        do {
            signatureResult = try signatureService.createSignature(
                method: .post,
                scheme: nil,
                authority: nil,
                path: path,
                headers: httpFields,
                body: bodyData,
            )
        } catch {
            throw .signatureFailed(error)
        }
        if let bodyHash = signatureResult.bodyHash {
            httpFields.append(.init(name: .bodyHash, value: bodyHash))
        }
        httpFields.append(.init(name: .requestSignature, value: signatureResult.signature))
        let httpRequest = HTTPRequest(
            method: .post,
            scheme: url.scheme,
            authority: authority,
            path: path + (components.query.map { "?\($0)" } ?? ""),
            headerFields: httpFields,
        )
        let data: Data
        let response: HTTPResponse
        do {
            if let bodyData {
                (data, response) = try await session.upload(for: httpRequest, from: bodyData)
            } else {
                (data, response) = try await session.data(for: httpRequest)
            }
        } catch let error as URLError {
            throw .networkError(error)
        } catch {
            throw .networkError(URLError(.unknown))
        }
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Request to POST \(path) completed in \(String(format: "%.3f", duration))s")
        guard (200 ... 299).contains(response.status.code) else {
            throw .httpError(statusCode: response.status.code, data: data)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw .decodingFailed(error)
        }
    }

    func setSession(_ session: TokenSession) async {
        await sessionManager.update(session)
    }

    func getSession() async -> TokenSession? {
        await sessionManager.currentSession
    }

    func clearSession() async {
        await sessionManager.remove()
    }

    func startAutoRefresh() async {
        await sessionManager.startAutoRefresh { [weak self] refreshToken in
            guard let self else { return nil }
            return try await performTokenRefresh(refreshToken: refreshToken)
        }
    }

    func stopAutoRefresh() async {
        await sessionManager.stopAutoRefresh()
    }

    private func getValidTokenIfAvailable() async throws(RPCError) -> String? {
        guard let session = await sessionManager.currentSession else {
            return nil
        }
        if session.isRefreshTokenExpired {
            await sessionManager.remove()
            // user should be logged out when refresh token is expired
            // TODO: add emit event here
            throw RPCError.refreshTokenExpired
        }
        if session.isExpired {
            do {
                let newSession = try await sessionManager.refreshSession(
                    session.refreshToken,
                ) { [weak self] refreshToken in
                    guard let self else {
                        throw RPCError.clientDeallocated
                    }
                    return try await performTokenRefresh(refreshToken: refreshToken)
                }
                guard let accessToken = newSession?.accessToken else { return nil }
                return accessToken
            } catch let error as RPCError {
                // lets not fail on error yet, server will force token refresh on request
                logger.warning("token refresh failed: \(error.localizedDescription)")
                return nil
            } catch {
                logger.warning("token refresh failed: \(error.localizedDescription)")
                return nil
            }
        }
        return session.accessToken
    }

    private func performTokenRefresh(refreshToken: String) async throws(RPCError) -> TokenSession {
        let startTime = Date()
        let refreshTokenPath = "/v1/rpc/\(RefreshTokensCommand.name.commandName)"
        guard let urlComponents = URLComponents(url: baseURL.appendingPathComponent(refreshTokenPath), resolvingAgainstBaseURL: true) else {
            throw .invalidURL(refreshTokenPath)
        }
        guard let url = urlComponents.url else {
            throw .invalidURL(refreshTokenPath)
        }
        var httpFields = HTTPFields()
        httpFields.append(.init(name: .contentType, value: "application/json"))
        httpFields.append(.init(name: .requestId, value: UUID.v7.uuidString))
        for header in defaultHeaders {
            httpFields.append(header)
        }
        let bodyData: Data
        do {
            bodyData = try encoder.encode(RefreshTokensCommand.RequestType(refreshToken: refreshToken))
        } catch {
            throw .encodingFailed(error)
        }
        let authority = if let port = url.port, let host = url.host {
            "\(host):\(port)"
        } else {
            url.host
        }
        let signatureResult: (signature: String, bodyHash: String?)
        do {
            signatureResult = try signatureService.createSignature(
                method: .post,
                scheme: nil,
                authority: nil,
                path: refreshTokenPath,
                headers: httpFields,
                body: bodyData,
            )
        } catch {
            throw .signatureFailed(error)
        }

        if let bodyHash = signatureResult.bodyHash {
            httpFields.append(.init(name: .bodyHash, value: bodyHash))
        }
        httpFields.append(.init(name: .requestSignature, value: signatureResult.signature))
        let httpRequest = HTTPRequest(
            method: .post,
            scheme: url.scheme,
            authority: authority,
            path: refreshTokenPath + (urlComponents.query.map { "?\($0)" } ?? ""),
            headerFields: httpFields,
        )
        let data: Data
        let response: HTTPResponse
        do {
            (data, response) = try await session.upload(for: httpRequest, from: bodyData)
        } catch let error as URLError {
            throw .networkError(error)
        } catch {
            throw .networkError(URLError(.unknown))
        }
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Token refresh completed in \(String(format: "%.3f", duration))s")
        guard (200 ... 299).contains(response.status.code) else {
            throw .httpError(statusCode: response.status.code, data: data)
        }
        let refreshResponse: RefreshTokensCommand.ResponseType
        do {
            refreshResponse = try decoder.decode(RefreshTokensCommand.ResponseType.self, from: data)
        } catch {
            throw .decodingFailed(error)
        }
        return TokenSession(
            accessToken: refreshResponse.accessToken,
            accessTokenExpiresAt: refreshResponse.accessTokenExpiresAt,
            refreshToken: refreshResponse.refreshToken,
            refreshTokenExpiresAt: refreshResponse.refreshTokenExpiresAt,
        )
    }
}

private actor SessionManager {
    private(set) var currentSession: TokenSession?
    private var inFlightRefreshTask: Task<TokenSession?, Error>?
    private var autoRefreshTask: Task<Void, Never>?

    private let autoRefreshTickDuration: TimeInterval = 10.0
    private let autoRefreshTickThreshold = 3

    func update(_ session: TokenSession) {
        currentSession = session
    }

    func remove() {
        currentSession = nil
        stopAutoRefresh()
    }

    func refreshSession(
        _ refreshToken: String,
        refreshHandler: @Sendable @escaping (String) async throws -> TokenSession?,
    ) async throws -> TokenSession? {
        if let inFlightRefreshTask {
            return try await inFlightRefreshTask.value
        }
        inFlightRefreshTask = Task {
            defer { inFlightRefreshTask = nil }
            let session = try await refreshHandler(refreshToken)
            currentSession = session
            return session
        }

        return try await inFlightRefreshTask!.value
    }

    func startAutoRefresh(
        refreshHandler: @escaping @Sendable (String) async throws -> TokenSession?,
    ) {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            while !Task.isCancelled {
                await autoRefreshTick(refreshHandler: refreshHandler)
                try? await Task.sleep(for: .seconds(autoRefreshTickDuration))
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func autoRefreshTick(
        refreshHandler: @Sendable @escaping (String) async throws -> TokenSession?,
    ) async {
        guard let session = currentSession else { return }
        let now = Date().timeIntervalSince1970
        let expiresInTicks = Int((session.accessTokenExpiresAt.timeIntervalSince1970 - now) / autoRefreshTickDuration)
        if expiresInTicks <= autoRefreshTickThreshold {
            _ = try? await refreshSession(session.refreshToken, refreshHandler: refreshHandler)
        }
    }
}

public enum RPCError: Error, LocalizedError, Sendable {
    case networkError(URLError)
    case httpError(statusCode: Int, data: Data)
    case decodingFailed(Error)
    case encodingFailed(Error)
    case invalidURL(String)
    case signatureFailed(Error)
    case sessionExpired
    case failedToObtainToken
    case refreshTokenExpired
    case tokenRefreshFailed(Error)
    case clientDeallocated
    case notAuthenticated

    public var errorDescription: String? {
        switch self {
        case let .networkError(urlError):
            "Network error: \(urlError.localizedDescription)"
        case let .httpError(statusCode, _):
            "HTTP error with status code: \(statusCode)"
        case let .decodingFailed(error):
            "Failed to decode response: \(error.localizedDescription)"
        case let .encodingFailed(error):
            "Failed to encode request: \(error.localizedDescription)"
        case .failedToObtainToken:
            "Failed to obtain a new token"
        case let .invalidURL(path):
            "Invalid URL for path: \(path)"
        case let .signatureFailed(error):
            "Failed to create signature: \(error.localizedDescription)"
        case .sessionExpired:
            "Session has expired, please log in again"
        case .refreshTokenExpired:
            "Refresh token has expired, please log in again"
        case let .tokenRefreshFailed(error):
            "Failed to refresh token: \(error.localizedDescription)"
        case .clientDeallocated:
            "RPC client was deallocated during operation"
        case .notAuthenticated:
            "Authentication required but no session found"
        }
    }
}
