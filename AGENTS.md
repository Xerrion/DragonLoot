# DragonLoot - Agent Guidelines

Project-specific guidelines for DragonLoot. See the parent `../AGENTS.md` for general WoW addon development rules.

---

## Overview

DragonLoot is a customizable loot addon that replaces the default Blizzard loot window, loot roll views, and provides a loot history frame.

**Status**: Feature-complete (Phases 1-5, 8, 10). Loot window, roll frame, loot history, config wiring, edge case fixes, DragonToast integration, individual roll notifications, instance-type filtering, and appearance expansion (font outline, quality borders, background/border customization) are all implemented.

**GitHub**: https://github.com/Xerrion/DragonLoot

---

## Target Versions

| Version | Interface | TOC Directive |
|---------|-----------|---------------|
| Retail | 110207, 120001, 120000 | `## Interface: 110207, 120001, 120000` |
| TBC Anniversary | 20505 | `## Interface-BCC: 20505` |
| Cata Classic | 40402 | `## Interface-Cata: 40402` |
| MoP Classic | 50503 | `## Interface-Mists: 50503` |

Version-specific files are loaded via BigWigsMods packager comment directives (`#@retail@` / `#@tbc-anniversary@` / `#@version-mists@` / `#@version-cata@`) in the TOC.

---

## Architecture

| Layer | Directory | Responsibility |
|-------|-----------|----------------|
| Core | `Core/` | Addon lifecycle, config, slash commands, minimap icon |
| Display | `Display/` | UI frames and presentation (loot window, roll frame, history) |
| Listeners | `Listeners/` | Event handling and version-specific loot/roll/history parsing |
| Libs | `Libs/` | Embedded Ace3 + utility libraries |

### File Map

| File | Purpose |
|------|---------|
| `Core/Init.lua` | AceAddon bootstrap, lifecycle, Blizzard frame suppression |
| `Core/Config.lua` | AceDB defaults, AceConfig options table, schema migration |
| `Core/ConfigWindow.lua` | AceConfigDialog toggle |
| `Core/MinimapIcon.lua` | LDB + LibDBIcon minimap button |
| `Core/SlashCommands.lua` | `/dl` and `/dragonloot` command router |
| `Display/LootFrame.lua` | Loot window frame pool, slot rendering, drag/position, test loot |
| `Display/LootAnimations.lua` | LibAnimate fadeIn/fadeOut for loot window |
| `Display/RollFrame.lua` | Roll frame pool (up to 4), timer bar, Need/Greed/DE/Pass/Transmog buttons |
| `Display/RollAnimations.lua` | LibAnimate slideInRight/fadeOut for roll frames |
| `Display/RollManager.lua` | Roll orchestration, overflow FIFO queue, timer tick, DRAGONTOAST_QUEUE_TOAST messaging |
| `Display/HistoryFrame.lua` | Scrollable loot history, entry pool, class-colored winners, time-ago refresh |
| `Listeners/LootListener_Retail.lua` | Retail: LOOT_OPENED + LOOT_READY with pendingAutoLoot |
| `Listeners/LootListener_Classic.lua` | Classic: LOOT_OPENED for TBC/MoP/Cata |
| `Listeners/RollListener_Retail.lua` | Retail: START_LOOT_ROLL, CANCEL_LOOT_ROLL, CANCEL_ALL_LOOT_ROLLS, recovery |
| `Listeners/RollListener_Classic.lua` | Classic: same minus CANCEL_ALL_LOOT_ROLLS |
| `Listeners/HistoryListener_Retail.lua` | Retail: encounter-based C_LootHistory with dedup |
| `Listeners/HistoryListener_Classic.lua` | Classic: roll-item indexed C_LootHistory |

### Namespace Pattern

All files use the shared private namespace:
```lua
local ADDON_NAME, ns = ...
```

### Namespace Sub-tables

All modules attach to `ns`:

| Sub-table | Set by |
|-----------|--------|
| `ns.Addon` | `Core/Init.lua` |
| `ns.LootFrame` | `Display/LootFrame.lua` |
| `ns.LootAnimations` | `Display/LootAnimations.lua` |
| `ns.RollFrame` | `Display/RollFrame.lua` |
| `ns.RollAnimations` | `Display/RollAnimations.lua` |
| `ns.RollManager` | `Display/RollManager.lua` |
| `ns.HistoryFrame` | `Display/HistoryFrame.lua` |
| `ns.LootListener` | `Listeners/LootListener_*.lua` |
| `ns.RollListener` | `Listeners/RollListener_*.lua` |
| `ns.HistoryListener` | `Listeners/HistoryListener_*.lua` |
| `ns.ConfigWindow` | `Core/ConfigWindow.lua` |
| `ns.MinimapIcon` | `Core/MinimapIcon.lua` |
| `ns.Print` | `Core/Init.lua` (helper function) |
| `ns.DebugPrint` | `Core/Init.lua` (helper function) |

### Config Schema Reference

#### Appearance Config (`db.profile.appearance`)

| Key                | Type    | Default              | Description                       |
|--------------------|---------|----------------------|-----------------------------------|
| font               | string  | "Friz Quadrata TT"  | LSM font name                     |
| fontSize           | number  | 12                   | Font size (8-20)                  |
| fontOutline        | string  | "OUTLINE"            | Font outline style                |
| iconSize           | number  | 36                   | Item icon size (16-64)            |
| qualityBorder      | boolean | true                 | Show quality-colored icon borders |
| backgroundColor    | table   | {r=0.05,g=0.05,b=0.05} | Frame background color         |
| backgroundAlpha    | number  | 0.9                  | Frame background opacity (0-1)    |
| backgroundTexture  | string  | "Solid"              | LSM statusbar texture for bg      |
| borderColor        | table   | {r=0.3,g=0.3,b=0.3} | Frame border color                |
| borderSize         | number  | 1                    | Border thickness (0-4)            |
| borderTexture      | string  | "Solid"              | LSM statusbar texture for border  |

#### Roll Frame Config (`db.profile.rollFrame`)

| Key              | Type   | Default     | Description                     |
|------------------|--------|-------------|---------------------------------|
| timerBarTexture  | string | "Blizzard"  | LSM statusbar texture for timer |

---

## Version-Specific API Differences

| Aspect | Retail | Classic (TBC/Cata/MoP) |
|--------|--------|------------------------|
| GetLootSlotInfo returns | 10 | 6 |
| GetLootRollItemInfo returns | 13 (incl canTransmog) | 12 |
| C_LootHistory | Encounter-based | Roll-item indexed |
| CANCEL_ALL_LOOT_ROLLS | Yes | No |
| LOOT_READY event | Yes (fires after LOOT_OPENED) | No |
| C_Loot.GetLootRollDuration | Yes | No |
| Loot listener | LootListener_Retail | LootListener_Classic |
| Roll listener | RollListener_Retail | RollListener_Classic |
| History listener | HistoryListener_Retail | HistoryListener_Classic |

---

## DragonToast Integration

DragonLoot integrates with DragonToast (sibling addon) via the generic DragonToast messaging API. Messages are fire-and-forget - no detection needed. Neither addon requires the other.

### Messages Sent by DragonLoot

DragonLoot uses the generic DragonToast messaging API (fire-and-forget, no detection needed):

| Message | Payload | When |
|---------|---------|------|
| `DRAGONTOAST_SUPPRESS` | `"DragonLoot"` (source string) | Loot window opens |
| `DRAGONTOAST_UNSUPPRESS` | `"DragonLoot"` (source string) | Loot window closes |
| `DRAGONTOAST_QUEUE_TOAST` | toast data table (see below) | A player wins a roll |
| `DRAGONTOAST_QUEUE_TOAST` | toast data table (see below) | Individual roll result (Phase 8) |

#### Roll Won Toast Data

```lua
{
    itemLink = string,     -- full item hyperlink
    itemName = string,     -- item name
    itemQuality = number,  -- 0-7 quality enum
    itemIcon = number,     -- icon texture ID
    itemID = number,       -- parsed from itemLink
    quantity = number,     -- stack count
    isRollWin = true,      -- suppression bypass flag
    isSelf = boolean,      -- true if current player won
    looter = string,       -- winner's name
    itemType = string,     -- e.g. "Need (87)" for display
    timestamp = number,    -- GetTime()
}
```

#### Individual Roll Result Toast Data (Phase 8)

```lua
{
    itemLink = string,     -- full item hyperlink
    itemName = string,     -- item name
    itemQuality = number,  -- 0-7 quality enum
    itemIcon = number,     -- icon texture ID
    itemID = number,       -- parsed from itemLink
    quantity = 1,          -- always 1
    isRollWin = false,     -- not a win notification
    isSelf = boolean,      -- true if current player rolled
    looter = string,       -- roller's name
    itemType = string,     -- e.g. "Need (87)" or "Greed (42)" for display
    timestamp = number,    -- GetTime()
}
```

### DragonToast Behavior

- `DRAGONTOAST_SUPPRESS` with source `"DragonLoot"` sets a suppress flag; item loot toasts are suppressed while DragonLoot's loot window is open
- `DRAGONTOAST_UNSUPPRESS` with source `"DragonLoot"` clears the suppress flag
- `DRAGONTOAST_QUEUE_TOAST` with `isRollWin = true` triggers a celebration toast
- `DRAGONTOAST_QUEUE_TOAST` with `isRollWin = false` triggers a standard item toast (individual roll result)
- XP, honor, currency toasts are never suppressed
- DragonToast's `Listeners/MessageBridge.lua` handles backward compatibility for old message names (`DRAGONLOOT_LOOT_OPENED`, `DRAGONLOOT_LOOT_CLOSED`, `DRAGONLOOT_ROLL_WON`)

---

## Placeholders

The following values are placeholders and must be updated before first release:

| Item | Placeholder | File |
|------|-------------|------|
| CurseForge Project ID | `0000000` | `DragonLoot.toc` |
| Wago ID | `TBD` | `DragonLoot.toc` |
| Icon texture | `Interface\AddOns\DragonLoot\DragonLoot_Icon` | `DragonLoot.toc` |

---

## Ace3 Stack

DragonLoot embeds Ace3 via `Libs/embeds.xml`. The full Ace3 library set is available:

| Library | Usage |
|---------|-------|
| AceAddon | Addon lifecycle |
| AceEvent | Event registration + inter-addon messaging |
| AceTimer | Timers (history refresh, roll tick) |
| AceDB | SavedVariables + profiles |
| AceConfig | Options table registration |
| AceConfigDialog | Blizzard settings integration |
| AceGUI | Standalone config window |
| AceConsole | Slash command registration |
| AceHook | Hook management |
| LibSharedMedia-3.0 | Font/texture selection |
| LibDataBroker-1.1 | Data source for minimap icon |
| LibDBIcon-1.0 | Minimap button |
| LibAnimate | Animation library (loot fadeIn/Out, roll slideIn/fadeOut) |
| AceGUI-SharedMediaWidgets | SharedMedia dropdowns in AceGUI |

### Local Dev: Ace3 Submodule

`.pkgmeta` externals only work during CI packaging. For local dev, add Ace3 as a git submodule at `Libs/Ace3/`.

---

## CI/CD

### Workflows

| File | Trigger | Purpose |
|------|---------|---------|
| `lint.yml` | `pull_request_target` to master | Luacheck (uses `pull_request_target` so it runs on release-please bot PRs) |
| `release-pr.yml` | `push` to master | release-please creates/updates a Release PR with version bump and changelog |
| `release.yml` | tag push or `workflow_dispatch` | BigWigsMods packager builds and uploads to CurseForge, Wago, and GitHub Releases |

### Secrets

| Secret | Purpose |
|--------|---------|
| `CF_API_KEY` | CurseForge upload |
| `WAGO_API_TOKEN` | Wago.io upload |

### Project IDs

| Platform | ID | TOC Field |
|----------|----|-----------|
| CurseForge | `0000000` (placeholder) | `X-Curse-Project-ID` |
| Wago | `TBD` (placeholder) | `X-Wago-ID` |

---

## Local Development

### Install Location

Create a directory junction from the WoW addons folder to the repo:
```powershell
New-Item -ItemType Junction -Path "E:\World of Warcraft\_anniversary_\Interface\AddOns\DragonLoot" -Target "F:\Repos\wow-addons\DragonLoot"
```

### Testing

No automated test framework. Test manually in-game.

#### Slash Commands

| Command | Action |
|---------|--------|
| `/dl` or `/dragonloot` | Toggle addon enabled/disabled |
| `/dl help` | Show all commands |
| `/dl status` | Print current settings |
| `/dl config` | Toggle config window |
| `/dl minimap` | Toggle minimap icon |
| `/dl enable` / `/dl disable` | Explicit enable/disable |
| `/dl reset` | Reset loot frame position |
| `/dl test` | Show test loot data |
| `/dl history` | Toggle history frame |

#### Phase 1 - Core (Manual Test Steps)

1. Load the addon in any supported game version
2. `/console scriptErrors 1` to catch Lua errors
3. Verify addon loaded message appears in chat on login
4. `/dl help` - verify help text lists all commands
5. `/dl status` - verify status output shows current settings
6. `/dl config` - verify config window opens with all tab groups
7. `/dl config` again - verify config window toggles closed
8. `/dl` - verify addon toggles disabled, then `/dl` again to re-enable
9. `/dl enable` and `/dl disable` - verify explicit enable/disable
10. `/dl minimap` - verify minimap icon toggles visibility
11. Left-click minimap icon - verify config window opens
12. Right-click minimap icon - verify addon toggles enabled/disabled
13. Shift-left-click minimap icon - verify test loot appears
14. Hover minimap icon - verify tooltip shows name, status, and shortcuts

#### Phase 2 - Loot Window (Manual Test Steps)

1. `/dl test` - verify custom loot window appears with test items
2. Verify items show icon, name, quantity, and quality-colored text
3. Click an item slot - verify it attempts to loot (or shows error for test data)
4. Drag the loot frame title bar - verify frame moves
5. Lock the frame via config - verify drag is blocked
6. `/dl reset` - verify frame returns to default position
7. Close the loot window - verify fadeOut animation plays
8. Open real loot (kill a mob) - verify DragonLoot window appears instead of Blizzard
9. Verify auto-loot passthrough works when shift-clicking or auto-loot is on
10. Disable loot window in config - verify Blizzard frame returns

#### Phase 3 - Loot Roll (Manual Test Steps)

1. Queue for a dungeon or raid where loot rolls occur
2. Verify roll frame appears with item icon, name, and timer bar
3. Verify timer bar color interpolates green -> yellow -> red
4. Click Need/Greed/DE/Pass buttons - verify roll is submitted
5. Verify frame slides in from right (animation)
6. Verify frame fades out on completion
7. If multiple rolls occur, verify overflow queue handles them (max 4 visible)
8. `/reload` during a roll - verify roll recovery works
9. Disable roll frame in config - verify Blizzard GroupLootFrame returns
10. If Transmog button shows (Retail only), verify pcall atlas fallback works

#### Phase 4 - Loot History (Manual Test Steps)

1. `/dl history` - verify history frame opens (may be empty)
2. Complete a dungeon boss with loot - verify entries appear
3. Verify entries show item icon, quality-colored item name, class-colored winner
4. Verify time-ago text updates every 10 seconds
5. Hover an entry - verify item tooltip appears
6. Click an entry - verify item link is inserted into chat
7. Scroll the history frame - verify scrollbar works
8. Drag the history frame - verify it moves
9. Lock history in config - verify drag is blocked
10. Set autoShow in config - verify history opens automatically on new loot

#### Phase 5 - Polish and Integration (Manual Test Steps)

1. Change font/fontSize/iconSize in config - verify all frames update immediately
2. Toggle animation enabled/disabled - verify animations respect the setting
3. With DragonToast installed: open loot window - verify DragonToast suppresses item toasts
4. With DragonToast installed: close loot window - verify DragonToast resumes normal toasts
5. With DragonToast installed: win a roll - verify DragonToast shows a celebration toast
6. Without DragonToast: verify all features work independently

#### Phase 8 - Roll Notifications and Instance Filtering (Manual Test Steps)

1. Open `/dl config` -> Loot Roll tab - verify new sections: Individual Roll Results, Instance Filtering
2. Enable "Show Individual Roll Results" - verify sub-options (Your Rolls, Group Rolls) become enabled
3. Disable "Show Individual Roll Results" - verify sub-options become disabled (greyed out)
4. Enable individual roll results, queue for a dungeon with Need/Greed loot
5. When rolls resolve, verify a DragonToast notification appears for each player's roll (not just winner)
6. Verify Pass rolls do NOT generate a toast
7. Disable "Show Your Rolls" - verify your own rolls no longer produce toasts
8. Disable "Show Group Rolls" - verify other players' rolls no longer produce toasts
9. Set "Minimum Quality" to Rare - verify Common/Uncommon items do not produce roll toasts
10. Disable "Show in Dungeons" - verify no roll notifications appear while in a dungeon
11. Enable "Show in Dungeons", disable "Show in Raids" - verify no roll notifications in raids
12. Disable "Show in Open World" - verify no roll notifications in world content
13. Verify roll won toasts also respect instance filtering and minimum quality
14. Verify no duplicate toasts for the same player/drop combination

#### Phase 10 - Appearance Expansion (Manual Test Steps)

1. Open config with `/dl` -> Appearance section
2. Verify all new options are present:
   - Font Outline (dropdown: None, Outline, Thick Outline, Monochrome)
   - Quality Border (toggle)
   - Background Color (color picker)
   - Background Opacity (slider 0-100%)
   - Background Texture (LSM statusbar dropdown)
   - Border Color (color picker)
   - Border Size (slider 0-4)
   - Border Texture (LSM statusbar dropdown)
3. Change each setting and verify all 3 frames update live:
   - Loot Frame: `/dl test` to spawn test loot, verify backdrop/border/outline changes
   - Roll Frame: start a group loot roll, verify backdrop/border/outline/timer bar changes
   - History Frame: open via minimap icon after rolls, verify backdrop/border/outline changes
4. Test Quality Border toggle:
   - Enable: item icons show quality-colored borders
   - Disable: item icons have no colored border
5. Test Background Opacity: slide to 0% (transparent), 100% (opaque), verify frame backdrop
6. Test Border Size 0: verify border disappears cleanly (no artifacts)
7. Test Font Outline None: verify text renders without outline
8. Test Timer Bar Texture: open Loot Roll options, change timer bar texture, verify roll timer bar updates
9. `/reload` and verify settings persist

---

## Deferred Features

- **Auto-loot with blacklist/whitelist filtering** - requires custom UI (not AceConfig), planned for future phase

---

## Known Gotchas

1. **GetItemInfo may return nil** on first call if item not cached - handle with retry timers
2. **CHAT_MSG_LOOT patterns are localized** - parsing requires Lua pattern matching on localized strings
3. **TOC conditional loading** - Mid-file `## Interface:` directives don't work. Use BigWigsMods packager comment directives (`#@retail@`, `#@tbc-anniversary@`, `#@version-mists@`, `#@version-cata@`)
4. **pull_request vs pull_request_target** - GitHub doesn't trigger `pull_request` workflows for PRs created by GITHUB_TOKEN (release-please). Use `pull_request_target` for lint workflows
5. **Blizzard frame suppression** - Must restore events on disable or the default loot window breaks permanently for the session
6. **Retail C_LootHistory duplicate events** - LOOT_HISTORY_UPDATE_ENCOUNTER re-fires for all drops; use processedDrops dedup table
7. **Retail API field names** - `winner.playerClass` not `winner.className` in C_LootHistory
8. **Classic double-open** - LOOT_OPENED can fire twice; guard with `if isLootOpen then return end`
9. **Roll data availability** - Fetch item info via GetLootRollItemInfo BEFORE calling CancelRoll, as data is lost after cancel
10. **Local dev listener loading** - All packager directives are comments locally; both Retail and Classic listeners load. Version guards (`WOW_PROJECT_ID` checks) in each file handle this correctly
11. **NOTIFICATION_STATE_MAP vs ROLL_STATE_MAP** - `ROLL_STATE_MAP` in HistoryListener_Retail maps Transmog->Greed (lossy) for history display. `ns.NOTIFICATION_STATE_MAP` in RollManager preserves Transmog as a distinct roll type for notifications
12. **Classic LOOT_HISTORY_ROLL_CHANGED timing** - May fire before roll value is assigned; ProcessClassicRollResult skips non-Pass rolls with nil roll values and relies on a later re-fire with the value
13. **Roll result dedup** - Both Retail and Classic listeners use `notifiedRollResults` tables to prevent duplicate notifications per player per drop; tables are wiped on history clear and shutdown
