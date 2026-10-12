# Crowd Status

A native iOS app built with SwiftUI. The current starting screen is the Crowd
Status Home screen with sample nearby and popular markets.

## Project structure

- `Sources/App` contains the app entry point and root view.
- `Sources/DesignSystem` contains shared colors and spacing values.
- `Sources/Features/Home` contains the Home screen and its screen-specific UI.
- `Assets.xcassets` contains the Home screen market and profile images.

Market search is available from the Home screen and filters the local sample
market list as text is entered. Search results and Home market cards open a
shared market detail screen with the selected market name. Each detail screen
uses the four-photo sample carousel from the design reference; swipe horizontally
to change photos and the four dots indicate the selected page.
The detail screen includes About information and a Google Maps search link.
Every market includes a description, opening days, hours, and rating. These are
sample details pending a live data source; Raja Market uses the design reference.
All Call links open the phone dialer for the supplied shared number, 8054369102.
Calling requires a device with telephone support.
The Home search field opens market details from search results. The Crowd Status
card’s Search Market button opens the same search screen in alert setup mode;
selecting a result opens that market’s notification popup. Detail page alert
buttons also open the popup. From/To wheel pickers select the time window,
Set Alert saves it locally per market and shows success, and Done closes it.
Saved times are restored on reopening. These preferences do not yet schedule
notifications; recurring alerts based on crowd levels require a live data service.
The Home bell opens Notifications, displaying saved market alert confirmations
and their time windows, or an empty state when no notifications remain.
Clear notifications asks for confirmation and persists the cleared list without
deleting saved alert windows. Saving an alert again creates a new confirmation.
Profile, crowd levels, distances, search market names, and editorial market detail
data still use samples defined in `HomeView.swift`. Addresses load from Google.

## Market addresses

Search previews and market detail headers share live Google Places formatted
addresses. The six markets use verified Place IDs to avoid selecting similarly
named shops, bus stops, or neighborhoods. KR Market uses the Sri Krishna
Rajendra Market listing. Raja Market uses the listing at 162 Avenue Road.
Addresses wrap in both views and directions open the same Google Place ID.
Only visible search results request an address; details opened directly from
Home request it too. The shared store keeps responses in memory for the session,
refreshes after five minutes when viewed again, and never writes addresses to
disk. Missing responses show **Address unavailable**; loading shows
**Loading address…**, rather than a guessed location.

Address fixture checks:

```sh
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Sources/Features/Home/MarketAddresses.swift Tests/MarketAddressChecks.swift -o /tmp/CrowdStatusAddressChecks
/tmp/CrowdStatusAddressChecks
```

## Nearby opening status

Nearby cards fetch Google Places (New) `currentOpeningHours`. An open market
shows **Open till 9pm** using its next closing time. A closed market shows
**Closed till 9am** using its next opening time, including
tomorrow or the weekday when appropriate, in Bengaluru's timezone. Google may
omit transition times; in that case the card shows **Open** or **Closed**.
Missing hours, failed requests, ambiguous matches, and missing configuration show
**Hours unavailable**. Loading shows **Checking hours…**. Cards no longer show
the original sample hours or the Google Maps text. Status refreshes every five
minutes while Home is active and at the next opening/closing transition (checked
every 30 seconds). Returning to Home refreshes expired results; pull down to
force a refresh. Opening-hour responses are not persisted.

To enable live data, create a Google Cloud project with billing and Places API
(New) enabled, then paste the key into `Configuration/Secrets.xcconfig`:
`GOOGLE_PLACES_API_KEY = your_key_here`. Create that file if it is missing;
it is excluded from Git. `Configuration/App.xcconfig` loads it for Debug and Release. The
generated Info.plist reads it as `GooglePlacesAPIKey`. No key is included in the
repository. Follow Google's key restriction guidance; for production, route
web-service calls through a backend to keep the key out of the app binary.
See [Places setup](https://developers.google.com/maps/documentation/places/web-service/get-api-key)
and [security guidance](https://developers.google.com/maps/api-security-best-practices).

Russell Market fetches hours directly using the verified Google Place ID for
its Shivaji Nagar listing, so changes to its display name do not break hours.
Other market lookups require a unique exact-name match within Bengaluru. Generic
sample names such as Sunday Market may not identify a unique Google listing;
confirm the real listing before changing its name or adding a stable Place ID.
Unavailable responses retry after 30 seconds while Home is active.
The existing card images, distances and crowd levels remain sample data.

Opening-status fixture checks (no API key needed):

```sh
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Tests/MarketOpeningHoursChecks.swift -o /tmp/CrowdStatusHoursChecks
/tmp/CrowdStatusHoursChecks
```

## Open and run in Xcode

1. Install Xcode from the Mac App Store if it is not already installed.
2. Open `CrowdStatus.xcodeproj` in Xcode.
3. Select the **CrowdStatus** scheme and an iPhone simulator from the toolbar.
4. Press the Run button or choose **Product > Run**.

The app targets iOS 17 and later and supports iPhone and iPad. You can also
connect an iPhone, select it as the run destination, and run the app there.
