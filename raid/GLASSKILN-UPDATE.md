# Glasskiln Works campus update

November 10, 2026. Additive source candidate for the existing two-map raid build.
This is a playable procedural blockout inspired by the supplied industrial-campus
concept. It is not a conversion of the image into finished 3D art, a detailed
replica of its inconsistent floor plans, or a Windows/rendered acceptance result.

## One consistent layout

The site still sits at (-88, 30) in Cinder Basin. Its cleared terrain radius grows
from 21 m to 45 m, with the same terrain preflight and seeded exclusion rules.
The west/east trails go around the buildings. In local coordinates:

- Furnace hall: x -13..13, z -37..-17. Two large furnaces, 18.1 m stacks,
  central front/rear entrances and side entrances with an aisle around the tanks.
- Control house: x -27..-15, z -18..-4. Ground through-route, control consoles
  and an upper service gallery.
- Warehouse: x 15..29, z -21..-1. Two loading entrances, side entrances,
  storage stacks and an upper service gallery.
- Maintenance workshop: x -26..-16, z 0..10. The existing service key and one
  locked cache remain. Field supplies are outside at (-30, 12).
- Power shed: x 19..29, z -34..-24. Two entrances and a central equipment aisle.

The loading yard has three staggered cargo islands and open central/flanking
routes. Existing key/card/code/puzzle state, loot rolls and quality bands are
unchanged. The larger site adds no reward caches; Glasskiln remains quality 2–3.
There is no combat or gunfire system here, so cover effectiveness and encounter
balance are not claimed as tested.

## Upper route

Two independent 2.6 m-wide stairways, at local x -12 and +12, use twenty real
21 cm treads over a 12.5 m run. The unchanged production player can ascend and
descend either staircase without jumping. At 4.2 m, the gantry connects the
control/warehouse galleries and branches into a furnace-hall mezzanine. Physical
1.1 m rails surround the route except at intended connections. Overhead pipes
connect the industry without crossing the player's standing routes.

## Verification

Godot 4.6.3, isolated disposable Linux profiles, headless:

- Existing Cinder contracts: 150 checks, including deterministic terrain/layers,
  pad exclusions, access rules, once-only loot and exact two top-tier sites.
- Existing scene checks: 25, including 591 route support/standing-clearance
  samples, physical lock doors and production movement.
- Existing whole-map walkthrough: 90, including all seven trails in both
  directions, all six sites, the moved workshop's supplies/key/cache, both
  extraction approaches and 3,708 m of production movement.
- New campus suite: 43, including all building approaches/through-routes,
  two-way stairs, three upper galleries, continuous 4.2 m floor height and
  a physical guardrail, including both edges of both side-gallery tips. It walks a further 601 m without jumping.

The final aggregate runner includes the campus suite plus both maps, both
procedural seed matrices, ship flow/selection and audio. Its JSON result is the
authority for the packaged source snapshot. Original settlement files and
frozen resource/geometry guards must still pass the separate packaging checks.

## Audio and acceptance limits

The three supplied valve variants are used deterministically for Echo Cistern
valves 1, 2 and 3. Relay Ridge retains its switch click. The single valve-voice
limit avoids overlaps, uses a provisional -18 dB gain, and never delays puzzle
state. Sources are preserved losslessly with hashes. See audio/README.md.

The user handles native Windows testing in the larger update. Rendering,
keyboard/mouse capture, audible mix, frame times, full-game regression and real
settlement save/reload are not accepted by headless checks. Do not replace an
earlier Windows ZIP's contents without building and verifying a new candidate.
