import Foundation
import HTTPTypes
import HTTPTypesFoundation
import OluttaShared
import OSLog

protocol RPCClientProtocol {
    @discardableResult
    func call<C: CommandMetadata>(
        _ commandType: C.Type,
        with request: C.RequestType,
        headers: [HTTPField]
    ) async throws(RPCError) -> C.ResponseType
}

extension RPCClientProtocol {
    @discardableResult
    func call<C: CommandMetadata>(
        _ commandType: C.Type,
        with request: C.RequestType,
        headers: [HTTPField] = []
    ) async throws(RPCError) -> C.ResponseType {
        try await call(commandType, with: request, headers: headers)
    }
}

final class RPCClient: RPCClientProtocol {
    private let logger: Logger
    private let baseURL: URL
    private let session: URLSession
    private let signatureService: SignatureService
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let rpcPath: String
    private var defaultHeaders: [HTTPField]

    init(
        baseURL: URL,
        secretKey: String,
        rpcPath: String = "/v1/rpc",
        defaultHeaders: [HTTPField] = [],
        session: URLSession = .shared
    ) {
        logger = Logger(subsystem: "", category: "RPCClient")
        self.baseURL = baseURL
        self.session = session
        self.rpcPath = rpcPath
        self.defaultHeaders = defaultHeaders
        signatureService = .init(secretKey: secretKey)
        encoder = .init()
        decoder = .init()
    }

    @discardableResult
    func call<C: CommandMetadata>(
        _: C.Type,
        with request: C.RequestType,
        headers: [HTTPField] = []
    ) async throws(RPCError) -> C.ResponseType {
        try await post(
            path: "\(rpcPath)/\(C.name.commandName)",
            body: request,
            headers: headers
        )
    }

    private func post<T: Decodable>(
        path: String,
        body: (some Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = []
    ) async throws(RPCError) -> T {
        let startTime = Date()

        guard let urlComponents = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: true
        ) else {
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
        for header in defaultHeaders {
            httpFields.append(header)
        }
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
                body: bodyData
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
            headerFields: httpFields
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
        logger.info("Request to POST \(path) completed in \(duration.formatted(.number.precision(.fractionLength(3))))s")
        guard (200 ... 299).contains(response.status.code) else {
            throw .httpError(statusCode: response.status.code, data: data)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw .decodingFailed(error)
        }
    }
}

final class AuthenticatedRPCClient: RPCClientProtocol {
    private let rpcClient: RPCClientProtocol
    private let authManager: AuthManager
    private let logger = Logger(subsystem: "", category: "AuthenticatedRPCClient")

    init(rpcClient: RPCClientProtocol, authManager: AuthManager) {
        self.rpcClient = rpcClient
        self.authManager = authManager
    }

    @discardableResult
    func call<C: CommandMetadata>(
        _: C.Type,
        with request: C.RequestType,
        headers: [HTTPField] = []
    ) async throws(RPCError) -> C.ResponseType {
        guard let token = try await authManager.getValidAccessToken() else {
            throw .notAuthenticated
        }
        let authHeader = HTTPField(name: .authorization, value: "Bearer \(token)")
        let headers = [authHeader] + headers
        do {
            return try await rpcClient.call(C.self, with: request, headers: headers)
        } catch RPCError.httpError(statusCode: 401, _) {
            logger.info("401, attempting token refresh and retry")
            return try await handleUnauthorizedAndRetry(C.self, with: request)
        }
    }

    private func handleUnauthorizedAndRetry<C: CommandMetadata>(
        _: C.Type,
        with request: C.RequestType
    ) async throws(RPCError) -> C.ResponseType {
        do {
            // attempt to refresh the token
            let newSession = try await authManager.forceRefresh()
            guard let accessToken = newSession?.accessToken else {
                throw RPCError.failedToObtainToken
            }
            // retry
            let authHeader = HTTPField(name: .authorization, value: "Bearer \(accessToken)")
            return try await rpcClient.call(C.self, with: request, headers: [authHeader])

        } catch {
            // if refresh fails, clear session and propagate error
            await authManager.handleAuthenticationFailure()
            throw error as? RPCError ?? .tokenRefreshFailed(error)
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
