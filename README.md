# DidYouGrind

A lightweight World of Warcraft addon that tracks your weekly progress in one compact window.

Built for fast "did I already do this?" checks without opening multiple Blizzard panels.

## Features

- Movable and resizable tracker frame
- Minimize / expand mode
- Config panel (gear button, top-right)
- Lock frame option (disables moving/resizing)
- Section visibility toggles:
  - Keys
  - Dawncrests
  - Weekly Boss
  - Great Vault
  - Great Vault child sections (Raids, Dungeons, World/Delves)
- Auto refresh on events + timed polling
- Compact mode for denser layout

## Tracked Data

- **Keys**
  - Restored Coffer Key
  - Coffer Key Shards
- **Dawncrests**
  - Adventurer
  - Veteran
  - Champion
  - Hero
- **Weekly Boss**
  - Killed / Not killed / Unknown
- **Great Vault**
  - Raids slots (1-3)
  - Dungeons slots (1-3)
  - World/Delves slots (1-3)
  - Progress, unlock status, tier, and (when available) example item level

## Installation

1. Place this folder in your WoW addons directory:
   - `World of Warcraft\_retail_\Interface\AddOns\DidYouGrind`
2. Make sure these files exist:
   - `DidYouGrind.toc`
   - `DidYouGrind.lua`
3. Start WoW (or run `/reload` if already in-game).
4. Enable **DidYouGrind** in the AddOns list at character select.

## Usage

- Type `/dyg` to view available commands.
- Use the top-right buttons:
  - `- / +` button to minimize/expand
  - gear button to open Settings
- Click section headers to collapse/expand groups.

## Slash Commands

- `/dyg`  
  Show command help.

- `/dyg reset`  
  Reset frame position and size.

- `/dyg min`  
  Minimize the tracker.

- `/dyg max`  
  Expand the tracker.

- `/dyg toggle`  
  Show/hide the tracker frame.

- `/dyg refresh`  
  Force immediate data refresh.

- `/dyg config`  
  Open/close the settings panel.

- `/dyg options`  
  Alias for `/dyg config`.

- `/dyg wbdebug`  
  Toggle weekly boss debug mode.  
  When enabled, quest turn-ins are printed to chat with `questID` to help identify correct weekly boss quest IDs.

## Weekly Boss Notes

Weekly boss tracking supports two detection paths:

1. **Quest completion** (most reliable, preferred)
2. **Saved world boss lockout fallback**

If your character killed the weekly boss but it still shows `Not killed` or `Unknown`, that usually means the lockout API is not reporting this specific boss in your current rotation.

Use `/dyg wbdebug`, kill/turn in, then capture the printed `questID` and add it in `DidYouGrind.lua`:

```lua
local WEEKLY_BOSS_QUEST_IDS = { 12345, 67890 }
```

You can store multiple IDs to support rotating weekly boss quests.

## Saved Variables

The addon stores settings in `DidYouGrindDB`, including:

- Frame position and size
- Minimized state
- Start minimized
- Auto refresh
- Compact mode
- Frame lock
- Section visibility
- Collapsed section states
- Weekly boss debug toggle

## Development

This repo is intended for local real-time testing:

1. Edit files in this folder.
2. In-game, run `/reload`.
3. Validate behavior immediately.
4. Commit/push stable checkpoints.

## License

No license file is currently included. Add one if you plan to share publicly.
