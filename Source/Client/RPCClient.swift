import Foundation
import OluttaShared

public struct RPCClient {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func call<C: CommandMetadata>(
        _ commandType: C.Type,
        with request: C.RequestType
    ) async throws(RPCError) -> C.ResponseType {
        do {
            return try await httpClient.post(
                path: "v1/rpc/\(Cmd.name)",
                body: request
            )
        } catch HTTPClientError.httpError(let code, let data) {
            throw RPCError.httpError(code: code, data: data)
        } catch HTTPClientError.decodingFailed(let error) {
            throw RPCError.decodingError(error)
        } catch {
            throw RPCError.networkError(error)
        }
    }

    public func call<Cmd: CommandMetadata>(
        _ commandType: Cmd.Type,
        with request: Cmd.RequestType,
        endpoint: String
    ) async throws(RPCError) -> Cmd.ResponseType {
        do {
            return try await httpClient.post(
                endpoint: endpoint,
                body: request
            )
        } catch HTTPClientError.httpError(let code, let data) {
            throw RPCError.httpError(code: code, data: data)
        } catch HTTPClientError.decodingFailed(let error) {
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
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code, _):
            return "HTTP error with status code: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .commandNotFound(let command):
            return "Command not found: \(command)"
        }
    }
}
