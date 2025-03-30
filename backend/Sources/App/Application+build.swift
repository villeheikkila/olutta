import AsyncHTTPClient
import Foundation
import Hummingbird
import Logging
import PGMQ
@preconcurrency import PostgresNIO
import RegexBuilder
import ServiceLifecycle

typealias AppRequestContext = BasicRequestContext

public func buildApplication(
    _ args: some AppArguments,
    environment: Environment
) async throws -> some ApplicationProtocol {
    let env = try buildEnv(environment: environment)
    let logger = buildLogger(
        label: args.serverName,
        telegramApiKey: env.telegramApiKey,
        telegramErrorChatId: env.telegramErrorChatId,
        logLevel: args.logLevel
    )
    logger.info("starting \(args.serverName) server on port \(args.hostname):\(args.port)...")
    let config = buildConfig(args: args, env: env)
    let context = await buildContext(logger: logger, config: config)
    let router = buildRouter(ctx: context)
    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(args.hostname, port: args.port),
            serverName: args.serverName
        ),
        logger: logger
    )
    app.addServices(context.pg)
    let queueService = PGMQService(context: context, logger: logger, poolConfig: .init(
        maxConcurrentJobs: 3,
        pollInterval: 1
    ))
    await queueService.registerQueue(alkoQueue)
    await queueService.registerQueue(untappdQueue)
    app.addServices(queueService)
    return app
}
