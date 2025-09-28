import Foundation

public enum PlatformEntity: String, Codable, Sendable {
    case ios
}

public struct AnonymousAuthRequest: Codable, Sendable {
    public init(deviceId: UUID, pushNotificationToken: String? = nil, isDevelopmentDevice: Bool, platform: PlatformEntity) {
        self.deviceId = deviceId
        self.pushNotificationToken = pushNotificationToken
        self.isDevelopmentDevice = isDevelopmentDevice
        self.platform = platform
    }

    public let deviceId: UUID
    public let pushNotificationToken: String?
    public let isDevelopmentDevice: Bool
    public let platform: PlatformEntity
}

public struct AnonymousAuthResponse: Codable, Hashable, Sendable {
    public init(refreshToken: String, refreshTokenExpiresAt: Date, accessToken: String, accessTokenExpiresAt: Date) {
        self.refreshToken = refreshToken
        self.accessToken = accessToken
        self.refreshTokenExpiresAt = refreshTokenExpiresAt
        self.accessTokenExpiresAt = accessTokenExpiresAt
    }

    public let refreshToken: String
    public let accessToken: String
    public let refreshTokenExpiresAt: Date
    public let accessTokenExpiresAt: Date
}

public struct AccessTokenRefreshResponse: Codable, Hashable, Sendable {
    public init(accessToken: String, accessTokenExpiresAt: Date) {
        self.accessToken = accessToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
    }

    public let accessToken: String
    public let accessTokenExpiresAt: Date
}

public struct UserResponse: Codable, Hashable, Sendable {
    public let subscribedStoreIds: [UUID]

    public init(subscribedStoreIds: [UUID]) {
        self.subscribedStoreIds = subscribedStoreIds
    }
}

public struct RefreshAccessTokenRequest: Codable, Sendable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}
