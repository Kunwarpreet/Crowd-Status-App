import SwiftUI

struct AppRootView: View {
    @ObservedObject private var notifications = MarketPushNotifications.shared
    var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(item: $notifications.marketToOpen) { route in
                    MarketDetailView(market: MarketSearchResult(
                        name: route.marketName, imageName: "", distance: "",
                        livePlace: .pendingSelection(id: route.placeID)
                    ))
                }
        }
    }
}

#Preview {
    AppRootView()
}
