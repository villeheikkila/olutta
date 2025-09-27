import Foundation
import PostgresNIO

struct DeviceRepository: Sendable {
    let logger: Logger

    @discardableResult
    func upsertDevice(
        _ connection: PostgresConnection,
        device: DeviceEntity,
    ) async throws -> (id: UUID, isNewDevice: Bool) {
        let result = try await connection.query("""
            INSERT INTO public.device (id, push_notification_token, is_sandbox, token_id)
            VALUES (
                \(device.id),
                \(device.pushNotificationToken),
                \(device.isSandbox),
                \(device.tokenId)
            )
            ON CONFLICT (id) DO UPDATE SET
                push_notification_token = EXCLUDED.push_notification_token,
                is_sandbox = EXCLUDED.is_sandbox,
                token_id = EXCLUDED.token_id
            RETURNING id, (xmax = 0) AS is_new
        """, logger: logger)
        for try await (id, isNewDevice) in result.decode((UUID, Bool).self) {
            return (id, isNewDevice)
        }
        throw RepositoryError.noData
    }

    func getDevice(
        _ connection: PostgresConnection,
        by id: UUID,
    ) async throws -> DeviceEntity? {
        let result = try await connection.query("""
            SELECT id, push_notification_token, is_sandbox, token_id
            FROM public.device
            WHERE id = \(id)
        """, logger: logger)

        for try await (id, pushNotificationToken, isSandbox, tokenId) in result.decode((UUID, String, Bool, UUID).self) {
            return DeviceEntity(id: id, pushNotificationToken: pushNotificationToken, isSandbox: isSandbox, tokenId: tokenId)
        }
        return nil
    }
}
