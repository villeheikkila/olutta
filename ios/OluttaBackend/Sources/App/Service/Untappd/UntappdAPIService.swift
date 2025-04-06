import AsyncHTTPClient
import Foundation
import Logging

final class UntappdService: Sendable {
    private let logger: Logger
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder
    private let clientId: String
    private let clientSecret: String
    private let baseUrl = "https://api.untappd.com/v4"
    private let appName: String

    public init(
        logger: Logger = Logger(label: "untappd"),
        httpClient: HTTPClient = HTTPClient.shared,
        appName: String,
        clientId: String,
        clientSecret: String
    ) {
        self.logger = logger
        self.httpClient = httpClient
        decoder = JSONDecoder()
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.appName = appName
    }

    // public methods
    public func getBeerMetadata(bid: Int) async throws(UntappdError) -> UntappdResponse<UntappdBeerResponse> {
        try await request(endpoint: "/beer/info/\(bid)")
    }

    public func searchBeer(query: String) async throws(UntappdError) -> UntappdResponse<UntappdSearchResponse> {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw .failedToEncodeUrl
        }
        return try await request(endpoint: "/search/beer?q=\(encodedQuery)")
    }

    // private methods
    private var defaultHeaders: [(name: String, value: String)] {
        [
            (name: "Content-Type", value: "application/json"),
            (name: "Accept", value: "application/json"),
            (name: "User-Agent", value: "\(appName) (\(clientId))"),
        ]
    }

    private enum HTTPMethod {
        case GET
        case POST(body: Encodable)
    }

    private func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        options: [(name: String, value: String)] = []
    ) async throws(UntappdError) -> T {
        var urlString = "\(baseUrl)\(endpoint)"
        let authParams = "client_id=\(clientId)&client_secret=\(clientSecret)"
        urlString += urlString.contains("?") ? "&\(authParams)" : "?\(authParams)"

        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw UntappdError.networkError(statusCode: 0, message: "Invalid URL")
        }
        var request = HTTPClientRequest(url: encodedURL)
        switch method {
        case .GET:
            request.method = .GET
        case let .POST(body):
            request.method = .POST
            do {
                let encodedBody = try JSONEncoder().encode(body)
                request.body = .bytes(encodedBody)
                request.headers.add(name: "Content-Type", value: "application/json")
            } catch {
                logger.error("encoding error: \(error.localizedDescription)")
                throw UntappdError.encodingError(message: "failed to encode request body: \(error.localizedDescription)")
            }
        }
        for header in defaultHeaders {
            request.headers.add(name: header.name, value: header.value)
        }
        for header in options {
            request.headers.add(name: header.name, value: header.value)
        }
        do {
            let response = try await httpClient.execute(request, timeout: .seconds(30))
            let data = try await response.body.collect(upTo: 1024 * 1024 * 10)
            if response.status.code != 200 {
                do {
                    let errorResponse = try decoder.decode(UntappdErrorResponse.self, from: data)
                    let errorMessage = errorResponse.meta.developerFriendly ?? errorResponse.meta.errorDetail
                    switch response.status.code {
                    case 401, 403:
                        throw UntappdError.unauthorized(message: errorMessage)
                    case 404:
                        throw UntappdError.notFound(message: errorMessage, resource: endpoint)
                    case 408, 504:
                        throw UntappdError.requestTimeout(message: errorMessage)
                    case 429:
                        throw UntappdError.rateLimitExceeded(message: errorMessage)
                    case 500 ... 599:
                        throw UntappdError.serverError(message: errorMessage)
                    default:
                        throw UntappdError.networkError(statusCode: response.status.code, message: errorMessage)
                    }
                } catch {
                    logger.error("failed to decode error response: \(error.localizedDescription)")
                    throw UntappdError.networkError(
                        statusCode: UInt(response.status.code),
                        message: "request failed with status code \(response.status.code)"
                    )
                }
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                logger.error("decoding error: \(error)")
                throw UntappdError.decodingError(message: "Failed to decode response: \(error.localizedDescription)")
            }
        } catch let error as UntappdError {
            throw error
        } catch {
            logger.error("request failed: \(error.localizedDescription)")
            throw .networkError(statusCode: 0, message: error.localizedDescription)
        }
    }

    enum UntappdError: Error {
        case encodingError(message: String)
        case decodingError(message: String)
        case unauthorized(message: String)
        case notFound(message: String, resource: String)
        case requestTimeout(message: String)
        case serverError(message: String)
        case networkError(statusCode: UInt, message: String)
        case rateLimitExceeded(message: String)
        case failedToEncodeUrl
    }
}
