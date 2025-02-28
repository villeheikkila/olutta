import Foundation
import Hummingbird

func buildRouter(ctx: Context) -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.info)
    }
    router.get("/health") { _, _ -> HTTPResponse.Status in
        return .ok
    }
    router.addRoutes(AppController(ctx: ctx).endpoints, atPath: "/data")
    return router
}
