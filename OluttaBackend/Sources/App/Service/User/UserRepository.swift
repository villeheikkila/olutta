import Foundation
import PostgresNIO

enum UserRepository {
    static func createUser(
        connection: PostgresConnection,
        logger: Logger,
    ) async throws -> UUID {
        let result = try await connection.query("""
            INSERT INTO public.users DEFAULT VALUES
            RETURNING id
        """, logger: logger)

        for try await (id) in result.decode(UUID.self) {
            return id
        }
        throw RepositoryError.noData
    }

    static func createRefreshToken(
        connection: PostgresConnection,
        logger: Logger,
        userId: UUID,
        expiresAt: Date,
    ) async throws -> UUID {
        let result = try await connection.query("""
            INSERT INTO public.user_refresh_tokens (user_id, expires_at)
            VALUES (\(userId), \(expiresAt))
            RETURNING refresh_token_id
        """, logger: logger)

        for try await (refreshTokenId) in result.decode(UUID.self) {
            return refreshTokenId
        }
        throw RepositoryError.noData
    }

    static func getRefreshTokenById(
        connection: PostgresConnection,
        refreshTokenId: UUID,
        logger: Logger,
    ) async throws -> (userId: UUID, deviceId: Int)? {
        let result = try await connection.query("""
            SELECT user_id
            FROM public.user_refresh_tokens
            WHERE refresh_token_id = \(refreshTokenId)
        """, logger: logger)

        for try await (userId, deviceId) in result.decode((UUID, Int).self) {
            return (userId: userId, deviceId: deviceId)
        }
        return nil
    }

    static func createUserDevice(
        connection: PostgresConnection,
        logger: Logger,
        userId: UUID,
        deviceId: UUID,
        pushNotificationToken: String?,
        expiresAt: Date,
    ) async throws -> UUID {
        let result = try await connection.query("""
            INSERT INTO public.user_devices (user_id, device_id, push_notification_token, expires_at)
            VALUES (\(userId), \(deviceId), \(pushNotificationToken), \(expiresAt))
            RETURNING token_id
        """, logger: logger)

        for try await (tokenId) in result.decode(UUID.self) {
            return tokenId
        }
        throw RepositoryError.noData
    }

    @discardableResult
    static func updateRefreshToken(
        connection: PostgresConnection,
        logger: Logger,
        userId: UUID,
        oldTokenId: UUID,
        newTokenId: UUID,
        expiresAt: Date,
    ) async throws -> UUID {
        let result = try await connection.query("""
            UPDATE public.user_refresh_tokens 
            SET 
                refresh_token_id = \(newTokenId),
                expires_at = \(expiresAt),
                updated_at = NOW()
            WHERE refresh_token_id = \(oldTokenId) AND user_id = \(userId)
            RETURNING refresh_token_id
        """, logger: logger)

        for try await (refreshTokenId) in result.decode(UUID.self) {
            return refreshTokenId
        }
        throw RepositoryError.noData
    }

    @discardableResult
    static func updateUserDevice(
        connection: PostgresConnection,
        logger: Logger,
        userId: UUID,
        deviceId: UUID,
        pushNotificationToken: String?,
    ) async throws -> UUID {
        let result = try await connection.query("""
            UPDATE public.user_devices 
            SET 
                push_notification_token = \(pushNotificationToken),
                updated_at = NOW(),
                seen_at = NOW()
            WHERE user_id = \(userId) AND device_id = \(deviceId)
            RETURNING token_id
        """, logger: logger)

        for try await (tokenId) in result.decode(UUID.self) {
            return tokenId
        }
        throw RepositoryError.noData
    }

    static func revokeUserDevice(
        connection: PostgresConnection,
        tokenId: UUID,
        logger: Logger,
    ) async throws {
        try await connection.query("""
            UPDATE public.user_devices
            SET revoked_at = NOW()
            WHERE token_id = \(tokenId)
        """, logger: logger)
    }

    static func getUserDevices(
        connection: PostgresConnection,
        userId: UUID,
        logger: Logger,
    ) async throws -> [UserDeviceEntity] {
        let result = try await connection.query("""
            SELECT id, device_id, token_id, push_notification_token, expires_at, created_at, revoked_at
            FROM public.user_devices
            WHERE user_id = \(userId)
            AND revoked_at IS NULL
            ORDER BY created_at DESC
        """, logger: logger)

        var devices: [UserDeviceEntity] = []
        for try await (id, deviceId, tokenId, pushNotificationId, expiresAt, createdAt, revokedAt) in result.decode((Int, String, UUID, String?, Date, Date, Date?).self) {
            let device = UserDeviceEntity(
                id: id,
                deviceId: deviceId,
                tokenId: tokenId,
                pushNotificationId: pushNotificationId,
                expiresAt: expiresAt,
                createdAt: createdAt,
                revokedAt: revokedAt,
            )
            devices.append(device)
        }
        return devices
    }

    static func getUser(
        connection: PostgresConnection,
        logger: Logger,
        userId: UUID,
    ) async throws -> UserWithSubscriptionsEntity? {
        let result = try await connection.query("""
            SELECT 
                u.id,
                u.created_at,
                u.updated_at,
                dpns.store_id,
                dpns.created_at as subscription_created_at
            FROM public.users u
            LEFT JOIN public.user_devices ud ON u.id = ud.user_id AND ud.revoked_at IS NULL
            LEFT JOIN public.device_push_notification_subscription dpns ON ud.id = dpns.device_id
            WHERE u.id = \(userId)
            ORDER BY dpns.created_at DESC
        """, logger: logger)
        var user: UserWithSubscriptionsEntity?
        var subscriptions: [StoreSubscriptionEntity] = []
        for try await (id, createdAt, updatedAt, storeId) in result.decode((UUID, Date, Date, UUID?).self) {
            if user == nil {
                user = UserWithSubscriptionsEntity(
                    id: id,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    subscriptions: [],
                )
            }

            if let storeId {
                let subscription = StoreSubscriptionEntity(
                    storeId: storeId,
                )
                subscriptions.append(subscription)
            }
        }
        user?.subscriptions = subscriptions
        return user
    }

    static func getUserDeviceByToken(
        connection: PostgresConnection,
        logger: Logger,
        tokenId: UUID,
    ) async throws -> (deviceId: UUID, userId: UUID, revokedAt: Date?)? {
        let result = try await connection.query("""
            SELECT 
                ud.device_id, 
                ud.user_id,
                ud.revoked_at
            FROM public.user_devices ud
            WHERE ud.token_id = \(tokenId)
        """, logger: logger)
        for try await (deviceId, userId, revokedAt) in result.decode((UUID, UUID, Date?).self) {
            return (deviceId, userId, revokedAt)
        }
        return nil
    }

    @discardableResult
    static func addPushNotificationSubscription(
        connection: PostgresConnection,
        deviceId: UUID,
        storeId: UUID,
        userId: UUID,
        logger: Logger,
    ) async throws -> UUID {
        let result = try await connection.query("""
            INSERT INTO public.device_push_notification_subscription (device_id, store_id, user_id)
            VALUES (\(deviceId), \(storeId), \(userId))
            ON CONFLICT (device_id, store_id) DO UPDATE SET
                updated_at = NOW()
            RETURNING id
        """, logger: logger)

        for try await id in result.decode(UUID.self) {
            return id
        }
        throw RepositoryError.noData
    }

    static func removePushNotificationSubscription(
        connection: PostgresConnection,
        deviceId: UUID,
        storeId: UUID,
        userId: UUID,
        logger: Logger,
    ) async throws {
        try await connection.query("""
            DELETE FROM public.device_push_notification_subscription
            WHERE device_id = \(deviceId) AND store_id = \(storeId) AND user_id = \(userId)
        """, logger: logger)
    }
}

struct UserDeviceEntity: Sendable {
    let id: Int
    let deviceId: String
    let tokenId: UUID
    let pushNotificationId: String?
    let expiresAt: Date
    let createdAt: Date
    let revokedAt: Date?
}

struct UserWithSubscriptionsEntity {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    var subscriptions: [StoreSubscriptionEntity]
}

struct StoreSubscriptionEntity {
    let storeId: UUID
}
