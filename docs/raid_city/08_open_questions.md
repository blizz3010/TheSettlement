# 8. Open questions for Michael

[Index](../raid_city_design.md) · prev: [7. Build plan](07_build_plan.md)

Proposed defaults are in **bold**, so a quick "yes" works. The first group blocks Phase 1.

## Death rule and flagging (blocks Phase 1)

1. **Q1. Does the new death rule apply to wild raids too?**
   Today a downed raid in Relay Ridge or Cinder Basin loses the haul and keeps gear with 25% wear, and Atlas holds carried items for a fee.
   There's no flagging in wild raids. Options: (a) wild raids keep today's rule; (b) **wild raids count as "civilian" unless you flag**; (c) wild raids are always "flagged-risk".
2. **Q2. Can you unflag mid-raid?** Options: never; **after heat clears plus a 120 s cooldown, without stolen items on you**; or only at a fixer.
3. **Q3. Does "lose everything carried" on a flagged death include the briefcase vehicle?**
   **Yes, unless insured (about 15% premium); insured vehicles return after one raid with half their installed upgrades.**
4. **Q4. Is being arrested at a checkpoint the same as a flagged death?** **Same loot loss, but you keep the vehicle and lose cash on hand only.**
5. **Q5. Can flagged players kill civilians, and do those civilians keep their loot?**
   **Yes, they can kill them; the civilian keeps all of their loot (it goes home with them); the killer gets +1 heat and nothing from the body.**
6. **Q6. Do stolen items lose their protection if a civilian (unflagged) carries them?** **Yes, stolen-tagged items are lost on any death.**
7. **Q7. Flagged versus flagged: does the killer get the victim's carried items as a drop?** **Yes.**
8. **Q8. Are flagged players allowed at civilian exits?** **No; refused at heat 0–1, arrested at heat ≥ 2** (Ori's suggestion).

## Vehicles

9. Q9. Briefcase deploy while flagged: **allowed, but slower (10 s) and never in police line of sight**? Or not at all?
10. Q10. Do vehicle upgrades stay with the briefcase vehicle? **Yes.** On a flagged death, lost with the vehicle unless insured (Q3).
11. Q11. Vehicles need fuel? **Soft fuel: refuel at gas stations; running dry only limits speed.** Or no fuel at all?
12. Q12. Can carjacked cars be kept (resprayed at a garage)? **Not in v1; sell to the fence only.**

## Gear (from the E1-D integration)

13. **Q13. Visor rule.** Current call (Ori's, used for E1-D): **a visor shows only on a helmet of the same tier. With no helmet or a different tier it's hidden, but its stats still apply.** Keep it? Should city disguises interact with visors (a visor hides your face for heat decay)?

## World and economy

14. Q14. Region size **4 × 6 km** and city ~3 × 1.6 km: OK? (The earlier guess was 2–4 km for the city alone.)
15. Q15. First district = **Neon Market + Central Bank block + bridge B2**? Or start with the small town (safer, smaller)?
16. Q16. Payout targets: crime about **2–3× civilian work per minute**, and Central Bank 3,000–6,000 credits per party. This means raising prices and sinks across the Settlement. OK?
17. Q17. Cash on hand (lost on a flagged death) separate from banked credits (always safe)? **Yes.**
18. Q18. Is PvP in the city in scope for single-player v1, or is v1 PvE only (police, gangs) with PvP arriving with parties?

## Tech

19. Q19. OK to add a native GDExtension (Terrain3D 1.1, pinned) if the spike wins, given the pinning and import policy? Or stay plugin-free?
20. Q20. Minimum spec target: **GTX 950 / Iris Xe, 8 GB, 1080p 30 fps on Low**. Correct?
21. Q21. Combat: what weapons, and is it first-person or third-person aiming? Weapons don't exist yet and they gate flagging.

## Later

22. Q22. Parties: loot split **per carrier, with heist cash split evenly**? Party flagging: **the whole party flags together**?
23. Q23. Clans: a shared plot next to the Settlement, or shared stations only?
