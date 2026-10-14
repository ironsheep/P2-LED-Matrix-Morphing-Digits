# Change Log

All notable changes to the P2 LED Matrix Morphing Digits project will be documented in this file. Our version numbering adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### Pages: [README](README.md) | Change Log

## v2.0.0 (2026-10-14)

Rebuilt for the HUB75 driver v4: digits drawn as one round-pen stroke at any size, placed anywhere on the display, moving at the display's full refresh rate.

### New Features

- `placeGroup()` places a clock, counter or value group in any area of the display and sizes its digits to fit; an area overlapping another group's is refused
- Each group can be turned: `ROT_0`, `ROT_90`, `ROT_180` or `ROT_270`
- Clocks show `LAYOUT_MM_SS`, `LAYOUT_HH_MM` or `LAYOUT_HH_MM_SS`, in 24 or 12 hours (`setClockHours()`), in real time or stepped (`setClockMode()`)
- `GRP_UP_COUNTER` and `GRP_DOWN_COUNTER` count up or down, one to six digits
- `setValue()` and `setTime()` change a group's value at any time; `digitValueAt()` reads what a digit shows
- `removeGroup()` morphs a group out and frees its area for another
- Each group's look and pace are settings: `setThickness()`, `setCrossSection()`, `setProfile()`, `setTailLength()`, `setMoveDuration()`, `setHoldDuration()`, `setEasing()`
- `placeGroup()` and every setter return `SUCCESS` or an `E_` status code (`isp_hub75_morphStatus.spin2`); a refused call changes nothing
- `MORPH_VERSION` and `versionString()` report the library version
- New demos: **demo_hub75_morphClock.spin2**, the minimal clock to copy from, and **demo_hub75_morphShowcase.spin2**

### Improvements

- A digit is one anti-aliased stroke with rounded corners, the same shape at every size and thickness
- Moves take the same time at any digit size and run at the display's refresh rate: 71 frames per second on a 256 x 128 display at 8-bit color
- A newly placed group's digits grow in instead of appearing at once
- **demo_hub75_morphSeg.spin2** sizes itself to the display: one clock on a 64 x 32 panel, all four groups on 128 x 64, twice the size on 256 x 128

### Bug Fixes

- Clocks count through 21:00 to 23:59 and roll over at midnight; they no longer jump from 20:59 back to 00:00

### Breaking Changes

- **BREAKING**: `placeGroup(adapter, left, top, width, height, type, layout, rotation, color, initialValue)` replaces `placeDigitGroup()`. Every placement call changes: give an area, not a position and segment length. A clock's initial value is now seconds since midnight, not minutes.
- **BREAKING**: `animate(nowMs)` replaces `animateStep()`. Give every group the same frame time from `isp_hub75_morphTime.update()`, once per frame, and commit once; a loop built on `isAnimationComplete()` and `animateStep()` must be rewritten as in the demos.
- **BREAKING**: The random-digits group type is removed. Give a `GRP_DIGITS` group random values with `setValue()`, as **demo_hub75_morphSeg.spin2** does.
- **BREAKING**: Requires the HUB75 driver v4.0.0 or later; earlier drivers do not compile with this code.

## [0.1.0] 2021-01-26

### Initial Release

- TBA


## History: Progress heading toward initial release
