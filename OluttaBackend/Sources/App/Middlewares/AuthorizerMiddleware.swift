import Foundation
import HTTPTypes
import Hummingbird
import JWTKit
import NIOFoundationCompat
import OluttaShared

struct UserIdentity: Sendable {
    let userId: UUID
}

struct AuthorizerMiddleware: RouterMiddleware {
    let jwtKeyCollection: JWTKeyCollection

    init(jwtKeyCollection: JWTKeyCollection) {
        self.jwtKeyCollection = jwtKeyCollection
    }

    func handle(_ request: Request, context: AppRequestContext, next: (Request, AppRequestContext) async throws -> Response) async throws -> Response {
        if let authenticated = try await authenticate(request: request, context: context) {
            var context = context
            context.identity = authenticated
            return try await next(request, context)
        }
        return try await next(request, context)
    }

    private func authenticate(request: Request, context: AppRequestContext) async throws -> UserIdentity? {
        guard let accessToken = request.headers[.authorization],
              accessToken.hasPrefix("Bearer ")
        else {
            context.logger.warning("call made to authorized route without authorization header")
            throw HTTPError(.unauthorized)
        }
        let payload: AccessTokenPayload
        do {
            payload = try await jwtKeyCollection.verify(accessToken, as: AccessTokenPayload.self)
        } catch {
            context.logger.warning("invalid jwt token: \(error.localizedDescription)")
            throw HTTPError(.unauthorized)
        }
        return UserIdentity(userId: payload.userId)
    }
}
