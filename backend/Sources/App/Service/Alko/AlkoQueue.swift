import Foundation

let alkoQueue = QueueConfiguration<Context>(
    name: "alko",
    policy: .init(isSequential: true),
    handler: { ctx, message in
        guard let typeValue = message.message["type"], let type = typeValue.stringValue else { throw QueueError.invalidMessageType }
        switch type {
        case "v1:refresh-stores":
            try await ctx.pg.withTransaction { tx in
                let stores = try await ctx.services.alko.getStores()
                let result = try await ctx.repositories.alko.upsertStores(tx, stores: stores)
                let totalStores = result.count
                let newStores = result.count(where: \.isNewRecord)
                ctx.logger.info("updated alko store records, \(totalStores) records updated, \(newStores) new records")
            }
        case "v1:refresh-beers":
            try await ctx.pg.withTransaction { tx in
                let products = try await ctx.services.alko.getAllBeers()
                let result = try await ctx.repositories.alko.upsertAlkoProducts(tx, products: products)
                let newBeers = result.count(where: \.isNewRecord)
                ctx.logger.info("updated alko beer records, \(result.count) records updated, \(newBeers) new records")
            }
        case "v1:refresh-availability":
            guard let typeValue = message.message["id"], let id = typeValue.stringValue else { throw QueueError.invalidPayload }
            try await ctx.pg.withTransaction { _ in
                let storeAvailability = try await ctx.services.alko.getProduct(id: id)
                let webstoreAvailability = try await ctx.services.alko.getWebstoreAvailability(id: id)
                // ctx.logger.info("updated alko beer records, \(result.count) records updated, \(newBeers) new records")
            }
        default:
            ctx.logger.error("unknown message type \(type)")
        }
    }
)
