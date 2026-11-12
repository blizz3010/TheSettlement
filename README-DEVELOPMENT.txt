Settlement next visual candidate — editable game project (not yet released)

Scope
This reconstructs tested PCK 301560e7bb3ab1724e49ab0ff9b7724e5e68f2531cb4a7dad3190a12519399f4: Save21 / Inventory8 / Fishing1 / Settings4, clothing Lockbox and visible drag icons, session-only cooking test, modest trader cleanup, provisional staff and corrected market stone union. ParkA includes the accepted 20-group soil-free layer and ten additional west-border plant groups with a flush stone edge. Hall gains smaller desk-front signs and two provisional visual staff. No new economy, XP, NPC services or recipe progression. Atlas has a tiny private spine-only idle; other character likenesses remain provisional.

Use Godot 4.6.3. The raw game source, assets, import settings, runtime JSON and portable export preset are included. Generated .godot caches are deliberately absent. Open/import copies, not the archived original. Running the project uses the production profile, so use an isolated profile for development and keep your real saves backed up.

Windows production save folder:
%APPDATA%\Godot\app_userdata\Settlement • First Playable
Before testing, close all builds and copy the entire folder. The first successful Save21 write over a valid Save20 save preserves the original Save20 bytes as settlement_v1.json.v20-backup; loading alone does not upgrade it. Mismatched backups fail closed. Returning to v0.62 or v0.63 needs no save-format rollback (same schemas); still close builds and preserve your profile. To return to v0.61, preserve your current profile separately and restore the pre-upgrade profile or copy that backup over settlement_v1.json. This discards post-upgrade progress. There is no automatic downgrade. Settings4 is unchanged; older builds may require their matching pre-Settings4 settings backup too.

Clean import and export (run from an unpacked project copy)
1. Choose a separate absolute output directory and a separate temporary profile. On Linux set XDG_DATA_HOME, XDG_CONFIG_HOME and XDG_CACHE_HOME to subdirectories of that temporary profile before EVERY Godot command. Never point these at real saves.
2. godot --headless --editor --path . --import
3. godot --headless --path . --export-pack "Windows Desktop" /absolute/output/raw.pck
4. python3 tools/prepare_export.py /absolute/output/raw.pck /absolute/output/rebuilt.pck
5. Run the Godot command printed by step 4. It creates a NEW guarded PCK, never overwriting the raw PCK. Do not run this command against an existing output.
6. In a new empty directory, validate actual packaged dependency closure using --main-pack /absolute/output/rebuilt.pck --script /absolute/project/tools/verify_dependencies.gd. Set DEPENDENCY_REPORT to an absolute output JSON file. Use the same isolated environment.
7. Run the native (non-headless) validator from the new empty directory with --main-pack /absolute/output/rebuilt.pck --script /absolute/project/tools/verify_rebuilt_native.gd. Set QA_PROFILE_ROOT to the absolute temporary-profile root, EXPECTED_MASKS to the absolute tools/expected-native-masks.json, and REBUILD_OUTPUT to an existing absolute result directory. It requires a working supported desktop/display; do not invent display-server workarounds. The validator refuses user:// outside QA_PROFILE_ROOT. Require terminal exit 0, its pass marker and result JSON; a timeout or assertion is not a pass.

Why the build step is required
The planting authority binds reviewed source hashes and ordered native geometry masks. Fresh imports can produce different imported SCN/CTEX bytes and remap metadata. prepare_export.py verifies immutable raw source and all required JSON bytes, then binds the ACTUAL exported metadata, scenes, textures and shader. Recursive dependency validation checks UID resolution as well as fallback paths. The native gate verifies original 506 protected and 1177 foliage polygons, the sole intended cooking cylinder, 47 planting groups, route union/contact, exact original 20 park polygons, west bounds/clearance, five coverage actors/Hall services, schema and disposal. Never merely change authority hashes to suppress a failure. Source changes require new review and live native mask proof. Never replace frozen expected masks to make a failure pass.

The rebuilt PCK need not be byte-identical to the tested release PCK. Native geometry equality is distinct from byte equality. This rebuild gate is bounded: it does not repeat the full interaction suite, complete visual ledger, Windows/audio or performance testing. Keep the original tested PCK separately.

Authoring and licenses
AUTHORING contains exact NPC provenance, Atlas deterministic fit replay and the system-asset license. Self-contained runtime GLBs can be imported into Blender for editing. The original private Blender authoring file is NOT included; this is rebuildable game source, not the complete original Blender/MPFB authoring bundle. Do not claim that a GLB import recovers MPFB controls. Further edits/re-exports are new candidates requiring review.

Public files exclude private evidence, profiles, screenshots, caches, test harnesses and unrelated art pilots. Export exclusions keep tools and AUTHORING out of runtime. Preserve them. Source-manifest hashes cover the game source; import settings/UIDs may be regenerated by Godot. Public tool/provenance hashes are separate.
