import Foundation
import Hummingbird

struct AlkoController {
    let ctx: Context
    let alkoRepository: AlkoRepository

    var endpoints: RouteCollection<AppRequestContext> {
        RouteCollection(context: AppRequestContext.self)
            .get(use: stores)
    }

    func stores(request _: Request, context _: some RequestContext) async throws -> [AlkoStoreEntity] {
        try await ctx.pg.withTransaction { tx in
            try await alkoRepository.getStores(tx)
        }
    }
}
