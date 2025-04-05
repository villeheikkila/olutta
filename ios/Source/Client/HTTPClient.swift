import CryptoKit
import Foundation
import HTTPTypes
import HTTPTypesFoundation
import OluttaShared

final class HTTPClient {
    private let baseURL: URL
    private let secretKey: String
    private let session: URLSession

    init(baseURL: URL, secretKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.secretKey = secretKey
        self.session = session
    }

    func request(
        method: HTTPRequest.Method,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = [],
        body: Data? = nil
    ) async throws -> (Data, HTTPResponse) {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        if let queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        guard let url = urlComponents.url else {
            throw HTTPClientError.invalidURL
        }
        var httpFields = HTTPFields()
        httpFields.append(.init(name: .contentType, value: "application/json"))
        for header in headers {
            httpFields.append(header)
        }
        let signatureService = SignatureService(secretKey: secretKey)
        let authority = if let port = url.port, let host = url.host { "\(host):\(port)" } else { url.host }
        let signatureResult = try signatureService.createSignature(
            method: method,
            scheme: nil,
            authority: nil,
            path: path,
            headers: httpFields,
            body: body
        )
        httpFields.append(.init(name: .requestSignature, value: signatureResult.signature))
        if let bodyHash = signatureResult.bodyHash {
            httpFields.append(.init(name: .bodyHash, value: bodyHash))
        }
        let httpRequest = HTTPRequest(
            method: method,
            scheme: url.scheme,
            authority: authority,
            path: path + (urlComponents.query.map { "?\($0)" } ?? ""),
            headerFields: httpFields,
        )
        return try await session.data(for: httpRequest)
    }

    func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = []
    ) async throws -> T {
        let (data, response) = try await request(
            method: .get,
            path: path,
            queryItems: queryItems,
            headers: headers
        )
        guard (200 ... 299).contains(response.status.code) else {
            throw HTTPClientError.httpError(code: response.status.code, data: data)
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed(error)
        }
    }

    func post<T: Decodable>(
        path: String,
        body: some Encodable,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPField] = []
    ) async throws -> T {
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(body)
        let (data, response) = try await request(
            method: .post,
            path: path,
            queryItems: queryItems,
            headers: headers,
            body: bodyData
        )
        guard (200 ... 299).contains(response.status.code) else {
            throw HTTPClientError.httpError(code: response.status.code, data: data)
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed(error)
        }
    }
}

enum HTTPClientError: Error {
    case invalidURL
    case requestCreationFailed
    case invalidResponse
    case httpError(code: Int, data: Data)
    case decodingFailed(Error)
}
