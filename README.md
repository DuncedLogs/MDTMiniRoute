# MDT Mini Route

A small World of Warcraft companion addon/plugin for Mythic Dungeon Tools.

It adds a movable mini overlay that shows the current MDT dungeon map, MDT-style pull outlines, enemy icons, POIs, pull colors, and selected/current pull.

Mini Route is a separate addon and does not edit Mythic Dungeon Tools files. After MDT opens, it appends a Mini Route group to MDT's existing Settings page.

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
- `/mdtmini lock` locks movement.
- `/mdtmini unlock` unlocks movement.
- `/mdtmini all` toggles all pulls vs selected/current pull only.
- `/mdtmini enemies` toggles enemy icons.
- `/mdtmini unpulled` toggles enemies that are not assigned to a pull.
- `/mdtmini dots` toggles enemy dots.
- `/mdtmini pois` toggles POIs.
- `/mdtmini outlines` toggles MDT-style pull outlines.
- `/mdtmini lines` toggles route connection lines.
- `/mdtmini numbers` toggles pull numbers.
- `/mdtmini size 348` sets overlay width.
- `/mdtmini alpha 0.85` sets transparency.
- `/mdtmini reset` resets size and position.

Drag the top bar to move it. Mouse wheel over the top bar resizes it.

Most options are also available inside MDT's Settings page under the Mini Route group.
