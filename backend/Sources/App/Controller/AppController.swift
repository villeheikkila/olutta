import Foundation
import Hummingbird

struct AppController {
    let ctx: Context

    var endpoints: RouteCollection<AppRequestContext> {
        RouteCollection(context: AppRequestContext.self)
            .get(use: stores)
    }

    @Sendable func stores(request _: Request, context _: some RequestContext) async throws -> [UUID] {
        [UUID()]
    }
}
