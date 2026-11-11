# Research Annex source backup: November 11, 2026

This checkpoint adds the verified Research Annex final_b integration to the previous two-map raid backup, commit `62706e72e84ee383b63941bcc23d7bcd41c9b64a`. It preserves all nineteen new or modified candidate files, including the exact original Blender/model, texture and reference-render archives. No blanket asset license is added.

The three source archives and self-contained runtime scene are stored as nine lossless parts because of the upload transport size limit. They are not reduced, recompressed or converted for this backup. `ANNEX-BACKUP-MANIFEST.json` records every part and reconstructed file's size, SHA-256 and Git blob hash. The remaining source changes are stored directly at their original paths. The earlier `RAID-BACKUP` files describe the preceding checkpoint and remain unchanged.

## Restore before importing or running

1. Check out this Annex backup branch.
2. From the repository root, run `python tools/restore_annex_backup.py` with Python 3.8 or later. It verifies every part, reconstructs all four exact files, and refuses to overwrite any existing file with different bytes. Use a filesystem supporting hard links, such as NTFS, APFS or ext4. Close Godot and other writers while restoring.
3. Run `python tools/restore_annex_backup.py --check` to verify without writing.
4. Follow the main README and `RECOVERED-SOURCE-SETUP.md` for the existing settlement dependencies, then `raid/README.md` for the map and ship-preview entry points. Use Godot 4.6.3 and a disposable development profile, never real player saves.

The source archives are reconstructed under `AUTHORING/ResearchAnnex/source/`. Extract them into a separate authoring folder if needed. The runtime scene is restored to `raid/assets/research_annex/research_annex_runtime.scn`. It is self-contained and requires no new Godot import cache. The conversion tool and source-equivalence test use the original model archive.

## Verification and limits

All nineteen candidate source files match the final verified source checkpoint. All nine uploaded parts match their local Git blob identities, and reconstruction of all four complete binary files matches both SHA-256 and Git blob hashes. The restoration tool passed seventeen focused safety and recovery checks, including missing/corrupt input, repeat runs, read-only checks, path escape refusal and preservation of differing destination files.

The exact candidate previously passed all 5,455 checks across 42 Godot headless raid suites, with all exits zero. These results are retained candidate verification, not a new gameplay run during this backup. Native Windows input, rendered Godot appearance, lighting/glass, audio, performance, production-save acceptance and a combined Windows package remain unverified. Reference Blender renders are not gameplay screenshots.

The main branch, previous raid backup, original source candidates and previously delivered builds remain unchanged. This is a source backup, not a release or playtest approval.
