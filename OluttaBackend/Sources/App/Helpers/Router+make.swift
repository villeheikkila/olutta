import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

func makeRouter(pg: PostgresClient, persist: RedisPersistDriver, jwtKeyCollection: JWTKeyCollection, requestSignatureSalt _: String) -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.info)
        // RequestSignatureMiddleware(secretKey: requestSignatureSalt)
        UniqueRequestMiddleware(persist: persist)
    }
    router.get("/health") { _, _ -> HTTPResponse.Status in
        return .ok
    }
    router.addRoutes(RouteCollection(context: AppRequestContext.self)
        .post("/v1/rpc/:command/unauthenticated", use: { request, context in
            try await handleUnauthenticatedCommand(request: request, context: context, pg: pg, persist: persist, jwtKeyCollection: jwtKeyCollection)
        }))
    router.addRoutes(RouteCollection(context: AppRequestContext.self)
        .add(middleware: JWTAuthenticator(jwtKeyCollection: jwtKeyCollection))
        .post("/v1/rpc/:command", use: { request, context in
            try await handleCommand(request: request, context: context, pg: pg, persist: persist, jwtKeyCollection: jwtKeyCollection)
        }))
    return router
}
