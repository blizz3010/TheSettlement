# Raid interaction audio

Fourteen original user-supplied WAVs, November 10, 2026. Their exact source hashes are recorded in SOURCE-PROVENANCE.json. No independent asset-rights verification or blanket license is inferred.

All sources are preserved as mono PCM16 / 44.1 kHz, without normalization, trimming, looping or lossy compression. Final-path import metadata was generated in separate minimal Godot 4.6.3 projects so the settlement's pinned imports were not touched.

Thirteen cues are wired: key unlock, keycard accepted, access denied, keypad press, relay switch click, three Cinder valve variants, puzzle solved, extraction activation, countdown pulse, cancellation and completion. The 3.518-second heavy_door_open.wav is preserved but not played: doors currently open instantly, so its long movement sound would not match.

The raid-local service uses the existing SFX bus without changing its volume or mute. Mechanical/puzzle cues are positional; UI and extraction feedback are local. Provisional event gains are -14 dB, with countdown and valves at -18 dB. Voice count is capped at eight. Unlock and solve sounds require actual state transitions. Countdown pulses follow elapsed integer crossings from second two, without catch-up bursts. Cancellation, focus loss, return and scene teardown stop the appropriate voices. Focus loss is silent.

## Cinder valve variants

Echo Cistern uses valve_turn_stop_1/2/3 for valves 1/2/3 respectively. This is a stable cosmetic assignment, not a clue about the correct order, and consumes no procedural or puzzle RNG. Relay Ridge retains its electrical relay click. The shared switch hook changes only the feedback, leaving puzzle input and once-only solve feedback intact.

Only one mechanical valve voice plays at a time, including across different valves. A new deliberate action stops and releases the previous voice, then plays its own variant at the valve's location. This deliberately favors bounded feedback over completing every 1.315–1.477 second clip under rapid input. Audio never delays gameplay input, and missing or suspended audio does not block puzzle progress. These are one-shot feedback sounds; matching turn/stop animation is not implemented or claimed.

The automated audio suite checks original source hashes, lossless imports, dispatch on both maps, fixed valve assignment, repeated actions, conservative valve gain, bounded/released voices, saved bus settings and lifecycle cleanup. This is not an audible mix or loudness approval. Test the mix alongside the larger gameplay update; do not treat technical no-clipping checks as listening acceptance.
