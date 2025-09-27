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

func buildApplication(
    config: Config,
) async throws -> some ApplicationProtocol {
    let logger = buildLogger(
        label: config.serverName,
        telegramApiKey: config.telegramApiKey,
        telegramErrorChatId: config.telegramErrorChatId,
        logLevel: config.logLevel,
    )
    logger.info("starting \(config.serverName) server on port \(config.host):\(config.port)...")
    let jwtKeyCollection = JWTKeyCollection()
    await jwtKeyCollection.add(hmac: HMACKey(stringLiteral: config.jwtSecret), digestAlgorithm: .sha256, kid: JWKIdentifier(stringLiteral: config.serverName.lowercased()))
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
        .init(hostname: config.redisHost, port: config.redisPort),
        logger: logger,
    )
    let context = try await buildContext(logger: logger, config: config, pgmq: pgmqClient, pg: postgresClient, redis: redis)
    let router = buildRouter(ctx: context, jwtKeyCollection: jwtKeyCollection)
    let queueService = PGMQService(context: context, logger: logger, poolConfig: .init(
        maxConcurrentJobs: 3,
        pollInterval: 1,
    ))
    await queueService.registerQueue(alkoQueue)
    await queueService.registerQueue(untappdQueue)
//    let client = APNSClient(
//        configuration: .init(
//            authenticationMethod: .jwt(
//                privateKey: try .init(pemRepresentation: privateKey),
//                keyIdentifier: keyIdentifier,
//                teamIdentifier: teamIdentifier
//            ),
//            environment: .development
//        ),
//        eventLoopGroupProvider: .createNew,
//        responseDecoder: JSONDecoder(),
//        requestEncoder: JSONEncoder()
//    )
    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(config.host, port: config.port),
            serverName: config.serverName,
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
    await migrations.add(AddDeviceTableMigration())
}
