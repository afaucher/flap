---
name: bird-design
description: How to design a bird in Flap -- add a new species or rework one (its flight numbers, wing planform, body, head and eyes, bill, legs and feet, feathers and plumage, poses, tack fit, sounds) from research and reference photos, and check it with the tests and renders. Use whenever a task adds or changes a species, or any part of how a bird looks or flies (a bill, an eye, a wing's shape, a plumage mark, a perch pose), even if it doesn't say "design".
---

# Designing a bird

Flap's five birds (crow, owl, hawk, falcon -- coloured as a male kestrel -- and sparrow) were each built the same
way: **research numbers first, the drawn bird derived from the flight model's numbers, every part checked against
a reference (a paper, a measurement, a traced photo) by a test that measures what is drawn.** This skill is that
method, the rules it settled on, and where each part lives. Read `AGENTS.md` first (build, test, gate, worktree and
mutation rules apply as everywhere).

Reference files here (read the one for the part you're working on):
- `numbers-and-wings.md` -- `BirdProfile` (the readable numbers, `derive()`, the tests that hold the polar), the five
  species' numbers, the wing planform (`WingShape`), the gameplay departures from the real birds.
- `body-head-legs.md` -- `BodyShape` (trunk, neck, head size and skull), eyes and the `Face` data, the owl's disc,
  gaze, legs and feet (`LegRig`), poses, how the tack fits.
- `bills.md` -- bills from traced photos: the trace, the emit, the loft, the shader, the snout, the eye seat.
- `feathers-and-plumage.md` -- the wing rig, feather layout and drawing, the atlas, plumage colour and pattern.
- `new-species-checklist.md` -- every table a new species needs an entry in (most fall back to the crow silently).
- `looking.md` -- the rig gallery, tack gallery, bird lab and probes: how to see and chart a bird.
- `lessons.md` -- mistakes already made and fixed, so they aren't made again.

## The method

1. **Research before numbers.** Each part of the bird has a research doc in `docs/research/` (aerodynamics by
   species, wing anatomy and shapes, body anatomy, poses and folded wings, eyes and beaks, legs and feet, plumage,
   feather looks). Find the species' measured numbers there, or add them, with sources and an honest grade: a
   number is **sourced**, **estimated** (`[E]`, from a related species or a photo), or a **gameplay choice**. Write
   which. Estimates are fine; unlabelled ones aren't.
2. **Pick a reference for each look.** A Wikimedia Commons photo (licence recorded) side-on for the head and bill,
   field-guide plates for plumage, measured bones for legs. Record the reference you're matching -- the falcon is
   coloured as a kestrel while `plumage_coloring.md` still lists peregrine values, and that drift cost time.
3. **Set the readable numbers; derive the rest.** Mass, span, area, Oswald e, glide ratio, CL max -- `derive()`
   computes the polar. The drawn wing is calibrated to the flight model's span and area (`WingShape.calibrate`);
   never tune a drawn size by hand when it has a source number upstream.
4. **Build from the reference's own geometry where you can.** The bills are lofted on profiles traced from photos;
   the body's rings come from anatomical landmarks; feather counts and attachment from wing anatomy. Parametric
   shapes ("a cone with a hook") read as generic -- the beaks did until they were traced.
5. **Chart it against the reference, side by side, in numbers.** Before and after: a 2D profile chart
   (`tools/beak_profiles.py`), an ortho render at the same view, a table of drawn vs reference. Say what's still off.
6. **Hold it with a test that measures the drawn mesh or the simulated flight**, both ways (left and right, pull and
   push), against the reference's numbers -- not a copy of the constants that built it. Every bug fixed gets a
   mutation entry that brings it back and must come back KILLED.
7. **Look at it in the game's light and camera**, not just the gallery: colours and marks are judged from the chase
   camera in game light (`plumage_coloring.md`); a mark needs at least 2 px to read.

## Rules that hold for every bird

- **Profile:** set only the readable numbers; `test_bird_profiles` and `test_glide_trim` hold the polar honest --
  never loosen their tolerances to make a tuning pass. Every preset ends `return p.derive()`.
- **Separate species by L/D, AR, thrust and agility**, not by stall speed (`bird_aerodynamics_by_species.md`).
- **Heads are about 1.2x life size** (the owl's at life size) so a real-proportioned bill fits and the face reads
  from the chase camera; the bill keeps its proportion to the head (scaled by the life head's half-width).
- **Everything joins on an edge loop of the surface it leaves**: neck on the trunk's front ring and the head's own
  ring, legs on the trunk's shell, toes on the pad, the bill buried into the head. Normals pinned at the join,
  colours handed over across it. Seams are tested (`test_neck_seam`, `test_leg_rig`).
- **Feathers overlap into one surface**; one stacking order open or folded; widths sized so neighbours overlap
  (the half-width bug). Only slotted fingers leave gaps.
- **Every assist and every look switch stays switchable** (`--cpu-feathers`, `--no-cards`, `--legs capsules`,
  plumage levels 0-6): the A/B is how a change is judged.
- **No fidelity cuts without asking** (LOD, fewer feathers, throttled rig updates).
- **GPU builds have a GDScript reference** that headless tests use; `gpu_test_*` compare them. Change both.
- **Docs drift**: when the code and a doc disagree the code is the truth -- fix the doc in the same change (known
  stale spots are in `lessons.md`).
- **Never open a windowed Godot directly** to look: `run.ps1 --shot`, `probe.ps1`, the test runner.

## Workflow for a change to one part

1. Worktree and branch (`AGENTS.md`). Read the part's reference file here and its research doc.
2. Render the **before**: the part's view in the rig gallery (`looking.md`), ortho, for every species, plus any
   chart. Save to the scratchpad; keep what's worth keeping in `docs/images/` as `<part>_before.jpg`.
3. Change the data or the builder. Re-run generators if their input changed (`tools/bill_profiles_emit.py`,
   `tools/bake_feathers.gd`, `tools/bake_sounds.gd`).
4. Render the **after** at the same views; chart against the reference. Iterate until the table is close; write
   down what's still off and why it's left.
5. Test: extend the part's test (or add one) so it measures the drawn result against the reference; add mutation
   entries for the bugs you fixed on the way. `.\test_runner.ps1 -TestAll`, `.\mutation_check.ps1 -Changed`.
6. Update `AGENTS.md`'s bullet for the part and the design/research doc; the gate; merge.

## Adding a species

Work through `new-species-checklist.md` in order: research numbers -> `BirdProfile` preset -> `WingShape` ->
`BodyShape` -> `Face` (eyes) -> bill trace -> `LegRig.SPEC` -> `POSE` -> plumage -> tack (`RIDDEN`, the rider must
fit at 8.5 cm) -> sounds -> menus and keys -> docs. Every test that loops over `BirdProfile.all()` picks the new bird
up; it must pass all of them (flight, landing, AI, race, rig, face, seams, legs, tack). Expect the AI and race
courses to shift: `CombatStyle` is derived from roll rate and stall, and courses are planned from the birds'
turning circles.
