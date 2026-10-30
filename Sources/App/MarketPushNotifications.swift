import UIKit
import UserNotifications
import Combine

/// Local demo notifications work with a Personal Team. Optional real remote push
/// remains gated until an APNs-capable team, provider and server are configured.
@MainActor
final class MarketPushNotifications: ObservableObject {
    static let shared = MarketPushNotifications()
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: String?
    @Published private(set) var registrationError: String?
    @Published var marketToOpen: MarketPushRoute?
    @Published private(set) var scheduledDemoCount = 0
    @Published private(set) var scheduledDemoCounts: [String: Int] = [:]
    @Published private(set) var demoSchedulingError: String?
    @Published private(set) var previewMessage: String?
    @Published private(set) var isPreviewCountdownActive = false
    private var schedulingTask: Task<Void, Never>?

    private var remotePushEnabled: Bool {
#if ENABLE_REMOTE_PUSH
        true
#else
        false
#endif
    }

    var setupMessage: String {
        if authorizationStatus == .denied {
            return "Your alert is saved. Allow notifications for Crowd Status in iPhone Settings to receive demo banners and sounds."
        }
        if let demoSchedulingError { return demoSchedulingError }
        if authorizationStatus == .notDetermined {
            return "Allow notifications to receive demo low-crowd alerts on this iPhone. These use simulated crowd data."
        }
        if scheduledDemoCount > 0 {
            return "Demo alerts are scheduled for simulated low-crowd periods during market hours. These use generated data, not live crowd readings."
        }
        return "Your alert is saved. No simulated low-crowd notifications are currently scheduled. Send a demo preview to test iPhone delivery."
    }

    func setupMessage(for placeID: String?) -> String {
        guard let placeID, [.authorized, .provisional, .ephemeral].contains(authorizationStatus),
              demoSchedulingError == nil else { return setupMessage }
        if let window = MarketAlertWindow.allSaved().first(where: { $0.placeID == placeID }) {
            let zone = MarketDetailsStore.shared.statuses[placeID]?.timeZoneID ?? "Asia/Kolkata"
            if let interval = window.oneTimeInterval(timeZoneID: zone), interval.end <= Date() {
                return "This one-time alert window has ended. It will not repeat. Save a new alert to choose another time."
            }
            if scheduledDemoCounts[placeID, default: 0] > 0 {
                return "Demo low-crowd alerts apply only to this saved time window once. They stop when it ends and do not repeat on following days. These are simulated readings."
            }
            return "This is a one-time alert window. No simulated low-crowd notifications are currently scheduled within it. It will not repeat. Send a demo preview to test delivery."
        }
        if scheduledDemoCounts[placeID, default: 0] == 0 {
            return "Your alert is saved. No simulated low-crowd notifications with available market hours are currently scheduled for this market. Send a demo preview to test delivery."
        }
        return setupMessage
    }

    func requestPermissionForSavedAlert() async {
        previewMessage = nil
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()
        do {
            if current.authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            }
            await refreshAuthorization()
        } catch {
            demoSchedulingError = "Could not enable notifications. Please try again in iPhone Settings."
        }
    }

    func refreshAuthorization() async {
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if remotePushEnabled && [.authorized, .provisional, .ephemeral].contains(authorizationStatus) {
            // Ask APNs for a fresh token each launch/foreground; never persist it.
            UIApplication.shared.registerForRemoteNotifications()
        }
        await synchronizeDemoAlerts()
    }

    func synchronizeDemoAlerts() async {
        // Serialize rebuilds: a removal or changed window must win over an older save.
        let previous = schedulingTask
        previous?.cancel()
        let task = Task { @MainActor in
            await previous?.value
            guard !Task.isCancelled else { return }
            await rebuildDemoAlerts()
        }
        schedulingTask = task
        await task.value
    }

    private func rebuildDemoAlerts() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        let lowCrowd = LowCrowdNotification.allSaved()
        let windows = MarketAlertWindow.allSaved()
        func id(_ placeID: String?, _ name: String) -> String? { placeID ?? GoogleMarketHours.placeIDs[name] }
        let alwaysOn = Set(lowCrowd.compactMap { id($0.placeID, $0.marketName) })
        var names: [String: String] = [:]
        for alert in lowCrowd { if let id = id(alert.placeID, alert.marketName) { names[id] = alert.marketName } }
        for alert in windows { if let id = id(alert.placeID, alert.marketName) { names[id] = alert.marketName } }
        let pending = await center.pendingNotificationRequests()
        let removed = pending.filter { request in
            let managed = request.identifier.hasPrefix("demo-low|") || request.identifier.hasPrefix("demo-preview|")
            let placeID = request.content.userInfo["placeID"] as? String ?? ""
            if managed && !names.keys.contains(placeID) { return true }
            guard request.identifier.hasPrefix("demo-low|"),
                  let window = windows.first(where: { id($0.placeID, $0.marketName) == placeID }) else { return false }
            let zone = MarketDetailsStore.shared.statuses[placeID]?.timeZoneID ?? "Asia/Kolkata"
            guard let interval = window.oneTimeInterval(timeZoneID: zone),
                  let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let fire = trigger.nextTriggerDate() else { return true }
            return fire < interval.start || fire >= interval.end
        }
        guard !Task.isCancelled else { return }
        center.removePendingNotificationRequests(withIdentifiers: removed.map(\.identifier))
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            scheduledDemoCount = 0
            scheduledDemoCounts = [:]
            return
        }
        let now = Date()
        var subscriptions: [DemoCrowdAlertSubscription] = []
        var unavailableIDs = Set<String>()
        for (placeID, name) in names.sorted(by: { $0.key < $1.key }) {
            guard !Task.isCancelled else { return }
            await MarketDetailsStore.shared.load(placeID: placeID)
            guard !Task.isCancelled else { return }
            guard let status = MarketDetailsStore.shared.statuses[placeID], !MarketDetailsStore.shared.failures.contains(placeID) else {
                unavailableIDs.insert(placeID)
                continue
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: status.timeZoneID) ?? TimeZone(identifier: "Asia/Kolkata")!
            let intervals = (0...3).flatMap { offset -> [DateInterval] in
                guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return [] }
                return status.todayOpenIntervals(at: day) ?? []
            }
            let selectedWindows = windows.filter { id($0.placeID, $0.marketName) == placeID }.map {
                DemoCrowdAlertWindow(fromMinutes: $0.fromMinutes, toMinutes: $0.toMinutes,
                                     occurrence: $0.oneTimeInterval(timeZoneID: status.timeZoneID))
            }
            subscriptions.append(.init(placeID: placeID, marketName: name, timeZoneID: status.timeZoneID,
                                       openIntervals: intervals, alwaysEnabled: alwaysOn.contains(placeID),
                                       windows: selectedWindows))
        }
        let delivered = await center.deliveredNotifications()
        var lastDelivered: [String: Date] = [:]
        for item in delivered where item.request.identifier.hasPrefix("demo-low|") {
            if let id = item.request.content.userInfo["placeID"] as? String {
                lastDelivered[id] = max(lastDelivered[id] ?? .distantPast, item.date)
            }
        }
        for index in subscriptions.indices { subscriptions[index].lastDeliveredAt = lastDelivered[subscriptions[index].placeID] }
        guard !Task.isCancelled else { return }
        // Network reads may take longer than the initial five-second lead time.
        // Plan relative to completion, retaining valid queued alerts during outages.
        await applyDemoPlan(subscriptions, now: Date(), preserving: unavailableIDs)
    }

    func applyDemoPlan(_ subscriptions: [DemoCrowdAlertSubscription], now: Date = Date(), preserving unavailableIDs: Set<String> = []) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let preserved = pending.filter { $0.identifier.hasPrefix("demo-low|") && unavailableIDs.contains($0.content.userInfo["placeID"] as? String ?? "") }
        let events = DemoCrowdNotificationPlan.events(for: subscriptions, now: now)
            .prefix(max(0, DemoCrowdNotificationPlan.requestLimit - preserved.count))
        guard !Task.isCancelled else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending.filter {
            $0.identifier.hasPrefix("demo-low|") && !unavailableIDs.contains($0.content.userInfo["placeID"] as? String ?? "")
        }.map(\.identifier))
        demoSchedulingError = nil
        scheduledDemoCount = preserved.count
        scheduledDemoCounts = [:]
        for request in preserved {
            if let id = request.content.userInfo["placeID"] as? String { scheduledDemoCounts[id, default: 0] += 1 }
        }
        for event in events {
            guard !Task.isCancelled else { return }
            let content = UNMutableNotificationContent()
            content.title = "Demo · Low crowd"
            content.body = "\(event.marketName): simulated crowd is \(event.simulatedPercent)%. This is demo data, not a live reading."
            content.sound = .default
            content.threadIdentifier = event.placeID
            content.userInfo = ["placeID": event.placeID, "marketName": event.marketName, "demo": true]
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: event.fireDate)
            components.timeZone = calendar.timeZone
            let request = UNNotificationRequest(identifier: event.id, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do {
                try await center.add(request)
                scheduledDemoCount += 1
                scheduledDemoCounts[event.placeID, default: 0] += 1
            } catch {
                demoSchedulingError = "Some demo alerts could not be scheduled. Please try saving the alert again."
            }
        }
    }

    func sendDemoPreview(placeID: String, marketName: String) async {
        guard !isPreviewCountdownActive else { return }
        isPreviewCountdownActive = true
        defer { isPreviewCountdownActive = false }
        await requestPermissionForSavedAlert()
        guard [.authorized, .provisional, .ephemeral].contains(authorizationStatus) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Demo preview · Crowd Status"
        content.body = "Sample low-crowd alert for \(marketName). This is a demo preview, not a live crowd reading."
        content.sound = .default
        content.threadIdentifier = placeID
        content.userInfo = ["placeID": placeID, "marketName": marketName, "demo": true]
        do {
            let deadline = Date().addingTimeInterval(5)
            try await UNUserNotificationCenter.current().add(.init(
                identifier: "demo-preview|\(placeID)", content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
            // Use the deadline so a suspended app catches up instead of resuming
            // a stale count. Finishing the timer does not confirm iOS delivery.
            while true {
                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0 else { break }
                let seconds = Int(ceil(remaining))
                let unit = seconds == 1 ? "second" : "seconds"
                previewMessage = "Demo preview scheduled.\nAppearing in \(seconds) \(unit)."
                do {
                    try await Task.sleep(for: .seconds(min(1, remaining)))
                } catch {
                    previewMessage = "Demo preview scheduled."
                    return
                }
            }
            previewMessage = "Preview countdown complete."
        } catch {
            previewMessage = "Could not schedule the demo preview. Please check notification settings."
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func registered(deviceToken: Data) {
        self.deviceToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        registrationError = nil
        // Future provider integration must securely send this token with the
        // current Place-ID subscriptions. Receiving a token is not live delivery.
    }

    func registrationFailed(_ error: Error) {
        deviceToken = nil
        registrationError = error.localizedDescription
    }

    func open(_ userInfo: [AnyHashable: Any]) {
        marketToOpen = MarketPushRoute(userInfo: userInfo)
    }
}

final class MarketNotificationAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in MarketPushNotifications.shared.registered(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in MarketPushNotifications.shared.registrationFailed(error) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // iOS presents scheduled local alerts and APNs alerts in the background.
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            if response.actionIdentifier != UNNotificationDismissActionIdentifier {
                MarketPushNotifications.shared.open(userInfo)
            }
            completionHandler()
        }
    }
}
