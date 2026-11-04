# Fighting tactics

The tactics a tutorial should teach, in the order a new pilot needs them. Written for players; the numbers are the
game's own (`Launcher`, `Projectile`, `CombatWorld`, `CombatStyle`) and what the combat AI was measured doing
(`docs/design/combat_ai.md`). When a number here changes in the code, change it here.

## 1. Your weapons

Your rider's launcher is bolted to the saddle facing forward: **you aim by flying the bird**. There's a pod each side,
and you choose each: rockets, seekers or a gun. With two different kinds, **Q / RB switches** between them.

**Rockets** (three a pod; fire is held for four a second). Unguided. Each has a proximity fuse that bursts within about 1 m
of a bird once it has flown 3 m. So a rocket has to *pass close*, not merely be near: fly the gunsight onto the lead
marker, the point the target will be at when the rocket gets there.
- Best from **8-22 m** behind: close enough that the target can't turn away during the flight, far enough that you
  aren't flying into it.
- Against a turning target, lead *inside* its turn; the marker already does.

**Gun** (40 rounds a pod; ten a second while fire is held, a tap fires three). Fast bullets, about 40 m at most, aimed
at the same lead marker as rockets (it sits much closer to the target: a bullet takes a fifth of a second to 20 m).
- A bullet has no fuse: it has to **hit the bird itself**, so a hawk is far easier to hit than a sparrow.
- Each hit takes a feather; more hits within a second take a third of one each. The gun **wears a bird down**
  over a long burst; rockets and seekers finish it.
- No stun: a bird you hit keeps flying, and keeps fighting.

**Seekers** (two a pod). Guided: lock on, then fire.
- Hold the target within **15°** of your nose for **1 s** to lock. Once building, the lock survives the target
  wandering out to **25°**; beyond that it's dropped.
- Lock range **6-40 m**. Hang back at **12-28 m**: inside 12 m a jinking target sweeps out of the cone.
- **The seeker head needs to see the target.** A trunk, a branch or an outpost's deck on the line between you
  stops the lock building; past a quarter of a second it starts to drain. Leaves don't count.
- Fire only when locked. A seeker fired without a lock flies straight.

**The machine gun** (40 rounds a pod, ten a second while fire is held; a tap fires a burst of three). Bullets fly at
about 95 m/s and die at about 40 m, scattering a little. A bullet has no fuse: it has to pass *through* the bird,
within a few tens of centimetres of its centre (a sparrow is a small target).
- Fly the lead marker and fire bursts at **6-18 m**. Beyond that the scatter spreads past the bird.
- A hit takes one feather, but hits within a second of the last take only a third of one. Sustained fire chips about a
  feather a second: the gun wears a bird down, and a rocket or seeker finishes it.
- It's best against a bird flying straight, busy with someone else. Against a bird that breaks, your nose can't stay on
  it: fire short snapshots as it crosses your sight.

## 2. Damage

A hit knocks out the flight feathers nearest it, about 2.5 at a time. That wing loses area and drops: **hold the stick
against the roll**. Eight feathers down and you fall. Hits within a second of each other take at most one more
feather (a bullet, a third of one), so a single salvo can't down you outright: break away after the first hit. A
stream of bullets costs you about a feather a second: get out of its line.

Sitting on **your team's base** (an outpost's rail) for 2 s rearms you and grows the feathers back. Any other perch
only rests you.

## 3. Energy

Height is stored speed, and speed is how you turn and escape.
- Flapping costs stamina; a weak beat (low on stamina) costs double. Gliding is free. Resting on a perch restores it.
- **Low and slow is where birds die**: no height to dive for speed, no speed to turn, the ground under you. A
  stalled wing drops the nose: let it, don't keep pulling.
- Diving trades height for speed; a pull-out shares the wing's lift with any turn you're making. Pull out first,
  then turn.

## 4. Defending against seekers

**Before it's fired: deny the lock.** You get a warning when someone is locking you.
- **Break toward the attacker's side.** Its nose has to swing across yours to keep you in the cone, and the lock
  breaks. Re-pick the side every half second or so. Measured against a seeker crow: a pilot defending this way takes
  2-4 hits where flying straight takes 11-15.
- Don't weave left-right-left: as you swing back you cross its nose and it locks.
- **Put wood between you.** With a trunk on the line the lock can't build. This works when a trunk is already near
  the line. A long run to a distant trunk is a straight line, which is the easiest lock of all.

**Once it's fired: drag it into a trunk.** In open air no level break beats a locked seeker. Among the trunks you can:
- Fly close past a trunk ahead and **hook in behind it** (as seen from the seeker). The seeker cuts the corner after
  you and hits the wood.
- It works with a trunk **2.5-3 m** off your line. Closer than about 2 m there isn't room to turn in behind it after
  you see the seeker coming. Start the hook early.
- Small, quick-rolling birds (the sparrow) do this best. A wide turner can't hook in behind in time.

## 5. Defending against rockets and the gun

A rocket from inside about 15 m arrives before you can roll. You can't dodge it once it's fired; you dodge the bird
holding it.
- **Don't let a rocket bird settle behind you at close range.** Jink when one is lined up on you (nose on you,
  inside ~30 m), before it fires.
- A rocket that misses flies on: don't fly through its line.
- **Against the gun, keep breaking.** Bullets are too fast to dodge once fired, but a gunner needs you steady in its
  sight; a bird that keeps turning is hard to hit.

## 6. Attacking

- **Choose a target nobody else is on.** Two on one leaves an enemy free behind you.
- **Seekers:** stay in the 12-28 m band; speed up to close and ease off to fall back. Line up so no trunk is on the
  line to the target; if one is, shift until it isn't.
- **Rockets:** close to 8-22 m, hold the gunsight on the lead marker, and fire when it's steady. Don't chase into the
  trunks: a rocket bird among them spends its time dodging wood.
- **Friendly fire is on.** A teal cross over the gunsight means a teammate is in your line of fire: hold.
- **When you're out of rounds, go home** to rearm, by a route away from the fight.

## 7. Using the wood

The wood isn't scenery; it's half the fight.
- **Trunks are shields** against seekers: they block locks and catch the rounds themselves.
- **Clearings and gaps** are open air: good for a seeker bird hunting, bad for a bird being hunted.
- **Low among the trunks** is a turn fighter's home and a seeker bird's trap.
- **Perches above where the enemy flies** are ambush seats: the owl sits, waits, and drops on a bird passing below.
- *(Coming: thermals over the clearings, free height for a bird that circles in them. Circling is slow and steady,
  though: the easiest target there is.)*

## 8. The birds

| Bird | Rounds | How it fights |
|---|---|---|
| **Sparrow** | Rockets | Turn fighter. Rolls fastest; at home low among the trunks; the best at dragging seekers into wood. |
| **Crow** | Seekers | All-rounder. Hunts from 12-28 m, denies locks well, too wide a turn to drag seekers past trunks. |
| **Owl** | Seekers | Ambusher. Floats slow; perches above the fight, waits, drops on a bird passing below. |
| **Hawk** | Rockets | Boom and zoom. Climbs above the target, stoops on it, zooms back up. Never fights low and slow. |
| **Falcon** | Rockets | Boom and zoom, more so: the fastest stoop, the widest turn, a high stall. Needs its height every moment. |

**Boom and zoom**, for the hawk and the falcon:
1. Climb: run out from the target and climb above it.
2. Stoop: dive on it from above with your rounds ready, one pass.
3. Zoom: pull up and climb away on the dive's speed.

Then do it again. Don't turn with a bird that out-turns you.

## 9. Teams and bases

- Each team has a base: its outpost. A downed bird comes back on it, mended and rearmed.
- The score is enemies downed.
- Spread out: share targets out, and cover a teammate who's being chased by attacking the bird behind it.
