import Foundation

struct DeviceEntity: Codable {
    let id: UUID
    let pushNotificationToken: String?
    let isSandbox: Bool
    let tokenId: UUID
}
