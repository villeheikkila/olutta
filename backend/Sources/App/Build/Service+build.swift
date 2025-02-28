import AsyncHTTPClient
import Foundation
import Logging

struct Services: Sendable {
    let alko: AlkoService

    init(logger: Logger, httpClient: HTTPClient, config: Config) async {
        alko = .init(
            logger: logger,
            httpClient: httpClient,
            apiKey: config.alkoApiKey,
            baseUrl: config.alkoBaseUrl,
            agent: config.alkoAgent
        )
    }
}
