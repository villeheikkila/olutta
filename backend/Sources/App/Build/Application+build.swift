import AsyncHTTPClient
import Foundation
import Hummingbird
import Logging
import PGMQ
@preconcurrency import PostgresNIO

typealias AppRequestContext = BasicRequestContext

public func buildApplication(
    _ arguments: some AppArguments
) async throws -> some ApplicationProtocol {
    let serverName = "Ylähylly"
    let logger = buildLogger(
        label: serverName, telegramApiKey: arguments.telegramApiKey,
        telegramErrorChatId: arguments.telegramErrorChatId, logLevel: arguments.logLevel)
    logger.info("starting server...")
    let config = Config(
        pgHost: arguments.pgHost,
        pgPort: arguments.pgPort,
        pgUsername: arguments.pgUsername,
        pgPassword: arguments.pgPassword,
        pgDatabase: arguments.pgDatabase,
        alkoApiKey: arguments.alkoApiKey,
        alkoBaseUrl: arguments.alkoBaseUrl,
        alkoAgent: arguments.alkoAgent
    )
    let context = await buildContext(logger: logger, config: config)
    let router = buildRouter(ctx: context)
    let queue = try await buildQueue(context: context)
    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: serverName
        ),
        logger: logger
    )
    app.addServices(context.pg)
    await withThrowingTaskGroup(of: Void.self) { taskGroup in
        taskGroup.addTask {
            await context.pg.run()
        }
        taskGroup.addTask {
            await queue.start()
        }
    }
    return app
}

struct Config: Sendable {
    let pgHost: String
    let pgPort: Int
    let pgUsername: String
    let pgPassword: String
    let pgDatabase: String
    let alkoApiKey: String
    let alkoBaseUrl: String
    let alkoAgent: String
}
