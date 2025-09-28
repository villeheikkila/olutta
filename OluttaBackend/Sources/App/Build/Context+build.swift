import AsyncHTTPClient
import Foundation
import HummingbirdRedis
import OpenAI
import PGMQ
import PostgresNIO

struct Context: QueueContextProtocol {
    let pgmq: PGMQ
    let pg: PostgresClient
    let redis: RedisConnectionPoolService
    let persist: RedisPersistDriver
    let openRouter: OpenAI
    let logger: Logger
    let services: Services
    let config: Config
}

func buildContext(logger: Logger, config: Config, pgmq: PGMQ, pg: PostgresClient, redis: RedisConnectionPoolService) async throws -> Context {
    let httpClient = HTTPClient.shared
    let persist = RedisPersistDriver(redisConnectionPoolService: redis)
    let openRouter = OpenAI(configuration: .init(token: config.openrouterApiKey, host: "openrouter.ai", basePath: "/api/v1", parsingOptions: .fillRequiredFieldIfKeyNotFound))
    let service = await Services(logger: logger, httpClient: httpClient, config: config)
    return Context(pgmq: pgmq, pg: pg, redis: redis, persist: persist, openRouter: openRouter, logger: logger, services: service, config: config)
}
