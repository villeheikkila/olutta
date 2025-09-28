import Foundation
import Hummingbird
import HummingbirdRedis
import JWTKit
import PostgresNIO

func makeRouter(pg: PostgresClient, persist: RedisPersistDriver, jwtKeyCollection: JWTKeyCollection, requestSignatureSalt: String) -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.info)
        // RequestSignatureMiddleware(secretKey: requestSignatureSalt)
        UniqueRequestMiddleware(persist: persist)
    }
    router.get("/health") { _, _ -> HTTPResponse.Status in
        return .ok
    }
    router.addRoutes(AuthController(pg: pg, persist: persist, jwtKeyCollection: jwtKeyCollection).endpoints)
    router.addRoutes(AppController(pg: pg, persist: persist, jwtKeyCollection: jwtKeyCollection).endpoints)
    router.addRoutes(UserController(pg: pg, persist: persist, jwtKeyCollection: jwtKeyCollection).endpoints)
    return router
}
