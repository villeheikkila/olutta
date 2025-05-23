import AsyncHTTPClient
import Foundation
import Hummingbird
import HummingbirdRedis
import Logging
import OpenAI
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
    let postgresClient = PostgresClient(
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
    let pgmqClient = PGMQClient(client: postgresClient)
    let redis = try RedisConnectionPoolService(
        .init(hostname: config.redisHostname, port: config.redisPort),
        logger: logger
    )
    let context = try await buildContext(logger: logger, config: config, pgmq: pgmqClient, pg: postgresClient, redis: redis)
    let router = buildRouter(ctx: context)
    let queueService = PGMQService(context: context, logger: logger, poolConfig: .init(
        maxConcurrentJobs: 3,
        pollInterval: 1
    ))
    await queueService.registerQueue(alkoQueue)
    await queueService.registerQueue(untappdQueue)
    return Application(
        router: router,
        configuration: .init(
            address: .hostname(args.hostname, port: args.port),
            serverName: args.serverName
        ),
        services: [postgresClient, redis, queueService],
        logger: logger
    )
}
