import Configuration
import Foundation
import Hummingbird
import Logging

struct Config {
    let host: String
    let port: Int
    let serverName: String
    let pgHost: String
    let pgPort: Int
    let pgUsername: String
    let pgPassword: String
    let pgDatabase: String
    let redisHost: String
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
    let logLevel: Logger.Level

    init(config: ConfigReader) throws {
        serverName = try config.requiredString(forKey: "server.name")
        host = try config.requiredString(forKey: "server.host")
        port = try config.requiredInt(forKey: "server.port")
        let logLevel = try config.requiredString(forKey: "server.log.level")
        self.logLevel = .init(from: logLevel)
        pgHost = try config.requiredString(forKey: "db.host")
        pgPort = try config.requiredInt(forKey: "db.port")
        pgUsername = try config.requiredString(forKey: "db.user")
        pgPassword = try config.requiredString(forKey: "db.password")
        pgDatabase = try config.requiredString(forKey: "db.name")
        redisHost = try config.requiredString(forKey: "redis.host")
        redisPort = try config.requiredInt(forKey: "redis.port")
        telegramApiKey = try config.requiredString(forKey: "telegram.api.key")
        telegramErrorChatId = try config.requiredString(forKey: "telegram.error.chat.id")
        alkoBaseUrl = try config.requiredString(forKey: "alko.base.url")
        alkoAgent = try config.requiredString(forKey: "alko.agent")
        alkoApiKey = try config.requiredString(forKey: "alko.api.key")
        untappdClientId = try config.requiredString(forKey: "untappd.client.id")
        untappdClientSecret = try config.requiredString(forKey: "untappd.client.secret")
        requestSignatureSalt = try config.requiredString(forKey: "request.signature.salt")
        openrouterApiKey = try config.requiredString(forKey: "openrouter.api.key")
        appleTeamId = try config.requiredString(forKey: "apple.team.id")
        appleKeyId = try config.requiredString(forKey: "apple.key.id")
        applePrivateKeyBase64 = try config.requiredString(forKey: "apple.private.key.base64")
        jwtSecret = try config.requiredString(forKey: "jwt.secret")
    }
}

public extension Logger.Level {
    init(from string: String) {
        self = Logger.Level(rawValue: string.lowercased()) ?? .info
    }
}
