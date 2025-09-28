import Foundation
import Hummingbird
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

struct AuthController {
    let pg: PostgresClient
    let persist: RedisPersistDriver
    let jwtKeyCollection: JWTKeyCollection

    var endpoints: RouteCollection<AppRequestContext> {
        RouteCollection(context: AppRequestContext.self)
            .post(.refresh, use: refresh)
            .post(.anonymous, use: createAnonymousUser)
    }
}

extension AuthController {
    func refresh(request: Request, context: AppRequestContext) async throws -> Response {
        let refreshTokenRequest = try await request.decode(as: RefreshAccessTokenRequest.self, context: context)
        // verify payload
        let payload: AccessTokenPayload
        do {
            payload = try await jwtKeyCollection.verify(refreshTokenRequest.refreshToken, as: AccessTokenPayload.self)
        } catch {
            context.logger.warning("invalid jwt token: \(error)")
            throw HTTPError(.unauthorized)
        }
        let refreshTokenId = payload.sub
        return try await pg.withTransaction { tx in
            // check that refresh token has not been revoked
            let device = try await UserRepository.getUserDeviceByToken(connection: tx, logger: context.logger, tokenId: refreshTokenId)
            guard let device else {
                context.logger.warning("attempt to refresh access token without corresponding row in user devices")
                throw HTTPError(.unauthorized)
            }
            if device.revokedAt != nil {
                context.logger.warning("attempt to refresh access token with revoked refresh token")
                throw HTTPError(.unauthorized)
            }
            // create new access token
            let accessTokenId = UUID()
            let payload = AccessTokenPayload(
                sub: accessTokenId,
                deviceId: device.deviceId,
                userId: device.userId,
                refreshTokenId: refreshTokenId,
                iat: Date(),
                // 15 minutes
                exp: Date().addingTimeInterval(15 * 60),
            )
            let accessToken = try await jwtKeyCollection.sign(payload)
            // response
            let body = AccessTokenRefreshResponse(
                accessToken: accessToken,
                accessTokenExpiresAt: payload.exp,
            )
            return try Response.makeJSONResponse(body: body)
        }
    }

    func createAnonymousUser(request: Request, context: AppRequestContext) async throws -> Response {
        let authRequest = try await request.decode(as: AnonymousAuthRequest.self, context: context)
        return try await pg.withTransaction { tx in
            let deviceId = authRequest.deviceId
            let pushNotificationToken = authRequest.pushNotificationToken
            let now = Date()
            // create user
            let userId = try await UserRepository.createUser(connection: tx, logger: context.logger)
            // store refresh token id
            let refreshTokenExpiry = now.addingTimeInterval(356 * 24 * 60 * 60) // 1 year
            let refreshTokenId = try await UserRepository.createUserDevice(connection: tx, logger: context.logger, userId: userId, deviceId: deviceId, pushNotificationToken: pushNotificationToken, expiresAt: refreshTokenExpiry)
            let refreshTokenPayload = RefreshTokenPayload(
                sub: refreshTokenId,
                iat: now,
                exp: refreshTokenExpiry,
            )
            let refreshToken = try await jwtKeyCollection.sign(refreshTokenPayload)
            // access token
            let accessTokenId = UUID()
            let accessTokenExpiry = now.addingTimeInterval(15 * 60) // 15 minutes
            let accessTokenPayload = AccessTokenPayload(
                sub: accessTokenId,
                deviceId: deviceId,
                userId: userId,
                refreshTokenId: refreshTokenId,
                iat: now,
                exp: accessTokenExpiry,
            )
            let accessToken = try await jwtKeyCollection.sign(accessTokenPayload)
            // response
            let body = AnonymousAuthResponse(
                refreshToken: refreshToken,
                refreshTokenExpiresAt: refreshTokenExpiry,
                accessToken: accessToken,
                accessTokenExpiresAt: accessTokenExpiry,
            )
            return try Response.makeJSONResponse(body: body)
        }
    }
}
