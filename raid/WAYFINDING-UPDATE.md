# Raid wayfinding candidate

A separate source-only batch on top of the Obsidian Archive v2.1 candidate. Existing Windows packages and prior source candidates are unchanged.

## Player changes

- On either raid map, click the centre of a site or extraction marker to pin it. Left/Right cycles through six sites and two beacons. Right-click or Delete clears the pin. Map/Escape retains its existing close behavior, including rebound Map keys.
- A site pin points to its public trail approach rather than its locked room. A beacon pin follows the actual generated beacon position. The map labels the destination and marks the approach with a gold diamond. No shortcut/pathfinding line is drawn through buildings.
- The map's white player triangle shows facing direction. A compact exploration HUD shows facing, selected destination, compass bearing and rounded-up horizontal distance. Distance is explicitly direct, not walking distance. Follow the existing marked trails; arrival does not collect supplies, unlock rooms, search caches or extract.
- The pin survives closing and reopening the map in the same raid, then resets in a new map instance. No save format or persistent state is added.
- Obsidian Archive gains seven short-range, depth-tested signs, nine non-colliding floor chevrons and a current-floor HUD cue. Gold paint follows the public entrance and east Stair B route to the upper vault. Green marks the return toward the main exit. The upper route exits Stair B to the north to avoid the nearby shelving. Raised stair landings use their actual imported floor heights.

## Preserved contracts

The supplied model, terrain, foliage, trail layout, player controller, lock handlers, audio, save/reload and reward state are unchanged. Exactly one Archive card, one locked vault, the original quality 4–5 cache roll and repeat-search protection remain. Pending Research Annex and sliding-door artwork is not included or assumed received.

## Checks and limits

The new suite checks both real map scenes, all 16 destinations, correct public forecourt/beacon coordinates, compass headings, keyboard cycling and clearing, key rebinding, repeated and hidden input, close/reopen and focus-loss behavior, invalid pins, logical UI bounds/text widths, state isolation, local archive floor cues and floor paint support/standing clearance. The existing movement, security, extraction and ship suites remain in the aggregate runner.

Read the accompanying verification report for the final counts and exact result. All Godot commands use disposable profiles. Headless/synthetic-input checks do not certify native Windows input, rendered appearance, sound, performance or real production-save acceptance. This batch is not a Windows export. The next combined Windows review should include a short click/keyboard-pin check and an Archive stair/sign walkthrough.
