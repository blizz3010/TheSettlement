# Three-landmark procedural art pass (v0.5 candidate)

November 10, 2026. This additive source candidate builds on the v0.4 two-map,
Glasskiln, audio and vegetation work. The existing delivered v0.4 packages are
preserved. New package verification and delivery are recorded separately.

## Landmarks

- **Relay Tower:** A tapered, seven-bay X-braced frame, top service platform and
  rails, two parabolic dishes, amber beacons, twin suspended cables, and a
  weathered equipment hut with a pitched roof, gables and framed windows. The
  added art uses 20 batched mesh instances. The tower and its upper platform are
  visual landmarks, not a new climb route.
- **Helion Mirror Array:** Four original-position mirror assemblies now have
  framed, segmented reflector faces and layered pedestals. The receiver has a
  faceted crown, shaft joints and a roof-supported base. Its existing control
  house has facade trim and a clearly depicted calibration keypad.
- **Obsidian Archive:** Two four-tier basalt wings flank a compact upper facility
  with weathered blue trim, framed windows and panel joints. The ground entrance
  has a card-slot reader and card symbol, rather than copying the reference's
  ambiguous keypad. Upper masses and wings are not authored climb routes.

These are original procedural interpretations of the supplied concept sheets,
not extracted 3D assets or finished production artwork. No textures or external
assets were imported for this pass. Reference views were adapted to retain the
game's tested room dimensions and movement routes.

## Gameplay preservation

The three sites keep their original POI coordinates, reserved areas, terrain,
trails, room walls, entrances, door/clue/cache positions, credentials and loot
quality bands. No caches or rewards were added. The visual upgrades do not add
combat, enemy AI, real item drops, persistence, harvesting, flight or progression.
The original r8 gameplay files, startup gates, exporter and guarded assets are
unchanged. All prototype raid state still resets on leaving the preview.

The supplied heavy-door audio remains reserved and unwired. Existing door
opening behavior and the thirteen wired raid sound cues are unchanged.

## Verification and review

The combined runner includes the new `test_relay_landmark.gd` and
`test_cinder_landmarks.gd` alongside existing route, real-controller walkthrough,
interaction, extraction, ship-selector, vegetation, audio and seed-matrix suites.
See the delivered validation records for the final run's counts and outcomes.
The new tests inspect geometry, determinism where applicable, room and entrance
clearance, target preservation and bounded mesh counts. They do not measure FPS.

Optional offline comparison sheets show triangles exported from the actual POI
builder before and after this pass, at matching scale. They omit in-game labels
and do not reproduce Godot lighting, emissions, reflections, shadows or culling.
They are geometry illustrations, not gameplay screenshots or rendered acceptance.

Native Windows input, visual quality, performance, audible mix, real ship boarding
and settlement save/reload remain for the user's larger-update playtest. Use only
the isolated disposable review profile. Do not overwrite a previous build or copy
real saves into a review profile. No production release or full regression pass
is implied.
