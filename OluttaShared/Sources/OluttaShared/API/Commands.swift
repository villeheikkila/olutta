import Foundation
import HTTPTypes

public protocol CommandMetadata: Sendable {
    associatedtype Request: Codable
    associatedtype Response: Codable

    static var name: String { get }
    static var authenticated: Bool { get }
}

public protocol AuthenticatedCommand: CommandMetadata {}

public extension AuthenticatedCommand {
    static var authenticated: Bool { true }
}

public protocol UnauthenticatedCommand: CommandMetadata {}

public extension UnauthenticatedCommand {
    static var authenticated: Bool { false }
}

public struct GetAppDataCommand: AuthenticatedCommand {
    public static let name = "get_stores"

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

public struct GetProductsByStoreIdCommand: AuthenticatedCommand {
    public static let name = "get_products_by_store_id"

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

public struct RefreshDeviceCommand: AuthenticatedCommand {
    public static let name = "refresh_device"

    public struct Request: Codable, Sendable {
        public let pushNotificationToken: String

        public init(pushNotificationToken: String) {
            self.pushNotificationToken = pushNotificationToken
        }
    }

    public struct Response: Codable, Sendable {
        public init() {}
    }
}

public struct GetUserCommand: AuthenticatedCommand {
    public static let name = "get_user"

    public struct Request: Codable, Sendable {
        public init() {}
    }

    public struct Response: Codable, Sendable {
        public let subscriptions: [Subscription]

        public init(subscriptions: [Subscription]) {
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

public struct SubscribeToStoreCommand: AuthenticatedCommand {
    public static let name = "subscribe_to_store"

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

public struct UnsubscribeFromStoreCommand: AuthenticatedCommand {
    public static let name = "unsusbscribe_from_store"

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

public struct RefreshTokensCommand: UnauthenticatedCommand {
    public static let name = "refresh_access_token"

    public struct Request: Codable, Sendable {
        public let refreshToken: String
        public let deviceId: UUID

        public init(refreshToken: String, deviceId: UUID) {
            self.refreshToken = refreshToken
            self.deviceId = deviceId
        }
    }

    public struct Response: Codable, Sendable {
        public let accessToken: String
        public let accessTokenExpiresAt: Date
        public let refreshToken: String
        public let refreshTokenExpiresAt: Date

        public init(accessToken: String, accessTokenExpiresAt: Date, refreshToken: String, refreshTokenExpiresAt: Date) {
            self.accessToken = accessToken
            self.accessTokenExpiresAt = accessTokenExpiresAt
            self.refreshToken = refreshToken
            self.refreshTokenExpiresAt = refreshTokenExpiresAt
        }
    }
}

public struct AuthenticateCommand: UnauthenticatedCommand {
    public static let name = "create_anonymous_user"

    public enum AuthenticationType: Codable, Sendable {
        case anonymous
        case signInWithApple(SignInWithApplePayload)

        public struct SignInWithApplePayload: Codable, Sendable {
            public let authorizationCode: String
            public let idToken: String
            public let nonce: String

            public init(authorizationCode: String, idToken: String, nonce: String) {
                self.authorizationCode = authorizationCode
                self.idToken = idToken
                self.nonce = nonce
            }
        }
    }

    public struct Request: Codable, Sendable {
        public let authenticationType: AuthenticationType
        public let deviceId: UUID

        public init(authenticationType: AuthenticationType, deviceId: UUID) {
            self.authenticationType = authenticationType
            self.deviceId = deviceId
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
            accessTokenExpiresAt: Date,
        ) {
            self.refreshToken = refreshToken
            self.refreshTokenExpiresAt = refreshTokenExpiresAt
            self.accessToken = accessToken
            self.accessTokenExpiresAt = accessTokenExpiresAt
        }
    }
}
