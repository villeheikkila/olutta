import Foundation
import Hummingbird
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

struct AuthController {
    let pg: PostgresClient
    let persist: RedisPersistDriver
    let jwtKeyCollection: JWTKeyCollection

    var endpoints: RouteCollection<AppRequestContext> {
        RouteCollection(context: AppRequestContext.self)
            .post(.anonymous, use: anonymous)
    }
}

struct AnonymousUserPayload: JWTPayload {
    let sub: String
    let deviceId: String
    let iat: Date
    let exp: Date

    func verify(using _: some JWTAlgorithm) throws {
        try ExpirationClaim(value: exp).verifyNotExpired()
    }
}

extension AuthController {
    func anonymous(request: Request, context: some RequestContext) async throws -> Response {
        let authRequest = try await request.decode(as: AnonymousAuthRequest.self, context: context)
        let existingUserId = try await persist.get(key: "device:\(authRequest.deviceId)", as: String.self)
        let userId: String
        if let existingUserId {
            userId = existingUserId
            context.logger.info("Existing anonymous user", metadata: ["user_id": .string(userId)])
        } else {
            userId = UUID().uuidString
            try await persist.set(key: "device:\(authRequest.deviceId)", value: userId, expires: .seconds(365 * 24 * 3600))
            context.logger.info("Created new anonymous user", metadata: ["user_id": .string(userId)])
        }
        let payload = AnonymousUserPayload(
            sub: userId,
            deviceId: authRequest.deviceId,
            iat: Date(),
            exp: Date().addingTimeInterval(90 * 24 * 3600),
        )
        let token = try await jwtKeyCollection.sign(payload)
        let body = AnonymousAuthResponse(
            userId: userId,
            token: token,
            expiresAt: payload.exp,
        )
        let data = try JSONEncoder().encode(body)
        return Response(
            status: .ok,
            headers: [
                .contentType: "application/json; charset=utf-8",
                .contentLength: "\(data.count)",
            ],
            body: .init(byteBuffer: ByteBuffer(data: data)),
        )
    }
}
