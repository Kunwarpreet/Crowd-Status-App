# Crowd Status

A native iOS app built with SwiftUI. The current starting screen is the Crowd
Status Home screen with sample nearby and popular markets.

## Project structure

- `Sources/App` contains the app entry point and root view.
- `Sources/DesignSystem` contains shared colors and spacing values.
- `Sources/Features/Home` contains the Home screen and its screen-specific UI.
- `Assets.xcassets` contains the Home screen market and profile images.

Market search uses live Google Places results for the current city. On opening
search, the app asks for location permission to detect the city; users can also
enter a city and country manually and tap Apply. Location failures and denied
permission leave the explicit city field available (initially Bengaluru, India).
The empty search shows city markets. Typing a name performs a debounced live
search rather than filtering six samples. Load more markets fetches subsequent
Google pages and deduplicates by Place ID. Google limits results per query, so
this is city-wide discovery, not an exhaustive municipal directory. A more
specific name search can discover listings missing from the broad city query.

Every result opens its own market detail screen using its Google Place ID.
Addresses, rating, phone, editorial description when available, up to four photos,
current status, weekly hours, and directions come from that same listing. Photo
author names are hidden on Home thumbnails and the detail carousel. Missing fields show unavailable states rather
than another market's phone, photos, or rating. Distances are computed when the
current location is available. Home's Chickpet entry is replaced by Gandhi Bazaar
Flower Market, verified with published hours, photos, rating, and phone details.
Every market detail screen includes a crowd bar graph restricted to that market’s
opening intervals for today, using Google’s current hours and regular hours as a
fallback. Split schedules leave closed gaps empty, partial hours keep exact opening
and closing minutes, and overnight intervals are clipped to today in the market’s
timezone. Only elapsed and current-hour bars are shown; future crowd values are
hidden. Longer graphs scroll horizontally with up to eight
hours visible at once, automatically placing the current-hour bar inside the
visible window when the chart appears or a new hour begins. A subtle draggable
grey scrollbar tracks the viewport and supports accessibility adjustments.
Scrolling reveals
earlier hours; future data remains excluded. The graph has no separate Open hours
text. The axis spans today's actual opening-to-closing window, including exact
closing minutes (for example, 10am–8:30pm). Only elapsed and current-hour crowd
bars are populated; future hours inside that opening window stay empty. Before the first opening time,
the app explains that the graph starts when the market opens. Closed days show
**Closed today**; missing schedules show
**Opening hours unavailable**. Markets open 24 hours show bars from midnight through the current hour. No measured crowd
provider is currently connected; all graphs use generated demo data and display
**Demo data**, simulated percentages, and an explicit simulated-data refresh label.
Each market and local date gets a different stable profile. The current hour is
highlighted and its demo value refreshes every ten minutes. Charts include markets
opened from Home and every result returned by city search.
Calling requires a device with telephone support.
The Home search field opens market details from search results. The Crowd Status
card’s Search Market button opens the same search screen in alert setup mode;
selecting a result opens that market’s notification popup. Detail page alert
buttons also open the popup. From/To wheel pickers select the time window,
Set Alert saves it locally per market and shows success, and Done closes it.
Saved times are restored on reopening. These preferences do not yet schedule
notifications; recurring alerts based on crowd levels require a live data service.
The notification icon on every market detail page opens a native iPhone alert
asking "Do you want to get notified everytime when there is low crowd."
Notified saves that market's low-crowd preference locally and shows an animated
white "Notification Set" toast with a green checkmark for 3.5 seconds after the
native alert finishes dismissing. The toast is centered between the back and
notification buttons over the hero image, without moving either button. Enabled
markets show a green bell with a checkmark; this state survives reopening the
detail screen or restarting the app. Tapping an enabled icon asks
"Do you want to remove this alert notification" with **Yes, Remove** and **Keep**.
Keep is the default action. Yes, Remove clears only that market's low-crowd
preference and confirmation, restores the default icon, and allows enabling it
again; other markets and saved time-window alerts are preserved. Cancel
returns to the detail screen. Toast padding is 8pt vertically and 12pt
horizontally, with an 8pt gap and 16pt corner radius. The separate Set Alert
button continues to configure a time window. Low-crowd preferences are stored
under `lowCrowdNotificationMarkets`; they do not yet deliver push notifications.
The Home bell opens Notifications, displaying saved low-crowd confirmations
and market alert time windows, or an empty state when no notifications remain.
Earlier low-crowd preferences are migrated into the list. Each confirmation
is persisted per market; confirming again creates a new confirmation ID.
Clear notifications asks for confirmation and persists the cleared list without
deleting saved alert windows or low-crowd preferences. Saving an alert again
creates a new confirmation.
Profile, featured Home markets, crowd levels, and featured Home distances still
use samples defined in `HomeView.swift`. Search names and listing details load from
Google. Low-crowd and time-window preferences use Place IDs, keeping same-name
markets in different cities independent; older saved preferences remain supported.

## Market addresses

Search results include Google's formatted address. Detail headers load the same
listing by Place ID, including markets discovered outside the featured Home list.
KR Market uses Sri Krishna Rajendra Market; Raja Market uses 162 Avenue Road.
Search addresses wrap. The detail header's name, address, and distance occupy a
250pt column with single-line tail truncation and an 8pt gap before the status
control. Directions always use the selected Place ID. Details refresh in memory
after five minutes or at the next status transition, checked every 30 seconds.
Failed detail requests retry after 30 seconds; Google responses are not saved to
disk. Missing addresses show **Address unavailable** and loading shows
**Loading address…**.

Loaded photos are cached as decoded images for the app session and shared between
Home cards and detail carousels. Reopening a market displays cached photos immediately
without another download. Concurrent views share one download per photo, and leaving
a screen does not cancel that shared download. Failed photos retry on reopening.
Details remain visible during background status refreshes. Crowd summary titles use
Low/Moderate/High crowd without the demo suffix; the Demo data badge and simulated
percentage labels still identify the data source.

Address fixture checks:

```sh
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Sources/Features/Home/MarketAddresses.swift Tests/MarketAddressChecks.swift -o /tmp/CrowdStatusAddressChecks
/tmp/CrowdStatusAddressChecks
```

## Nearby opening status

Home cards fetch Google Places (New) `currentOpeningHours`. A nearby open market
shows **Open · Closes at 9pm** using its next closing time. A closed market shows
**Closed · Opens at 9am** using its next opening time, including
tomorrow or the weekday when appropriate, in Bengaluru's timezone. Google may
omit transition times; in that case the card shows **Open** or **Closed**.
Missing hours, failed requests, ambiguous matches, and missing configuration show
**Hours unavailable**. Loading shows **Checking hours…**. Cards no longer show
the original sample hours or the Google Maps text. Status refreshes every five
minutes while Home is active and at the next opening/closing transition (checked
every 30 seconds). Returning to Home refreshes expired results; pull down to
force a refresh. Opening-hour responses are not persisted. Popular cards also load live status
instead of always showing Open. The About section shows rating and Call; available
days and hours are shown in the header dropdown.
The detail header includes an Open/Closed dropdown based on live Google status:
Open is green and Closed is grey. Tapping it opens a weekly hours popover with
all seven weekdays, starting with today in the listing's timezone and highlighting
today in bold. Closed days remain visible; unpublished hours show Unavailable.
The red crowd indicator dot fades between full and 15% opacity every 1.2 seconds using
a time-driven timeline. It resumes when the app returns to the foreground and is
steady when Reduce Motion is enabled.

To enable live data, create a Google Cloud project with billing and Places API
(New) enabled, then paste the key into `Configuration/Secrets.xcconfig`:
`GOOGLE_PLACES_API_KEY = your_key_here`. Create that file if it is missing;
it is excluded from Git. `Configuration/App.xcconfig` loads it for Debug and Release. The
generated Info.plist reads it as `GooglePlacesAPIKey`. No key is included in the
repository. Follow Google's key restriction guidance; for production, route
web-service calls through a backend to keep the key out of the app binary.
See [Places setup](https://developers.google.com/maps/documentation/places/web-service/get-api-key)
and [security guidance](https://developers.google.com/maps/api-security-best-practices).

All six markets fetch hours directly by the shared verified Google Place IDs;
addresses, hours, and directions use the same listing even when Google renames it.

Google Places audit on 13 October 2026:

| Market | Published regular hours |
| --- | --- |
| Russell Market | Daily, 7am–11pm |
| Jayanagar Market | Mon/Wed/Thu/Fri 10am–9:30pm; Tue 10am–9am next day; Sat 10am–10pm; Sun 10am–9pm |
| Sunday Market | Daily, 10am–10:30pm (the pinned listing is not Sunday Bazar) |
| KR Market | Daily, 10am–9pm (Sri Krishna Rajendra Market listing) |
| Raja Market | Mon–Sat 10am–8:30pm; Sun 10:30am–6pm |
| Gandhi Bazaar Flower Market | Mon 3:30am–11:30pm; Fri 5:20am–9pm; Tue/Wed/Thu/Sat/Sun open 24 hours |

These audit values are documentation, not fallback schedules. Jayanagar’s Tuesday
closing time is unusual but returned by Google as 9am the next day; the app keeps
Google’s value. Current hours can include holiday exceptions and may differ from
regular weekly hours. The app fetches live values rather than hardcoding this table.
Unavailable responses retry after 30 seconds while Home is active.
The existing Home card images, distances and crowd levels remain sample data;
Gandhi Bazaar Flower Market uses a photo from its own Google listing.

Opening-status fixture checks (no API key needed):

```sh
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Tests/MarketOpeningHoursChecks.swift -o /tmp/CrowdStatusHoursChecks
/tmp/CrowdStatusHoursChecks
```

## Crowd graph provenance

Checked on 13 October 2026. The configured Google Places API does not expose
hourly foot-traffic or live busyness fields. BestTime documents forecast and live
foot-traffic endpoints, but the project has no BestTime credentials. No verified,
current crowd dataset for the app's markets was retrieved or imported.

| Market | Crowd bar graph source |
| --- | --- |
| Russell Market | Generated demo data |
| Jayanagar Market | Generated demo data |
| Sunday Market | Generated demo data |
| KR Market / Sri Krishna Rajendra Market | Generated demo data |
| Raja Market | Generated demo data |
| Gandhi Bazaar Flower Market | Generated demo data |
| All other markets discovered through city search | Generated demo data |

**Actual/live crowd datasets used: none.** Google addresses, hours, ratings, photos,
and phone fields remain real listing data; they are separate from simulated crowd
percentages. The graph percentages are neither visitor counts nor measured occupancy.
The generator is in `MarketCrowdData.swift`; it seeds a daily profile by Place ID and
local date, so reopening a market doesn't randomly change the whole chart. Only the
current-hour value varies by ten-minute refresh bucket. No generated crowd values
trigger or deliver real notifications.

Sources checked:
[Google Places fields](https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places)
and [BestTime API documentation](https://documentation.besttime.app/app/).

```sh
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Sources/Features/Home/MarketCrowdData.swift Tests/MarketCrowdDataChecks.swift -o /tmp/CrowdStatusCrowdChecks
/tmp/CrowdStatusCrowdChecks
```

## Search and preference checks

```sh
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketOpeningHours.swift Sources/Features/Home/MarketDiscovery.swift Tests/MarketDiscoveryChecks.swift -o /tmp/CrowdStatusDiscoveryChecks
/tmp/CrowdStatusDiscoveryChecks
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/LowCrowdNotification.swift Tests/LowCrowdNotificationChecks.swift -o /tmp/CrowdStatusNotificationChecks
/tmp/CrowdStatusNotificationChecks
```

## Open and run in Xcode

1. Install Xcode from the Mac App Store if it is not already installed.
2. Open `CrowdStatus.xcodeproj` in Xcode.
3. Select the **CrowdStatus** scheme and an iPhone simulator from the toolbar.
4. Press the Run button or choose **Product > Run**.

The app targets iOS 17 and later and supports iPhone and iPad. You can also
connect an iPhone, select it as the run destination, and run the app there.

### Location-based Home markets

Home uses the shared city/location selection instead of fixed Bengaluru cards. It asks for location permission and displays the detected city. The location label opens market search, where a city can also be entered manually. Nearby combines city results with a Google Places distance-ranked market search, excludes results beyond 8 km, sorts by straight-line distance, and shows at most the nearest four available markets. Manual city selection without coordinates displays a location prompt in Nearby rather than sample distances.

Popular loads the city search pages (up to 60 results) and shows up to eight markets ranked by Google review count, then rating. This ranks the returned market results, rather than claiming an exhaustive city-wide popularity measure. Cards use Google photos, real opening status, and Place IDs to open the matching market details. Home crowd badges remain explicitly labelled demo data. Pull to refresh requests an updated location and reloads the lists.

Home and search validate market details before showing cards: name, address, known opening status, a usable schedule with hours for all seven days, and a usable phone number are required. Markets missing either hours or a phone number are excluded from Nearby, Popular and search, including subsequent search pages. Phone numbers must contain 7–15 digits; a valid national number is accepted when the international number is missing or invalid. Concurrent Home/search validation awaits the same detail request. Crowd charts remain demo estimates; real crowd data is not an eligibility requirement. Unavailable markets are skipped and the next qualifying results fill the sections. Closed markets with known hours remain visible. The Home location label uses the geocoded area and city (city alone if no area is supplied); the country remains in the search query for accuracy but is omitted from Home.

Nearby badges display Low/Mid/High. Home and market details share the same driving-route distance from the current coordinates where Apple Maps routing is available; both use straight-line distance while routing is unavailable. Distances always use km (1.2 km / 0.45 km). Both screens track location changes of roughly 100m while active and recalculate routing, refreshing estimates every five minutes. Tracking stops when neither screen is active. Home omits the crowd demo estimates sentence; market details retain their Demo data badge and simulated percentage labels.

Home caches the last successful Nearby/Popular lists in a shared session store. Returning from details reuses those results without clearing cards or re-running discovery. A city change, gaining/losing coordinates, or moving at least 100m triggers discovery again; pull-to-refresh can explicitly reload. Refresh commits both lists together and preserves existing cards while loading. Home cards show distance only, with no car icon or driving-time row.

### Market descriptions

The market detail About section uses researched descriptions from
`MarketDescriptions.swift`, each with a visible source link. Checked on
22 October 2026. The catalog contains 19 entries across Bengaluru and Amritsar.
The approved Justdial wording is used for Raja Market, Russell Market and the
separate KR Market Flower Market listing. Raja's source is explicitly labelled
as review highlights. The larger KR Market retains its broader, LBB-backed
flower-and-produce description so the flower-market listing is not conflated
with the whole market.

Other researched entries cover Gandhi Bazaar, Jayanagar 4th Block, Chickpet,
Hall Bazaar, Katra Jaimal Singh, Guru Bazaar, Shastri Market, Katra Ahluwalia,
Pratap Bazaar, Tahli Wala Bazaar, Mai Sewa Wala Bazaar, Dal Mandi, Mishri Bazaar,
Urban Haat and Lawrence Road. Sources include Incredible India, LBB,
Karnataka.com and The Tribune. Each entry links to its supporting page.

Descriptions match an existing exact Google Place ID or an explicitly supported
market name together with the city in that listing's address. They never use the
user's current city to identify a market. Every other discovered listing uses
its existing Google Places editorial summary, unchanged, when supplied. If no
summary is supplied, About shows the listing's actual category and address,
with a Google Maps source link. It explicitly states that a main product
specialty is not supplied. This fallback covers new markets and cities without
inventing specialties from market names. It is a listing overview, not a
researched claim about what that market is famous for.

The primary category label is fetched in the existing detail request. No extra
API calls or credentials are required. Unknown categories are not shown as raw
API identifiers. No descriptions are scraped from Justdial at runtime; its
pages often contain only generic business copy, so it cannot guarantee a
specialty description for every market. Missing listing identity retains the
loading/unavailable state. The ambiguous Sunday Market name has no researched
fallback, but real Sunday Market listings can use their own Google data.

```sh
swiftc -module-cache-path /tmp/CrowdStatusSwiftModuleCache Sources/Features/Home/MarketDescriptions.swift Tests/MarketDescriptionChecks.swift -o /tmp/CrowdStatusDescriptionChecks
/tmp/CrowdStatusDescriptionChecks
```
