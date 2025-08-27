import Foundation
import Hummingbird

func buildEnv(environment: Environment) throws -> Env {
    try Env(
        pgHost: environment.get("DB_HOST") ?? "localhost",
        pgPort: environment.get("DB_PORT", as: Int.self) ?? 5432,
        pgUsername: environment.get("DB_USER") ?? "postgres",
        pgPassword: environment.get("DB_PASSWORD") ?? "postgres",
        pgDatabase: environment.get("DB_NAME") ?? "postgres",
        redisHostname: environment.get("REDIS_HOSTNAME") ?? "localhost",
        redisPort: environment.get("REDIS_PORT", as: Int.self) ?? 6379,
        telegramApiKey: environment.require("TELEGRAM_API_KEY"),
        telegramErrorChatId: environment.require("TELEGRAM_ERROR_CHAT_ID"),
        alkoBaseUrl: environment.require("ALKO_BASE_URL"),
        alkoAgent: environment.require("ALKO_AGENT"),
        alkoApiKey: environment.require("ALKO_API_KEY"),
        untappdClientId: environment.require("UNTAPPD_CLIENT_ID"),
        untappdClientSecret: environment.require("UNTAPPD_CLIENT_SECRET"),
        requestSignatureSalt: environment.require("REQUEST_SIGNATURE_SALT"),
        openrouterApiKey: environment.require("OPENROUTER_API_KEY"),
        appleTeamId: environment.require("APPLE_TEAM_ID"),
        appleKeyId: environment.require("APPLE_KEY_ID"),
        applePrivateKeyBase64: environment.require("APPLE_PRIVATE_KEY_BASE64"),
        jwtSecret: environment.require("JWT_SECRET"),
    )
}

struct Env {
    let pgHost: String
    let pgPort: Int
    let pgUsername: String
    let pgPassword: String
    let pgDatabase: String
    let redisHostname: String
    let redisPort: Int
    let telegramApiKey: String
    let telegramErrorChatId: String
    let alkoBaseUrl: String
    let alkoAgent: String
    let alkoApiKey: String
    let untappdClientId: String
    let untappdClientSecret: String
    let requestSignatureSalt: String
    let openrouterApiKey: String
    let appleTeamId: String
    let appleKeyId: String
    let applePrivateKeyBase64: String
    let jwtSecret: String
}
