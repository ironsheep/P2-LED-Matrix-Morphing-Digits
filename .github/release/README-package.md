# P2 LED-Matrix Morphing Digits - Release v{{VERSION}}
Morphing-digit clocks, counters and values for HUB75 RGB LED matrix panels on the P2

![Project Maintenance][maintenance-shield]

[![License][license-shield]](LICENSE)

This folder holds the morphing-digit files for the Parallax Propeller 2 [P2 or P2X8C4M64P]. They are copied on top of a configured **P2 HUB75 LED Matrix Driver v4.0.0 or later**; the driver itself is not included. Everything else (how to use the objects in your own code, the reference tables, how the animations are made, known issues) is at the project's home: [github.com/ironsheep/P2-LED-Matrix-Morphing-Digits](https://github.com/ironsheep/P2-LED-Matrix-Morphing-Digits).

## Installing

1. Put the HUB75 driver v4.0.0 (or later) files in a folder. Get them from the [driver's Releases page](https://github.com/ironsheep/P2-HUB75-LED-Matrix-Driver/releases).
1. Configure the driver for your panels in its **isp_hub75_hwPanelConfig.spin2** (the `DISP0_*` settings), following the driver's documentation. This folder does not contain that file, so copying it in never overwrites your configuration.
1. Copy the `.spin2` files from this folder into the driver's folder. None of them shares a name with a driver file. (Leave **ChangeLog.md**, **LICENSE** and this **README.md** here: the driver's folder has files of those names.)
1. Compile and run **demo_hub75_morphClock.spin2** first: one clock filling your display. Then try the other two demos.

Each demo sizes itself to your display, from a single 64 x 32 panel up.

## What's in this folder

| File | Purpose |
|---|---|
| **demo_hub75_morphClock.spin2** | the minimal example: one real-time clock filling the display. Copy it to start your own program |
| **demo_hub75_morphSeg.spin2** | the 2021 demo on this library: two clocks, a countdown and random digits, in thin strokes |
| **demo_hub75_morphShowcase.spin2** | the library's range in a loop of scenes: thick, colored digits, many groups at once, all four rotations |
| **isp_hub75_morphCounters.spin2** | a group of up to six digits (and colons): placement, settings, values and the clock |
| **isp_hub75_morph7seg.spin2** | used by the group: draws one digit and runs its animations |
| **isp_hub75_morphSegment.spin2** | used by the digit: the moves of each part of a digit |
| **isp_hub75_morphMask.spin2** | used by the group: the stroke's shape at its thickness |
| **isp_hub75_morphColor.spin2** | used by the group: the shades of its color |
| **isp_hub75_morphTime.spin2** | your frame loop's clock: the time each frame is drawn for, and the frame rate |
| **isp_hub75_morphStatus.spin2** | the `SUCCESS` and `E_` codes that placement and the settings return |
| **ChangeLog.md** | what changed in each release |
| **LICENSE** | the MIT License |

## License

Licensed under the MIT License. <br>
<br>
Follow this link for more information: [License](LICENSE)

[maintenance-shield]: https://img.shields.io/badge/maintainer-stephen%40ironsheep.biz-blue.svg?style=for-the-badge

[license-shield]: https://img.shields.io/badge/License-MIT-yellow.svg
