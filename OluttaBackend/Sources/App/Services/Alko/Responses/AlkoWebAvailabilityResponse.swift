struct AlkoWebAvailabilityResponse: Codable, Sendable {
    let messageCode: String
    let status: LocalizedStatus
    let statusCode: String
    let productId: String
    let estimatedAvailabilityDate: String?
    let delivery: DeliveryTime?
    let statusMessage: String

    struct LocalizedStatus: Codable, Sendable {
        let sv: String
        let en: String
        let fi: String
    }

    struct DeliveryTime: Codable, Sendable {
        let min: Int
        let max: Int
    }
}
