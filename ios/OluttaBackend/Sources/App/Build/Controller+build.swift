import Foundation
import Hummingbird

func buildRouter(ctx: Context) -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.info)
        RequestSignatureMiddleware(secretKey: ctx.config.requestSignatureSalt)
        UniqueRequestMiddleware(persist: ctx.persist)
    }
    router.get("/health") { _, _ -> HTTPResponse.Status in
        return .ok
    }
    router.addRoutes(AppController(pg: ctx.pg, persist: ctx.persist, alkoRepository: ctx.repositories.alko).endpoints)
    return router
}
