import AsyncHTTPClient
import Foundation
import Logging

struct AlkoService: Sendable {
    private let logger: Logger
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder
    private let apiKey: String
    private let baseUrl: String
    private let agent: String

    init(logger: Logger = Logger(label: "AlkoService"), httpClient: HTTPClient = HTTPClient.shared, apiKey: String, baseUrl: String, agent: String) {
        self.logger = logger
        self.httpClient = httpClient
        decoder = JSONDecoder()
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.agent = agent
    }

    // public methods
    func getStores() async throws(AlkoError) -> [AlkoStoreResponse] {
        try await request(endpoint: "/v1/stores?lang=fi")
    }

    func getAvailability(productId: String) async throws(AlkoError) -> [AlkoStoreAvailabilityResponse] {
        try await request(endpoint: "/v1/availability/\(productId)?lang=fi")
    }

    func getWebstoreAvailability(id: String) async throws(AlkoError) -> [AlkoWebAvailabilityResponse] {
        try await request(endpoint: "/v1/webshopAvailability?products=\(id)&lang=fi")
    }

    func getProduct(id: String) async throws(AlkoError) -> AlkoProductResponse {
        try await request(endpoint: "/v1/products/\(id)?omitFields=webshopAvailability&lang=fi")
    }

    func getAllBeers() async throws(AlkoError) -> [AlkoSearchProductResponse] {
        try await getAllProducts(queries: [
            .init(op: "eq", field: "productGroupId", value: "productGroup_600"),
            .init(op: "eq", field: "productGroupId", value: "productGroup_940"),
        ])
    }

    // private methods
    private func getAllProducts(queries: [AlkoService.AlkoSearchRequest.Filter.Query]) async throws(AlkoError) -> [AlkoSearchProductResponse] {
        var allProducts: [AlkoSearchProductResponse] = []
        var skip = 0
        let pageSize = 50
        let seed = generateSearchSeed()
        while true {
            let searchRequest = AlkoSearchRequest(
                filter: .init(
                    op: "or",
                    queries: queries,
                ),
                top: pageSize,
                skip: skip,
                orderby: "onlineAvailabilityDatetimeTs desc",
                seed: seed,
                freeText: "",
            )
            let response: AlkoProductSearchResponse = try await request(
                endpoint: "/v1/products/search?lang=fi",
                method: .POST(body: searchRequest),
            )
            allProducts.append(contentsOf: response.value)
            if response.value.count < pageSize || allProducts.count >= response.count {
                break
            }
            skip += pageSize
            try? await Task.sleep(for: .milliseconds(200))
        }
        return allProducts
    }

    private func generateSearchSeed() -> Double {
        let random = Double.random(in: 0 ... 1)
        return Double(String(random).prefix(18)) ?? random
    }

    private var defaultHeaders: [(name: String, value: String)] {
        [
            (name: "Content-Type", value: "application/json"),
            (name: "Accept", value: "application/json"),
            (name: "x-api-key", value: apiKey),
            (name: "x-alko-mobile", value: "\(agent)/1.18.1 ios/18.2.1"),
            (name: "Accept-Language", value: "en-GB,en,q=0.9"),
            (name: "Accept-Encoding", value: "gzip, deflate, br"),
            (name: "User-Agent", value: "\(agent) CFNetwork/1568.300.101 Darwin/24.2.0"),
        ]
    }

    private enum HTTPMethod {
        case GET
        case POST(body: Encodable)
    }

    private func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        options: [(name: String, value: String)] = [],
    ) async throws(AlkoError) -> T {
        let url = "\(baseUrl)\(endpoint)"
        var request = HTTPClientRequest(url: url)
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
                logger.error("Encoding error: \(error.localizedDescription)")
                throw AlkoError.encodingError(message: "Failed to encode request body: \(error.localizedDescription)")
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
            switch response.status.code {
            case 200:
                let data = try await response.body.collect(upTo: 1024 * 1024 * 10)
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    logger.error("Decoding error: \(error.localizedDescription)")
                    throw AlkoError.decodingError(message: "Failed to decode response: \(error.localizedDescription)")
                }
            case 401, 403:
                throw AlkoError.unauthorized(message: "Invalid API key or unauthorized access")
            case 404:
                throw AlkoError.notFound(message: "Resource not found", resource: endpoint)
            case 408, 504:
                throw AlkoError.requestTimeout(message: "Request timed out")
            case 500 ... 599:
                throw AlkoError.serverError(message: "Server error: HTTP \(response.status.code)")
            default:
                throw AlkoError.networkError(statusCode: response.status.code, message: "Unexpected status code")
            }
        } catch let error as AlkoError {
            throw error
        } catch {
            logger.error("Request failed: \(error.localizedDescription)")
            throw .networkError(statusCode: 0, message: error.localizedDescription)
        }
    }

    struct AlkoSearchRequest: Encodable {
        struct Filter: Encodable {
            struct Query: Encodable {
                let op: String
                let field: String
                let value: String
            }

            let op: String
            let queries: [Query]
        }

        let filter: Filter
        let top: Int
        let skip: Int
        let orderby: String
        let seed: Double
        let freeText: String
    }

    private struct AlkoProductSearchResponse: Decodable {
        let count: Int
        let value: [AlkoSearchProductResponse]

        enum CodingKeys: String, CodingKey {
            case count = "@odata.count"
            case value
        }
    }
}

public enum AlkoError: Error, CustomStringConvertible {
    case networkError(statusCode: UInt, message: String)
    case decodingError(message: String)
    case invalidResponse(message: String)
    case requestTimeout(message: String)
    case unauthorized(message: String)
    case notFound(message: String, resource: String)
    case serverError(message: String)
    case fileDownloadError(message: String)
    case unknown(message: String)
    case encodingError(message: String)

    public var description: String {
        switch self {
        case let .networkError(statusCode, message):
            "Network error (HTTP \(statusCode)): \(message)"
        case let .decodingError(message):
            "Failed to decode response: \(message)"
        case let .invalidResponse(message):
            "Invalid response: \(message)"
        case let .requestTimeout(message):
            "Request timed out: \(message)"
        case let .unauthorized(message):
            "Unauthorized: \(message)"
        case let .notFound(message, resource):
            "Resource not found: \(message) (Resource: \(resource))"
        case let .serverError(message):
            "Server error: \(message)"
        case let .fileDownloadError(message):
            "File download error: \(message)"
        case let .unknown(message):
            "Unknown error: \(message)"
        case let .encodingError(message: message):
            "Encoding error: \(message)"
        }
    }
}
