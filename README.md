# Crowd Status

Crowd Status is a native SwiftUI app for discovering markets around the user's
current location and exploring markets in their detected city. Home, search,
and market details use dynamic Google Places listings rather than a fixed list
of markets for particular cities. The app targets iOS 17 and later on iPhone
and iPad.

**Crowd levels and low-crowd alerts use simulated data because real-time crowd
data is not available to this app.** They are demonstrations, not measured
visitor counts, occupancy, or live crowd reports. Google Places listing data is
separate from these simulated crowd values.

## Dynamic market discovery

With location permission, an internet connection, and a configured Google Places
API key, the app detects the user's city and loads local market listings. For
example, someone in Kolkata can discover markets around their Kolkata location;
the app is not limited to the cities used during development.

- **Nearby:** combines city discovery with a distance-ranked market search,
  excludes markets beyond 8 km, and shows up to four eligible markets nearest
  to the user's coordinates.
- **Popular:** discovers markets for the detected city and shows up to eight
  eligible markets ranked by Google review count, then rating. Nearby markets
  are excluded by Place ID to avoid duplicate cards across the two sections.
- **Search:** uses the same city context, shows up to seven initial suggestions,
  and searches Google Places as the user types. Partial-name searches combine
  autocomplete and text search. Load more retrieves subsequent results.
- **Market details:** opens the selected Google Place ID, so the address, photos,
  rating, phone number, opening hours, and directions belong to that listing.
- **Alerts:** are saved for the selected market by Place ID, keeping markets
  with the same name in different cities independent.

Discovery depends on Google's coverage, request availability, and the app's
market filters. The lists are not an exhaustive directory or a guarantee that
every city will return four Nearby and eight Popular markets. Supplemental
queries such as bazaar, farmers, flea, wholesale, vegetable, flower, and cloth
markets help find more candidates when the initial city results are limited.
Existing researched catalogs provide extra query seeds and identity checks for
some destinations; they do not limit discovery to those cities or supply
fallback cards, ratings, phone numbers, or hours.

Nearby requires a recognized market category, a live listing name and address,
known opening status, a usable weekly schedule, and a usable phone number.
Search and Popular also accept eligible market destinations without a phone
number or complete opening hours. Individual shops and ambiguous listings can
be excluded by the destination filters. Fewer cards are shown when fewer
eligible markets are available.

### Location behavior and limitations

Home asks for location permission and displays the detected area and city.
Location updates while Home or market details are active refresh discovery and
distances as the user moves. Tracking stops when neither screen is active.
Home and details share driving-route distances when Apple Maps routing is
available, with straight-line distance as a fallback.

Home waits for a resolved city before discovering markets. Without location
permission or a successful location lookup, it cannot automatically show the
user's local markets. Search currently has only a market-name field; it has no
manual city selector. Until a city is resolved, search can use the internal
default city, Bengaluru, India. Users should allow location access for their
own city's results. A GitHub download alone does not configure live Places
requests: each developer must supply their own API key.

Home reuses successful lists during the app session. Nearby also saves its
selected Place IDs and discovery coordinates locally. Within 100 m of the saved
origin, it restores the same selection and order while loading listing details
live. Moving at least 100 m selects a new nearby list. Pull to refresh reloads
details and Popular while retaining Nearby membership at the same origin.
Temporary failures show loading or unavailable states rather than invented data.

## Listing details and opening hours

Google Places supplies listing names, addresses, photos, ratings, phone numbers,
and current and regular opening hours when available. Directions use the same
Place ID. Missing addresses and hours show unavailable states; the Call control
is omitted when no usable phone number is supplied. Calling requires a device
with telephone support.

Opening status and weekly hours use the listing's timezone. Split schedules,
overnight hours, closed days, and 24-hour listings are supported. Details refresh
in memory after five minutes or at the next opening-status transition; failed
requests can retry after 30 seconds. Listing content is not persisted to disk by
the app's listing stores. Decoded photos are shared and cached for the session.

About uses an existing researched description when the listing's identity
matches the catalog. Other markets use Google's editorial summary when supplied,
or a listing overview based on the actual category and address. New cities do
not require adding a researched description before their markets can appear.
Missing product specialties are not invented from market names.

## Simulated crowd data

**No real-time crowd provider or measured crowd dataset is connected.**
`MarketCrowdData.swift` generates demo percentages for every market discovered
through Home or search, regardless of city.

| Information | Source |
| --- | --- |
| Market listings, addresses, photos, ratings, phone numbers, and hours | Google Places, when available |
| Crowd percentages, crowd badges, and hourly crowd graphs | Generated simulated data |
| Low-crowd notification decisions | The same simulated crowd data |
| Saved alert preferences and time windows | Local device storage |

Each market and local date gets a stable generated profile based on its Place
ID. The current-hour demo value refreshes every ten minutes. Market details
label the graph **Demo data** and identify percentages as simulated.

Graphs follow the market's opening intervals for today in its timezone. Only
elapsed and current-hour crowd values appear; future bars remain empty. Closed
days and unavailable opening schedules show explanatory states. These graphs
must not be treated as evidence of actual market crowding.

## Demo notifications

Saving a market bell preference or a From/To alert window requests notification
permission and schedules local **Demo** notifications from simulated crowd data.
No live crowd feed or notification backend is required for these demonstrations.

Demo low-crowd events require a simulated percentage below 35%, an open market,
and an enabled alert window or bell preference. Saved time windows apply once
on the day they are saved, end at the chosen time, and do not renew on later
days. A saved window takes precedence over an unrestricted bell preference.
Unrestricted bells use a planning horizon of up to 72 hours. Scheduling limits
include at least one hour between a market's events and 48 pending demo events
globally. Scheduled local notifications can arrive while the app is closed,
subject to the device's notification and Focus settings.

**Send Demo Preview** schedules a test banner about five seconds later. Tapping
a notification opens its selected market. Removing an alert reconciles pending
notifications. Alert preferences and confirmation history are stored locally;
clearing the notification list does not delete saved alert preferences.

Genuine live alerts would require a real crowd-data provider and an APNs backend.
Remote push is unconfigured in the default build. See
[Demo and live notification setup](Documentation/LiveCrowdNotifications.md).

## Project structure

```text
Crowd Status App/
├── CrowdStatus.xcodeproj/           # Xcode project and shared scheme
├── Sources/
│   ├── App/
│   │   ├── CrowdStatusApp.swift     # App entry point and lifecycle
│   │   ├── AppRootView.swift        # Root navigation
│   │   └── MarketPushNotifications.swift # Local demo notification handling
│   ├── DesignSystem/
│   │   └── AppTheme.swift          # Shared colors and spacing
│   └── Features/Home/
│       ├── HomeView.swift          # Home, search, details, and alert UI
│       ├── MarketDiscovery.swift   # Places requests, location, and discovery stores
│       ├── MarketAddresses.swift   # Address loading and validation
│       ├── MarketDescriptions.swift # Researched descriptions and identity catalog
│       ├── MarketOpeningHours.swift # Opening schedules and status
│       ├── MarketCrowdData.swift   # Simulated crowd profiles
│       ├── DemoCrowdNotificationPlan.swift # Demo alert scheduling logic
│       └── LowCrowdNotification.swift # Saved alert preferences and models
├── Assets.xcassets/                # App icon, colors, and bundled images
├── Configuration/
│   ├── App.xcconfig                # Shared build configuration
│   ├── Info.plist                  # Location permission text and API-key setting
│   ├── CrowdStatus.entitlements    # Entitlements file
│   └── Secrets.xcconfig            # Developer-created API key file; ignored by Git
├── Tests/                         # Executable Swift fixture and regression checks
├── Documentation/                 # Notification setup and app-icon notes
└── README.md
```

Live market cards use Google listing photos when available. Bundled assets
provide app visuals; the asset catalog does not determine which cities or
markets can be discovered.

## Technologies used

| Technology | Use in this app |
| --- | --- |
| Swift | Application language; the Xcode project uses Swift 5 language mode |
| SwiftUI | Native screens, navigation, forms, animations, and accessibility |
| Swift Charts | Hourly graphs of simulated crowd percentages |
| Combine | Observable stores that publish changes to the UI |
| Swift concurrency (`async`/`await`, `Task`, `@MainActor`) | Asynchronous requests, cancellation, and UI state updates |
| Foundation and `URLSession` | HTTPS requests, dates, timezones, and JSON encoding/decoding |
| Google Places API (New) | Dynamic market discovery, autocomplete, listing details, photos, and opening hours |
| Core Location | Foreground location access and reverse geocoding to detect the user's city |
| MapKit | Driving-route distance estimates through Apple Maps |
| UserNotifications | Permission requests and local simulated low-crowd notifications |
| UIKit | App delegate integration, notification callbacks, and opening system settings |
| `UserDefaults`, `@AppStorage`, and Codable | Local alert preferences, notification history, and Nearby selection persistence |
| Xcode, `.xcconfig`, and asset catalogs | iOS builds, signing configuration, app icons, colors, and bundled images |
| Git and GitHub | Source version control and repository sharing |

The current app uses Apple's frameworks and direct Google Places web-service
requests, with no third-party package dependencies configured. It supports
**iOS 17 and later** on iPhone and iPad. The executable checks in `Tests` run
with `swiftc` as documented below.

There is no connected real-time crowd-data service or deployed notification
backend. Crowd generation runs locally, and demo notifications use the same
simulated values shown in market details.

## Open and run

1. Open `CrowdStatus.xcodeproj` in Xcode.
2. Create `Configuration/Secrets.xcconfig` with your own Google Places key:

   ```xcconfig
   GOOGLE_PLACES_API_KEY = your_key_here
   ```

3. Enable Places API (New) and billing in the associated Google Cloud project.
   `Configuration/App.xcconfig` loads the optional secrets file for Debug and
   Release. The secrets file is excluded from Git; no key is included in the
   repository.
4. Select the **CrowdStatus** scheme and an iPhone simulator or connected device.
   For a physical device, choose your own development team in Signing &
   Capabilities and use a bundle identifier your team can sign.
5. Run the app and allow location access to discover local markets. In the
   simulator, configure a simulated location for the city you want to explore.
6. Allow notifications if you want to test demo alerts.

The built app reads the key from its Info.plist. Keep local secrets out of Git
and apply Google's API-key restrictions. For production, route web-service
requests through a backend to keep the key out of the app binary. See
[Places setup](https://developers.google.com/maps/documentation/places/web-service/get-api-key)
and [Google Maps Platform security guidance](https://developers.google.com/maps/api-security-best-practices).

## Local validation

These fixture checks do not require an API key. They validate parsing,
discovery rules, search behavior, preferences, opening hours, and simulated
crowd logic; they do not establish live coverage for every city.

```sh
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Sources/Features/Home/MarketAddresses.swift Tests/MarketAddressChecks.swift -o /tmp/CrowdStatusAddressChecks
/tmp/CrowdStatusAddressChecks
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Tests/MarketOpeningHoursChecks.swift -o /tmp/CrowdStatusHoursChecks
/tmp/CrowdStatusHoursChecks
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Sources/Features/Home/MarketCrowdData.swift Tests/MarketCrowdDataChecks.swift -o /tmp/CrowdStatusCrowdChecks
/tmp/CrowdStatusCrowdChecks
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Sources/Features/Home/MarketDiscovery.swift Tests/MarketDiscoveryChecks.swift -o /tmp/CrowdStatusDiscoveryChecks
/tmp/CrowdStatusDiscoveryChecks
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/LowCrowdNotification.swift Tests/LowCrowdNotificationChecks.swift -o /tmp/CrowdStatusNotificationChecks
/tmp/CrowdStatusNotificationChecks
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Sources/Features/Home/MarketDiscovery.swift Tests/NearbyMarketSelectionChecks.swift -o /tmp/CrowdStatusNearbySelectionChecks
/tmp/CrowdStatusNearbySelectionChecks
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketDescriptions.swift Tests/MarketDescriptionChecks.swift -o /tmp/CrowdStatusDescriptionChecks
/tmp/CrowdStatusDescriptionChecks
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Sources/Features/Home/MarketDiscovery.swift Tests/PopularMarketDiscoveryChecks.swift -o /tmp/CrowdStatusPopularChecks
/tmp/CrowdStatusPopularChecks
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Sources/Features/Home/MarketDiscovery.swift Tests/MarketSearchChecks.swift -o /tmp/CrowdStatusSearchChecks
/tmp/CrowdStatusSearchChecks
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Tests/MarketAlertHoursChecks.swift -o /tmp/CrowdStatusAlertHoursChecks
/tmp/CrowdStatusAlertHoursChecks
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketCrowdData.swift Sources/Features/Home/DemoCrowdNotificationPlan.swift Sources/Features/Home/LowCrowdNotification.swift Tests/DemoCrowdNotificationChecks.swift -o /tmp/CrowdStatusDemoNotificationChecks
/tmp/CrowdStatusDemoNotificationChecks
```

To check discovery on a device or simulator, set a location in the desired city,
confirm the Home location label, inspect Nearby and Popular, search for a local
market, and verify that its details and directions refer to the selected listing.
Repeat in another city. Market counts can vary with location and Google results;
crowd graphs and alerts remain simulated in every city.
