# Scapulars: how they lie

Research for the scapular silhouette cards (`BirdRig.CARD_TRACTS` "scapular", `_lay_card`; `test_scapulars`).
Gathered 2026-11-11. No source I could reach gives measured scapular lengths or angles, so every number below
marked [E] is an estimate from the photos.

## Why it mattered

The old cards were a 3 x 4 grid on each side of the back, laid on the tangent at their roots. They showed as two raised
slabs that lit apart from the back. Beside the body, behind the arm wing, the gap to the innermost tertials (4.4 cm on
the owl) showed the white underwing through it. On a bird the scapulars cover that join.

## What the sources say

- **Where they grow.** A narrow band at the shoulder, starting at its middle, just in front of the shoulder joint. It
  runs "obliquely upon the humerus in a direction parallel to that of the shoulder blades" (Nitzsch, *Pterylography*,
  1867, p.25, public domain: https://archive.org/details/nitzschspterylog00nitzrich). Preparators cut "below the
  scapular feathers" to keep them with a spread wing, so they are rooted on the shoulder's skin, not the spine (Wommack,
  MVZ, *How to Prepare a Spread Wing*). [S]
- **Which way they run.** The tract parallels the shoulder blade; it is "not oriented along the humerus either"
  (Jollie 1977, *Evolutionary Theory* 2(4) p.147). Every feather points back toward the tail (Sharpe 1891 tract
  diagram, Commons `HirundoRustica.jpg`). [S] Splay out from straight back about 10-20 deg [E].
- **How they lie.** Flat, one field from the mantle onto the inner coverts, with no ridge, step or gap, in every
  flight photo below. [S, photos]
- **How far onto the spread wing.** The rear scapulars cover the arm wing's root: the bases of the tertials, inner
  secondaries and inner coverts. In the kestrel and sparrow that's about the inner tenth from body to wrist; in the
  red-tail and barn owl, up to about a quarter. [E] This fits the anatomy: strong, broad tracts in birds of prey and
  owls (Nitzsch p.25; Clark 1894 for owls), "few, but very large" feathers in true falcons (Nitzsch p.56), small and
  narrow in songbirds (p.73). [S]
- **Length.** The rear feathers are the longest (Nitzsch). The field reaches from the shoulder to about the rump,
  roughly half the bill-to-tail-base length in the kestrel. [E]
- **Folded.** The large rear scapulars lie on top of the folded wing, over the tertials and the secondaries' bases,
  and hold it against the body (Nitzsch; the mounts below). [S]

## References (checked by eye)

Flight photos from above or behind (Wikimedia Commons):
- Red-tailed Hawk from behind, wings spread: `Red-tailed_hawk_in_flight_from_behind_-_DPLA_-_4f2fbb10f4b2460918161f9a69af2c0e.jpg`
  (Warren Garst, CC BY-SA 4.0). The pale-mottled scapulars make a V, lying flat over the wing roots.
- American Kestrel, male, from above and to the side: `American_Kestrel_(34004033155).jpg` (Ed Dunens, CC BY 2.0).
  The rufous mantle and scapulars form one flat field, ending over the tertials.
- Barn Owl from above and behind: `Barn_Owl_2a_(7637607840).jpg` (Tony Hisgett, CC BY 2.0). The grey-freckled cape
  merges into the coverts; the rear scapulars point straight back over the tertials.
- House Sparrow, wings spread: `Sparrow_wings.jpg` (Ritesh Man Tamrakar, CC BY-SA 2.0). The streaked mantle band runs
  straight back and into the chestnut lesser coverts without a seam.
- Common Raven: `3782_Common_Raven_in_flight.jpg` (Copetersen, CC BY-SA 3.0). The back flows into the coverts with no
  step.

3D (Sketchfab), folded wings unless noted:
- Common Buzzard, spread-wing mount (no CC licence): `common-buzzard-kane-lesni-e11b8169001b4dabbeae52e689a10950`.
- American Kestrel, Florida Museum UF 59281: `american-kestrel-052f197ecc094be7b6c99f3fd870ed6f`.
- Barn Owl, Watt Institution (CC BY): `barn-owl-tyto-alba-608a7502cf2643d9ab4c89294199a8d1`.
- Red-tailed Hawk, University of Iowa SUI:VERT:36305: `red-tailed-hawk-76d55c1ba91e41e8a11ede71582606c1`.
- Common Raven (CC BY): `korppi-corvus-corax-da4bf1396118436888fd32bd3ff5730e`.
- Boston College study skins (CC BY-NC): house sparrow, barred owl, American kestrel.

Spread-wing image collections (Slater Museum, the USFWS Feather Atlas, Featherbase) cut the scapulars off with the
body, so they don't show them. For scale, a male Common Kestrel's tertials are 65.5 / 42.5 / 25 mm and its inner
secondaries about 100 mm (Featherbase specimen 10493).

## In the rig

- **Roots.** A band high on each side of the back (34-64 deg round the trunk, from just ahead of the shoulder to
  0.2 behind it along the trunk), 4 rows of 3. The rows grow from 0.13 to 0.26 L.
- **Direction.** Straight back, splayed out 16 deg x the species' `SCAP_REACH` as the wing spreads (hawk and owl 1,
  crow 0.8, falcon 0.6, sparrow 0.55), and a row's cards fanned apart 10 deg.
- **Lying flat.** Each card is a chord of the surface under it: its tip is set on the back's shell inside the body's
  outline, or on the wing's root (as high as the shoulder) outside it, and the card is arched to meet the surface
  between its ends.
- **Folded.** The tips follow the back's taper (inside 0.7 of its half-width), the cards are 0.72 as long, and the fan
  closes.
- **Each side** follows its own wing's fold (`wing_fold(i)`).
- **Colour.** The back's (a feather of the back's tract), wherever the card is rooted.
- **Light.** Nothing shines through a silhouette card and only its tip catches the edge glow (it lies on the body or
  the wing; `feather_texture.gdshader`, contour rows).

Before and after: `docs/images/scapulars_ab.jpg`. The wing root from above, in numbers: `tests/probe_wing_root.gd`.
