import Foundation
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

extension AuthenticateCommand: UnauthenticatedCommandExecutable {
    static func execute(
        logger: Logger,
        deps: CommandDependencies,
        request: Request,
    ) async throws -> Response {
        try await deps.pg.withTransaction { tx in
            let now = Date()
            // handle authentication provider
            let authResult = try await handleAuthProvider(
                request: request,
                deps: deps,
                tx: tx,
                logger: logger,
                now: now,
            )
            // get or create user
            let userId = if let existingUserId = authResult.existingUserId {
                existingUserId
            } else {
                try await createUserWithAuthProvider(tx: tx, logger: logger, authResult: authResult)
            }
            // create refresh token
            let refreshTokenExpiry = now.addingTimeInterval(365 * 24 * 60 * 60) // 1 year
            let refreshTokenId = try await UserRepository.createRefreshToken(connection: tx, logger: logger, userId: userId, expiresAt: refreshTokenExpiry)
            let refreshTokenPayload = RefreshTokenPayload(
                sub: refreshTokenId,
                iat: now,
                exp: refreshTokenExpiry,
                provider: authResult.refreshTokenProvider,
            )
            let refreshToken = try await deps.jwtKeyCollection.sign(refreshTokenPayload)
            // create access token
            let accessTokenId = UUID()
            let accessTokenExpiry = now.addingTimeInterval(15 * 60) // 15 minutes
            let accessTokenPayload = AccessTokenPayload(
                sub: accessTokenId,
                userId: userId,
                refreshTokenId: refreshTokenId,
                iat: now,
                exp: accessTokenExpiry,
                provider: authResult.accessTokenProvider,
            )
            let accessToken = try await deps.jwtKeyCollection.sign(accessTokenPayload)
            // return response
            return Response(
                refreshToken: refreshToken,
                refreshTokenExpiresAt: refreshTokenExpiry,
                accessToken: accessToken,
                accessTokenExpiresAt: accessTokenExpiry,
            )
        }
    }

    private struct AuthProviderResult {
        let externalId: String?
        let provider: AuthProvider
        let existingUserId: UUID?
        let refreshTokenProvider: RefreshTokenPayload.AuthProvider?
        let accessTokenProvider: AccessTokenPayload.AuthProvider?
    }

    private static func handleAuthProvider(
        request: Request,
        deps: CommandDependencies,
        tx: PostgresConnection,
        logger: Logger,
        now: Date,
    ) async throws -> AuthProviderResult {
        switch request.authenticationType {
        case let .signInWithApple(payload):
            let tokens = try await deps.siwaService.sendTokenRequest(type: .authorizationCode(code: payload.authorizationCode))
            guard let idTokenString = tokens.idToken else {
                logger.error("missing id token when converting authorization code")
                throw AuthenticateCommandError.missingIdToken
            }
            let idToken = try await deps.siwaService.verifyIdToken(idToken: idTokenString, nonce: payload.nonce)
            let externalId = idToken.sub.value
            let existingUserId = try await UserRepository.getUserByAuthProvider(connection: tx, logger: logger, authProvider: .signInWithApple, externalId: externalId)
            let accessTokenExpiresAt = now.addingTimeInterval(tokens.expiresIn)
            let refreshTokenExpiresAt = now.addingTimeInterval(180 * 24 * 60 * 60) // 6 months
            return AuthProviderResult(
                externalId: externalId,
                provider: .signInWithApple,
                existingUserId: existingUserId,
                refreshTokenProvider: .signInWithApple(.init(refreshToken: tokens.refreshToken, expiresAt: refreshTokenExpiresAt)),
                accessTokenProvider: .signInWithApple(.init(accessToken: tokens.accessToken, expiresAt: accessTokenExpiresAt)),
            )
        case .anonymous:
            return AuthProviderResult(externalId: nil, provider: .anonymous, existingUserId: nil, refreshTokenProvider: nil, accessTokenProvider: nil)
        }
    }

    private static func createUserWithAuthProvider(
        tx: PostgresConnection,
        logger: Logger,
        authResult: AuthProviderResult,
    ) async throws -> UUID {
        let newUserId = try await UserRepository.createUser(connection: tx, logger: logger)
        guard let externalId = authResult.externalId else { return newUserId }
        // connect user to external auth provider
        // TODO: combine these
        let (_, isNew) = try await UserRepository.connectUserToAuthProvider(
            connection: tx,
            logger: logger,
            userId: newUserId,
            authProvider: authResult.provider,
            externalId: externalId,
        )
        if isNew {
            logger.info("new user created using \(authResult.provider.rawValue)")
        }
        return newUserId
    }
}

enum AuthenticateCommandError: Error {
    case missingIdToken
}
