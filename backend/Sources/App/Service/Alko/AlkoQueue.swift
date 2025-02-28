import Foundation

let alkoQueue = QueueConfiguration<Context>(
    name: "alko",
    policy: .init(isSequential: true),
    handler: { ctx, message in
        guard let typeValue = message.message["type"], let type = typeValue.stringValue else { throw QueueError.invalidMessageType }
        switch type {
        case "v1:refresh-stores":
            guard let typeValue = message.message["id"], let id = typeValue.intValue else { throw QueueError.invalidPayload }
            try await ctx.pg.withTransaction { tx in
                let stores = try await ctx.services.alko.getStores()
                let result = try await ctx.repositories.alko.upsertStores(tx, stores: stores)
                let totalStores = result.count
                let newStores = result.count(where: \.isNewRecord)
                ctx.logger.info("updated alko store records, \(totalStores) records updated, \(newStores) new records")
            }
        default:
            ctx.logger.error("unknown message type \(type)")
        }
    }
)
