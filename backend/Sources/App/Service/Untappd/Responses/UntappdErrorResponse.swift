import Foundation

struct UntappdErrorResponse: Codable {
    let meta: ErrorMeta

    struct ErrorMeta: Codable {
        let code: Int
        let errorDetail: String
        let errorType: String
        let developerFriendly: String?
        let responseTime: ResponseTime

        enum CodingKeys: String, CodingKey {
            case code
            case errorDetail = "error_detail"
            case errorType = "error_type"
            case developerFriendly = "developer_friendly"
            case responseTime = "response_time"
        }

        struct ResponseTime: Codable {
            let time: Double
            let measure: String
        }
    }
}
