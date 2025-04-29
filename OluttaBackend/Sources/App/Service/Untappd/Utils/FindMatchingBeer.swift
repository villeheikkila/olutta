import Foundation
import Logging
import OpenAI
import RegexBuilder

public enum UntappdLLMError: Error {
    case noMatchFound(productName: String, confidence: Int, reasoning: String)
    case noSearchResults(productName: String, query: String)
    case invalidLLMResponse(response: String)
}

struct UntappdLLM {
    private let openRouter: OpenAI
    private let logger: Logger
    private let minimumConfidenceThreshold: Int
    private let untappdService: UntappdService

    struct BeerMatchResponse: Codable, StructuredOutput {
        public let matchingBeerId: Int?
        public let confidenceScore: Int
        public let reasoning: String

        public static var example: BeerMatchResponse {
            BeerMatchResponse(
                matchingBeerId: 123_456,
                confidenceScore: 85,
                reasoning: "Strong name similarity, same brewery and matching ABV and style"
            )
        }
    }

    init(
        openRouter: OpenAI,
        untappdService: UntappdService,
        logger: Logger,
        minimumConfidenceThreshold: Int = 50
    ) {
        self.openRouter = openRouter
        self.logger = logger
        self.minimumConfidenceThreshold = minimumConfidenceThreshold
        self.untappdService = untappdService
    }

    public func findBestMatch(
        alkoProduct: AlkoProductEntity,
        untappdResults: [UntappdSearchResponse.BeerItem]
    ) async throws -> (match: UntappdSearchResponse.BeerItem, confidence: Int, reasoning: String) {
        let prompt = createPrompt(alkoProduct: alkoProduct, untappdResults: untappdResults)
        let query = ChatQuery(
            messages: [.init(role: .user, content: prompt)!],
            model: "google/gemini-2.5-flash-preview",
            responseFormat: .jsonSchema(name: "BeerMatch", type: BeerMatchResponse.self)
        )
        let result = try await openRouter.chats(query: query)
        if let content = result.choices.first?.message.content,
           let jsonData = content.data(using: .utf8),
           let response = try? JSONDecoder().decode(BeerMatchResponse.self, from: jsonData)
        {
            logger.info("llm match result",
                        metadata: [
                            "product_name": .init(stringLiteral: alkoProduct.name),
                            "matching_id": .init(stringLiteral: String(describing: response.matchingBeerId)),
                            "confidence": .init(stringLiteral: String(response.confidenceScore)),
                            "reasoning": .init(stringLiteral: response.reasoning),
                        ])

            if let matchingBeerId = response.matchingBeerId,
               let matchingBeer = untappdResults.first(where: { $0.beer.bid == matchingBeerId })
            {
                if response.confidenceScore >= minimumConfidenceThreshold {
                    return (matchingBeer, response.confidenceScore, response.reasoning)
                } else {
                    throw UntappdLLMError.noMatchFound(
                        productName: alkoProduct.name,
                        confidence: response.confidenceScore,
                        reasoning: response.reasoning
                    )
                }
            } else if response.matchingBeerId != nil {
                logger.warning("llm returned a beer ID that doesn't match any in our results",
                               metadata: ["beer_id": .init(stringLiteral: String(describing: response.matchingBeerId))])
                throw UntappdLLMError.noMatchFound(
                    productName: alkoProduct.name,
                    confidence: response.confidenceScore,
                    reasoning: "llm returned beer ID \(response.matchingBeerId!) which doesn't match any in our results. " + response.reasoning
                )
            }
            throw UntappdLLMError.noMatchFound(
                productName: alkoProduct.name,
                confidence: response.confidenceScore,
                reasoning: response.reasoning
            )
        }
        logger.error("failed to parse LLM JSON response",
                     metadata: ["response": .init(stringLiteral: result.choices.first?.message.content ?? "No content")])
        throw UntappdLLMError.invalidLLMResponse(
            response: result.choices.first?.message.content ?? "No content"
        )
    }

    private func createPrompt(alkoProduct: AlkoProductEntity, untappdResults: [UntappdSearchResponse.BeerItem]) -> String {
        var prompt = """
        I need to find the best matching beer from Untappd for this product from Alko (Finnish alcohol retailer).

        ALKO PRODUCT:
        Name: \(alkoProduct.name)
        """
        if let abv = alkoProduct.abv {
            prompt += "\nABV: \(abv)%"
        }
        let styles = alkoProduct.beerStyleName
        if !styles.isEmpty {
            prompt += "\nBeer Style: \(styles.joined(separator: ", "))"
        }
        if let country = alkoProduct.countryName {
            prompt += "\nCountry: \(country)"
        }
        if let description = alkoProduct.description {
            prompt += "\nDescription: \(description)"
        }
        if let taste = alkoProduct.taste {
            prompt += "\nTaste Profile: \(taste)"
        }
        prompt += "\n\nUNTAPPD SEARCH RESULTS:"

        for (index, beerItem) in untappdResults.enumerated() {
            let beer = beerItem.beer
            let brewery = beerItem.brewery

            prompt += """

            BEER #\(index + 1):
            ID: \(beer.bid)
            Name: \(beer.beerName)
            Brewery: \(brewery.breweryName)
            Style: \(beer.beerStyle)
            ABV: \(beer.beerAbv)%
            IBU: \(beer.beerIbu)
            Country: \(brewery.countryName)
            City: \(brewery.location.breweryCity), \(brewery.location.breweryState)
            Description: \(beer.beerDescription)
            Check-in Count: \(beerItem.checkinCount)
            """
        }

        prompt += """

        Based on the information provided, determine which Untappd beer is the best match for the Alko product.
        Consider name similarity, ABV, style, country of origin, and description.

        Respond with a JSON object containing:
        - matchingBeerId: The ID number of the best matching beer, or null if no good match exists
        - confidenceScore: A number from 0-100 indicating your confidence in the match
        - reasoning: A brief explanation of why this beer is the best match

        If the confidence score is below \(minimumConfidenceThreshold), set matchingBeerId to null.
        """

        return prompt
    }

    private func createSearchQuery(from product: AlkoProductEntity) -> String {
        var query = product.name
        let wordsToRemove = ["tölkki"]
        for word in wordsToRemove {
            query = query.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        let numberPackPattern = Regex {
            OneOrMore(.digit)
            "-pack"
        }.ignoresCase()
        query = query.replacing(numberPackPattern, with: "")
        query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query
    }

    public func searchAndMatch(
        alkoProduct: AlkoProductEntity,
    ) async throws -> (match: UntappdBeerResponse.Beer, confidence: Int, reasoning: String) {
        let query = createSearchQuery(from: alkoProduct)
        let searchResults = try await untappdService.searchBeer(query: query)
        let first10Results = Array(searchResults.response.beers.items.prefix(10))
        guard !first10Results.isEmpty else {
            logger.info("no Untappd results to match against",
                        metadata: ["product_name": .init(stringLiteral: alkoProduct.name), query: .init(stringLiteral: query)])
            throw UntappdLLMError.noSearchResults(productName: alkoProduct.name, query: query)
        }
        let result = try await findBestMatch(alkoProduct: alkoProduct, untappdResults: first10Results)
        let response = try await untappdService.getBeerMetadata(bid: result.match.beer.bid)
        return (response.response.beer, result.confidence, result.reasoning)
    }
}
