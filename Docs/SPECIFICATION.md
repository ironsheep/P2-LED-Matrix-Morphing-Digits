# Morphing Digits for HUB75: Specification

**Status:** draft 1, 2026-10-10. Written with Stephen M. Moraco during sprint planning.
**Applies to:** the release that completes `Docs/plans/V4-DISPLAY-QUALITY-SPRINT-PLAN.md`, and later releases.
**Scope:** the behavior a user of this library can observe and rely on. How it is built lives in the sprint plan and in the code. Each requirement has an ID (`R-x.y`) so tests and changes can cite it.

---

## 1. What this library is

**R-1.1** This library paints changing numbers, drawn as morphing seven-segment digits, onto a HUB75 LED matrix display driven by a Parallax Propeller 2.

**R-1.2** It is a **numeric transition system**: anything that can be expressed as a number can be shown, including clocks, timers, counters and status values.

**R-1.3** It paints; it does not manage the display. Panel layout, mounting rotation, brightness, refresh and pin assignment belong to the [P2 HUB75 LED Matrix Driver](https://github.com/ironsheep/P2-HUB75-LED-Matrix-Driver). The library takes the display as the driver presents it ("as mounted") and owns only what it draws.

**R-1.4** It requires HUB75 driver **v4.0.0 or later** and is distributed separately from it. Users install the driver, then copy this library's files over it.

**R-1.5** It runs in the caller's cog and starts no cogs of its own.

## 2. Terms

| Term | Meaning |
|---|---|
| **Display** | The drawing surface the driver provides: its full width × height in pixels, as mounted (e.g. the "quad", 256 × 128). |
| **Area** | A rectangle of the display, in display pixel coordinates (origin top-left), that the caller hands to a group. |
| **Group** | One numeric display: a clock, a counter or a value, made of one or more digits plus any separators. |
| **Digit** | Seven segments, A-G, in the standard arrangement. |
| **Segment** | One bar of a digit. |
| **Transition** | The animated change of a digit from one value to another. |
| **Frame** | One complete picture handed to the driver. |

## 3. Groups

**R-3.1 Types.** A group is one of:
- **Clock:** shows time of day or elapsed time (R-3.3).
- **Up counter:** counts up by one per step and wraps to zero after its maximum.
- **Down counter:** counts down by one per step and wraps to its maximum after zero.
- **Value:** shows whatever number the caller sets.
- **Random:** shows a new random value each step (a showcase type).

**R-3.2 Digit count.** Counters and value groups have 1 to 6 digits. Their maximum is 10ⁿ − 1 for n digits. Values outside 0..max are refused (R-10.2).

**R-3.3 Clock formats.** A clock group is one of these formats:

| Format | Shows | Range |
|---|---|---|
| `MM:SS` | minutes and seconds | 00:00 – 59:59 |
| `HH:MM` | hours and minutes | 12h: 1:00 – 12:59 · 24h: 00:00 – 23:59 |
| `HH:MM:SS` | hours, minutes, seconds | 12h: 1:00:00 – 12:59:59 · 24h: 00:00:00 – 23:59:59 |

**R-3.4 12-hour rule.** In 12-hour mode the hour shown is always 1-12. Zero is never shown as an hour, and 12:59 is followed by 1:00.

**R-3.5 24-hour rule.** In 24-hour mode, 23:59 (or 23:59:59) is followed by 00:00 (or 00:00:00).

**R-3.6 Clock modes.** A clock advances in one of two modes:
- **Real time:** one second per second, from a start time the caller gives.
- **Accelerated:** one unit per caller-chosen interval, for demonstrations.

**R-3.7 Caller-driven values.** The caller can set any group's value at any time: `setTime` for clocks, `setValue` for counters and value groups. Doing so is how the library shows state from elsewhere in the P2 (the status-panel pattern). Where time comes from (a compiled-in start, an external clock chip, a network) is the caller's business.

**R-3.8 Separators.** Clock groups show colon separators between their fields. The colon pulses once per real second in real-time mode. Its look follows the group's color and style.

**R-3.9 Independence.** Every group's settings are its own. Groups of different types, sizes, stroke weights, colors and orientations can share one display at the same time.

## 4. Digits and segments

**R-4.1 Digit shapes.** Digits 0-9 use the standard seven-segment patterns (`segmentsByDigit` in `isp_hub75_morph7seg.spin2`). 6, 7 and 9 use the forms in that table.

**R-4.2 Stroke weight.** Segment thickness is per group, from **1 pixel** up to the largest the group's area allows. A 1-pixel group and a thick group can sit next to each other.

**R-4.3 Segment shape.** Segments are drawn as smooth, anti-aliased shapes: edge pixels are lit in proportion to how much of the shape covers them. The ends are one of:
- **Square:** a flat end.
- **Angled:** the classic pointed seven-segment end. Thicknesses below 3 pixels draw square ends, because an angle can't be shown.

**R-4.4 Cross-section.** A segment's brightness across its width is either:
- **Flat:** even across the width.
- **Tube:** brightest along the center line, like a lit LED or VFD segment.

**R-4.5 Defaults.** The default end style and cross-section are chosen by eye on the target display during the first release's certification, and recorded here when chosen.

## 5. Transitions

**R-5.1 Which segments move, and how.** For every from→to digit pair, the segments that turn on or off, and the direction each one travels, are given by the transition table that `Generator/pymorph.py` produces. That table is the authority on transition choreography. This specification does not restate it.

**R-5.2 Movement styles.** A segment turns on or off by one of:
- growing or shrinking along its length (top-down, bottom-up, left-to-right, right-to-left);
- the left verticals (E, F) sliding sideways as a whole column;
- switching immediately.

**R-5.3 Smooth motion.** Moving segments are drawn at the display's frame rate. The moving end of a segment is drawn with one of:
- **Soft tail (default):** a brightness gradient several pixels long behind the moving end.
- **Fractional edge:** a single edge pixel lit in proportion to how far the end has advanced into it.

Movement shows no visible one-pixel jumps.

**R-5.4 Timing is time-based.** A transition takes the same real time (a set duration, e.g. 300 ms) regardless of digit size, scene density or frame rate. If a frame is late, the next frame shows the position for the current time; motion never slows down to catch up.

**R-5.5 Interruptions.** A new value that arrives while a transition is still in flight starts the next transition from the segments' current state. The digit always ends on the correct final pattern.

**R-5.6 First appearance.** A group placed with an initial value shows that value's segments growing in, rather than appearing all at once.

**R-5.7 Correct end state.** When any transition completes, the digit's pixels are exactly the pixels of the target digit drawn at rest.

## 6. Color

**R-6.1 Color per group.** Each group has one 24-bit color (`$RRGGBB`).

**R-6.2 Perceptual brightness.** Partial brightness (tails, edges, anti-aliasing, the tube cross-section) is gamma-corrected, so equal steps look equal. A color's full brightness matches the driver's own rendering of that color exactly.

**R-6.3 No color bleed.** A channel that is zero in the group's color is zero in every pixel of that group, at every brightness.

**R-6.4 Global brightness** is the driver's (R-1.3). The library never changes it.

## 7. Orientation

**R-7.1 Rotation per group.** Each group is drawn at one of four rotations: **0°**, **90° left**, **90° right** or **180°** (upside down).

**R-7.2 Motion rotates with the digit.** A segment that grows "top-down" grows from the rotated digit's top.

**R-7.3 Independent of mounting.** Group rotation is separate from, and combines with, the driver's display mounting rotation. It is never a substitute for it.

## 8. Placement and layout

**R-8.1 Placing by area.** A group is placed by giving it an area. It sizes itself to the largest digits that fit, with proportional spacing and separators, and centers itself in the area. It reports the size it actually used.

**R-8.2 Explicit stroke weight.** The caller may fix the stroke thickness instead of letting it be computed (R-4.2).

**R-8.3 Any area.** Any rectangle of the display is a valid area, from small (e.g. 32 × 32) up to the whole display, in landscape or portrait shape. A smaller display is simply a smaller area: the library behaves the same on a 64 × 32 panel as in a 64 × 32 area of a larger display.

**R-8.4 Groups stay in their area.** A group never draws outside its area, nor outside the display.

**R-8.5 Overlap.** Areas are the caller's to arrange. If two groups' areas overlap, the group drawn later wins where they overlap.

## 9. Frame rate and performance

**R-9.1 Frame-rate goal.** The library delivers at least **60 new frames per second** on the target display (the quad, 256 × 128, at full 8-bit color depth), including the densest showcase scene. Smaller displays and areas are no slower.

**R-9.2 One commit per frame.** The library's frame loop hands the driver at most one frame per display refresh, and uses the driver's frame hand-off as its pace.

**R-9.3 Only change costs.** Groups and segments that are not changing cost nothing per frame.

**R-9.4 Recorded performance.** Measured performance (primitive costs, frames per second for each showcase scene) is recorded in `Docs/analysis/performance-baseline.md`. No release may be slower than that record beyond measurement noise. A release that aims to be faster must show the gain there.

**R-9.5 Capacity.** The number of groups one program can hold is limited by hub memory. The supported maximum is stated in the README for each release.

## 10. Errors

**R-10.1 Error codes, not crashes.** Placement and setter calls return an error code when given an invalid request; they never draw garbage or abort. Invalid requests include:
- an area too small for the requested digits;
- a thickness larger than fits;
- an unknown type, format or rotation;
- an out-of-range value or time.

**R-10.2 No partial effect.** A refused call leaves the display and the group's state unchanged.

## 11. Version

**R-11.1 Version format.** Releases are numbered `vMAJOR.MINOR.PATCH` with standard semantic-versioning meaning. `ChangeLog.md` is the source of the number.

**R-11.2 Visible to readers.** Every library file carries the release version in its header.

**R-11.3 Visible to code.** The top-level group object exposes the version as a constant (`MORPH_VERSION`), so programs can display or log it.

**R-11.4 Demos.** Demo and test programs carry no version stamp of their own. They show the library's constant.

## 12. Demonstrations

**R-12.1 Showcase demo.** `demo_hub75_morphSeg.spin2` shows the library's range by rotating through scenes. Between scenes, all digits morph out and the next scene's digits morph in. The scenes cover at least:
- one large clock;
- mixed sizes and stroke weights;
- a "splatter" of many groups of every type, size, color and rotation running at once;
- a status panel of meaningful values: a real-time clock, uptime, a countdown, and the live frame rate;
- one group shown at all four rotations.

It shows the library version at start-up.

**R-12.2 Minimal example.** `demo_hub75_morphClock.spin2` is the shortest correct program that shows one clock. It is the starting point for users' own programs.

## 13. Certification

**R-13.1 Tested on hardware.** Behavior and performance are certified on the target display by Spin2 test programs that report through the debug output to log files: one PASS or FAIL line per check, timing figures, and a summary.

**R-13.2 Release gates.** Before every release, two kept test sets must pass on the target display:
- the **range gate**: every behavior in this specification, at its edges;
- the **performance gate**: R-9.1 and R-9.4.

The evidence (log excerpt and commit) is recorded for the release.

**R-13.3 Target display.** Certification uses the "quad": four 128 × 64 panels in a 2 × 2 grid, 256 × 128 pixels, at full 8-bit color depth.

## 14. Distribution

**R-14.1 What ships.** This project distributes only its own files:
- the library objects;
- the demos;
- the test programs;
- the generator;
- the docs.

It never ships, edits or versions driver files.

**R-14.2 File names.** Library files are named `isp_hub75_morph*.spin2`. Demo and test programs are named `demo_hub75_morph*.spin2`.

## 15. Out of scope

- Alphanumeric characters. The generator could be extended to them later; this specification covers digits 0-9.
- Managing the display in any way (R-1.3).
- Supplying real time. Clock chips and network time are the caller's business (R-3.7).
- Driving more than one HUB75 adapter from one program. This is not required; whether it works is untested.
