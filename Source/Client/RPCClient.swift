import Foundation
import OluttaShared

public struct RPCClient {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func call<C: CommandMetadata>(
        _: C.Type,
        with request: C.RequestType,
    ) async throws(RPCError) -> C.ResponseType {
        do {
            return try await httpClient.post(
                path: "v1/rpc/\(Cmd.name)",
                body: request,
            )
        } catch let HTTPClientError.httpError(code, data) {
            throw RPCError.httpError(code: code, data: data)
        } catch let HTTPClientError.decodingFailed(error) {
            throw RPCError.decodingError(error)
        } catch {
            throw RPCError.networkError(error)
        }
    }

    public func call<Cmd: CommandMetadata>(
        _: Cmd.Type,
        with request: Cmd.RequestType,
        endpoint: String,
    ) async throws(RPCError) -> Cmd.ResponseType {
        do {
            return try await httpClient.post(
                endpoint: endpoint,
                body: request,
            )
        } catch let HTTPClientError.httpError(code, data) {
            throw RPCError.httpError(code: code, data: data)
        } catch let HTTPClientError.decodingFailed(error) {
            throw RPCError.decodingError(error)
        } catch {
            throw RPCError.networkError(error)
        }
    }
}

public enum RPCError: Error, LocalizedError {
    case networkError(Error)
    case httpError(code: Int, data: Data)
    case decodingError(Error)
    case commandNotFound(String)

    public var errorDescription: String? {
        switch self {
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case let .httpError(code, _):
            "HTTP error with status code: \(code)"
        case let .decodingError(error):
            "Failed to decode response: \(error.localizedDescription)"
        case let .commandNotFound(command):
            "Command not found: \(command)"
        }
    }
}
