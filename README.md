# PETRI

PETRI is a single-player, desktop-browser survival game built with Godot 4.7.2 and GDScript. Its main mode, **CULTURE WARS**, treats the discourse as the infection: ragebait germs split into louder opposing takes, platform elites monetize both sides, and the antibiotic protagonist notices who profits. The satire targets inflammatory rhetoric and its incentives—not demographic groups or ordinary people.

You are an antibiotic particle inside a bounded culture dish: move with inertia, shoot germs, manage a rechargeable boost, and survive the debris created by splitting threats. Pulsing membrane auras telegraph every newly entering germ. Scheduled gold tank elites drop permanent automatic upgrades through item-specific pickup auras.

## Controls

- `WASD` — apply directional force
- Mouse — aim
- Left click — fire (up to six pellets per second)
- Hold `Space` — boost acceleration and maximum speed
- `Escape` — pause/resume
- `R` — restart after game over

Items activate automatically after collection. Spinning hitters, AOE pulses, turrets, ricochet, spread shots, and leave-behind mines can each reach level three; fully maxed builds receive temporary level-four overcharges.

Space is exclusively boost. There is no syringe action.

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

The deterministic suite covers boost timing, combo scoring, germ splits, elite cadence, pickup lifecycle, all six item effects, overcharge, difficulty ramping, persistence, collision outcomes, fixed pools, and scene loading.

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

- `scripts/petri_game.gd` — pooled simulation, input, responsive rendering, menus, HUD, settings, and run lifecycle
- `scripts/culture_war_dialogue.gd` — deterministic Culture Wars topics, opposing stances, escalation lines, and protagonist/elite commentary
- `scripts/game_math.gd` — deterministic gameplay rules used by runtime and tests
- `scripts/item_data.gd` — public item enum, display specifications, and level curves
- `scripts/germ_data.gd` and `data/*.tres` — public `GermTier` data resources
- `scripts/save_store.gd` — `user://petri.cfg` persistence
- `scripts/audio_manager.gd` — runtime-synthesized original SFX and ambient hum, unlocked after user interaction

The runtime preallocates 35 regular germs plus one elite, 80 fragments, 240 projectiles, three turrets, 48 mines, and four pickup/aura slots. No account, networking, backend, leaderboard, touch controls, or per-projectile node creation is included in v1.
# petri
