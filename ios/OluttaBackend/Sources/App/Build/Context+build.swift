import AsyncHTTPClient
import Foundation
import HummingbirdRedis
import PGMQ
import PostgresNIO

struct Context: QueueContextProtocol {
    let pgmq: PGMQ
    let pg: PostgresClient
    let redis: RedisConnectionPoolService
    let persist: RedisPersistDriver
    let logger: Logger
    let services: Services
    let repositories: Repositories
    let config: Config
}

func buildContext(logger: Logger, config: Config, pgmq: PGMQ, pg: PostgresClient, redis: RedisConnectionPoolService) async throws -> Context {
    let httpClient = HTTPClient.shared
    let persist = RedisPersistDriver(redisConnectionPoolService: redis)
    let repository = Repositories(logger: logger)
    let service = await Services(logger: logger, httpClient: httpClient, config: config)
    return Context(pgmq: pgmq, pg: pg, redis: redis, persist: persist, logger: logger, services: service, repositories: repository, config: config)
}
