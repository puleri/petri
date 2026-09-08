# Implementation notes

## Responsive layout

The arena radius is derived every frame from the viewport and receives a 1.3225× play-space scale (15% larger than the previous 1.15× treatment). Every viewport uses the angled mockup-style score, time, boost, concentric playspace backdrop, and logo composition through a shared responsive unit. The backdrop follows the supplied artwork with a mint field, a pale outer circle at 1.44× the dish radius, and a soft inset shadow spanning the outer 20% of the white dish. Widths below 1024 CSS pixels reserve a top safe area for the keyboard-and-mouse recommendation.

Gameplay HUD typography uses a 0.72× scale treatment. Logo, score, timer, combo, and boost groups transition to 15% opacity when the player or a germ moves behind them. Speech bubbles and floating score/item popups transition to 28% opacity under the same obstruction rule, ignoring a bubble's own speaker.

Dialogue runs as a short simulation-freezing cut scene without adding a camera node or runtime allocations to the actor pools. A deterministic draw transform eases from 1× to 1.58× around the speaking germ or player, holds while the line types in, and eases back before the bubble is cleared and gameplay resumes. Lines of one to four words receive a 2.2-second total duration, with another 0.25 seconds added for every word beyond four; the typewriter rate adapts to finish 0.2 seconds before the speaking phase ends. A 24-second start-to-start gate limits the channel to roughly 2.5 cut scenes per minute, with a due protagonist line taking the next available slot rather than interrupting an active speaker. The focused actor pulses inward by at most 5.5%; the HUD fades to 8% prominence while a subtle tint and letterbox frame separate the beat from active play. Manual pause freezes the cut-scene clock. Reduced Motion keeps the pause and complete line but disables the camera zoom, typewriter reveal, and speaker pulse.

Target compositions are 1280×720, 1920×1080, and 2560×1080.

## Germ visuals

Regular germs, the elite, and bosses one and three are drawn from the four concentric `Meeboid-4.png` through `Meeboid-1.png` layers; `Meeboid.png` remains a composite preview. Startup builds six hue-shifted, mipmapped Meeboid texture sets while preserving the original alpha and relative shading: cyan for large/small, lavender for medium, orange for the elite, dark purple for the first boss, and midnight purple for the third boss. Their 238-pixel outer layer scales to each existing gameplay radius, so collision geometry and tier statistics remain unchanged.

Boss two instead uses the four original-color `Pewpoid-1.png` through `Pewpoid-4.png` layers and its own cached flash masks. The authored body renders at the existing 100-pixel collision radius and rotates at 0.5 radians per second. The six warning rays and Boid spawn positions use the exact authored Pewpoid emitter offsets, rotated and scaled with the body. Boss two's six Boids use the shared 80-entry debris pool, a 0.25 visual scale, a 27.5-pixel collision radius, no spin, and the supplied staggered one-second layer pulse. Elite and boss identity rings, health arcs, dash tells, volley warnings, and the contracting-ring tell continue to render around the illustrated bodies.

Every debris slot owns six fixed trail samples, for 480 `Vector2` entries total. Active Boids add a sample after each seven pixels of travel and draw tapered copies of `ParticleMask-Soft.png` behind the body. Destroying or consuming a Boid requests a four-particle, 0.4-second lavender explosion from the existing 24-entry effect pool; a full pool drops the visual without changing gameplay. Reduced Motion removes the Boid layer pulse, trail warble, and explosion displacement while preserving movement, trails, collision, and all attack timing. The Pewpoid, Boid, trail, and explosion scenes remain editor previews only and are never instantiated by gameplay.

The custom canvas renderer uses a fixed painter's order instead of allocating separate z-indexed sprite nodes. Hostiles render from largest to smallest—third boss, second boss, first boss, elite, large, medium, small, then debris—so the smallest threats remain visible when bodies overlap. Pellets and the player continue to render above the hostile stack.

Each pooled germ stores one hit-reaction timer. A surviving hit restarts the supplied 0.3-second outer-to-inner 1.1× layer ripple and a coral flash that peaks at 0.05 seconds and clears by 0.25 seconds. Killing blows still split or disappear immediately. The renderer evaluates these curves directly from pooled state—there are no germ child nodes or per-hit tweens. Reduced Motion clears active hit reactions and suppresses both ripple and flash; future hits animate normally if the preference is disabled again.

The player body uses the soft-edged `P1.png` arrow. Its upward-facing source artwork is rotated 90 degrees into the aim direction and rendered at a 39.1-pixel source width (15% smaller than its initial treatment) while preserving the existing 18-pixel collision radius, dialogue pulse, boost trail, spawn-protection ring, and weapon-upgrade indicators.

## Gameplay constants

- Base acceleration: 360 px/s²
- Base maximum speed: 190 px/s
- Boost: 1.8× acceleration, 1.5× maximum speed
- Boost timing: 2 s drain, 0.5 s delay, 3 s recharge
- Fire rate: 6 pellets/s; 1.25 s lifetime
- Spawn protection: 1.5 s
- Player health: 3; unprotected germ, debris, and lethal membrane impacts remove 1 health and grant 1 s of post-hit grace
- Lethal membrane impact: outward speed over 240 px/s
- Debris lifetime: 12 s
- Non-boss base movement: large 38.4–60.8, medium 52.8–78.4, small 70.4–105.6, and elite 30.4–46.4 px/s; the existing late-run multiplier still caps at 1.5×
- Germ spawn telegraph: 2.5 s pulsing aura before activation
- Split descendants spawn at 75% of their tier's normal velocity
- Item drop telegraph: 0.85 s item-specific aura before pickup activation
- Tank elites: first at 5 s, then every 10 s
- Boss threshold: 50,000 points; spawning pauses until all active germs and debris are gone
- Boss: radius 88, 240 HP, speed 32–44, 5,000 base score, no split or debris
- Boss dash: 2.5 s initial delay, 0.9 s direction-lock tell, 0.6 s at 420 px/s, 3 s cooldown
- Boss reward: reset all item state, refill health to the current maximum, grant 2-damage player pellets for the remainder of the run, then enter boon selection
- Second boss threshold: 100,000 points, using the same clear-dish entry gate and reserved boss slot
- Second boss: radius 100, 600 HP, speed 36–48, 10,000 base score, no split or death debris; renders as the original mint/cyan Pewpoid
- Second-boss volley: first available after 4.5 s of chase time; 0.9 s tell; six Boids at 220 px/s, 6 s lifetime, and one bounce; 6 s cooldown
- Second boss reward: clear volley debris, reset all item state, refill health to the current maximum, retain 2-damage pellets, increase the player fire rate from 6 to 9 volleys/s, then enter boon selection
- Third boss threshold: 150,000 points, using the same clear-dish entry gate and shared reserved boss slot
- Third boss: radius 120, 2,200 HP, speed 38–48, 25,000 base score, no split or death debris; retains the existing dash and radial volley
- Third-boss volley: ten ordinary debris with the same 0.9 s tell, 220 px/s speed, 6 s lifetime, one bounce, and 6 s cooldown
- Contracting ring: first available after 7 s of chase time; 1.1 s stationary warning with a locked 60-degree safe wedge; an 18-pixel ring contracts from membrane to center over 1.4 s and repeats after 7 s of chase time
- Third boss reward: clear volley/ring state, reset all item state, retain the 2-damage/9-volley weapon, add one run-only maximum health, refill health, then enter boon selection

## Post-boss boons

Boss death applies its reward immediately, marks that boss defeated, clears all transient Space/beam/freeze/goo effects, stops player momentum, and enters `BOON_SELECTION`. The three-choice pool is filled with distinct, non-maxed boon types and placed 120 pixels from the arena center (or `arena_radius - 48` in a smaller dish). Choices are collision-inactive for exactly two seconds and never expire. During this state only safe WASD movement advances: run time, pellets, hazards, item timers, cooldowns, dialogue, and spawning remain frozen. Collecting one choice clears all three entries, restarts the elite timer, and either resumes survival or begins the next already-earned cleanup stage. `COMPLETED` is reached only after the third boss's boon is chosen.

`BoonData.BoonType` exposes nine run-only boons. Eight have a two-level cap; Max Health has one level because it immediately establishes the five-health maximum. Space boons share one equipped slot while retaining their individual stored levels; Charged Beam layers onto left click and passive boons need no input. Item resets do not remove boons, but `_start_run()` clears every boon level, restores three health, and resets transient fields without touching the save format.

- Dash Evade: 600 px/s for 0.18 s with a 2.5 s cooldown; level two is 700 px/s for 0.22 s with a 2 s cooldown. Direction uses held movement or aim fallback, contact is invulnerable, and membrane contact ends the dash safely.
- Speed Boosts: active-mobility speed +15%/+30%, duration +10%/+20%, and recovery 15%/30% faster. It affects the original boost, Dash, and Goo Boost; offers omit it while Invincibility or Freeze occupies Space.
- Point Multiplier: 1.5×/2× future score after combo multiplication.
- Invincibility: 2 s with a 12 s cooldown, then 3 s with a 10 s cooldown; hostile, debris, and membrane contact pass through harmlessly.
- Goo Trail Boost: the normal boost deposits radius-24, 4-second patches every 0.15 s. Level two uses 2× acceleration, 1.7× maximum speed, radius 28, 5-second patches, and a 0.12 s cadence. Goo deals one damage per hostile at most every 0.45 s and can destroy score-bearing debris.
- Freeze AOE Shock: radius 180 for 3 s with a 10 s cooldown, then radius 220 for 4 s with an 8 s cooldown. Regular germs and debris stop completely; bosses and their attack timers advance at 50% speed.
- Movement Speed: base acceleration and maximum speed +15%/+30%.
- Charged Beam: holding fire for 1.5 s prepares a three-second cursor-tracking beam without interrupting pellet autofire. Early release cancels. Beam ticks every 0.2 s for 4 damage at width 18, or 6 damage at width 24 on level two.
- Max Health: raises the normal current and maximum health from three to five when selected. The third-boss reward adds one to either capacity, producing four or six maximum health. Both upgrades persist through ability resets and reset with a new run.

The top-center segmented health bar supports three through six health. The lower-right HUD changes from `BOOST / SPACE` to the active Space-boon name and cooldown/charge state. Owning Charged Beam adds a separate `BEAM / HOLD FIRE` meter. Reduced Motion preserves every timing and gameplay tell—including ring contraction—while removing boon pulses, goo wobble, beam flicker, and decorative ring pulsing.

## Elite items

- Tank elite: first at 5 s, then every 10 s; radius 66, 18 HP, speed 30.4–46.4, 600 score, four debris, no split
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
- Boids: radius 27.5 versus the ordinary debris defaults of 8 for contact and 10 at the membrane. Player attacks and abilities destroy them for the normal 10 debris points and Catalytic Cleanup interactions. Player contact always consumes them but protection prevents damage; timeout, final membrane impact, contact, boss cleanup, and run reset grant no score.
- Fixed pools: 37 germs (35 regular, one elite, one shared milestone-boss slot), 80 debris, 480 Boid-trail points, 240 projectiles, 3 turrets, 48 mines, 24 shared ring/explosion effects, 4 pickup/aura slots, 3 boon choices, and 64 goo patches

## Figma handoff

`Page 1` remains the archive. Four new local variable collections were created: `PETRI / Primitives`, `PETRI / Color`, `PETRI / Layout`, and `PETRI / Typography`. Primitive and semantic palette variables were completed with aliases, scopes, and web code syntax. The Figma Starter-plan MCP quota then prevented the remaining layout variables, reusable components, screens, and source-asset download.

The existing Figma text nodes identify the exact face as `{ family: "Excelorate", style: "Regular" }`, but report `hasMissingFont: true` to the remote plugin. The bundled `Excelorate-Font.otf` is committed and used directly by Godot.

The gameplay HUD uses the approved `assets/figma/petri-logo.png` export. Every viewport uses the archived composition's angled outlined score/time blocks, concentric mint playspace rings, and lower-right dynamic `SPACE` ability pill, plus a beam meter when owned. A shared responsive unit scales and repositions the treatment for standard, wide, and compact layouts without changing its visual language.

When Figma access resumes, continue the design-system ledger from `/private/tmp/design-system-state-petri-v1.json`; do not recreate the completed color variables.
