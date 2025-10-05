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
    jwtKeyCollection: JWTKeyCollection,
    requestSignatureSalt _: String,
    appleService: SignInWithAppleService,
    signatureService: SignatureService,
    unauthenticatedCommands: [String: any UnauthenticatedCommandExecutable.Type],
    authenticatedCommands: [String: any AuthenticatedCommandExecutable.Type],
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
                        siwaService: appleService,
                    ),
                    commands: unauthenticatedCommands,
                )
            },
    )
    router.addRoutes(
        RouteCollection(context: AppRequestContext.self)
            .add(middleware: AuthorizerMiddleware(jwtKeyCollection: jwtKeyCollection))
            .post("/v1/rpc/:command") { request, context in
                try await handleCommand(
                    request: request,
                    context: context,
                    deps: .init(pg: pg, appleService: appleService),
                    commands: authenticatedCommands,
                )
            },
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
    let appleService: SignInWithAppleService
}

protocol AuthenticatedCommandExecutable: AuthenticatedCommand {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        deps: AuthenticatedCommandDependencies,
        request: RequestType,
    ) async throws -> ResponseType
}

private func executeAuthenticated<C: AuthenticatedCommandExecutable>(
    _: C.Type,
    request: Request,
    context: AppRequestContext,
    identity: UserIdentity,
    deps: AuthenticatedCommandDependencies,
) async throws -> Response {
    let requestData = try await request.decode(as: C.RequestType.self, context: context)
    let body = try await C.execute(
        logger: context.logger,
        identity: identity,
        deps: deps,
        request: requestData,
    )
    return try Response.makeJSONResponse(body: body)
}

func handleCommand(
    request: Request,
    context: AppRequestContext,
    deps: AuthenticatedCommandDependencies,
    commands: [String: any AuthenticatedCommandExecutable.Type],
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
        deps: deps,
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
    deps: UnauthenticatedCommandDependencies,
) async throws -> Response {
    let requestData = try await request.decode(as: C.RequestType.self, context: context)
    let body = try await C.execute(
        logger: context.logger,
        deps: deps,
        request: requestData,
    )
    return try Response.makeJSONResponse(body: body)
}

protocol UnauthenticatedCommandExecutable: UnauthenticatedCommand {
    static func execute(
        logger: Logger,
        deps: UnauthenticatedCommandDependencies,
        request: RequestType,
    ) async throws -> ResponseType
}

func handleUnauthenticatedCommand(
    request: Request,
    context: AppRequestContext,
    dependencies: UnauthenticatedCommandDependencies,
    commands: [String: any UnauthenticatedCommandExecutable.Type],
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
        deps: dependencies,
    )
}
