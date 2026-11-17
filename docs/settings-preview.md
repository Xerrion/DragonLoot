# Settings panel and live preview

The options panel uses sidebar navigation, compact paired setting rows, and a pinned preview. The preview selector switches between the loot window, roll frame, and history window. Visiting one of those settings pages selects its corresponding preview; other pages retain the selected sample. In narrow windows, the viewing-mode buttons move to a second toolbar row and the preview viewport adjusts below them.

Each display module exposes `CreatePreview(parent)`. These factories reuse the actual row constructors, fonts, backdrop helpers, and render functions with fixed sample data. Their anonymous frames belong to the settings panel. They never acquire live loot/roll/history pool entries, register gameplay events, start timers, submit loot or roll actions, or write history or saved positions. Preview buttons and item rows do not accept gameplay input.

`Refresh()` reads the active profile again and redraws the existing sample frames. The shared DragonWidgets panel schedules updates after widget changes, profile refreshes, tab changes, and panel resizing. It coalesces refreshes while visible. Selecting a preview only changes controller state; the shared widget event schedules its redraw.

Samples retain configured dimensions, including minimum loot-window height. **Actual size** is the default: it uses the configured scale and clips the top-aligned sample within the preview area, keeping text readable at normal settings. **Fit** scales the complete sample down to fit and never enlarges above 100%. The caption shows dimensions, rendered scale, and whether the sample is clipped. These viewing choices never change the saved settings. Mouse-wheel input remains available to the settings panel. Disabled features remain previewable and are labeled as disabled. Preview animation playback is intentionally absent; animation settings still control the real addon displays.

Profile callbacks register when the options addon loads, before the Profiles page is opened. Visible widgets reread their getters, and affected tabs recompute dependent disabled controls. Manual button/input rows use the same layout registration as the other widgets.

## Customization and organization

The goal is to give actual loot, roll, and history displays a modern default appearance and let players adjust their size and information density while seeing the result immediately. Existing saved keys, explicit styling choices, loot/roll actions, and persisted history are contracts. The old default appearance and the grouping of every icon-size control on Appearance were inherited choices. Default styling now changes deliberately, and feature-specific controls move to their corresponding pages without changing their saved keys.

The sidebar orders General, Loot Window, Roll Frame, History, Appearance, Animation, Auto-Loot, Notifications, and Profiles. Feature pages put dimensions and spacing together, then content and style, then behavior. Test and destructive actions have separate sections at the end. Shared typography, icon borders, backgrounds, and borders remain on Appearance.

| Page | New setting | Default |
| --- | --- | --- |
| Loot Window | Show Item Details | On |
| Loot Window | Show Stack Counts | On |
| Loot Window | Quality Glow | Off; can enable it for Rare and better items |
| Loot Window | Background Intensity | 100% of the existing style's opacity |
| Roll Frame | Show Timer Text | On; minimal bars always hide text |
| History | Width | 350 |
| History | Height | 400 |
| History | Scale | 1 |
| History | Show Timestamps | On |

Schema 8 fills missing settings and preserves existing values, including frame positions and the original icon-size/item-level keys. Background intensity is unavailable when Slot Background is None, timer text is unavailable for minimal bars, and feature-specific controls follow their master enable switch. Hiding timestamps only changes their display and releases the reserved item-name space; it does not remove stored times.

## Modern display style

Core display utilities own the palette and media registration, so live windows do not depend on the load-on-demand DragonWidgets library. Defaults use dark blue-gray panels at 98% opacity, crisp borders, a slightly lighter title surface, neutral primary/muted text, teal accents, flat quality highlights without an icon halo, and a flat teal roll timer. Rarity-colored item names/borders, quest gold, class colors, and bind warnings retain their meaning. The addon-owned title bars, close buttons, History clear button, and scrollbar use the same simple surfaces in live windows and previews.

Loot and History share a 24-pixel header with a left-aligned title, matching text padding and close-button placement, a teal accent, and a full-width separator. History reserves space for its Clear button beside Close. Header refresh follows the configured font and border width without moving content, changing saved geometry, or reanchoring live History scrolling from a preview.

The `Dragon UI` font resolves from `ChatFontSmall:GetFont()`, then `STANDARD_TEXT_FONT`, then the old Friz fallback. It registers with LibSharedMedia's all-language mask. The default removes outlines and shadows, while existing font choices remain selectable. `Dragon UI` also registers a flat white-pixel border and status-bar texture.

Existing explicit values are never automatically replaced merely because they resemble old defaults; the code cannot reliably distinguish a deliberate choice from an old saved default. **Appearance → Apply Modern Style** explicitly applies the visual preset and refreshes live windows, controls, and previews. It changes font family/outline/shadow, frame background/border styling, row highlights/glow, and timer colors/textures. It preserves font size, icon sizes, dimensions, scale, positions, content switches, filters, history, animation behavior, and feature enablement. Missing fields and newly created/reset profiles use the modern defaults.

The implementation keeps the history row-edge anchoring fixes, compact roll anchoring, quest-item gold border overrides, and Classic-only tally guards. Quest borders now also survive settings changes while the loot window is open. Preview cleanup checks `HasScript` before clearing handlers because native Frames do not accept Button-only scripts such as `OnClick`.

## Verification

Run `busted --verbose` and `luacheck .`. Preview tests use the real display constructors and renderers with recording frame primitives. Timer, item-query, loot, and roll APIs fail immediately if a preview touches them. Tests verify sample ownership, absent gameplay handlers, unchanged profile/history data, reuse on redraw, current appearance settings, tab selection, Actual size/Fit behavior, and profile-dependent disabled states. Separate live-display tests verify changes to already-visible windows, retained quest borders, timer-text gating, and history sizing without position or persistence writes. Modern-style tests cover locale font fallback, registration masks, intentional defaults, live/preview parity, and the preset's restricted mutation scope. Migration and options tests cover existing values, moved bindings, and dependencies after profile replacement.

In game, use `/dl config`. Check all preview choices, sliders and dropdowns, profile switching before opening Profiles, narrow/UI-scaled layouts, and enabled/disabled controls. Confirm an active loot window, roll, and history list remain independent of opening or closing settings. No in-game rendering verification was available during implementation.
