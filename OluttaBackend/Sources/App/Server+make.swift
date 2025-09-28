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

typealias AppRequestContext = BasicAuthRequestContext<UserIdentity>

func makeServer(config: Config) async throws -> some ApplicationProtocol {
    // logger
    let logger = makeLogger(
        label: config.serverName,
        telegramApiKey: config.telegramApiKey,
        telegramErrorChatId: config.telegramErrorChatId,
        logLevel: config.logLevel,
    )
    // postgres
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
    // redis
    let redis = try RedisConnectionPoolService(
        .init(hostname: config.redisHost, port: config.redisPort),
        logger: logger,
    )
    let persist = RedisPersistDriver(redisConnectionPoolService: redis)
    // http client
    let httpClient = HTTPClient.shared
    // services
    let openRouter = OpenAI(configuration: .init(token: config.openrouterApiKey, host: "openrouter.ai", basePath: "/api/v1", parsingOptions: .fillRequiredFieldIfKeyNotFound))
    let alkoService = AlkoService(
        logger: logger,
        httpClient: httpClient,
        apiKey: config.alkoApiKey,
        baseUrl: config.alkoBaseUrl,
        agent: config.alkoAgent,
    )
    let untappdService = UntappdService(
        logger: logger,
        httpClient: httpClient,
        appName: config.serverName,
        clientId: config.untappdClientId,
        clientSecret: config.untappdClientSecret,
    )
    // queue
    let pgmqClient = PGMQClient(client: postgresClient)
    let queueContext = QueueContext(pgmq: pgmqClient, pg: postgresClient, openRouter: openRouter, logger: logger, alkoService: alkoService, untappdService: untappdService, config: config)
    let queueService = PGMQService(context: queueContext, logger: logger, poolConfig: .init(
        maxConcurrentJobs: 3,
        pollInterval: 1,
    ))
    await queueService.registerQueue(alkoQueue)
    await queueService.registerQueue(untappdQueue)
    // apns
    let apnsService = try APNSService(
        privateKey: config.apnsToken,
        keyIdentifier: config.appleKeyId,
        teamIdentifier: config.appleTeamId,
        environment: .development,
        apnsTopic: config.apnsTopic,
        pg: postgresClient,
    )
    // router
    let jwtKeyCollection = JWTKeyCollection()
    await jwtKeyCollection.add(hmac: HMACKey(stringLiteral: config.jwtSecret), digestAlgorithm: .sha256, kid: JWKIdentifier(stringLiteral: config.serverName.lowercased()))
    let router = makeRouter(pg: postgresClient, persist: persist, jwtKeyCollection: jwtKeyCollection, requestSignatureSalt: config.requestSignatureSalt)
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

struct QueueContext: QueueContextProtocol {
    let pgmq: PGMQ
    let pg: PostgresClient
    let openRouter: OpenAI
    let logger: Logger
    let alkoService: AlkoService
    let untappdService: UntappdService
    let config: Config
}
