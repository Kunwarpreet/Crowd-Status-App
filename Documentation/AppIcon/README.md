# Crowd Status app icon preview

The new icon is configured locally for Debug and Release through the `AppIcon`
asset catalog. No app build, upload, or distribution was performed.

- Asset: `../../Assets.xcassets/AppIcon.appiconset/AppIcon.png`
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
passes. Build validation is deferred to preserve the requested preview step.
