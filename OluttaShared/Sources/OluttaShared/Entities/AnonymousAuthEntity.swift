import Foundation

public enum PlatformEntity: String, Codable, Sendable {
    case ios
}

public struct AnonymousAuthRequest: Codable, Sendable {
    public init(deviceId: String, pushNotificationToken: String? = nil, platform: PlatformEntity) {
        self.deviceId = deviceId
        self.pushNotificationToken = pushNotificationToken
        self.platform = platform
    }

    public let deviceId: String
    public let pushNotificationToken: String?
    public let platform: PlatformEntity
}

public struct AnonymousAuthResponse: Codable, Hashable, Sendable {
    public init(userId: String, token: String, expiresAt: Date) {
        self.userId = userId
        self.token = token
        self.expiresAt = expiresAt
    }

    public let userId: String
    public let token: String
    public let expiresAt: Date
}
