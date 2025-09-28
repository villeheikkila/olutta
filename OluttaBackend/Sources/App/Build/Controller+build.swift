import Foundation
import Hummingbird
import JWTKit

func buildRouter(ctx: Context, jwtKeyCollection: JWTKeyCollection) -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.info)
        // RequestSignatureMiddleware(secretKey: ctx.config.requestSignatureSalt)
        UniqueRequestMiddleware(persist: ctx.persist)
    }
    router.get("/health") { _, _ -> HTTPResponse.Status in
        return .ok
    }
    router.addRoutes(AuthController(pg: ctx.pg, logger: ctx.logger, persist: ctx.persist, jwtKeyCollection: jwtKeyCollection).endpoints)
    router.addRoutes(AppController(pg: ctx.pg, persist: ctx.persist, jwtKeyCollection: jwtKeyCollection).endpoints)
    router.addRoutes(UserController(pg: ctx.pg, persist: ctx.persist, jwtKeyCollection: jwtKeyCollection).endpoints)
    return router
}
