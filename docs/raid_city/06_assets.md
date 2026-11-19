# 6. Asset reuse: three groups

[Index](../raid_city_design.md) · prev: [5. Tech](05_tech_and_budgets.md) · next: [7. Build plan](07_build_plan.md)

The rule from Michael: **reuse most existing assets as-is, or upgrade them to fit, before building anything new.**
New art is mid-to-high poly (budgets in [5. Tech](05_tech_and_budgets.md) §5.6).
**Group 2 is Artie's**: Artie owns the city and vehicle art; integration, tests and merges stay with the code side, per TASKS item 7.

## Group 1: reuse as-is

| Asset / system | Path | City / region use |
|---|---|---|
| Cargo containers and stacks (olive, sand; intact, dented, pallet) | `raid/assets/cargo/*.glb`, `raid/scripts/cargo_scenery.gd` | Industrial docks, truck depot, salvage yard |
| Loot caches | `raid/assets/props/loot_cache_*.glb`, `raid/scripts/raid_props.gd` | Region stashes, outposts, the cave behind the falls |
| Salvage items (6) | `raid/assets/salvage/*.glb` | Salvage job, crashed ship, pawn-shop stock |
| Keys, cards, logbooks, clipboards, supply stands | `raid/assets/field_supplies/*.glb`, `raid/scripts/field_supplies.gd` | Sewer and tunnel keys, intel items, job paperwork |
| Lever and valve puzzles | `raid/assets/puzzle_controls/*.glb`, `raid/scripts/puzzle_controls.gd` | Substation power cut (bank step b), electrician job |
| Campus / annex / archive sites | `raid/scripts/glasskiln_campus.gd`, `raid/scripts/research_annex.gd` + `raid/assets/research_annex/`, `raid/scripts/obsidian_archive.gd` + `raid/assets/obsidian/` | Region outposts and the crashed-ship site, as today's wild-raid content |
| Ship, pad, takeoff cutscene | `assets/kit/launchpad_ship.glb`, `assets/midstyle_rollout2/launchpad_*.gltf`, `raid/scripts/ship_takeoff_*.gd` | Drop zones (city pad, town pad) |
| Gear T1–T4, visors, default outfit | `raid/scripts/gear_tiers/*`, `raid/assets/outfit/`, Artie gear handoffs | Player gear in the city; armor vs police |
| Sentry turret logic | `raid/scripts/sentry_turret.gd` | Bank security turret, anti-air (logic only; the mesh is upgraded in group 2) |
| Hazard zone | `raid/scripts/hazard_zone.gd` | Substation live-cable hazard, sewer hazards |
| Health and HUD | `raid/scripts/health_component.gd`, `raid_health_controller.gd`, `raid_health_hud.gd` | Same health model in the city |
| Foliage (Quaternius, kit trees/shrubs, planting sets) | `assets/quaternius/*.gltf`, `assets/kit/border_*`, `assets/planting_dense/`, `raid/scripts/biome_foliage.gd`, `raid/scripts/vegetation_meshes.gd` | Region countryside, park, suburbs |
| Grass and culling | `assets/settlement_grass_v086/`, `raid/scripts/grass_view_culling.gd` | Park and suburb lawns (with culling) |
| Far scenery and distant hills | `raid/scripts/far_scenery_options.gd`, Artie `distant_hills` handoff | Region horizon |
| Raid audio | `raid/audio/*.wav`, `raid/scripts/raid_audio.gd` | Beacons, access denied, extraction cues |
| Wildlife | `assets/wildlife/*.glb`, `scripts/ambient_wildlife.gd` | Park and countryside ambience |

## Group 2: upgrade or retheme (Artie)

Changes are near-future trims, new materials, neon or emissive accents, and city signage.

| Asset | From | Changes |
|---|---|---|
| Extraction beacons → civilian and criminal extract markers | `raid/assets/props/extraction_beacon_*.glb` | Bus-stop totem, toll gantry light, smuggler lantern, sewer hatch beacon; colour coding (green civilian, red criminal) |
| Canopy stall | `assets/kit/canopy_stall.glb` | Neon Market street stalls: LED strips, holo price signs, awning fabric variants |
| Plaza bench, lantern, planter | `assets/kit/plaza_bench.glb`, `lantern.glb`, `planter.glb` (+ Artie's `screens_planters` handoff) | Street furniture: steel and composite trims, LED lamp heads, concrete planters |
| Fountain | `assets/kit/fountain.glb`, `fountain_apron.glb` | City Park fountain; bigger basin, stone and brass |
| Retaining walls kit | Artie `retaining_walls` handoff | River embankments, bridge abutments, highway cuts |
| Request board | `assets/midstyle_rollout2/request_board.gltf` (+ Artie `request_board_woven`) | City job board / fixer board; screen panel and emissive |
| Sentry turret mesh | primitive-built in `raid/scripts/sentry_turret.gd` | Modelled bank turret and anti-air battery (LOD0 ~8k) |
| Trader and staff NPC bodies | `assets/npc_coverage/*.glb` (gitignored), `scripts/staff_fit.gd`, `scripts/staff_role_materials.gd` | Civilians, shopkeepers, police and security uniforms via role materials; **needs rigging and animation** (C12) |
| Vendor desk, west trader, trader frontage | `assets/kit/vendor_desk.glb`, `west_trader.glb`, `trader_frontage.glb` | Pawn shop counter, diner counter, kiosk fronts |
| Hall and inn architecture | `assets/hall_v098/`, Town Hall kit (`assets/kit/town_hall.glb`) | Small-town sheriff office and motel: weathered, dry palette |
| Lake shaders | `shaders/inn_lake_v088.gdshader`, `shaders/lake_bank_v089.gdshader` | River, park lake, waterfall pool |
| Cargo containers | `raid/assets/cargo/*` | Corporate liveries, clean and neon variants for downtown loading bays |
| Market detail props | `assets/market_detail/*.glb` (`psy_expedition_pack`, `atlas_returns`, ...) | Pawn-shop and grocery shelf dressing |

## Group 3: new builds, in priority order

| # | Asset | Why first | Notes |
|---|---|---|---|
| 1 | **Bank** (Central Bank exterior + lobby + vault, and a small-town bank variant) | Rung 4–5 heists; landmark dome | Exterior streamed separately from the interior; vault door with drill points |
| 2 | **ATM** | Rung 1; dozens of placements | 2 variants (wall, kiosk); screen emissive; damaged state |
| 3 | **Grocery store** (with interior and back-room safe) | Rung 2; mockup street view | Shelf MultiMesh; checkout till; corner-store variant for suburbs and town |
| 4 | **Bridges** (suspension B1, truss B2, concrete B3) | Chokepoints; district links | 19–20 m and ~10 m decks (§3.5); police-block props |
| 5 | Road and street kit (lanes, curbs, crosswalks, signs, stop signs, traffic lights, guardrails, dirt roads) | Needed by everything with vehicles (TASKS item 20) | Trim-sheet based, so draw calls stay low |
| 6 | Modular city building kit (facades, storefronts, roofs) + tower impostors | Fills districts | Merged per block; impostors at 800 m |
| 7 | Vehicles: sedan, scooter, police cruiser | Phase 2 | Damage part swaps, colour palette |
| 8 | Vehicles: SUV, van, motorcycle, cargo truck, taxi, bus | Phase 3 | |
| 9 | Pawn shop, diner, arcade, gas station | Neon Market completion | |
| 10 | Police station / HQ, hospital | City spawns, jobs | |
| 11 | Corporate tower | Downtown silhouette, rooftop pickup | |
| 12 | Statue landmark on the mountain | Region Phase 4 | LOD + impostor (§2.5) |
| 13 | Waterfall + cave, park gazebos and footbridges | POIs | Water shaders (§5.4) |
| 14 | Toll booth, bus and train stations, sewer entrance, dock smuggler boat | Extracts | |
| 15 | Hover car, flying car, landing pads, air-lane markers | Phase 5 | |
| 16 | Character animation set (locomotion, flee, hands-up, drive, shoot) | NPCs and the player (C12) | Can be bought or retargeted (mixamo-style licence check) |
