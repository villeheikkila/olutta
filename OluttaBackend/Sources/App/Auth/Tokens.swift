import Foundation
import JWTKit

struct AccessTokenPayload: JWTPayload, Codable {
    let sub: UUID
    let refreshTokenId: UUID
    let iat: Date
    let exp: Date
    let provider: AuthProvider?
    let identity: UserIdentity

    init(
        sub: UUID,
        refreshTokenId: UUID,
        iat: Date,
        exp: Date,
        provider: AuthProvider? = nil,
        identity: UserIdentity,
    ) {
        self.sub = sub
        self.refreshTokenId = refreshTokenId
        self.iat = iat
        self.exp = exp
        self.provider = provider
        self.identity = identity
    }

    func verify(using _: some JWTAlgorithm) throws {
        try ExpirationClaim(value: exp).verifyNotExpired()
    }

    enum AuthProvider: Codable {
        case signInWithApple(SignInWithAppleAccessClaims)

        struct SignInWithAppleAccessClaims: Codable {
            let accessToken: String
            let expiresAt: Date

            init(accessToken: String, expiresAt: Date) {
                self.accessToken = accessToken
                self.expiresAt = expiresAt
            }
        }
    }
}

struct RefreshTokenPayload: JWTPayload, Codable {
    let sub: UUID
    let iat: Date
    let exp: Date
    let provider: AuthProvider?

    init(
        sub: UUID,
        iat: Date,
        exp: Date,
        provider: AuthProvider? = nil,
    ) {
        self.sub = sub
        self.iat = iat
        self.exp = exp
        self.provider = provider
    }

    func verify(using _: some JWTAlgorithm) throws {
        try ExpirationClaim(value: exp).verifyNotExpired()
    }

    enum AuthProvider: Codable {
        case signInWithApple(SignInWithAppleRefreshClaims)

        struct SignInWithAppleRefreshClaims: Codable {
            let refreshToken: String
            let expiresAt: Date

            init(refreshToken: String, expiresAt: Date) {
                self.refreshToken = refreshToken
                self.expiresAt = expiresAt
            }
        }
    }
}
