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
        case "v1:search-alko-produt":
            guard let typeValue = message.message["id"], let idString = typeValue.stringValue, let id = UUID(uuidString: idString) else {
                throw QueueError.invalidPayload
            }
            try await ctx.pg.withTransaction { tx in
                let alkoProduct = try await ctx.repositories.alko.getProductById(tx, id: id)
                let query = alkoProduct.name.replacingOccurrences(of: "tölkki", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)
                let products = try await ctx.services.untappd.searchBeer(query: query)
                guard let bid = products.response.beers.items.first?.beer.bid else {
                    ctx.logger.info("no beers found for product", metadata: ["id": .init(stringLiteral: id.description), query: .init(stringLiteral: query)])
                    return
                }
                let beer = try await ctx.services.untappd.getBeerMetadata(bid: bid)
                let untappdProductId = try await ctx.repositories.untappd.upsertBeer(tx, beer: beer.response)
                try await ctx.repositories.untappd.createProductMapping(tx, alkoProductId: alkoProduct.id, untappdProductId: untappdProductId, confidenceScore: 0.0, isVerified: false)
            }
        default:
            ctx.logger.error("unknown message type \(type)")
        }
    }
)
