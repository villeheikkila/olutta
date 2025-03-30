func buildConfig(args: AppArguments, env: Env) -> Config {
    Config(
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
