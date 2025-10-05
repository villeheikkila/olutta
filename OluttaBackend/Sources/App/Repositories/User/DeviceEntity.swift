import Foundation

struct DeviceEntity: Codable {
    let id: UUID
    let pushNotificationToken: String?
    let isSandbox: Bool
    let tokenId: UUID
}

struct UserEntity: Codable {
    let id: UUID
    let subscriptions: [Subscription]

    struct Subscription: Codable {
        let storeId: UUID
    }
}
