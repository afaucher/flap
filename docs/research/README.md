# Flap research notes

The research behind Flap's flight model, bird rig and looks. Each note cites its sources and marks estimates, either with tags (**[S]** sourced, **[F]** or **[W]** secondhand, **[E]** estimate) or with `~` and **est.** The design docs that turn this research into rules are in `docs/design/`.

| Note | What it covers | Used by |
|---|---|---|
| `bird_aerodynamics_by_species.md` | Measured glide polars, wing loading, speeds and wingbeat rates for real species, and how each of Flap's five gameplay profiles was derived from them | `scripts/flight/bird_profile.gd`; `docs/design/flight_model.md` §8 |
| `flight_simulation_models.md` | Arcade, point-mass and 6DOF flight models, flapping models, stall and perching assists, bank-and-yank, integration; the recommended hybrid | `scripts/flight/flight_model.gd`; `docs/design/flight_model.md` §1, §3 |
| `wing_shapes_and_articulation.md` | Wing shape classes, the wing's joints, morphing, slots, alula and tail in flight, the flap cycle, the perching manoeuvre, rig parameters | `scripts/bird/wing_shape.gd`, `bird_rig.gd` (`animate()`); `docs/design/wing_rig.md`, `wing_rig_plan.html`; auto-sweep in `flight_model.md` |
| `wing_anatomy.md` | Flight muscles and the supracoracoideus pulley, arm muscles and tendons, the propatagium, feather attachment, the airfoil section, the Z-fold and the coupled elbow and wrist; mapped to the rig | `scripts/bird/bird_rig.gd` (`LIMB`, fold IK), `wing_shape.gd`; `docs/design/wing_rig.md` (wing thickness) |
| `body_poses_and_folded_wings.md` | How the folded wing sits on the body, body pitch by state and species, legs, toes and tail when perched, the take-off crouch; rig guidance | `scripts/bird/bird_rig.gd` (`POSE`, fold anchor); `docs/design/body_rig_plan.html` |
| `body_anatomy.md` | The fused trunk, neck vertebrae and the S-curve, pygostyle, leg bones and the "backward knee", toe arrangements, the tendon lock and the automatic perching mechanism, head stabilisation and head-bobbing; mapped to the rig | `scripts/bird/body_shape.gd`, `bird_rig.gd` (neck, legs, head); `docs/design/body_rig_plan.html` |
| `landing_and_takeoff.md` | Perching studies (Harris's hawks, steppe eagle, pigeons, parrotlets, lovebirds), the leg share of take-off speed, foot timing; compared with Flap's landing and leap | `scripts/bird/bird.gd` (LANDING, `FLARE_PITCH`, `PUSH_TIME`), `flight_model.gd` (flare), `bird_profile.gd` (`hop_speed`, catch speed), `bird_rig.gd`, `scripts/ai/ai_pilot.gd`; `docs/design/flight_model.md` §3 |
| `feather_rendering.md` | How feathers are rendered in games and film, the visual effects of real feathers, the parked feather shader | `scripts/bird/feather.gdshader`, `BirdRig.FEATHER_LOOK`, `BirdRig.plain_feathers` |
| `plumage_coloring.md` | Plumage pattern elements, top versus underside colour for the five species, a cheapest-first plan and per-species colour specs | `scripts/bird/plumage.gd`, `BirdRig` colours |
| `eyes_and_beaks.md` | Eyes, beaks and head motion for the five species, and a plan to add them to the rig (written separately) | `scripts/bird/bird_rig.gd`, `body_shape.gd` |

**Sources that refuse automated fetches.** All About Birds (Cornell), the JEB PDFs on `cob.silverchair.com`, ScienceOpen and some publisher sites returned HTTP 403. Claims from them rest on abstracts, journal landing pages or search summaries, and each note says so where it matters.
