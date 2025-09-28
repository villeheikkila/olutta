import Foundation
import JWTKit

public struct RefreshTokenPayload: JWTPayload, Codable {
    public init(sub: UUID, iat: Date, exp: Date) {
        self.sub = sub
        self.iat = iat
        self.exp = exp
    }

    public func verify(using _: some JWTAlgorithm) throws {
        try ExpirationClaim(value: exp).verifyNotExpired()
    }

    public let sub: UUID
    public let iat: Date
    public let exp: Date
}
