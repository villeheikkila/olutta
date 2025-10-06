import Foundation
import Logging
import OluttaShared
import PostgresNIO

extension GetAppDataCommand: AuthenticatedCommandExecutable {
    static func execute(
        logger: Logger,
        identity _: UserIdentity,
        deps: CommandDependencies,
        request _: Request,
    ) async throws -> Response {
        let stores = try await deps.pg.withConnection { tx in
            try await AlkoRepository.getStores(tx, logger: logger)
        }
        let storeEntities: [Store.Entity] = stores.map { store in
            .init(
                id: store.id,
                alkoStoreId: store.alkoStoreId,
                name: store.name,
                address: store.address,
                city: store.city,
                postalCode: store.postalCode,
                latitude: store.latitude,
                longitude: store.longitude,
            )
        }
        return Response(stores: storeEntities)
    }
}

extension GetAppDataCommand: CacheableCommand {
    static func cachePolicy(for _: Request) -> CachePolicy {
        .cache(key: "app_data", ttl: .seconds(300))
    }
}
