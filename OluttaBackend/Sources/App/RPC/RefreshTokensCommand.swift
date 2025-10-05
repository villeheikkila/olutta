import Foundation
import Hummingbird
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

extension RefreshTokensCommand: UnauthenticatedCommandExecutable {
    static func execute(
        logger: Logger,
        deps: UnauthenticatedCommandDependencies,
        request: Request,
    ) async throws -> Response {
        // verify payload
        let payload = try await verifyRefreshToken(
            refreshToken: request.refreshToken,
            jwtKeyCollection: deps.jwtKeyCollection,
            logger: logger,
        )
        return try await deps.pg.withTransaction { tx in
            // check that refresh token has not been revoked
            let refreshTokenVerificationRow = try await UserRepository.getRefreshTokenById(connection: tx, logger: logger, refreshTokenId: payload.sub)
            guard let refreshTokenVerificationRow else {
                logger.warning("attempt to refresh access token without corresponding row")
                throw HTTPError(.unauthorized)
            }
            if refreshTokenVerificationRow.revokedAt != nil {
                logger.warning("attempt to refresh access token with revoked refresh token")
                throw HTTPError(.unauthorized)
            }
            let now = Date()
            // refresh third party auth provider tokens
            let authProviders = try await refreshAuthProviderTokens(
                payload: payload,
                dependencies: deps,
                now: now,
            )
            // create new refresh token
            let refreshTokenExpiry = payload.exp // do not extend the refresh token exp period, we only want to use up the old token
            let newRefreshTokenId = UUID()
            let refreshTokenId = try await UserRepository.updateRefreshToken(
                connection: tx,
                logger: logger,
                userId: refreshTokenVerificationRow.userId,
                oldTokenId: payload.sub,
                newTokenId: newRefreshTokenId,
                expiresAt: refreshTokenExpiry,
            )
            let refreshTokenPayload = RefreshTokenPayload(
                sub: refreshTokenId,
                iat: now,
                exp: refreshTokenExpiry,
                provider: authProviders.refreshTokenProvider,
            )
            let refreshToken = try await deps.jwtKeyCollection.sign(refreshTokenPayload)
            // create new access token
            let accessTokenId = UUID()
            let accessTokenExpiry = now.addingTimeInterval(15 * 60) // 15 minutes
            let accessTokenPayload = AccessTokenPayload(
                sub: accessTokenId,
                userId: refreshTokenVerificationRow.userId,
                refreshTokenId: newRefreshTokenId,
                iat: now,
                exp: accessTokenExpiry,
                provider: authProviders.accessTokenProvider,
            )
            let accessToken = try await deps.jwtKeyCollection.sign(accessTokenPayload)
            // return response
            return Response(
                accessToken: accessToken,
                accessTokenExpiresAt: accessTokenExpiry,
                refreshToken: refreshToken,
                refreshTokenExpiresAt: refreshTokenExpiry,
            )
        }
    }

    private static func verifyRefreshToken(
        refreshToken: String,
        jwtKeyCollection: JWTKeyCollection,
        logger: Logger,
    ) async throws -> RefreshTokenPayload {
        do {
            return try await jwtKeyCollection.verify(refreshToken, as: RefreshTokenPayload.self)
        } catch {
            logger.warning("invalid jwt token: \(error)")
            throw HTTPError(.unauthorized)
        }
    }

    private struct AuthProviders {
        let refreshTokenProvider: RefreshTokenPayload.AuthProvider?
        let accessTokenProvider: AccessTokenPayload.AuthProvider?
    }

    private static func refreshAuthProviderTokens(
        payload: RefreshTokenPayload,
        dependencies: UnauthenticatedCommandDependencies,
        now: Date,
    ) async throws -> AuthProviders {
        switch payload.provider {
        case let .signInWithApple(claims):
            let tokens = try await dependencies.siwaService.sendTokenRequest(type: .refreshToken(refreshToken: claims.refreshToken))
            let accessTokenExpiresAt = now.addingTimeInterval(tokens.expiresIn)
            let refreshTokenExpiresAt = now.addingTimeInterval(180 * 24 * 60 * 60) // 6 months - each refresh extends the expiry
            return AuthProviders(
                refreshTokenProvider: .signInWithApple(.init(refreshToken: tokens.refreshToken, expiresAt: refreshTokenExpiresAt)),
                accessTokenProvider: .signInWithApple(.init(accessToken: tokens.accessToken, expiresAt: accessTokenExpiresAt)),
            )
        case .none:
            return AuthProviders(refreshTokenProvider: nil, accessTokenProvider: nil)
        }
    }
}
