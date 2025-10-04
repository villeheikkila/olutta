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
    let appleAPNSKeyId: String
    let appleBundleId: String
    let siwaToken: String
    let siwaKeyId: String
    let apnsToken: String
    let apnsTopic: String
    let jwtSecret: String
    let logLevel: Logger.Level

    init(configReader: ConfigReader) throws {
        serverName = try configReader.requiredString(forKey: "server.name")
        host = try configReader.requiredString(forKey: "server.host")
        port = try configReader.requiredInt(forKey: "server.port")
        let logLevel = try configReader.requiredString(forKey: "server.log.level")
        self.logLevel = .init(from: logLevel)
        pgHost = try configReader.requiredString(forKey: "db.host")
        pgPort = try configReader.requiredInt(forKey: "db.port")
        pgUsername = try configReader.requiredString(forKey: "db.user")
        pgPassword = try configReader.requiredString(forKey: "db.password")
        pgDatabase = try configReader.requiredString(forKey: "db.name")
        redisHost = try configReader.requiredString(forKey: "redis.host")
        redisPort = try configReader.requiredInt(forKey: "redis.port")
        telegramApiKey = try configReader.requiredString(forKey: "telegram.api.key")
        telegramErrorChatId = try configReader.requiredString(forKey: "telegram.error.chat.id")
        alkoBaseUrl = try configReader.requiredString(forKey: "alko.base.url")
        alkoAgent = try configReader.requiredString(forKey: "alko.agent")
        alkoApiKey = try configReader.requiredString(forKey: "alko.api.key")
        untappdClientId = try configReader.requiredString(forKey: "untappd.client.id")
        untappdClientSecret = try configReader.requiredString(forKey: "untappd.client.secret")
        requestSignatureSalt = try configReader.requiredString(forKey: "request.signature.salt")
        openrouterApiKey = try configReader.requiredString(forKey: "openrouter.api.key")
        appleTeamId = try configReader.requiredString(forKey: "apple.team.id")
        appleAPNSKeyId = try configReader.requiredString(forKey: "apple.apns.key.id")
        let apnsToken = try configReader.requiredString(forKey: "apple.apns.token").decodeBase64()
        guard let apnsToken else {
            throw ConfigError.invalidAPNSToken
        }
        siwaKeyId = try configReader.requiredString(forKey: "apple.siwa.key.id")
        siwaToken = try configReader.requiredString(forKey: "apple.siwa.token")
        appleBundleId = try configReader.requiredString(forKey: "apple.bundle.id")
        apnsTopic = try configReader.requiredString(forKey: "apple.apns.topic")
        self.apnsToken = apnsToken
        jwtSecret = try configReader.requiredString(forKey: "jwt.secret")
    }
}

enum ConfigError: Error {
    case invalidAPNSToken
}
