# V4-DISPLAY-QUALITY — Sprint Plan

**Status:** planned, 2026-10-10. Not started. The release version is agreed at `sprint-start`.
**Scope confirmed by Stephen, 2026-10-10:** "yes your recommendation" to these six items:
1. Testing.
2. Color resolution.
3. Presentation, layout and frame pacing.
4. Version stamping («#117»).
5. Docs.
6. Hardware certification inside the sprint.

The style checker «#118» and the audit «#119» ride along. Audit findings are fixed in the files this sprint rewrites; untouched files are recorded only.

## § Open Questions

None. All ten planning questions were answered by Stephen on 2026-10-10 (see the decision log below).

## Standing rulings that bound this sprint

| Date | Ruling (Stephen, verbatim where quoted) | Where it lands |
|---|---|---|
| 2026-10-09 | v4 refreshes above 60 Hz at full 8-bit; rebuilding to exploit it for "a more beautiful, more realistic, more soothing display" is a **guideline for this project** | everything; doctrine overlay P1 |
| 2026-10-09 | Driver is not versioned here; users download it and copy our files over it; driver files in `Src/` are replaced wholesale, never edited | §1, §13 |
| 2026-10-09 | "please don't run against hardware, it's in use", meaning no board use without his go-ahead | bench-day model, below |
| 2026-10-10 | "all versions will be v0.0.0 format - standard meaning" | §13 |
| 2026-10-10 | The 2021 demos were experimental ("see if we could do it and how fast"). "Now we're going to put this into production … This is a numeric transition system, so anything that can be numeric can be used. Up counters, down counters, and clocks … in different sizes, colors, and orientations." | §8, §9, §10 |
| 2026-10-10 | "we should be able to see thin pix lines and thick pix lines on the same panel. our demo's should show our range of freedom/capability" | §5, §8, §10 |
| 2026-10-10 | "Orientation for this is strictly orientation for the group … Rotation is for this display, not the underlying panel" | §7 |
| 2026-10-10 | "This library paints things on the display. It does not manage the display." | all; doctrine overlay P1 |
| 2026-10-10 | Tests are Spin2 programs on the hardware that write debug() output to log files: "precise timing … individual checks passing and failing … We're not talking about invoking Python." The agent runs them and steps through the logs to certify. No automation of the log reading. | §1, §2, §11, §12 |
| 2026-10-10 | Two test families: **performance characterization** (goals and baselines written down; rerun after changes to prove nothing got worse, or that it improved) and **range testing** of behaviors before every release. "A lot of this animation will probably be written in inline Pasm." | §2, §6, §11, §12 |
| 2026-10-10 | The bench is granted "for a day at a time" while this library is worked on; "run as often as you want"; certify each feature as it lands. Tests are built as first needed; a kept subset gates the release. | bench-day model |
| 2026-10-10 | "The driver provides you with a panel surface, and you have the ability to subset that panel … If you want a 32x32 panel, just use only that much of it." | §8, §11 |
| 2026-10-10 | "Our target goal is the 60 Hz frame rate on all panels … measure 60 Hz frame rates on whatever panel size we're on" | §3, §6, §12 |

## Decision log (questions pass, 2026-10-10)

| Q | Question | Stephen's answer |
|---|---|---|
| 1 | Motion model | Time-based motion at the frame rate. Two edge profiles, both built as settings of one renderer: **A**, a single fractional edge pixel, and **C**, a multi-pixel soft tail. "we'll want to eyeball A and C but i'm guessing we'll like C". Default C. |
| 2 | Layout | **A+**: a layout computed from the area given, real thick segments, and anti-aliased segment shapes built from coverage masks. End style (square or angled) and the lit-tube cross-section are settings to judge by eye. |
| 3/4 | What the demo shows, and how | **C**: `demo_hub75_morphSeg.spin2` becomes a timed, rotating showcase; a new minimal `demo_hub75_morphClock.spin2` is the "copy me" example. |
| 5 | Clock meaning | Answered by the production ruling. Clock format, 12h/24h and real-time/accelerated are per-group settings. The 2021 rollover defect is fixed. |
| 6 | Orientation | **Per-group rotation** (0°, 90° left, 90° right, 180°), never whole-display rotation. |
| 7 | Version stamp | The version lives in the topmost group object as a constant, plus a banner line in each library file. The demos carry no stamp; they display the constant. |
| 8 | Tests | Spin2 test programs on the P2 that report through debug logs. |
| 9 | Bench | Bench days granted by Stephen; certify continuously; the kept tests gate the release. |
| 10 | Geometry variety | Sub-rectangles of the quad only. |
| — | Real-time source | Not asked further; resolved by the "library paints" rule. The clock either advances itself from a start value or takes `setTime()` from the caller. The demo uses a compiled-in start time. |
| — | Group object | One group object with a type setting. A split into separate clock and counter objects was offered and not taken. |

## Bench-day model (how this sprint executes)

- **Bench days.** Work on a section needs Stephen to grant a bench day (board USB `Parw7ukt`, the quad display, 256x128). Outside a granted day, no download or flash ever happens.
- **On a bench day:**
  - Build, run and certify as often as the work needs.
  - Run each test headless per `p2-dev-cycle` (`pnut-term-ts --headless`, exit code first, then the log).
  - Step through the log and certify each check.
- **Done means certified.** A section is done only when its tests have passed on the board, with the log cited. A section that only compiles is not done.
- **First bench day.** It opens with §2's baseline of today's code, before any rewrite lands on the board.
- **Off-bench work.** Without a bench day, work that needs no board continues to the compile-clean stage. That covers the clock logic, version stamping, the style checker and audit, and docs drafts.

## Entry baseline (measured 2026-10-10)

- **Tree:** clean except untracked `.todo-mcp/`. Its disposition is owed at `sprint-start`: ignore it or commit it.
- **Tracking:** «#116»–«#119» pending, none in progress. «#116» is superseded by this plan's testing model (Q8). Its premises were a host-side suite and a red build, and both are stale. `plan-to-tasks` regenerates it.
- **Build:** green, 0 warnings, 0 errors (details in §B at the end).
- **Tests:** no suite exists, so the substitute gate is the compile of `demo_hub75_morphSeg.spin2`. A green compile proves nothing about behavior; behavior was last seen on a board in 2021, on the old driver.
- **Hub memory:** `demo_hub75_morphSeg.bin` = 421,373 B, which includes the driver's DAT buffers (`isp_hub75_hwBuffers.spin2:44-46`). Free hub = 524,288 − 421,373 = **102,915 B** before VAR and stack.
  - VAR per counter group, read from the VAR blocks: about 25 longs, plus 6 digits × (13 longs + 7 segments × 19 longs), which comes to roughly **3.6 KB**. Driver child objects hold no VAR.
  - So 4 groups ≈ 14.5 KB today.
  - **Hub memory is the binding limit on how many groups a scene can hold** (see named unknown U5).

## Driver facts this design rests on (read from the v4.0.0 source in `Src/`)

| Fact | Citation |
|---|---|
| The full-screen commit is a PASM conversion in the caller's cog: 4.09 ms on the quad. Refresh is 71.0 Hz. | driver `ChangeLog.md:82-83` |
| A commit blocks until the previously posted frame set has been taken (double-buffered), so a loop that commits once per frame is paced by the refresh | `isp_hub75_panel.spin2:739-760` |
| The driver exposes no frame counter, vsync or refresh-rate getter | survey of `isp_hub75_display.spin2` |
| Gamma is constant FALSE; the per-adapter `colorTable` maps 8-bit input to buffer bytes (depth mapping only) | `isp_hub75_colorUtils.spin2:72-85` |
| Packing a color: `packedCorrectedRgb(chain, r, g, b)` makes three reads of the colour table | `isp_hub75_colorUtils.spin2:167-187`; `isp_hub75_screenUtils.spin2:158` |
| Run writers `fillRowRun`, `fillColumnRun` (one color) and `copyRowRun` (a color per pixel, **rows only**; there is no `copyColumnRun`) | `isp_hub75_screenUtils.spin2:170-215` |
| Runs off the display are **held to the edge**, not clipped, so callers must clip | `isp_hub75_screenUtils.spin2:204-207` |
| Sizes are reported "as mounted" | `isp_hub75_hwBufferAccess` `maxDisplayColumns/Rows` |

Inline PASM limits (domain authority `p2kb`, key `p2kbSpin2InlinePasm`):
- `ORG..END` runs cog-exec.
- Only the method's first **16 long variables** are mapped to registers.
- Code must fit in **$000..$11F (288 longs)**.
- Labels must start with `.`.
- At most 5 nested CALL levels.
- C and Z are undefined on entry.
- `ORGH..END` runs hub-exec, with no size limit and 13+ clock branches.

---

## 1. Bench test harness and conventions

**Why.** Every later section is certified on the board through debug logs (rulings of 2026-10-10). The harness serves Stephen's request for tests ("tests to measure performance of drawing … edge cases of the displays … individual checks passing and failing", 2026-10-10).

**Current state.**
- No tests exist.
- `TEST_COMMAND` says "none yet" (`.claude/skill-conventions.md`, Build & test).
- `.gitignore` keeps only `Src/isp_hub75_morph*.spin2` and `Src/demo_hub75_morphSeg.spin2`.
- `P2_LOG_DIR` is unset, so the default is `Src/logs/`.

**Target.**
- **Shared harness object.** `Src/isp_hub75_morphTestUtils.spin2` gives every test program one way to report:
  - `PASS`/`FAIL` lines carrying the test name, expected value and actual value;
  - timing lines from the system counter, reported as clock ticks and µs at `clkfreq`;
  - a final summary (ran / passed / failed);
  - the end marker.

  Every test program uses it, so the log format is identical across all tests. It follows Part 6 of `central:spin2-authoring-guide` (6.1 named constants in comparisons, 6.5 lifecycle, 6.6 comments on expected errors, 6.7 tests must pass).
- **Test programs.** Each is named `Src/demo_hub75_morphTest<Area>.spin2`.
- **`.gitignore`.** The keep-rule widens to `!Src/demo_hub75_morph*.spin2`. `Src/logs/` is ignored.
- **Logs.** A certification log that backs a release gate is quoted, as the excerpt plus the commit, in the gate's record (§11, §12). It is not committed raw.
- **Conventions file.** `TEST_COMMAND` names the headless run of the kept gate programs; `P2_LOG_DIR` is set.

**Integration.** All later sections add their checks through this object. Test programs never edit or shadow driver constants (guide 6.2).

**Conformance.** `central:spin2-authoring-guide` (gate). Done includes `STYLE_GATE_COMMAND` clean on the new files once §14 lands it.

**Verify.**
- **Normal:** a smoke test program reports one PASS and one timing line on the board, and the log parses as described.
- **Edge:** a run with zero checks still prints the summary and the end marker.
- **Error:** a deliberately false check prints FAIL with expected vs. actual, the summary counts it, and the run still reaches the end marker. This proves a failure is visible, not silent.

## 2. Performance baseline of today's code (first bench day, before any rewrite)

**Why.** A performance gate needs a starting point. To show the rewrite *improved* frame rate, the 2021 drawing must be measured on driver v4 first (Stephen, 2026-10-10: "We'll need an initial measurement").

**Current state.** The demo is paced by an idle count (`busyCount := 40`, `isp_hub75_morphCounters.spin2:241`). It draws pixel by pixel through `drawPixelAtRCwithRGB` with per-call `rgbForCValue` (`isp_hub75_morphSegment.spin2:426-442`). Name lookups run on every update, even though their debug lines are commented out (:215-218, :247-249).

**Target.**
- **Test program.** `demo_hub75_morphTestPerf.spin2`, in its baseline form, times each item listed below.
- **Record.** The figures are written into **`Docs/analysis/performance-baseline.md`**, the performance record, with the log excerpt, the commit, the date and the display (quad, 256x128). This record is the ratchet §12 enforces. It is updated only from a measured run.

What the baseline times:
- one `drawPixelAtRCwithRGB`;
- `fillRowRun` and `copyRowRun` of 8, 32 and 128 pixels;
- `packedCorrectedRgb`;
- `commitScreenToPanelSet` without the blocking wait (the first commit after a quiet period) and with it (back-to-back);
- one `animateStep` of a 4-digit group;
- the frame rate the 2021 demo actually delivers (frames per second over 10 s).

**Verify.**
- **Normal:** every item reports a time.
- **Edge:** back-to-back commits report about one refresh period (≈14 ms at 71 Hz). That confirms the blocking behavior §3 relies on.
- **Error:** if a measured commit differs from the driver's 4.09 ms by more than 20%, stop and confirm the measurement by a second, independent method (a pin toggle, or a `getct` bracket in a different place) before recording it.

## 3. Time base and frame loop

**Why.**
- Q1 makes motion time-based.
- The goal is ≥60 new frames per second in every scene (Stephen, 2026-10-10).
- Today speed depends on loop speed, and the clock "minute" depends on animation length (`morphCounters:160-172`, `:241`).

**Current state.**
- `animateStep()` advances one pixel per call at every level: demo:96-98 → `morphCounters:232` → `morph7seg:116` → `morphSegment:190`.
- Nothing in the code reads the time.

**Target.**
- **Shared time object.** `Src/isp_hub75_morphTime.spin2` keeps elapsed milliseconds as a running total that survives the system counter's wrap. At 335 MHz the counter wraps every 2³²/335e6 ≈ 12.8 s, so time is added up from `getct()` deltas, never compared raw. It's shared by every group, so time is read once per frame, not per segment.
- **New per-frame call.** `animate(nowMs)` replaces `animateStep()` at every level. A segment computes its position from `(nowMs − startMs) / durationMs`, with optional easing.
- **Frame loop.** The demo's loop is: read time → advance values → animate every group → **one** commit. The blocking commit paces the loop at the refresh rate.
- **Remove the 2021 pacing.** `busyCount` goes, and so does the separate commit in `stepIdleCounters` (demo:103-110). Two commits per pass halve the frame rate.
- **FPS meter.** The frame loop counts frames per second and exposes the figure for the showcase's live FPS group (§10) and for §12.

**Verify.**
- **Normal:** over 60 s the elapsed total matches the count of whole seconds within 1 ms per minute.
- **Edge:** the total stays correct across 6 or more counter wraps (a 90 s run), and a 300 ms move takes 300 ms ± one frame whatever the frame rate.
- **Error:** a frame that takes longer than its budget (forced by a test delay) makes motion skip ahead to the correct position rather than slow down. The FPS figure reports the drop.

## 4. Color pipeline: gamma and per-group intensity ramps

**Why.** Every partial-brightness pixel (tails, edges, anti-aliasing) needs perceptually even steps. The driver applies none (`bGammaEnable` FALSE, `colorUtils:72-76`). Calling `packedCorrectedRgb` per pixel is three table reads plus a method call.

**Target.**
- **Gamma table.** A 256-byte gamma table (γ≈2.2), computed once at start-up with Spin2 float operators. 256 entries computed once is cheap, and nothing is computed per pixel.
- **Intensity ramp.** Each group builds an intensity ramp for its color when it's placed. `ramp[i]` = the packed value of `(gamma(r·i/255), gamma(g·i/255), gamma(b·i/255))`, from `packedCorrectedRgb`.
- **Per-pixel work** becomes one ramp lookup: `packed := ramp[intensity]`.
- **Ramp length.** 256 entries is 1 KB per color, 64 entries is 256 B. The choice is fixed by §6's measurements and U2.
- **Shared helper.** It lives in one place (`isp_hub75_morphColor.spin2`), used by segments and by the clock's seconds dots, so no copy exists elsewhere.

**Verify.**
- **Normal:** `ramp[255]` equals `packedColorOf(color)` exactly, and `ramp[0]` is black.
- **Edge:** the ramp is monotonic for primaries, white and an odd color (cOrange); a 1-step input change never produces a visible jump, judged on a full-width gradient test bar.
- **Error:** a color with a zero channel never leaks that channel at any ramp level.

## 5. Segment geometry: coverage masks

**Why.** Q2 A+: thick, shaped, anti-aliased segments, with thin and thick groups on the same panel (ruling of 2026-10-10).

**Current state.**
- Thickness is stored but ignored: drawing is a 1-px line (`morphSegment:426-442`).
- Width is forced to 1 (`morph7seg.spin2:~79`).
- The size math assumes width 1 (FIXME, `morphCounters:245`).

**Target.**
- **The mask.** When a group is placed, it builds one coverage mask for its segment shape: thickness × length, one byte per pixel (0-255), from exact fractional geometry. One mask serves all seven segments, because horizontal and vertical are the same mask transposed, and transposition is done by the §7 transform, not stored.
- **Settings:**
  - end style: `square` | `angled` (the classic 7-segment point);
  - cross-section: `flat` | `tube` (center brighter). Default flat.
- **Thin strokes.** Thickness 1 is legal. It produces a 1-pixel mask, and angled ends fall back to square at thicknesses below 3, where an angle can't be drawn.
- **Memory.** A 60×9 mask is 540 B per group.

**Verify.**
- **Normal:** the mask is symmetric end to end, and the interior is all 255.
- **Edge:** thicknesses 1, 2, 3 and the largest that fits a 256x128 group; fractional lengths (e.g. 37.4) sum to the right total coverage within 1%.
- **Error:** a thickness greater than the length is refused when the group is placed, with an error code (guide 5.4), not drawn.

## 6. Segment renderer: motion profiles, row rendering, inline PASM where measured

**Why.** This is where "beautiful, realistic, soothing" happens (doctrine overlay P1), and it's where the ≥60 fps budget is spent.

**Current state.** The renderer has three update paths (`morphSegment:246-424`). Each one clears the whole segment and redraws it every step, pixel by pixel.

**Target.**
- **Motion profiles.** A segment's lit amount along its length is a profile of position:
  - **A:** solid, then one fractional edge pixel.
  - **C (default):** solid, then a gradient tail several pixels long, sized to the segment.
  - Profile and tail length are settings.
- **Every pattern in the transition table maps onto this:** the snakes (`CMD_TOP_DOWN` etc.), the E/F column slides and `CMD_IMMEDIATE`. The table and `Generator/pymorph.py` do not change.
- **Pixel intensity** = `mask × profile`, scaled to 0-255, then `ramp[]` (§4).
- **Row rendering.** A segment is rendered **by screen rows** over its screen-space bounding box. Each row builds packed colors into a small row buffer, then makes one `copyRowRun`. Rows are used because the driver has no column copy, and because this works the same at every rotation (§7). Runs are clipped to the group's area before the call, because the driver holds runs to the edge.
- **Redraw only what changed.** Only segments that are moving, or just finished, are redrawn. Static segments cost nothing, because the screen buffer keeps its contents between commits. A fully lit, still segment is drawn once with `fillRowRun`.
- **Inline PASM.** The candidate is the row-build loop (mask byte × profile → ramp lookup → store). It is written in Spin2 first, measured, and converted to `ORG..END` inline PASM if §12's figures show it's needed. The pure-Spin2 timing is recorded as the figure the PASM must beat. The loop fits the 16-long variable limit and the 288-long code limit by design.
- **Cleanup in rewritten code.** Remove the per-update name lookups (`:215-218`, `:247-249`); the `nameOf*` helpers are kept only behind debug.

**Verify.**
- **Normal:** each of the 7 segment slots × the 7 styles × on/off animates to the same final pixels as `turnOnDigit()` from rest. Final-frame pixel checksums are compared in the log.
- **Edge:**
  - a move interrupted by a new command mid-flight;
  - tail length larger than the segment;
  - thickness 1;
  - a segment touching the display edge.
- **Error:** a bad command byte is refused with an error code and logged, never drawn.
- **Performance:**
  - time per segment-frame for each profile;
  - time for the densest scene's frame, which must leave the frame at ≥60 fps (§12).

## 7. Per-group rotation

**Why.** Stephen, 2026-10-10: "I could have a counter that's upside down. I could have a clock that's rotated left 90°."

**Target.**
- **Rotation setting.** Each group has one: `ROT_0` | `ROT_LEFT_90` | `ROT_RIGHT_90` | `ROT_180`. The library's own enum is used, never the driver's, because the driver's rotation is display mounting.
- **One transform.** All drawing goes through a single group-local → screen transform. The transition table stays in digit terms ("top-down" means down the digit), so motion rotates with the digit.
- **Layout follows rotation.** A 90° group swaps its width and height.

**Verify.**
- **Normal:** for each rotation, a digit 8 lights the expected screen pixels (checksum), and the "1→7" transition moves in the rotated direction, confirmed by eye on the bench.
- **Edge:** rotated groups touching each display edge and the panel seams at column 128 and row 64; mixed rotations side by side.
- **Error:** an invalid rotation value is refused when the group is placed, with an error code.

## 8. Layout: fit a group into a rectangle

**Why.**
- Q2 A+ and Q10: groups fill whatever area they're given, from 32x32 up to the whole 256x128.
- Hard-coded positions are defects (doctrine overlay P1; demo:82-91).

**Current state.** `placeDigitGroup(row, column, grpType, nbrDigits, segThickness, segLength, initialValue, rgbColor)` (`morphCounters:81`) takes pixel sizes and a corner.

**Target.**
- **New placement call.** `placeGroup(area, type, format/digits, rotation, style, color, initialValue)`. `area` is a rectangle in display coordinates.
  - The group computes the largest digit size that fits, with spacing and colon or dots, and centers itself.
  - An explicit thickness may override the computed one, so thin-next-to-thick is a choice.
  - It returns the size actually used.
- **What goes.** The FIXMEs at `morph7seg:~79` and `morphCounters:245` are retired. The `placeDigitGroup` signature is replaced, not kept beside the new one: this is a code-user API change, recorded in the README and the ChangeLog.

**Verify.**
- **Normal:** a 4-digit HH:MM group in the full 256x128 area, and in 128x64, 64x32 and 32x32 sub-areas, logs computed sizes that fit and are centered within one pixel.
- **Edge:** a portrait area (48x128) at `ROT_LEFT_90`; an odd area (100x37); the smallest area that still fits a legible digit (reported); thickness 1 in a large area.
- **Error:** an area too small for the digits returns an error code and draws nothing.

## 9. Group types, values and the clock

**Why.** Production numeric display (ruling of 2026-10-10). The 2021 clock is defective: `currValue` counts minutes but is compared to 1259 as if it were HHMM, so it runs 00:00-20:59 (`morphCounters:165-168`). The seconds dots follow `minutes // 4` (`:205`).

**Target.**
- **Clock formats:**
  - `MM:SS`;
  - `HH:MM`;
  - `HH:MM:SS`.

  Each comes in 12h (1-12, never 00) and 24h (00-23).
- **Clock modes.** Real-time from `isp_hub75_morphTime` (§3) or accelerated (one unit per configured interval).
- **Status-panel pattern.** The caller can set values directly: `setTime(h, m, s)` and `setValue(n)`. The library paints; the time source is the caller's (ruling of 2026-10-10).
- **Counters.** Up and down counters wrap at the digit count. The existing `GRP_DIGITS` (value set from outside) and `GRP_DIGITS_RANDOM` types are kept; neither was asked to be removed.
- **Seconds indicator.** It shows real seconds, drawn through the same ramp and mask pipeline (§4, §5).
- **Idle-count pacing removed** (`busyCount`).

**Verify.**
- **Normal:** each format counts correctly for 3 or more units.
- **Edge (range gate):**
  - 12:59→1:00 (12h);
  - 23:59→00:00 (24h);
  - 59:59→00:00 (`MM:SS`);
  - 23:59:59→00:00:00;
  - an up-counter at 9999→0000;
  - a down-counter at 0→9999;
  - `setTime` to each boundary.
- **Error:** an out-of-range `setTime` or `setValue` returns an error code and leaves the display unchanged.

## 10. Demos: rotating showcase and the minimal clock

**Why.** Q3/Q4 C, and the "range of freedom/capability" and production rulings.

**Target.**
- **`demo_hub75_morphSeg.spin2` becomes the showcase.** It runs a table of scenes, each a list of `placeGroup` calls with a duration. Adding a scene is a data change.
  - **Scene changes.** All lit segments morph off, then the next scene morphs on.
  - **At start-up,** the library version (`counters.MORPH_VERSION`, §13) morphs on.
  - **Scenes:**
    - **Hero clock:** one real-time HH:MM:SS clock filling the display.
    - **Mixed:** a thick clock above a row of thin-stroked counters.
    - **Splatter:** many groups of all three types in mixed sizes, colors, rotations and stroke weights, running at once. This is the worst-case load for §12.
    - **Status panel:** two or three meaningful groups fed from P2 state: a real-time clock, an uptime counter, a restarting countdown and the **live FPS** of the render loop.
    - **Orientation:** the same group shown at all four rotations.
- **New `demo_hub75_morphClock.spin2`.** The shortest correct program: start the driver, place one clock, run the frame loop. It is the file the README tells developers to copy.
- **Edge style and profile.** A CON setting in the showcase switches A↔C, square↔angled and flat↔tube for Stephen's by-eye choice on the bench. The shipped defaults are recorded from his choice.

**Verify.**
- **Normal:** every scene runs for its duration, and scene changes morph cleanly.
- **Edge:** the splatter scene holds ≥60 fps (§12); the showcase runs unattended for 30 minutes or more (a full scene loop) with no fault.
- **Error:** a scene whose group fails to place logs the error code, skips that group and keeps running.
- **By eye (Stephen):** A vs C, end style and tube, judged on the bench. His picks become the defaults.

## 11. Range gate: behavior test programs (release gate)

**Why.** Range testing is required "every time we release, before we release" (Stephen, 2026-10-10).

**Target.**
- **The gate programs.** `demo_hub75_morphTestRange.spin2`, split into more files if one grows past a readable size. They are kept as the release gate and collect the behavior checks written in §3-§10:
  - layout across sub-areas;
  - rotations;
  - every clock and counter boundary;
  - masks, ramps and gamma;
  - the elapsed-time wrap;
  - interrupted moves;
  - error-code paths;
  - `MORPH_VERSION` equals the version expected by the build.
- **Gate record.** `Docs/analysis/range-gate.md` holds the case list, plus the last certification's log excerpt and commit.
- **Release step.** A clean range run on file for the release commit is a required step before tagging. The `build-wrapup` overlay or the release checklist gets that line (see the Documentation Blast Radius).

**Verify.**
- **Normal:** the full program passes on the board.
- **Edge:** the count of cases that ran equals the count in the record. A case missing from the run is a failure (`baseline-health` §3).
- **Error:** one case is deliberately broken once in a scratch build. The log shows FAIL for it, which proves the gate can fail.

## 12. Performance gate (release gate) and the ≥60 fps goal

**Why.** Stephen, 2026-10-10: the performance record lets us "make sure that we have not worsened the performance … if our goal was to improve it, we actually improved it". The target is 60 Hz on every panel.

**Target.**
- **The gate program.** `demo_hub75_morphTestPerf.spin2`, grown from §2, is kept as the release gate. It measures the primitives, the renderer per profile, and the frames per second of each showcase scene, the splatter scene included.
- **Goals,** recorded in `Docs/analysis/performance-baseline.md`:
  - every scene ≥60 fps on the quad;
  - no figure worse than the recorded baseline beyond measurement noise (noise is set from repeat runs on the first bench day);
  - a change aimed at speed must show the gain.
- **Inline PASM decisions** are made from this program's figures and recorded with them.

**Verify.**
- **Normal:** all scenes ≥60 fps.
- **Edge:** a repeat run sits within noise of the previous one.
- **Error:** a slowdown injected on purpose (a delay in the row loop, scratch build) shows as a regression against the record, which proves the gate can fail.

## 13. Version stamping («#117»)

**Why.** Stephen, 2026-10-09: the distributed files carry the release version. Q7 placed it.

**Target.**
- **Constant.** `MORPH_VERSION` (and a version string) in a `CON` block of the topmost group object.
- **Banner line.** `Version.... v0.x.y` in the banner of each **library** file: group, digit, segment, and this sprint's new library objects (`morphTime`, `morphColor`, `morphTestUtils`).
- **Demos and test programs** carry no stamp. They read the constant.
- **Stamping script.** `tools/stamp_version.sh` writes the newest `ChangeLog.md` `## [x.y.z]` version into every banner line and the constant, and with `--check` reports any disagreement. It's a host script, not a test; it serves the 2026-10-09 request directly.
- **Release wiring.** `build-wrapup`'s version bump runs it.

**Verify.**
- **Normal:** after a run, every library banner and the constant equal the ChangeLog version.
- **Edge:** a new library file without a banner line is reported by `--check`.
- **Error:** hand-editing one banner to a different version makes `--check` fail and name that file:line.

## 14. Spin2 style checker («#118») and audit («#119»)

**Why.** The `CONFORMANCE_GUIDES` gate row for `Src/*.spin2` is owed (`.claude/skill-conventions.md`).

**Target.**
- **The checker** («#118»), as specified in its task: `tools/check_style.sh` covers the T1 rules and the T1+T2 detection halves of `central:spin2-authoring-guide` over our `Src/*.spin2` (the morph and demo globs only, never the driver), and reports three parts. `STYLE_GATE_COMMAND` is set to it.
- **The audit** («#119»), run on the tree **after** the rewrite: `Docs/analysis/spin2-T2-audit.md`.
  - Findings in files this sprint rewrote are fixed in-sprint (scope ruling of 2026-10-10).
  - Findings in untouched files are recorded only.
  - The generated table blocks route to `Generator/pymorph.py`.
- **Order.** The checker lands **before** the rewrite, so every new file is written against it.

**Verify.** As written in «#118» and «#119»: a fixture that violates each rule makes the checker fail, and every audit finding carries file:line.

## 15. Documentation

**Why.** Documentation is a deliverable (`sprint-plan` §4).

**Target.** Every item in the Documentation Blast Radius below is updated, with the README rewritten around the production API:
- placing groups (areas, types, formats, rotation, style, color);
- the frame loop;
- the two demos;
- installing and building;
- running the gate tests on a board.

---

## Documentation Blast Radius

Composed by hand. `DOC_AUDIT_COMMAND` is unset, so the instrument is owed and `plan-to-tasks` 2a generates its build task. Checked 2026-10-10 against the tracked files (`git ls-files`).

| Artifact | What changes | Section |
|---|---|---|
| `README.md`: "Current status (2026)" | Replace the plan text with what shipped | §15 |
| `README.md`: "The Demo" table (4 files) | Files and counts change: new library objects, `demo_hub75_morphClock`, test programs | §1, §3-§4, §10 |
| `README.md`: "Installing and building", step 4 | Name both demos; add how to run the gate tests | §1, §10 |
| `README.md`: "To use this code in your own project" | Rewrite around `placeGroup` and the frame loop, pointing at `demo_hub75_morphClock` | §8, §10 |
| `README.md`: Project Goals / video note | The video still shows 2021; say so, or replace it if Stephen records a new one (not a deliverable unless he asks) | §15 |
| `Docs/SPECIFICATION.md` | Record the by-eye defaults (R-4.5), the supported group maximum (R-9.5 via README), and any requirement execution changes | §10, §12, §15 |
| `ChangeLog.md` | Release entry for this sprint. The `## [0.1.0]` "TBA" bodies stay as they are unless Stephen asks. Voice: `central:changelog-voicing` | §15 |
| Docstrings (`''` PUB docs) in all 3 library files | Every renamed or re-scoped PUB (`placeDigitGroup`→`placeGroup`, `animateStep`→`animate`, `placeDigit`, `placeSegment`, `commandSegment`); guide 4.3 | §3, §6, §8 |
| Banner blocks of every library file | `Updated....` date and the new `Version....` line | §13 |
| `Src/demo_hub75_morphSeg.spin2` banner | `File.......` reads `isp_hub75_demoMorphSeg.spin2`, a stale name (defect found 2026-10-10) | §10 |
| `CLAUDE.md` Architecture (gitignored, not shipped) | Cooperative stepping → frame loop and time base; segment rendering paths; new objects; test programs | §15 |
| `.claude/skill-conventions.md` (gitignored) | `TEST_COMMAND`, `P2_LOG_DIR`, `STYLE_GATE_COMMAND`, `EXCLUSIVE_RESOURCES` (+ `Docs/analysis/performance-baseline.md`, the record) | §1, §12, §14 |
| `.gitignore` | `demo_hub75_morph*.spin2` keep-rule, `Src/logs/` | §1 |
| `Docs/transition-table.out`, `Docs/segment_ops.txt` | **None:** the table and generator are unchanged (§6); checked | — |
| `Generator/pymorph.py` | **None:** encoding unchanged; checked | — |
| New: `Docs/analysis/performance-baseline.md`, `range-gate.md`, `spin2-T2-audit.md` | Created | §2, §11, §12, §14 |
| Release steps (`build-wrapup` overlay or checklist) | Add the range-gate and performance-gate lines | §11, §12 |

**Duplication watch.** The API description lives once, in the README. `CLAUDE.md` points to it rather than repeating signatures.

## Order and resources

**Execution order:**
1. §14 checker (off-bench).
2. §1 harness (off-bench, then certified on bench day 1).
3. §2 baseline (bench day 1, before any rewrite runs on the board).
4. §3 → §4 → §5 → §6 (drawing core; certified on the bench as each lands).
5. §7 → §8 → §9.
6. §10.
7. §11 and §12 certification.
8. §13 (any time; the final stamp at release).
9. §14 audit (after the rewrite).
10. §15 last.

**Off-bench work.** §9's clock logic and §13 need no board to be written. They still need the board to be certified.

**Exclusive resources.**
- The board, the `.bin` and `ChangeLog.md` (`EXCLUSIVE_RESOURCES`).
- `isp_hub75_morph7seg.spin2` is touched by §5 to §8. Those sections are serial (`arbiter-serial`).

## Named unknowns

| # | Unknown | Planned response |
|---|---|---|
| U1 | Real per-pixel and per-row cost of the row-build loop in Spin2 | Measured in §6 on the bench; if the splatter scene falls below 60 fps, convert the loop to inline PASM (§6); if still short, cap the splatter group count |
| U2 | Ramp length (256 vs 64 levels): memory vs smoothness | 256 by default; drop to 64 only if U5 binds, then judge the tails by eye |
| U3 | Banding at the dark end of tails after gamma | Look on the bench; add temporal dithering only if visible (Q2) |
| U4 | Whether Stephen picks A or C, square or angled, flat or tube | Bench by-eye session (§10); the shipped defaults are recorded |
| U5 | How many groups fit in hub (≈103 KB free before VAR; ≈3.6 KB per group today, plus masks and ramps) | Measure the `.bin` and VAR after §8; set `MAX_GROUPS` to fit with ≥8 KB margin; record it in the README |
| U6 | Interpreter overhead of returning from inline PASM (not published, per `p2kb`) | Covered by §12's measurements, not assumed |

## §B. Entry baseline build

Measured 2026-10-10 on commit `1be3614`:
`cd Src && pnut-ts -d demo_hub75_morphSeg.spin2 > baseline-build.log 2>&1`
- rc=0, 69 s.
- `grep -ci warning` → 0; `grep -ci error` → 0.
- Wrote `demo_hub75_morphSeg.bin` (421,373 bytes).

This is the substitute gate (compile only): one top file, which pulls in all 3 library objects. Nothing is excluded. **A green compile says nothing about behavior.** Behavior is first proven on bench day 1 (§2).

Entry baseline is re-taken after `sprint-start`'s last commit, per `baseline-health` §5.

## Specification

The behavior this sprint must deliver is specified in **`Docs/SPECIFICATION.md`** (written 2026-10-10 alongside this plan). Where this plan and the specification disagree, raise it before executing; do not pick one silently.
