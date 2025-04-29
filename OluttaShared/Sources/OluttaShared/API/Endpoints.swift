import Foundation

public enum APIEndpoint {
    case stores
    case productsByStoreId(UUID)

    public var path: String {
        switch self {
        case .stores:
            "/v1/stores"
        case let .productsByStoreId(id):
            "/v1/stores/\(id.uuidString.lowercased())/products"
        }
    }

    public var pathConfig: String {
        switch self {
        case .stores:
            "/v1/stores"
        case .productsByStoreId:
            "/v1/stores/:id/products"
        }
    }
}
