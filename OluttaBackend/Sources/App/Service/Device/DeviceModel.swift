import Foundation
import Logging
import PostgresNIO

final class DeviceModel: Sendable {
    private let logger: Logger
    let pg: PostgresClient
    private let deviceRepository: DeviceRepository

    init(
        logger: Logger = Logger(label: "device"),
        deviceRepository: DeviceRepository,
        pg: PostgresClient,
    ) {
        self.logger = logger
        self.deviceRepository = deviceRepository
        self.pg = pg
    }

    func upsertDevice(deviceId: UUID, pushNoticationToken: String, isSandbox: Bool, tokenId: UUID) async throws {
        try await pg.withTransaction { tx in
            try await deviceRepository.upsertDevice(tx, device: .init(id: deviceId, pushNotificationToken: pushNoticationToken, isSandbox: isSandbox, tokenId: tokenId))
        }
    }
}
