# Obsidian Archive v2.1 candidate

The isolated candidate replaces only Obsidian's old room and procedural dressing
with the supplied full-scale archive. The Cinder POI identity, position, radius,
forecourt, terrain seed, trails, map, loot band and raid state are unchanged.
No Windows build or native-input acceptance is claimed by these headless tests.

## Integration

`raid/scripts/obsidian_archive.gd` owns presentation and collision. The model is
instantiated as an imported PackedScene at the existing POI root, with no scale
or rotation correction. Godot coordinates are Y-up; the front faces +Z.
All retained architectural meshes receive actual mesh-derived collision.
Presentation `Site_*` meshes and figure nodes are excluded. Ordinary door leaves
are removed entirely while frames remain, so public openings are visibly open.
The front reader is removed because the public entrance is not card-locked.

The partly open imported vault leaf is replaced with one real closed game door,
with its collision shape directly below the door body, compatible with the
existing `_open_door()` handler. The existing state enforces the same keycard
permission and one quality 4–5 reward roll. The imported vault reader remains.

POI-local interaction positions:
- Card: (-9, 0.9, 19), outside the south entrance, reachable before unlock.
- Vault door: (0, 9.75, -8), opening on the upper floor at Y=8.5.
- Cache: (0, 9, -10.5), inside the enclosed vault.

The 32×28 m ground slab lies inside the existing radius-23 terrain pad. The
slightly wider plinth and exterior stair are fitted without altering terrain or
foliage settings; scene and seed tests must continue guarding the natural site.

## Routes and tests

`obsidian_routes.json` contains geometric waypoints, not uploaded executable
code. `obsidian_walk_driver.gd` drives the unchanged production controller at
60 Hz against the integrated world, retaining 3D height assertions. The
Obsidian visit in `test_cinder_walkthrough.gd` now follows the public building,
collects the card, climbs Stair B, unlocks the upper vault, searches once and
returns to the existing forecourt without repositioning mid-visit.

Upper Stair B's west exit faces shelving: the continuous vault route uses its
north door instead, then follows the clear corridor to the vault. The exterior
stair's return-flight centreline uses X=18.82 and its turn uses Godot Z=-7.86 to
avoid the actual support posts. No geometry was changed to force tests through.

`test_obsidian_archive.gd` exercises six routes in both directions with capsule
radii 0.32 and 0.35, plus the uninterrupted credential/cache lifecycle. Separate
`test_obsidian_independent.gd` covers access/security boundaries. Both are in
`run_relay_candidate_checks.py`. Old Obsidian decorative-envelope assertions
were replaced, while Helion and the generic state tests remain intact.

Run from the project directory using a disposable profile:

```sh
XDG_DATA_HOME=/tmp/obsidian-review/data \
XDG_CONFIG_HOME=/tmp/obsidian-review/config \
XDG_CACHE_HOME=/tmp/obsidian-review/cache \
godot --headless --fixed-fps 60 --path . \
  --script raid/tests/test_obsidian_archive.gd
```

Full candidate checks: `python3 raid/tests/run_relay_candidate_checks.py /absolute/output-directory`.
