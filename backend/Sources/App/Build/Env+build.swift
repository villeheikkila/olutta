import Foundation
import Hummingbird

func buildEnv(environment: Environment) throws -> Env {
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
}
