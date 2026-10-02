[SIZE="5"][COLOR="SeaGreen"]APH-FPSGraph[/COLOR][/SIZE]
[COLOR="Gray"][i]A frame-rate graph that times every frame, with average FPS, 1% and 0.1% lows, frame time, stutters and ping.[/i][/COLOR]

[SIZE="3"][COLOR="DarkOrchid"]Dependencies:[/COLOR][/SIZE]

This addon requires:
[LIST]
[*] [COLOR="#FF69B4"]LibAPH[/COLOR] [COLOR="Gray"][i](Required Unified helpers shared with my addons)[/i][/COLOR]
[/LIST]

Optionals for additional features:
[LIST]
[*] [url="https://www.esoui.com/downloads/info7-LibAddonMenu-2.0.html"][COLOR="#FF69B4"]LibAddonMenu-2.0[/COLOR][/url] [COLOR="Gray"][i](PC Settings Menu)[/i][/COLOR]
[*] [COLOR="#FF69B4"]LibHarvensAddonSettings[/COLOR] [COLOR="Gray"][i](Console Settings Menu)[/i][/COLOR]
[/LIST]

[b]Without the optional Dependencies:[/b] You can still run the addon entirely independent, and control its settings via built-in slash commands as a standalone utility.

[SIZE="3"][COLOR="DarkOrchid"]Slash Commands[/COLOR][/SIZE]

[LIST]
[*] [color=#00FFFF]/fpsgraph[/color]: shows or hides the graph.
[/LIST]
[spoiler]
[LIST]
[*] [color=#00FFFF]/fpsgraph record[/color]: starts recording a session.
[*] [color=#00FFFF]/fpsgraph stop[/color]: stops the recording.
[*] [color=#00FFFF]/fpsgraph reset[/color]: clears the numbers.
[*] [color=#00FFFF]/fpsgraph report[/color]: prints a session summary to chat.
[/LIST]
[/spoiler]

[SIZE="3"][COLOR="DarkOrchid"]The Graph[/COLOR][/SIZE]

Every frame's length is recorded as it happens, so the numbers are not the game's smoothed FPS reading. Each bar is the average FPS for one step (a quarter, half or whole second), and its solid part stops at the slowest frame of that step, so a dip shows even when the average looks fine. A bar turns red when even one frame in it fell below your target FPS, and frame times over the target's budget turn red too. A grey number after a red value, such as (-1.00), is how far it is from the target. Dots mark ping on its own ms scale at the right, red above the high-ping level you set, a line marks the target, the left axis is FPS and grows with your frame rate, and a timeline runs underneath.

Above the graph: FPS now and on average, the 1% and 0.1% lows, frame time (average, 99th percentile, worst and jitter), stutters counted from a threshold you set, ping (now, average, low, high and jitter) and, if you want it, add-on Lua memory and the add-on memory pool. Loading screens are left out. Timing a frame writes one number into a fixed buffer, and the graph only redraws when a step closes.

Right-click the graph to record a session, open its summary or its timeline in their own windows, and compare it with an earlier one (the last 10 are kept). The summary goes past averages to median, 95%, 99% and 99.9% frames, frames below target, time lost to stutters and ping, side by side with the compared run. The timeline zooms with the wheel or its buttons and pans by dragging. With a controller, bind Control the FPS Graph or press Open the summary in the settings, and the buttons show under the window. The window, the graph and the text each have their own opacity slider. The window can be resized with the text scaling to match, locked, shown in menus too, or have the graph turned off to keep just the numbers. Pick how much the text shows (FPS single value, FPS details, FPS and frame time details or full details) and snap the window to a corner or the top or bottom center of the screen (it stays put there; pick Where I put it to move it freely); with only the text shown, it lines up with the screen edge it sits near.

[center]
[b][COLOR="Orange"]⚠️ CONSOLE TESTING NOTES ⚠️[/COLOR][/b]
This addon was developed and tested on [b][COLOR="#FF69B4"]PC / Steam Deck[/COLOR][/b] [COLOR="Gray"][i](using Force Console Flow for console testing)[/i][/COLOR].

[SIZE="5"][COLOR="Red"]LICENSE & USAGE[/COLOR][/SIZE]

Copyright © 2026 [COLOR="#FF69B4"]@APHONlC[/COLOR]. All rights reserved. See LICENSE.md

[COLOR="Gray"][i](For permissions or inquiries, contact [COLOR="#FF69B4"]@APHONlC[/COLOR] on ESOUI.)[/i][/COLOR]

[b][COLOR="Orange"]Testers & Suggestions:[/COLOR][/b]
[LIST]
[*] [color="#FF69B4"]@Drakius192[/color]
[/LIST]

[b][color=#9CD04C]Check out my other addons/projects:[/color][/b]

[LIST]
[*] [url="https://www.esoui.com/downloads/fileinfo.php?id=4388#info"][color=#fa9c1b]Auto Lua Memory Cleaner[/color][/url]
[*] [url="https://www.esoui.com/downloads/fileinfo.php?id=4116#info"][color=#fa9c1b]Permanent Memento[/color][/url]
[*] [url="https://www.esoui.com/downloads/fileinfo.php?id=3249#info"][color=#fa9c1b]Tamriel Trade Center, HarvestMap, ESO-Hub, ESOUI Auto-Updater[/color][/url] [COLOR="Gray"][i](Linux, macOS, SteamDeck, & Windows)[/i][/COLOR]
[/LIST]

[b][color=#ff3300][SIZE="4"]BUG REPORTS[/SIZE][/color][/b]
If you encounter any issues, please submit a report here
[/center]