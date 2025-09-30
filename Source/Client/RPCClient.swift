import Foundation
import HTTPTypes
import OluttaShared

final class RPCClient {
    private let httpClient: HTTPClient
    private let path: String
    private var tokenProvider: (() -> String?)?

    init(
        httpClient: HTTPClient,
        path: String = "v1/rpc"
    ) {
        self.httpClient = httpClient
        self.path = path
    }

    func setTokenProvider(_ provider: @escaping () -> String?) {
        tokenProvider = provider
    }

    @discardableResult
    func call<C: CommandMetadata>(
        _: C.Type,
        with request: C.RequestType,
    ) async throws(RPCError) -> C.ResponseType {
        var headers: [HTTPField] = []
        if let token = tokenProvider?() {
            headers.append(.init(name: .authorization, value: "Bearer \(token)"))
        }

        do {
            return try await httpClient.post(
                path: "\(path)/\(C.name)",
                body: request,
                headers: headers
            )
        } catch let HTTPClientError.httpError(code, data) {
            throw RPCError.httpError(code: code, data: data)
        } catch let HTTPClientError.decodingFailed(error) {
            throw RPCError.decodingError(error)
        } catch {
            throw RPCError.networkError(error)
        }
    }

    func call<Cmd: CommandMetadata>(
        _: Cmd.Type,
        with request: Cmd.RequestType,
        endpoint: String,
    ) async throws(RPCError) -> Cmd.ResponseType {
        var headers: [HTTPField] = []
        if let token = tokenProvider?() {
            headers.append(.init(name: .authorization, value: "Bearer \(token)"))
        }

        do {
            return try await httpClient.post(
                path: endpoint,
                body: request,
                headers: headers
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
