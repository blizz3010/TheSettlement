# Raid menu safety and accurate extraction markers

Unshipped source follow-on to the combined v0.7 field-kit candidate, November 11,
2026. This change is staged separately; it does not replace the delivered Windows
review or its source snapshot.

## Changes

- Modal buttons now belong to the specific panel that created them. Closing a
  panel, replacing it with a new panel, or beginning return invalidates old
  actions. Delayed actions cannot unlock a door after cancellation, begin a
  cancelled extraction, dismiss a newer menu, or leave a raid after choosing to
  keep exploring.
- Code-entry submission and keypad feedback use the same panel-lifetime check.
  Current wrong-code attempts still allow retries; correct codes, normal
  extraction confirmation and results Return still work.
- Extraction markers use the actual generated beacon positions. Previously the
  map used nearby trail endpoints, which are two meters west of each beacon.

These are shared changes for Relay Ridge and Cinder Basin. No art, terrain,
collision, loot, inventory, save format, import guard or production game file is
changed. Sliding doors and the expanded Obsidian Archive remain separate work.

## Verification and limits

The new `test_raid_ui_lifecycle.gd` runs against both real generated maps using
synthetic retained GUI signals. It checks cancellation/replacement, stale button
and text-entry actions, quiet stale keypad feedback, valid retries, normal
extraction, once-only return, and map markers tied to actual beacon nodes.
The unfixed baseline reproduced the stale-action behavior before changes.

Run the complete candidate suite with isolated disposable profiles:

    python3 raid/tests/run_relay_candidate_checks.py /absolute/output-directory

The aggregate includes this test in addition to the existing map walkthroughs,
extraction scheduling, ship flow, asset integration and procedural seed matrices.
Final results are supplied in the separate validation report and source manifest.
The focused checks exercise synthetic signals, not native event ordering. No new
Windows execution, rendered visual review, audible mix, performance acceptance,
production save test or Windows export is claimed. Keep the larger-batch review
cadence; this small source delta does not need a separate user playtest.
