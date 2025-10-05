import Foundation
import Hummingbird
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

func makeRouter(
    pg: PostgresClient,
    persist: RedisPersistDriver,
    decoder: JSONDecoder,
    encoder: JSONEncoder,
    jwtKeyCollection: JWTKeyCollection,
    appleService: SignInWithAppleService,
    signatureService: SignatureService,
    unauthenticatedCommands: [String: any UnauthenticatedCommandExecutable.Type],
    authenticatedCommands: [String: any AuthenticatedCommandExecutable.Type]
) -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.debug)
        RequestSignatureMiddleware(signatureService: signatureService)
        UniqueRequestMiddleware(persist: persist)
    }
    router.get("/health") { _, _ -> HTTPResponse.Status in
        .ok
    }
    router.addRoutes(
        RouteCollection(context: AppRequestContext.self)
            .post("/v1/rpc/:command/unauthenticated") { request, context in
                try await handleUnauthenticatedCommand(
                    request: request,
                    context: context,
                    dependencies: .init(
                        pg: pg,
                        jwtKeyCollection: jwtKeyCollection,
                        siwaService: appleService
                    ),
                    commands: unauthenticatedCommands
                )
            }
    )
    router.addRoutes(
        RouteCollection(context: AppRequestContext.self)
            .add(middleware: AuthorizerMiddleware(jwtKeyCollection: jwtKeyCollection))
            .post("/v1/rpc/:command") { request, context in
                try await handleCommand(
                    request: request,
                    context: context,
                    deps: .init(pg: pg, persist: persist, decoder: decoder, encoder: encoder, appleService: appleService),
                    commands: authenticatedCommands
                )
            }
    )
    return router
}

// context
struct AppRequestContext: RequestContext {
    var coreContext: CoreRequestContextStorage
    var identity: UserIdentity?

    init(source: ApplicationRequestContextSource) {
        coreContext = .init(source: source)
    }
}

// authenticated command
struct AuthenticatedCommandDependencies {
    let pg: PostgresClient
    let persist: RedisPersistDriver
    let decoder: JSONDecoder
    let encoder: JSONEncoder
    let appleService: SignInWithAppleService
}

protocol AuthenticatedCommandExecutable: AuthenticatedCommand {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        deps: AuthenticatedCommandDependencies,
        request: RequestType
    ) async throws -> ResponseType
}

private func executeAuthenticated<C: AuthenticatedCommandExecutable>(
    _: C.Type,
    request: Request,
    context: AppRequestContext,
    identity: UserIdentity,
    deps: AuthenticatedCommandDependencies
) async throws -> Response {
    let requestData = try await request.decode(as: C.RequestType.self, context: context)
    return try await withCache(
        command: C.self,
        request: requestData,
        context: context,
        deps: deps
    ) {
        try await C.execute(
            logger: context.logger,
            identity: identity,
            deps: deps,
            request: requestData
        )
    }
}

private func handleCommand(
    request: Request,
    context: AppRequestContext,
    deps: AuthenticatedCommandDependencies,
    commands: [String: any AuthenticatedCommandExecutable.Type]
) async throws -> Response {
    guard let commandName = context.parameters.get("command", as: String.self) else {
        throw HTTPError(.badRequest)
    }
    guard let identity = context.identity else {
        throw HTTPError(.unauthorized)
    }
    guard let commandType = commands[commandName] else {
        throw HTTPError(.badRequest)
    }
    return try await executeAuthenticated(
        commandType,
        request: request,
        context: context,
        identity: identity,
        deps: deps
    )
}

// unauthenticated command
struct UnauthenticatedCommandDependencies {
    let pg: PostgresClient
    let jwtKeyCollection: JWTKeyCollection
    let siwaService: SignInWithAppleService
}

private func executeUnauthenticated<C: UnauthenticatedCommandExecutable>(
    _: C.Type,
    request: Request,
    context: AppRequestContext,
    deps: UnauthenticatedCommandDependencies
) async throws -> Response {
    let requestData = try await request.decode(as: C.RequestType.self, context: context)
    let body = try await C.execute(
        logger: context.logger,
        deps: deps,
        request: requestData
    )
    return try Response.makeJSONResponse(body: body)
}

protocol UnauthenticatedCommandExecutable: UnauthenticatedCommand {
    static func execute(
        logger: Logger,
        deps: UnauthenticatedCommandDependencies,
        request: RequestType
    ) async throws -> ResponseType
}

private func handleUnauthenticatedCommand(
    request: Request,
    context: AppRequestContext,
    dependencies: UnauthenticatedCommandDependencies,
    commands: [String: any UnauthenticatedCommandExecutable.Type]
) async throws -> Response {
    guard let commandName = context.parameters.get("command", as: String.self) else {
        throw HTTPError(.badRequest)
    }
    guard let commandType = commands[commandName] else {
        throw HTTPError(.badRequest)
    }
    return try await executeUnauthenticated(
        commandType,
        request: request,
        context: context,
        deps: dependencies
    )
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
    context: AppRequestContext,
    deps: AuthenticatedCommandDependencies,
    execute: () async throws -> C.ResponseType
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
        if let cachedData = try await deps.persist.get(key: cacheKey, as: Data.self) {
            context.logger.debug("loaded \(C.name) result from cache", metadata: ["key": .string(cacheKey)])
            let cachedResponse = try deps.decoder.decode(C.ResponseType.self, from: cachedData)
            return try Response.makeJSONResponse(body: cachedResponse)
        }
    } catch {
        context.logger.warning("failed to read \(C.name) from cache", metadata: [
            "key": .string(cacheKey),
            "error": .string(error.localizedDescription)
        ])
    }
    let body = try await execute()
    // populate cache
    do {
        let data = try deps.encoder.encode(body)
        try await deps.persist.set(key: cacheKey, value: data, expires: ttl)
        context.logger.debug("cached result for \(C.name)", metadata: [
            "key": .string(cacheKey),
            "ttl": .stringConvertible(ttl)
        ])
    } catch {
        context.logger.warning("cache write error for \(C.name)", metadata: [
            "key": .string(cacheKey),
            "error": .string(error.localizedDescription)
        ])
    }
    return try Response.makeJSONResponse(body: body)
}
