import Foundation
import OpenAI
import RegexBuilder

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
                try await ctx.repositories.untappd.upsertBeer(tx, beer: beer.response.beer)
                ctx.logger.info("updated untappd beer record", metadata: ["id": .init(stringLiteral: id.description)])
            }
        case "v1:match-alko-product-to-untappd-product":
            guard let typeValue = message.message["id"], let idString = typeValue.stringValue, let id = UUID(uuidString: idString) else {
                throw QueueError.invalidPayload
            }
            try await ctx.pg.withTransaction { tx in
                let untappdLLM = UntappdLLM(openRouter: ctx.openRouter, untappdService: ctx.services.untappd, logger: ctx.logger)
                let alkoProduct = try await ctx.repositories.alko.getProductById(tx, id: id)
                let (beer, confidenceScore, reasoning) = try await untappdLLM.searchAndMatch(alkoProduct: alkoProduct)
                let untappdProductId = try await ctx.repositories.untappd.upsertBeer(tx, beer: beer)
                try await ctx.repositories.untappd.createProductMapping(tx, alkoProductId: alkoProduct.id, untappdProductId: untappdProductId, confidenceScore: confidenceScore, isVerified: false, reasoning: reasoning)
            }
        default:
            ctx.logger.error("unknown message type \(type)")
        }
    },
)
