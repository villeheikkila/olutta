import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

struct UserController {
    let pg: PostgresClient
    let persist: RedisPersistDriver
    let jwtKeyCollection: JWTKeyCollection

    var endpoints: RouteCollection<AppRequestContext> {
        RouteCollection(context: AppRequestContext.self)
            .add(middleware: JWTAuthenticator(jwtKeyCollection: jwtKeyCollection))
            .get(.user, use: getUser)
            .post(.subscribeToStore(UUID()), use: subscribeToStore)
            .patch(.refreshDevice, use: refreshDevice)
            .delete(.subscribeToStore(UUID()), use: unsubscribeFromStore)
    }
}

extension UserController {
    func subscribeToStore(request _: Request, context: AppRequestContext) async throws -> Response {
        guard let storeId = context.parameters.get("id", as: UUID.self) else { throw HTTPError(.badRequest) }
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        try await pg.withTransaction { tx in
            try await DB.addPushNotificationSubscription(connection: tx, deviceId: user.deviceId, storeId: storeId, logger: context.logger)
            return try Response.makeOkResponse()
        }
        return try Response.makeOkResponse()
    }
}

extension UserController {
    func unsubscribeFromStore(request _: Request, context: AppRequestContext) async throws -> Response {
        guard let storeId = context.parameters.get("id", as: UUID.self) else { throw HTTPError(.badRequest) }
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        return try await pg.withTransaction { tx in
            try await DB.removePushNotificationSubscription(connection: tx, deviceId: user.deviceId, storeId: storeId, logger: context.logger)
            return try Response.makeOkResponse()
        }
    }
}

extension UserController {
    func getUser(request _: Request, context: AppRequestContext) async throws -> Response {
        let identity = context.identity
        guard let identity else {
            throw HTTPError(.internalServerError)
        }
        return try await pg.withTransaction { tx in
            let userId = identity.deviceId
            let user = try await DB.getUser(connection: tx, logger: context.logger, userId: userId)
            guard let user else { throw HTTPError(.notFound) }
            let body = UserEntity(
                id: user.id,
                subscriptions: user.subscriptions.map { .init(storeId: $0.storeId) },
            )
            return try Response.makeJSONResponse(body: body)
        }
    }
}

extension UserController {
    func refreshDevice(request: Request, context: AppRequestContext) async throws -> Response {
        let body = try await request.decode(as: UpsertPushNotificationTokenRequest.self, context: context)
        let identity = context.identity
        guard let identity else {
            throw HTTPError(.internalServerError)
        }
        return try await pg.withTransaction { tx in
            let userId = identity.deviceId
            try await DB.updateUserDevice(connection: tx, logger: context.logger, userId: userId, deviceId: identity.deviceId, pushNotificationToken: body.pushNotificationToken)
            return try Response.makeOkResponse()
        }
    }
}
