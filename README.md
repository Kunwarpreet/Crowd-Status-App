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
Set Alert currently shows an availability notice. Notifications, profile, and
live market data have not been implemented yet. The Home screen, search results,
and market detail data use samples defined in `HomeView.swift`.

## Open and run in Xcode

1. Install Xcode from the Mac App Store if it is not already installed.
2. Open `CrowdStatus.xcodeproj` in Xcode.
3. Select the **CrowdStatus** scheme and an iPhone simulator from the toolbar.
4. Press the Run button or choose **Product > Run**.

The app targets iOS 17 and later and supports iPhone and iPad. You can also
connect an iPhone, select it as the run destination, and run the app there.
