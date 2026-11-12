# Field supplies integration candidate

This separate development copy extends the validated puzzle-controls source
candidate. It does not replace a delivered Windows package or the previous
development copy. No settlement inventory, save, economy or progression changes
are included.

## Placement and behavior

Each of the four locked-site clue targets has one matching object, rather than
all four credentials being shown together: key for a key lock, card for a card
lock, clipboard for the generated code, and logbook for the puzzle sequence.
Relay Ridge uses woodland materials and Cinder Basin uses salt-flat materials.
Glasskiln supplies remain at the workshop's existing offset.

The old pickup target at local (-9, 0.9, 7), its 0.7 x 0.12 x 0.5 m collision
box, and the stand at (-9, 0.43, 7) with its 1.4 x 0.8 x 1.0 m solid collision
box are retained. Stand art is bottom-centered at Y=0.03, aligned with the old
stand collision bottom. Pickup origins sit on the measured 0.792 m inset deck,
at local Y=0.822. No resizing, tilting or extra collision is introduced.

Collection calls the unchanged raid-state code, retains the same generated
message and field-note content, then hides only the pickup and safely disables
its collider. Hidden targets are immediately excluded from selection. Repeated
or stale interactions are ignored. The stand and original FIELD SUPPLIES label
remain. A fresh raid restores the supplies and clears the temporary kit.

The stand intentionally retains the original simple solid collision volume:
the open shelf and spaces between legs are visual, not new crawl-through gaps.
Small keys/cards intentionally retain the larger pickup target for usability.
No permanent or settlement pickup persistence is added.

## Asset validation

The uploaded archive passed CRC and path checks. Its ten intended GLBs have
byte-identical copies in the supplied Godot-test folder. All ten intended
models were independently imported in a clean Godot 4.6.3 project at the same
resource paths used by this candidate, with both name-suffix conversion options
disabled. Only newly generated asset caches were copied into the candidate;
the existing approved imports were not regenerated.

Actual imported X/Y/Z dimensions, in meters:

- Key: 0.18 / 0.014 / 0.042, 296 triangles.
- Card: 0.12 / 0.0095 / 0.08, 168 triangles.
- Clipboard: 0.22 / 0.0257 / 0.3005, 280 triangles.
- Logbook: 0.26 / 0.0296 / 0.19, 200 triangles.
- Stand: 1.4 / 0.8 / 1.0, 564 triangles; measured deck top 0.792.

Both variants use the same geometry. They are self-contained, Y-up with
bottom-centered identity transforms, and have no embedded animation, scripts,
lights, cameras or collision. The clipboard has a negligible 0.25 mm footprint
center offset from its clip. All materials are double-sided. Four or five
materials are used per asset; the clipboard has seven surfaces across three
meshes. No UVs, textures or baked clue text are present.

No supplied Python, GDScript or Blender script was executed, and no Blend file
was opened. Editable sources remain in the original user archive. No blanket
license is assigned to supplied assets.

## Tests and limits

The dedicated suite checks every imported variant, exact triangle counts and
dimensions, measured deck triangles, types/materials, actual map placement,
front standing support/clearance, real camera/raycast targeting at the small
objects, acquisition, lifecycle guards, duplicate interaction, disappearance,
collider removal, independent objects, retained generated notes and fresh-raid
reset. The existing full regression runner also covers both maps' route walks,
door/code/puzzle/cache flows, extraction, six seed cases per biome, ship
boundaries, foliage, landmarks, audio events and previously integrated props.

Read the accompanying VALIDATION.json for final suite counts and outcomes.
Initial expected dimensions were corrected from rounded README values to the
actual binary geometry (clipboard 25.7 mm; logbook 29.6 mm). Geometry itself was
not changed to satisfy a test.

These are headless physics and interaction-handler tests, not native mouse or
keyboard testing. In-engine rendered acceptance, Windows execution, frame-rate,
audible mix, full real-save roundtrip and complete game acceptance remain
untested. No fresh Windows package is created for this small source update.

## Visual quality assessment

The supplied overview and individual previews are Cycles renders, not captures
from this candidate. They show coherent starter props but still very lean
low-poly art: sparse flat surfaces, blocky silhouettes and raised orange rust
patches. Technical import success is not final low-mid visual approval.

For the later coordinated quality pass, prioritize selective edge bevels and
normal cleanup on close-up silhouettes, subtle roughness/wear variation, stronger
metal-versus-painted-surface separation, and a few readable construction details
on the clip, key bow, card rim and book spine. Avoid indiscriminate subdivision
or arbitrary triangle quotas. Keep clue faces blank and preserve exact size,
deck placement and readable pickup silhouettes. Check real gameplay-camera
visibility, particularly the small key and card, under both maps' lighting
before considering this art finished.
