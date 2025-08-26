import AsyncHTTPClient
import Foundation
import Hummingbird
import HummingbirdPostgres
import HummingbirdRedis
import Logging
import OpenAI
import PGMQ
import PostgresMigrations
@preconcurrency import PostgresNIO
import RegexBuilder
import ServiceLifecycle
import JWTKit
import HummingbirdAuth

typealias AppRequestContext = BasicAuthRequestContext<Device>

public func buildApplication(
    _ args: some AppArguments,
    environment: Environment,
) async throws -> some ApplicationProtocol {
    let env = try buildEnv(environment: environment)
    let logger = buildLogger(
        label: args.serverName,
        telegramApiKey: env.telegramApiKey,
        telegramErrorChatId: env.telegramErrorChatId,
        logLevel: args.logLevel,
    )
    logger.info("starting \(args.serverName) server on port \(args.hostname):\(args.port)...")
    let config = buildConfig(args: args, env: env)
    let jwtKeyCollection = JWTKeyCollection()
    await jwtKeyCollection.add(hmac: HMACKey(stringLiteral: config.jwtSecret), digestAlgorithm: .sha256, kid: JWKIdentifier(stringLiteral: config.appName.lowercased()))
    let postgresClient = PostgresClient(
        configuration: .init(
            host: config.pgHost,
            port: config.pgPort,
            username: config.pgUsername,
            password: config.pgPassword,
            database: config.pgDatabase,
            tls: .disable,
        ),
        backgroundLogger: logger,
    )
    let migrations = DatabaseMigrations()
    await addDatabaseMigrations(to: migrations)
    let postgresPersist = await PostgresPersistDriver(client: postgresClient, migrations: migrations, logger: logger)
    let pgmqClient = PGMQClient(client: postgresClient)
    let redis = try RedisConnectionPoolService(
        .init(hostname: config.redisHostname, port: config.redisPort),
        logger: logger,
    )
    let context = try await buildContext(logger: logger, config: config, pgmq: pgmqClient, pg: postgresClient, redis: redis)
    let router = buildRouter(ctx: context)
    let queueService = PGMQService(context: context, logger: logger, poolConfig: .init(
        maxConcurrentJobs: 3,
        pollInterval: 1,
    ))
    await queueService.registerQueue(alkoQueue)
    await queueService.registerQueue(untappdQueue)
    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(args.hostname, port: args.port),
            serverName: args.serverName,
        ),
        services: [postgresClient, postgresPersist, redis, queueService],
        logger: logger,
    )
    app.beforeServerStarts {
        try await migrations.apply(client: postgresClient, logger: logger, dryRun: false)
    }
    return app
}

func addDatabaseMigrations(to migrations: DatabaseMigrations) async {
    await migrations.add(AdoptHummingbirdMigrations())
    await migrations.add(ScheduleAvailabilityRefreshMigration())
}
