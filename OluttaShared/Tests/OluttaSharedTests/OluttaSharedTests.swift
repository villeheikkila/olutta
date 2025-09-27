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

@Test func testCreateSignature() async throws {
    let service = SignatureService(secretKey: "test-secret-key")
    let method = HTTPRequest.Method.get
    let path = "/api/test"
    var headers = HTTPFields()
    headers.append(.init(name: .init("Content-Type")!, value: "application/json"))
    let body = "{\"key\":\"value\"}".data(using: .utf8)

    let result = try service.createSignature(
        method: method,
        scheme: nil,
        authority: nil,
        path: path,
        headers: headers,
        body: body,
    )
    #expect(!result.signature.isEmpty)
    #expect(result.bodyHash != nil)
    #expect(!result.bodyHash!.isEmpty)
    let emptyResult = try service.createSignature(
        method: method,
        scheme: nil,
        authority: nil,
        path: path,
        headers: headers,
        body: nil,
    )
    #expect(!emptyResult.signature.isEmpty)
    #expect(emptyResult.bodyHash == nil)
    let differentPath = "/api/different"
    let differentResult = try service.createSignature(
        method: method,
        scheme: nil,
        authority: nil,
        path: differentPath,
        headers: headers,
        body: body,
    )
    #expect(result.signature != differentResult.signature)
}
