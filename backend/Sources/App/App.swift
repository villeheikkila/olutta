import ArgumentParser
import Hummingbird
import Logging

public protocol AppArguments: Sendable {
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level { get }
    var telegramApiKey: String { get }
    var telegramErrorChatId: String { get }
    var pgPort: Int { get }
    var pgHost: String { get }
    var pgUsername: String { get }
    var pgPassword: String { get }
    var pgDatabase: String { get }
    var alkoBaseUrl: String { get }
    var alkoApiKey: String { get }
    var alkoAgent: String { get }
    var untappdClientId: String { get }
    var untappdClientSecret: String { get }
}

@main
struct AppCommand: AsyncParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var hostname: String = Environment().get("HOST") ?? "127.0.0.1"

    @Option(name: .shortAndLong)
    var port: Int = Environment().get("PORT", as: Int.self) ?? 3000

    @Option(name: .shortAndLong)
    var logLevel: Logger.Level = .info

    @Option(name: .long)
    var pgHost: String = Environment().get("DB_HOST") ?? "localhost"

    @Option(name: .long)
    var pgPort: Int = Environment().get("DB_PORT", as: Int.self) ?? 5432

    @Option(name: .long)
    var pgUsername: String = Environment().get("DB_USER") ?? "postgres"

    @Option(name: .long)
    var pgPassword: String = Environment().get("DB_PASSWORD") ?? "postgres"

    @Option(name: .long)
    var pgDatabase: String = Environment().get("DB_NAME") ?? "postgres"

    @Option(name: .long)
    var telegramApiKey: String = Environment().get("TELEGRAM_API_KEY")!

    @Option(name: .long)
    var telegramErrorChatId: String = Environment().get("TELEGRAM_ERROR_CHAT_ID")!

    @Option(name: .long)
    var alkoBaseUrl: String = Environment().get("ALKO_BASE_URL")!

    @Option(name: .long)
    var alkoAgent: String = Environment().get("ALKO_AGENT")!

    @Option(name: .long)
    var alkoApiKey: String = Environment().get("ALKO_API_KEY")!

    @Option(name: .long)
    var untappdClientId: String = Environment().get("UNTAPPD_CLIENT_ID")!

    @Option(name: .long)
    var untappdClientSecret: String = Environment().get("UNTAPPD_CLIENT_SECRET")!

    func run() async throws {
        let app = try await buildApplication(self)
        try await app.runService()
    }
}

extension Logger.Level: @retroactive ExpressibleByArgument {}
