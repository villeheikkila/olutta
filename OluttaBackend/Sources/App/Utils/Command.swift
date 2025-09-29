import Foundation
import Hummingbird
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

func execute<C: AuthenticatedCommand>(
    _: C.Type,
    request: Request,
    context: AppRequestContext,
    identity: UserIdentity,
    pg: PostgresClient,
    persist _: RedisPersistDriver,
) async throws -> C.ResponseType {
    let requestData = try await request.decode(as: C.RequestType.self, context: context)
    return try await C.execute(
        logger: context.logger,
        identity: identity,
        pg: pg,
        request: requestData,
    )
}

func execute<C: UnauthenticatedCommand>(
    _: C.Type,
    request: Request,
    context: AppRequestContext,
    pg: PostgresClient,
    jwtKeyCollection: JWTKeyCollection,
) async throws -> C.ResponseType {
    let requestData = try await request.decode(as: C.RequestType.self, context: context)
    return try await C.execute(
        logger: context.logger,
        pg: pg,
        jwtKeyCollection: jwtKeyCollection,
        request: requestData,
    )
}

protocol AuthenticatedCommand: CommandMetadata {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        pg: PostgresClient,
        request: RequestType,
    ) async throws -> ResponseType
}

protocol UnauthenticatedCommand: CommandMetadata {
    static func execute(
        logger: Logger,
        pg: PostgresClient,
        jwtKeyCollection: JWTKeyCollection,
        request: RequestType,
    ) async throws -> ResponseType
}
