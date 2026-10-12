import Foundation

@main
struct MarketAddressChecks {
    static func main() throws {
        precondition(GoogleMarketAddresses.placeIDs.count == 6)
        precondition(Set(GoogleMarketAddresses.placeIDs.values).count == 6)
        let placeID = GoogleMarketAddresses.placeIDs["Russell Market"]!
        let response = Data("""
        {"id":"\(placeID)","formattedAddress":"  MF Norrona St, Shivaji Nagar, Bengaluru, Karnataka 560051  "}
        """.utf8)
        let address = try GoogleMarketAddresses.address(from: response, expectedPlaceID: placeID)
        precondition(address == "MF Norrona St, Shivaji Nagar, Bengaluru, Karnataka 560051")
        for invalidResponse in [
            "{\"id\":\"unrelated-listing\",\"formattedAddress\":\"A different market\"}",
            "{\"id\":\"\(placeID)\",\"formattedAddress\":\"   \"}",
            "{\"id\":\"\(placeID)\"}"
        ] {
            do {
                _ = try GoogleMarketAddresses.address(from: Data(invalidResponse.utf8), expectedPlaceID: placeID)
                preconditionFailure("Wrong listing or missing address must not be displayed")
            } catch { }
        }
        print("Market address checks passed")
    }
}
