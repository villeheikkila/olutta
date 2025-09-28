import APNS
import APNSCore
import AsyncHTTPClient
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdPostgres
import HummingbirdRedis
import JWTKit
import Logging
import OpenAI
import PGMQ
import PostgresMigrations
import PostgresNIO
import RegexBuilder
import ServiceLifecycle

typealias AppRequestContext = BasicAuthRequestContext<Device>

func buildApplication(config: Config) async throws -> some ApplicationProtocol {
    // logger
    let logger = buildLogger(
        label: config.serverName,
        telegramApiKey: config.telegramApiKey,
        telegramErrorChatId: config.telegramErrorChatId,
        logLevel: config.logLevel,
    )
    // database
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
    for migration in allMigrations {
        await migrations.add(migration)
    }
    let postgresPersist = await PostgresPersistDriver(client: postgresClient, migrations: migrations, logger: logger)
    let pgmqClient = PGMQClient(client: postgresClient)
    let redis = try RedisConnectionPoolService(
        .init(hostname: config.redisHost, port: config.redisPort),
        logger: logger,
    )
    // context
    let context = try await buildContext(logger: logger, config: config, pgmq: pgmqClient, pg: postgresClient, redis: redis)
    // services
    let queueService = PGMQService(context: context, logger: logger, poolConfig: .init(
        maxConcurrentJobs: 3,
        pollInterval: 1,
    ))
    await queueService.registerQueue(alkoQueue)
    await queueService.registerQueue(untappdQueue)
    let apnsService = try APNSService(
        privateKey: config.apnsToken,
        keyIdentifier: config.appleKeyId,
        teamIdentifier: config.appleTeamId,
        environment: .development,
        apnsTopic: config.apnsTopic,
        pg: context.pg,
        deviceRepository: context.repositories.device,
    )
    // router
    let jwtKeyCollection = JWTKeyCollection()
    await jwtKeyCollection.add(hmac: HMACKey(stringLiteral: config.jwtSecret), digestAlgorithm: .sha256, kid: JWKIdentifier(stringLiteral: config.serverName.lowercased()))
    let router = buildRouter(ctx: context, jwtKeyCollection: jwtKeyCollection)
    // app
    logger.info("starting \(config.serverName) server on port \(config.host):\(config.port)...")
    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(config.host, port: config.port),
            serverName: config.serverName,
        ),
        services: [postgresClient, postgresPersist, redis, queueService, apnsService],
        logger: logger,
    )
    app.beforeServerStarts {
        try await migrations.apply(client: postgresClient, logger: logger, dryRun: false)
    }
    return app
}
