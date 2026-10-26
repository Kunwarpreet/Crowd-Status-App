# Demo notifications and future live push

The current app delivers **local demo notifications** using the same generated
crowd profile as the market charts. This works with the existing Personal Team.
It does not claim to measure real crowd levels, and it does not need a backend.

## Use the demo on your iPhone

1. Build and run the app. Open a market and enable its low-crowd bell or save a
   From/To alert window. Tap Allow on the iPhone notification permission prompt.
2. The app schedules notifications when the simulated crowd is below 35%, during
   the market's published opening intervals. A saved time-window alert further
   restricts delivery to one future time window today. Past hours and minutes are
   absent from both wheels; To must follow From within the same opening interval.
   The earliest selectable start is the next whole minute in the market timezone.
   A save-time check rejects a selection that has since passed. It never rolls a
   past selection over to tomorrow and does not repeat daily. A saved time window takes precedence over the all-day
   bell for that market, including after the window expires.
3. Use **Send Demo Preview** in the confirmation dialog or saved-alert sheet to
   request a sample banner about five seconds later. This preview is explicitly
   labelled as a sample and can be used even outside market hours. Scheduled
   low-crowd events, unlike previews, must satisfy the actual demo low/open/window
   conditions.
4. Put the app in the background or lock the iPhone to check system delivery.
   Foreground banners and sounds are also enabled by the app's notification delegate.
   Tapping a notification opens that market by its Google Place ID.
5. If permission was denied, use **Open Notification Settings**. Ensure Allow
   Notifications, Banners, Lock Screen and Sounds are enabled as desired. Focus or
   Scheduled Summary can delay or silence notifications.

Every notification says Demo and describes simulated data. No phone number or
crowd measurement is invented. Saving a preference without notification permission
retains it and explains the permission needed.

## Scheduling behavior

- The app computes up to three future low-crowd episodes per market within a
  rolling 72-hour horizon, using the same deterministic 10-minute demo values as
  MarketCrowdData. It never schedules a low-crowd claim from a real crowd feed.
- Known opening intervals are required. Closed markets, unavailable schedules,
  invalid windows and disabled subscriptions cannot create low-crowd events.
- Time windows use the market timezone and resolve once from their persisted
  save timestamp. Reopening or replanning cannot roll an expired window forward.
  Legacy undated records are anchored and persisted once on migration. Already
  elapsed saved windows resolve to no interval rather than a new day. Old queued
  notifications outside the fixed occurrence are cancelled, even if an hours
  refresh subsequently fails. An expired window needs a new explicit save.
- The 72-hour horizon is only an internal planning limit for unrestricted bell
  preferences. It never makes a saved From/To window recur on following days.
- Notifications have at least an hour between low-crowd events for the same
  market. Delivered low-crowd notifications are consulted when rebuilding to
  avoid immediately repeating an alert on foregrounding.
- At most 48 scheduled demo low-crowd notifications are retained globally, with
  capacity offered to each market's first alert before repeats. Preview requests
  are separate and one pending preview per market replaces an earlier preview.
- The system retains scheduled requests and can deliver them while the app is
  closed. Reopen the app to refresh the next three days; there is no indefinite
  server-side monitoring or guaranteed background execution.
- Every save, removal and foreground rebuilds pending requests. Rebuilds serialize
  so a later removal/window change wins over an earlier save. Removing the bell
  cancels its all-day alerts; a separately saved one-time From/To window remains
  valid only until its fixed end time.
- Unrelated notifications are not cancelled. Clearing the in-app confirmation
  list does not disable preferences or pending alerts.

## What remote push means

**Local:** the app prepares a notification and iOS delivers it at the scheduled
condition. This is sufficient for generated demo data and Personal Team testing.

**Remote:** a provider server sends an event through Apple Push Notification
service (APNs) to a registered device. This is needed for new real crowd readings
arriving while the app is closed. Local demo delivery does not enable remote push.

## Enable remote push later

1. Enroll in the Apple Developer Program and select the supported team in Xcode
   → CrowdStatus target → Signing & Capabilities. A free Personal Team cannot
   provision the Push Notifications capability.
2. Use **+ Capability → Push Notifications**. Let Xcode configure the entitlements
   file and a compatible App ID/provisioning profile for that team. Check whether
   the signed build uses the development or production APNs environment.
3. Add `ENABLE_REMOTE_PUSH` to Swift Active Compilation Conditions for the
   intended build configurations, preserving inherited conditions. The client
   then requests a fresh APNs token for authorized devices. Tokens stay in memory
   and are not logged or persisted.
4. Deploy an HTTPS notification backend and securely register device tokens and
   per-market subscriptions with a stable installation/account identity. Handle
   saves, time-window edits, removals and token rotation. APNs credentials belong
   on the server, not inside the iPhone app.
5. For genuine low-crowd alerts, connect a licensed measured crowd-data source
   with tested coverage for the requested Place IDs. Reject missing/stale readings,
   restrict delivery to open markets and saved windows, and add event deduplication,
   cooldowns, delivery retries and invalid-token handling.

The current default target has no Push Notifications capability or APS entitlement,
so Personal Team signing still works. Live remote delivery is not implemented:
there is no server, subscription synchronization or real crowd provider yet.

The receiver already handles banners, registration callbacks and payload routing:

```json
{
  "aps": {"alert": {"title": "Crowd Status", "body": "A provider event"}, "sound": "default"},
  "placeID": "market-place-id",
  "marketName": "Selected market"
}
```

## Validation

Planner checks cover low-threshold parity with chart data, opening intervals,
market-local time windows, disabled/invalid subscriptions, cooldowns, deterministic
results, unique IDs and queue limits. Notification preference and route checks
also run without credentials. Both simulator and signed Personal Team device
builds are checked. Physical iPhone permission/banners should be tested with Send
Demo Preview; no end-to-end remote delivery is claimed.

```sh
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketCrowdData.swift Sources/Features/Home/DemoCrowdNotificationPlan.swift Sources/Features/Home/LowCrowdNotification.swift Tests/DemoCrowdNotificationChecks.swift -o /tmp/CrowdStatusDemoNotificationChecks
/tmp/CrowdStatusDemoNotificationChecks
```

## Apple references

- [Local notification scheduling and cancellation](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [Local delivery while the app is not running](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html)
- [Notification permission](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [Enable Push Notifications](https://help.apple.com/xcode/mac/current/en.lproj/devdfd3d04a1.html)
- [Registering with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
