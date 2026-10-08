# Lineman simulator: assets and game loop

Branch `lineman` of RealityHD (clone `~/Dev/RealityHD-lineman`). App: `~/Dev/LinemanVision`
(visionOS 26, depends on this package by local path). Everything is life-size, meters, +Y up.

## Workstreams and clones

| Clone | Branch | Scope |
|---|---|---|
| `~/Dev/RealityHD-lineman-truck` | `lineman-truck` | bucket truck, cab interior, bucket platform |
| `~/Dev/RealityHD-lineman-pole` | `lineman-pole` | pole hardware, damaged pole states |
| `~/Dev/RealityHD-lineman-tools` | `lineman-tools` | handheld lineman tools and PPE |
| `~/Dev/RealityHD-lineman` | `lineman` | scenes, tag additions, merges of the three above |
| `~/Dev/LinemanVision` | `main` | visionOS app, game loop |

Every asset follows AGENTS.md: brief, `realityhd new`, build, lint, gate with `--ref <photo>` (photoreal
comparison against a real reference photo saved under `notes/refs/<id>.jpg`, not committed if
licensed), verdict, sign-off, thumbnail, catalog, `swift test`.

New tags (add once in `Tags.swift`, `lineman` clone owns the merge): `utility`, `electrical`, `ppe`.

## Asset ids (permanent, the app references these strings)

Truck (`Structures/Vehicle/` or `Props/Vehicle/`, tag `vehicle`, `articulated`):

| id | kind | notes |
|---|---|---|
| `bucket-truck` | structure, articulated | White class-7 aerial device truck, ~10.2 m long, 3.6 m stowed height. Conventional cab, white steel utility body with compartment doors, insulated two-section boom (fiberglass upper), turret, jib, single-man fiberglass bucket, 4 outriggers, amber beacons, rear steps. Parts: `turret` (yaw 0...360), `lowerBoom` (pitch 0...80), `upperBoom` (pitch 0...170), `bucketLevel` (keeps bucket level, mimic), `outriggerFL/FR/RL/RR` (slide 0...0.9), `doorL`, `doorR` (hinge 0...70), `wheelFL/FR` steer (-35...35), wheel spin. States `stowed`, `deployed`, `working`. Budget up to 30k. Exposes attachment points: driver eye `driverEye`, bucket floor `bucketFloor`, bucket console `bucketConsole`. |
| `truck-cab-interior` | prop, articulated | Driver area at 1:1: bench/air-ride seat, steering wheel (part `steering`, revolute -540...540), gear selector (`shifter` PRNDL), parking brake knob, pedals `throttle` `brake`, dash cluster with speedometer needle part `speedNeedle`, PTO switch, beacon switch, outrigger control panel. |
| `aerial-bucket` | prop, articulated | Fiberglass bucket 0.6 x 0.6 x 1.07 m with liner, upper control console: single-handle `boomStick` (2-axis), `rotateStick`, `jibLever`, red `estop` (push), `tool-power` toggle, horn, tool hooks, step. |

Pole and line hardware (`Props/Utility/`, tags `prop`, `utility`, `electrical`):

| id | notes |
|---|---|
| `distribution-pole` | 13 m class-3 pole, 3-phase crossarm, pin insulators, neutral, transformer, cutouts, arrester, guy wire. articulated states: `normal`, `damaged` (cracked insulator B, conductor B dropped, cutout A open with blown fuse tube hanging). Parts `cutoutA`, `cutoutB`, `cutoutC` (hinge open 0...-120), `conductorB` option visible. Attachment points per repair site. |
| `pin-insulator` | handheld, porcelain, 15 kV; variant `broken` knob. |
| `polymer-deadend` | gray silicone deadend insulator with clevis/tongue. |
| `fused-cutout` | articulated door, `fuse-tube` swaps. |
| `fuse-link` | handheld. |
| `lightning-arrester` | polymer housed. |
| `hot-line-clamp` | handheld, bronze, eye screw. |
| `automatic-splice` | handheld, aluminum, colored ends. |
| `conductor-coil` | ACSR coil. |
| `pole-transformer` | 25 kVA can, standalone. |

Tools and PPE (`Props/Lineman/`, tags `prop`, `tool`, `handheld` unless noted):

| id | notes |
|---|---|
| `hot-stick` | 2.4 m fiberglass shotgun stick, yellow, part `hook` slide. |
| `voltage-detector` | stick-mount audible detector, LED. |
| `rubber-gloves` | Class 2 red/black insulating gloves (pair). |
| `leather-protectors` | |
| `lineman-pliers` | |
| `cable-cutter` | ratchet cutter. |
| `hydraulic-crimper` | battery crimper with die. |
| `grounding-set` | clamps, clear-jacket copper lead, ferrule. |
| `wire-brush` | |
| `hard-hat` | white class E, prop, `ppe`. |
| `fall-harness` | prop, `ppe`, with lanyard. |
| `insulating-blanket` | orange rubber blanket, clip. |
| `wire-grip` | come-along grip. |

Scenes (`lineman` clone):

| id | notes |
|---|---|
| `lineman-yard` | Utility service yard: concrete lot, chain link, steel shop building, pole stacks, cable spools, truck spawn. |
| `lineman-district` | City route built from `generated-building`, road tiles, `sidewalk-curb`, street furniture, overhead pole line (`distribution-pole` every 40 m) along both streets, job site pole at a T-junction with the `damaged` state. Scene exposes markers `spawn`, `jobsite`, `park` in metadata. |

## Game loop (LinemanVision)

1. **Yard briefing.** Mixed or full immersion at the yard. Work order on a tablet window: outage
   ticket, address, failed parts, voltage (12.47 kV wye). Info card: what a distribution circuit is.
2. **Pre-trip.** Walk-around checklist (tires, outriggers stowed, boom cradled). Tap items.
3. **Cab.** Viewer teleports to `driverEye`. Hand-tracked steering wheel (pinch-and-hold the rim,
   rotation from hand angle), throttle and brake by left-hand pinch distance or game controller.
   Gear selector P/R/N/D. Vehicle physics: bicycle model, max 15 m/s in city, speed limit fines.
4. **Drive.** Route arrow on ground, street names, stop signs scored. Arrive at `park` zone.
5. **Set up.** Parking brake, PTO on, wheel chocks, cones (place 4 by hand), outriggers down from
   the rear panel. Score each step.
6. **PPE.** Grab hard hat, harness (clip lanyard in bucket), rubber gloves (air test: roll the cuff),
   leather protectors. Missing PPE is logged and arc risk raised.
7. **Bucket.** Teleport to `bucketFloor`. Hand-tracked console: grab `boomStick`, deflection drives
   lower/upper boom and turret; `estop` stops all. Minimum approach distance shown as a translucent
   shell on energized parts (0.65 m at 12.47 kV phase-to-ground for unprotected body).
8. **Repair loop** (each job is data, order enforced, wrong order = hazard event):
   test-before-touch with `voltage-detector` on `hot-stick` → open `cutoutA` with hot stick
   (de-energize transformer) → verify dead → install `grounding-set` (ground end first) →
   cover adjacent phases with `insulating-blanket` → replace broken `pin-insulator`
   (cut tie, swap, retie) → splice dropped conductor with `automatic-splice` after `wire-brush`
   → reconnect jumper with `hot-line-clamp` → install new `fuse-link` in cutout tube →
   remove grounds (ground end last) → remove blankets → close cutout with hot stick → power restored.
9. **Stow.** Boom to cradle, outriggers up, cones back, drive back to yard.
10. **Debrief.** Score: safety (MAD breaches, PPE, order), quality (torque/tie OK), time, driving.
    Each step unlocks an info card with the real-world reason (OSHA 1910.269 references).

Failure: touching an energized part without gloves inside MAD triggers arc flash flash/audio,
job fails, explanation card.

## Systems (ECS)

`VehicleComponent` + `VehicleSystem`, `SteeringWheelComponent` (hand angle), `BoomComponent` +
`BoomSystem` (joint rates, limits, MAD check), `EnergizedComponent` (voltage, phase), `ToolComponent`
(tool kind, attach socket), `RepairSiteComponent` (step id, accepts tool kind), `JobRunner`
(state machine from `Jobs/*.json`), `HazardSystem`, `ScoreLedger`, `InfoCardQueue`.
Hand tracking: `ARKitSession` + `HandTrackingProvider`; simulator fallback: pinch drag gestures.
