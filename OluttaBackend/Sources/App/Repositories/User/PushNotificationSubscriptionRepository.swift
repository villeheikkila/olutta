import Foundation
import PostgresNIO

struct PushNotificationSubscriptionRepository: Sendable {
    @discardableResult
    func addSubscription(
        _ connection: PostgresConnection,
        logger: Logger,
        deviceId: UUID,
        storeId: UUID,
    ) async throws -> UUID {
        let result = try await connection.query("""
            INSERT INTO public.push_notification_subscription (device_id, store_id)
            VALUES (\(deviceId), \(storeId))
            ON CONFLICT (device_id, store_id) DO UPDATE SET
                updated_at = NOW()
            RETURNING id
        """, logger: logger)

        for try await id in result.decode(UUID.self) {
            return id
        }
        throw RepositoryError.noData
    }

    func removeSubscription(
        _ connection: PostgresConnection,
        logger: Logger,
        deviceId: UUID,
        storeId: UUID,
    ) async throws {
        try await connection.query("""
            DELETE FROM public.push_notification_subscription
            WHERE device_id = \(deviceId) AND store_id = \(storeId)
        """, logger: logger)
    }
}
