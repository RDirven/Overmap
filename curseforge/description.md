# Overmap

**A fully customizable, see-through map overlay, like the one in Diablo 2.** Press a key and your zone is drawn over the world. Press it again and it's gone. Great for questing, exploring and farming routes, in WoW Forever and Retail.

Overmap draws the map itself instead of reusing the game's world map. That means **no taint, it works in combat, and your normal map (M) stays as it is.**

## Features

- **Toggle or hold**: one key turns it on and off, or use a key that shows it only while you hold it.
- **Opacity your way**: separate sliders for the map, the markers and a dark background. It can fade further while you move. There are also keys to make it more or less see-through on the fly.
- **Diablo look**: glowing (additive) drawing, black and white with any colour tint, and **fog of war** that shows only the areas you have explored.
- **Shapes**: square, oval or diamond, each with hard, soft or very soft edges.
- **Move, resize, zoom, pan**: hold Shift over the map. Otherwise it is fully click-through, so you keep playing.
- **Follow me**: keeps you centred like a big minimap, with smooth zoom.
- **Markers**: quests, rares and treasures, points of interest, flight masters, party and raid in class colours, your corpse and your map pin. Hover a marker to see its name.
- **Farming tools**: your own farm marks (raid icons with a label, saved per zone) and a trail of where you walked.
- **Presets**: Diablo, See-through, Farming and Corner, plus your own saved setups.
- Optionally hide the minimap while it's open, or hide the overlay in combat.

## Getting started

1. Install it.
2. Type `/om bind TAB` (or any key), or set a key in **Key Bindings > AddOns > Overmap**.
3. Type `/om` to open the options. The map stays visible while you tweak it.

## Commands

- `/om`: options
- `/om toggle`, `/om show`, `/om hide`
- `/om preset diablo | overlay | farming | corner`
- `/om save <name>` and `/om load <name>`: your own presets
- `/om bind <key>` and `/om hold <key>`
- `/om mark [1-8] [label]`, `/om unmark`, `/om clearmarks`
- `/om cleartrail`, `/om center`, `/om reset`

## Good to know

- In dungeons and raids the game hides your position, so the arrow and follow-me pause there. The map is still drawn.
- Markers from other addons (Questie, HandyNotes) don't appear, because this isn't the game's world map.

Bugs and ideas are welcome in the comments.
