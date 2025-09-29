import Foundation
import Hummingbird
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

extension RefreshAccessTokenCommand: UnauthenticatedCommand {
    static func execute(
        logger: Logger,
        pg: PostgresClient,
        jwtKeyCollection: JWTKeyCollection,
        request: Request,
    ) async throws -> Response {
        // verify payload
        let payload: AccessTokenPayload
        do {
            payload = try await jwtKeyCollection.verify(request.refreshToken, as: AccessTokenPayload.self)
        } catch {
            logger.warning("invalid jwt token: \(error)")
            throw HTTPError(.unauthorized)
        }
        let refreshTokenId = payload.sub
        return try await pg.withTransaction { tx in
            // check that refresh token has not been revoked
            let device = try await UserRepository.getUserDeviceByToken(connection: tx, logger: logger, tokenId: refreshTokenId)
            guard let device else {
                logger.warning("attempt to refresh access token without corresponding row in user devices")
                throw HTTPError(.unauthorized)
            }
            if device.revokedAt != nil {
                logger.warning("attempt to refresh access token with revoked refresh token")
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
            return Response(
                accessToken: accessToken,
                accessTokenExpiresAt: payload.exp,
            )
        }
    }
}
