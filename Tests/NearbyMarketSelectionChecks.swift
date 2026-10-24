import Foundation
import CoreLocation

@main
struct NearbyMarketSelectionChecks {
    @MainActor
    static func main() async throws {
        // This standalone executable deliberately has no API configuration.
        // Detail/search failures exercise restoration without making live requests.
        precondition(Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") == nil)
        let suite = "NearbyMarketSelectionChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let origin = CLLocation(latitude: 12.97, longitude: 77.59)
        let drift = CLLocation(latitude: 12.9701, longitude: 77.59)
        let moved = CLLocation(latitude: 12.972, longitude: 77.59)
        let ids = ["saved-second", "saved-first"]
        let selection = NearbyMarketSelection(location: origin, placeIDs: ids)
        precondition(NearbyMarketSelection.load(defaults: defaults) == nil)
        selection.save(defaults: defaults)
        let restored = NearbyMarketSelection.load(defaults: defaults)!
        precondition(restored.placeIDs == ids)
        precondition(restored.matches(location: origin))
        precondition(restored.matches(location: drift))
        precondition(!restored.matches(location: moved))
        precondition(!restored.matches(location: nil))

        let firstLaunch = HomeMarketStore(defaults: defaults)
        precondition(!firstLaunch.hasCompletedLaunchSkeleton)
        await firstLaunch.completeLaunchSkeleton()
        precondition(firstLaunch.hasCompletedLaunchSkeleton)
        // A recreated Home view uses the same session store; appearing again
        // must not reset its launch skeleton, even after an unsuccessful refresh.
        await firstLaunch.completeLaunchSkeleton()
        precondition(firstLaunch.hasCompletedLaunchSkeleton)
        await firstLaunch.refresh(city: "Bengaluru, India", location: origin, hasResolvedCity: true)
        precondition(firstLaunch.nearby.map(\.id) == ids)
        precondition(firstLaunch.hasCompletedLaunchSkeleton)
        // A fresh instance simulates relaunch; transient failures cannot rotate cards.
        let relaunch = HomeMarketStore(defaults: defaults)
        precondition(!relaunch.hasCompletedLaunchSkeleton)
        let cancelledLaunch = Task { await relaunch.completeLaunchSkeleton() }
        cancelledLaunch.cancel()
        await cancelledLaunch.value
        precondition(!relaunch.hasCompletedLaunchSkeleton)
        await relaunch.completeLaunchSkeleton()
        precondition(relaunch.hasCompletedLaunchSkeleton)
        await relaunch.refresh(city: "Bengaluru, India", location: drift, hasResolvedCity: true)
        precondition(relaunch.nearby.map(\.id) == ids)
        await relaunch.refresh(city: "Bengaluru, India", location: origin, hasResolvedCity: true, force: true)
        precondition(relaunch.nearby.map(\.id) == ids)
        // A geocoder label change at the same coordinates does not change selection.
        await relaunch.refresh(city: "Bangalore, India", location: origin, hasResolvedCity: true)
        precondition(relaunch.nearby.map(\.id) == ids)
        await relaunch.refresh(city: "Bengaluru, India", location: moved, hasResolvedCity: true)
        precondition(relaunch.nearby.isEmpty)
        // Failed discovery at a new origin must not overwrite a successful selection.
        precondition(NearbyMarketSelection.load(defaults: defaults)!.matches(location: origin))
        await relaunch.refresh(city: "Bengaluru, India", location: nil, hasResolvedCity: true)
        precondition(relaunch.nearby.isEmpty)
        defaults.set(Data("broken".utf8), forKey: NearbyMarketSelection.storageKey)
        precondition(NearbyMarketSelection.load(defaults: defaults) == nil)
        print("Nearby selection persistence and refresh checks passed")
    }
}
