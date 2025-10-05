import Configuration
import Logging

@main
struct Entrypoint {
    static func main() async throws {
        let configReader = try await ConfigReader(provider: EnvironmentVariablesProvider(environmentFilePath: ".env"))
        let config = try Config(configReader: configReader)
        let app = try await makeServer(config: config)
        try await app.runService()
    }
}
