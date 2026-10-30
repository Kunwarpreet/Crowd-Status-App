# Crowd Status app icon preview

The new icon is configured locally for Debug and Release through the `CrowdStatusAppIcon`
asset catalog. The original artwork preparation did not include an app build, upload, or distribution.

- Asset: `../../Assets.xcassets/CrowdStatusAppIcon.appiconset/AppIcon.png`
- Concept mockup: `CrowdStatus-Icon-Mockup.png`
- Source supplied by the user: `Crowd Status - App logo.png` (1254 × 1254).
- Prepared asset: 1024 × 1024 RGB PNG, opaque, full bleed. iOS applies the corner mask.

The built-in imagegen tool adapted the supplied artwork to remove the outer white
presentation margin and extend the blue gradient to square corners. This is an
AI-adapted version of the supplied logo, so fine rendering details can differ.
The mockup is an AI-generated concept, not a simulator or device screenshot;
its size labels are illustrative.

Prompt specifications used:

1. Produce a production iOS app icon square texture from the supplied logo.
   Preserve the white 3D location pin, storefront, and ascending green, yellow,
   and red bars. Remove the outer white margin and shadow; fill the square with
   the blue tile and extend its gradient into corners. Keep the artwork centered.
   No rounded corners, white frame, text, mockup, or additional elements.
2. Create a landscape product presentation with a black iPhone showing the icon
   at Home Screen scale, labeled “Crowd Status,” alongside a large icon close-up
   and smaller previews. Use the prepared icon as the reference and preserve its
   artwork. Use a restrained blue wallpaper, an off-white board, and the title
   “Crowd Status,” caption “App icon preview,” and footer “Concept mockup · Not a
   device screenshot.” No app interior or invented features.

Validation: project file passes `plutil -lint`, asset JSON resolves to its PNG,
PNG dimensions and absence of alpha verified with `sips`, and `git diff --check`
passes. Build validation was originally deferred to preserve the requested preview step.

## Notification icon update

The icon set includes explicit iPhone and iPad sizes, including the 20-point
notification icons, all resized from the current 1024-pixel logo. Both Debug and
Release select `CrowdStatusAppIcon`. The new asset name also gives the compiled
icons new resource names when upgrading from the previous `AppIcon` set.

The **Send Demo Preview** banner uses the app icon supplied by iOS; there is no
separate notification logo in the notification payload. Build and install the
updated app before testing a new preview. If iOS still displays a cached icon,
restart the device and send a fresh preview. Reinstalling is a last resort
because deleting the app removes locally saved alert preferences.

Validation of the notification update: unsigned Debug build for generic iOS
succeeded; compiled iPhone and iPad icon metadata selects `CrowdStatusAppIcon`;
all 18 icon slots resolve to opaque PNGs with matching pixel dimensions; project
plist validation and `git diff --check` passed. On-device banner appearance has
not been verified.

### Standalone icon fallback

Debug and Release set `ASSETCATALOG_COMPILER_STANDALONE_ICON_BEHAVIOR = all`
to emit every supported icon size as a standalone PNG as well as keeping it in
`Assets.car`. This makes the notification-sized images available to system
consumers that load loose icon files. The compiled Home Screen icon was decoded
and visually checked against the current blue logo. A successful build does not
verify the device's notification icon cache; test a fresh banner after installing.

Standalone fallback validation: a fresh unsigned generic-iOS Debug build passed.
The bundle contains 17 standalone icon PNGs, including iPhone notification icons
at 2x and 3x. Both iPhone and iPad `CFBundleIconFiles` now list the 20-point icon
family. The packaged 3x notification PNG was decoded and visually verified.
The user confirmed the Home Screen already displays the current blue logo;
notification banner verification with this fallback build remains on-device.

### Unresolved device notification icon

The device still showed the placeholder after both asset updates, while the user
confirmed the current logo on the Home Screen. These changes have therefore not
been verified to fix notification presentation. Avoid further asset changes
without evidence of a packaging error.

Apple acknowledges stale notification icons after app updates and recommends
checking the installed version, restarting, and recording the iOS version and
Home Screen icon appearance before filing a reproducible bug:
https://developer.apple.com/forums/thread/775787

A fresh simulator build also passed. End-to-end simulator notification validation
was blocked because notification permission was not granted and Simulator UI
control was unavailable; delivery was not visually verified.
