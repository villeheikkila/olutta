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
        appleKeyId = try configReader.requiredString(forKey: "apple.key.id")
        apnsTopic = try configReader.requiredString(forKey: "apple.apns.topic")
        let apnsToken = try configReader.requiredString(forKey: "apple.apns.token").decodeBase64()
        guard let apnsToken else {
            fatalError("Invalid APNS token")
        }
        self.apnsToken = apnsToken
        jwtSecret = try configReader.requiredString(forKey: "jwt.secret")
    }
}

public extension Logger.Level {
    init(from string: String) {
        self = Logger.Level(rawValue: string.lowercased()) ?? .info
    }
}

func decodeBase64(_ base64String: String) -> String? {
    // Try direct decode first
    if let data = Data(base64Encoded: base64String),
       let result = String(data: data, encoding: .utf8)
    {
        return result
    }

    // Try with ignore unknown characters
    if let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
       let result = String(data: data, encoding: .utf8)
    {
        return result
    }

    // Try removing quotes if present
    let cleaned = base64String.replacingOccurrences(of: "\"", with: "")
    if let data = Data(base64Encoded: cleaned),
       let result = String(data: data, encoding: .utf8)
    {
        return result
    }

    return nil
}
