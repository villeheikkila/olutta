import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

func makeRouter(pg: PostgresClient, persist: RedisPersistDriver, jwtKeyCollection: JWTKeyCollection, requestSignatureSalt _: String) -> Router<AppRequestContext> {
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
    case let .authenticated(command):
        guard let identity = context.identity else {
            throw HTTPError(.unauthorized)
        }
        let commandType: any AuthenticatedCommand.Type = switch command {
        case .refreshDevice: RefreshDeviceCommand.self
        case .getUser: GetUserCommand.self
        case .subscribeToStore: SubscribeToStoreCommand.self
        case .unsubscribeFromStore: UnsubscribeFromStoreCommand.self
        case .getStores: GetStoresCommand.self
        case .getProductsByStoreId: GetProductsByStoreIdCommand.self
        }
        let body = try await execute(commandType, request: request, context: context, identity: identity, pg: pg, persist: persist)
        return try Response.makeJSONResponse(body: body)
    case let .unauthenticated(command):
        let commandType: any UnauthenticatedCommand.Type = switch command {
        case .refreshAccessToken: RefreshTokensCommand.self
        case .createAnonymousUser: CreateAnonymousUserCommand.self
        }
        let body = try await execute(commandType, request: request, context: context, pg: pg, jwtKeyCollection: jwtKeyCollection)
        return try Response.makeJSONResponse(body: body)
    }
}
