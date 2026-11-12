# Distinct biome vegetation pass

November 10, 2026. Additive source candidate following Glasskiln Works. These are
original, low-poly procedural interpretations of the supplied concept sheets.
They are actual three-dimensional meshes, not images placed in the world, but
not finished asset conversions or a promise of the detail pictured in the art.
The earlier Windows review ZIP is unchanged by these source edits.

## Species and scale

Relay Ridge now mixes three silhouettes: tiered Ridgeback Pine (18 m), broad
Lanternleaf Oak (12 m) and pale, narrow Silverbark Birch (10 m). Amberberry
Thicket (1.5 m), Ridge Meadow Grass (0.8 m) and Glowfern (0.5 m) fill the existing
shrub and groundcover placements. Amber fruit and fern veins have restrained
emissive color, without individual lights. No gathering rewards are added.

Cinder Basin has Cinder Juniper (4.8 m), Salt Yucca (3.6 m), Glassplume Shrub
(1.65 m), Bonebrush (1.15 m), Ember Agave (0.95 m) and Salt Samphire Mat (0.36 m).
Basalt remains on the rock layer; its original sparse central salt exclusions
remain. Woodland and salt-basin species never cross between the maps.

These are nominal mesh heights before the existing 0.8–1.25 placement scale.
The concept sheets are not measured drawings. Cinder heights are implementation
choices; all scales remain subject to the later in-game art review.

## Safety and rendering budgets

- Terrain, POIs, trails, extraction areas, landing zone and all seeded placement
  counts, yaw and scale are unchanged. A separate position hash selects species,
  so density changes do not perturb another layer or move existing plants.
- Existing trunk and rock collision envelopes are retained exactly. These are
  conservative gameplay proxies, not precise silhouettes. Undergrowth and
  elevated crowns remain decorative/pass-through. No new physics obstacles,
  gameplay loot or interaction are added. Cinder trunks now carry wood-surface
  audio metadata rather than the previous geological stone tag.
- Each species has one opaque, vertex-colored mesh surface. Meshes and one
  material are shared across 32 m batches, with explicit bounds and distance
  culling at 75 m for groundcover, 140 m for shrubs and 245 m for trees/rocks.
  Relay groundcover/shrub ranges rise slightly from the previous 70/135 m. Groundcover casts no shadows. Emission uses no dynamic lights or
  transparency. No new textures, imported assets, plugins or purchases.
- Appearance version is separate from natural-generation versions. The original
  settlement source, project startup, import hashes and geometry/resource guards
  are not changed. The candidate cannot bypass travel readiness checks.

## Verification

Run the combined headless runner for both maps, ship flow/selection, extraction,
readiness, Glasskiln, audio and the two six-case procedural matrices. It now
includes `test_biome_vegetation.gd`: mesh finiteness/height/uniqueness, deterministic
species coverage, exact placement transforms and physics envelopes, zero-density
behavior, culling bounds, and bounded default geometry counts. Headless checks inspect
the exact transforms submitted to MultiMesh, not GPU instance readback.

The aggregate JSON in the validation directory is the pass/fail authority for
this source snapshot. The baseline audit separately checks original source,
guarded runtime files and approved imports. Source mesh geometry can also be
exported for an offline shape review; such a diagram is not an in-engine render.

The automated checks do not accept appearance, lighting, occlusion, audio,
framerate, native input, Windows behavior or real ship save/reload. No prolonged
Windows playtest is required for this pass. Those remain bundled with the larger
update, under the user's testing plan. Building or sharing a new Windows package
requires a fresh separately verified candidate; do not silently replace the
previous package or label this source pass a Windows-tested release.
