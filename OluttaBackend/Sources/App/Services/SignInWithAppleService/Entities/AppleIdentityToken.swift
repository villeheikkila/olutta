import JWTKit

struct AppleIdentityToken: JWTPayload, Sendable {
    let iss: IssuerClaim
    let sub: SubjectClaim
    let aud: AudienceClaim
    let iat: IssuedAtClaim
    let exp: ExpirationClaim
    let nonce: String?
    let email: String?
    let emailVerified: String?
    let isPrivateEmail: String?
    let realUserStatus: Int?
    let authTime: Int?
    let transferSub: String?

    func verify(using _: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }
}
