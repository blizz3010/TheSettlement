# Package the pinned recovered r8 source

This is a supported **packaging-only** path for the recovered public r8 runtime
at commit `48e2b75d9f3e314d5b54eac62e12a384a5ed95df`. It builds a new PCK from the
checkout and its existing pinned resources, without needing the separately
delivered r7/r8 game packs. It does not import assets or modify checkout files, change game scripts,
refresh fingerprints, or rewrite the scenery/service authority.

The output is a development candidate, not a newly verified Windows release.
It is not byte-identical to the previously delivered r8 PCK: it uses the public
recovered text scenes and project settings, excludes editor/UID caches, and
retains the public provenance redactions. Two license notices have their
original CRLF line endings restored in staging, because the public upload
normalized them to LF while the unchanged authority pins the original bytes. The geometry, placement and service
guards remain unchanged. Normal rendered startup and the full starter-loop
walkthrough still need acceptance.

## Requirements

- The public r8 checkout, with this document and the three new files under
  `tools/` overlaid. Newer gameplay source is intentionally rejected by this
  snapshot-specific tool.
- Python 3.8 or later and the official Godot **4.6.3 stable** executable.
- Godot and other checkout writers closed while restoring or packaging.
- An existing output directory outside the checkout, with about 410 MB free
  for temporary staging and the new pack. The filesystem must support hard
  links so the verified result can be published without overwriting a file.

## Commands

Run these from the checkout. Use an absolute Godot path with `--godot` if its
executable is not on PATH; on Windows use the console executable. Preserve
repository line endings when checking out source. For a fresh Git for Windows
clone, `git -c core.autocrlf=false clone https://github.com/blizz3010/TheSettlement.git`
sets that choice for the clone without changing global Git settings.

```sh
python tools/restore_approved_imports.py
python tools/build_pinned_r8.py --check
python tools/build_pinned_r8.py --output ../Settlement-r8-source-review.pck
```

No editor import is needed for this path. If the editor was previously opened,
restore the pinned imports again before packaging. Any mismatched runtime file
stops the build instead of silently accepting a different source snapshot.

The command prints a receipt containing the output SHA-256, byte count,
resource count, and `native_verified: false`. Save that output with the build
if desired. Existing output files are never replaced; choose a new name for
another build. If a command reports a cleanup failure after publication, check
whether its new output exists before retrying.

The pack can later be opened with Godot 4.6.3 using `--main-pack`, but only under
an isolated development profile and when the rendered review is appropriate.
Never run it against your normal character saves. This tool does not produce
a Windows executable or installer and is not the r7-to-r8 upgrade launcher.

## What is checked

`tools/pinned-r8-runtime.json` is the reviewed allowlist of 730 runtime files.
The tool verifies every source SHA-256, stages independent copies, confirms
all 587 existing guarded resource hashes are covered, and runs Godot's own
PCKPacker in an empty project with temporary HOME/APPDATA/XDG directories.
It then verifies every packed entry's SHA-256 and MD5 before exclusively
publishing the new file. No player game, editor, save or normal desktop session
is opened by the build tool. `--check` is read-only and does not run Godot.

The two notice restorations are allowed only for their named license files.
Both public input and restored runtime SHA-256 must match the reviewed
contract; the checkout is never rewritten. An ordinary direct source launch
after a Git checkout may still encounter those line-ending guard mismatches.
Use this pinned packaging path for a candidate; do not loosen guards.

The manifest and the Godot executable are trusted build inputs. The tool does
not authenticate Git ancestry or prove a modified manifest is official. Do
not regenerate the manifest or guard hashes to suppress a mismatch. Review
future runtime changes deliberately and update the packaging contract with
the matching source changes. There is no protection against another process
maliciously changing directories concurrently; keep the checkout closed.

## Verification performed

- Thirteen focused exporter checks passed, covering read-only checking,
  missing/corrupt sources, unsafe/symlink paths, duplicate JSON keys, missing
  guarded resources, optimized Python, existing/inside-checkout outputs, and
  corrupted/encrypted pack rejection, and narrowly scoped notice restoration.
- The restored r8 source produced a 730-file, 203,985,816-byte PCK. A second
  independent staging/build produced identical bytes and SHA-256:
  `4574c92de75fcf12612f608fd9e389ea2a7bde48f60954fa4346a2042da94a8e`.
- Headless title startup exited 0 without script/resource-load failures. It
  retained the previously observed shutdown warning about a leaked instance
  and one resource still in use. This is not a graphics or gameplay pass.

Run the focused tooling tests with:

```sh
python tools/test_build_pinned_r8.py
```

Windows execution, graphics, audio, normal-menu starter-home/stash/crafting
progression and save/reload, and a fresh raw-authoring-assets standalone export
remain unverified. This path still depends on the exact pinned imported assets.
The historical `tools/prepare_export.py`, old source/build manifests and
version-0.63 export preset are not used or promoted to current authority.
