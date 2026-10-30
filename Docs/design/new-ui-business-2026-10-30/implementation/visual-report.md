# Native component visual fixture evidence

Completed a bounded macOS SwiftUI `ImageRenderer` fixture using actual production display component source bodies. No application files were changed during this visual subtask.

Artifacts: `/tmp/ddlNew-newUI-5-visuals/`.

- `make_host.py` copies 15 production files and writes source paths/SHA256 to `provenance.json`.
- `ProductionCopies.swift` preserves full production bodies; only `import UIKit` and `import UIAdapter` are removed. No layouts, sizes, strings or view expressions were rewritten.
- `Shims.swift` provides UIKit-style dynamic color providers using NSColor, numeric `.zoom()` returning the original point value, and two anonymous navigation route types. Actual HomeTheme/MessagingTheme/ClubTheme constants and color expressions remain copied from source.
- `Host.swift` injects anonymous activity/profile values, no-op callbacks, fixed tab binding and local SF Symbol avatar. It composes components for observation; this wrapper is not a production screen.
- `render-host` compiled successfully with `xcrun swiftc -parse-as-library`; execution exit 0. `render.log` lists every image and dimension. `outputs.json` records PNG SHA256 and byte sizes.

## Coverage

24 PNGs: `components`, `mine`, `settings` × four configurations × light/dark.

| Configuration | Logical width | Data / environment |
| --- | --- | --- |
| 390 | 390pt | Default dynamic type, ordinary anonymous text |
| 320-a3 | 320pt | Long anonymous activity/title/location/account, accessibility3 |
| 320-a5 | 320pt | Same long text, accessibility5 |
| 768 | 768pt | Default dynamic type, ordinary anonymous text |

`components-*`: actual HomeFeaturedActivity (+ HomeActivityDate), HomeActivityRow, ClubButtonStyle enabled/disabled, MessagingTabs and source themes. `mine-*`: actual MinePageContent with anonymous injected identity. `settings-*`: actual SettingsPageContent with anonymous identity and inert destination.

Inspected directly with view_image: components-390-light/dark, components-320-a5-light, components-320-a3-dark, components-768-dark; mine-390-light, mine-320-a5-dark, mine-320-a3-light, mine-768-light; settings-390-dark, settings-320-a5-light, settings-768-light. The remaining variants were generated in the same deterministic matrix; generation is not a claim of individually inspecting every PNG.

## Observations

- Cobalt/white and adaptive dark colors resolve correctly. Enabled primary buttons have dark text on the pale dark-mode action color; outgoing-bubble behavior is outside this fixture.
- Featured date and identity switch to the explicit vertical accessibility layout branches. Long titles, locations and profile identity wrap without observed overlap or clipping in the inspected images.
- Activity/status/button hierarchy, flat single activity rows, settings entries and destructive logout remain distinguishable. Width768 stretches to the fixture width as requested; production page wrappers apply their existing maximum-content-width separately.
- Selected tabs retain underline and color; disabled button remains visibly subdued. This is static rendering, not touch or selection execution.

## Evidence limits

These are **macOS native production-component fixtures**, not iOS production screen runtime captures. The wrapper omits navigation bars, TabView, safe areas, keyboard, sheet transitions, web captcha, photo picker, SDK state, networking and actual startup storyboard. It does not test callbacks or live data.

macOS accepts the DynamicTypeSize environment and exercises production `isAccessibilitySize` branches, but its system text rendering does not reproduce iOS accessibility font scaling. In this host, a3/a5 output dimensions are identical. Therefore **largest iOS Dynamic Type sizing is not verified**; only narrow long-text wrapping and explicit accessibility layout branches are evidenced. No simulator/device/full-project build was used in this subtask. Integrated iOS compilation is a separate root-agent gate.

While preparing the host, source review found enabled white text in Task3 LoginButtonStyle/InvitationCodeButtonStyle could conflict with the adaptive pale dark-mode primary action. Reported to root to change their foreground to MessagingTheme.onPrimaryAction; those controls are not part of this fixture and no app code was edited here.
