import Foundation
import Logging
import OluttaShared
import PostgresNIO

extension GetProductsByStoreIdCommand: AuthenticatedCommandExecutable {
    static func execute(
        logger: Logger,
        identity _: UserIdentity,
        deps: AuthenticatedCommandDependencies,
        request: Request,
    ) async throws -> Response {
        let products = try await deps.pg.withTransaction { tx in
            try await AlkoRepository.getProductsByStoreId(tx, logger: logger, id: request.storeId)
        }
        let productEntities = products.map {
            ProductEntity(
                id: $0.alkoProduct.id,
                alkoId: $0.alkoProduct.productExternalId,
                untappdId: $0.untappdProduct?.productExternalId,
                name: $0.alkoProduct.name,
                manufacturer: $0.untappdProduct?.breweryName,
                price: $0.alkoProduct.price,
                alcoholPercentage: $0.alkoProduct.abv,
                beerStyle: $0.untappdProduct?.style,
            )
        }
        return Response(products: productEntities)
    }
}
