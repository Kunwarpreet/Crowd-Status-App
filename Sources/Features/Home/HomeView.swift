import SwiftUI
import Charts

private struct NearbyMarket: Identifiable {
    let id: String
    let name: String
    let imageName: String
    let crowdLevel: CrowdLevel
    let distance: String
    var livePlace: GoogleMarketPlace? = nil
}

private struct PopularMarket: Identifiable {
    let id: String
    let name: String
    let imageName: String
    var livePlace: GoogleMarketPlace? = nil
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
    @State private var isStartingHome = true
    @AppStorage("marketAlertWindows") private var savedAlertWindows = Data()
    @AppStorage("lowCrowdNotificationConfirmations") private var savedLowCrowdNotifications = Data()
    @AppStorage("seenMarketNotifications") private var seenNotifications = Data()
    @AppStorage("clearedMarketNotifications") private var clearedNotifications = Data()
    @ObservedObject private var cityStore = MarketCityStore.shared
    @ObservedObject private var details = MarketDetailsStore.shared
    @StateObject private var homeMarkets = HomeMarketStore.shared
    @ObservedObject private var journeys = MarketJourneyStore.shared
    @Environment(\.scenePhase) private var scenePhase

    private var hasUnreadNotifications: Bool {
        let alerts = (try? JSONDecoder().decode([MarketAlertWindow].self, from: savedAlertWindows)) ?? []
        let lowCrowd = (try? JSONDecoder().decode([LowCrowdNotification].self, from: savedLowCrowdNotifications)) ?? []
        return !MarketNotificationReadState.unreadIDs(
            notificationIDs: alerts.map(\.notificationID) + lowCrowd.map(\.notificationID),
            seen: seenNotifications, cleared: clearedNotifications
        ).isEmpty
    }

    private var locationID: String {
        "\(cityStore.hasResolvedCity)|\(cityStore.city)|\(cityStore.location?.coordinate.latitude ?? 0)|\(cityStore.location?.coordinate.longitude ?? 0)"
    }
    private var nearbyMarkets: [NearbyMarket] {
        homeMarkets.nearby.filter { details.isAvailableForHome(placeID: $0.id) }.map { candidate in
            let place = details.places[candidate.id] ?? candidate
            let percent = MarketCrowdData.demo(marketID: place.id, timeZoneID: details.statuses[place.id]?.timeZoneID ?? TimeZone.current.identifier).currentPercent
            return NearbyMarket(id: place.id, name: place.name, imageName: "", crowdLevel: percent < 35 ? .low : percent < 65 ? .medium : .high, distance: journeys.distanceLabel(for: place, from: cityStore.location) ?? "", livePlace: place)
        }
    }
    private var popularMarkets: [PopularMarket] {
        homeMarkets.popular.filter { details.isAvailableForHome(placeID: $0.id) }.map { PopularMarket(id: $0.id, name: $0.name, imageName: "", livePlace: $0) }
    }
    private var isDiscoveringMarkets: Bool {
        isStartingHome || homeMarkets.isLoading || cityStore.isLocating
    }
    private func refreshMarkets(force: Bool = false) async {
        await homeMarkets.refresh(city: cityStore.city, location: cityStore.location, hasResolvedCity: cityStore.hasResolvedCity, force: force)
    }

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
        .onAppear {
            cityStore.startTracking()
            _ = LowCrowdNotification.allSaved()
        }
        .onDisappear { cityStore.stopTracking() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { cityStore.startTracking() } else { cityStore.stopTracking() }
        }
        .task(id: "\(scenePhase)|\(locationID)|\(homeMarkets.nearby.map(\.id))") {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await journeys.refresh(places: homeMarkets.nearby, location: cityStore.location)
                do { try await Task.sleep(for: .seconds(300)) } catch { return }
            }
        }
        .task(id: locationID) {
            await refreshMarkets()
            isStartingHome = false
        }
        .task(id: "\(scenePhase)|\(homeMarkets.nearby.map(\.id))|\(homeMarkets.popular.map(\.id))") {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                for place in GoogleMarketDiscovery.merging(homeMarkets.nearby, homeMarkets.popular) {
                    await details.load(placeID: place.id)
                }
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
        .refreshable {
            cityStore.detectCity()
            await refreshMarkets(force: true)
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.large) {
            HStack(spacing: 8) {
                NavigationLink { MarketSearchView() } label: {
                  HStack(spacing: 2) {
                    Image("LocationPin")
                        .resizable()
                        .frame(width: 24, height: 24)

                    Text(cityStore.isLocating ? "Finding your location…" : cityStore.hasResolvedCity ? cityStore.homeLocationLabel : "Choose your location")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                  }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                NavigationLink {
                    MarketNotificationsView()
                } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .overlay(alignment: .topTrailing) {
                            if hasUnreadNotifications {
                                Circle()
                                    .fill(AppColors.primary)
                                    .frame(width: 8, height: 8)
                                    .overlay { Circle().stroke(.white, lineWidth: 2) }
                                    .padding(.top, 7)
                                    .padding(.trailing, 8)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Notifications")
                .accessibilityValue(hasUnreadNotifications ? "Unread notifications" : "No unread notifications")
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
                    sectionHeading("Nearby", subtitle: "Markets closest to you · Within 8 km")
                    if isDiscoveringMarkets && nearbyMarkets.isEmpty {
                        VStack(spacing: 20) {
                            ForEach(0..<2) { _ in NearbyMarketSkeleton() }
                        }
                        .modifier(MarketSkeletonShimmer())
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Loading nearby markets")
                    }
                    if !isDiscoveringMarkets, let error = homeMarkets.errorMessage { Text(error).font(.footnote).foregroundStyle(.secondary) }
                    if !isDiscoveringMarkets && nearbyMarkets.isEmpty && homeMarkets.errorMessage == nil {
                        Text(cityStore.location == nil ? "Enable location to find nearby markets, or tap your location above to choose a city." : "No nearby markets found within 8 km.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    VStack(spacing: 20) {
                        ForEach(nearbyMarkets) { market in
                            Button {
                                selectedMarket = market.detail
                            } label: {
                                NearbyMarketCard(
                                    market: market,
                                    openingStatus: details.statuses[market.id]
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
                sectionHeading("Popular", subtitle: cityStore.hasResolvedCity ? "Most reviewed markets in \(cityStore.cityName)" : "Choose your location to discover popular markets")
                if !isDiscoveringMarkets && cityStore.hasResolvedCity && popularMarkets.isEmpty && homeMarkets.errorMessage == nil {
                    Text("No popular markets found. Try another city.").font(.footnote).foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        if isDiscoveringMarkets && popularMarkets.isEmpty {
                            HStack(spacing: 16) {
                                ForEach(0..<3) { _ in PopularMarketSkeleton() }
                            }
                            .modifier(MarketSkeletonShimmer())
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Loading popular markets")
                        }
                        ForEach(popularMarkets) { market in
                            Button {
                                selectedMarket = market.detail
                            } label: {
                                PopularMarketCard(market: market, openingStatus: details.statuses[market.id])
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

private struct SkeletonBlock: View {
    var width: CGFloat? = nil
    let height: CGFloat
    var cornerRadius: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(hex: 0xE9EDF3))
            .frame(width: width, height: height)
    }
}

private struct NearbyMarketSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonBlock(width: 72, height: 72, cornerRadius: 8)
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(height: 16)
                SkeletonBlock(width: 88, height: 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 10) {
                SkeletonBlock(width: 54, height: 26, cornerRadius: 13)
                SkeletonBlock(width: 38, height: 10)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: 0xF2F2F7), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct PopularMarketSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonBlock(width: 131, height: 76, cornerRadius: 0)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 100, height: 12)
                SkeletonBlock(width: 76, height: 10)
            }
            .padding(8)
        }
        .frame(width: 131, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: 0xF2F2F7), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct MarketSkeletonShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var startedAt = Date()

    func body(content: Content) -> some View {
        Group {
            if reduceMotion {
                content
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { timeline in
                    // A local clock restarts the pulse and sweep for each loading appearance.
                    let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
                    let progress = elapsed.truncatingRemainder(dividingBy: 1.4) / 1.4
                    let opacity = 0.85 + 0.15 * cos(elapsed * .pi * 2 / 1.4)
                    content
                        .opacity(opacity)
                        .overlay {
                            GeometryReader { geometry in
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.9), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: geometry.size.width * 0.55)
                                .offset(x: geometry.size.width * (progress * 1.55 - 0.55))
                            }
                            .mask(content)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                        }
                }
            }
        }
        .onAppear { startedAt = Date() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { startedAt = Date() }
        }
    }
}

private struct NearbyMarketCard: View {
    let market: NearbyMarket
    let openingStatus: MarketOpeningStatus?

    private var openingLabel: AttributedString {
        var label = AttributedString(openingStatus?.label ?? "Checking hours…")
        label.foregroundColor = AppColors.secondaryText
        let statusEnd = label.range(of: " · ")?.lowerBound ?? label.endIndex
        label[label.startIndex..<statusEnd].foregroundColor =
            openingStatus?.isOpen == true ? Color(hex: 0x156014)
            : openingStatus?.isOpen == false ? Color(hex: 0xDD0405)
            : AppColors.secondaryText
        return label
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let photo = market.livePlace?.photos?.first { GoogleMarketPhotoView(photo: photo, compact: true, showsAuthorAttributions: false) }
                else { ZStack { Color(.systemGray6); Image(systemName: "storefront").foregroundStyle(.secondary) } }
            }
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

                Text(openingLabel)
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
    @ObservedObject private var details = MarketDetailsStore.shared
    let market: PopularMarket
    let openingStatus: MarketOpeningStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if market.imageName.isEmpty {
                    if let photo = (details.places[market.detail.id] ?? market.livePlace)?.photos?.first {
                        GoogleMarketPhotoView(photo: photo, compact: true, showsAuthorAttributions: false)
                    } else {
                        ZStack {
                            Color(.systemGray6)
                            Image(systemName: "storefront").foregroundStyle(.secondary)
                        }
                    }
                } else { Image(market.imageName).resizable().scaledToFill() }
            }
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
                        Text(openingStatus.map { status in
                            status.isOpen.map { $0 ? "Open" : "Closed" } ?? "Hours unavailable"
                        } ?? "Checking hours…")
                            .foregroundStyle(AppColors.secondaryText)
                            .accessibilityLabel(openingStatus?.label ?? "Checking hours…")
                        Circle()
                            .fill(AppColors.secondaryText)
                            .frame(width: 2, height: 2)
                        Text((details.places[market.detail.id] ?? market.livePlace)?.rating.map { String(format: "%.1f", $0) } ?? "—")
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
        .task {
            if let placeID = market.detail.resolvedPlaceID { await details.load(placeID: placeID) }
        }
    }
}

#Preview {
    HomeView()
}

struct MarketSearchResult: Identifiable, Hashable {
    let name: String
    let imageName: String
    let distance: String

    var livePlace: GoogleMarketPlace? = nil
    var resolvedPlaceID: String? { livePlace?.id ?? GoogleMarketHours.placeIDs[name] }
    var id: String { resolvedPlaceID ?? name }
}

private extension NearbyMarket {
    var detail: MarketSearchResult {
        MarketSearchResult(
            name: name,
            imageName: imageName,
            distance: distance,
            livePlace: livePlace
        )
    }
}

private extension PopularMarket {
    var detail: MarketSearchResult {
        MarketSearchResult(
            name: name,
            imageName: imageName,
            distance: "",
            livePlace: livePlace
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

    @ObservedObject private var cityStore = MarketCityStore.shared
    @StateObject private var search = MarketSearchStore()
    @State private var cityText = ""

    private var searchID: String { "\(cityStore.city)|\(searchText)" }

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

                    TextField("Search markets", text: $searchText)
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

            TextField("City, country", text: $cityText)
                .font(.system(size: 14))
                .submitLabel(.search)
                .onSubmit { cityStore.useCity(cityText) }
                .accessibilityLabel("City to search")
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            if let message = cityStore.locationMessage {
                Text(message).font(.system(size: 12)).foregroundStyle(AppColors.secondaryText)
                    .padding(.horizontal, 20)
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(search.markets) { place in
                        let market = MarketSearchResult(name: place.name, imageName: "", distance: place.distance(from: cityStore.location) ?? "", livePlace: place)
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
                    if search.isLoading {
                        ProgressView("Loading markets…")
                    } else if let message = search.errorMessage {
                        Text(message).font(.system(size: 14)).foregroundStyle(AppColors.secondaryText)
                        Button("Try again") {
                            Task {
                                if search.nextPageToken != nil { await search.loadMore() }
                                else { await search.search(city: cityStore.city, query: searchText) }
                            }
                        }
                    } else if search.markets.isEmpty {
                        Text("No markets found. Try a different name or city.")
                            .font(.system(size: 14)).foregroundStyle(AppColors.secondaryText)
                    }
                    if search.nextPageToken != nil && !search.isLoading {
                        Button("Load more markets") { Task { await search.loadMore() } }
                            .font(.system(size: 14, weight: .semibold))
                    }
                    if !search.markets.isEmpty {
                        Text("Market listings from Google Maps")
                            .font(.system(size: 12)).foregroundStyle(AppColors.secondaryText)
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
            cityText = cityStore.city
            cityStore.detectCity(automatically: true)
        }
        .onChange(of: cityStore.city) { _, city in cityText = city }
        .task(id: searchID) {
            await search.search(city: cityStore.city, query: searchText)
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

                    Text(market.livePlace?.formattedAddress ?? addresses.label(for: market.name))
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
            if market.livePlace == nil { await addresses.load(marketName: market.name) }
        }
    }
}

private struct LiveCrowdIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let blinkDuration: TimeInterval = 1.2

    var body: some View {
        if reduceMotion {
            dot
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { context in
                // Derive opacity from time so navigation and foreground transitions
                // cannot leave a repeating animation stuck in its initial phase.
                let progress = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: blinkDuration) / blinkDuration
                let opacity = 0.15 + 0.85 * (1 + cos(progress * 2 * .pi)) / 2
                dot.opacity(opacity)
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
    @ObservedObject private var details = MarketDetailsStore.shared
    @ObservedObject private var journeys = MarketJourneyStore.shared
    @ObservedObject private var cityStore = MarketCityStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("lowCrowdNotificationMarkets") private var notificationMarkets = Data()
    @State private var showsOpeningHours = false
    @State private var selectedPhotoIndex = 0
    @State private var crowdScrollPosition: Double = 0
    @State private var crowdScrollDragStart: Double?
    @State private var showsAlertNotice = false
    @State private var showsNotificationConfirmation = false
    @State private var isRemovingNotification = false
    @State private var showsNotificationSet = false
    @State private var notificationToastID: UUID?

    let market: MarketSearchResult

    private var place: GoogleMarketPlace? { details.places[market.id] ?? market.livePlace }
    private var marketDescription: MarketDescription? {
        MarketDescriptions.description(
            placeID: market.resolvedPlaceID,
            name: place?.name ?? market.name,
            address: place?.formattedAddress,
            editorialSummary: place?.editorialSummary?.text,
            types: place?.types ?? [],
            primaryTypeDisplayName: place?.primaryTypeDisplayName?.text
        )
    }
    private var marketPhotos: [GoogleMarketPlace.Photo] { Array((place?.photos ?? []).prefix(4)) }
    private var addressLabel: String {
        place?.formattedAddress ?? (details.failures.contains(market.id) ? "Address unavailable" : "Loading address…")
    }
    private var distanceLabel: String? {
        place.flatMap { journeys.distanceLabel(for: $0, from: cityStore.location) }
    }
    private var journeyContextID: String {
        "\(scenePhase)|\(market.id)|\(cityStore.location?.coordinate.latitude ?? 0)|\(cityStore.location?.coordinate.longitude ?? 0)|\(place?.location?.latitude ?? 0)|\(place?.location?.longitude ?? 0)"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroImage
                    marketInformation
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            cityStore.startTracking(owner: "detail")
            defer { cityStore.stopTracking(owner: "detail") }
            while !Task.isCancelled {
                if let placeID = market.resolvedPlaceID { await details.load(placeID: placeID) }
                do { try await Task.sleep(for: .seconds(30)) }
                catch { return }
            }
        }
        .task(id: journeyContextID) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                if let place { await journeys.refresh(places: [place], location: cityStore.location) }
                do { try await Task.sleep(for: .seconds(300)) }
                catch { return }
            }
        }
        .sheet(isPresented: $showsAlertNotice) {
            MarketAlertSheet(market: market)
        }
        .alert(
            isRemovingNotification
                ? "Do you want to remove this alert notification"
                : "Do you want to get notified everytime when there is low crowd.",
            isPresented: $showsNotificationConfirmation
        ) {
            if isRemovingNotification {
                Button("Yes, Remove", role: .destructive) {
                    removeLowCrowdNotifications()
                }
                Button("Keep", role: .cancel) {}
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Notified") {
                    enableLowCrowdNotifications()
                }
                .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) {}
            }
        }
        .task(id: notificationToastID) {
            guard notificationToastID != nil else { return }
            do {
                // Wait for the native alert to dismiss before starting the visible timer.
                while showsNotificationConfirmation {
                    try await Task.sleep(for: .milliseconds(50))
                }
                try await Task.sleep(for: .milliseconds(350))
                withAnimation(reduceMotion ? .easeIn(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.8)) {
                    showsNotificationSet = true
                }
                try await Task.sleep(for: .milliseconds(3500))
            } catch {
                return
            }
            withAnimation(.easeOut(duration: 0.2)) {
                showsNotificationSet = false
            }
        }
        .onDisappear {
            showsNotificationSet = false
            notificationToastID = nil
        }
    }

    private var notificationSetToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: 0x00C853))
                .accessibilityHidden(true)
            Text("Notification Set")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notification Set")
    }

    private var legacyNotificationNames: [String] {
        GoogleMarketHours.placeIDs.compactMap { name, placeID in
            placeID == market.resolvedPlaceID ? name : nil
        }
    }

    private func enableLowCrowdNotifications() {
        LowCrowdNotification.save(for: market.name, placeID: market.resolvedPlaceID, legacyMarketNames: legacyNotificationNames)
        var saved = Set((try? JSONDecoder().decode([String].self, from: notificationMarkets)) ?? [])
        saved.subtract(legacyNotificationNames)
        saved.remove(market.name)
        saved.insert(market.id)
        if let data = try? JSONEncoder().encode(saved.sorted()) {
            notificationMarkets = data
        }
        showsNotificationConfirmation = false
        showsNotificationSet = false
        notificationToastID = UUID()
    }

    private var lowCrowdNotificationsEnabled: Bool {
        let saved = (try? JSONDecoder().decode([String].self, from: notificationMarkets)) ?? []
        return saved.contains(market.id) || !Set(saved).isDisjoint(with: legacyNotificationNames)
    }

    private func removeLowCrowdNotifications() {
        LowCrowdNotification.remove(for: market.name, placeID: market.resolvedPlaceID, legacyMarketNames: legacyNotificationNames)
        notificationMarkets = UserDefaults.standard.data(forKey: "lowCrowdNotificationMarkets") ?? Data()
        showsNotificationSet = false
        notificationToastID = nil
    }

    private var notificationButtonIcon: some View {
        Group {
            if lowCrowdNotificationsEnabled {
                Image(systemName: "bell")
                    .font(.system(size: 22, weight: .medium))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .padding(2)
                            .background(.white, in: Circle())
                            .offset(x: 4, y: -3)
                    }
                    .foregroundStyle(Color(hex: 0x00C853))
                    .frame(width: 24, height: 24)
            } else {
                Image("NotificationAdd")
                    .resizable()
                    .frame(width: 24, height: 24)
            }
        }
        .frame(width: 48, height: 48)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityHidden(true)
    }

    private var heroImage: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedPhotoIndex) {
                if marketPhotos.isEmpty {
                    ZStack {
                        Color(.systemGray6)
                        Image(systemName: "storefront")
                            .font(.system(size: 48)).foregroundStyle(.secondary)
                        Text(details.places[market.id] == nil && !details.failures.contains(market.id) ? "Loading photos…" : "Photos unavailable")
                            .font(.system(size: 12)).foregroundStyle(.secondary).offset(y: 48)
                    }
                    .tag(0)
                } else {
                    ForEach(Array(marketPhotos.enumerated()), id: \.element.id) { index, photo in
                        GoogleMarketPhotoView(photo: photo, showsAuthorAttributions: false)
                            .tag(index)
                            .accessibilityLabel("Market photo \(index + 1) of \(marketPhotos.count)")
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 296)
            .onChange(of: marketPhotos.count) { _, count in
                selectedPhotoIndex = min(selectedPhotoIndex, max(0, count - 1))
            }
            .accessibilityLabel("Photos of \(market.name)")
            .accessibilityValue(marketPhotos.isEmpty ? "Photos unavailable" : "Photo \(selectedPhotoIndex + 1) of \(marketPhotos.count)")

            HStack(spacing: 12) {
                detailAction(symbol: "arrow.left", label: "Back") {
                    dismiss()
                }

                ZStack {
                    if showsNotificationSet {
                        notificationSetToast
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)

                Button {
                    isRemovingNotification = lowCrowdNotificationsEnabled
                    showsNotificationConfirmation = true
                } label: {
                    notificationButtonIcon
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(lowCrowdNotificationsEnabled ? "Remove" : "Enable") low crowd notifications for \(market.name)")
                .accessibilityValue(lowCrowdNotificationsEnabled ? "Enabled" : "Not enabled")
            }
            .padding(.horizontal, 16)
            .padding(.top, 96)

            if marketPhotos.count > 1 {
                HStack(spacing: 4) {
                    ForEach(marketPhotos.indices, id: \.self) { index in
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
                        Text(addressLabel)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .accessibilityLabel(addressLabel)
                    }
                    .foregroundStyle(AppColors.secondaryText)
                }

                if let distance = distanceLabel {
                    Text("\(distance) from your location")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(width: 250, alignment: .leading)

            openingHoursDropdown
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var openingHoursDropdown: some View {
        let status = details.statuses[market.id]
        let title = status.map { $0.isOpen.map { $0 ? "Open" : "Closed" } ?? "Unavailable" } ?? "Checking…"
        return Button {
            showsOpeningHours.toggle()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(status?.isOpen == true ? Color(hex: 0x156014) : AppColors.secondaryText)
                    .lineLimit(1)
                Image(systemName: showsOpeningHours ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.secondaryText)
            }
            .frame(minWidth: 76, maxWidth: 100, minHeight: 44)
            .background(.white, in: Capsule())
            .overlay { Capsule().stroke(Color(hex: 0xF2F2F7), lineWidth: 1) }
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). Opening hours")
        .accessibilityHint("Shows all weekdays and their opening and closing times")
        .accessibilityValue(showsOpeningHours ? "Expanded" : "Collapsed")
        .popover(isPresented: $showsOpeningHours, arrowEdge: .top) {
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                ForEach((status ?? .unavailable).weeklyHours()) { row in
                    GridRow(alignment: .top) {
                        Text(row.day)
                        Text(row.hours)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 16, weight: row.isToday ? .bold : .regular))
                    .foregroundStyle(row.isToday ? AppColors.primaryText : AppColors.secondaryText)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(row.isToday ? "Today, " : "")\(row.day), \(row.hours)")
                }
            }
            .fixedSize(horizontal: true, vertical: true)
            .padding(20)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var todaysCrowd: some View {
        TimelineView(.periodic(from: Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970 / 60) * 60), by: 60)) { context in
            let status = details.statuses[market.id]
            let intervals = status?.todayOpenIntervals(at: context.date)
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    sectionHeading("Today’s crowd")
                    Spacer()
                    Text("Demo data")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: 0xF3F3F6), in: Capsule())
                }
                if let intervals {
                    if intervals.isEmpty {
                        Text("Closed today")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                    } else {
                        let snapshot = MarketCrowdData.demo(
                            marketID: market.id,
                            timeZoneID: status?.timeZoneID ?? "Asia/Kolkata",
                            now: context.date,
                            openIntervals: intervals
                        )
                        crowdSummary(snapshot)
                        if snapshot.visibleSamples.isEmpty {
                            Text("Crowd graph starts when the market opens today.")
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.secondaryText)
                        } else {
                            VStack(spacing: 12) {
                                crowdChart(snapshot)
                                Text("Simulated data · refreshes every 10 minutes")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppColors.secondaryText)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                } else {
                    Text(status == nil ? "Checking opening hours…" : "Opening hours unavailable")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.secondaryText)
                }
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
            if let description = marketDescription {
                Text(description.text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.black)
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: description.sourceURL) {
                    Label("Source: \(description.sourceName)", systemImage: "arrow.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .frame(minHeight: 44, alignment: .leading)
                }
                .tint(AppColors.primary)
                .accessibilityHint("Opens the source for this market description")
            } else {
                Text(market.resolvedPlaceID != nil && details.places[market.id] == nil && !details.failures.contains(market.id)
                     ? "Loading market description…"
                     : "A verified description of what this market is known for isn’t available yet.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
                GridRow {
                    marketFact(symbol: "star.fill", text: place?.rating.map { String(format: "%.1f/5", $0) } ?? "Unrated")
                    if let phoneURL = place?.phoneURL {
                        Link(destination: phoneURL) {
                            marketFact(symbol: "phone", text: "Call")
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Call \(market.name)")
                    } else {
                        marketFact(symbol: "phone", text: "Phone unavailable")
                            .foregroundStyle(AppColors.secondaryText)
                    }
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
                            .font(.system(size: 16))
                            .fontWeight(.medium)
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
            URLQueryItem(name: "query", value: "\(market.name), \(place?.formattedAddress ?? cityStore.city)"),
            URLQueryItem(name: "query_place_id", value: market.resolvedPlaceID)
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
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func crowdSummary(_ snapshot: MarketCrowdSnapshot) -> some View {
        let foreground = !snapshot.isOpenNow ? AppColors.secondaryText : snapshot.currentPercent < 35 ? Color(hex: 0x156014)
            : snapshot.currentPercent < 65 ? Color(hex: 0xA66600) : Color(hex: 0xDD0405)
        let background = !snapshot.isOpenNow ? Color(hex: 0xF3F3F6) : snapshot.currentPercent < 35 ? Color(hex: 0xE6FAED)
            : snapshot.currentPercent < 65 ? Color(hex: 0xFEEFDA) : Color(hex: 0xFCDFE0)
        return HStack(spacing: 24) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 24, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.levelTitle)
                    .font(.system(size: 18, weight: .semibold))
                Text(snapshot.isOpenNow ? "\(snapshot.currentPercent)% simulated crowd level" : "Graph shows today’s opening hours")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer()
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 24))
    }

    private func crowdChart(_ snapshot: MarketCrowdSnapshot) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 4) {
                LiveCrowdIndicator()
                Text(snapshot.isOpenNow ? "Demo · \(MarketCrowdSnapshot.hourLabel(snapshot.currentHour)) highlighted" : "Demo · past opening hours")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)

            Chart(snapshot.visibleSamples) { sample in
                let inset = min(3.0, Double(sample.endMinute - sample.startMinute) * 0.08)
                RectangleMark(
                    xStart: .value("Opening time", Double(sample.startMinute) + inset),
                    xEnd: .value("Closing time", Double(sample.endMinute) - inset),
                    yStart: .value("Baseline", 0),
                    yEnd: .value("Simulated crowd level", sample.percent)
                )
                .cornerRadius(4)
                .foregroundStyle(snapshot.isCurrent(sample) ? Color(hex: 0xEF4444) : Color(hex: 0xC8D9FF))
                .accessibilityLabel("\(MarketCrowdSnapshot.timeLabel(sample.startMinute)) to \(MarketCrowdSnapshot.timeLabel(sample.endMinute))")
                .accessibilityValue("\(sample.percent) percent, simulated")
            }
            .chartXScale(domain: Double(snapshot.samples.first?.startMinute ?? 0)...Double(snapshot.samples.last?.endMinute ?? 60))
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: snapshot.scrollWindow)
            .chartScrollPosition(x: $crowdScrollPosition)
            .onAppear {
                crowdScrollPosition = snapshot.preferredScrollPosition
            }
            .onChange(of: snapshot.visibleSamples.last?.id) { _, _ in
                crowdScrollPosition = snapshot.preferredScrollPosition
            }
            .chartYScale(domain: 0...100)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: snapshot.axisMinutes) { value in
                    AxisValueLabel {
                        if let minute = value.as(Int.self) {
                            Text(MarketCrowdSnapshot.timeLabel(minute))
                                .font(.system(size: 8, weight: .regular))
                                .foregroundStyle(Color(hex: 0x475569))
                        }
                    }
                }
            }
            .frame(height: 112)
            .accessibilityLabel("Today’s simulated hourly crowd for \(market.name)")

            if snapshot.maxScrollPosition > snapshot.scrollStart {
                crowdScrollbar(snapshot)
            }
        }
    }

    private func crowdScrollbar(_ snapshot: MarketCrowdSnapshot) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let thumbWidth = width * snapshot.scrollWindow / (snapshot.scrollEnd - snapshot.scrollStart)
            let travel = max(1, width - thumbWidth)
            let scrollRange = snapshot.maxScrollPosition - snapshot.scrollStart
            let position = min(snapshot.maxScrollPosition, max(snapshot.scrollStart, crowdScrollPosition))
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0xF3F3F6))
                Capsule().fill(Color(hex: 0xD1D5DB))
                    .frame(width: thumbWidth)
                    .offset(x: (position - snapshot.scrollStart) / scrollRange * travel)
            }
            .frame(height: 4)
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if crowdScrollDragStart == nil { crowdScrollDragStart = position }
                        let destination = (crowdScrollDragStart ?? position) + value.translation.width / travel * scrollRange
                        crowdScrollPosition = min(snapshot.maxScrollPosition, max(snapshot.scrollStart, destination))
                    }
                    .onEnded { _ in crowdScrollDragStart = nil }
            )
            .accessibilityElement()
            .accessibilityLabel("Crowd graph scrollbar")
            .accessibilityValue("Showing \(MarketCrowdSnapshot.timeLabel(Int(position))) to \(MarketCrowdSnapshot.timeLabel(Int(position + snapshot.scrollWindow)))")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: crowdScrollPosition = min(snapshot.maxScrollPosition, position + 60)
                case .decrement: crowdScrollPosition = max(snapshot.scrollStart, position - 60)
                @unknown default: break
                }
            }
            .onDisappear { crowdScrollDragStart = nil }
        }
        .frame(height: 20)
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
    @State private var lowCrowdAlerts: [LowCrowdNotification] = []
    @State private var showsClearConfirmation = false
    @AppStorage("clearedMarketNotifications") private var clearedNotifications = Data()
    @AppStorage("seenMarketNotifications") private var seenNotifications = Data()

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

            if alerts.isEmpty && lowCrowdAlerts.isEmpty {
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
                        ForEach(lowCrowdAlerts) { alert in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(AppColors.primary)
                                    .frame(width: 48, height: 48)
                                    .background(Color(hex: 0xE4EDFF), in: RoundedRectangle(cornerRadius: 16))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Notification set for \(alert.marketName)")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Low crowd notification enabled")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("Notification preference saved")
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
                        ForEach(alerts, id: \.notificationID) { alert in
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
            lowCrowdAlerts = LowCrowdNotification.allSaved().reversed().filter { !cleared.contains($0.notificationID) }
            seenNotifications = MarketNotificationReadState.markingSeen(
                notificationIDs: alerts.map(\.notificationID) + lowCrowdAlerts.map(\.notificationID),
                seen: seenNotifications
            )
        }
        .alert("Clear notifications?", isPresented: $showsClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear notifications", role: .destructive) {
                var cleared = Set((try? JSONDecoder().decode([String].self, from: clearedNotifications)) ?? [])
                cleared.formUnion(alerts.map(\.notificationID))
                cleared.formUnion(lowCrowdAlerts.map(\.notificationID))
                if let data = try? JSONEncoder().encode(Array(cleared)) {
                    clearedNotifications = data
                    alerts = []
                    lowCrowdAlerts = []
                }
            }
        } message: {
            Text("This will clear all notifications from this list. Your saved market alert times and low crowd preferences will stay unchanged.")
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
    var placeID: String? = nil
    var savedAt: Date? = Date()

    var notificationID: String {
        "\(placeID ?? marketName)|\(fromMinutes)|\(toMinutes)|\(savedAt?.timeIntervalSince1970 ?? 0)"
    }

    func save() {
        let key = "marketAlertWindows"
        let existing = UserDefaults.standard.data(forKey: key)
        var windows = existing.flatMap { try? JSONDecoder().decode([Self].self, from: $0) } ?? []
        windows.removeAll { record in
            if let placeID {
                return record.placeID == placeID || (record.placeID == nil && record.marketName == marketName)
            }
            return record.placeID == nil && record.marketName == marketName
        }
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

    static func saved(for marketName: String, placeID: String? = nil) -> Self? {
        let windows = allSaved()
        if let placeID, let saved = windows.first(where: { $0.placeID == placeID }) { return saved }
        return windows.first { $0.placeID == nil && $0.marketName == marketName }
    }
}

private struct MarketAlertSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var details = MarketDetailsStore.shared
    let market: MarketSearchResult
    @State private var fromMinutes = 130
    @State private var toMinutes = 790
    @State private var isSaved = false

    private var alertHours: MarketAlertHours? {
        details.statuses[market.id].flatMap { MarketAlertHours(status: $0) }
    }

    private var canSave: Bool {
        alertHours?.permits(from: fromMinutes, to: toMinutes) == true
    }

    private func adjustSelection() {
        guard let hours = alertHours, let first = hours.ranges.first else { return }
        fromMinutes = hours.adjusted(fromMinutes)
        toMinutes = hours.adjusted(toMinutes)
        if !hours.permits(from: fromMinutes, to: toMinutes) {
            fromMinutes = first.lowerBound
            toMinutes = first.upperBound
        }
    }

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
            if let saved = MarketAlertWindow.saved(for: market.name, placeID: market.resolvedPlaceID) {
                fromMinutes = saved.fromMinutes
                toMinutes = saved.toMinutes
            }
            adjustSelection()
        }
        .task {
            if let placeID = market.resolvedPlaceID { await details.load(placeID: placeID) }
        }
        .onChange(of: alertHours) { _, _ in
            adjustSelection()
        }
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Set Notification for\n\(market.name)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 40)

            if let hours = alertHours, !hours.ranges.isEmpty {
                Text("Market hours today: \(hours.label)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.secondaryText)

                VStack(alignment: .leading, spacing: 12) {
                    Text("From")
                        .font(.system(size: 16, weight: .semibold))
                    MarketTimeWheel(minutesSinceMidnight: $fromMinutes, label: "From", allowedHours: hours.hours)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("To")
                        .font(.system(size: 16, weight: .semibold))
                    MarketTimeWheel(minutesSinceMidnight: $toMinutes, label: "To", allowedHours: hours.hours)
                }
                if !canSave {
                    Text("Choose an end time after the start time, within one market opening period.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.secondaryText)
                }
            } else if alertHours?.ranges.isEmpty == true {
                Text("This market is closed today. Alerts are available during market hours.")
                    .foregroundStyle(AppColors.secondaryText)
            } else if details.statuses[market.id] == nil && market.resolvedPlaceID != nil {
                ProgressView("Loading market hours…")
            } else {
                Text("Market hours are unavailable. Please try again later.")
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer(minLength: 8)
            actionButton("Set Alert") {
                guard canSave else { return }
                MarketAlertWindow(marketName: market.name, fromMinutes: fromMinutes, toMinutes: toMinutes, placeID: market.resolvedPlaceID).save()
                isSaved = true
            }
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
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
            Text("Notification set from \(MarketCrowdSnapshot.timeLabel(fromMinutes)) to \(MarketCrowdSnapshot.timeLabel(toMinutes))")
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
    let allowedHours: [Int]

    private var availablePeriods: [Int] {
        Array(Set(allowedHours.map { $0 / 12 })).sorted()
    }

    private var availableHours: [Int] {
        allowedHours.filter { $0 / 12 == minutesSinceMidnight / 720 }.map {
            $0 % 12 == 0 ? 12 : $0 % 12
        }
    }

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
            let requestedHour = value * 12 + (minutesSinceMidnight / 60) % 12
            let hours = allowedHours.filter { $0 / 12 == value }
            guard let closest = hours.min(by: { abs($0 - requestedHour) < abs($1 - requestedHour) }) else { return }
            minutesSinceMidnight = closest * 60 + minutesSinceMidnight % 60
        })
    }

    var body: some View {
        HStack(spacing: 20) {
            MarketTimeColumn(
                values: availableHours, selection: hour, label: "\(label) hour",
                display: { String(format: "%02d", $0) }
            )
            .id(availableHours)
            MarketTimeColumn(
                values: Array(0..<60), selection: minute, label: "\(label) minute",
                display: { String(format: "%02d", $0) }
            )
            MarketTimeColumn(
                values: availablePeriods, selection: period, label: "\(label) AM or PM",
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
