import Foundation
import Hummingbird
import HummingbirdAuth
import JWTKit
import NIOFoundationCompat

struct JWTAuthenticator: AuthenticatorMiddleware, Sendable {
    typealias Context = AppRequestContext
    let jwtKeyCollection: JWTKeyCollection

    init(jwtKeyCollection: JWTKeyCollection) {
        self.jwtKeyCollection = jwtKeyCollection
    }

    func authenticate(request: Request, context: Context) async throws -> Device? {
        guard let jwtToken = request.headers.bearer?.token else { throw HTTPError(.unauthorized) }
        let payload: AnonymousUserPayload
        do {
            payload = try await jwtKeyCollection.verify(jwtToken, as: AnonymousUserPayload.self)
        } catch {
            context.logger.warning("invalid jwt token: \(error)")
            throw HTTPError(.unauthorized)
        }
        return Device(id: payload.sub)
    }
}

struct Device: Sendable {
    let id: String
}
