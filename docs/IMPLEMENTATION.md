# Implementation notes

## Responsive layout

The arena radius is derived every frame from the viewport and receives a 1.15× play-space scale. At ultrawide aspect ratios, angled dark-mint rails hold the side HUD. At standard and compact desktop ratios, counters remain in anchored top corners and the boost meter sits below the arena. Widths below 1024 CSS pixels show the keyboard-and-mouse recommendation.

Target compositions are 1280×720, 1920×1080, and 2560×1080.

## Gameplay constants

- Base acceleration: 360 px/s²
- Base maximum speed: 190 px/s
- Boost: 1.8× acceleration, 1.5× maximum speed
- Boost timing: 2 s drain, 0.5 s delay, 3 s recharge
- Fire rate: 6 pellets/s; 1.25 s lifetime
- Spawn protection: 1.5 s
- Lethal membrane impact: outward speed over 240 px/s
- Debris lifetime: 12 s
- Spawn telegraph: 0.85 s pulsing aura before activation

## Figma handoff

`Page 1` remains the archive. Four new local variable collections were created: `PETRI / Primitives`, `PETRI / Color`, `PETRI / Layout`, and `PETRI / Typography`. Primitive and semantic palette variables were completed with aliases, scopes, and web code syntax. The Figma Starter-plan MCP quota then prevented the remaining layout variables, reusable components, screens, and source-asset download.

The existing Figma text nodes identify the exact face as `{ family: "Excelorate", style: "Regular" }`, but report `hasMissingFont: true` to the remote plugin. The bundled `Excelorate-Font.otf` is committed and used directly by Godot.

The gameplay HUD uses the approved `assets/figma/petri-logo.png` export. Wide layouts follow the archived composition with angled outlined score/time blocks and a lower-right `BOOST / SPACE` charge pill; standard layouts retain anchored corners for readability.

When Figma access resumes, continue the design-system ledger from `/private/tmp/design-system-state-petri-v1.json`; do not recreate the completed color variables.
