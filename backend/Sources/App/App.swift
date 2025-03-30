import ArgumentParser
import Hummingbird
import Logging

public protocol AppArguments: Sendable {
    var serverName: String { get }
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level { get }
}

@main
struct AppCommand: AsyncParsableCommand, AppArguments {
    @Option(name: .shortAndLong)
    var serverName: String = "Ylähylly"

    @Option(name: .shortAndLong)
    var hostname: String = "localhost"

    @Option(name: .shortAndLong)
    var port: Int = 3000

    @Option(name: .shortAndLong)
    var logLevel: Logger.Level = .info

    func run() async throws {
        let environment = try await Environment().merging(with: .dotEnv())
        let app = try await buildApplication(self, environment: environment)
        try await app.runService()
    }
}

extension Logger.Level: @retroactive ExpressibleByArgument {}
