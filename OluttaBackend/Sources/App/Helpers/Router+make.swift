import Foundation
import Hummingbird
import HummingbirdRedis
import JWTKit
import Logging
import OluttaShared
import PostgresNIO

struct UnauthenticatedCommandDependencies {
    let pg: PostgresClient
    let jwtKeyCollection: JWTKeyCollection
    let appleService: SignInWithAppleService
}

struct AppRequestContext: RequestContext {
    var coreContext: CoreRequestContextStorage
    var identity: UserIdentity?

    init(source: ApplicationRequestContextSource) {
        self.coreContext = .init(source: source)
    }
}

func makeRouter(pg: PostgresClient, persist: RedisPersistDriver, jwtKeyCollection: JWTKeyCollection, requestSignatureSalt _: String, appleService: SignInWithAppleService) -> Router<AppRequestContext> {
    let router = Router(context: AppRequestContext.self)
    router.addMiddleware {
        LogRequestsMiddleware(.trace)
        // RequestSignatureMiddleware(secretKey: requestSignatureSalt)
        UniqueRequestMiddleware(persist: persist)
    }
    router.get("/health") { _, _ -> HTTPResponse.Status in
        return .ok
    }
    router.addRoutes(RouteCollection(context: AppRequestContext.self)
        .post("/v1/rpc/:command/unauthenticated", use: { request, context in
            try await handleUnauthenticatedCommand(request: request, context: context, dependencies: .init(pg: pg, jwtKeyCollection: jwtKeyCollection, appleService: appleService))
        }))
    router.addRoutes(RouteCollection(context: AppRequestContext.self)
        .add(middleware: AuthorizerMiddleware(jwtKeyCollection: jwtKeyCollection))
        .post("/v1/rpc/:command", use: { request, context in
            try await handleCommand(request: request, context: context, pg: pg, persist: persist, jwtKeyCollection: jwtKeyCollection)
        }))
    return router
}
