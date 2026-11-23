
# FFA NextBots — Lightweight Deathmatch Bots for Garry's Mod

A standalone, high-performance Free-For-All NextBot system for Garry's Mod built on native `base_nextbot` and C++ Navmesh navigation. Designed to simulate a fast-paced multiplayer deathmatch experience without external dependencies or heavy CPU overhead.

## Features

- **100% Standalone:** No external bases or required addons. Works out of the box with default HL2 weapons and playermodels.
- **Custom Weapons & Playermodels Support:** Easily toggle any installed Workshop weapons (MW Base, TFA, ArcCW, CS:S, etc.) and playermodels directly from the in-game menu.
- **Multiplayer-Style Polish:**
  - Randomized bot names displayed as 3D floating nametags.
  - Full native killfeed integration (bot-vs-bot, bot-vs-player, and player-vs-bot) with weapon icons
  - Compatible with third-party hitmarker and HUD addons via standard `OnNPCKilled` hooks.
- **Smart Combat & Navigation:**
  - Tactical strafing with lateral wall and ledge detection to prevent getting stuck or walking off edges.
  - Built-in Navmesh status check and one-click `Generate Navmesh` button for maps missing a `.nav` file.
- **In-Game Admin Configuration:** Accessible via `Q (Spawn Menu) > Utilities > Admin > FFA NextBots` with persistent JSON configuration (`data/ffa_nextbots_config.json`).

## Installation

### From Steam Workshop (Later)
Subscribe to the addon on the Steam Workshop and launch any map with a `.nav` file.

### Manual / Git Installation
1. Clone or download this repository into your `garrysmod/addons/` directory:
```bash
   git clone https://github.com/Psychocrvsh/gmod-ffa-nextbots.git
```
extract and paste the folder into ...steamapps\common\GarrysMod\garrysmod\addons\
2. Launch Garrys Mod, open the Spawn Menu (`Q` or `A`), and navigate to **Utilities > Admin > FFA NextBots**.
    
3. If the map lacks a Navmesh, click **Generate Navmesh (Map Reloads)**.
    

## Console Variables & Commands

| **ConVar / Command**    | **Default** | **Description**                                                |
| ----------------------- | ----------- | -------------------------------------------------------------- |
| `ffabot_enabled`        | `0`         | Enable or disable automatic bot spawning                       |
| `ffabot_quota`          | `8`         | Maximum number of active bots (`0`–`40`)                       |
| `ffabot_health`         | `100`       | Starting health points for spawned bots                        |
| `ffabot_accuracy`       | `1.0`       | Bot aim accuracy multiplier (`0.2`–`2.5`)                      |
| `ffabot_only_custom_pm` | `1`         | Use only Workshop playermodels when none are manually selected |
| `ffabot_spawn_now`      | —           | Immediately spawn a single bot                                 |
| `ffabot_clear`          | —           | Remove all active FFA NextBots                                 |
| `ffabot_generate_nav`   | —           | Enable `sv_cheats 1` and run `nav_generate`                    |

## Credits & Transparency

- **Concept, testing, integration & game design:** Psychocrvsh
    
- **AI Assistance:** Parts of the Lua architecture, debugging, and optimization were co-developed with AI assistance (Gemini).
