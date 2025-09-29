import CoreLocation
import CryptoKit
import Foundation
import HTTPTypes
import HTTPTypesFoundation
import OluttaShared
import OSLog

final class HTTPClient {
    private let logger: Logger
    private let baseURL: URL
    private let session: URLSession
    private let signatureService: SignatureService
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var defaultHeaders: [HTTPField]

    init(
        baseURL: URL,
        secretKey: String,
        defaultHeaders: [HTTPField] = [],
        session: URLSession = .shared,
    ) {
        logger = Logger(subsystem: "", category: "HTTPClient")
        self.baseURL = baseURL
        self.session = session
        self.defaultHeaders = defaultHeaders
        signatureService = .init(secretKey: secretKey)
        encoder = .init()
        decoder = .init()
    }

    private init(
        baseURL: URL,
        signatureService: SignatureService,
        defaultHeaders: [HTTPField],
        session: URLSession,
        encoder: JSONEncoder,
        decoder: JSONDecoder,
    ) {
        logger = Logger(subsystem: "", category: "HTTPClient")
        self.baseURL = baseURL
        self.session = session
        self.defaultHeaders = defaultHeaders
        self.signatureService = signatureService
        self.encoder = encoder
        self.decoder = decoder
    }

    func copyWith(
        baseURL: URL? = nil,
        secretKey _: String? = nil,
        defaultHeaders: [HTTPField]? = nil,
    ) -> HTTPClient {
        HTTPClient(
            baseURL: baseURL ?? self.baseURL,
            signatureService: signatureService,
            defaultHeaders: defaultHeaders ?? self.defaultHeaders,
            session: session,
            encoder: encoder,
            decoder: decoder,
        )
    }

    func request(
        method: HTTPRequest.Method,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = [],
        body: Data? = nil,
    ) async throws -> (Data, HTTPResponse) {
        let startTime = Date()

        let urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        guard var urlComponents else {
            throw HTTPClientError.invalidURL
        }
        if let queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        guard let url = urlComponents.url else {
            throw HTTPClientError.invalidURL
        }
        var httpFields = HTTPFields()
        httpFields.append(.init(name: .contentType, value: "application/json"))
        httpFields.append(.init(name: .requestId, value: UUID.v7.uuidString))
        let _headers = defaultHeaders + headers
        for header in _headers {
            httpFields.append(header)
        }
        let authority = if let port = url.port, let host = url.host { "\(host):\(port)" } else { url.host }
        let signatureResult = try signatureService.createSignature(
            method: method,
            scheme: nil,
            authority: nil,
            path: path,
            headers: httpFields,
            body: body,
        )
        if let bodyHash = signatureResult.bodyHash {
            httpFields.append(.init(name: .bodyHash, value: bodyHash))
        }
        httpFields.append(.init(name: .requestSignature, value: signatureResult.signature))
        let httpRequest = HTTPRequest(
            method: method,
            scheme: url.scheme,
            authority: authority,
            path: path + (urlComponents.query.map { "?\($0)" } ?? ""),
            headerFields: httpFields,
        )
        let result: (Data, HTTPResponse) = if let body {
            try await session.upload(for: httpRequest, from: body)
        } else {
            try await session.data(for: httpRequest)
        }
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Request to \(method.rawValue) \(path) completed in \(String(format: "%.3f", duration))s")
        return result
    }

    func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = [],
    ) async throws -> T {
        let (data, response) = try await request(
            method: .get,
            path: path,
            queryItems: queryItems,
            headers: headers,
        )
        guard (200 ... 299).contains(response.status.code) else {
            throw HTTPClientError.httpError(code: response.status.code, data: data)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed(error)
        }
    }

    func post<T: Decodable>(
        path: String,
        body: (some Encodable)? = nil,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = [],
    ) async throws -> T {
        let bodyData: Data? = if let body { try encoder.encode(body) } else { nil }
        let (data, response) = try await request(
            method: .post,
            path: path,
            queryItems: queryItems,
            headers: headers,
            body: bodyData,
        )
        guard (200 ... 299).contains(response.status.code) else {
            throw HTTPClientError.httpError(code: response.status.code, data: data)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed(error)
        }
    }

    func patch<T: Decodable>(
        path: String,
        body: some Encodable,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = [],
    ) async throws -> T {
        let bodyData = try encoder.encode(body)
        let (data, response) = try await request(
            method: .patch,
            path: path,
            queryItems: queryItems,
            headers: headers,
            body: bodyData,
        )
        guard (200 ... 299).contains(response.status.code) else {
            throw HTTPClientError.httpError(code: response.status.code, data: data)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed(error)
        }
    }

    func delete<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = [],
    ) async throws -> T {
        let (data, response) = try await request(
            method: .delete,
            path: path,
            queryItems: queryItems,
            headers: headers,
            body: nil,
        )
        guard (200 ... 299).contains(response.status.code) else {
            throw HTTPClientError.httpError(code: response.status.code, data: data)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed(error)
        }
    }
}

extension HTTPClient {
    func request(
        method: HTTPRequest.Method,
        path: APIEndpoint,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = [],
        body: Data? = nil,
    ) async throws -> (Data, HTTPResponse) {
        try await request(
            method: method,
            path: path,
            queryItems: queryItems,
            headers: headers,
            body: body,
        )
    }

    func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = [],
    ) async throws -> T {
        try await get(
            path: path,
            queryItems: queryItems,
            headers: headers,
        )
    }

    func post<T: Decodable>(
        path: String,
        body: some Encodable,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = [],
    ) async throws -> T {
        try await post(
            path: path,
            body: body,
            queryItems: queryItems,
            headers: headers,
        )
    }

    func patch<T: Decodable>(
        path: String,
        body: some Encodable,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = [],
    ) async throws -> T {
        try await patch(
            path: path,
            body: body,
            queryItems: queryItems,
            headers: headers,
        )
    }

    func delete<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = [],
    ) async throws -> T {
        try await delete(
            path: path,
            queryItems: queryItems,
            headers: headers,
        )
    }
}

enum HTTPClientError: Error {
    case invalidURL
    case requestCreationFailed
    case invalidResponse
    case httpError(code: Int, data: Data)
    case decodingFailed(Error)
}

public struct RPCClient {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func call<Cmd: CommandMetadata>(
        _ commandType: Cmd.Type,
        with request: Cmd.RequestType
    ) async throws -> Cmd.ResponseType {
        do {
            return try await httpClient.post(
                path: "v1/rpc/\(Cmd.name)",
                body: request
            )
        } catch HTTPClientError.httpError(let code, let data) {
            throw RPCError.httpError(code: code, data: data)
        } catch HTTPClientError.decodingFailed(let error) {
            throw RPCError.decodingError(error)
        } catch {
            throw RPCError.networkError(error)
        }
    }

    public func call<Cmd: CommandMetadata>(
        _ commandType: Cmd.Type,
        with request: Cmd.RequestType,
        path: APIEndpoint
    ) async throws(RPCError) -> Cmd.ResponseType {
        do {
            return try await httpClient.post(
                path: path,
                body: request
            )
        } catch HTTPClientError.httpError(let code, let data) {
            throw RPCError.httpError(code: code, data: data)
        } catch HTTPClientError.decodingFailed(let error) {
            throw RPCError.decodingError(error)
        } catch {
            throw RPCError.networkError(error)
        }
    }
}

public enum RPCError: Error, LocalizedError {
    case networkError(Error)
    case httpError(code: Int, data: Data)
    case decodingError(Error)
    case commandNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code, _):
            return "HTTP error with status code: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .commandNotFound(let command):
            return "Command not found: \(command)"
        }
    }
}
