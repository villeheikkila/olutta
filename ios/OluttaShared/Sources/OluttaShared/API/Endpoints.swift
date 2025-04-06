import Foundation

public enum APIEndpoint {
    case stores

    public var path: String {
        switch self {
        case .stores:
            "/v1/stores"
        }
    }
}
