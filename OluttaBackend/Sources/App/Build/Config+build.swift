func buildConfig(args: AppArguments, env: Env) -> Config {
    Config(
        appName: args.serverName,
        pgHost: env.pgHost,
        pgPort: env.pgPort,
        pgUsername: env.pgUsername,
        pgPassword: env.pgPassword,
        pgDatabase: env.pgDatabase,
        redisHostname: env.redisHostname,
        redisPort: env.redisPort,
        alkoApiKey: env.alkoApiKey,
        alkoBaseUrl: env.alkoBaseUrl,
        alkoAgent: env.alkoAgent,
        untappdClientId: env.untappdClientId,
        untappdClientSecret: env.untappdClientSecret,
        requestSignatureSalt: env.requestSignatureSalt,
        openrouterApiKey: env.openrouterApiKey,
        jwtSecret: env.jwtSecret
    )
}

struct Config: Sendable {
    let appName: String
    let pgHost: String
    let pgPort: Int
    let pgUsername: String
    let pgPassword: String
    let pgDatabase: String
    let redisHostname: String
    let redisPort: Int
    let alkoApiKey: String
    let alkoBaseUrl: String
    let alkoAgent: String
    let untappdClientId: String
    let untappdClientSecret: String
    let requestSignatureSalt: String
    let openrouterApiKey: String
    let jwtSecret: String
}
