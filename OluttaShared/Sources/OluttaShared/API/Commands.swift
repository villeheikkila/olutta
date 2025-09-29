import Foundation
import HTTPTypes

public enum AuthenticatedCommand: String, Sendable, CaseIterable {
    case refreshDevice = "refresh_device"
    case getUser = "get_user"
    case subscribeToStore = "subscribe_to_store"
    case unsubscribeFromStore = "unsusbscribe_from_store"
    case getStores = "get_stores"
    case getProductsByStoreId = "get_products_by_store_id"
}

public enum UnauthenticatedCommand: String, Sendable, CaseIterable {
    case refreshAccessToken = "refresh_access_token"
    case createAnonymousUser = "create_anonymous_user"
}

public enum Command: Sendable {
    case authenticated(AuthenticatedCommand)
    case unauthenticated(UnauthenticatedCommand)

    public init?(from string: String) {
        if let authenticatedCommand = AuthenticatedCommand(rawValue: string) {
            self = .authenticated(authenticatedCommand)
        } else if let unauthenticatedCommand = UnauthenticatedCommand(rawValue: string) {
            self = .unauthenticated(unauthenticatedCommand)
        } else {
            return nil
        }
    }
}

public protocol CommandMetadata {
    associatedtype RequestType: Codable
    associatedtype ResponseType: Codable

    static var name: Command { get }
}

public struct GetStoresCommand: CommandMetadata {
    public typealias RequestType = Request
    public typealias ResponseType = Response
    public static let name = Command.authenticated(.getStores)

    public struct Request: Codable, Sendable {
        public init() {}
    }

    public struct Response: Codable {
        public let stores: [StoreEntity]

        public init(stores: [StoreEntity]) {
            self.stores = stores
        }
    }
}

public struct GetProductsByStoreIdCommand: CommandMetadata {
    public typealias RequestType = Request
    public typealias ResponseType = Response
    public static let name = Command.authenticated(.getProductsByStoreId)

    public struct Request: Codable, Sendable {
        public let storeId: UUID

        public init(storeId: UUID) {
            self.storeId = storeId
        }
    }

    public struct Response: Codable {
        public let products: [ProductEntity]

        public init(products: [ProductEntity]) {
            self.products = products
        }
    }
}

public struct RefreshDeviceCommand: CommandMetadata {
    public typealias RequestType = Request
    public typealias ResponseType = Response
    public static let name = Command.authenticated(.refreshDevice)

    public struct Response: Codable, Sendable {
        public init() {}
    }

    public struct Request: Codable, Sendable {
        public let pushNotificationToken: String

        public init(pushNotificationToken: String) {
            self.pushNotificationToken = pushNotificationToken
        }
    }
}

public struct GetUserCommand: CommandMetadata {
    public typealias RequestType = Request
    public typealias ResponseType = Response
    public static let name = Command.authenticated(.getUser)

    public struct Request: Codable, Sendable {
        public init() {}
    }

    public struct Response: Codable, Sendable {
        public let id: UUID
        public let subscriptions: [Subscription]

        public init(id: UUID, subscriptions: [Subscription]) {
            self.id = id
            self.subscriptions = subscriptions
        }

        public struct Subscription: Codable, Sendable {
            public let storeId: UUID

            public init(storeId: UUID) {
                self.storeId = storeId
            }
        }
    }
}

public struct SubscribeToStoreCommand: CommandMetadata {
    public typealias RequestType = Request
    public typealias ResponseType = Response
    public static let name = Command.authenticated(.subscribeToStore)

    public struct Request: Codable, Sendable {
        public let storeId: UUID

        public init(storeId: UUID) {
            self.storeId = storeId
        }
    }

    public struct Response: Codable, Sendable {
        public init() {}
    }
}

public struct UnsubscribeFromStoreCommand: CommandMetadata {
    public typealias RequestType = Request
    public typealias ResponseType = Response
    public static let name = Command.authenticated(.unsubscribeFromStore)

    public struct Request: Codable, Sendable {
        public let storeId: UUID

        public init(storeId: UUID) {
            self.storeId = storeId
        }
    }

    public struct Response: Codable, Sendable {
        public init() {}
    }
}

public struct RefreshAccessTokenCommand: CommandMetadata {
    public typealias RequestType = Request
    public typealias ResponseType = Response
    public static let name = Command.unauthenticated(.refreshAccessToken)
    public static let authenticated = false

    public struct Request: Codable, Sendable {
        public let refreshToken: String

        public init(refreshToken: String) {
            self.refreshToken = refreshToken
        }
    }

    public struct Response: Codable, Sendable {
        public let accessToken: String
        public let accessTokenExpiresAt: Date

        public init(accessToken: String, accessTokenExpiresAt: Date) {
            self.accessToken = accessToken
            self.accessTokenExpiresAt = accessTokenExpiresAt
        }
    }
}

public struct CreateAnonymousUserCommand: CommandMetadata {
    public typealias RequestType = Request
    public typealias ResponseType = Response
    public static let name = Command.unauthenticated(.createAnonymousUser)
    public static let authenticated = false

    public struct Request: Codable, Sendable {
        public let deviceId: UUID
        public let pushNotificationToken: String

        public init(deviceId: UUID, pushNotificationToken: String) {
            self.deviceId = deviceId
            self.pushNotificationToken = pushNotificationToken
        }
    }

    public struct Response: Codable, Sendable {
        public let refreshToken: String
        public let refreshTokenExpiresAt: Date
        public let accessToken: String
        public let accessTokenExpiresAt: Date

        public init(
            refreshToken: String,
            refreshTokenExpiresAt: Date,
            accessToken: String,
            accessTokenExpiresAt: Date
        ) {
            self.refreshToken = refreshToken
            self.refreshTokenExpiresAt = refreshTokenExpiresAt
            self.accessToken = accessToken
            self.accessTokenExpiresAt = accessTokenExpiresAt
        }
    }
}
