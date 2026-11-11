# Raid source backup: November 11, 2026

This additive development checkpoint preserves the complete 184-file raid directory from the wayfinding candidate after Obsidian Archive v2.1. It includes Relay Ridge and Cinder Basin, Glasskiln Works, vegetation, supplied props and interaction audio, puzzle controls, field supplies, cargo scenery, Archive integration, map pins and Archive floor/stair guidance.

The base is commit `61fcd11304e27b93937c0d3feba73cebc4bc80e6`. Every existing repository file is retained byte-for-byte, including the newer r8 packaging tools and README. The default startup remains the settlement title menu. This checkpoint does not replace or modify the default branch, previous source candidates, or previously delivered Windows packages.

## Restore and run

Check out this backup branch, then follow the main README and RECOVERED-SOURCE-SETUP.md to restore the settlement dependencies and import with Godot 4.6.3. Use a disposable profile. Follow raid/README.md for standalone map and ship-preview entry points. Do not run development builds against real player saves.

RAID-BACKUP-MANIFEST.json records byte sizes, SHA-256 hashes and Git blob identities for every backed-up raid file. Generated .godot caches are excluded and rebuilt by the engine. Existing vendor dependencies remain intact. Original private authoring material, personal saves, private reference identifiers and unrelated uploads are not part of this public checkpoint. User-supplied assets retain their rights; no blanket license is added.

## Verification and limits

The exact source checkpoint has passing final-source results for all 3,462 checks across 40 Godot headless suites. The first aggregate run had one ship-flow process exit -9 without a script error; an isolated retry passed its 14 checks without source changes. This is the retained prior verification, not a fresh gameplay run during backup. The backup audit independently verified all source hashes against that checkpoint.

Native Windows input, rendered appearance, audio mix, performance, production-save acceptance and a fresh combined Windows export remain unverified. This is a source backup, not a new release or playtest approval.
