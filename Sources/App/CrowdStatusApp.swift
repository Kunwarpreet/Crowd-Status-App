import SwiftUI

@main
struct CrowdStatusApp: App {
    @UIApplicationDelegateAdaptor(MarketNotificationAppDelegate.self) private var notificationDelegate
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await MarketPushNotifications.shared.refreshAuthorization()
                }
        }
    }
}
