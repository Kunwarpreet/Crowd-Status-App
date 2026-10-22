import Foundation

@main
struct MarketDescriptionChecks {
    static func main() {
        func description(_ name: String, city: String? = nil, id: String? = nil, summary: String? = nil) -> MarketDescription? {
            MarketDescriptions.description(placeID: id, name: name, address: city, editorialSummary: summary)
        }
        let hall = description("Hall Bazar", city: "Hall Road, Amritsar, Punjab, India")!
        precondition(hall.text.contains("phulkari"))
        precondition(hall.sourceName == "Incredible India")
        precondition(hall.sourceURL.scheme == "https")
        precondition(description("  HALL   BAZAAR  ", city: "Amritsar") == hall)
        precondition(description("Hall Bazaar", city: "Delhi") == nil)
        precondition(description("Hall Bazaar") == nil)
        precondition(description("Hall Bazaar Clothes Shop", city: "Amritsar") == nil)
        precondition(description("City Market", city: "Mysuru") == nil)
        precondition(description("K.R. Market", city: "Bangalore")?.text.contains("flowers") == true)
        precondition(description("Gandhi Bazar Flower Market", city: "Bengaluru")?.text.contains("puja") == true)
        precondition(description("Guru Bazar", city: "Amritsar")?.text.contains("jadau") == true)
        precondition(description("Katra Jaimal Singh Market", city: "Amritsar")?.text.contains("textiles") == true)
        // Exact listing identity still works when its display name changes.
        precondition(description("Updated listing name", id: "ChIJ_xC6VOEVrjsRy_ZNwGx87Ac")?.text.contains("KR Market") == true)
        precondition(description("Sunday Market", city: "Bengaluru") == nil)
        precondition(description("Unknown Market", id: "unknown", summary: " \n ")?.sourceName == "Google Maps · Listing details")
        precondition(description("Unknown Market", summary: "A summary without a listing identity") == nil)
        let google = description("Fruit & Flower Market", id: "some/listing+id", summary: "  A source-supplied description.  ")!
        precondition(google.text == "  A source-supplied description.  ")
        precondition(google.sourceName == "Google Maps")
        let queryItems = URLComponents(url: google.sourceURL, resolvingAgainstBaseURL: false)!.queryItems!
        precondition(queryItems.first { $0.name == "query_place_id" }?.value == "some/listing+id")
        // Researched copy takes priority over a generic listing summary.
        precondition(description("Hall Bazaar", city: "Amritsar", id: "hall", summary: "Generic summary") == hall)
        let raja = description("Raja Market", city: "Bengaluru")!
        precondition(raja.sourceName == "Justdial · Review highlights")
        precondition(raja.text.contains("Visitors also mention"))
        precondition(description("Russell Market", city: "Bangalore")?.sourceName == "Justdial")
        precondition(description("KR Market Flower Market", city: "Bengaluru")?.sourceName == "Justdial")
        // The flower-market description must not replace the whole KR Market.
        precondition(description("KR Market", city: "Bengaluru")?.sourceName == "LBB")
        precondition(description("Shastri Market", city: "Amritsar")?.text.contains("textile") == true)
        precondition(description("Shastri Market", city: "Delhi") == nil)

        // Newly discovered listings work in any city without adding catalog entries.
        let farmers = MarketDescriptions.description(placeID: "new-farmers", name: "Harvest Market", address: "Pune, India", editorialSummary: nil, types: ["point_of_interest", "market", "farmers_market"])!
        precondition(farmers.text.contains("Farmers’ market"))
        precondition(farmers.text.contains("Pune, India"))
        precondition(!farmers.text.contains("mainly known"))
        let localized = MarketDescriptions.description(placeID: "new-flowers", name: "Flower Square", address: nil, editorialSummary: nil, types: ["market"], primaryTypeDisplayName: "Flower market")!
        precondition(localized.text.contains("Flower market"))
        let noCategory = MarketDescriptions.description(placeID: "new-place", name: "New Market", address: nil, editorialSummary: nil, types: ["unknown_future_type", "point_of_interest"])!
        precondition(!noCategory.text.contains("unknown_future_type"))
        precondition(noCategory.text.contains("specialty isn’t provided"))
        precondition(description("No listing", id: "   ") == nil)
        print("Market description checks passed")
    }
}
