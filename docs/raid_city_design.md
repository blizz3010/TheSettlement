# Raid City design: crime-and-extraction raids in a sci-fi region

Status: **draft for review** (queue item 6). Docs only; no game code changes. Branch `docs/raid-city-design` off main `f618de2`.
Sources: TASKS.md item 6 (base list), Michael's later additions via Ori (Nov 19 2026), and the mockups in [`raid_city/mockups/`](raid_city/mockups/README.md).
Where the later additions replace earlier notes, the later version is used:

- the death rule
- separate civilian and criminal extracts
- the GTA V-style region with a big city in the south and a small town in the north
- the three-group asset reuse split

## In one paragraph

The Settlement stays home base. The city is a **new raid type** reached by the same ship.
You **drop in as a civilian** and can earn safely through civilian jobs. To kill or steal you must first **flag** yourself.
Flagging turns on a **heat 0–5** wanted system with security, police waves, bridge blocks and extracts that close at max heat.
Heists climb a ladder from **ATMs and grocery stores to the Central Bank**. **Civilians who die keep their loot; flagged players who die lose everything they carried.**
Civilian and criminal players leave by **different extracts**. One **4 × 6 km region** holds a big city in the south, a small rough town in the north,
and countryside, a statue mountain, a waterfall forest and a highway between them that shows off the vehicles.
The plan starts with **one city district** and ends with flying cars and parties.

## Sections

| # | File | Covers |
|---|---|---|
| 1 | [Core loop and rules](raid_city/01_rules_and_loop.md) | Loop; what civilians can do safely; flagging (how, how long, what others see); heat 0–5 and police waves; civilian vs criminal extracts; death rule; heist ladder; civilian jobs; payout comparison and risk vs reward |
| 2 | [World layout](raid_city/02_world_layout.md) | GTA V-style region (city south, town north) with the top-down sketch; map scale vs vehicle speeds; city districts; bridges as chokepoints; landmarks; park and waterfall POIs; the Phase 1 slice |
| 3 | [Vehicles](raid_city/03_vehicles.md) | Roster and roles; briefcase vehicles; build order; flying cars, air lanes, anti-air; road and bridge widths; damage; upgrade tree; civilian traffic and AI, carjacking |
| 4 | [Systems integration](raid_city/04_systems_integration.md) | Mermaid system diagram; existing systems with real files (quests, skills, character creation, stats, building, traders, looting, crafting, resources and items, ship); trader heist contracts; resource economy vs current item code; **conflicts C1–C18**; gaps; parties and clans |
| 5 | [Tech and budgets](raid_city/05_tech_and_budgets.md) | Godot terrain options (own heightmap vs Terrain3D vs static meshes); streaming and chunks; LOD, impostors, occlusion; water and waterfall; foliage budget; low-end hardware budgets and poly budgets |
| 6 | [Assets](raid_city/06_assets.md) | Group 1 reuse as-is; group 2 upgrade or retheme (Artie); group 3 new builds in priority order (bank, ATM, grocery, bridges, ...) |
| 7 | [Build plan](raid_city/07_build_plan.md) | Phases 0–6, starting with one district (Neon Market + bank block + bridge B2) |
| 8 | [Open questions](raid_city/08_open_questions.md) | 23 questions for Michael, with proposed defaults |

Also included: [`raid_city/region_sketch.png`](raid_city/region_sketch.png) (generated top-down sketch; script in `raid_city/tools/region_sketch.py`) and the four mockups.
The `raid_city/.gdignore` file keeps Godot from importing any of it.

## Top decisions needed (from §8)

1. **Q1.** Does the new death rule also apply to wild raids? Today Relay Ridge and Cinder Basin lose the haul and keep gear (conflict C1).
2. **Q2.** Unflagging mid-raid: proposed after heat clears plus a 120 s cooldown, with no stolen items on you.
3. **Q3.** Does a flagged death lose the briefcase vehicle? Proposed: yes, unless insured.
4. **Q5.** Flagged players can kill civilians; the civilian keeps their loot.
5. **Q13.** Visor rule: the visor shows only on a same-tier helmet, and its stats always apply.
6. **Q21.** Combat design. There are no player weapons yet, and flagging depends on them.

## Biggest conflicts with current code (from §4.5)

- **C1 death rule:** `raid/scripts/raid_loot/raid_loot_install.gd` (a downed raid loses the haul), `raid/scripts/atlas_recovery_service.gd` (carried items held for a fee), and `raid/scripts/gear_tiers/gear_defs.gd` `DOWNED_DURABILITY_LOSS` (gear kept) all differ from "civilian keeps all / flagged loses all".
- **C10 no weapons or combat** (`scripts/equipment_catalog.gd` has empty weapon slots). **C12 no NPC AI or animation.** **C13 no vehicles or roads.**
- **C5 two closed item registries** (`scripts/inventory_state.gd`, `raid/scripts/raid_loot/loot_table.gd`). **C6/C7 stats and skills not applied.** **C8/C9 one quest and one recipe.**
- **C14 Compatibility renderer** (no SSR, so the neon reflections must be faked). **C15 trimesh terrain** won't scale. **C16 adding a native plugin** collides with the pinning and import policy.

## Coverage checklist (every input item → section)

| Input | Section |
|---|---|
| Settlement stays home base; extraction runs with GTA-style crime in sci-fi cities | 1.1 |
| Core rule: drop in as a civilian, flag before you can kill or steal | 1.2, 1.3 |
| What civilians can do safely | 1.2 |
| Flagging: how it turns on, whether it lasts until extract, what others see | 1.3, Q2 |
| Wanted level, security and police waves, extracts closing at max heat | 1.4, 1.5 |
| Heist jobs from traders | 1.7, 4.3 |
| What you lose on death (**replaced** by Michael's death rule) | 1.6, C1, Q1–Q7 |
| Hover-car getaways on the planned roads (item 20) | 3.1–3.5 |
| First city district with heists of several difficulties | 2.7, 7 (Phase 1) |
| Risk versus reward | 1.9 |
| Open questions for Michael | 8 |
| Civilian job track and payout comparison | 1.8, 1.9 |
| Heist ladder: grocery and ATM quick and low-heat, bank big and multi-step | 1.7 |
| Bridges: chokepoints, police blocks, district links | 2.4 |
| Asset reuse; new assets in priority order (bank, ATM, grocery, bridges); mid-to-high poly | 6, 5.6 |
| Vehicle roles; flying cars (air lanes, anti-air at banks); road and bridge widths; ground first, flying last | 3.1, 3.3–3.5 |
| Keep quests, skills, character creation, stats, building, traders, looting; city is a new raid type; the loop | 1.1, 4.1, 4.2 |
| Map types (wild = materials, city = money); districts and bridges; quests across maps; skills by use; stats; garage later | 1.1, 2.3, 4.2, 4.4, 3.2 |
| One connected diagram; flag conflicts with code | 4.1, 4.5 |
| Traffic variety, traffic AI, carjacking with flag and heat, density budget | 3.8, 5.6 |
| Map scale vs vehicle and flying speeds and getaways; Settlement size; streaming, LOD, impostors, occlusion, detail at heist sites; one district first | 2.2, 5.2, 5.3, 7 |
| Parties, clans, networking, impact on single-player code, design for now | 4.7, 7 (Phase 6), Q22–Q23 |
| Ship and briefcase vehicles (deploy time, flagged or mid-chase, death, size and weight, carjacking, garage) | 3.2, Q3, Q9 |
| City layout mockup (river, 3 bridges, districts, police, drop zone, 3 extracts) | 2.3, 1.5, mockups |
| Open region, terrain tech, streaming, LOD, foliage budget, revised scale, phases | 2.1, 2.2, 5, 7 |
| Landmarks (statue; stash, lookout, quest, landing; LOD and impostors) | 2.5, 6 (group 3 #12) |
| Other POIs: Central Park-style park, waterfall forest with cave stash; water shaders and foliage budget | 2.6, 5.4, 5.5 |
| Resource economy mapped against current item code with gaps | 4.4, C5 |
| Death rule (civilian keeps, flagged loses all) and its questions | 1.6, Q1–Q8 |
| Vehicle damage | 3.6 |
| Vehicle upgrades (4 tiers, effects, crafted or bought, garage, briefcase, flagged death) | 3.7, Q10 |
| Civilian jobs (Ori's draft), starter set of 4–5 | 1.8 |
| Separate extracts; flagged at civilian exits; replace the mockup's 3 extracts | 1.5, Q8 |
| GTA V-style region (big city south, small town north) with a top-down sketch | 2.1, `region_sketch.png` |
| Mockups as layout references | `raid_city/mockups/` |
| Asset reuse in three groups (Artie takes group 2) | 6 |
| Unflag cooldown, briefcase on death, visor rule (open questions) | Q2, Q3, Q13 |
