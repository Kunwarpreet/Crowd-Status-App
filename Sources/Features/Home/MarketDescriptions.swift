import Foundation

struct MarketDescription: Equatable {
    let text: String
    let sourceName: String
    let sourceURL: URL
}

enum MarketDescriptions {
    private struct Entry {
        let placeID: String?
        let names: [String]
        let cities: [String]
        let description: MarketDescription
    }

    // Researched on 22 October 2026. These are concise original summaries of the
    // linked sources, not inferred from a market's name or its Google categories.
    private static let entries: [Entry] = [
        // This is the flower-market listing, not every part of the larger KR Market.
        entry(
            names: ["KR Market Flower Market", "K R Market Flower Market"], cities: ["Bengaluru", "Bangalore"],
            text: "A flower-shopping destination in Bengaluru’s City Market area, with sellers offering flowers for different occasions.",
            source: "Justdial", url: "https://www.justdial.com/Bangalore/Kr-market-flower-market-Near-kr-market-post-office-next-city-City-market/080PXX80-XX80-221222110743-Q4W8_BZDET"
        ),
        entry(
            placeID: "ChIJ_xC6VOEVrjsRy_ZNwGx87Ac",
            names: ["KR Market", "K R Market", "Krishnarajendra Market", "Sri Krishnarajendra Market", "Sri Krishna Rajendra Market", "Krishna Rajendra Market", "City Market"],
            cities: ["Bengaluru", "Bangalore"],
            text: "KR Market is mainly known for its wholesale flower trade and fresh vegetables. Vendors sell flowers such as marigolds, jasmine and roses, alongside produce stalls.",
            source: "LBB", url: "https://lbb.in/bangalore/markets-in-bangalore/"
        ),
        entry(
            placeID: "ChIJwQdZj2EWrjsRvUuO1AgrS18",
            names: ["Russell Market", "Russel Market"], cities: ["Bengaluru", "Bangalore"],
            text: "A market in Shivajinagar where shoppers can buy fresh vegetables for everyday cooking.",
            source: "Justdial", url: "https://www.justdial.com/Bangalore/Russell-Market-Near-St-Churt-Shivaji-Nagar/080PXX80-XX80-180327111646-E6S1_BZDET"
        ),
        entry(
            placeID: "ChIJrSid6fIVrjsRbF8xr-ITHSw",
            names: ["Gandhi Bazaar", "Gandhi Bazaar Flower Market", "Gandhi Bazaar Market"], cities: ["Bengaluru", "Bangalore"],
            text: "Gandhi Bazaar in Basavanagudi is mainly known for fresh flowers, fruit, vegetables and puja supplies. The surrounding shops also sell silk saris, spices, incense and traditional sweets.",
            source: "Incredible India", url: "https://www.incredibleindia.gov.in/en/karnataka/bengaluru/bengaluru-travel-and-food-guide"
        ),
        entry(
            placeID: "ChIJPc7ToDMXrjsRe8YoBeRWLA4",
            names: ["Raja Market"], cities: ["Bengaluru", "Bangalore"],
            text: "Mainly known for jewellery, including gold and silver items. Visitors also mention gift items, craft supplies, puja essentials and celebration decorations.",
            source: "Justdial · Review highlights", url: "https://www.justdial.com/Bangalore/Raja-Market-Ganigarpet-Nagarathpet/080PXX80-XX80-190719231849-F3X2_BZDET/reviews"
        ),
        entry(
            placeID: "ChIJU7PCQbwVrjsRQapyxEblmF0",
            names: ["Jayanagar Market", "Jayanagar 4th Block Market", "Jayanagar 4th Block Shopping Complex", "Jayanagar Shopping Complex", "Jayanagar BDA Shopping Complex"], cities: ["Bengaluru", "Bangalore"],
            text: "Jayanagar's 4th Block market is known for clothes, footwear and fashion accessories. Shops and stalls around the BDA shopping complex also offer pottery, sculptures and other art items.",
            source: "Karnataka.com", url: "https://www.karnataka.com/bangalore/street-shopping-in-bangalore/"
        ),
        entry(
            names: ["Chickpet", "Chickpete", "Chikpet", "Chickpet Market", "Chickpete Market", "Chikpet Market"], cities: ["Bengaluru", "Bangalore"],
            text: "Chickpet is mainly known for sarees and textiles, including silk, cotton and other fabrics. Its shopping lanes are also a destination for traditional clothing and wedding shopping.",
            source: "Karnataka.com", url: "https://www.karnataka.com/bangalore/street-shopping-in-bangalore/"
        ),
        entry(
            names: ["Hall Bazaar", "Hall Bazaar Market"], cities: ["Amritsar"],
            text: "Hall Bazaar is known for phulkari embroidery, Punjabi clothing and fabrics. Shoppers also visit for shawls, traditional juttis, electronics and other everyday goods.",
            source: "Incredible India", url: "https://www.prod.incredibleindia.gov.in/content/incredible-india-v2/en/destinations/amritsar/listicles/traditional-markets-of-amritsar.html"
        ),
        entry(
            names: ["Katra Jaimal Singh", "Katra Jaimal Singh Bazaar", "Katra Jaimal Singh Market", "Jaimal Singh Market"], cities: ["Amritsar"],
            text: "Katra Jaimal Singh Bazaar is mainly known for textiles and clothing, including silk and cotton fabrics, embroidered dupattas, sarees and woollen shawls. Punjabi juttis are another traditional purchase here.",
            source: "Incredible India", url: "https://www.prod.incredibleindia.gov.in/content/incredible-india-v2/en/destinations/amritsar/listicles/traditional-markets-of-amritsar.html"
        ),
        entry(
            names: ["Guru Bazaar", "Guru Bazaar Market", "Guru Ka Bazaar"], cities: ["Amritsar"],
            text: "Guru Bazaar is mainly known for jewellery, especially gold and silver ornaments and traditional jadau pieces. It is one of Amritsar's historic markets, near the Golden Temple and Guru ka Mahal.",
            source: "Incredible India", url: "https://www.prod.incredibleindia.gov.in/content/incredible-india-v2/en/destinations/amritsar/listicles/traditional-markets-of-amritsar.html"
        ),
        entry(
            names: ["Shastri Market"], cities: ["Amritsar"],
            text: "Shastri Market is a wholesale and retail textile-shopping area in Amritsar.",
            source: "The Tribune", url: "https://www.tribuneindia.com/news/amritsar/tangled-mess-dangling-wires-an-open-invite-to-tragedy-in-amritsar-458802/"
        ),
        entry(
            names: ["Katra Ahluwalia", "Katra Ahluwalia Market", "Katra Ahluwalia Bazaar"], cities: ["Amritsar"],
            text: "Katra Ahluwalia is known as a wholesale and retail textile market in Amritsar.",
            source: "The Tribune", url: "https://www.tribuneindia.com/news/amritsar/tangled-mess-dangling-wires-an-open-invite-to-tragedy-in-amritsar-458802/"
        ),
        entry(
            names: ["Pratap Bazaar", "Partap Bazaar", "Pratap Market", "Partap Market"], cities: ["Amritsar"],
            text: "Pratap Bazaar is part of Amritsar’s wholesale and retail textile-shopping district.",
            source: "The Tribune", url: "https://www.tribuneindia.com/news/amritsar/tangled-mess-dangling-wires-an-open-invite-to-tragedy-in-amritsar-458802/"
        ),
        entry(
            names: ["Tahli Wala Bazaar", "Tahli Sahib Bazaar", "Bazaar Tahli Sahib", "Tahli Sahib Market"], cities: ["Amritsar"],
            text: "Tahli Wala Bazaar is known for wholesale and retail textile trading in Amritsar.",
            source: "The Tribune", url: "https://www.tribuneindia.com/news/amritsar/tangled-mess-dangling-wires-an-open-invite-to-tragedy-in-amritsar-458802/"
        ),
        entry(
            names: ["Mai Sewa Wala Bazaar", "Bazaar Mai Sewan", "Mai Sewan Bazaar", "Bazaar Mai Sewan Wala"], cities: ["Amritsar"],
            text: "Mai Sewa Wala Bazaar is known for stationery shopping in Amritsar’s old city.",
            source: "The Tribune", url: "https://www.tribuneindia.com/news/amritsar/tangled-mess-dangling-wires-an-open-invite-to-tragedy-in-amritsar-458802/"
        ),
        entry(
            names: ["Dal Mandi"], cities: ["Amritsar"],
            text: "Dal Mandi is among Amritsar’s trading markets for grains and spices.",
            source: "The Tribune", url: "https://www.tribuneindia.com/news/amritsar/tangled-mess-dangling-wires-an-open-invite-to-tragedy-in-amritsar-458802/"
        ),
        entry(
            names: ["Mishri Bazaar"], cities: ["Amritsar"],
            text: "Mishri Bazaar is among Amritsar’s trading markets for grains and spices.",
            source: "The Tribune", url: "https://www.tribuneindia.com/news/amritsar/tangled-mess-dangling-wires-an-open-invite-to-tragedy-in-amritsar-458802/"
        ),
        entry(
            names: ["Urban Haat", "Urban Haat Market"], cities: ["Amritsar"],
            text: "Urban Haat is known for traditional handicrafts and locally made artisan goods. Visitors can also sample Punjabi food while browsing the craft stalls.",
            source: "Incredible India", url: "https://www.incredibleindia.gov.in/en/punjab/amritsar/a-shoppers-paradise-of-heritage-and-elegance"
        ),
        entry(
            names: ["Lawrence Road", "Lawrence Road Market"], cities: ["Amritsar"],
            text: "Lawrence Road is a shopping area known for branded and designer clothing, alongside electronics, home decor and places to eat.",
            source: "Incredible India", url: "https://www.incredibleindia.gov.in/en/punjab/amritsar/a-shoppers-paradise-of-heritage-and-elegance"
        )
    ]

    static func description(placeID: String?, name: String, address: String?, editorialSummary: String?, types: [String] = [], primaryTypeDisplayName: String? = nil) -> MarketDescription? {
        // Place IDs identify exact listings. Name matching additionally needs the
        // listing's own city, never the user's currently selected city.
        if let placeID, let entry = entries.first(where: { $0.placeID == placeID }) {
            return entry.description
        }
        let normalizedName = normalize(name)
        let addressWords = Set(normalize(address ?? "").split(separator: " ").map(String.init))
        if let entry = entries.first(where: { entry in
            entry.names.contains { normalize($0) == normalizedName }
                && entry.cities.contains { addressWords.contains(normalize($0)) }
        }) {
            return entry.description
        }
        guard let placeID, !placeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var components = URLComponents(string: "https://www.google.com/maps/search/")!
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: name),
            URLQueryItem(name: "query_place_id", value: placeID)
        ]
        guard let url = components.url else { return nil }
        // Google editorial summaries are displayed as supplied, without rewriting.
        if let summary = editorialSummary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return MarketDescription(text: summary, sourceName: "Google Maps", sourceURL: url)
        }
        // Discovery is open-ended: every real listing can show its actual category
        // and location, but categories are never promoted into invented specialties.
        let category = listingCategory(primaryTypeDisplayName: primaryTypeDisplayName, types: types)
        var text = category.map { "\(name) is listed under “\($0)” on Google Maps." }
            ?? "\(name) is listed on Google Maps."
        if let address, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text += " You can find it at \(address.trimmingCharacters(in: .whitespacesAndNewlines))."
        }
        text += " A main product specialty isn’t provided in the available listing details."
        return MarketDescription(text: text, sourceName: "Google Maps · Listing details", sourceURL: url)
    }

    private static func listingCategory(primaryTypeDisplayName: String?, types: [String]) -> String? {
        if let label = primaryTypeDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            return label
        }
        // Use only known, user-facing labels, not arbitrary raw API values.
        let labels: [(String, String)] = [
            ("farmers_market", "Farmers’ market"), ("flea_market", "Flea market"),
            ("wholesaler", "Wholesaler"), ("florist", "Florist"),
            ("jewelry_store", "Jewellery store"), ("clothing_store", "Clothing store"),
            ("shoe_store", "Shoe store"), ("electronics_store", "Electronics store"),
            ("book_store", "Bookshop"), ("hardware_store", "Hardware store"),
            ("home_goods_store", "Home goods store"), ("furniture_store", "Furniture store"),
            ("grocery_store", "Grocery store"), ("supermarket", "Supermarket"),
            ("shopping_mall", "Shopping mall"), ("market", "Market"), ("store", "Store")
        ]
        return labels.first { types.contains($0.0) }?.1
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .map { $0 == "bazar" ? "bazaar" : $0 }
            .joined(separator: " ")
    }

    private static func entry(placeID: String? = nil, names: [String], cities: [String], text: String, source: String, url: String) -> Entry {
        Entry(placeID: placeID, names: names, cities: cities,
              description: MarketDescription(text: text, sourceName: source, sourceURL: URL(string: url)!))
    }
}
