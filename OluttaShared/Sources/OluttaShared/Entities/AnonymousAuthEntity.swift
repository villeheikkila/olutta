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
    public init(deviceId: UUID, token: String, expiresAt: Date) {
        self.deviceId = deviceId
        self.token = token
        self.expiresAt = expiresAt
    }

    public let deviceId: UUID
    public let token: String
    public let expiresAt: Date
}
