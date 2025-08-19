import Hummingbird
import OluttaShared

public extension RouteCollection {
    @discardableResult func get(
        _ endpoint: APIEndpoint,
        use handler: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator,
    ) -> Self {
        get(RouterPath(stringLiteral: endpoint.pathConfig), use: handler)
    }

    @discardableResult func put(
        _ endpoint: APIEndpoint,
        use handler: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator,
    ) -> Self {
        put(RouterPath(stringLiteral: endpoint.pathConfig), use: handler)
    }

    @discardableResult func delete(
        _ endpoint: APIEndpoint,
        use handler: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator,
    ) -> Self {
        delete(RouterPath(stringLiteral: endpoint.pathConfig), use: handler)
    }

    @discardableResult func head(
        _ endpoint: APIEndpoint,
        use handler: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator,
    ) -> Self {
        head(RouterPath(stringLiteral: endpoint.pathConfig), use: handler)
    }

    @discardableResult func post(
        _ endpoint: APIEndpoint,
        use handler: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator,
    ) -> Self {
        post(RouterPath(stringLiteral: endpoint.pathConfig), use: handler)
    }

    @discardableResult func patch(
        _ endpoint: APIEndpoint,
        use handler: @Sendable @escaping (Request, Context) async throws -> some ResponseGenerator,
    ) -> Self {
        patch(RouterPath(stringLiteral: endpoint.pathConfig), use: handler)
    }
}
