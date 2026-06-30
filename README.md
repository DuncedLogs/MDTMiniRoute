# MDT Mini Route

A small World of Warcraft companion addon/plugin for Mythic Dungeon Tools.

It adds a movable mini overlay that shows the current MDT dungeon map, MDT-style pull outlines, pull colors, selected/current pull, and an optional clickable pull sidebar.

Mini Route is a separate addon and does not edit Mythic Dungeon Tools files. It opens its own floating options window alongside MDT instead of injecting controls into MDT's settings page. The options include separate map and icon alpha controls, separate sidebar and minimap pull-number font controls, a clean frame/title toggle, a configurable clickable pull sidebar, and an optional dungeon-only mode with per-dungeon layouts.

## Requirements

- World of Warcraft retail or Mists client supported by the installed MDT version
- Mythic Dungeon Tools

The current `.toc` includes interface `120007`.

## Install

1. Extract `MDTMiniRoute` into `World of Warcraft\_retail_\Interface\AddOns`.
2. Restart the game or run `/reload`.
3. Enable `MDT Mini Route` in the addon list.

## Commands

- `/mdtmini` toggles the overlay.
- `/mdtmini options` opens the floating options window.
- `/mdtmini lock` locks movement.
- `/mdtmini unlock` unlocks movement.
- `/mdtmini pull 3` selects pull 3 and switches the mini route to selected-pull mode.
- `/mdtmini all` toggles all pulls vs selected/current pull only.
- `/mdtmini outlines` toggles MDT-style pull outlines.
- `/mdtmini lines` toggles route connection lines.
- `/mdtmini numbers` toggles pull numbers.
- `/mdtmini frame` toggles the overlay frame, title, and background artwork.
- `/mdtmini dungeon` toggles only showing the overlay inside the matching dungeon. When enabled, position, width, alpha, icon alpha, and frame/title visibility are saved per dungeon.
- `/mdtmini sidebar` toggles the clickable pull sidebar.
- `/mdtmini side` toggles the sidebar between left and right.
- `/mdtmini detach` toggles the sidebar between attached and detached.
- `/mdtmini sidebarlock` locks or unlocks movement for the detached sidebar.
- `/mdtmini percent` toggles sidebar percentages.
- `/mdtmini size 348` sets overlay width.
- `/mdtmini alpha 0.85` sets map transparency.
- `/mdtmini iconalpha 0.85` sets route marker transparency.
- `/mdtmini reset` resets size and position.

Click the pull sidebar to choose the selected pull. The fixed `All Pulls` button at the top of the sidebar toggles all pulls vs selected/current pull only without scrolling away, and also works as the detached sidebar drag handle when `Lock detached sidebar` is off. The font pickers use LibSharedMedia fonts when available, including ElvUI fonts if ElvUI is loaded. Mouse wheel over the sidebar scrolls it. Drag the title bar, or the map itself when the frame/title is hidden, to move the overlay. Mouse wheel over the overlay resizes it.

When `/mdt` opens, Mini Route opens its own options window.
