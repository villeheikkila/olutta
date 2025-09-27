import Foundation
import HTTPTypes
import Hummingbird

extension Response {
    static func makeJSONResponse(
        status: HTTPResponse.Status = .ok,
        headers: HTTPFields = [:],
        body: some Encodable,
    ) throws -> Response {
        let data = try JSONEncoder().encode(body)
        let defaultHeaders: HTTPFields = [
            .contentType: "application/json; charset=utf-8",
            .contentLength: "\(data.count)",
        ]
        let responseHeaders = defaultHeaders + headers
        return Response(
            status: status,
            headers: responseHeaders,
            body: .init(byteBuffer: ByteBuffer(data: data)),
        )
    }
}
