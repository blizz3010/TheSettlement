# Recovered-source setup repair

This small developer-tool update applies to the recovered r7 source at commit
`6d5b8c707ff8e0c53438ff456021f3a00c0b7c23`, with or without the separate r8
starter-home source delta. It is not a new game build or a standalone project.
Copy the two files under `tools/` into the corresponding checkout directory.
Keep Godot and other writers closed while restoring. Python 3.8 or later is
required; no additional Python packages are needed.

## What changed

- Hash checks are explicit and remain active under optimized Python (`-O`).
- Every pinned import, import descriptor, and large-asset chunk is checked and
  staged before any destination file is replaced. Staged outputs are read back
  and verified against the existing manifest hashes too.
- Manifest paths must stay in the expected project locations. Traversal,
  symlinks, duplicate destinations, missing inputs, and invalid hashes fail
  closed.
- Each file is replaced atomically, so an installation error does not publish
  a truncated asset. Matching existing files are left untouched.
- `--check` verifies all source inputs without writing anything.

If installation itself fails after some replacements, the tool reports how
many completed. This is not a whole-project transaction or rollback. Close
Godot, resolve the filesystem error, and rerun. The temporary staging directory
requires about 200 MB of additional free space for this snapshot and is cleaned
up on normal exit or a handled error. No tool can guarantee cleanup after an
abrupt operating-system or process termination.

## Setup

Use a disposable development profile and keep real player saves separate.

1. Optional read-only check: `python tools/restore_approved_imports.py --check`.
2. Restore: `python tools/restore_approved_imports.py`.
3. Import once: `godot --headless --editor --path . --import --quit`.
4. Close Godot and run `python tools/restore_approved_imports.py` again.
5. Start normally from the title menu with `godot --path .` when the normal
   rendering/gameplay review is appropriate.

The existing project README describes save isolation. Never run development
and production builds against the same save profile simultaneously.

## Verification and remaining limits

The focused helper suite is available as:
`python tools/test_restore_approved_imports.py`.

Thirteen focused checks passed, including corrupt or missing late inputs,
optimized Python, path safety, staging failure, interrupted installation and cleanup, and
idempotence. One isolated restore of the actual manifests verified all 346
outputs (199,360,735 bytes) against their existing hashes; a repeat installed
zero files. The original helper's optimized-Python hash bypass and partial
restore on a corrupt later chunk were reproduced using tiny disposable
fixtures, not real game assets.

The manifests, raw assets, game scripts, runtime PCK, geometry fingerprints,
placement surveys, and service guards are unchanged. This verifies recovery
tool behavior, not normal gameplay, rendering, Windows launcher execution,
audio, or a fresh standalone export. The older `tools/prepare_export.py` and
historical source/build manifests remain historical evidence, not a supported
new r7/r8 export pipeline. Do not regenerate guard hashes to force acceptance.
