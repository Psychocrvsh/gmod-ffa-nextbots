# FFA NextBots — Lightweight Deathmatch Bots for Garry's Mod

A standalone, high-performance Free-For-All NextBot system for Garry's Mod built on native `base_nextbot` and C++ Navmesh navigation. Designed to simulate a fast-paced multiplayer deathmatch experience without external dependencies or heavy CPU overhead.

## Features

- **100% Standalone:** No external bases or required addons. Works out of the box with default HL2 weapons and playermodels.
- **Custom Weapons & Playermodels Support:** Easily toggle any installed Workshop weapons (MW Base, TFA, ArcCW, CS:S, etc.) and playermodels directly from the in-game menu.
- **Multiplayer-Style Polish:**
  - Randomized bot names displayed as 3D floating nametags (customizable scale, color, and render distance).
  - Full native killfeed integration (bot-vs-bot, bot-vs-player, and player-vs-bot) with weapon icons.
  - Compatible with third-party hitmarker and HUD addons via standard `OnNPCKilled` hooks.
- **Smart Combat & Navigation:**
  - Tactical strafing with lateral wall and ledge detection, automatic door opening, and stuck-bot recovery.
  - Built-in Navmesh status check and one-click `Generate Navmesh` button for maps missing a `.nav` file.
- **In-Game Admin Configuration:** Accessible via `Q (Spawn Menu) > Utilities > Admin > FFA NextBots` with persistent JSON configuration (`data/ffa_nextbots_config.json`).

## Installation

### From Steam Workshop (Later)
Subscribe to the addon on the Steam Workshop and launch any map with a `.nav` file.

### Manual / Git Installation
1. Clone or download this repository into your `garrysmod/addons/` directory:
```bash
git clone https://github.com/Psychocrvsh/gmod-ffa-nextbots.git
````

Extract and paste the folder into `...\steamapps\common\GarrysMod\garrysmod\addons\`. 2. Launch Garry's Mod, open the Spawn Menu (`Q` or `A`), and navigate to **Utilities > Admin > FFA NextBots**. 3. If the map lacks a Navmesh, click **Generate Navmesh (Map Reloads)**.

## Console Variables & Commands

|**ConVar / Command**|**Default**|**Description**|
|---|---|---|
|`ffabot_enabled`|`0`|Enable or disable automatic bot spawning|
|`ffabot_quota`|`8`|Maximum number of active bots (`0`–`40`)|
|`ffabot_health`|`100`|Starting health points for spawned bots|
|`ffabot_accuracy`|`1.0`|Bot aim accuracy multiplier (`0.2`–`2.5`)|
|`ffabot_only_custom_pm`|`1`|Use only Workshop playermodels when none are manually selected|
|`ffabot_spawn_now`|—|Immediately spawn a single bot|
|`ffabot_clear`|—|Remove all active FFA NextBots|
|`ffabot_generate_nav`|—|Enable `sv_cheats 1` and run `nav_generate`|

## Known Issues & Map Compatibility

- **Map-Dependent Spawning & Navigation:** Bot pathfinding and spawn distribution rely entirely on the quality of the map's `.nav` file. On community maps with fragmented, incomplete, or bottlenecked Navmeshes (e.g., certain indoor sections or ported maps), bots may spawn repeatedly in the same rooms or fail to reach isolated areas. Running `nav_generate` on a clean map often improves coverage.
    
- **Stuck Bots on Complex Props:** While an automatic stuck-recovery monitor relocates stationary bots after a few seconds, bots may still briefly clip or get caught on intricate map geometry, narrow ladders, or physics props. Use `ffabot_clear` (or the menu button) to reset active bots if needed.
    
- **Third-Party Weapon Bases (MW Base, TFA, ArcCW):** Bots emulate weapon firing stats using the selected weapon's worldmodel and primary attack data. Complex weapon features (custom projectiles, melee-only SWEPs, or scripted secondary fire modes) may not behave identically to player-held weapons, and high bot quotas (`20+`) combined with heavy weapon bases on massive maps can cause brief engine micro-stutters.
    
- **No Team Modes (FFA Only):** This addon is strictly built for Free-For-All combat—every bot treats all players and other bots as hostile targets.
    

## Credits & Transparency

- **Concept, testing, integration & game design:** Psychocrvsh
    
- **AI Assistance:** Parts of the Lua architecture, debugging, and optimization were co-developed with AI assistance (Gemini).

## License

This project is open-source and licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

You are free to use, modify, and redistribute this addon or build derivative versions of it, **provided that you include proper credit and a link back to the original repository ([Psychocrvsh/gmod-ffa-nextbots](https://github.com/Psychocrvsh/gmod-ffa-nextbots)) or Steam Workshop page**.