# Settings panel and live preview

The options panel uses sidebar navigation, compact paired setting rows, and a pinned preview. The preview selector switches between the loot window, roll frame, and history window. Visiting one of those settings pages selects its corresponding preview; other pages retain the selected sample. In narrow windows, the viewing-mode buttons move to a second toolbar row and the preview viewport adjusts below them.

Each display module exposes `CreatePreview(parent)`. These factories reuse the actual row constructors, fonts, backdrop helpers, and render functions with fixed sample data. Their anonymous frames belong to the settings panel. They never acquire live loot/roll/history pool entries, register gameplay events, start timers, submit loot or roll actions, or write history or saved positions. Preview buttons and item rows do not accept gameplay input.

`Refresh()` reads the active profile again and redraws the existing sample frames. The shared DragonWidgets panel schedules updates after widget changes, profile refreshes, tab changes, and panel resizing. It coalesces refreshes while visible. Selecting a preview only changes controller state; the shared widget event schedules its redraw.

Samples retain configured dimensions, including minimum loot-window height. **Actual size** is the default: it uses the configured scale and clips the top-aligned sample within the preview area, keeping text readable at normal settings. **Fit** scales the complete sample down to fit and never enlarges above 100%. The caption shows dimensions, rendered scale, and whether the sample is clipped. These viewing choices never change the saved settings. Mouse-wheel input remains available to the settings panel. Disabled features remain previewable and are labeled as disabled. Preview animation playback is intentionally absent; animation settings still control the real addon displays.

Profile callbacks register when the options addon loads, before the Profiles page is opened. Visible widgets reread their getters, and affected tabs recompute dependent disabled controls. Manual button/input rows use the same layout registration as the other widgets.

## Verification

Run `busted --verbose` and `luacheck .`. Preview tests use the real display constructors and renderers with recording frame primitives. Timer, item-query, loot, and roll APIs fail immediately if a preview touches them. Tests verify sample ownership, absent gameplay handlers, unchanged profile/history data, reuse on redraw, current appearance settings, tab selection, Actual size/Fit behavior, and profile-dependent disabled states.

In game, use `/dl config`. Check all preview choices, sliders and dropdowns, profile switching before opening Profiles, narrow/UI-scaled layouts, and enabled/disabled controls. Confirm an active loot window, roll, and history list remain independent of opening or closing settings. No in-game rendering verification was available during implementation.
