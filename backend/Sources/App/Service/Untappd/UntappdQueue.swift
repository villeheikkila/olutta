import Foundation

let untappdQueue = QueueConfiguration<Context>(
    name: "untappd",
    policy: .init(isSequential: true),
    handler: { ctx, message in
        guard let typeValue = message.message["type"], let type = typeValue.stringValue else { throw QueueError.invalidMessageType }
        switch type {
        case "v1:upsert-beer-by-id":
            guard let typeValue = message.message["id"], let id = typeValue.intValue else { throw QueueError.invalidPayload }
            try await ctx.pg.withTransaction { tx in
                let beer = try await ctx.services.untappd.getBeerMetadata(bid: id)
                try await ctx.repositories.untappd.upsertBeer(tx, beer: beer.response)
                ctx.logger.info("updated untappd beer record", metadata: ["id": .init(stringLiteral: id.description)])
            }
        default:
            ctx.logger.error("unknown message type \(type)")
        }
    }
)
