# Lessons: mistakes already made

Each was found, fixed, and (mostly) has a mutation entry in `tests/regressions/mutations.json`. The pattern behind
most of them: **a part built from its own constants instead of the reference, checked by eye instead of by a
measurement of what is drawn.**

## Measure the drawn thing
- Every feather was drawn at half width: the outline peaked at 0.5 of the instance width. Found only by measuring
  the drawn mesh, not the constants (`feathers-half-width`).
- The beaks were all "17-25% too long" by a metric comparison that forgot our heads are ~1.2x life; measured against
  the head, only the kestrel's was (it used peregrine data). Compare in the units the rig is built in.
- Bills from one parametric shape read as generic across species; tracing each photo fixed the shape, a per-pixel
  shader fixed the smeared colour (`bill-generic-profile`).

## Joins and seams
- The neck seam: a ring low on the nape left a notch; entering along the axis made a crease; unpinned normals lit
  the join wrong (up to 177 deg apart); colours stopped at the ring; the throat curled in so the head looked thrust
  forward (`neck-*`, `head-*`, `gpu-neck-*`).
- The upright owl's retracted head sat off its nape: placed in world terms, not the body's.
- The eye sat on top of the bill's base until the eye seat and the snout (`eye-seat-ignored`, `bill-no-snout`);
  moving eyes back while they still faced the optic axis buried them (`eye-cap-off-seat`).
- The snout's flat top aimed at the culmen made a shelf; without a flat top a block showed; too wide, it poked through
  the kestrel's bill.
- The leg loop smeared along the belly (`leg-loop-off-shell`); the ankle folded (`leg-ankle-fold`); the pad sat in the
  bark; toes ignored their heading.

## Folding and poses
- The folded wing stood in a raised V (the elbow pole); per-kind layers z-fought; fairings stood up as a slab; tucking
  by plain rotation turned the pale underside out -> one stacking order, a shared folded normal, no arch folded.
- The alula sat on the forearm's end, floating; it rides the hand.
- Tucked legs flipped through the back in the owl's flare; feet snapped at touchdown; tucked feet level in the body
  looked on backwards; perched legs crossed on a turned bird.
- The owl's disc sat low, "a face plate on a brown dome" (`owl-disc-low`, `owl-chin-band`).
- A head target behind and below swung the yaw past vertical (`head-yaw-past-vertical`).

## Looks
- The first feather shader looked worse than flat colour (sheen flooded the cards): parked, not shipped.
- Body tiles too busy ("pinecone / leopard"); square covert tips ("tombstones"); a mirrored projection's herringbone
  down the keel; down shells as floating dashed lines -> replaced by fraying the body's edge.
- Silhouette cards made larger and lifted stood off the back as a shelf.
- `BACKLIGHT` is shadowed by the feather above: use transmittance.
- Heads at 2x life forced stubby beaks.

## Numbers
- An unsplit lift rotation steepened every glide ~0.6 deg; the phugoid damper misread flap thrust and held the nose
  ~5 deg low; the damper could stall the wing in a steep dive ("only the stick can").
- The climb trim at the true Vy dived birds to the stall on letting go: floored at v*.
- Tack scaling once forced owl and sparrow special cases: one rider size all birds carry (8.5 cm).
- The first legs cost 3.9 ms a bird a tick and spiralled the game to 8 fps: measure a new rig part's cost.

## Stale docs to fix when you're near them
- `wing_anatomy.md` 7.2 still puts the alula on the forearm's end.
- `wing_rig.md` plans Godot IK nodes and ~70 feathers (built: GDScript IK, ~120); it and `wing_rig_plan.html` disagree
  on which digits carry p7-p10.
- `body_rig_plan.html` section 5 and `body_anatomy.md` 8.4 have old proportions (head 0.105); `eyes_and_beaks.md` gives
  the owl's skull z 0.8 (code 0.7).
- `BodyShape.DATA.head_yaw` is unused (Face's is read).
- `plumage.gd` says only the hawk has a level-6 look (falcon, owl, sparrow are tuned too); `plumage_coloring.md` section 5
  gives peregrine values for the falcon (coloured as a kestrel); `feather_texture_study.md` gives first-pass atlas sizes.
