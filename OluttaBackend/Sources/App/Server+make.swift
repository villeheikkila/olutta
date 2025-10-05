import APNS
import APNSCore
import AsyncHTTPClient
import Foundation
import Hummingbird
import HummingbirdPostgres
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import OpenAI
import PGMQ
import PostgresMigrations
import PostgresNIO
import RegexBuilder
import ServiceLifecycle

func makeServer(config: Config) async throws -> some ApplicationProtocol {
    // utils
    let decoder = JSONDecoder()
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
    // migrations
    let postgresMigrations = DatabaseMigrations()
    let migrations: [DatabaseMigration] = [
        AdoptHummingbirdMigrations(),
        ScheduleAvailabilityRefreshMigration(),
        AddDeviceTableMigration(),
        AddPushNotificationSubscriptionTableMigration(),
        CreateUsersTableMigration(),
        AddUserRefreshTokensMigration(),
        AddAuthProvidersMigration(),
    ]
    for migration in migrations {
        await postgresMigrations.add(migration)
    }
    let postgresPersist = await PostgresPersistDriver(client: postgresClient, migrations: postgresMigrations, logger: logger)
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
    let appleService = try await SignInWithAppleService(logger: logger, httpClient: httpClient, decoder: decoder, bundleIdentifier: config.appleBundleId, teamIdentifier: config.appleTeamId, privateKeyId: config.appleKeyId, privateKey: config.applePrivateKey)
    let apnsService = try APNSService(
        privateKey: config.applePrivateKey,
        keyIdentifier: config.appleKeyId,
        teamIdentifier: config.appleTeamId,
        environment: .development,
        apnsTopic: config.appleBundleId,
        pg: postgresClient,
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
    // commands
    let unauthenticatedCommands: [String: any UnauthenticatedCommandExecutable.Type] = [
        RefreshTokensCommand.name: RefreshTokensCommand.self,
        AuthenticateCommand.name: AuthenticateCommand.self,
    ]
    let authenticatedCommands: [String: any AuthenticatedCommandExecutable.Type] = [
        RefreshDeviceCommand.name: RefreshDeviceCommand.self,
        GetUserCommand.name: GetUserCommand.self,
        SubscribeToStoreCommand.name: SubscribeToStoreCommand.self,
        UnsubscribeFromStoreCommand.name: UnsubscribeFromStoreCommand.self,
        GetAppDataCommand.name: GetAppDataCommand.self,
        GetProductsByStoreIdCommand.name: GetProductsByStoreIdCommand.self,
    ]
    // router
    let jwtKeyCollection = JWTKeyCollection()
    await jwtKeyCollection.add(hmac: HMACKey(stringLiteral: config.jwtSecret), digestAlgorithm: .sha256, kid: JWKIdentifier(stringLiteral: config.serverName.lowercased()))
    let router = makeRouter(pg: postgresClient, persist: persist, jwtKeyCollection: jwtKeyCollection, requestSignatureSalt: config.requestSignatureSalt, appleService: appleService,
                            unauthenticatedCommands: unauthenticatedCommands, authenticatedCommands: authenticatedCommands)
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
        try await postgresMigrations.apply(client: postgresClient, logger: logger, dryRun: false)
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
