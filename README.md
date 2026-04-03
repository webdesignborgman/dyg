# DidYouGrind

A lightweight World of Warcraft addon for quick weekly-progress checks.

## What It Tracks

- Keys
  - Restored Coffer Key
  - Coffer Key Shards
- Dawncrests
  - Adventurer
  - Veteran
  - Champion
  - Hero
- Weekly Boss
  - Killed / Not killed / Unknown
- Great Vault
  - Raids slots (1-3)
  - Dungeons slots (1-3)
  - World/Delves slots (1-3)
  - Progress + ready state + tier + example ilvl (when available)

## Main Features

- Movable + resizable tracker frame
- Minimize / expand
- Gear settings panel
- Lock frame
- Compact mode
- Auto refresh toggle
- Per-character display preferences
- Optional account-wide layout sharing
- Section show/hide controls
- Category icons + divider lines above category headers

## ALTS Board

Click the `ALTS` button in the tracker header to open the Alt Board.

- Left side: tracked alts list (snapshot cards)
- Right side: selected alt details for all tracked stats
- `x` on a character row hides that alt from the list
- Hidden alts reappear automatically when that character logs in again and writes a fresh snapshot

## Weekly Boss Detection

The addon uses:

1. Known quest IDs
2. Auto-learned quest IDs from turn-ins (for known Midnight world boss names)
3. Lockout fallback when available

Useful commands:

- `/dyg wbdebug` toggles debug printing on `QUEST_TURNED_IN`
- `/dyg wbids` prints known weekly boss quest IDs

## Slash Commands

- `/dyg` show help
- `/dyg reset` reset frame position/size
- `/dyg min` minimize tracker
- `/dyg max` expand tracker
- `/dyg toggle` show/hide tracker
- `/dyg refresh` force refresh
- `/dyg config` open/close settings
- `/dyg options` alias of `/dyg config`
- `/dyg alts` open/close ALTS board
- `/dyg wbdebug` toggle weekly boss debug logging
- `/dyg wbids` list known weekly boss quest IDs
- `/dyg layoutscope` show current layout scope mode

## Installation

1. Place this folder in:
   - `World of Warcraft\_retail_\Interface\AddOns\DidYouGrind`
2. Ensure these files exist:
   - `DidYouGrind.toc`
   - `DidYouGrind.lua`
3. Launch WoW (or run `/reload`).
4. Enable **DidYouGrind** at character select.

## SavedVariables Notes

Data is stored in `DidYouGrindDB`, including:

- Character snapshots (for ALTS board)
- Hidden alt list
- Weekly boss learned quest IDs
- Profile settings (layout scope + per-character display prefs)

## Dev Workflow

1. Edit addon files locally.
2. `/reload` in-game.
3. Validate behavior.
4. Commit and push stable checkpoints.
