# 7. Phased build plan (start with one city district)

[Index](../raid_city_design.md) · prev: [6. Assets](06_assets.md) · next: [8. Open questions](08_open_questions.md)

Each phase lands as review-only PRs with tests and before/after shots, the same way as the current queue.
Ground vehicles come first and flying comes last. The Settlement isn't resized.

| Phase | Scope | Depends on | Exit criteria |
|---|---|---|---|
| **0. Decisions + spikes** | Michael answers the top open questions (§8). Tech spikes: (a) Terrain3D 1.1 vs own heightmap on min-spec; (b) `VehicleBody3D` arcade sedan in a test scene; (c) animated NPC crowd cost in Compatibility (20/45/80 peds); (d) combat prototype (one sidearm, hitscan like `sentry_turret.gd`) | — | Written spike results with frame times; terrain choice; weapon/combat design note |
| **1. First district: Neon Market + bank block + bridge B2** | New raid id in `raid_catalog.gd`; city map adapter on `raid_world.gd`; civilian drop at the city pad; **flag + heat 0–3**; police on foot and in kinematic cars; ATMs (rung 1), grocery (rung 2), pawn shop (fence, rung 3); Central Bank *exterior* + lobby (vault later); 2 civilian + 2 criminal extracts; **death rule v2** (C1, C2); civilian jobs: courier on foot, salvage, repairs; ambient kinematic traffic; streaming of 128 m blocks | Phase 0; weapons (C10); NPC animation (C12); new items (C5) | One full loop: drop as a civilian, job or ATM/grocery, flag, chase, extract; the suite and a city test pass; budgets in §5.6 met on min-spec |
| **2. Drivable ground vehicles + bank heist** | Sedan, scooter, police cruiser; briefcase deploy/pack; vehicle damage; heat 4–5 with bridge blocks; **Central Bank multi-step heist** (rung 5); delivery driver job; security-guard job intel; garage station v1 at the Settlement (repair, store) | Phase 1; road kit (item 20) | Bank heist solo-able in ≤ 20 min; vehicle chase over B2 |
| **3. Rest of the city** | Downtown towers (impostors) + corporate tower, Suburbs + City Park, Industrial Docks, Police HQ + hospital; bridges B1, B3; SUV, van, motorcycle, truck, taxi, bus; dock smuggler, rooftop pickup (ground), tunnel; traffic lights and full traffic AI | Phase 2 | Full city playable; all 3 bridges as chokepoints |
| **4. Region + small town** | 4 × 6 km region on the chosen terrain tech; highway; small town (corner store, ATMs, small bank, sheriff, motel, fixer); farms, quarry, mine, logging, salvage yard, outpost, crashed ship (reusing wild-raid sites); statue landmark; waterfall forest + cave; bus station, toll; **resource economy** (new items, vehicle cargo, rich nodes + gangs); skills by use; stats applied (C6, C7); quest model (C8) | Phase 3; Phase 0 terrain spike | Drive town → city in ~2 min; resource runs feed Settlement crafting |
| **5. Hover then flying** | Hover car; then flying car, air lanes, landing pads, anti-air at banks; rooftop flying pickup; upgrade tree (§3.7) at a tuning station; insurance | Phase 4 | Air-lane traffic within budget; anti-air works |
| **6. Parties, then clans** | Networking (authoritative server), squad drop-in, loot split, party flagging; then clans, shared base or stations, clan heists | Design-for-now rules in §4.7 | Separate design doc + network spike first |

**Tests per phase** follow the current runner (`raid/tests/run_relay_candidate_checks.py`). Examples:

- `test_city_flag_rules` (no kill or steal unflagged)
- `test_city_death_rule` (civilian keeps, flagged loses)
- `test_city_extracts` (flagged refused at civilian exits; heat locks)
- `test_city_budget` (rendered draw calls and triangle counts on a fixed camera path)

Rendered tests run one at a time, as now.
