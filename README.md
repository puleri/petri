# PETRI

PETRI is a single-player, desktop-browser survival game built with Godot 4.7.2 and GDScript. Its main mode, **CULTURE WARS**, treats the discourse as the infection: ragebait germs split into louder opposing takes, platform elites monetize both sides, and the antibiotic protagonist notices who profits. The satire targets inflammatory rhetoric and its incentives—not demographic groups or ordinary people.

You are a soft-edged antibiotic arrow with three health inside a bounded culture dish: move with inertia, shoot germs, manage a rechargeable boost, and survive the debris created by splitting threats. Germ, debris, and high-speed membrane impacts each remove one health, with a short grace period after a hit. Regular germs and bosses one and three use four-layer, tier-colored Meeboid illustrations; surviving hits send a 0.3-second coral flash and ripple through those layers. Pulsing membrane auras telegraph every newly entering germ. When a germ or the player speaks, gameplay freezes for a brief cut scene that eases toward the speaker, types the line into a speech bubble, pulses the speaker inward, then returns to the full arena. Cut scenes are globally limited to roughly 2.5 per minute; lines up to four words receive 2.2 seconds, with another 0.25 seconds for each additional word. Scheduled gold tank elites drop permanent automatic upgrades through item-specific pickup auras. Reaching 50,000 points locks the spawn pipeline until the dish is clear, then introduces a one-time dash boss. Defeating it wipes collected abilities, refills health, upgrades the base weapon to double-damage pellets, and opens a three-boon choice. At 100,000 points, the mint-and-cyan Pewpoid boss fires six large, destructible Boids from rotating body ports and overclocks the weapon from six to nine volleys per second. At 150,000 points, the Meeboid endurance boss retains its ten-shot debris volley and adds an arena-wide contracting ring with a locked safe wedge; defeating it resets abilities, adds one maximum health, refills it, and opens the third boon choice before endless survival resumes.

## Controls

- `WASD` — apply directional force
- Mouse — aim
- Left click — fire (up to six pellets per second, then nine after boss two); hold and release to charge a beam when that boon is owned
- `Space` — boost initially, then control the equipped Dash, Invincibility, Goo Boost, or Freeze boon
- `Escape` — pause/resume
- `R` — restart after game over

Items activate automatically after collection. The twenty-item pool includes spinning hitters, AOE pulses, turrets, ricochet, spread shots, leave-behind mines, faster fire, piercing pellets, a slowing field, a rechargeable contact shell, debris-triggered blasts, and seeking pellets. Eight additional elite drops enlarge projectile coverage, reward repeated hits and long-range shots, create lysis pulses on projectile kills, freeze newly split germs, retaliate after health loss, push surviving targets, and echo periodic volleys. Each item can reach level three; fully maxed builds receive temporary level-four overcharges. After each milestone boss, all twenty item abilities rebuild from level zero while the rewarded base weapon upgrades persist.

After a boss dies, survival time and every hazard/cooldown pause while three distinct boons appear in the dish. They are dim and inactive for two seconds, then remain until touched. You can still move safely during the choice. Boons persist for the current run and may reappear after later bosses to reach level two:

- Dash Evade — invulnerable directional dash on `Space`
- Speed Boosts — improves boost, Dash, and Goo mobility, duration, and recovery
- Point Multiplier — multiplies future score after combo calculation
- Invincibility — timed hostile and membrane pass-through on `Space`
- Goo Trail Boost — boosting deposits pooled damaging goo
- Freeze AOE Shock — freezes regular threats and slows bosses by half on `Space`
- Movement Speed — permanently increases base acceleration and maximum speed
- Charged Beam — hold left click for 1.5 seconds, then release a three-second cursor-tracking beam while pellets continue firing
- Max Health — raises the normal maximum from three to five and fills it immediately; the third-boss bonus raises either value by one

Four boons compete for the active `Space` slot; choosing another replaces the equipped action without erasing the stored level. Boss resets never remove boons. All boon state resets on a new run and is not saved.

## Run locally

Open the project in Godot 4.7.2 or run:

```sh
godot --path .
```

The project uses the Compatibility renderer and contains no threaded gameplay or web dependencies.

## Test

```sh
godot --headless --path . --script tests/run_tests.gd
```

The deterministic suite covers boost timing, combo scoring, germ splits, layered germ texture caches and hit reactions, Pewpoid emitters, Boid trails, collisions, destruction and pooled explosions, Reduced Motion behavior, dialogue cut-scene sequencing, elite cadence, all three milestone boss lifecycles, dash, radial-volley, and contracting-ring behavior, the post-boss selection lockout, all nine boons and their level curves, player health and boss refills, pickup lifecycle, boss ability resets and rewards, all twenty item effects, overcharge, difficulty ramping, persistence, collision outcomes, fixed pools, and scene loading.

## Export for web

Install the Godot 4.7.2 export templates, then run:

```sh
./scripts/export_web.sh
```

This produces the generated deployment artifact in `dist/`. The Web preset explicitly disables thread support, so SharedArrayBuffer headers are unnecessary.

## Deploy with Vercel

```sh
vercel
vercel --prod
```

`vercel.json` publishes `dist/` and gives fixed-name Godot bundles revalidation caching. Local Vercel metadata and generated exports are ignored by Git.

## Connect GitHub later

```sh
git remote add origin <repository-url>
git branch -M main
git push -u origin main
```

No remote is created until a repository URL is supplied.

## Architecture

- `scripts/petri_game.gd` — pooled simulation, layered germ rendering, input, responsive layout, menus, HUD, settings, and run lifecycle
- `scripts/culture_war_dialogue.gd` — deterministic Culture Wars topics, opposing stances, escalation lines, and protagonist/elite commentary
- `scripts/game_math.gd` — deterministic gameplay rules used by runtime and tests
- `scripts/item_data.gd` — public item enum, display specifications, and level curves
- `scripts/boon_data.gd` — public boon enum, labels, colors, level caps, and tuning curves
- `scripts/germ_data.gd` and `data/*.tres` — public `GermTier` data resources
- `scripts/save_store.gd` — `user://petri.cfg` persistence
- `scripts/audio_manager.gd` — runtime-synthesized original SFX and ambient hum, unlocked after user interaction

The runtime preallocates 35 regular germs, one elite, and one shared slot for the 50,000-, 100,000-, and 150,000-point bosses, plus 80 fragments, 480 Boid-trail points (six per fragment slot), 240 projectiles, three turrets, 48 mines, 24 shared ring/explosion effects, eight delayed-volley entries, four pickup/aura slots, three boon-choice entries, and 64 goo patches. Pewpoid, Boids, trails, and explosions use this renderer-owned storage rather than runtime scene nodes. No account, networking, backend, leaderboard, touch controls, or per-projectile node creation is included in v1.
# petri
