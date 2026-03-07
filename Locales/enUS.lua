-------------------------------------------------------------------------------
-- enUS.lua
-- English (default) locale strings for DragonLoot
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------

local L = LibStub("AceLocale-3.0"):NewLocale("DragonLoot", "enUS", true)
if not L then return end

-- When key == value, use: L["key"] = true
-- This avoids typing the English string twice.

-------------------------------------------------------------------------------
-- Core/Init.lua
-------------------------------------------------------------------------------

L["Loaded. Type /dl help for commands."] = true

-------------------------------------------------------------------------------
-- Core/SlashCommands.lua
-------------------------------------------------------------------------------

L["--- DragonLoot Commands ---"] = true
L["/dl - Toggle addon on/off"] = true
L["/dl config - Open settings panel"] = true
L["/dl minimap - Toggle minimap icon"] = true
L["/dl enable - Enable addon"] = true
L["/dl disable - Disable addon"] = true
L["/dl reset - Reset loot frame position"] = true
L["/dl test - Show test loot"] = true
L["/dl testroll - Show test roll frames"] = true
L["/dl history - Toggle loot history"] = true
L["/dl status - Show current settings"] = true
L["/dl help - Show this help"] = true
L["--- DragonLoot Status ---"] = true
L["Yes"] = true
L["No"] = true
L["Enabled:"] = true
L["Loot Window:"] = true
L["Roll Frame:"] = true
L["History:"] = true
L["Animations:"] = true
L["Minimap Icon:"] = true
L["Addon enabled"] = true
L["Addon disabled"] = true
L["Loot frame position reset."] = true
L["Loot frame not yet available."] = true
L["Test loot not yet available."] = true
L["Test roll not yet available."] = true
L["Loot history not yet available."] = true
L["Unknown command:"] = true

-------------------------------------------------------------------------------
-- Core/MinimapIcon.lua
-------------------------------------------------------------------------------

L["Shift-click test: DragonLoot is working."] = true
L["Enabled"] = true
L["Disabled"] = true
L["Status:"] = true
L["Left-Click"] = true
L["Shift-Left-Click"] = true
L["Right-Click"] = true
L["Open settings"] = true
L["Test message"] = true
L["Toggle on/off"] = true

-------------------------------------------------------------------------------
-- Core/ConfigWindow.lua
-------------------------------------------------------------------------------

L["DragonLoot_Options addon not found. Please ensure it is installed."] = true

-------------------------------------------------------------------------------
-- Display/LootFrame.lua
-------------------------------------------------------------------------------

L["BoP"] = true
L["BoE"] = true
L["BoU"] = true
L["Quest"] = true
L["Currency"] = true
L["Money"] = true
L["iLvl"] = true
L["Loot"] = true
L["Fishing"] = true
L["Showing test loot window."] = true
L["Test slot clicked:"] = true

-------------------------------------------------------------------------------
-- Display/RollFrame.lua
-------------------------------------------------------------------------------

L["Pass"] = true
L["Need"] = true
L["Greed"] = true
L["Disenchant"] = true
L["Transmog"] = true
L["Roll"] = true
L["Not available for this item"] = true
L["Test roll:"] = true
L["Test Item"] = true
L["Test item:"] = true
L["Showing test roll frames."] = true

-------------------------------------------------------------------------------
-- Display/RollManager.lua
-------------------------------------------------------------------------------

L["Unknown"] = true

-------------------------------------------------------------------------------
-- Display/HistoryFrame.lua
-------------------------------------------------------------------------------

L["DragonLoot - Loot History"] = true
L["Clear History"] = true
L["Looted"] = true
L["Unknown Item"] = true
L["%ds ago"] = true
L["%dm ago"] = true
L["%dh ago"] = true

-------------------------------------------------------------------------------
-- DragonLoot_Options/Core.lua
-------------------------------------------------------------------------------

L["DragonLoot namespace not found."] = true

-------------------------------------------------------------------------------
-- DragonLoot_Options/Tabs - General tab
-------------------------------------------------------------------------------

L["General"] = true
L["Enable DragonLoot"] = true
L["Enable or disable the DragonLoot addon"] = true
L["Show Minimap Icon"] = true
L["Show or hide the minimap button"] = true
L["Debug Mode"] = true
L["Enable verbose debug output in chat"] = true

-------------------------------------------------------------------------------
-- DragonLoot_Options/Tabs - Loot Window tab
-------------------------------------------------------------------------------

L["Loot Window"] = true
L["Enable Custom Loot Window"] = true
L["Replace the default loot window with DragonLoot's custom frame"] = true
L["Lock Position"] = true
L["Prevent the loot window from being moved"] = true
L["Layout"] = true
L["Scale"] = true
L["Width"] = true
L["Height"] = true
L["Slot Spacing"] = true
L["Content Padding"] = true

-------------------------------------------------------------------------------
-- DragonLoot_Options/Tabs - Loot Roll tab
-------------------------------------------------------------------------------

L["Loot Roll"] = true
L["Roll Frame"] = true
L["Enable Custom Roll Frame"] = true
L["Replace the default Blizzard roll frame with DragonLoot's custom version"] = true
L["Prevent the roll frame from being dragged"] = true
L["Roll frame scale"] = true
L["Frame Width"] = true
L["Width of the roll frame"] = true
L["Row Spacing"] = true
L["Vertical spacing between roll rows"] = true
L["Timer Bar Height"] = true
L["Height of the countdown timer bar"] = true
L["Timer Bar Spacing"] = true
L["Space between item row and timer bar"] = true
L["Inner padding of the roll frame"] = true
L["Button Size"] = true
L["Size of Need/Greed/Pass buttons"] = true
L["Button Spacing"] = true
L["Spacing between roll buttons"] = true
L["Frame Spacing"] = true
L["Spacing between multiple roll frames"] = true
L["Timer Bar Texture"] = true
L["Roll Notifications"] = true
L["Show Roll Won"] = true
L["Show a notification when someone wins a roll"] = true
L["Show Group Wins"] = true
L["Show notifications when other group members win rolls"] = true
L["Show Roll Results"] = true
L["Show individual roll result notifications"] = true
L["Show My Rolls"] = true
L["Show notifications for your own roll results"] = true
L["Show Group Rolls"] = true
L["Show notifications for other group members' roll results"] = true
L["Minimum Quality"] = true
L["Instance Filters"] = true
L["Show in Open World"] = true
L["Show roll notifications while in the open world"] = true
L["Show in Dungeons"] = true
L["Show roll notifications while in dungeons"] = true
L["Show in Raids"] = true
L["Show roll notifications while in raids"] = true

-------------------------------------------------------------------------------
-- DragonLoot_Options/Tabs - History tab
-------------------------------------------------------------------------------

L["Enable History"] = true
L["Auto Show on Loot"] = true
L["Track Direct Loot"] = true
L["Track items you pick up directly (not from a loot window)"] = true
L["Max Entries"] = true
L["Entry Spacing"] = true

-------------------------------------------------------------------------------
-- DragonLoot_Options/Tabs - Auto-Loot tab
-------------------------------------------------------------------------------

L["Auto-Loot"] = true
L["Smart Auto-Loot"] = true
L["Enable Smart Auto-Loot"] = true
L["When enabled, qualifying items are automatically looted based on your filter rules"] = true
L["Whitelist"] = true
L["Blacklist"] = true
L["No items - drag items here to add"] = true
L["AUTO_LOOT_DESC"] = "Automatically loot items that meet your criteria. Items on the whitelist are always picked up. Items on the blacklist are never auto-looted. Everything else is evaluated against the minimum quality threshold."
L["WHITELIST_DESC"] = "Items on this list are always looted automatically, regardless of quality. Drag an item from your bags onto an empty slot to add it."
L["BLACKLIST_DESC"] = "Items on this list are never auto-looted, even if they meet the quality threshold. They will remain in the loot window for manual pickup."

-------------------------------------------------------------------------------
-- DragonLoot_Options/Tabs - Appearance tab
-------------------------------------------------------------------------------

L["Font"] = true
L["Font Family"] = true
L["Font Size"] = true
L["Base font size for all DragonLoot frames"] = true
L["Font Outline"] = true
L["None"] = true
L["Outline"] = true
L["Thick Outline"] = true
L["Monochrome"] = true
L["Icon Sizes"] = true
L["Loot Icon Size"] = true
L["Icon size in the loot window"] = true
L["Roll Icon Size"] = true
L["Icon size in the roll frame"] = true
L["History Icon Size"] = true
L["Icon size in the history frame"] = true
L["Quality Border"] = true
L["Show quality-colored borders on item icons"] = true
L["Slot Background"] = true
L["Gradient"] = true
L["Flat"] = true
L["Stripe"] = true
L["Background"] = true
L["Background Color"] = true
L["Background Opacity"] = true
L["Opacity of the frame background"] = true
L["Background Texture"] = true
L["Border"] = true
L["Border Color"] = true
L["Border Size"] = true
L["Thickness of the frame border"] = true
L["Border Texture"] = true

-------------------------------------------------------------------------------
-- DragonLoot_Options/Tabs - Animation tab
-------------------------------------------------------------------------------

L["Animation"] = true
L["Enable Animations"] = true
L["Enable or disable all DragonLoot animations"] = true
L["Open Duration"] = true
L["Duration of open/show animations in seconds"] = true
L["Close Duration"] = true
L["Duration of close/hide animations in seconds"] = true
L["Open Animation"] = true
L["Close Animation"] = true
L["Show Animation"] = true
L["Hide Animation"] = true

-------------------------------------------------------------------------------
-- DragonLoot_Options/Tabs - Profiles tab
-------------------------------------------------------------------------------

L["Profiles"] = true
L["PROFILES_DESC"] = "Profiles allow you to save different settings configurations. You can switch between profiles, copy settings from another profile, or reset to defaults."
L["Current Profile"] = true
L["Active Profile"] = true
L["New Profile"] = true
L["Create"] = true
L["Create a new profile with the entered name and switch to it"] = true
L["Profile Actions"] = true
L["Copy From"] = true
L["Reset Current Profile"] = true
L["Reset all settings in the current profile to their default values"] = true
L["Delete Profile"] = true
L["Are you sure you want to reset the current profile to defaults?"] = true
L["Are you sure you want to delete profile \"%s\"?"] = true

-------------------------------------------------------------------------------
-- Quality names (used in dropdowns)
-------------------------------------------------------------------------------

L["Poor"] = true
L["Common"] = true
L["Uncommon"] = true
L["Rare"] = true
L["Epic"] = true
L["Legendary"] = true
