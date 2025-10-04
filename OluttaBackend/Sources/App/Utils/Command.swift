import Foundation
import Hummingbird
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

protocol AuthenticatedCommandExecutable: AuthenticatedCommand {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        pg: PostgresClient,
        request: RequestType,
    ) async throws -> ResponseType
}

protocol UnauthenticatedCommandExecutable: UnauthenticatedCommand {
    static func execute(
        logger: Logger,
        pg: PostgresClient,
        jwtKeyCollection: JWTKeyCollection,
        request: RequestType,
    ) async throws -> ResponseType
}

private func executeUnauthenticated<C: UnauthenticatedCommandExecutable>(
    _: C.Type,
    request: Request,
    context: AppRequestContext,
    pg: PostgresClient,
    jwtKeyCollection: JWTKeyCollection,
) async throws -> Response {
    let requestData = try await request.decode(as: C.RequestType.self, context: context)
    let body = try await C.execute(
        logger: context.logger,
        pg: pg,
        jwtKeyCollection: jwtKeyCollection,
        request: requestData,
    )
    return try Response.makeJSONResponse(body: body)
}

private func executeAuthenticated<C: AuthenticatedCommandExecutable>(
    _: C.Type,
    request: Request,
    context: AppRequestContext,
    identity: UserIdentity,
    pg: PostgresClient,
    persist _: RedisPersistDriver,
) async throws -> Response {
    let requestData = try await request.decode(as: C.RequestType.self, context: context)
    let body = try await C.execute(
        logger: context.logger,
        identity: identity,
        pg: pg,
        request: requestData,
    )
    return try Response.makeJSONResponse(body: body)
}

func handleUnauthenticatedCommand(
    request: Request,
    context: AppRequestContext,
    pg: PostgresClient,
    persist _: RedisPersistDriver,
    jwtKeyCollection: JWTKeyCollection,
) async throws -> Response {
    guard let commandName = context.parameters.get("command", as: String.self) else {
        throw HTTPError(.badRequest)
    }
    switch commandName {
    case RefreshTokensCommand.name:
        return try await executeUnauthenticated(RefreshTokensCommand.self, request: request, context: context, pg: pg, jwtKeyCollection: jwtKeyCollection)
    case CreateAnonymousUserCommand.name:
        return try await executeUnauthenticated(CreateAnonymousUserCommand.self, request: request, context: context, pg: pg, jwtKeyCollection: jwtKeyCollection)
    default:
        throw HTTPError(.badRequest)
    }
}

func handleCommand(
    request: Request,
    context: AppRequestContext,
    pg: PostgresClient,
    persist: RedisPersistDriver,
    jwtKeyCollection _: JWTKeyCollection,
) async throws -> Response {
    guard let commandName = context.parameters.get("command", as: String.self) else {
        throw HTTPError(.badRequest)
    }
    guard let identity = context.identity else {
        throw HTTPError(.unauthorized)
    }
    switch commandName {
    case RefreshDeviceCommand.name:
        return try await executeAuthenticated(RefreshDeviceCommand.self, request: request, context: context, identity: identity, pg: pg, persist: persist)
    case GetUserCommand.name:
        return try await executeAuthenticated(GetUserCommand.self, request: request, context: context, identity: identity, pg: pg, persist: persist)
    case SubscribeToStoreCommand.name:
        return try await executeAuthenticated(SubscribeToStoreCommand.self, request: request, context: context, identity: identity, pg: pg, persist: persist)
    case UnsubscribeFromStoreCommand.name:
        return try await executeAuthenticated(UnsubscribeFromStoreCommand.self, request: request, context: context, identity: identity, pg: pg, persist: persist)
    case GetAppData.name:
        return try await executeAuthenticated(GetAppData.self, request: request, context: context, identity: identity, pg: pg, persist: persist)
    case GetProductsByStoreIdCommand.name:
        return try await executeAuthenticated(GetProductsByStoreIdCommand.self, request: request, context: context, identity: identity, pg: pg, persist: persist)
    default:
        throw HTTPError(.badRequest)
    }
}
