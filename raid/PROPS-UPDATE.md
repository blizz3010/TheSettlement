# Loot cache and extraction beacon integration

This separate source candidate builds on the three-landmark candidate. The earlier
landmark project and delivered builds are not overwritten. No production or native
Windows playtest approval is implied.

## Supplied assets

The two user-supplied archives passed ZIP CRC and safe-path checks. Their four GLBs
are self-contained glTF 2.0 files, with no external textures or buffer references,
animation, cameras, lights, gameplay scripts or collision. Supplied Python scripts
and Blender authoring files were not executed or opened with automatic scripts.
The game includes only the four verified GLBs, import metadata and their generated
Godot resources, not the authoring scripts or Blender files.
The original READMEs reference optional sibling preview scripts and a Godot test
folder that are not included in either archive. These are not needed to import or
use the four GLBs. The Blender files passed structural integrity checks, but their
authoring workflow was not exercised.

Independent geometry checks and a clean, isolated Godot 4.6.3 import confirmed:

- Loot cache: 708 triangles, 1.50 m wide × 1.00 m high × 1.00 m deep, ground-centred
  origin. Separate Cache_Lid pivot at (0, 0.85, -0.484), with its latch parented to
  the lid. It opens around local X to -70 degrees. Its interior is a shallow well.
- Extraction beacon: 1,214 triangles, 1.07 m wide × 2.00 m high × 1.08 m deep,
  ground-centred origin. Separate control panel and emissive Beacon_Light_Glow.
  The device has foot pads, without an asset-integrated platform or zone ring.
- Both variants face +Z. Woodland uses muted green/steel. Salt flat uses pale
  sand/rust. Geometry is identical between each pair of material variants.

No new blanket license is assigned to user-supplied assets. Preserve the user's
original archives for editable sources and provenance.

## Gameplay integration

Relay Ridge uses the woodland versions; Cinder Basin uses the salt-flat versions.
Each map still has six caches and two extraction beacons at its original positions.
The primitive cache bodies/lids and solid beacon block visuals are replaced.

A successful cache search opens its hinged lid over 0.32 seconds. A denied search
does not open it, and repeated search cannot animate again or reroll loot. All
cache state remains disposable, resetting with the raid. Lid movement is visual:
the original simple static cache collider stays in place, including the opening.

Beacon glow materials are duplicated per instance. Activation brightens the active
beacon, the countdown gives a mild one-second pulse, cancellation restores idle
emission, and completion holds brighter emission. This does not add a local light
or change environment glow settings. Visible bloom depends on the renderer and
environment. Other beacons do not share an active beacon's material state.

The existing collider sizes, target centres, aiming/raycast behavior, extraction
ground-height calculation, eight-second timer, cancellation rules, target counts,
quality bands, credential checks, and audio remain unchanged. The old external
navigation marker pole, text, and terrain-following four-metre extraction markers
remain separate gameplay guidance; no platform or extra ring is added by the GLB.
The beacon retains the slightly broader 1.2 × 2.0 × 1.2 m prototype collision box.

No changes to the original settlement source, startup/save guards, production saves,
map terrain, trails, POIs, doors, vegetation, combat or rewards are part of this pass.

## Verification

The new `test_raid_props.gd` covers both imported variants and both generated maps:
dimensions and triangle counts, hierarchy and hinge, emission and per-instance
isolation, original target/collision positions, variant selection, denied/repeated/
successful search, finished lid angle, and extraction activation/cancel/completion.

The combined runner also includes all prior raid checks. The accompanying validation
report records **1,946 passed assertions across 33 suites**, including 162 dedicated
prop checks and all twelve seeded-layout matrix cases. All 346 original pinned
settlement imports passed their read-only checksum check. No rendered,
native-input, Windows, frame-rate, audio-mix or real-save acceptance is claimed.
Keep the user's larger-update playtest cadence; there is no new small-change
playtest request. Any future manual review must use a disposable isolated profile.

## Import and packaging

The four GLBs were imported in a small project at the same `res://raid/assets/props/`
paths, then the four scene resources and remaps were copied into this candidate.
This avoided a whole-project editor reimport of pinned settlement assets. All
imports used empty import-script fields. Pinned original resources were not changed.

For a new build, include the GLBs, matching `.glb.import` files, and the four imported
`.scn` resources. They are also listed with hashes in `assets/props/ASSET-MANIFEST.json`.
For a fresh development import, use Godot 4.6.3 and then restore the approved original
imports as described in the project setup notes. This source pass does not itself
produce or validate a new Windows package.
