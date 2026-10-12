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
    @StateObject private var openingHours = MarketOpeningHoursStore()
    @Environment(\.scenePhase) private var scenePhase

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
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await openingHours.refresh(markets: nearbyMarkets.map { ($0.id, $0.name) })
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    return
                }
            }
        }
        .refreshable {
            await openingHours.refresh(markets: nearbyMarkets.map { ($0.id, $0.name) }, force: true)
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

                NavigationLink {
                    MarketNotificationsView()
                } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Notifications")
                .accessibilityHint("Opens notifications")

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
                                NearbyMarketCard(
                                    market: market,
                                    openingStatus: openingHours.statuses[market.id]
                                )
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
    let openingStatus: MarketOpeningStatus?

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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(openingStatus?.label ?? "Checking hours…")
                    .foregroundStyle(
                        openingStatus?.isOpen == true ? Color(hex: 0x156014)
                        : openingStatus?.isOpen == false ? Color(hex: 0xDD0405)
                        : AppColors.secondaryText
                    )
                    .font(.system(size: 12, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
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

            NavigationLink {
                MarketSearchView(presentsAlertSetup: true)
            } label: {
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
            .buttonStyle(.plain)

        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xEFF6FF), in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .contain)
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
            distance: distance
        )
    }
}

private extension PopularMarket {
    var detail: MarketSearchResult {
        MarketSearchResult(
            name: name,
            imageName: imageName,
            distance: "5kms"
        )
    }
}

private struct MarketSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    @State private var searchText = ""
    @State private var selectedMarket: MarketSearchResult?
    @State private var alertMarket: MarketSearchResult?

    var presentsAlertSetup = false

    private let markets = [
        MarketSearchResult(
            name: "Raja Market",
            imageName: "PopularRajaMarket",
            distance: "5kms"
        ),
        MarketSearchResult(
            name: "KR Market",
            imageName: "PopularKRMarket",
            distance: "5kms"
        ),
        MarketSearchResult(
            name: "Chickpet Market",
            imageName: "PopularChickpetMarket",
            distance: "5kms"
        ),
        MarketSearchResult(
            name: "Russell Market",
            imageName: "RussellMarket",
            distance: "1km"
        ),
        MarketSearchResult(
            name: "Jayanagar Market",
            imageName: "JayanagarMarket",
            distance: "1.5km"
        ),
        MarketSearchResult(
            name: "Sunday Market",
            imageName: "SundayMarket",
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
                            if presentsAlertSetup {
                                alertMarket = market
                            } else {
                                selectedMarket = market
                            }
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
        .sheet(item: $alertMarket) { market in
            MarketAlertSheet(market: market)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSearchFocused = true
            }
        }
    }
}

private struct MarketSearchResultRow: View {
    @ObservedObject private var addresses = MarketAddressStore.shared
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

                    Text(addresses.label(for: market.name))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: 0x808080))
                        .fixedSize(horizontal: false, vertical: true)
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
        .task(id: market.id) {
            await addresses.load(marketName: market.name)
        }
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
    @ObservedObject private var addresses = MarketAddressStore.shared
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
        .task(id: market.id) {
            await addresses.load(marketName: market.name)
        }
        .sheet(isPresented: $showsAlertNotice) {
            MarketAlertSheet(market: market)
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

                    HStack(alignment: .top, spacing: 2) {
                        Image("LocationOn")
                            .resizable()
                            .frame(width: 16, height: 16)
                            .accessibilityHidden(true)
                        Text(addresses.label(for: market.name))
                            .font(.system(size: 12, weight: .medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(AppColors.secondaryText)
                }

                Text("\(market.distance) from your location")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
                            .font(.system(size: 16, weight: .medium))
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
            URLQueryItem(name: "query", value: "\(market.name), \(addresses.address(for: market.name) ?? "Bengaluru, Karnataka")"),
            URLQueryItem(name: "query_place_id", value: GoogleMarketAddresses.placeIDs[market.name])
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

private struct MarketNotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var alerts: [MarketAlertWindow] = []
    @State private var showsClearConfirmation = false
    @AppStorage("clearedMarketNotifications") private var clearedNotifications = Data()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ZStack {
                Text("Notifications")
                    .font(.system(size: 20, weight: .semibold))
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 24, weight: .medium))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                    Spacer()
                }
            }
            .padding(.horizontal, 16)

            if alerts.isEmpty {
                GeometryReader { geometry in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            EmptyNotificationsIllustration()
                                .padding(.bottom, 24)
                            Text("No Notifications")
                                .font(.system(size: 32, weight: .semibold))
                            Text("You haven’t received any\nnotifications yet.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, max(40, geometry.size.height * 0.2))
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                Button("Clear notifications") {
                    showsClearConfirmation = true
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.primary)
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 16)

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(alerts, id: \.marketName) { alert in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(AppColors.primary)
                                    .frame(width: 48, height: 48)
                                    .background(Color(hex: 0xE4EDFF), in: RoundedRectangle(cornerRadius: 16))
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Alert set for \(alert.marketName)")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("\(formattedTime(alert.fromMinutes)) – \(formattedTime(alert.toMinutes))")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("Notification window saved")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppColors.secondaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: 0xE5E7EB), lineWidth: 1)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .foregroundStyle(.black)
        .padding(.top, 8)
        .background(.white)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            let cleared = Set((try? JSONDecoder().decode([String].self, from: clearedNotifications)) ?? [])
            alerts = MarketAlertWindow.allSaved().reversed().filter { !cleared.contains($0.notificationID) }
        }
        .alert("Clear notifications?", isPresented: $showsClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear notifications", role: .destructive) {
                var cleared = Set((try? JSONDecoder().decode([String].self, from: clearedNotifications)) ?? [])
                cleared.formUnion(alerts.map(\.notificationID))
                if let data = try? JSONEncoder().encode(Array(cleared)) {
                    clearedNotifications = data
                    alerts = []
                }
            }
        } message: {
            Text("This will clear all notifications from this list. Your saved market alert times will stay unchanged.")
        }
    }

    private func formattedTime(_ minutes: Int) -> String {
        let hours = (minutes / 60) % 12
        return String(format: "%d:%02d %@", hours == 0 ? 12 : hours, minutes % 60, minutes < 720 ? "AM" : "PM")
    }
}

private struct EmptyNotificationsIllustration: View {
    private let accents: [CGPoint] = [
        CGPoint(x: -88, y: -72), CGPoint(x: 124, y: -80),
        CGPoint(x: -140, y: -32), CGPoint(x: 100, y: -32),
        CGPoint(x: -104, y: 16), CGPoint(x: 80, y: 48),
        CGPoint(x: -136, y: 60), CGPoint(x: -88, y: 84),
        CGPoint(x: 24, y: 84)
    ]

    var body: some View {
        ZStack {
            ForEach(accents.indices, id: \.self) { index in
                Image(systemName: "plus")
                    .font(.system(size: index % 3 == 0 ? 16 : 12, weight: .ultraLight))
                    .foregroundStyle(index == 8 ? AppColors.primary.opacity(0.6) : AppColors.secondaryText)
                    .offset(x: accents[index].x, y: accents[index].y)
            }
            Image(systemName: "bell.fill")
                .font(.system(size: 132, weight: .regular))
                .rotationEffect(.degrees(32))
                .foregroundStyle(AppColors.primary)
            Capsule()
                .fill(.white)
                .frame(width: 6, height: 20)
                .rotationEffect(.degrees(-16))
                .offset(x: 36, y: -28)
        }
        .frame(width: 304, height: 200)
        .accessibilityHidden(true)
    }
}

private struct MarketAlertWindow: Codable {
    let marketName: String
    let fromMinutes: Int
    let toMinutes: Int
    var savedAt: Date? = Date()

    var notificationID: String {
        "\(marketName)|\(fromMinutes)|\(toMinutes)|\(savedAt?.timeIntervalSince1970 ?? 0)"
    }

    func save() {
        let key = "marketAlertWindows"
        let existing = UserDefaults.standard.data(forKey: key)
        var windows = existing.flatMap { try? JSONDecoder().decode([Self].self, from: $0) } ?? []
        windows.removeAll { $0.marketName == marketName }
        windows.append(self)
        if let data = try? JSONEncoder().encode(windows) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func allSaved() -> [Self] {
        guard let data = UserDefaults.standard.data(forKey: "marketAlertWindows"),
              let windows = try? JSONDecoder().decode([Self].self, from: data) else { return [] }
        return windows
    }

    static func saved(for marketName: String) -> Self? {
        allSaved().first { $0.marketName == marketName }
    }
}

private struct MarketAlertSheet: View {
    @Environment(\.dismiss) private var dismiss
    let market: MarketSearchResult
    @State private var fromMinutes = 130
    @State private var toMinutes = 790
    @State private var isSaved = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                Group {
                    if isSaved {
                        successContent
                    } else {
                        setupContent
                    }
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(.white)
        .presentationDetents([.height(600)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .onAppear {
            if let saved = MarketAlertWindow.saved(for: market.name) {
                fromMinutes = saved.fromMinutes
                toMinutes = saved.toMinutes
            }
        }
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Set Notification for\n\(market.name)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 40)

            VStack(alignment: .leading, spacing: 12) {
                Text("From")
                    .font(.system(size: 16, weight: .semibold))
                MarketTimeWheel(minutesSinceMidnight: $fromMinutes, label: "From")
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("To")
                    .font(.system(size: 16, weight: .semibold))
                MarketTimeWheel(minutesSinceMidnight: $toMinutes, label: "To")
            }
            Spacer(minLength: 8)
            actionButton("Set Alert") {
                MarketAlertWindow(marketName: market.name, fromMinutes: fromMinutes, toMinutes: toMinutes).save()
                isSaved = true
            }
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(AppColors.primary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close notification setup")
            .padding(.top, 12)
            .padding(.trailing, 20)
        }
    }

    private var successContent: some View {
        VStack(spacing: 0) {
            ZStack {
                Image(systemName: "sparkle")
                    .font(.system(size: 32)).foregroundStyle(AppColors.primary.opacity(0.4))
                    .offset(x: -48, y: -136)
                Image(systemName: "sparkle")
                    .font(.system(size: 20)).foregroundStyle(AppColors.primary)
                    .offset(x: 112, y: -96)
                Image(systemName: "sparkle")
                    .font(.system(size: 20)).foregroundStyle(AppColors.primary)
                    .offset(x: -96, y: -64)
                Image(systemName: "sparkle")
                    .font(.system(size: 32)).foregroundStyle(AppColors.primary.opacity(0.4))
                    .offset(x: 120, y: -16)
                Circle().fill(AppColors.primary.opacity(0.3))
                    .frame(width: 12, height: 12).offset(x: 40, y: -80)
                Circle().fill(AppColors.primary.opacity(0.3))
                    .frame(width: 12, height: 12).offset(x: -128, y: -16)
                Image(systemName: "checkmark")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 104, height: 104)
                    .background(AppColors.primary, in: Circle())
            }
            .frame(height: 208, alignment: .bottom)
            .accessibilityHidden(true)

            Text("Alert Set")
                .font(.system(size: 24, weight: .semibold))
                .padding(.top, 32)
            Text("Your notification window for \(market.name) has been saved.")
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            Spacer(minLength: 32)
            actionButton("Done") { dismiss() }
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppColors.primary, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct MarketTimeWheel: View {
    @Binding var minutesSinceMidnight: Int
    let label: String

    private var hour: Binding<Int> {
        Binding(get: {
            let value = (minutesSinceMidnight / 60) % 12
            return value == 0 ? 12 : value
        }, set: { value in
            minutesSinceMidnight = (minutesSinceMidnight / 720) * 720 + (value % 12) * 60 + minutesSinceMidnight % 60
        })
    }

    private var minute: Binding<Int> {
        Binding(get: { minutesSinceMidnight % 60 }, set: { value in
            minutesSinceMidnight = (minutesSinceMidnight / 60) * 60 + value
        })
    }

    private var period: Binding<Int> {
        Binding(get: { minutesSinceMidnight / 720 }, set: { value in
            minutesSinceMidnight = value * 720 + minutesSinceMidnight % 720
        })
    }

    var body: some View {
        HStack(spacing: 20) {
            MarketTimeColumn(
                values: Array(1...12), selection: hour, label: "\(label) hour",
                display: { String(format: "%02d", $0) }
            )
            MarketTimeColumn(
                values: Array(0..<60), selection: minute, label: "\(label) minute",
                display: { String(format: "%02d", $0) }
            )
            MarketTimeColumn(
                values: [0, 1], selection: period, label: "\(label) AM or PM",
                display: { $0 == 0 ? "AM" : "PM" }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0xE4EDFF))
                Capsule().fill(AppColors.primary)
                    .frame(width: 212, height: 44)
            }
        }
        .clipped()
    }
}

/// Snapping wheel without the native picker's gray selection overlays or fading text.
private struct MarketTimeColumn: View {
    let values: [Int]
    @Binding var selection: Int
    let label: String
    let display: (Int) -> String
    @State private var scrollID: Int?

    init(values: [Int], selection: Binding<Int>, label: String, display: @escaping (Int) -> String) {
        self.values = values
        self._selection = selection
        self.label = label
        self.display = display
        self._scrollID = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(values, id: \.self) { value in
                        Text(display(value))
                            .font(.system(size: 18, weight: value == selection ? .bold : .regular))
                            .foregroundStyle(value == selection ? Color.white : Color.black)
                            .monospacedDigit()
                            .frame(width: 44, height: 40)
                            .id(value)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.vertical, 40, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $scrollID, anchor: .center)
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
            .onChange(of: scrollID) { _, value in
                if let value, values.contains(value), selection != value {
                    selection = value
                }
            }
            .onChange(of: selection) { _, value in
                if scrollID != value {
                    scrollID = value
                    proxy.scrollTo(value, anchor: .center)
                }
            }
        }
        .frame(width: 44, height: 120)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(display(selection))
        .accessibilityAdjustableAction { direction in
            guard let index = values.firstIndex(of: selection) else { return }
            switch direction {
            case .increment: selection = values[min(index + 1, values.count - 1)]
            case .decrement: selection = values[max(index - 1, 0)]
            @unknown default: break
            }
        }
    }
}
