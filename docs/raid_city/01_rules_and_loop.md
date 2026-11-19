# 1. Core loop and rules

[Index](../raid_city_design.md) · next: [2. World layout](02_world_layout.md)

## 1.1 The loop (unchanged home base)

The city is a **new raid type**, not a separate mode. The Settlement stays home base at its current size.

```
Settlement → ship (scripts/launchpad_ship.gd, raid/scripts/ship_raid_selection.gd) → pick a map
  → takeoff cutscene (raid/scripts/ship_takeoff_cutscene.gd) → drop in AS A CIVILIAN
  → civilian jobs  ─or─  flag and rob / heist
  → extract (civilian or criminal exit) → raid outcome (raid/scripts/raid_outcome.gd) → home
```

- Wild raids (Relay Ridge and Cinder Basin today, listed in `raid/scripts/raid_catalog.gd`) give **materials**.
- City raids give **money and rare loot**.
- Quests span both map types (see [4. Systems](04_systems_integration.md)).
- Base, skills and stash are always safe. What you carry depends on the death rule in §1.6.

## 1.2 Civilian by default: what is safe

You always drop in as a civilian (unflagged). Civilians can:

| Allowed as a civilian | Not allowed until flagged |
|---|---|
| Walk, sprint, drive, ride public transport | Draw or fire a weapon in public (the weapon "safety" is on) |
| Take civilian jobs (§1.8) and get paid | Melee or shoot NPCs or players |
| Buy, sell and pawn **legal** goods | Steal from a cash register, ATM, vault, car or player |
| Scout: walk into the bank lobby, read layouts, pick up job intel | Carjack (taking an unlocked, parked car is a petty crime and flags you) |
| Gather legal region resources (§4.4) | Use criminal extracts |
| Defend yourself: self-defence damage against someone who attacked you first does **not** flag you | Enter restricted zones (vault, rooftop pads, police HQ) |

**Hard rule:** you cannot kill or steal while unflagged. The input is blocked and you see a "Flag to commit crimes" prompt.
That means griefing a civilian is impossible unless you first flag yourself publicly.

## 1.3 Flagging

- **How you turn it on:** hold the Flag key for 3 s while not in a vehicle chase. This is deliberate, so it can't happen by accident.
  There is one forced flag: betraying your security-guard employer (§1.8) flags you instantly.
- **How long it lasts:** proposed default is until you extract, die, or **unflag**.
  Unflagging needs heat 0 plus a cooldown (proposal: 120 s at heat 0, and you can't be carrying stolen items).
  This is an open question for Michael (Q2).
- **What others see:**
  - Other players: a red name plate and a red outline within 60 m, plus a red mask icon on the minimap within 150 m.
  - NPCs: shopkeepers raise their hands, civilians flee or record you, and security guards draw.
  - The police get your last-known position whenever a witness reports (heat ≥ 2).
- **While flagged:** civilian extracts refuse you, so you're turned away or arrested at the checkpoint (§1.5).
  Civilian jobs pause. Briefcase vehicle deploy takes longer (see [3. Vehicles](03_vehicles.md)).

## 1.4 Wanted level (heat 0–5), security and police waves

Heat is per player (per party later). It rises with witnessed crimes and falls when you're out of sight.

| Heat | Trigger (examples) | Response | Decay |
|---|---|---|---|
| 0 | Flagged, nothing witnessed | None | — |
| 1 | Petty crime seen (shoplift, ATM skim, carjack) | Shop security and private guards in that block | 30 s out of sight |
| 2 | Armed robbery (grocery till), assault | 2 patrol cars converge, **witness reports** start | 45 s out of sight |
| 3 | Small bank job, police hurt | 4 cars plus a **bridge block** on the nearest bridge, and civilian traffic thins | 75 s out of sight |
| 4 | Central Bank alarm, officer killed | SWAT van, drones, spike strips, roadblocks on 2 bridges, criminal extracts start locking (cheapest first) | 120 s out of sight |
| 5 (max) | Vault breach at heat 4, or sustained combat | Gunship plus anti-air at banks; **all bridges blocked**; only the extracts you hold a key or fixer deal for stay open, and they close one by one on a 3-minute timer | Doesn't decay; you must extract or die |

Police waves spawn **off-screen** from the police HQ and district edge spawners (budgets in [5. Tech](05_tech_and_budgets.md)).
Line of sight is checked with ray casts against a coarse occluder set. It isn't per-pixel.

## 1.5 Extracts: civilian and criminal are separate

These replace the mockup's three generic extracts (North, East, South).

| Type | Extract | Condition | Locks when |
|---|---|---|---|
| Civilian | Ship pad (city drop zone, small-town pad) | Unflagged; possible police scan at heat ≥ 1 in the district (contraband check, §1.6) | Never, for civilians |
| Civilian | Bus station, train station | Unflagged; ticket costs a few credits; 60 s wait | Never, for civilians |
| Civilian | Highway toll | Unflagged; drive through in a vehicle; toll fee | Never, for civilians |
| Criminal | Dock smuggler | Pay a fee (scales with haul value) | Heat 4 |
| Criminal | Sewer or tunnel | Needs a maintenance key; reuses the key items in `raid/scripts/field_supplies.gd` | Heat 5 timer |
| Criminal | Rooftop flying-car pickup | Needs intel from a job or a fixer, and a call-in wait | Heat 4 (anti-air near banks) |
| Criminal | Paid fixer (small town) | Expensive; one use per raid | Last to close at heat 5 |

**Flagged players at civilian exits** (Ori's suggestion, adopted as the default): the exit **refuses** a flagged player.
At heat ≥ 2 the checkpoint **arrests** you. Arrest is a new outcome; proposal: it counts as a flagged death for loot, but you keep your vehicle (Q4).

The current extraction model is one radius (4 m, `EXTRACTION_RADIUS` in `raid/scripts/raid_world.gd`) and an 8 s hold
(`EXTRACTION_DURATION` in `raid/scripts/raid_state.gd`). It needs typed extracts with conditions. See conflict C3 in [4. Systems](04_systems_integration.md).

## 1.6 Death rule (Michael's version, replaces "lose carried gear")

| You die as | You keep | You lose |
|---|---|---|
| **Civilian** (unflagged) | **All loot you carried comes home**, including the raid haul, carried stacks and equipped gear. Durability wear still applies (proposal: today's 25% downed loss, `DOWNED_DURABILITY_LOSS` in `raid/scripts/gear_tiers/gear_defs.gd`) | Nothing, except legal-item contraband found by a police scan (proposal) |
| **Flagged** | Base, skills, stash, lockbox, gear locker contents you didn't bring | **Everything carried**: raid haul, carried stacks, equipped gear, cash on hand. The briefcase vehicle is an open question (Q3) |

Edge cases (proposed defaults; Michael decides, see [8. Open questions](08_open_questions.md)):

- **Can flagged players kill civilians?** Yes. A flagged player is a threat to everyone, which is the risk of a busy city.
  The civilian victim still gets **their** loot back (the civilian rule above). The killer gets nothing from the body and takes +1 heat.
  That removes any reason to farm civilians for loot.
- **Can civilians fight back?** Yes, in self-defence (§1.2), without flagging.
- **Flagged vs flagged:** the victim's carried items drop as a loot bag the killer can take. That's the PvP risk/reward.
- **Anti-abuse:** going civilian and stuffing stolen goods in your pockets doesn't protect them. Stolen items are tagged `stolen`,
  and a civilian who dies carrying stolen items loses those items (proposal).

This **conflicts with current code**: today a downed raid loses the haul and keeps equipped gear. See conflict C1.

## 1.7 Heists: a ladder from traders

Heist jobs come from Settlement traders (new "contracts" tab; see [4. Systems](04_systems_integration.md)) and from intel found on civilian jobs.

| Rung | Target | Steps | Time | Heat | Party | Payout (credits, proposal) |
|---|---|---|---|---|---|---|
| 1 | ATM skim (Neon Market, small town) | Hack or pry, take cassette | 30–60 s | 1–2 | Solo | 60–150 |
| 2 | Grocery / corner store till plus safe | Flag, intimidate clerk, till, back-room safe (code from job intel) | 2–3 min | 2 | Solo | 150–350 |
| 3 | Pawn shop back room, armored courier van | Lockpick, or a vehicle box-in | 3–5 min | 2–3 | Solo / duo | 300–700 |
| 4 | Small-town bank (north) | Lobby, manager key, vault door drill (STR/tool), timer | 5–8 min | 3–4 | Solo / duo | 800–1,500 |
| 5 | **Central Bank** (downtown) | Multi-step: (a) intel from a security-guard or electrician job, (b) cut power at a substation, (c) lobby, (d) vault drill/hack under siege, (e) carry heavy bags (weight!), (f) getaway over a bridge or by rooftop | 12–20 min | 4–5 | Party of 2–4 (solo possible) | 3,000–6,000 split |

Lock and puzzle steps can reuse the existing raid puzzle code: key, code and valve-sequence locks in `raid/scripts/raid_state.gd`
(`try_unlock`, `flip_switch`, `PUZZLE_ORDER`) and `raid/scripts/puzzle_controls.gd`.

## 1.8 Civilian job track (the safe way to earn)

Ori's full list is kept below. The **starter set** reuses systems that exist today or are on the roadmap.

**Starter set (Phase 1–2):**

1. **Courier (on foot or scooter):** carry a package A → B. Reuses haul and weight (`raid/scripts/raid_loot/loot_table.gd` `UNIT_WEIGHT`, `raid/scripts/gear_tiers/gear_storage.gd`) and raid map pins (`raid/scripts/raid_map.gd`).
2. **Delivery driver (van):** multi-drop route. Needs ground vehicles (Phase 2) and reuses the delivery depot POI.
3. **Salvage (docks and crashed ship):** search salvage piles. This is the existing cache-search loop (`raid_state.gd` `search_cache`) and salvage items (`raid/assets/salvage/*`).
4. **Repairs / electrician:** fix a panel with a valve/switch puzzle (`puzzle_controls.gd`). **Reveals security**: it marks bank cameras and the substation (heist intel hook).
5. **Security guard:** patrol a site and learn layouts and guard routes (intel for rung 4–5). Betraying the employer flags you instantly.

**Later:** taxi and rideshare, tow truck, cargo trucker, hover-car valet, mechanic, construction, logger, miner, farmhand,
salvage diver, park ranger, paramedic, street vendor or cook (could reuse the Cookhouse recipes, `scripts/cooking_catalog.gd`), bounty spotter.

**Hook:** jobs give heist intel (codes, guard routes, rooftop pickup slots). That makes the two tracks feed each other.

## 1.9 Risk versus reward: how the tracks compare

Targets per 15-minute run on Phase 1 numbers (balance proposal, to tune in playtests):

| Track | Credits per run | Loss risk | Notes |
|---|---|---|---|
| Civilian jobs only | 150–300 | ~0 (civilian death rule) | Steady and safe; also gives intel, skill XP (driving, trading) and legal goods |
| Petty crime (ATM + grocery) | 300–700 | Medium: lose carried items on death | Quick, low heat; civilian exits are closed once you're flagged |
| Small bank | 800–1,500 | High | Heat 3–4, bridge blocks |
| Central Bank | 3,000–6,000 (party) | Very high: lose everything carried; extracts close | The endgame of a city run; needs prep from jobs |

Rule of thumb: **crime should pay about 2–3× civilian work per minute, before losses**. Expected value after deaths should
still favour crime for skilled players, but not by much for new ones.

Today's economy is small (150 starting credits and a 100-credit plot expansion in `scripts/settlement.gd`; salvage worth 6–110
credits each in `loot_table.gd`). City payouts need a matching set of sinks: vehicles, upgrades and fixer fees. See conflict C11.
