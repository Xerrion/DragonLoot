# DragonLoot Copilot review instructions

## About this project

- DragonLoot is a World of Warcraft addon written for Lua 5.1.
- It targets three flavors: Retail (Midnight, interface 120005), MoP Classic (Mists, 50503), and TBC Anniversary (BCC, 20505). Use `WOW_PROJECT_ID` and explicit interface checks for version-specific code.

## Lua conventions

- Do not use `require`. Load libraries with `LibStub("LibName-X.Y")`.
- Flag Lua 5.2+ syntax or APIs, including `_ENV`, `goto`, `table.pack`, `table.unpack`, `bit32`, and `//`.
- Each Lua file starts with the standard header: 80 hyphens, filename, one-line description, blank line, `-- Supported versions: ...`, then `local ADDON_NAME, ns = ...`.
- Keep addon state in `ns`; only `DragonLootDB` and `SLASH_DRAGONLOOT1/2` should be real globals.
- Naming: PascalCase files and functions, camelCase locals, UPPER_SNAKE_CASE module constants.
- Use 4 spaces, no tabs, double quotes, Unix line endings, and 120-character lines. `Locales/*.lua` is exempt from the line-length rule.

## WoW API patterns

- Cache WoW API globals and Lua globals as locals at file top, for example `local GetTime = GetTime`.
- Do not rely on TOC packager directives for runtime safety. Locally, all version-specific files load because directives are comments.
- Use BigWigsMods packager directives in TOC files for flavor-specific loading, for example `#@retail@` ... `#@end-retail@`. Never add `## Interface:` mid-TOC to gate files.
- Guard version-specific logic with `WOW_PROJECT_ID` checks and explicit API availability checks where needed.

## AceLocale pattern

- Locale keys are full English sentences, not short symbolic keys.
- Base `enUS` files use `LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "enUS", true, true)` and `L["Full English sentence"] = true`.
- Other locale files use `NewLocale(ADDON_NAME, "locale")` and set translated string values.
- In options code, prefer `local L = ns.L` after `Core.lua` exposes the main addon's locale.

## Critical gotchas

- Retail Midnight 12.0+ removes addon access to `COMBAT_LOG_EVENT_UNFILTERED`; `CombatLogGetCurrentEventInfo()` can return obfuscated values. Flag new CLEU parsing in retail-targeted code. Prefer `UNIT_SPELLCAST_INTERRUPT`, `UNIT_SPELLCAST_SUCCEEDED`, `UNIT_AURA`, `C_UnitAuras`, and `C_Spell` APIs.
- Ace3 `AceEvent30Frame` is a shared named global frame. Taint from one addon can affect all AceEvent consumers. Flag `addon:RegisterEvent` for high-traffic or sensitive events; prefer a private unnamed `CreateFrame("Frame")` for those registrations.

## DragonLoot specifics

- Config writes must match the AceDB schema under `db.profile.appearance`, `db.profile.history`, `db.profile.lootWindow`, `db.profile.rollFrame`, `db.profile.notifications`, `db.profile.autoLoot`, or `db.profile.animation`.
- Inter-addon messaging goes through `ns.MessageBridge` over AceComm. Treat messages as fire-and-forget and do not add hard dependencies on DragonToast or other addons.
- Retail and Classic loot APIs differ. Check tuple sizes and field names before approving shared listener code.
- If code suppresses Blizzard loot frames or events, verify it restores them on disable, shutdown, and error paths that leave the custom UI closed.
- Fetch roll item data before `CancelRoll`; the data is unavailable after canceling.

## Verification

- `just check` is the local gate; it runs `stylua --check`, `luacheck`, and `busted`.
- Code should pass all three checks without new warnings or failing tests.
- Do not flag long `L[...]` locale-key bracket lines solely because StyLua cannot wrap inside them.

## Commit and PR conventions

- Commit subjects use conventional prefixes: `feat:`, `fix:`, `chore:`, `style:`, `refactor:`, `test:`, `docs:`, or `ci:`.
- Reference issues as `(#123)` when present.
- The default branch is `master`; PRs are squash-merged.
