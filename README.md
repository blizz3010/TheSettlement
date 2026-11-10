# The Settlement

An in-development Godot 4.6.3 settlement/survival RPG by Michael Onofre (blizz3010), built with AI-assisted development. The settlement hub is the foundation for a planned extraction adventure. Planetary raids and PvPvE are roadmap work, not completed features.

## Current snapshot

This repository contains the editable game scripts, shaders, scene configuration, assets and pinned imported resources corresponding to **v0.100-r8**, plus the recovered-source setup repair. The corresponding review runtime PCK SHA-256 is `5d26c269634fad9c3749049e61b3f263e8dcb3cea2ba44784d0c386505aadccd`. This identifies the separately packaged review build, not a verified fresh export of this repository.

Current work includes the settlement hub, player housing/building, inventory/equipment, character creation and separate saves, traders, requests, fishing, menus and environmental systems. Several systems and visual assets remain provisional. This is a development snapshot, not a finished release.

### r8 starter-home workflow update

Adds hover and keyboard inventory inspection, storage guidance, a read-only starter-home checklist in the journal, hovered building-piece requirements and material shortfalls, and workbench recipe, review, progress, save-paused and full-bag guidance. Seven scripts and their matching source-integrity hashes changed beyond r7. Existing recipes, costs, timing, rewards, transactions, save formats, world geometry and service guards remain unchanged.

Focused checks of the exact r8 runtime passed using production state classes, including UI bounds at 1280x720 and 1440x900. This is not a rendered review or a full gameplay pass. The normal-start Windows starter loop, save/reload walkthrough, audio/graphics review and Windows upgrade launcher remain unverified. The r7 menu work below is included.

### r7 gameplay-menu update

Adds Request Board/Workbench styling, journal filters and material shortfalls, shop match counts and Clear filters with hidden-selection protection, and cooking-test availability, tray/reset guidance, preparation steps and keyboard focus. Six UI scripts and their exact source-integrity hashes changed; no save-format, pricing, recipe, reward or transaction-rule changes. Focused r7 headless checks passed; broader combined and native Windows validation remain pending. The source-recovery checks below describe the r6 foundation, not a newly exported r7 or r8 build.

## Setup

Requires Godot **4.6.3** and Python 3.8 or later. Use an isolated development profile, never your real player saves.

1. Run `python tools/restore_approved_imports.py` to reconstruct large assets.
2. Import once: `godot --headless --editor --path . --import --quit`.
3. Close the editor. Run `python tools/restore_approved_imports.py`.
4. Run `godot --path .` (start at the title menu).

See [recovered-source setup notes](RECOVERED-SOURCE-SETUP.md) for the read-only `--check` option, staging requirements and recovery after an interrupted restoration. Keep Godot and other writers closed during restoration.

Repeat step 3 after editor reimports. The restoration tool verifies every pinned resource hash before installing it; it does not disable geometry or foliage guards. On Linux set `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` to separate disposable directories for development. Windows production saves use `%APPDATA%/Godot/app_userdata/Settlement • First Playable`; back them up before testing and do not run two builds against them together.

## Pinned r8 source packaging

A new snapshot-specific packaging path can build a PCK directly from this restored public r8 source without the older runtime packs or an editor import. It preserves all existing guard bytes and pinned resources. See [recovered r8 packaging](RECOVERED-R8-PACKAGING.md) for commands, the exact source allowlist and verification limits.

Two independent builds produced identical bytes, and a headless title-start smoke exited 0 with the existing shutdown resource warning. This is packaging verification, not a new Windows release or a full gameplay pass. It still depends on pinned imported resources and does not produce a standalone executable.

## Source recovery and rebuild limits

This snapshot combines the exact r8 runtime scripts/data with retained raw authoring assets. Text scene/configuration files were recovered through Godot. The character preview GLB and six textures were recovered from current imported resources; original MPFB authoring controls are not recovered. Original private Blender authoring files and personal save files are not included.

`vendor/approved-runtime-imports` and `vendor/approved-import-metadata` preserve the approved imported asset bytes and remaps. Fresh raw imports alone do not reproduce every reviewed mesh fingerprint; the pinned resources are intentional build dependencies, not disposable caches. Editing those assets requires deliberate review and a new validated import. Do not replace guard fingerprints merely to make an altered asset pass. A raw-assets-only rebuild and final standalone export pipeline remain follow-up work. No byte-identical fresh export is claimed. The older `README-DEVELOPMENT.txt`, `tools/prepare_export.py` and source/build manifests are historical recovery evidence, not a supported current r8 export pipeline.

## Verification

Clean Godot import completed. Headless title startup exited 0 but reported an existing shutdown resource/leak warning. A focused direct-world startup comparison found the same garden/inn refusal behavior in the shipped r6 PCK and this restored-source snapshot; direct-world headless entry is not proof of full normal gameplay. A later minimal probe demonstrated that this headless environment reads back identity transforms from MultiMesh after nonidentity transforms are written. That explains the scenery-guard mismatch mechanism; it does not establish that the assets are broken or that normal rendered startup passes. Guards remain enforced. No fresh Windows, graphics, audio or full-playthrough validation is claimed for this source recovery. Mike's prior playtest applies to the supplied r6 runtime, not a newly exported build.

## Development priorities

- Consolidate the reproducible export pipeline and replace pinned-import dependence with exact current authoring sources.
- Continue gameplay/content in meaningful batches, with quick checks per change and broader testing at milestones.
- Refine character/menu presentation and remaining provisional settlement systems.

## Ownership and asset notices

No blanket open-source license is granted by this upload. Original project material remains its owner's property; third-party rights are retained. See `THIRD_PARTY_NOTICES/` and asset provenance files. MakeHuman/MPFB system assets, Quaternius nature and selected Holizna music have CC0 notices; StayAtHomeDev has MIT terms; fonts retain their notices. User-supplied procedural audio and generated video are identified as such, not relicensed as CC0. Generated intro/menu footage is not gameplay. Private Library reference IDs have been removed from three provenance files, with only their corresponding integrity hashes updated.

Large binary assets are stored as lossless chunks under `vendor/large-assets` to fit the upload transport. The restoration script reconstructs and verifies their exact bytes before import and running; these are not simplified replacements.
