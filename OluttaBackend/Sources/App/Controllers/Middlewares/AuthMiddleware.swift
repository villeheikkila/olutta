import Foundation
import Hummingbird
import HummingbirdAuth
import JWTKit
import NIOFoundationCompat

struct JWTPayloadData: JWTPayload, Equatable {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case tokenId = "token_id"
    }

    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var tokenId: String

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}

// TODO
struct JWTAuthenticator: AuthenticatorMiddleware, Sendable {
    typealias Context = AppRequestContext
    let jwtKeyCollection: JWTKeyCollection

    init(jwtKeyCollection: JWTKeyCollection) {
        self.jwtKeyCollection = jwtKeyCollection
    }

    func authenticate(request: Request, context: Context) async throws -> Device? {
        guard let jwtToken = request.headers.bearer?.token else { throw HTTPError(.unauthorized) }
        let payload: JWTPayloadData
        do {
            payload = try await self.jwtKeyCollection.verify(jwtToken, as: JWTPayloadData.self)
        } catch {
            throw HTTPError(.unauthorized)
        }
        guard let id = UUID(uuidString: payload.subject.value) else {
            throw HTTPError(.unauthorized)
        }
        return Device(id: id)
    }
}

struct Device: Sendable {
    let id: UUID
}

