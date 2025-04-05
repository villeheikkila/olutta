import Foundation
import Testing
@testable import Ylahylly

@Test func testUntappdSearch() async throws {
    do {
        print("HEI")
        let service = UntappdService(appName: "Olutta", clientId: "CE330C2A8FD159902D33A6675F43450D9C311C98", clientSecret: "C9D7120536A8E3330CD85CD43EEF62EE9EB85CC3")
        let beer = try await service.searchBeer(query: "Punk IPA")
        print(beer)
    } catch {
        print("HEII")
        print(error)
    }
}

@Test func testUntappdMeta() async throws {
    do {
        print("HEI")
        let service = UntappdService(appName: "Olutta", clientId: "CE330C2A8FD159902D33A6675F43450D9C311C98", clientSecret: "C9D7120536A8E3330CD85CD43EEF62EE9EB85CC3")
        let beer = try await service.getBeerMetadata(bid: 4_643_737)
        print(beer)
    } catch {
        print("HEII")
        print(error)
    }
}
