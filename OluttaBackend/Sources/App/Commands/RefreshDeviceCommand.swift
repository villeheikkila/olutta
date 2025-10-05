import Foundation
import Logging
import OluttaShared
import PostgresNIO

extension RefreshDeviceCommand: AuthenticatedCommandExecutable {
    static func execute(
        logger: Logger,
        identity: UserIdentity,
        deps: CommandDependencies,
        request: Request,
    ) async throws -> Response {
        try await deps.pg.withTransaction { tx in
            try await UserRepository.updateUserDevice(
                connection: tx,
                logger: logger,
                userId: identity.userId,
                deviceId: request.deviceId,
                pushNotificationToken: request.pushNotificationToken,
            )
            return Response()
        }
    }
}
