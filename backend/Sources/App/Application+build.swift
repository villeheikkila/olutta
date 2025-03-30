import AsyncHTTPClient
import Foundation
import Hummingbird
import Logging
import PGMQ
@preconcurrency import PostgresNIO
import ServiceLifecycle

typealias AppRequestContext = BasicRequestContext

struct Env {
    let pgHost: String
    let pgPort: Int
    let pgUsername: String
    let pgPassword: String
    let pgDatabase: String
    let telegramApiKey: String
    let telegramErrorChatId: String
    let alkoBaseUrl: String
    let alkoAgent: String
    let alkoApiKey: String
    let untappdClientId: String
    let untappdClientSecret: String

    static func load(from environment: Environment) throws -> Env {
        try Env(
            pgHost: environment.get("DB_HOST") ?? "localhost",
            pgPort: environment.require("DB_PORT", as: Int.self),
            pgUsername: environment.get("DB_USER") ?? "postgres",
            pgPassword: environment.get("DB_PASSWORD") ?? "postgres",
            pgDatabase: environment.get("DB_NAME") ?? "postgres",
            telegramApiKey: environment.require("TELEGRAM_API_KEY"),
            telegramErrorChatId: environment.require("TELEGRAM_ERROR_CHAT_ID"),
            alkoBaseUrl: environment.require("ALKO_BASE_URL"),
            alkoAgent: environment.require("ALKO_AGENT"),
            alkoApiKey: environment.require("ALKO_API_KEY"),
            untappdClientId: environment.require("UNTAPPD_CLIENT_ID"),
            untappdClientSecret: environment.require("UNTAPPD_CLIENT_SECRET")
        )
    }
}

public func buildApplication(
    _ args: some AppArguments,
    environment: Environment
) async throws -> some ApplicationProtocol {
    let env = try Env.load(from: environment)
    let logger = buildLogger(
        label: args.serverName, telegramApiKey: env.telegramApiKey,
        telegramErrorChatId: env.telegramErrorChatId, logLevel: args.logLevel
    )
    logger.info("starting \(args.serverName) server on port \(args.hostname):\(args.port)...")
    let config = Config(
        appName: args.serverName,
        pgHost: env.pgHost,
        pgPort: env.pgPort,
        pgUsername: env.pgUsername,
        pgPassword: env.pgPassword,
        pgDatabase: env.pgDatabase,
        alkoApiKey: env.alkoApiKey,
        alkoBaseUrl: env.alkoBaseUrl,
        alkoAgent: env.alkoAgent,
        untappdClientId: env.untappdClientId,
        untappdClientSecret: env.untappdClientSecret
    )
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

struct Config: Sendable {
    let appName: String
    let pgHost: String
    let pgPort: Int
    let pgUsername: String
    let pgPassword: String
    let pgDatabase: String
    let alkoApiKey: String
    let alkoBaseUrl: String
    let alkoAgent: String
    let untappdClientId: String
    let untappdClientSecret: String
}
