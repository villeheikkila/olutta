import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

func makeRPCEndpoint(pg: PostgresClient, persist: RedisPersistDriver, jwtKeyCollection: JWTKeyCollection, requestSignatureSalt: String) -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.info)
        // RequestSignatureMiddleware(secretKey: requestSignatureSalt)
        UniqueRequestMiddleware(persist: persist)
    }
    router.get("/health") { _, _ -> HTTPResponse.Status in
        return .ok
    }
    router.addRoutes(RouteCollection(context: AppRequestContext.self)
        .add(middleware: JWTAuthenticator(jwtKeyCollection: jwtKeyCollection))
        .post("/v1/rpc/:command", use: { request, context in
            try await handleCommand(request: request, context: context, pg: pg, persist: persist, jwtKeyCollection: jwtKeyCollection)
        }))
    return router
}

func handleCommand(request: Request, context: AppRequestContext, pg: PostgresClient, persist: RedisPersistDriver, jwtKeyCollection: JWTKeyCollection) async throws -> Response {
    guard let commandName = context.parameters.get("command", as: String.self), let command = Command(from: commandName) else {
        throw HTTPError(.badRequest)
    }
    switch command {
    case .authenticated(let command):
        guard let identity = context.identity else {
            throw HTTPError(.unauthorized)
        }
        let body = try await executeAuthenticatedCommand(
            command: command,
            request: request,
            context: context,
            identity: identity,
            pg: pg,
            persist: persist
        )
        return try Response.makeJSONResponse(body: body)
    case .unauthenticated(let command):
        let body = try await executeUnauthenticatedCommand(command: command, request: request, context: context, pg: pg, jwtKeyCollection: jwtKeyCollection)
        return try Response.makeJSONResponse(body: body)
    }
}

private func executeUnauthenticatedCommand(
    command: UnauthenticatedCommand,
    request: Request,
    context: AppRequestContext,
    pg: PostgresClient,
    jwtKeyCollection: JWTKeyCollection
) async throws -> any Codable {
    switch command {
    case .refreshAccessToken:
        let requestData = try await request.decode(as: RefreshAccessTokenCommand.Request.self, context: context)
        return try await RefreshAccessTokenCommand.execute(
            logger: context.logger,
            pg: pg,
            jwtKeyCollection: jwtKeyCollection,
            request: requestData
        )
    case .createAnonymousUser:
        let requestData = try await request.decode(as: CreateAnonymousUserCommand.Request.self, context: context)
        return try await CreateAnonymousUserCommand.execute(
            logger: context.logger,
            pg: pg,
            jwtKeyCollection: jwtKeyCollection,
            request: requestData
        )
    }
}

private func executeAuthenticatedCommand(
    command: AuthenticatedCommand,
    request: Request,
    context: AppRequestContext,
    identity: UserIdentity,
    pg: PostgresClient, persist: RedisPersistDriver
) async throws -> any Codable {
    switch command {
    case .refreshDevice:
        let requestData = try await request.decode(as: RefreshDeviceCommand.Request.self, context: context)
        return try await RefreshDeviceCommand.execute(
            logger: context.logger,
            identity: identity,
            pg: pg,
            request: requestData
        )
    case .getUser:
        let requestData = try await request.decode(as: GetUserCommand.Request.self, context: context)
        return try await GetUserCommand.execute(
            logger: context.logger,
            identity: identity,
            pg: pg,
            request: requestData
        )
    case .subscribeToStore:
        let requestData = try await request.decode(as: SubscribeToStoreCommand.Request.self, context: context)
        return try await SubscribeToStoreCommand.execute(
            logger: context.logger,
            identity: identity,
            pg: pg,
            request: requestData
        )
    case .unsubscribeFromStore:
        let requestData = try await request.decode(as: UnsubscribeFromStoreCommand.Request.self, context: context)
        return try await UnsubscribeFromStoreCommand.execute(
            logger: context.logger,
            identity: identity,
            pg: pg,
            request: requestData
        )
    case .getStores:
        let requestData = try await request.decode(as: GetStoresCommand.Request.self, context: context)
        return try await GetStoresCommand.execute(
            logger: context.logger,
            identity: identity,
            pg: pg,
            persist: persist,
            request: requestData
        )
    case .getProductsByStoreId:
        let requestData = try await request.decode(as: GetProductsByStoreIdCommand.Request.self, context: context)
        return try await GetProductsByStoreIdCommand.execute(
            logger: context.logger,
            identity: identity,
            pg: pg,
            request: requestData
        )
    }
}
