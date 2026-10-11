import SwiftUI

private struct NearbyMarket: Identifiable {
    let id: String
    let name: String
    let imageName: String
    let crowdLevel: CrowdLevel
    let distance: String
}

private struct PopularMarket: Identifiable {
    let id: String
    let name: String
    let imageName: String
}

private enum CrowdLevel {
    case low
    case medium
    case high

    var title: String {
        switch self {
        case .low: "Low"
        case .medium: "Mid"
        case .high: "High"
        }
    }

    var foreground: Color {
        switch self {
        case .low: Color(hex: 0x156014)
        case .medium: Color(hex: 0xFC9E0C)
        case .high: Color(hex: 0xDD0405)
        }
    }

    var background: Color {
        switch self {
        case .low: Color(hex: 0xE6FAED)
        case .medium: Color(hex: 0xFEEFDA)
        case .high: Color(hex: 0xFCDfe0)
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

struct HomeView: View {
    @State private var selectedMarket: MarketSearchResult?

    private let nearbyMarkets = [
        NearbyMarket(
            id: "russell",
            name: "Russell Market",
            imageName: "RussellMarket",
            crowdLevel: .low,
            distance: "1km"
        ),
        NearbyMarket(
            id: "jayanagar",
            name: "Jayanagar Market",
            imageName: "JayanagarMarket",
            crowdLevel: .medium,
            distance: "1.5km"
        ),
        NearbyMarket(
            id: "sunday",
            name: "Sunday Market",
            imageName: "SundayMarket",
            crowdLevel: .high,
            distance: "2km"
        )
    ]

    private let popularMarkets = [
        PopularMarket(id: "kr", name: "KR Market", imageName: "PopularKRMarket"),
        PopularMarket(id: "chickpet", name: "Chickpet Market", imageName: "PopularChickpetMarket"),
        PopularMarket(id: "raja", name: "Raja Market", imageName: "PopularRajaMarket")
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 40) {
                header
                mainSections
            }
            .padding(.horizontal, AppSpacing.regular)
            .padding(.top, 12)
            .padding(.bottom, AppSpacing.large)
        }
        .background(Color.white)
        .navigationDestination(item: $selectedMarket) { market in
            MarketDetailView(market: market)
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.large) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Image("LocationPin")
                        .resizable()
                        .frame(width: 24, height: 24)

                    Text("BK Nagar Main Rd, BLR")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "bell")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 40)
                    .accessibilityLabel("Notifications")

                Image("ProfileAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .accessibilityLabel("Profile")
            }
            .frame(height: 40)

            NavigationLink {
                MarketSearchView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(.black)

                    Text("Search by “Market”")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.black)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .frame(height: 57)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: 0xE5E7EB), lineWidth: 1)
                }
                // CSS blur 4px corresponds to a 2pt shadow radius, with no spread.
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Search by Market")
            .accessibilityHint("Opens market search")
        }
    }

    private var mainSections: some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 24) {
                    sectionHeading("Nearby", subtitle: "Check nearby markets crowd")

                    VStack(spacing: 20) {
                        ForEach(nearbyMarkets) { market in
                            Button {
                                selectedMarket = market.detail
                            } label: {
                                NearbyMarketCard(market: market)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                CrowdStatusCard()
            }

            VStack(alignment: .leading, spacing: 24) {
                sectionHeading("Popular", subtitle: "Check popular markets crowd")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(popularMarkets) { market in
                            Button {
                                selectedMarket = market.detail
                            } label: {
                                PopularMarketCard(market: market)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.trailing, -AppSpacing.regular)
            }
        }
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppColors.primaryText)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
        }
    }
}

private struct NearbyMarketCard: View {
    let market: NearbyMarket

    var body: some View {
        HStack(spacing: 12) {
            Image(market.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.18))
                        .allowsHitTesting(false)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(market.name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 4) {
                    Text("Open")
                        .foregroundStyle(Color(hex: 0x156014))
                    Circle()
                        .fill(Color(hex: 0x808080))
                        .frame(width: 2, height: 2)
                    Text("Closed 9pm")
                        .foregroundStyle(AppColors.secondaryText)
                }
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(market.crowdLevel.title)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(market.crowdLevel.foreground)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(market.crowdLevel.background, in: Capsule())

                HStack(spacing: 2) {
                    Image("LocationPinGray")
                        .resizable()
                        .frame(width: 12, height: 12)

                    Text(market.distance)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(1)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: 0xF2F2F7), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 0)
        .accessibilityElement(children: .combine)
    }
}

private struct CrowdStatusCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Crowd Status")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)

                Text("Search any market you want to check crowd status at your time.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: 0x475569))
                    .frame(width: 256, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Text("Search Market")
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppColors.primary, in: Capsule())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xEFF6FF), in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}

private struct PopularMarketCard: View {
    let market: PopularMarket

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(market.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 129, height: 76)
                .clipped()
                .overlay {
                    Color.black.opacity(0.18)
                        .allowsHitTesting(false)
                }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(market.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text("Open")
                            .foregroundStyle(AppColors.secondaryText)
                        Circle()
                            .fill(AppColors.secondaryText)
                            .frame(width: 2, height: 2)
                        Text("4.0")
                            .foregroundStyle(.black)
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.accent)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
            }
            .padding(8)
        }
        .frame(width: 131, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: 0xF2F2F7), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 0)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeView()
}

private struct MarketSearchResult: Identifiable, Hashable {
    let name: String
    let imageName: String
    let address: String?
    let distance: String

    var id: String { name }

    // Shared sample gallery in the order supplied in the design reference.
    var galleryImageNames: [String] {
        ["PopularRajaMarket", "JayanagarMarket", "RussellMarket", "PopularChickpetMarket"]
    }

    // Sample editorial copy and visit details, pending a live market data source.
    var aboutDescription: String {
        switch name {
        case "Raja Market":
            "Raja Market is most famous for its vast wholesale and retail selection of imitation and traditional jewelry, including Kundan sets, temple jewelry, Rajasthani handmade pieces, and antique silver items."
        case "KR Market":
            "Explore KR Market’s busy shopping lanes, browse the stalls, and discover something new on your next visit. Check the crowd before you leave and use the directions below to plan your trip."
        case "Chickpet Market":
            "Take a walk through Chickpet Market, explore the shops, and compare finds along the way. Plan some extra time to browse and check the crowd to choose a comfortable time for your visit."
        case "Russell Market":
            "Browse Russell Market’s stalls and explore the surrounding shopping area at your own pace. Check today’s crowd and plan your route before heading out for your next market visit."
        case "Jayanagar Market":
            "Explore Jayanagar Market, browse the shops, and enjoy a relaxed shopping trip. Use the crowd information to plan your visit and the directions below to find your way to the market."
        case "Sunday Market":
            "Make time for a weekend visit to Sunday Market, explore the stalls, and browse for your next find. Check the crowd before you set off and use the map to plan your route."
        default:
            "Explore \(name), browse the shops, and plan your next visit with the crowd information and directions below."
        }
    }

    var openingDays: String { name == "Sunday Market" ? "Sunday" : "Mon-Sat" }
    var openingHours: String { "9am - 9pm" }
    var rating: String { "4/5" }

    // Shared contact number supplied for all markets.
    var phoneURL: URL { URL(string: "tel:8054369102")! }
}

private extension NearbyMarket {
    var detail: MarketSearchResult {
        MarketSearchResult(
            name: name,
            imageName: imageName,
            address: nil,
            distance: distance
        )
    }
}

private extension PopularMarket {
    var detail: MarketSearchResult {
        MarketSearchResult(
            name: name,
            imageName: imageName,
            address: nil,
            distance: "5kms"
        )
    }
}

private struct MarketSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    @State private var searchText = ""
    @State private var selectedMarket: MarketSearchResult?

    private let markets = [
        MarketSearchResult(
            name: "Raja Market",
            imageName: "PopularRajaMarket",
            address: "162, Avenue Rd, Kumbarpet, Dodpete, Nagarathpete, Bengaluru, Karnataka 560002",
            distance: "5kms"
        ),
        MarketSearchResult(
            name: "KR Market",
            imageName: "PopularKRMarket",
            address: nil,
            distance: "5kms"
        ),
        MarketSearchResult(
            name: "Chickpet Market",
            imageName: "PopularChickpetMarket",
            address: nil,
            distance: "5kms"
        ),
        MarketSearchResult(
            name: "Russell Market",
            imageName: "RussellMarket",
            address: nil,
            distance: "1km"
        ),
        MarketSearchResult(
            name: "Jayanagar Market",
            imageName: "JayanagarMarket",
            address: nil,
            distance: "1.5km"
        ),
        MarketSearchResult(
            name: "Sunday Market",
            imageName: "SundayMarket",
            address: nil,
            distance: "2km"
        ),
    ]

    private var matchingMarkets: [MarketSearchResult] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        return markets.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 32) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(width: 32, height: 32, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.black)

                    TextField("", text: $searchText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                        .focused($isSearchFocused)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Search markets")
                }
                .padding(.horizontal, 15)
                .frame(height: 57)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: 0xE5E7EB), lineWidth: 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(matchingMarkets) { market in
                        Button {
                            isSearchFocused = false
                            selectedMarket = market
                        } label: {
                            MarketSearchResultRow(market: market)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 29)
                .padding(.top, 22)
                .padding(.bottom, 20)
            }

            Spacer(minLength: 0)
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedMarket) { market in
            MarketDetailView(market: market)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSearchFocused = true
            }
        }
    }
}

private struct MarketSearchResultRow: View {
    let market: MarketSearchResult

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "storefront")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color(hex: 0x222222))
                    .frame(width: 48, height: 48)
                    .background(Color(hex: 0xF3F3F6), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(market.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)

                    Text(market.address ?? "Bengaluru, Karnataka")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: 0x808080))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: 0x222222))
                .frame(width: 32, height: 32)
                .background(Color(hex: 0xF3F3F6), in: Circle())
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LiveCrowdIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let fadeDuration: TimeInterval = 0.6

    var body: some View {
        if reduceMotion || scenePhase != .active {
            dot
        } else {
            dot.phaseAnimator([true, false]) { content, isVisible in
                content.opacity(isVisible ? 1 : 0.15)
            } animation: { _ in
                .easeInOut(duration: fadeDuration)
            }
        }
    }

    private var dot: some View {
        Circle()
            .fill(Color(hex: 0xDD0405))
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

private struct MarketDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isBookmarked = false
    @State private var selectedPhotoIndex = 0
    @State private var showsAlertNotice = false

    let market: MarketSearchResult

    private let crowdValues: [CGFloat] = [
        0.18, 0.31, 0.26, 0.61, 0.2, 0.16, 0.23, 0.19, 0.14, 0.11, 0.16, 0.12, 0.1
    ]
    private let hours = ["9am", "10am", "11am", "12pm", "1pm", "2pm", "3pm", "4pm", "5pm", "6pm", "7pm", "8pm", "9pm"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroImage
                marketInformation
            }
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Crowd alerts", isPresented: $showsAlertNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Scheduled crowd alerts are not available yet. Crowd information currently uses sample data.")
        }
    }

    private var heroImage: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array(market.galleryImageNames.enumerated()), id: \.offset) { index, imageName in
                    GeometryReader { geometry in
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .tag(index)
                    .accessibilityLabel("Market photo \(index + 1) of \(market.galleryImageNames.count)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 296)
            .accessibilityLabel("Photos of \(market.name)")
            .accessibilityValue("Photo \(selectedPhotoIndex + 1) of \(market.galleryImageNames.count)")

            HStack {
                detailAction(symbol: "arrow.left", label: "Back") {
                    dismiss()
                }

                Spacer()

                Button {
                    showsAlertNotice = true
                } label: {
                    Image("NotificationAdd")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .frame(width: 48, height: 48)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set a crowd alert for \(market.name)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 96)

            if market.galleryImageNames.count > 1 {
                HStack(spacing: 4) {
                    ForEach(market.galleryImageNames.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedPhotoIndex ? .white : .white.opacity(0.4))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 24)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .frame(height: 296)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.12)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 72)
            .allowsHitTesting(false)
        }
    }

    private var marketInformation: some View {
        VStack(alignment: .leading, spacing: 40) {
            marketHeader
            todaysCrowd
            alertCard
            aboutMarket
            directions
        }
        .padding(.horizontal, 16)
        .padding(.top, 40)
        .padding(.bottom, 28)
    }

    private var marketHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(market.name)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 2) {
                        Image("LocationOn")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .accessibilityHidden(true)
                        Text(market.address ?? (market.name == "Raja Market"
                            ? "162, Avenue Rd, Kumbarpet, Bengaluru"
                            : "Bengaluru, Karnataka"))
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .foregroundStyle(AppColors.secondaryText)
                }

                Text("\(market.distance) from your location")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 266, alignment: .leading)

            Spacer(minLength: 0)

            Button {
                isBookmarked.toggle()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var todaysCrowd: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeading("Today’s crowd")
            crowdSummary
            VStack(spacing: 12) {
                crowdChart
                Text("Updates in every 10mins")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var alertCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Check this market crowd at your specific time.")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showsAlertNotice = true
            } label: {
                Text("Set Alert")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 44)
                    .background(AppColors.primary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xE4EDFF), in: RoundedRectangle(cornerRadius: 24))
    }

    private var aboutMarket: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading("About")
            Text(market.aboutDescription)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
                GridRow {
                    marketFact(symbol: "storefront", text: market.openingDays)
                    marketFact(symbol: "clock", text: market.openingHours)
                }
                GridRow {
                    marketFact(symbol: "star.fill", text: market.rating)
                    Link(destination: market.phoneURL) {
                        marketFact(symbol: "phone", text: "Call")
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Call \(market.name) at 8054369102")
                }
            }
            .foregroundStyle(.black)
            .tint(.black)
            .padding(.top, 16)
        }
    }

    private var directions: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading("Directions")
            if let url = directionsURL {
                Link(destination: url) {
                    HStack(spacing: 16) {
                        Text("Check on Google Maps")
                            .font(.system(size: 16, weight: .regular))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .medium))
                    }
                    .foregroundStyle(.black)
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.white)
                            // CSS blur 4px corresponds to a 2pt shadow radius.
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 0)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(hex: 0xE5E7EB), lineWidth: 1)
                    }
                }
                .accessibilityLabel("Open directions to \(market.name) in Google Maps")
            }
        }
    }

    private var directionsURL: URL? {
        var components = URLComponents(string: "https://www.google.com/maps/search/")
        components?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: "\(market.name), \(market.address ?? "Bengaluru, Karnataka")")
        ]
        return components?.url
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.black)
    }

    private func marketFact(symbol: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .frame(width: 24, height: 24)
            Text(text)
                .font(.system(size: 16, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var crowdSummary: some View {
        HStack(spacing: 24) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 24, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Less right now")
                    .font(.system(size: 18, weight: .semibold))
                Text("Compare to usual")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: 0x808080))
            }

            Spacer()
        }
        .foregroundStyle(Color(hex: 0x156014))
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(Color(hex: 0xE6FAED), in: RoundedRectangle(cornerRadius: 24))
    }

    private var crowdChart: some View {
        VStack(spacing: 16) {
            HStack(spacing: 4) {
                LiveCrowdIndicator()
                Text("Live - less than usual")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(crowdValues.enumerated()), id: \.offset) { index, value in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index == 3 ? Color(hex: 0xEF4444) : Color(hex: 0xE4EDFF))
                            .frame(width: 12, height: 112 * value + 8)
                            .frame(maxWidth: .infinity, alignment: .bottom)
                    }
                }
                .frame(height: 88, alignment: .bottom)
                .overlay(alignment: .bottom) {
                    GeometryReader { geometry in
                        Path { path in
                            path.move(to: .zero)
                            path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                        }
                        .stroke(Color(hex: 0x808080), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .frame(height: 1)
                }

                HStack(spacing: 4) {
                    ForEach(hours, id: \.self) { hour in
                        Text(hour)
                            .font(.system(size: 8, weight: .regular))
                            .foregroundStyle(Color(hex: 0x475569))
                            .frame(maxWidth: .infinity)
                    }
                }
            }

        }
    }

    private func detailAction(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 48, height: 48)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
