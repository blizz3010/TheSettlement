# 3. Vehicles, briefcase, damage, upgrades, traffic

[Index](../raid_city_design.md) · prev: [2. World](02_world_layout.md) · next: [4. Systems](04_systems_integration.md)

There is **no vehicle code in the project today**. The player is a `CharacterBody3D` with walk and sprint only (`scripts/player.gd`).
TASKS item 20 (vehicles plus roads, with dirt roads, guardrails, signs, stop signs and traffic lights) is the umbrella for all of this.

## 3.1 Vehicle roster and roles

| Vehicle | Speed (cruise / top m/s) | Armor | Cargo (haul units) | Seats | Role |
|---|---|---|---|---|---|
| Scooter | 18 / 22 | Very low | 2 | 1 | Starter courier; weaves through traffic and park paths |
| Motorcycle | 35 / 55 | Low | 3 | 2 | Fastest ground getaway; passenger can shoot |
| Sedan | 30 / 45 | Medium | 8 | 4 | All-rounder; taxi and rideshare jobs |
| SUV | 28 / 42 | Medium-high | 12 | 4–5 | Party getaway, off-road capable, rams roadblocks |
| Van / light truck | 22 / 35 | High | 24 | 2 | Delivery job, heist loot runs (heavy bags) |
| Cargo truck | 18 / 30 | Very high | 48 | 2 | Region resource hauling; slow and a big target |
| Hover car | 35 / 50 (≤ 3 m altitude) | Medium | 8 | 4 | Crosses rivers and off-road without slowing; ignores spike strips |
| Flying car | 50 / 70 (air lanes) | Low-medium | 6 | 2–4 | Rooftop pickups and region travel; shot down near banks |
| Police cruiser / SWAT van / gunship (NPC) | 32 / 48 · 25 / 38 · 45 / 60 | Med · Very high · High | — | — | Pursuit, roadblocks, air pursuit at heat 5 |

Pursuit balance: police cruisers are slightly slower than a motorcycle but faster than an SUV. They catch up on straights, and you lose them in corners and side streets.

## 3.2 Ship and briefcase vehicles

The ship is the travel hub and map select (`raid/scripts/ship_raid_selection.gd`). Personal vehicles **deploy from and pack into a briefcase**.

| Question | Proposal |
|---|---|
| Deploy time | 4 s unflagged; **10 s while flagged**; blocked within 15 s of taking damage, and blocked while police have line of sight (no mid-chase spawns) |
| Pack-up time | 3 s, standing next to the vehicle, engine off |
| Inventory size / weight | The briefcase takes **4 haul units and 6 kg** in the raid pouch (`HAUL_BASE_CAPACITY := 8` in `raid/scripts/raid_loot/loot_table.gd`). One briefcase per raid at first |
| Cargo inside the vehicle | Packing up with cargo is **not allowed**; you unload or lose the cargo. That keeps vehicle cargo a run decision |
| Damage | **Persists** through pack-up (§3.6). A vehicle at 0 HP can't be packed |
| On death (civilian) | The briefcase comes home with your loot (civilian rule) |
| On death (flagged) | Open question Q3. Proposal: the briefcase is **lost** unless it's **insured** (premium paid at the garage before the raid, about 15% of vehicle value). Insured vehicles come back after a 1-raid wait, similar to how Atlas holds recovery today (`raid/scripts/atlas_recovery_service.gd`) |
| Carjacking | A carjacked NPC car is not yours. It can't be packed into a briefcase, so it's a temporary getaway. Later, a "hot" car can be sold to the dock fence |
| Garage (later) | Owned vehicles live in a Settlement garage station. The briefcase is the in-raid form of a garage vehicle |

## 3.3 Build order (ground first, flying last)

1. **Phase 2:** sedan (one physics controller), scooter, police cruiser. `VehicleBody3D` with a tuned arcade grip model, plus NPC traffic on lane splines.
2. **Phase 3:** SUV, van, motorcycle (bikes need a custom lean controller; `VehicleBody3D` handles 2 wheels poorly), cargo truck.
3. **Phase 5:** hover car (ray-cast hover springs over terrain, same input).
4. **Phase 5+:** flying car (6-DoF arcade flight, air lanes, landing pads, anti-air).

## 3.4 Flying cars: air lanes and anti-air

- **Air lanes:** two altitude bands, **60–90 m** (city) and **120–150 m** (region transit). Lanes are splines between pads. NPC flying traffic stays on lanes.
  Players can fly off-lane, but at heat ≥ 2 that draws police drones.
- **Building height cap:** downtown towers ≤ 180 m, so the upper lane stays clear except for the corporate tower spire.
- **No-fly zones with anti-air:** a 250 m radius around each bank and the police HQ. Turrets reuse the logic in `raid/scripts/sentry_turret.gd` (track, telegraph, fire), scaled up.
  They warn first (lens telegraph), then fire. That's why the rooftop pickup locks at heat 4.
- **Landing:** marked pads (rooftops, the statue shoulder, ship pads). Off-pad landing is allowed on flat ground below 15° slope.

## 3.5 Road and bridge widths (vehicle-width roads)

Design widths (also passed to the item 20 road kit; P1's grass-edge lips already avoid narrowing hard surfaces):

| Road type | Lanes × width | Plus | Total clear |
|---|---|---|---|
| Alley / service | 1 × 3.5 m | — | 4 m |
| Residential | 2 × 3.25 m | 2 × 2 m sidewalk | ~11 m |
| City arterial | 4 × 3.5 m | 2 m median + 2 × 3 m sidewalk | ~22 m |
| Highway | 2 + 2 × 3.75 m | 2 × 2.5 m shoulder + 1 m barrier | ~21 m |
| Dirt road | 1–2 × 3 m | soft verge | 4–6 m |
| Main bridge | 4 × 3.5 m | 2 × 2.5 m walkways | 19–20 m |
| Old / narrow bridge | 2 × 3.5 m | 1 × 2 m walkway | ~9–10 m |

Reference vehicle widths: scooter 0.8 m, motorcycle 0.9 m, sedan 1.9 m, SUV 2.0 m, van 2.1 m, truck 2.5 m, hover car 2.2 m.
Lane 3.5 m = truck + 0.5 m each side.

## 3.6 Vehicle damage

- **Collision damage scales with speed:** `damage = k × max(0, impact_speed − 4 m/s)²`, from the contact impulse. At 4 m/s or less it's a scrape.
- **Visual damage (no soft-body):** swap in damaged part meshes (bumpers, doors, hood), dent and scorch **decals**, then smoke at < 40% HP and fire at < 15%. These are GPU particles; the Compatibility renderer supports them.
- **Handling:** below 50% HP top speed drops by up to 30%, steering by up to 20%, and there's a random pull. At 0 HP the vehicle **breaks down**; if it was on fire, it **explodes** after 5 s (damage radius 6 m).
- **Weapons damage vehicles and occupants.** Glass and body panels absorb some damage based on armor tier. Bulletproof glass (§3.7) blocks it.
  This reuses the damage classes in `raid/scripts/gear_tiers/gear_defs.gd` (`DAMAGE_CLASSES`, ballistic).
- **Repairs** use resources (metal, parts, electronics) at the garage or tuning station in the Settlement, priced like gear repair (`REPAIR_FRACTION` in `gear_defs.gd`).
- **Persistence:** damage is saved with the briefcase vehicle.

## 3.7 Upgrade tree (4 tiers per part)

Parts are crafted (Settlement stations) or bought (a new vehicle trader, or Rook for raw parts), and installed at a garage or tuning station.
Effect per tier, as a percentage of base. T1 is stock and T4 is the max.

| Part | Handling | Accel | Top speed | Braking | Durability | Cargo | Tier-4 note |
|---|---|---|---|---|---|---|---|
| ECU tune | +2/4/6 | +4/8/12 | +2/4/6 | — | — | — | Unlocks the nitro slot |
| Intercooler | — | +2/4/6 | +1/2/3 | — | — | — | Needed for turbo T3+ |
| Tires | +5/10/15 | +2/4/6 | — | +4/8/12 | — | — | T4: run-flat (spike strips only slow you) |
| Brakes | +2/4/6 | — | — | +8/16/24 | — | — | — |
| Turbo | −1/−2/−3 | +6/12/18 | +3/6/9 | — | — | — | — |
| Exhaust | — | +1/2/3 | +1/2/3 | — | — | — | Louder means more witness radius (heat) |
| Suspension | +4/8/12 | — | — | +2/4/6 | — | — | Off-road penalty −10/20/30% |
| Transmission | +1/2/3 | +3/6/9 | +2/4/6 | — | — | — | — |
| Armor plating | −2/−4/−6 | −2/−4/−6 | −1/−2/−3 | −2/−4/−6 | +15/30/45 | −1/−2/−3 units | — |
| Bulletproof glass | — | — | — | — | +5/10/15 | — | T3+: blocks small-arms fire into the cabin |
| Nitro | — | +10/20/30 burst | +5/10/15 burst | — | — | — | Charges 30 s |
| Cargo rack | −1/−2/−3 | −1/−2/−3 | — | — | — | +2/4/6 units | — |
| Hover thrusters | — | — | — | — | — | — | Converts a car to a hover car (hover chassis only) |
| Flight thrusters | — | — | — | — | — | — | Converts a hover car to a flying car (late game) |

(Values are steps T2/T3/T4 over the T1 stock part.)

- **Upgrades stay with briefcase vehicles**, because they're part of the saved vehicle.
- **On a flagged death:** if the vehicle is lost (Q3), its upgrades are lost with it. Insurance covers the chassis and **half** the installed parts (proposal).

## 3.8 Civilian traffic and traffic AI

- **Variety:** sedans, SUVs, trucks, vans, taxis, buses, scooters, motorcycles, plus hover and flying cars on lanes. 3–5 colour and trim variants each come from a material palette (shared meshes, so there's no draw-call explosion).
- **Lanes:** a road graph of splines with lane ids, built from the same data as the road meshes (item 20). Intersections have traffic lights with phase timers. Stop signs give way to traffic from the right.
- **NPC driving model:** NPC cars are **kinematic followers** on lane splines with simple gap-keeping (IDM-style). Only cars within ~60 m of the player, or hit by something, switch to physics bodies (`VehicleBody3D`). That keeps physics cost bounded.
- **Reactions:** at heat ≥ 1 nearby cars slow and honk. At heat ≥ 2 they swerve away from flagged gunfire and pull over for police sirens. Drivers flee their cars when shot at.
- **Carjacking:** you must be flagged. It's +1 heat (or +2 if witnessed by police). The NPC driver gets out; armed NPC drivers in later districts may fight back.
- **Pedestrians:** sidewalk splines plus crosswalk waits. They flee from flagged players with weapons drawn. Some act as witnesses (they report to police after 5 s unless you intimidate them).
- **Density budget for low-end hardware:** see [5. Tech](05_tech_and_budgets.md) §5.6 (cars, pedestrians and physics bodies per quality tier).
