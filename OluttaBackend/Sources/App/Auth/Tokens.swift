import Foundation
import JWTKit

struct AccessTokenPayload: JWTPayload, Codable {
    init(sub: UUID, deviceId: UUID, userId: UUID, refreshTokenId: UUID, iat: Date, exp: Date) {
        self.sub = sub
        self.deviceId = deviceId
        self.userId = userId
        self.refreshTokenId = refreshTokenId
        self.iat = iat
        self.exp = exp
    }

    let sub: UUID
    let deviceId: UUID
    let userId: UUID
    let refreshTokenId: UUID
    let iat: Date
    let exp: Date

    func verify(using _: some JWTAlgorithm) throws {
        try ExpirationClaim(value: exp).verifyNotExpired()
    }
}

struct RefreshTokenPayload: JWTPayload, Codable {
    init(sub: UUID, iat: Date, exp: Date) {
        self.sub = sub
        self.iat = iat
        self.exp = exp
    }

    func verify(using _: some JWTAlgorithm) throws {
        try ExpirationClaim(value: exp).verifyNotExpired()
    }

    let sub: UUID
    let iat: Date
    let exp: Date
}
