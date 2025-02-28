import AsyncHTTPClient
import Foundation
import Logging

final class AlkoService: Sendable {
    private let logger: Logger
    private let httpClient: HTTPClient
    private let apiKey: String
    private let baseUrl: String
    private let agent: String

    init(logger: Logger = Logger(label: "AlkoService"), httpClient: HTTPClient = HTTPClient.shared, apiKey: String, baseUrl: String, agent: String) {
        self.logger = logger
        self.httpClient = httpClient
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.agent = agent
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

    func request(endpoint: String, options: [(name: String, value: String)] = []) async throws -> HTTPClientResponse {
        let url = "\(baseUrl)\(endpoint)"
        print(url)
        var request = HTTPClientRequest(url: url)
        request.method = .GET
        for header in defaultHeaders {
            request.headers.add(name: header.name, value: header.value)
        }
        for header in options {
            request.headers.add(name: header.name, value: header.value)
        }
        return try await httpClient.execute(request, timeout: .seconds(30))
    }

    func getStores() async throws -> [AlkoStoreResponse] {
        let response = try await request(endpoint: "/v1/stores")
        guard response.status == .ok else {
            logger.error("error fetching stores: HTTP \(response.status.code)")
            return []
        }
        let body = try await response.body.collect(upTo: 1024 * 1024)
        let decoder = JSONDecoder()
        print("HERE")
        do {
            return try decoder.decode([AlkoStoreResponse].self, from: body)
        } catch {
            logger.error("error decoding response: \(error)")
            return []
        }
    }
}

struct ApiHeader {
    let name: String
    let value: String
}
