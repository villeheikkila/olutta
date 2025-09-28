import Foundation
import Hummingbird
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

struct AuthController {
    let pg: PostgresClient
    let logger: Logger
    let persist: RedisPersistDriver
    let jwtKeyCollection: JWTKeyCollection
    let deviceRepository: DeviceRepository

    var endpoints: RouteCollection<AppRequestContext> {
        RouteCollection(context: AppRequestContext.self)
            .post(.anonymous, use: anonymous)
    }
}

struct AnonymousUserPayload: JWTPayload {
    let sub: UUID
    let deviceId: UUID
    let tokenId: UUID
    let iat: Date
    let exp: Date

    func verify(using _: some JWTAlgorithm) throws {
        try ExpirationClaim(value: exp).verifyNotExpired()
    }
}

extension AuthController {
    func anonymous(request: Request, context: AppRequestContext) async throws -> Response {
        let authRequest = try await request.decode(as: AnonymousAuthRequest.self, context: context)
        return try await pg.withTransaction { tx in
            let identity = context.identity
            let tokenId = UUID()
            let deviceId = identity?.deviceId ?? authRequest.deviceId
            let (_, isNew, storeIds) = try await deviceRepository.upsertDevice(tx, device: .init(id: authRequest.deviceId, pushNotificationToken: authRequest.pushNotificationToken, isSandbox: authRequest.isDevelopmentDevice, tokenId: tokenId))
            if isNew {
                context.logger.info("new device id registered")
            }
            let payload = AnonymousUserPayload(
                sub: tokenId,
                deviceId: authRequest.deviceId,
                tokenId: tokenId,
                iat: Date(),
                exp: Date().addingTimeInterval(90 * 24 * 3600),
            )
            let token = try await jwtKeyCollection.sign(payload)
            let body = AnonymousAuthResponse(
                deviceId: deviceId,
                token: token,
                expiresAt: payload.exp,
                subscribedStoreIds: storeIds,
            )
            return try Response.makeJSONResponse(body: body)
        }
    }
}
