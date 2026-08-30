# Implementation notes

## Responsive layout

The arena radius is derived every frame from the viewport and receives a 1.3225× play-space scale (15% larger than the previous 1.15× treatment). Every viewport uses the angled mockup-style score, time, boost, rails, and logo composition through a shared responsive unit. Widths below 1024 CSS pixels reserve a top safe area for the keyboard-and-mouse recommendation.

Gameplay HUD typography uses a 0.72× scale treatment. Logo, score, timer, combo, and boost groups transition to 15% opacity when the player or a germ moves behind them. Speech bubbles and floating score/item popups transition to 28% opacity under the same obstruction rule, ignoring a bubble's own speaker.

Dialogue runs as a short simulation-freezing cut scene without adding a camera node or runtime allocations to the actor pools. A deterministic draw transform eases from 1× to 1.58× around the speaking germ or player, holds while the line types in, and eases back before the bubble is cleared and gameplay resumes. Lines of one to four words receive a 2.2-second total duration, with another 0.25 seconds added for every word beyond four; the typewriter rate adapts to finish 0.2 seconds before the speaking phase ends. A 24-second start-to-start gate limits the channel to roughly 2.5 cut scenes per minute, with a due protagonist line taking the next available slot rather than interrupting an active speaker. The focused actor pulses inward by at most 5.5%; the HUD fades to 8% prominence while a subtle tint and letterbox frame separate the beat from active play. Manual pause freezes the cut-scene clock. Reduced Motion keeps the pause and complete line but disables the camera zoom, typewriter reveal, and speaker pulse.

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
- Germ spawn telegraph: 2.5 s pulsing aura before activation
- Split descendants spawn at 75% of their tier's normal velocity
- Item drop telegraph: 0.85 s item-specific aura before pickup activation

## Elite items

- Tank elite: first at 20 s, then every 30 s; radius 66, 18 HP, speed 38–58, 600 score, four debris, no split
- Item aura: 0.85 s; pickup lifetime: 15 s; pickup radius: 18
- Permanent item cap: level 3; all-max drops grant one random 15 s level-four overcharge
- Spinning hitter: 1–4 orbiters at radius 58 and 2.8 rad/s
- AOE: radii 130/150/170/190; intervals 5/4.25/3.5/2.75 s
- Turrets: one per level, 300 range and 0.8 s cadence; overcharge gives 360 range and 0.4 s cadence
- Ricochet: 1–4 membrane bounces with 1.6–2.65 s projectile lifetimes
- Spread: 3/5/7/9 pellets at symmetric 12° steps
- Leave-behinds: 1.4/1.1/0.85/0.6 s mine cadence; 55 radius or 70 while overcharged
- Fixed pools: 36 germs, 80 debris, 240 projectiles, 3 turrets, 48 mines, and 4 pickup/aura slots

## Figma handoff

`Page 1` remains the archive. Four new local variable collections were created: `PETRI / Primitives`, `PETRI / Color`, `PETRI / Layout`, and `PETRI / Typography`. Primitive and semantic palette variables were completed with aliases, scopes, and web code syntax. The Figma Starter-plan MCP quota then prevented the remaining layout variables, reusable components, screens, and source-asset download.

The existing Figma text nodes identify the exact face as `{ family: "Excelorate", style: "Regular" }`, but report `hasMissingFont: true` to the remote plugin. The bundled `Excelorate-Font.otf` is committed and used directly by Godot.

The gameplay HUD uses the approved `assets/figma/petri-logo.png` export. Every viewport uses the archived composition's angled outlined score/time blocks, mint side rails, and lower-right `BOOST / SPACE` charge pill. A shared responsive unit scales and repositions the treatment for standard, wide, and compact layouts without changing its visual language.

When Figma access resumes, continue the design-system ledger from `/private/tmp/design-system-state-petri-v1.json`; do not recreate the completed color variables.
