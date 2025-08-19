import Foundation

let alkoQueue = QueueConfiguration<Context>(
    name: "alko",
    policy: .init(isSequential: true),
    handler: { ctx, message in
        guard let typeValue = message.message["type"], let type = typeValue.stringValue else { throw QueueError.invalidMessageType }
        switch type {
        case "v1:refresh-stores":
            ctx.logger.info("refreshing alko stores")
            try await ctx.pg.withTransaction { tx in
                let stores = try await ctx.services.alko.getStores()
                let result = try await ctx.repositories.alko.upsertStores(tx, stores: stores)
                let totalStores = result.count
                let newStores = result.count(where: \.isNewRecord)
                ctx.logger.info("updated alko store records, \(totalStores) records updated, \(newStores) new records")
            }
        case "v1:refresh-beers":
            ctx.logger.info("refreshing beers")
            try await ctx.pg.withTransaction { tx in
                let products = try await ctx.services.alko.getAllBeers()
                let result = try await ctx.repositories.alko.upsertAlkoProducts(tx, products: products)
                let noLongerAvailable = if result.count != 0 {
                    try await ctx.repositories.alko.markUnavailableAlkoProducts(tx, excludingProductIds: result.map(\.id))
                } else {
                    0
                }
                let newBeers = result.count(where: \.isNewRecord)
                ctx.logger.info("updated alko beer records, \(result.count) records updated, \(newBeers) new records, \(noLongerAvailable) no longer available products")
            }
        case "v1:refresh-availability":
            guard let typeValue = message.message["id"], let idString = typeValue.stringValue, let id = UUID(uuidString: idString) else {
                throw QueueError.invalidPayload
            }
            ctx.logger.info("refreshing availabilities")
            try await ctx.pg.withTransaction { tx in
                let product = try await ctx.repositories.alko.getProductById(tx, id: id)
                let stores = try await ctx.repositories.alko.getStores(tx)
                let storeAvailability = try await ctx.services.alko.getAvailability(productId: product.productExternalId)
                let webstoreAvailability = try await ctx.services.alko.getWebstoreAvailability(id: product.productExternalId)
                let storeAvailabilityResult = try await ctx.repositories.alko.upsertWebstoreInventory(tx, productId: id, availabilities: webstoreAvailability)
                let availabilities: [(storeId: UUID, count: String?)] = storeAvailability.compactMap { availability in
                    let store = stores.first { store in store.alkoStoreId == availability.id }
                    guard let store else {
                        ctx.logger.warning("availability found for a store that doesn't exist in the db")
                        return nil
                    }
                    return (storeId: store.id, count: availability.count)
                }
                let webstoreAvailabilityResult = try await ctx.repositories.alko.upsertStoreInventory(tx, productId: id, availabilities: availabilities)
                ctx.logger.info("updated alko product availability records", metadata: ["external_id": .string(product.productExternalId)])
            }
        default:
            ctx.logger.error("unknown message type \(type)")
        }
    },
)
