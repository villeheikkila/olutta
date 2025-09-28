import Foundation

public enum APIEndpoint {
    case stores
    case productsByStoreId(UUID)
    case subscribeToStore(UUID)
    case anonymous
    case currentUser
    case user

    public var path: String {
        switch self {
        case .stores:
            "/v1/stores"
        case let .productsByStoreId(id):
            "/v1/stores/\(id.uuidString.lowercased())/products"
        case .anonymous:
            "/v1/auth/anonymous"
        case .currentUser:
            "/v1/users/me"
        case .user:
            "/v1/user"
        case let .subscribeToStore(id):
            "/v1/stores/\(id.uuidString.lowercased())/subscribe"
        }
    }

    public var pathConfig: String {
        switch self {
        case .stores:
            "/v1/stores"
        case .productsByStoreId:
            "/v1/stores/:id/products"
        case .anonymous:
            "/v1/auth/anonymous"
        case .currentUser:
            "/v1/users/me"
        case .user:
            "/v1/user"
        case .subscribeToStore:
            "/v1/stores/:id/subscribe"
        }
    }
}
