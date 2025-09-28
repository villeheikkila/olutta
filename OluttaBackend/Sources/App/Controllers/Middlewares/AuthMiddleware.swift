import Foundation
import Hummingbird
import HummingbirdAuth
import JWTKit
import NIOFoundationCompat
import OluttaShared

struct JWTAuthenticator: AuthenticatorMiddleware, Sendable {
    typealias Context = AppRequestContext
    let jwtKeyCollection: JWTKeyCollection

    init(jwtKeyCollection: JWTKeyCollection) {
        self.jwtKeyCollection = jwtKeyCollection
    }

    func authenticate(request: Request, context: Context) async throws -> UserIdentity? {
        guard let jwtToken = request.headers.bearer?.token else { throw HTTPError(.unauthorized) }
        let payload: AccessTokenPayload
        do {
            payload = try await jwtKeyCollection.verify(jwtToken, as: AccessTokenPayload.self)
        } catch {
            context.logger.warning("invalid jwt token: \(error.localizedDescription)")
            throw HTTPError(.unauthorized)
        }
        return UserIdentity(tokenId: payload.sub, deviceId: payload.deviceId, userId: payload.userId)
    }
}

struct UserIdentity: Sendable {
    let tokenId: UUID
    let deviceId: UUID
    let userId: UUID
}
