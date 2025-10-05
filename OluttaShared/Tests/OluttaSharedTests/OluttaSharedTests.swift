import Foundation
import HTTPTypes
@testable import OluttaShared
import Testing

@Test func testComputeBodyHash() {
    let service = SignatureService(secretKey: "test-secret-key")
    let testData = "test data".data(using: .utf8)!
    let bodyHash = service.computeBodyHash(data: testData)
    #expect(!bodyHash.isEmpty)
    #expect(Data(base64Encoded: bodyHash) != nil)
    let secondHash = service.computeBodyHash(data: testData)
    #expect(bodyHash == secondHash)
    let differentData = "different data".data(using: .utf8)!
    let differentHash = service.computeBodyHash(data: differentData)
    #expect(bodyHash != differentHash)
}

@Test func computeBodyHashEmptyData() {
    let service = SignatureService(secretKey: "test-secret-key")
    let emptyData = Data()
    let bodyHash = service.computeBodyHash(data: emptyData)
    #expect(!bodyHash.isEmpty)
    #expect(Data(base64Encoded: bodyHash) != nil)
}

@Test func createSignatureWithBody() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)
    let result = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    #expect(!result.signature.isEmpty)
    #expect(result.bodyHash != nil)
    #expect(!result.bodyHash!.isEmpty)
    #expect(Data(base64Encoded: result.signature) != nil)
}

@Test func createSignatureWithoutBody() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.get
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let result = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: nil
    )
    #expect(!result.signature.isEmpty)
    #expect(result.bodyHash == nil)
}

@Test func createSignatureWithEmptyBody() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let result = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: Data()
    )
    #expect(!result.signature.isEmpty)
    #expect(result.bodyHash == nil)
}

@Test func createSignatureDeterministic() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)
    let result1 = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    let result2 = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    #expect(result1.signature == result2.signature)
    #expect(result1.bodyHash == result2.bodyHash)
}

@Test func createSignatureDifferentMethods() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)
    let getResult = try service.createSignature(
        method: .get,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    let postResult = try service.createSignature(
        method: .post,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    #expect(getResult.signature != postResult.signature)
}

@Test func createSignatureDifferentPaths() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)
    let result1 = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: "/api/test",
        headers: headers,
        body: body
    )
    let result2 = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: "/api/different",
        headers: headers,
        body: body
    )
    #expect(result1.signature != result2.signature)
}

@Test func createSignatureDifferentSchemes() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)
    let httpsResult = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    let httpResult = try service.createSignature(
        method: method,
        scheme: "http",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    #expect(httpsResult.signature != httpResult.signature)
}

@Test func createSignatureDifferentAuthorities() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)
    let result1 = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    let result2 = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "different.com",
        path: path,
        headers: headers,
        body: body
    )
    #expect(result1.signature != result2.signature)
}

@Test func createSignatureDifferentRequestIds() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    let body = "{\"key\":\"value\"}".data(using: .utf8)
    var headers1 = HTTPFields()
    headers1.append(.init(name: .requestId, value: "request-id-1"))
    var headers2 = HTTPFields()
    headers2.append(.init(name: .requestId, value: "request-id-2"))
    let result1 = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers1,
        body: body
    )
    let result2 = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers2,
        body: body
    )
    #expect(result1.signature != result2.signature)
}

@Test func createSignatureDifferentSecretKeys() throws {
    let service1 = SignatureService(secretKey: "secret-key-1")
    let service2 = SignatureService(secretKey: "secret-key-2")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)
    let result1 = try service1.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    let result2 = try service2.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    #expect(result1.signature != result2.signature)
    #expect(result1.bodyHash == result2.bodyHash)
}

@Test func verifySignatureSuccess() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)!
    let result = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    headers.append(.init(name: .requestSignature, value: result.signature))
    if let bodyHash = result.bodyHash {
        headers.append(.init(name: .bodyHash, value: bodyHash))
    }
    try service.verifySignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
}

@Test func verifySignatureSuccessEmptyBody() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.get
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = Data()
    let result = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    headers.append(.init(name: .requestSignature, value: result.signature))
    try service.verifySignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
}

@Test func verifySignatureMissingSignature() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    let headers = HTTPFields()
    let body = "{\"key\":\"value\"}".data(using: .utf8)!
    #expect(throws: SignatureError.missingSignature) {
        try service.verifySignature(
            method: method,
            scheme: "https",
            authority: "example.com",
            path: path,
            headers: headers,
            body: body
        )
    }
}

@Test func verifySignatureMissingBodyHash() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    headers.append(.init(name: .requestSignature, value: "dummy-signature"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)!
    #expect(throws: SignatureError.missingBodyHash) {
        try service.verifySignature(
            method: method,
            scheme: "https",
            authority: "example.com",
            path: path,
            headers: headers,
            body: body
        )
    }
}

@Test func verifySignatureInvalidBodyHash() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    headers.append(.init(name: .requestSignature, value: "dummy-signature"))
    headers.append(.init(name: .bodyHash, value: "invalid-hash"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)!
    #expect(throws: SignatureError.invalidBodyHash) {
        try service.verifySignature(
            method: method,
            scheme: "https",
            authority: "example.com",
            path: path,
            headers: headers,
            body: body
        )
    }
}

@Test func verifySignatureInvalidSignature() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)!
    let result = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    headers.append(.init(name: .requestSignature, value: "invalid-signature"))
    if let bodyHash = result.bodyHash {
        headers.append(.init(name: .bodyHash, value: bodyHash))
    }
    #expect(throws: SignatureError.invalidSignature) {
        try service.verifySignature(
            method: method,
            scheme: "https",
            authority: "example.com",
            path: path,
            headers: headers,
            body: body
        )
    }
}

@Test func verifySignatureModifiedBody() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)
    let result = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    headers.append(.init(name: .requestSignature, value: result.signature))
    if let bodyHash = result.bodyHash {
        headers.append(.init(name: .bodyHash, value: bodyHash))
    }
    let modifiedBody = "{\"key\":\"modified\"}".data(using: .utf8)!
    #expect(throws: SignatureError.invalidBodyHash) {
        try service.verifySignature(
            method: method,
            scheme: "https",
            authority: "example.com",
            path: path,
            headers: headers,
            body: modifiedBody
        )
    }
}

@Test func verifySignatureModifiedPath() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)!
    let result = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    headers.append(.init(name: .requestSignature, value: result.signature))
    if let bodyHash = result.bodyHash {
        headers.append(.init(name: .bodyHash, value: bodyHash))
    }
    let modifiedPath = "/api/modified"
    #expect(throws: SignatureError.invalidSignature) {
        try service.verifySignature(
            method: method,
            scheme: "https",
            authority: "example.com",
            path: modifiedPath,
            headers: headers,
            body: body
        )
    }
}

@Test func signatureWithNilSchemeAndAuthority() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)!
    let result = try service.createSignature(
        method: method,
        scheme: nil,
        authority: nil,
        path: path,
        headers: headers,
        body: body
    )
    #expect(!result.signature.isEmpty)
    headers.append(.init(name: .requestSignature, value: result.signature))
    if let bodyHash = result.bodyHash {
        headers.append(.init(name: .bodyHash, value: bodyHash))
    }
    try service.verifySignature(
        method: method,
        scheme: nil,
        authority: nil,
        path: path,
        headers: headers,
        body: body
    )
}

@Test func signatureWithMultipleIncludedHeaders() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .requestId, value: "test-request-id"))
    headers.append(.init(name: .init("Content-Type")!, value: "application/json"))
    headers.append(.init(name: .init("Authorization")!, value: "Bearer token"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)!
    let result = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
    #expect(!result.signature.isEmpty)
    headers.append(.init(name: .requestSignature, value: result.signature))
    if let bodyHash = result.bodyHash {
        headers.append(.init(name: .bodyHash, value: bodyHash))
    }
    try service.verifySignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers,
        body: body
    )
}

@Test func signatureHeaderSorting() throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.post
    let path = "/api/test"
    let body = "{\"key\":\"value\"}".data(using: .utf8)!
    var headers1 = HTTPFields()
    headers1.append(.init(name: .requestId, value: "test-request-id"))
    var headers2 = HTTPFields()
    headers2.append(.init(name: .requestId, value: "test-request-id"))
    let result1 = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers1,
        body: body
    )
    let result2 = try service.createSignature(
        method: method,
        scheme: "https",
        authority: "example.com",
        path: path,
        headers: headers2,
        body: body
    )
    #expect(result1.signature == result2.signature)
}
