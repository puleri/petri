# Implementation notes

## Responsive layout

The arena radius is derived every frame from the viewport and receives a 1.3225× play-space scale (15% larger than the previous 1.15× treatment). Every viewport uses the angled mockup-style score, time, boost, rails, and logo composition through a shared responsive unit. Widths below 1024 CSS pixels reserve a top safe area for the keyboard-and-mouse recommendation.

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
- Germ spawn telegraph: 1.02 s pulsing aura before activation
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
- Catalyst: 6.75/7.5/8.5/10 shots per second
- Piercing dose: 1/2/3/5 additional distinct targets per pellet
- Inhibitor field: radii 110/135/160/190; hostile speed multipliers 0.8/0.7/0.6/0.45
- Antibody shell: 32/24/16/8 s recharge; blocks germ and debris contact but not membrane impacts
- Catalytic cleanup: shot debris deals 1 damage at radii 45/60/75; overcharge deals 2 damage at radius 95
- Seeking enzyme: acquisition radii 170/240/320/500; turn speeds 1.2/2/3/5 rad/s
- Fixed pools: 36 germs, 80 debris, 240 projectiles, 3 turrets, 48 mines, 24 effect flashes, and 4 pickup/aura slots

## Figma handoff

`Page 1` remains the archive. Four new local variable collections were created: `PETRI / Primitives`, `PETRI / Color`, `PETRI / Layout`, and `PETRI / Typography`. Primitive and semantic palette variables were completed with aliases, scopes, and web code syntax. The Figma Starter-plan MCP quota then prevented the remaining layout variables, reusable components, screens, and source-asset download.

The existing Figma text nodes identify the exact face as `{ family: "Excelorate", style: "Regular" }`, but report `hasMissingFont: true` to the remote plugin. The bundled `Excelorate-Font.otf` is committed and used directly by Godot.

The gameplay HUD uses the approved `assets/figma/petri-logo.png` export. Every viewport uses the archived composition's angled outlined score/time blocks, mint side rails, and lower-right `BOOST / SPACE` charge pill. A shared responsive unit scales and repositions the treatment for standard, wide, and compact layouts without changing its visual language.

When Figma access resumes, continue the design-system ledger from `/private/tmp/design-system-state-petri-v1.json`; do not recreate the completed color variables.
