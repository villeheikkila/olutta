import Foundation
import PostgresNIO

struct DeviceRepository: Sendable {
    let logger: Logger

    @discardableResult
    func upsertDevice(
        _ connection: PostgresConnection,
        device: DeviceEntity,
    ) async throws -> (id: UUID, isNewDevice: Bool, subscribedStoreIds: [UUID]) {
        let result = try await connection.query("""
            WITH device_upsert AS (
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
            )
            SELECT 
                d.id,
                d.is_new,
                COALESCE(ARRAY_AGG(pns.store_id ORDER BY pns.created_at DESC) FILTER (WHERE pns.store_id IS NOT NULL), ARRAY[]::UUID[]) AS subscribed_store_ids
            FROM device_upsert d
            LEFT JOIN public.push_notification_subscription pns ON d.id = pns.device_id
            GROUP BY d.id, d.is_new
        """, logger: logger)
        
        for try await (id, isNewDevice, subscribedStoreIds) in result.decode((UUID, Bool, [UUID]).self) {
            return (id, isNewDevice, subscribedStoreIds)
        }
        throw RepositoryError.noData
    }

    func removePushNotificationToken(
        _ connection: PostgresConnection,
        pushNotificationToken: String,
    ) async throws {
        try await connection.query("""
            DELETE FROM public.device
            WHERE push_notification_token = \(pushNotificationToken)
        """, logger: logger)
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
