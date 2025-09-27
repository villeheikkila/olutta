import Configuration
import Hummingbird
import Logging

@main
struct App {
    static func main() async throws {
        let configReader = try await ConfigReader(provider: EnvironmentVariablesProvider(environmentFilePath: ".env"))
        let config = try Config(config: configReader)
        let app = try await buildApplication(config: config)
        try await app.runService()
    }
}
