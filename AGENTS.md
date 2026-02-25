# DragonLoot - Agent Guidelines

Project-specific guidelines for DragonLoot. See the parent `../AGENTS.md` for general WoW addon development rules.

---

## Overview

DragonLoot is a loot tracking addon for World of Warcraft.

**Status**: Scaffolding only. No Lua source files have been implemented yet.

**GitHub**: TBD

---

## Target Versions

| Version | Interface | TOC Directive |
|---------|-----------|---------------|
| Retail | 110207, 120001, 120000 | `## Interface: 110207, 120001, 120000` |
| TBC Anniversary | 20505 | `## Interface-BCC: 20505` |

Version-specific files are loaded via BigWigsMods packager comment directives (`#@retail@` / `#@tbc-anniversary@`) in the TOC.

---

## Architecture

| Layer | Directory | Responsibility |
|-------|-----------|----------------|
| Core | `Core/` | Addon lifecycle, config, slash commands |
| Engine | `Engine/` | Pure Lua logic (no WoW API) |
| Display | `Display/` | UI frames and presentation |
| Listeners | `Listeners/` | Event handling and version-specific parsing |
| Libs | `Libs/` | Embedded Ace3 + utility libraries |

### Namespace Pattern

All files use the shared private namespace:
```lua
local ADDON_NAME, ns = ...
```

---

## Placeholders

The following values are placeholders and must be updated before first release:

| Item | Placeholder | File |
|------|-------------|------|
| CurseForge Project ID | `0000000` | `DragonLoot.toc` |
| Wago ID | `TBD` | `DragonLoot.toc` |
| Icon texture | `Interface\AddOns\DragonLoot\DragonLoot_Icon` | `DragonLoot.toc` |
| GitHub URL | TBD | This file |

---

## Ace3 Stack

DragonLoot embeds Ace3 via `Libs/embeds.xml`. The full Ace3 library set is available:

| Library | Usage |
|---------|-------|
| AceAddon | Addon lifecycle |
| AceEvent | Event registration |
| AceTimer | Timers |
| AceDB | SavedVariables + profiles |
| AceConfig | Options table registration |
| AceConfigDialog | Blizzard settings integration |
| AceGUI | Standalone config window |
| AceConsole | Slash command registration |
| LibSharedMedia-3.0 | Font/texture/sound selection |
| LibDataBroker-1.1 | Data source for minimap icon |
| LibDBIcon-1.0 | Minimap button |

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

No automated tests. No Lua source files exist yet.

Once source files are added, test manually in-game:
1. Load the addon in the target game version
2. Exercise core features and slash commands
3. `/console scriptErrors 1` to catch Lua errors

---

## Known Gotchas

1. **GetItemInfo may return nil** on first call if item not cached - handle with retry timers
2. **CHAT_MSG_LOOT patterns are localized** - parsing requires Lua pattern matching on localized strings
3. **TOC conditional loading** - Mid-file `## Interface:` directives don't work. Use BigWigsMods packager comment directives (`#@retail@`, `#@tbc-anniversary@`)
4. **pull_request vs pull_request_target** - GitHub doesn't trigger `pull_request` workflows for PRs created by GITHUB_TOKEN (release-please). Use `pull_request_target` for lint workflows
