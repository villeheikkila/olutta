import Foundation
import Testing
@testable import Ylahylly

@Test func testGetProduct() async throws {
    let service = AlkoService(apiKey: "gfpVm6EIC0lE3LwVADQNMWeClvPvpM3L1P95FYD88M5KNAmpT97kwaaSFgLWFKC0", baseUrl: "https://mobile-api.alko.fi", agent: "AlkoMobile/1740734300")
    let stores = try await service.getProduct(id: "793575")
    print(stores)
}

@Test func testGetWebstoreAvailability() async throws {
    let service = AlkoService(apiKey: "gfpVm6EIC0lE3LwVADQNMWeClvPvpM3L1P95FYD88M5KNAmpT97kwaaSFgLWFKC0", baseUrl: "https://mobile-api.alko.fi", agent: "AlkoMobile/1740734300")
    let stores = try await service.getWebstoreAvailability(id: "793575")
    print(stores)
}

@Test func testGetAvailability() async throws {
    let service = AlkoService(apiKey: "gfpVm6EIC0lE3LwVADQNMWeClvPvpM3L1P95FYD88M5KNAmpT97kwaaSFgLWFKC0", baseUrl: "https://mobile-api.alko.fi", agent: "AlkoMobile/1740734300")
    let stores = try await service.getAvailability(productId: "793575")
    print(stores)
}

@Test func testGetStores() async throws {
    let service = AlkoService(apiKey: "gfpVm6EIC0lE3LwVADQNMWeClvPvpM3L1P95FYD88M5KNAmpT97kwaaSFgLWFKC0", baseUrl: "https://mobile-api.alko.fi", agent: "AlkoMobile/1740734300")
    let stores = try await service.getStores()
    print(stores)
}

@Test func testGetAllBeer() async throws {
    let service = AlkoService(apiKey: "gfpVm6EIC0lE3LwVADQNMWeClvPvpM3L1P95FYD88M5KNAmpT97kwaaSFgLWFKC0", baseUrl: "https://mobile-api.alko.fi", agent: "AlkoMobile/1740734300")
    let stores = try await service.getAllBeers()
    print(stores)
}
