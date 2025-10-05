import Foundation
import JWTKit

struct AppleAuthToken: JWTPayload {
    let iss: IssuerClaim
    let iat: IssuedAtClaim
    let exp: ExpirationClaim
    let aud: AudienceClaim
    let sub: SubjectClaim

    init(clientId: String, teamId: String) {
        iss = .init(value: teamId)
        iat = .init(value: Date())
        exp = .init(value: Date().addingTimeInterval(15_777_000))
        aud = .init(value: "https://appleid.apple.com")
        sub = .init(value: clientId)
    }

    func verify(using _: some JWTAlgorithm) throws {
        try exp.verifyNotExpired()
    }
}
