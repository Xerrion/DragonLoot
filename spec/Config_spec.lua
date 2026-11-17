-------------------------------------------------------------------------------
-- Config_spec.lua
-- Tests for Config.lua schema migration via ns.InitializeDB
-------------------------------------------------------------------------------

local mock = require("spec.wow_mock")

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, child in pairs(value) do
        result[key] = Copy(child)
    end
    return result
end

local modernVisuals = {
    appearance = {
        font = "Dragon UI",
        fontOutline = "",
        fontShadow = false,
        slotBackground = "flat",
        backgroundColor = { r = 0.035, g = 0.047, b = 0.065 },
        backgroundAlpha = 0.98,
        backgroundTexture = "Solid",
        borderColor = { r = 0.22, g = 0.28, b = 0.35 },
        borderSize = 1,
        borderTexture = "Dragon UI",
    },
    rollFrame = {
        timerBarTexture = "Dragon UI",
        timerBarBorderColor = { r = 0.22, g = 0.28, b = 0.35 },
        timerBarColorMode = "custom",
        timerBarColor = { r = 0.28, g = 0.83, b = 0.73 },
        timerBarBackgroundColor = { r = 0.065, g = 0.085, b = 0.115 },
        timerBarBackgroundAlpha = 1,
    },
    lootWindow = {
        qualityGlow = false,
        backgroundIntensity = 1,
    },
}

describe("Config", function()
    local ns

    before_each(function()
        mock.Reset()
        ns = mock.CreateNamespace()
    end)

    -- Helper: load Config.lua and run InitializeDB on a mock addon
    local function initWithSeed(currentNs, profileSeed)
        mock._profileSeed = profileSeed
        mock.LoadConfig(currentNs)
        local addon = { db = nil }
        currentNs.InitializeDB(addon)
        return addon.db
    end

    ---------------------------------------------------------------------------
    -- Fresh profile (all defaults)
    ---------------------------------------------------------------------------

    describe("fresh profile", function()
        it("has all default keys after InitializeDB", function()
            local db = initWithSeed(ns, nil)

            assert.is_true(db.profile.enabled)
            assert.is_true(db.profile.showLoginMessage)
            assert.are.equal(1.0, db.profile.lootWindow.scale)
            assert.are.equal(12, db.profile.rollFrame.timerBarHeight)
            assert.are.equal("Dragon UI", db.profile.appearance.font)
            assert.are.equal(100, db.profile.history.maxEntries)
        end)

        it("uses modern visual defaults without changing text or icon sizes", function()
            local db = initWithSeed(ns, nil)
            for section, fields in pairs(modernVisuals) do
                for key, value in pairs(fields) do
                    assert.are.same(value, db.profile[section][key])
                end
            end
            assert.are.equal(12, db.profile.appearance.fontSize)
            assert.are.equal(36, db.profile.appearance.lootIconSize)
            assert.are.equal(36, db.profile.appearance.rollIconSize)
            assert.are.equal(24, db.profile.appearance.historyIconSize)
            assert.is_true(db.profile.appearance.qualityBorder)
            assert.is_true(db.profile.appearance.showItemLevel)
        end)

        it("sets schemaVersion to current schema", function()
            local db = initWithSeed(ns, nil)

            -- Keep in sync with CURRENT_SCHEMA in DragonLoot/Core/Config.lua
            assert.are.equal(8, db.profile.schemaVersion)
        end)

        it("has lootIconSize in a fresh profile", function()
            local db = initWithSeed(ns, nil)

            assert.is_not_nil(db.profile.appearance.lootIconSize)
            assert.are.equal(36, db.profile.appearance.lootIconSize)
        end)

        it("defaults rollFrame.autoConfirmRolls to false (opt-in)", function()
            local db = initWithSeed(ns, nil)

            assert.is_false(db.profile.rollFrame.autoConfirmRolls)
        end)

        it("defaults rollFrame.confirmGreedAndPass to false (opt-in)", function()
            local db = initWithSeed(ns, nil)

            assert.is_false(db.profile.rollFrame.confirmGreedAndPass)
        end)

        it("defaults rollFrame.keepOpenAfterVote to false (opt-in)", function()
            local db = initWithSeed(ns, nil)

            assert.is_false(db.profile.rollFrame.keepOpenAfterVote)
        end)

        it("defaults rollFrame.resultLingerDuration to 3 seconds", function()
            local db = initWithSeed(ns, nil)

            assert.are.equal(3, db.profile.rollFrame.resultLingerDuration)
        end)

        it("defaults rollFrame.showRollTally to false (opt-in)", function()
            local db = initWithSeed(ns, nil)

            assert.is_false(db.profile.rollFrame.showRollTally)
        end)

        it("defaults rollFrame.reverseButtonOrder to false", function()
            local db = initWithSeed(ns, nil)

            assert.is_false(db.profile.rollFrame.reverseButtonOrder)
        end)
    end)

    ---------------------------------------------------------------------------
    -- FillMissingDefaults (tested through InitializeDB)
    ---------------------------------------------------------------------------

    describe("FillMissingDefaults", function()
        it("preserves explicit legacy styling while filling missing fields with modern defaults", function()
            local seed = {
                schemaVersion = 7,
                appearance = {
                    font = "Friz Quadrata TT",
                    fontOutline = "OUTLINE",
                    fontShadow = true,
                    slotBackground = "gradient",
                    backgroundColor = { r = 0.05, g = 0.05, b = 0.05 },
                    backgroundAlpha = 0.9,
                    borderColor = { r = 0.3, g = 0.3, b = 0.3 },
                    borderTexture = "None",
                },
                rollFrame = {
                    timerBarTexture = "Blizzard",
                    timerBarColorMode = "gradient",
                    timerBarColor = { r = 0, g = 1, b = 0 },
                    timerBarBackgroundColor = { r = 0.1, g = 0.1, b = 0.1 },
                    timerBarBackgroundAlpha = 0.8,
                },
                lootWindow = { qualityGlow = true, backgroundIntensity = 0.3 },
            }
            local db = initWithSeed(ns, Copy(seed))
            for _, section in ipairs({ "appearance", "rollFrame", "lootWindow" }) do
                for key, value in pairs(seed[section]) do
                    assert.are.same(value, db.profile[section][key])
                end
            end
            assert.are.same(modernVisuals.rollFrame.timerBarBorderColor, db.profile.rollFrame.timerBarBorderColor)
            assert.are.equal(1, db.profile.appearance.borderSize)
        end)

        it("adds presentation defaults to schema 7 without replacing saved appearance or positions", function()
            local db = initWithSeed(ns, {
                schemaVersion = 7,
                lootWindow = { width = 410, x = 87, y = -43 },
                appearance = { lootIconSize = 42, rollIconSize = 50, historyIconSize = 30, showItemLevel = false },
                history = { maxEntries = 65 },
            })
            assert.are.equal(410, db.profile.lootWindow.width)
            assert.are.equal(87, db.profile.lootWindow.x)
            assert.are.equal(-43, db.profile.lootWindow.y)
            assert.is_true(db.profile.lootWindow.showDetails)
            assert.is_true(db.profile.lootWindow.showQuantity)
            assert.is_false(db.profile.lootWindow.qualityGlow)
            assert.are.equal(1, db.profile.lootWindow.backgroundIntensity)
            assert.are.equal(350, db.profile.history.width)
            assert.are.equal(400, db.profile.history.height)
            assert.are.equal(1, db.profile.history.scale)
            assert.is_true(db.profile.history.showTimestamp)
            assert.are.equal(65, db.profile.history.maxEntries)
            assert.is_true(db.profile.rollFrame.showTimerText)
            assert.are.equal(42, db.profile.appearance.lootIconSize)
            assert.are.equal(50, db.profile.appearance.rollIconSize)
            assert.are.equal(30, db.profile.appearance.historyIconSize)
            assert.is_false(db.profile.appearance.showItemLevel)
        end)

        it("preserves customized presentation values through migration", function()
            local db = initWithSeed(ns, {
                schemaVersion = 7,
                lootWindow = {
                    showDetails = false,
                    showQuantity = false,
                    qualityGlow = false,
                    -- Zero intensity is an intentional choice, not a missing value.
                    backgroundIntensity = 0,
                },
                history = { width = 620, height = 510, scale = 1.4, showTimestamp = false },
                rollFrame = { showTimerText = false },
            })
            assert.is_false(db.profile.lootWindow.showDetails)
            assert.is_false(db.profile.lootWindow.showQuantity)
            assert.is_false(db.profile.lootWindow.qualityGlow)
            assert.are.equal(0, db.profile.lootWindow.backgroundIntensity)
            assert.are.equal(620, db.profile.history.width)
            assert.are.equal(510, db.profile.history.height)
            assert.are.equal(1.4, db.profile.history.scale)
            assert.is_false(db.profile.history.showTimestamp)
            assert.is_false(db.profile.rollFrame.showTimerText)
        end)

        it("back-fills missing showLoginMessage with true", function()
            local db = initWithSeed(ns, {
                schemaVersion = 6,
            })

            assert.is_true(db.profile.showLoginMessage)
        end)

        it("preserves an opted-out showLoginMessage", function()
            local db = initWithSeed(ns, {
                schemaVersion = 6,
                showLoginMessage = false,
            })

            assert.is_false(db.profile.showLoginMessage)
        end)

        it("resets a wrong-type showLoginMessage to true", function()
            local db = initWithSeed(ns, {
                schemaVersion = 6,
                showLoginMessage = "bad",
            })

            assert.is_true(db.profile.showLoginMessage)
        end)

        it("back-fills missing rollFrame.frameWidth", function()
            local db = initWithSeed(ns, {
                rollFrame = {
                    enabled = true,
                    -- frameWidth intentionally missing
                },
            })

            assert.are.equal(328, db.profile.rollFrame.frameWidth)
        end)

        it("resets wrong-type timerBarHeight to default number", function()
            local db = initWithSeed(ns, {
                rollFrame = {
                    timerBarHeight = "bad",
                },
            })

            assert.are.equal(12, db.profile.rollFrame.timerBarHeight)
        end)

        it("preserves valid non-default history.maxEntries", function()
            local db = initWithSeed(ns, {
                history = {
                    maxEntries = 50,
                },
            })

            assert.are.equal(50, db.profile.history.maxEntries)
        end)

        it("back-fills missing rollFrame.autoConfirmRolls with false", function()
            local db = initWithSeed(ns, {
                rollFrame = {
                    enabled = true,
                    -- autoConfirmRolls intentionally missing
                },
            })

            assert.is_false(db.profile.rollFrame.autoConfirmRolls)
        end)

        it("preserves an opted-in rollFrame.autoConfirmRolls", function()
            local db = initWithSeed(ns, {
                rollFrame = {
                    autoConfirmRolls = true,
                },
            })

            assert.is_true(db.profile.rollFrame.autoConfirmRolls)
        end)

        it("back-fills missing rollFrame.confirmGreedAndPass with false", function()
            local db = initWithSeed(ns, {
                schemaVersion = 4,
                rollFrame = {
                    enabled = true,
                },
            })

            assert.is_false(db.profile.rollFrame.confirmGreedAndPass)
        end)

        it("preserves an opted-in rollFrame.confirmGreedAndPass", function()
            local db = initWithSeed(ns, {
                schemaVersion = 4,
                rollFrame = {
                    confirmGreedAndPass = true,
                },
            })

            assert.is_true(db.profile.rollFrame.confirmGreedAndPass)
        end)

        it("back-fills missing rollFrame.keepOpenAfterVote and resultLingerDuration", function()
            local db = initWithSeed(ns, {
                rollFrame = {
                    enabled = true,
                    -- keepOpenAfterVote and resultLingerDuration intentionally missing
                },
            })

            assert.is_false(db.profile.rollFrame.keepOpenAfterVote)
            assert.are.equal(3, db.profile.rollFrame.resultLingerDuration)
        end)

        it("preserves an opted-in rollFrame.keepOpenAfterVote and custom linger", function()
            local db = initWithSeed(ns, {
                rollFrame = {
                    keepOpenAfterVote = true,
                    resultLingerDuration = 7,
                },
            })

            assert.is_true(db.profile.rollFrame.keepOpenAfterVote)
            assert.are.equal(7, db.profile.rollFrame.resultLingerDuration)
        end)

        it("resets a wrong-type resultLingerDuration to the default number", function()
            local db = initWithSeed(ns, {
                rollFrame = {
                    resultLingerDuration = "bad",
                },
            })

            assert.are.equal(3, db.profile.rollFrame.resultLingerDuration)
        end)

        it("back-fills missing rollFrame.showRollTally with false", function()
            local db = initWithSeed(ns, {
                rollFrame = {
                    enabled = true,
                    -- showRollTally intentionally missing
                },
            })

            assert.is_false(db.profile.rollFrame.showRollTally)
        end)

        it("preserves an opted-in rollFrame.showRollTally", function()
            local db = initWithSeed(ns, {
                rollFrame = {
                    showRollTally = true,
                },
            })

            assert.is_true(db.profile.rollFrame.showRollTally)
        end)

        it("back-fills missing rollFrame.reverseButtonOrder with false", function()
            local db = initWithSeed(ns, {
                schemaVersion = 5,
                rollFrame = {
                    enabled = true,
                },
            })

            assert.is_false(db.profile.rollFrame.reverseButtonOrder)
        end)

        it("preserves an opted-in rollFrame.reverseButtonOrder", function()
            local db = initWithSeed(ns, {
                schemaVersion = 5,
                rollFrame = {
                    reverseButtonOrder = true,
                },
            })

            assert.is_true(db.profile.rollFrame.reverseButtonOrder)
        end)
    end)

    ---------------------------------------------------------------------------
    -- MigrateProfile: borderTexture fix
    ---------------------------------------------------------------------------

    describe("borderTexture migration", function()
        it("replaces the invalid Solid border with the current default", function()
            local db = initWithSeed(ns, {
                appearance = {
                    borderTexture = "Solid",
                },
            })

            assert.are.equal("Dragon UI", db.profile.appearance.borderTexture)
        end)
    end)

    describe("ApplyModernStyle", function()
        it("changes only preset visual fields and refreshes live displays", function()
            local db = initWithSeed(ns, {
                enabled = false,
                minimap = { hide = true },
                lootWindow = {
                    width = 420,
                    scale = 1.4,
                    x = 81,
                    y = -33,
                    showDetails = false,
                    backgroundIntensity = 0.4,
                },
                history = { width = 620, height = 510, scale = 1.2, maxEntries = 50, showTimestamp = false },
                autoLoot = { enabled = true, minQuality = 3, whitelist = { [123] = true } },
                rollNotifications = { showGroupWins = false, minQuality = 4 },
                animation = { enabled = false, openDuration = 0.8, lootOpenAnim = "none" },
                appearance = {
                    font = "Custom font",
                    fontSize = 18,
                    fontOutline = "THICKOUTLINE",
                    fontShadow = true,
                    lootIconSize = 48,
                    rollIconSize = 54,
                    historyIconSize = 32,
                    qualityBorder = false,
                    showItemLevel = false,
                    slotBackground = "stripe",
                    backgroundColor = { r = 0.8, g = 0.1, b = 0.2 },
                    backgroundAlpha = 0.45,
                    backgroundTexture = "Custom background",
                    borderColor = { r = 1, g = 0, b = 0 },
                    borderSize = 3,
                    borderTexture = "Custom border",
                    extensionData = { untouched = true },
                },
                rollFrame = {
                    frameWidth = 470,
                    scale = 1.3,
                    x = 201,
                    y = 95,
                    autoConfirmRolls = true,
                    reverseButtonOrder = true,
                    timerBarStyle = "minimal",
                    timerBarHeight = 20,
                    timerBarBorder = true,
                    showTimerText = false,
                    timerBarTexture = "Custom timer",
                    timerBarBorderColor = { r = 1, g = 0, b = 0 },
                    timerBarColorMode = "gradient",
                    timerBarColor = { r = 1, g = 0, b = 0 },
                    timerBarBackgroundColor = { r = 1, g = 0, b = 0 },
                    timerBarBackgroundAlpha = 0.3,
                },
                extensionData = { untouched = true },
            })
            ns.Addon.db = db
            db.char = { history = { entries = { { itemLink = "stored loot" } } } }
            local savedHistory = Copy(db.char)
            local expected = Copy(db.profile)
            for section, fields in pairs(modernVisuals) do
                for key, value in pairs(fields) do
                    expected[section][key] = Copy(value)
                end
            end
            local calls = {}
            for _, module in ipairs({ "LootFrame", "RollManager", "HistoryFrame" }) do
                ns[module] = {
                    ApplySettings = function()
                        calls[#calls + 1] = module
                    end,
                }
            end

            ns.ApplyModernStyle()

            assert.are.same(expected, db.profile)
            assert.are.same(savedHistory, db.char)
            assert.are.same({ "LootFrame", "RollManager", "HistoryFrame" }, calls)
        end)

        it("copies palette tables independently on every application", function()
            local db = initWithSeed(ns, nil)
            ns.Addon.db = db
            ns.ApplyModernStyle()
            local firstBackground = db.profile.appearance.backgroundColor
            local firstTimer = db.profile.rollFrame.timerBarColor
            firstBackground.r = 1
            firstTimer.g = 0

            ns.ApplyModernStyle()

            assert.are_not.equal(firstBackground, db.profile.appearance.backgroundColor)
            assert.are_not.equal(firstTimer, db.profile.rollFrame.timerBarColor)
            assert.are.same(modernVisuals.appearance.backgroundColor, db.profile.appearance.backgroundColor)
            assert.are.same(modernVisuals.rollFrame.timerBarColor, db.profile.rollFrame.timerBarColor)
            mock._profileSeed = nil
            local freshAddon = {}
            ns.InitializeDB(freshAddon)
            assert.are.same(modernVisuals.appearance.backgroundColor, freshAddon.db.profile.appearance.backgroundColor)
            assert.are.same(modernVisuals.rollFrame.timerBarColor, freshAddon.db.profile.rollFrame.timerBarColor)
        end)
    end)

    ---------------------------------------------------------------------------
    -- MigrateProfile: iconSize split
    ---------------------------------------------------------------------------

    describe("iconSize split migration", function()
        it("clears old iconSize field after migration", function()
            local db = initWithSeed(ns, {
                appearance = {
                    iconSize = 48,
                },
            })

            -- FillMissingDefaults runs first and fills lootIconSize/rollIconSize
            -- with defaults (36), so iconSize=48 does NOT propagate. The old
            -- iconSize field is cleared regardless.
            assert.is_nil(db.profile.appearance.iconSize)
            assert.are.equal(36, db.profile.appearance.lootIconSize)
            assert.are.equal(36, db.profile.appearance.rollIconSize)
        end)

        it("preserves existing lootIconSize when iconSize is also present", function()
            local db = initWithSeed(ns, {
                appearance = {
                    iconSize = 48,
                    lootIconSize = 42,
                    rollIconSize = 44,
                },
            })

            -- Existing values survive: FillMissingDefaults does not overwrite
            -- them (they're not nil), and iconSize migration skips them too.
            assert.are.equal(42, db.profile.appearance.lootIconSize)
            assert.are.equal(44, db.profile.appearance.rollIconSize)
            assert.is_nil(db.profile.appearance.iconSize)
        end)

        it(
            "copies iconSize to lootIconSize when lootIconSize is absent (skips FillMissingDefaults at current schema)",
            function()
                local db = initWithSeed(ns, {
                    -- Seed at current schema so FillMissingDefaults is skipped and the
                    -- (unconditional) iconSize-split migration can propagate iconSize=48.
                    -- Keep in sync with CURRENT_SCHEMA in DragonLoot/Core/Config.lua.
                    schemaVersion = 8,
                    appearance = {
                        iconSize = 48,
                        -- lootIconSize intentionally absent to test migration propagation
                    },
                })

                assert.are.equal(48, db.profile.appearance.lootIconSize)
                assert.is_nil(db.profile.appearance.iconSize)
            end
        )
    end)

    ---------------------------------------------------------------------------
    -- Schema version
    ---------------------------------------------------------------------------

    describe("schemaVersion", function()
        it("is set to current schema after migration from version 0", function()
            local db = initWithSeed(ns, {
                -- schemaVersion intentionally missing (defaults to 0)
            })

            -- Keep in sync with CURRENT_SCHEMA in DragonLoot/Core/Config.lua
            assert.are.equal(8, db.profile.schemaVersion)
        end)
    end)
end)
