import Foundation
import Logging
import PostgresNIO

final class DeviceModel: Sendable {
    private let logger: Logger
    let pg: PostgresClient
    private let deviceRepository: DeviceRepository
    private let pushNotificationSubscriptionRepository: PushNotificationSubscriptionRepository

    init(
        logger: Logger = Logger(label: "device"),
        deviceRepository: DeviceRepository,
        pg: PostgresClient,
        pushNotificationSubscriptionRepository: PushNotificationSubscriptionRepository,
    ) {
        self.logger = logger
        self.deviceRepository = deviceRepository
        self.pg = pg
        self.pushNotificationSubscriptionRepository = pushNotificationSubscriptionRepository
    }

    func upsertDevice(deviceId: UUID, pushNoticationToken: String, isSandbox: Bool, tokenId: UUID) async throws {
        try await pg.withTransaction { tx in
            try await deviceRepository.upsertDevice(tx, device: .init(id: deviceId, pushNotificationToken: pushNoticationToken, isSandbox: isSandbox, tokenId: tokenId))
        }
    }

    func subscribeToStore(deviceId: UUID, storeId: UUID) async throws {
        try await pg.withTransaction { tx in
            try await pushNotificationSubscriptionRepository.addSubscription(.init(logger: logger, connection: tx), deviceId: deviceId, storeId: storeId)
        }
    }

    func unsubscribeFromStore(deviceId: UUID, storeId: UUID) async throws {
        try await pg.withTransaction { tx in
            try await pushNotificationSubscriptionRepository.removeSubscription(.init(logger: logger, connection: tx), deviceId: deviceId, storeId: storeId)
        }
    }
}
