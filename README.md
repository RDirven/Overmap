# Overmap

A fully customizable, click-through map overlay in the style of Diablo 2, for **WoW Forever** and **Retail**.
Press a key and your zone is drawn over the world. Press it again (or let go of a hold key) and it is gone.

Unlike other overlay addons, it does **not** borrow the game's world map: it draws the map art itself.
So it never taints the UI, it works in combat, and your normal map (M) is not changed.

## Features

- **Toggle or hold**: one key to switch it on and off, or a key that shows it only while held.
- **Opacity**: separate sliders for the map, the markers and a dark background, plus a lower opacity while you move.
  Keys for more or less opacity on the fly.
- **Diablo look**: "Glow" drawing (additive), black-and-white with any colour tint, and **fog of war**
  (only the parts of the zone you have explored are drawn).
- **Shape**: square, oval or diamond, with hard, soft or very soft edges. Markers fade out along the edge too.
- **Size, scale, position and layer**: hold Shift over the map to drag it, resize it from the corner,
  zoom with the mouse wheel or pan with the right button. Middle-click puts the view back.
- **Zoom and follow me**: keeps you in the middle, like a minimap, with smooth zoom (keys for zoom in and out).
- **Markers**: quests, rares and treasures, points of interest, flight masters, party and raid (class colours),
  your corpse and your map pin. Names show on hover without catching your clicks.
- **Farming**: your own farm marks (raid icons with a label, saved per zone) and a walked trail that shows which
  part of your route you have done.
- **Presets**: Diablo, See-through, Farming and Corner, plus your own (`/om save <name>`, `/om load <name>`).
- Hide the minimap while it is open, hide it in combat, zone name and coordinates.

## Getting started

1. Copy the `Overmap` folder to `World of Warcraft\_<flavor>_\Interface\AddOns\`.
2. Bind a key: `/om bind TAB` (toggle) or `/om hold <key>` (hold), or via Key Bindings > AddOns > Overmap.
3. `/om` opens the options. The map stays visible while you change them.

## Commands

| Command | |
| --- | --- |
| `/om` | options |
| `/om toggle`, `show`, `hide` | the overlay |
| `/om preset diablo \| overlay \| farming \| corner` | load a preset |
| `/om save <name>`, `/om load <name>` | your own presets |
| `/om bind <key>`, `/om hold <key>` | bind a key |
| `/om mark [1-8] [label]` | farm mark at your position |
| `/om unmark`, `/om clearmarks` | remove the nearest / all marks on this map |
| `/om cleartrail` | clear the walked trail |
| `/om center`, `/om reset` | back to the middle / default settings |

## Good to know

- In dungeons and raids the game hides your position, so the arrow, follow me and the trail stop there.
  The map itself is still drawn.
- Markers of other addons (Questie, HandyNotes) are not drawn, since this overlay is not the game's world map.
- If the addon shows as "out of date", check your game's number with `/dump select(4, GetBuildInfo())`
  and add it to the `## Interface:` line in `Overmap.toc`.
