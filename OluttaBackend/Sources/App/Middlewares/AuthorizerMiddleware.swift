import Foundation
import HTTPTypes
import Hummingbird
import JWTKit
import NIOFoundationCompat
import OluttaShared

struct UserIdentity: Sendable, Codable {
    let userId: UUID
    let deviceId: UUID
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
        guard let authorizationHeader = request.headers[.authorization],
              authorizationHeader.hasPrefix("Bearer ")
        else {
            return nil
        }
        let accessToken = authorizationHeader.replacingOccurrences(of: "Bearer ", with: "")
        let payload: AccessTokenPayload
        do {
            payload = try await jwtKeyCollection.verify(accessToken, as: AccessTokenPayload.self)
        } catch {
            context.logger.warning("invalid jwt token: \(error.localizedDescription)")
            return nil
        }
        return payload.identity
    }
}
