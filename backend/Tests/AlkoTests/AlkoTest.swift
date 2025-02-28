import Testing
@testable import Ylahylly

@Test func testFetchingAlkoStores() async throws {
    let service = AlkoService(apiKey: "-", baseUrl: "-", agent: "-")
    let stores = try await service.getStores()
    #expect(stores.count > 0)
}
