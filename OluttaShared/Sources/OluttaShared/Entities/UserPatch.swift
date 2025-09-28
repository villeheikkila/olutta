public struct UpsertPushNotificationTokenRequest: Codable, Sendable {
    public let pushNotificationToken: String

    public init(pushNotificationToken: String) {
        self.pushNotificationToken = pushNotificationToken
    }
}

public struct UpsertPushNotificationTokenResponse: Codable, Sendable {
    public init() {}
}
