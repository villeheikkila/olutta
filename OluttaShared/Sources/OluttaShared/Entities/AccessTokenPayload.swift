import Foundation
import JWTKit

public struct AccessTokenPayload: JWTPayload, Codable {
    public init(sub: UUID, deviceId: UUID, userId: UUID, refreshTokenId: UUID, iat: Date, exp: Date) {
        self.sub = sub
        self.deviceId = deviceId
        self.userId = userId
        self.refreshTokenId = refreshTokenId
        self.iat = iat
        self.exp = exp
    }

    public let sub: UUID
    public let deviceId: UUID
    public let userId: UUID
    public let refreshTokenId: UUID
    public let iat: Date
    public let exp: Date

    public func verify(using _: some JWTAlgorithm) throws {
        try ExpirationClaim(value: exp).verifyNotExpired()
    }
}
