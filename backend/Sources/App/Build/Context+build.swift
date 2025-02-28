import Foundation
import PGMQ
import PostgresNIO
import AsyncHTTPClient

struct Context: QueueContextProtocol {
    let pgmq: PGMQ
    let pg: PostgresClient
    let logger: Logger
    let services: Services
    let repositories: Repositories
}

func buildContext(logger: Logger, config: Config) async -> Context {
    let httpClient = HTTPClient.shared
    let pg = PostgresClient(
        configuration: .init(
            host: config.pgHost,
            port: config.pgPort,
            username: config.pgUsername,
            password: config.pgPassword,
            database: config.pgDatabase,
            tls: .disable
        ),
        backgroundLogger: logger
    )
    let pgmq = PGMQClient(client: pg)
    let repository = Repositories(logger: logger)
    let service = await Services(logger: logger, httpClient: httpClient,config: config)
    return Context(pgmq: pgmq, pg: pg, logger: logger, services: service, repositories: repository)
}
