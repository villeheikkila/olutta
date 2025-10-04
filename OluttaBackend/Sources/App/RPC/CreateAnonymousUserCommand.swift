import Foundation
import Hummingbird
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

extension CreateAnonymousUserCommand: UnauthenticatedCommandExecutable {
    static func execute(
        logger: Logger,
        pg: PostgresClient,
        jwtKeyCollection: JWTKeyCollection,
        request _: Request,
    ) async throws -> Response {
        try await pg.withTransaction { tx in
            let now = Date()
            // create user
            let userId = try await UserRepository.createUser(connection: tx, logger: logger)
            // store refresh token id
            let refreshTokenExpiry = now.addingTimeInterval(356 * 24 * 60 * 60) // 1 year
            let refreshTokenId = try await UserRepository.createRefreshToken(connection: tx, logger: logger, userId: userId, expiresAt: refreshTokenExpiry)
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
                userId: userId,
                refreshTokenId: refreshTokenId,
                iat: now,
                exp: accessTokenExpiry,
            )
            let accessToken = try await jwtKeyCollection.sign(accessTokenPayload)
            // response
            return Response(
                refreshToken: refreshToken,
                refreshTokenExpiresAt: refreshTokenExpiry,
                accessToken: accessToken,
                accessTokenExpiresAt: accessTokenExpiry,
            )
        }
    }
}
