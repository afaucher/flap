# Audio plan

What Flap needs to sound like, what each sound must do, and where the sounds come from. Dated 2026-11-02. The
first pass is built: see **As built** at the end.

## Where we are

`scripts/audio/flight_audio.gd` (`FlightAudio`, section 7 of `flight_model.md`) is the only sound in the game. It
synthesizes everything in GDScript, sample by sample, into one `AudioStreamGenerator`, driven by `Bird.telemetry()`:
- **wind** that rises with airspeed, flutters in a stall and whistles in a dive;
- a **whoosh** on each speed-band crossing;
- a **thump** on each wingbeat.

Nothing in combat, the world, the perches or the menu makes a sound.

## What squirrel racer does (`..\squirrel-racer\sr\index.html`, "FOREST AUDIO")

Every sound there is synthesized with Web Audio; it has no sound files. Ideas worth taking:
- **Layers that follow where you are.** Canopy wind (band-passed pink noise) with random gusts every 2-7 s, louder
  with height. Leaf rustle (high-passed noise, a 7 Hz flutter) that follows how fast you move. Birdsong that grows
  with height. Crickets near the ground only. Every layer moves on slow time constants (0.25-1.5 s), so nothing
  jumps.
- **Bird calls as recipes.** Each species is a short list of notes `[time, f0, f1, length, wave, level, am]`, swept
  exponentially, with noise notes for harsh calls. Each play shifts pitch about ±5 % and tempo ±7 %, and each note
  wavers ±1.5 %, so no two songs are alike.
- **Calls from real birds in the world.** About half the distant calls come from a bird actually sitting in a nearby
  tree, panned and quietened by distance; the rest are off-screen birds of the same forest. Far calls are low-passed
  (7 kHz down to 4 kHz).
- **One-shots as filtered noise bursts.** A leap is a rising band-pass sweep and a landing is a falling low-pass.
  The camera shutter is two high-passed clicks; a reward is a short sine arpeggio.

Its **Caledonian Pinewood** forest is the same Scots-pine wood that `Pinewood` grows. Its six species already have
recipes ready to port: Eurasian jay, crested tit, great spotted woodpecker, coal tit, robin and chaffinch.

## Principles

1. **Audio reads what the HUD reads.** It reads `Bird.telemetry()`, the `Bird` signals (`perched`, `released`,
   `bonked`) and the `CombatWorld` signals (`burst`, `downed`), plus launcher and HUD state. It never reads
   `FlightModel` itself. This is the same rule as the HUD and the rig (AGENTS.md).
2. **Testable headless.** Every cue goes through one `AudioDirector`, which records it as an event (`{cue, pos,
   gain}`), as `FlightAudio.events` does. Tests assert on cues, for example "a burst 3 m away plays `burst_near`" or
   "lock tone pitch rises with lock progress". Each sound bug we fix gets a mutation entry.
3. **Small-scale world.** The riders are thumb-sized and the rockets are pencil-sized. Bursts should sound like
   firecrackers and cap guns, not artillery, and the launchers should sound like air rifles. Real recordings of big
   things are used pitched up and shortened.
4. **Synthesize what needs live control; use samples where realism matters.**
   - **Synthesize** wind, motors, tones and whooshes, which follow a parameter every frame.
   - **Use samples** for impacts, wood, explosions and real bird calls.
   - **Cost.** GDScript per-sample synthesis costs CPU: `FlightAudio` already runs 22 050 samples a second in a
     script loop. Keep live synthesis to that one generator and bake everything else to WAV with a tool, the way
     the feathers and leg scales are baked (`tools/`, `assets/`). Squirrel racer's recipes port as an offline
     `tools/bake_calls.gd`.
5. **3D where it has a place.** `AudioStreamPlayer3D` with the listener on the chase camera. Use Doppler on rockets,
   seekers and fly-bys (`doppler_tracking` in the physics step), since rockets cross at about 45 m/s.
   - **Occlusion by trunks:** use `ArenaLayout`'s geometry queries, not physics rays.
   - **Voice caps** per cue (`max_polyphony`), plus a 32-voice budget overall.
6. **Buses:** Master, which holds:
   - **Flight**: your bird's wind and wings;
   - **SFX**: combat, impacts and perches;
   - **Ambience**: forest beds and distant birds, through a short, diffuse forest reverb;
   - **UI**: menu and HUD tones, dry.

   A burst within about 5 m briefly ducks Ambience and Flight through a sidechain compressor on SFX. Each bus has
   its own volume in the menu, and there is a mute toggle.
7. **Variations.** Any cue that can repeat within a second has at least three takes, picked round-robin with
   ±4 % pitch jitter. Rockets fire four a second, so they need at least five takes.

## The sound list

Columns:
- **Trigger** names the existing signal or field the sound hangs on.
- **Space**: *2D* means it's your own bird or the HUD; *3D* means it's positioned in the world.
- **Src**: *synth* is live synthesis; *bake* is synthesized offline; *sample* is a recording.
- **P** is priority: 1 is needed before combat playtests, 2 is soon after, 3 is polish.

### Your bird

| Sound | Trigger | Space | Requirements | Src | P |
|---|---|---|---|---|---|
| Wind, stall flutter, dive whistle | telemetry speed / stalled (exists) | 2D | Keep. Add a gust layer and a little stereo width (now mono) | synth | 1 |
| Band whooshes | SpeedBands (exists) | 2D | Keep | synth | - |
| Wingbeat | `flap_count` (exists) | 2D | Per species: crow a heavy whump, hawk and kestrel a crisp beat, sparrow a fast whirr. The owl stays nearly silent (its fringed flight feathers silence it), so its loss of sound is the feature | bake | 1 |
| Flare and air-brake | telemetry: landing flare, high angle of attack at low speed | 2D | A rising, ruffled, broadband whoosh, the bird spreading everything | synth | 2 |
| Perch catch | `perched` | 3D | Talons on bark: a scratch and thunk, louder with arrival speed. A planked outpost sounds wooden | sample | 1 |
| Take-off push | `released` / `_leap` | 3D | A branch spring creak and a first hard wingbeat. Ground take-off: a needle-litter scuff | sample | 2 |
| Ground landing | state becomes GROUNDED | 3D | A crunch of pine-needle litter, by speed | sample | 2 |
| Bonk (tree or branch) | `bonked(normal, speed)` | 3D | A dull bark thud scaled by speed, with bark crumble and a pattering of needles above 6 m/s. Your bird's distress squawk follows (see Calls) | sample | 1 |
| Canopy brush | passing through needle pads near the flight path (ArenaLayout query) | 3D | A fast needle swish, by speed | sample | 3 |
| Out of stamina | EnergyModel empty | 2D | A soft, short rasp (tired), only once per emptying | bake | 3 |

### Combat

| Sound | Trigger | Space | Requirements | Src | P |
|---|---|---|---|---|---|
| Rocket launch | `Launcher.fire`, ROCKETS | 3D at the pod | An air-rifle pop and an ignition hiss, under 0.2 s, with 5+ takes so 4 a second doesn't machine-gun | sample | 1 |
| Rocket motor | the projectile's burn (0.35 s), then coast | 3D, follows the round | A short, fierce hiss with Doppler, then a faint whistle while it coasts. The `Projectile.id` keys the voice | synth or bake loop | 1 |
| Seeker launch | `Launcher.fire`, SEEKERS | 3D | A heavier thunk and a longer ignition | sample | 1 |
| Seeker motor | burn (1.2 s), life 2.2 s | 3D | A steadier, higher rocket hiss with Doppler; it stays loud enough that the target hears it coming | bake loop | 1 |
| Burst, fuse | `CombatWorld.burst(at, "fuse")` | 3D | A firecracker crack. Within 5 m: a punch, a ducking pulse and a short high ring. Far: low-passed with a forest echo tail | sample | 1 |
| Burst on a trunk | `burst` "impact" + what it hit | 3D | Crack + wood splinter + bark crumble | sample | 2 |
| Burst on the ground | `burst` "impact", near the ground | 3D | Crack + dirt and needle thump | sample | 2 |
| Fizzle | `burst` "expired" | 3D | A small dull pop in the air, clearly harmless | sample | 2 |
| Feathers knocked out | `CombatWorld.hit` / `lose_feathers` | 3D (2D if it's you) | A soft feather-puff swish, and the bird's distress call | sample | 1 |
| Downed | `downed(bird)` | 3D | A long distress call and a ragged falling flutter. If it's you, the wind thins out | sample | 1 |
| Respawn | `CombatWorld.respawn` | 2D | A soft rustle as the bird settles | bake | 3 |
| Score | `score` changes | 2D | A short, warm two-note sting: up for us, down for them | bake | 2 |
| Weapon switch | weapon changes | 2D | A small mechanical clack | sample | 2 |
| Empty | fire pressed with no ammo | 2D | A dry click, at most once per press | sample | 1 |
| Friend in the line | `friend_in_line()` while you fire | 2D | A short muted buzz ("hold fire") | bake | 2 |
| Near miss | a round passes within 3 m of you | 3D | A whizz-by: the motor's Doppler sweep does most of it, and a crack adds to it | synth | 3 |

### Locks and warnings (HUD tones, 2D, all synthesized: they're signals, not foley)

| Sound | Trigger | Requirements | P |
|---|---|---|---|
| Lock building | `Launcher.lock` 0..1 | Slow beeps that speed up and rise in pitch as the lock grows. It must be readable without looking, as the tone is the point | 1 |
| Locked | `locked()` | A steady high tone, distinct from the building beeps, while the lock holds; it stops the moment it drops | 1 |
| Being locked | an enemy launcher has `lock_target == you` | A low, slow pulse, different in pitch and rhythm from your own lock tone so the two never get confused | 1 |
| Incoming | a seeker targeting you, or `threat_to(you)` | A fast rising warble that gets faster as it closes: the "tail warning" in `concept_briefs.html` | 1 |

### The base (outposts)

| Sound | Trigger | Space | Requirements | P |
|---|---|---|---|---|
| Rearm ticks | each round restored during `RESTOCK_TIME` (2 s) | 3D at the rail | A brass clink per round, so you hear the rack fill | 1 |
| Rearmed | ammo full | 2D | A small bright chime, the cue to leave | 1 |
| Mend | feathers restored | 3D | A soft feather rustle | 2 |
| Outpost life | near an outpost | 3D loop | A windsock flapping in gusts, a hangar creak. Ground crew comes later, when the art has them | 3 |

### The forest (Ambience bus)

These follow squirrel racer's layer model, driven by your bird's height and speed.

| Layer | Requirements | Src | P |
|---|---|---|---|
| Canopy wind | A gusting band of noise in the pines, louder and brighter with height. Gusts shared with the windsock and, later, swaying trees | synth (fold into the existing generator) | 1 |
| Pine creak | Rare trunk creaks on strong gusts, 3D on nearby big pines | sample | 3 |
| Ground insects | A warm summer afternoon: grasshoppers and crickets near the ground, fading out by about 10 m up | bake | 2 |
| Distant birdsong | Caledonian pinewood species: chaffinch, coal tit, crested tit, robin, a jay's screech, woodpecker drumming. Every 1.5-5 s, more often higher up, panned in 3D at a believable distance and low-passed with range | bake (port squirrel racer's recipes) | 1 |
| Clearing | Less reverb and more insects in the open clearing; more reverb among the trunks | reverb send | 3 |

### Bird calls (the five species)

Two calls each: a **contact call**, used for ambient AI chatter and at a base, and an **alarm/distress call**, used
when hit, when downed, and by the AI when mobbing.

| Species | Contact | Alarm / distress | Source plan |
|---|---|---|---|
| Crow | "caw" in twos and threes | Harsh rapid caws (mobbing) | Freesound CC0 recordings |
| Owl (barn owl in-game) | Barn owls screech rather than hoot. Use the screech; avoid the tawny "twit-twoo" cliché unless you want it | A hiss and a scream | Freesound (check the licence per file); fallback bake |
| Hawk | The red-tailed scream "kee-eeer" | Repeated shorter screams | Freesound CC0 |
| Kestrel | "kee-kee-kee" | Faster, shriller "kee-kee" | Bake: an easy recipe. Freesound has one, licence unverified |
| Sparrow | "chirrup" chirps | A rattling scold | Bake: an easy recipe (squirrel racer style) |

Calls in combat need a voice cap (one per bird, a 0.8 s cooldown). Ambient AI chatter goes on the Ambience bus.

### Menu and UI

Menu move, confirm and back, open and close, and pause. Use one small consistent set (Kenney Interface Sounds),
dry, on the UI bus. P2.

### Not planned

- **Music.** None is planned. It's your call (see Decisions). The stings above leave room for it.
- **Rider voices.** Not planned until the riders do something.

## Free sources

Only licences that allow a commercial game. **The repo is public on GitHub**, and that decides more than the
licence's commercial clause does: committing a sound file to the repo distributes it as a standalone file.

| Source | Licence | Commercial | Public repo | Good for |
|---|---|---|---|---|
| [Kenney](https://kenney.nl/assets) audio packs | CC0 | yes | yes | [Impact Sounds](https://kenney.nl/assets/impact-sounds) (130 files: wood, plank, light hits: perch catch, bonk, clacks); [Interface Sounds](https://kenney.nl/assets/interface-sounds) (menu); [RPG Audio](https://kenney.nl/assets/rpg-audio) (50 files: metal clinks for the rearm ticks, foley); [Sci-Fi Sounds](https://kenney.nl/assets/sci-fi-sounds) (explosions, probably too sci-fi) |
| [Freesound](https://freesound.org), CC0 filter | CC0 | yes | yes | Real bird calls and forest beds (leads below) |
| Freesound, CC BY | attribution | yes | yes, credited in `assets/LICENSES.md` | Widens the bird-call choice (e.g. Benboncan's owl recordings) |
| [Sonniss #GameAudioGDC](https://sonniss.com/gameaudiogdc/) bundles (2015-2026, tens of GB) | [royalty-free, no attribution](https://sonniss.com/gdc-bundle-license/) | yes | **no**: the licence forbids redistributing the sounds as sounds; finished games are fine | The best explosions, impacts and foley. Usable only if those files stay out of git (gitignored, fetched from your own download) or are reworked into our own baked sounds |
| [Pixabay sound effects](https://pixabay.com/service/license/) | Pixabay Content License | yes | doubtful: no standalone redistribution | Gap filling only, same caveat as Sonniss |
| [xeno-canto](https://xeno-canto.org/about/terms) | per recording, [mostly CC BY-NC(-ND)](https://www.xeno-canto.org/help/FAQ) | mostly **no** | - | Avoid; ND also forbids editing |
| [BBC Sound Effects](https://sound-effects.bbcrewind.co.uk) (RemArc) | personal, education and research only | **no** | - | Avoid |

Freesound CC0 leads found (check each page's licence before downloading; licences can change):
- **Crow:** giddster [437345](https://freesound.org/people/giddster/sounds/437345/) (crows in trees),
  nigelcoop [75162](https://freesound.org/people/nigelcoop/sounds/75162/) (caw while flying off, cleaned),
  ken788 [386768](https://freesound.org/people/ken788/sounds/386768/) (1:48 of cawing).
- **Owl:** Breviceps [465697](https://freesound.org/people/Breviceps/sounds/465697/) (hoot),
  raoul_slayer [203598](https://freesound.org/people/raoul_slayer/sounds/203598/) (crickets and a tawny owl at
  night: also a ground-insect bed). No barn owl screech found yet.
- **Red-tailed hawk:** TRP [616995](https://freesound.org/people/TRP/sounds/616995/) and
  [616926](https://freesound.org/people/TRP/sounds/616926/) (isolated calls).
- **Kestrel:** YleArkisto [352263](https://freesound.org/people/YleArkisto/sounds/352263/): licence not confirmed.
- **Forest beds:** wind, alppdcjr12 [662575](https://freesound.org/people/alppdcjr12/sounds/662575/) and
  Noted451 [531016](https://freesound.org/people/Noted451/sounds/531016/); a bird loop, Magnesus
  [723913](https://freesound.org/people/Magnesus/sounds/723913/). We'd rather synthesize the canopy wind (it must
  follow height and gusts) and bake the birdsong (so it's this forest's species), so these are references more than
  assets.

**Gaps nothing free covers well:**
- **Tiny-scale bursts.** Try CC0 firecracker and cap-gun recordings, pitched and layered with a baked crack.
- **Talons on bark.** Try Kenney's wood scrapes, or a 10-minute home recording of a fork on pine bark: our own
  recording is CC0 by definition.
- **A barn owl screech.**
- **Sparrow and kestrel calls.** Bake these from recipes.

## Build order

1. **`AudioDirector` + buses + cue events.**
   - Move `FlightAudio` onto the Flight bus.
   - Add `tools/bake_calls.gd`, porting squirrel racer's call engine and its six pinewood recipes, with our five
     species added.
   - Tests: cue events per signal.
2. **The combat loop (P1):** rocket and seeker launch and motor, burst near and far, hit, downed, empty, the four
   lock and warning tones, and the rearm ticks and chime.
3. **The forest:** canopy wind and gusts in the generator, birdsong, perch catch, bonk and wingbeats per species.
4. **P2, then P3.**

Each step lands with its tests, a mutation entry per fixed bug, and an A/B recording (a short capture of the same
scripted flight before and after, via the bird lab or the range) in place of the A/B images we use for visual
changes.

## Decisions

Settled (user, 2026-11-02):
- **Synthesize what the plan proposed.** The user will record claws on a cat tree for the perch catch.
- **Fireworks:** use ..\cast's firework recording for the bursts.

Still open:
1. **Sonniss:** not used so far. Using it means a gitignored `assets/audio/external/`, fetched by a setup step from
   your own download.
2. **The owl's voice:** a barn owl screech for now (true to the model). The alternative is a hoot (what players
   expect).
3. **Music:** none, menu only, or a light in-flight score?
4. **Your own bird's call:** should your bird ever call, for example on a button?

## As built (2026-11-02)

**Code** (`scripts/audio/`):
- `GameAudio` decides what plays when. Its inputs:
  - your bird's telemetry;
  - the `Bird` signals (`perched`, `released`, `bonked`);
  - the `CombatWorld` signals (`launched`, `burst`, `struck`, `downed`);
  - the launchers' public state (`lock`, `lock_target`, `shots`, `dry_fires`, `on_base()`, `full()`).

  It records every cue it asks for in `events`, so `test_sounds` checks what would be heard, headless.
- `Sfx` plays cues, ported from ..\cast's `Sfx`:
  - pooled players and a voice cap per cue;
  - a minimum gap between plays, and pitch jitter;
  - takes picked at random, never the same one twice running;
  - 3D players with Doppler and a distance low-pass.
- `FlightAudio` keeps the live wind, whooshes and wingbeats. The wingbeat is now per species, and the owl's is next to
  silent. It plays on the Flight bus.

**Buses** (`default_bus_layout.tres`):
- Master has a limiter.
- Flight and Ambience duck under SFX through a sidechain compressor.
- Ambience also has a short forest reverb.
- UI is dry.

**Sounds:**
- `SoundRecipes` holds 46 sounds (89 takes), built on `SoundDsp` (filters, noise, tones, note lists, loops).
- `tools/bake_sounds.gd` bakes them into `assets/audio/sfx/` in about 4 s.
- Everything is synthesized except the bursts, which are built on the bang of the CC0 firework recording that ..\cast
  uses (Freesound 336008), pitched up 3-7 semitones.
- The pinewood birdsong is squirrel racer's recipes, ported.
- **Stand-ins:**
  - `perch_catch`, until the cat-tree recording;
  - the five species' calls, synthesized after their real calls.

**Not built yet:**
- the near-miss whizz;
- the canopy brush;
- the out-of-stamina rasp;
- trunk creaks and outpost life;
- clearing versus trunk reverb;
- menu sounds;
- per-bus volume in the menu.
