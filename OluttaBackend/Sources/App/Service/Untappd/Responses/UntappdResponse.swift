import Foundation

public struct UntappdResponse<T: Decodable>: Decodable {
    let meta: Meta
    let notifications: Notifications
    let response: T

    struct Meta: Decodable {
        let code: Int
        let responseTime: ResponseTime

        struct ResponseTime: Decodable {
            let time: Double
            let measure: String

            enum CodingKeys: String, CodingKey {
                case time
                case measure
            }
        }

        enum CodingKeys: String, CodingKey {
            case code
            case responseTime = "response_time"
        }
    }

    struct Notifications: Decodable {}

    enum CodingKeys: String, CodingKey {
        case meta
        case notifications
        case response
    }
}
