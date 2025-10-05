import Foundation
import Hummingbird
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

// dependencies
struct CommandDependencies {
    let pg: PostgresClient
    let persist: RedisPersistDriver
    let decoder: JSONDecoder
    let encoder: JSONEncoder
    let signatureService: SignatureService
    let jwtKeyCollection: JWTKeyCollection
    let siwaService: SignInWithAppleService
}

// context
struct AppRequestContext: RequestContext {
    var coreContext: CoreRequestContextStorage
    var identity: UserIdentity?

    init(source: ApplicationRequestContextSource) {
        coreContext = .init(source: source)
    }
}

// router
func makeRouter(
    deps: CommandDependencies,
    commands: [any CommandExecutable.Type],
) -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    let commandMap = Dictionary(
        uniqueKeysWithValues: commands.map { ($0.name, $0) }
    )
    router.addMiddleware {
        LogRequestsMiddleware(.debug)
        RequestSignatureMiddleware(signatureService: deps.signatureService)
        UniqueRequestMiddleware(persist: deps.persist)
        AuthorizerMiddleware(jwtKeyCollection: deps.jwtKeyCollection)
    }
    router.get("/health") { _, _ -> HTTPResponse.Status in
        .ok
    }
    router.addRoutes(
        RouteCollection(context: AppRequestContext.self)
            .post("/v1/rpc/:command") { request, context in
                try await handleCommand(
                    request: request,
                    context: context,
                    deps: deps,
                    commandMap: commandMap,
                )
            },
    )
    return router
}

private func handleCommand(
    request: Request,
    context: AppRequestContext,
    deps: CommandDependencies,
    commandMap: [String: any CommandExecutable.Type],
) async throws -> Response {
    guard let commandName = context.parameters.get("command", as: String.self) else {
        throw HTTPError(.badRequest)
    }
    guard let commandType = commandMap[commandName] else {
        throw HTTPError(.badRequest)
    }
    // authenticated
    if commandType.authenticated {
        guard let identity = context.identity else {
            context.logger.warning("call made to authorized route without authorization")
            throw HTTPError(.unauthorized)
        }
        guard let authenticatedCommandType = commandType as? any AuthenticatedCommandExecutable.Type else {
            throw HTTPError(.internalServerError)
        }
        return try await executeAuthenticated(
            authenticatedCommandType,
            request: request,
            context: context,
            identity: identity,
            deps: deps,
        )
    }
    // unauthenticated
    guard let unauthenticatedCommandType = commandType as? any UnauthenticatedCommandExecutable.Type else {
        throw HTTPError(.internalServerError)
    }
    return try await executeUnauthenticated(
        unauthenticatedCommandType,
        request: request,
        context: context,
        deps: deps,
    )
}

// authenticated
protocol AuthenticatedCommandExecutable: AuthenticatedCommand, CommandExecutable {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        deps: CommandDependencies,
        request: RequestType,
    ) async throws -> ResponseType
}

private func executeAuthenticated<C: AuthenticatedCommandExecutable>(
    _: C.Type,
    request: Request,
    context: AppRequestContext,
    identity: UserIdentity,
    deps: CommandDependencies,
) async throws -> Response {
    let requestData = try await request.decode(as: C.RequestType.self, context: context)
    return try await withCache(
        command: C.self,
        request: requestData,
        logger: context.logger,
        persist: deps.persist,
        decoder: deps.decoder,
        encoder: deps.encoder,
    ) {
        try await C.execute(
            logger: context.logger,
            identity: identity,
            deps: deps,
            request: requestData,
        )
    }
}

// unauthenticated
protocol UnauthenticatedCommandExecutable: UnauthenticatedCommand, CommandExecutable {
    static func execute(
        logger: Logger,
        deps: CommandDependencies,
        request: RequestType,
    ) async throws -> ResponseType
}

private func executeUnauthenticated<C: UnauthenticatedCommandExecutable>(
    _: C.Type,
    request: Request,
    context: AppRequestContext,
    deps: CommandDependencies,
) async throws -> Response {
    let requestData = try await request.decode(as: C.RequestType.self, context: context)
    let body = try await C.execute(
        logger: context.logger,
        deps: deps,
        request: requestData,
    )
    return try Response.makeJSONResponse(body: body)
}

// command caching
enum CachePolicy: Sendable {
    case noCache
    case cache(key: String, ttl: Duration)
}

protocol CacheableCommand: CommandMetadata {
    static func cachePolicy(for request: RequestType) -> CachePolicy
}

extension CommandMetadata {
    static func cachePolicy(for _: RequestType) -> CachePolicy {
        .noCache
    }
}

private func withCache<C: CommandMetadata>(
    command _: C.Type,
    request: C.RequestType,
    logger: Logger,
    persist: RedisPersistDriver,
    decoder: JSONDecoder,
    encoder: JSONEncoder,
    execute: () async throws -> C.ResponseType,
) async throws -> Response {
    let policy = C.cachePolicy(for: request)
    // early return
    guard case let .cache(key, ttl) = policy else {
        let body = try await execute()
        return try Response.makeJSONResponse(body: body)
    }
    let cacheKey = "command:\(C.name):\(key)"
    // load from cache
    do {
        if let cachedData = try await persist.get(key: cacheKey, as: Data.self) {
            logger.debug("loaded \(C.name) result from cache", metadata: ["key": .string(cacheKey)])
            let cachedResponse = try decoder.decode(C.ResponseType.self, from: cachedData)
            return try Response.makeJSONResponse(body: cachedResponse)
        }
    } catch {
        logger.warning("failed to read \(C.name) from cache", metadata: [
            "key": .string(cacheKey),
            "error": .string(error.localizedDescription),
        ])
    }
    let body = try await execute()
    // populate cache
    do {
        let data = try encoder.encode(body)
        try await persist.set(key: cacheKey, value: data, expires: ttl)
        logger.debug("cached result for \(C.name)", metadata: [
            "key": .string(cacheKey),
            "ttl": .stringConvertible(ttl),
        ])
    } catch {
        logger.warning("cache write error for \(C.name)", metadata: [
            "key": .string(cacheKey),
            "error": .string(error.localizedDescription),
        ])
    }
    return try Response.makeJSONResponse(body: body)
}
