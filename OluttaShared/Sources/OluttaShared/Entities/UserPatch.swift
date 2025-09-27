public struct UserPatchRequest: Codable, Sendable {
    let pushNotificationToken: String

    public init(pushNotificationToken: String) {
        self.pushNotificationToken = pushNotificationToken
    }
}

public struct UserPatchResponse: Codable, Sendable {
    public init() {}
}
