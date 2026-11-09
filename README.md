# The Settlement

An in-development Godot 4.6.3 settlement/survival RPG by Michael Onofre (blizz3010), built with AI-assisted development. The settlement hub is the foundation for a planned extraction adventure. Planetary raids and PvPvE are roadmap work, not completed features.

## Current snapshot

This repository contains the editable game scripts, shaders, scene configuration, assets and pinned imported resources corresponding to **v0.100-r7**. The reviewed runtime PCK SHA-256 is `896d37a95cc3fbff07ff4dab45aa27f664a5cb957d80e14c0f6f12fb227af9fa`.

Current work includes the settlement hub, player housing/building, inventory/equipment, character creation and separate saves, traders, requests, fishing, menus and environmental systems. Several systems and visual assets remain provisional. This is a development snapshot, not a finished release.

### r7 gameplay-menu update

Adds Request Board/Workbench styling, journal filters and material shortfalls, shop match counts and Clear filters with hidden-selection protection, and cooking-test availability, tray/reset guidance, preparation steps and keyboard focus. Six UI scripts and their exact source-integrity hashes changed; no save-format, pricing, recipe, reward or transaction-rule changes. Focused r7 headless checks passed; broader combined and native Windows validation remain pending. The source-recovery checks below describe the r6 foundation, not a newly exported r7 build.

## Setup

Requires Godot **4.6.3** and Python 3. Use an isolated development profile, never your real player saves.

1. Run `python tools/restore_approved_imports.py` to reconstruct large assets.
2. Import once: `godot --headless --editor --path . --import --quit`.
3. Close the editor. Run `python tools/restore_approved_imports.py`.
4. Run `godot --path .` (start at the title menu).

Repeat step 3 after editor reimports. The restoration tool verifies every pinned resource hash before installing it; it does not disable geometry or foliage guards. On Linux set `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` to separate disposable directories for development. Windows production saves use `%APPDATA%/Godot/app_userdata/Settlement • First Playable`; back them up before testing and do not run two builds against them together.

## Source recovery and rebuild limits

This snapshot combines the exact r7 runtime scripts/data with retained raw authoring assets. Text scene/configuration files were recovered through Godot. The character preview GLB and six textures were recovered from current imported resources; original MPFB authoring controls are not recovered. Original private Blender authoring files and personal save files are not included.

`vendor/approved-runtime-imports` and `vendor/approved-import-metadata` preserve the approved imported asset bytes and remaps. Fresh raw imports alone do not reproduce every reviewed mesh fingerprint; the pinned resources are intentional build dependencies, not disposable caches. Editing those assets requires deliberate review and a new validated import. Do not replace guard fingerprints merely to make an altered asset pass. A raw-assets-only rebuild and final standalone export pipeline remain follow-up work. No byte-identical fresh export is claimed.

## Verification

Clean Godot import completed. Headless title startup exited 0 but reported an existing shutdown resource/leak warning. A focused direct-world startup comparison found the same garden/inn refusal behavior in the shipped r6 PCK and this restored-source snapshot; direct-world headless entry is not proof of full normal gameplay. No fresh Windows, graphics, audio or full-playthrough validation is claimed for this source recovery. Mike's prior playtest applies to the supplied r6 runtime, not a newly exported build.

## Development priorities

- Consolidate the reproducible export pipeline and replace pinned-import dependence with exact current authoring sources.
- Continue gameplay/content in meaningful batches, with quick checks per change and broader testing at milestones.
- Refine character/menu presentation and remaining provisional settlement systems.

## Ownership and asset notices

No blanket open-source license is granted by this upload. Original project material remains its owner's property; third-party rights are retained. See `THIRD_PARTY_NOTICES/` and asset provenance files. MakeHuman/MPFB system assets, Quaternius nature and selected Holizna music have CC0 notices; StayAtHomeDev has MIT terms; fonts retain their notices. User-supplied procedural audio and generated video are identified as such, not relicensed as CC0. Generated intro/menu footage is not gameplay. Private Library reference IDs have been removed from three provenance files, with only their corresponding integrity hashes updated.

Large binary assets are stored as lossless chunks under `vendor/large-assets` to fit the upload transport. The restoration script reconstructs and verifies their exact bytes before import and running; these are not simplified replacements.
