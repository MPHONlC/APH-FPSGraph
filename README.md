<div align="center">

# APH-FPSGraph

*A frame-rate graph that times every frame, with average FPS, 1% and 0.1% lows, frame time, stutters and ping.*

![Version](https://img.shields.io/badge/version-2026.10.06.13.49-9CD04C?style=flat-square)
![ESO API](https://img.shields.io/badge/ESO%20API-101051%20%7C%20101052-00FFFF?style=flat-square)
![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-fa9c1b?style=flat-square)
![Platform](https://img.shields.io/badge/platform-PC%20%7C%20Xbox%20%7C%20PlayStation-FF69B4?style=flat-square)

</div>

## Dependencies

Requires **LibAPH** (shared helper library, hard dependency).

Optionals for additional features:
- **LibAddonMenu-2.0:** required for the PC Settings Menu.
- **LibHarvensAddonSettings:** required for the Console Settings Menu.

Without the optional dependencies, the addon still runs entirely independently and can be controlled via built-in slash commands as a standalone utility.

## Slash Commands

- `/fpsgraph`: shows or hides the graph.

<details>
<summary>Show all commands</summary>

- `/fpsgraph record`: starts recording a session.
- `/fpsgraph stop`: stops the recording.
- `/fpsgraph reset`: clears the numbers.
- `/fpsgraph report`: prints a session summary to chat.

</details>

## The Graph

Every frame's length is recorded as it happens, so the numbers are not the game's smoothed FPS reading. Each bar is the average FPS for one step (a quarter, half or whole second), and its solid part stops at the slowest frame of that step, so a dip shows even when the average looks fine. A bar turns red when even one frame in it fell below your target FPS, and frame times over the target's budget turn red too. A grey number after a red value, such as (-1.00), is how far it is from the target. Dots mark ping on its own ms scale at the right, red above the high-ping level you set, a line marks the target, the left axis is FPS and grows with your frame rate, and a timeline runs underneath.

Above the graph: FPS now and on average, the 1% and 0.1% lows, frame time (average, 99th percentile, worst and jitter), stutters counted from a threshold you set, ping (now, average, low, high and jitter) and, if you want it, add-on Lua memory and the add-on memory pool. Loading screens are left out. Timing a frame writes one number into a fixed buffer, and the graph only redraws when a step closes.

Right-click the graph to record a session, open its summary or its timeline in their own windows, and compare it with an earlier one (the last 10 are kept). The summary goes past averages to median, 95%, 99% and 99.9% frames, frames below target, time lost to stutters and ping, side by side with the compared run. The timeline zooms with the wheel or its buttons and pans by dragging. With a controller, the buttons show under the window. The window, the graph and the text each have their own opacity slider. The window can be resized with the text scaling to match, locked, shown in menus too, or have the graph turned off to keep just the numbers. Pick how much the text shows (FPS single value, FPS details, FPS and frame time details or full details) and snap the window to a corner or the top or bottom center of the screen (it stays put there; pick Where I put it to move it freely); with only the text shown, it lines up with the screen edge it sits near.

> [!WARNING]
> **Console Testing Notes:** This addon was developed and tested on **PC / Steam Deck** *(using Force Console Flow for console testing)*.

## License

Copyright © 2026 @APHONlC. All rights reserved. See LICENSE.md

> [!NOTE]
> This add-on is not created by, affiliated with, or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.

For permissions or inquiries, contact @APHONlC on ESOUI.

**Testers & Suggestions:**

<!-- TESTERS:START -->
- @Drakius192
<!-- TESTERS:END -->

**Check out my other addons/projects:**

- [Auto Lua Memory Cleaner](https://www.esoui.com/downloads/fileinfo.php?id=4388#info)
- [Permanent Memento](https://www.esoui.com/downloads/fileinfo.php?id=4116#info)
- [Tamriel Trade Center, HarvestMap, ESO-Hub, ESOUI Auto-Updater](https://www.esoui.com/downloads/fileinfo.php?id=3249#info) <sub>*(Linux, macOS, SteamDeck, & Windows)*</sub>

If you like the addon and are considering donating, here's a link. Thank you!

[![Buy Me A Coffee](https://img.shields.io/badge/Support-Buy%20Me%20A%20Coffee-FFDD00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/aph0nlc)

### Bug Reports

If you encounter any issues, please submit a report here
