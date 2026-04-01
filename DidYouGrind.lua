-- =========================================
-- DidYouGrind - lightweight weekly tracker
-- =========================================

local addonName = ...
local eventFrame = CreateFrame("Frame")

-- =========================================
-- DATABASE DEFAULTS
-- =========================================

local defaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    width = 420,
    height = 320,
    minimized = false,
    startMinimized = false,
    autoRefresh = true,
    compactMode = false,
    locked = false,
    weeklyBossDebug = false,
    showSections = {
        keys = true,
        dawncrests = true,
        weeklyboss = true,
        greatvault = true,
        raids = true,
        dungeons = true,
        world = true,
    },
    collapsed = {
        keys = false,
        dawncrests = false,
        weeklyboss = false,
        greatvault = false,
        raids = false,
        dungeons = true,
        world = false,
    },
}

local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then
        dst = {}
    end

    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end

    return dst
end

-- =========================================
-- MAIN FRAME
-- =========================================

local mainFrame = CreateFrame("Frame", "DidYouGrindFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(420, 320)
mainFrame:SetResizable(true)
if mainFrame.SetResizeBounds then
    mainFrame:SetResizeBounds(320, 160, 900, 900)
end
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetClampedToScreen(true)

mainFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = {
        left = 2,
        right = 2,
        top = 2,
        bottom = 2
    }
})

mainFrame:SetBackdropColor(0, 0, 0, 0.92)

mainFrame:SetScript("OnDragStart", function(self)
    if DidYouGrindDB and DidYouGrindDB.locked then
        return
    end
    self:StartMoving()
end)

mainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    local point, _, relativePoint, x, y = self:GetPoint()
    DidYouGrindDB.point = point
    DidYouGrindDB.relativePoint = relativePoint
    DidYouGrindDB.x = x
    DidYouGrindDB.y = y
end)

-- Resize handle
local resizeButton = CreateFrame("Button", nil, mainFrame)
resizeButton:SetSize(16, 16)
resizeButton:SetPoint("BOTTOMRIGHT", -4, 4)
resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

resizeButton:SetScript("OnMouseDown", function()
    if DidYouGrindDB and DidYouGrindDB.locked then
        return
    end
    mainFrame:StartSizing("BOTTOMRIGHT")
end)

resizeButton:SetScript("OnMouseUp", function()
    mainFrame:StopMovingOrSizing()
    DidYouGrindDB.width = mainFrame:GetWidth()
    DidYouGrindDB.height = mainFrame:GetHeight()
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

-- =========================================
-- HEADER
-- =========================================

mainFrame.icon = mainFrame:CreateTexture(nil, "ARTWORK")
mainFrame.icon:SetSize(20, 20)
mainFrame.icon:SetPoint("TOPLEFT", 8, -8)
mainFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")

local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -8)
title:SetText("|cff00ff99DidYouGrind|r")

local subtitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOP", 0, -30)
subtitle:SetText("|cffaaaaaa(Probably not)|r")

local minimizeButton = CreateFrame("Button", nil, mainFrame)
minimizeButton:SetSize(22, 22)
minimizeButton:SetPoint("TOPRIGHT", -8, -8)

minimizeButton.text = minimizeButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
minimizeButton.text:SetAllPoints()
minimizeButton.text:SetJustifyH("CENTER")
minimizeButton.text:SetJustifyV("MIDDLE")

local configButton = CreateFrame("Button", nil, mainFrame)
configButton:SetSize(22, 22)
configButton:SetPoint("TOPRIGHT", -32, -8)

configButton.icon = configButton:CreateTexture(nil, "ARTWORK")
configButton.icon:SetSize(16, 16)
configButton.icon:SetPoint("CENTER", 0, 0)
configButton.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
configButton.icon:SetVertexColor(0.85, 0.90, 0.95, 1)

configButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

local configPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
configPanel:SetSize(210, 270)
configPanel:SetPoint("TOPRIGHT", -8, -34)
configPanel:SetFrameStrata("DIALOG")
configPanel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = {
        left = 2,
        right = 2,
        top = 2,
        bottom = 2
    }
})
configPanel:SetBackdropColor(0, 0, 0, 0.95)
configPanel:Hide()

local configTitle = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
configTitle:SetPoint("TOPLEFT", 10, -10)
configTitle:SetText("|cffd7dde4Settings|r")

local sectionTitle = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sectionTitle:SetPoint("TOPLEFT", 10, -88)
sectionTitle:SetText("|cff9fb0c0Sections|r")

local function CreateConfigCheckbox(parent, text, y)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetPoint("TOPLEFT", 10, y)

    check.label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.label:SetJustifyH("LEFT")
    check.label:SetText(text)

    return check
end

local lockCheck = CreateConfigCheckbox(configPanel, "Lock frame", -28)
local startMinimizedCheck = CreateConfigCheckbox(configPanel, "Start minimized", -48)
local autoRefreshCheck = CreateConfigCheckbox(configPanel, "Auto refresh", -68)
local compactModeCheck = CreateConfigCheckbox(configPanel, "Compact mode", -108)

local showKeysCheck = CreateConfigCheckbox(configPanel, "Show Keys", -128)
local showDawncrestsCheck = CreateConfigCheckbox(configPanel, "Show Dawncrests", -148)
local showWeeklyBossCheck = CreateConfigCheckbox(configPanel, "Show Weekly Boss", -168)
local showGreatVaultCheck = CreateConfigCheckbox(configPanel, "Show Great Vault", -188)
local showRaidsCheck = CreateConfigCheckbox(configPanel, "  - Raids", -208)
local showDungeonsCheck = CreateConfigCheckbox(configPanel, "  - Dungeons", -228)
local showWorldCheck = CreateConfigCheckbox(configPanel, "  - World / Delves", -248)

-- =========================================
-- SCROLL AREA
-- =========================================

local scrollFrame = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -56)
scrollFrame:SetPoint("BOTTOMRIGHT", -28, 10)

local contentFrame = CreateFrame("Frame", nil, scrollFrame)
contentFrame:SetSize(1, 1)
scrollFrame:SetScrollChild(contentFrame)

-- =========================================
-- UI HELPERS
-- =========================================

local function CreateDivider(parent)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetHeight(1)
    tex:SetColorTexture(1, 1, 1, 0.10)
    return tex
end

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetJustifyH("LEFT")

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.value:SetPoint("RIGHT", 0, 0)
    row.value:SetJustifyH("RIGHT")

    return row
end

local function CreateSectionHeader(parent, key, text, indent)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(18)

    button.indent = indent or 0
    button.key = key
    button.labelText = text
    button.summaryText = ""

    button.icon = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.icon:SetPoint("LEFT", button.indent, 0)
    button.icon:SetJustifyH("LEFT")

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label:SetPoint("LEFT", button.indent + 18, 0)
    button.label:SetJustifyH("LEFT")

    button.summary = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.summary:SetPoint("RIGHT", 0, 0)
    button.summary:SetJustifyH("RIGHT")

    button:SetScript("OnClick", function(self)
        DidYouGrindDB.collapsed[self.key] = not DidYouGrindDB.collapsed[self.key]
        if _G.DidYouGrind_Layout then
            _G.DidYouGrind_Layout()
        end
    end)

    return button
end

-- =========================================
-- SECTIONS
-- =========================================

local sections = {}

sections.keys = {
    key = "keys",
    header = CreateSectionHeader(contentFrame, "keys", "Keys", 0),
    divider = CreateDivider(contentFrame),
    rows = {
        restored = CreateRow(contentFrame),
        shards = CreateRow(contentFrame),
    },
    rowOrder = { "restored", "shards" },
}

sections.dawncrests = {
    key = "dawncrests",
    header = CreateSectionHeader(contentFrame, "dawncrests", "Dawncrests", 0),
    divider = CreateDivider(contentFrame),
    rows = {
        adventurer = CreateRow(contentFrame),
        veteran = CreateRow(contentFrame),
        champion = CreateRow(contentFrame),
        hero = CreateRow(contentFrame),
    },
    rowOrder = { "adventurer", "veteran", "champion", "hero" },
}

sections.weeklyboss = {
    key = "weeklyboss",
    header = CreateSectionHeader(contentFrame, "weeklyboss", "Weekly Boss", 0),
    divider = CreateDivider(contentFrame),
    rows = {
        status = CreateRow(contentFrame),
    },
    rowOrder = { "status" },
}

sections.greatvault = {
    key = "greatvault",
    header = CreateSectionHeader(contentFrame, "greatvault", "Great Vault", 0),
    divider = CreateDivider(contentFrame),
    children = {}
}

sections.raids = {
    key = "raids",
    visibilityKey = "raids",
    header = CreateSectionHeader(contentFrame, "raids", "Raids", 12),
    rows = {
        slot1 = CreateRow(contentFrame),
        slot2 = CreateRow(contentFrame),
        slot3 = CreateRow(contentFrame),
    },
    rowOrder = { "slot1", "slot2", "slot3" },
}

sections.dungeons = {
    key = "dungeons",
    visibilityKey = "dungeons",
    header = CreateSectionHeader(contentFrame, "dungeons", "Dungeons", 12),
    rows = {
        slot1 = CreateRow(contentFrame),
        slot2 = CreateRow(contentFrame),
        slot3 = CreateRow(contentFrame),
    },
    rowOrder = { "slot1", "slot2", "slot3" },
}

sections.world = {
    key = "world",
    visibilityKey = "world",
    header = CreateSectionHeader(contentFrame, "world", "World / Delves", 12),
    rows = {
        slot1 = CreateRow(contentFrame),
        slot2 = CreateRow(contentFrame),
        slot3 = CreateRow(contentFrame),
    },
    rowOrder = { "slot1", "slot2", "slot3" },
}

sections.greatvault.children = {
    sections.raids,
    sections.dungeons,
    sections.world,
}

-- =========================================
-- ROW FORMATTING HELPERS
-- =========================================

local function SetRow(row, labelText, valueText, labelColor)
    row.label:SetText((labelColor or "|cffffffff") .. labelText .. "|r")
    row.value:SetText(valueText or "")
end

local function FormatNumber(value)
    if not value or value == 0 then
        return "|cff666666--|r"
    end

    return "|cffffffff" .. tostring(value) .. "|r"
end

local function CountUnlockedSlots(slots)
    local count = 0
    for _, slot in ipairs(slots or {}) do
        if slot.unlocked then
            count = count + 1
        end
    end
    return count
end

-- =========================================
-- DATA HELPERS
-- =========================================

local function GetCurrencyByName(searchName)
    local search = string.lower(searchName)

    for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)

        if info and info.name then
            local name = string.lower(info.name)
            if string.find(name, search, 1, true) then
                return info.quantity or 0
            end
        end
    end

    return 0
end

-- Add quest IDs here for the most accurate weekly world boss check.
-- Example: local WEEKLY_BOSS_QUEST_IDS = { 12345, 67890 }
local WEEKLY_BOSS_QUEST_IDS = {}

local function IsQuestCompleted(questID)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questID)
    end

    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questID)
    end

    return false
end

local function GetWeeklyBossStatus()
    local hasQuestIDs = #WEEKLY_BOSS_QUEST_IDS > 0

    for _, questID in ipairs(WEEKLY_BOSS_QUEST_IDS) do
        if IsQuestCompleted(questID) then
            return true, "Weekly quest complete", true, true
        end
    end

    if GetNumSavedWorldBosses and GetSavedWorldBossInfo then
        local bossCount = GetNumSavedWorldBosses() or 0
        if bossCount > 0 then
            local firstBossName = nil
            for i = 1, bossCount do
                local name = GetSavedWorldBossInfo(i)
                if name then
                    firstBossName = name
                    break
                end
            end
            return true, firstBossName or "Lockout found", false, true
        end
    end

    if hasQuestIDs then
        return false, nil, true, true
    end

    return false, nil, false, false
end

-- =========================================
-- GREAT VAULT HELPERS
-- =========================================

-- 3 = Raids
-- 1 = Dungeons
-- 6 = World / Delves
local VAULT_TYPES = {
    RAID = 3,
    DUNGEON = 1,
    WORLD = 6,
}

local latestVaultData = {
    raidSlots = {},
    dungeonSlots = {},
    worldSlots = {},
}

local latestWeeklyBossData = {
    killed = false,
    sourceText = "",
    byQuest = false,
    known = false,
}

local function TryGetItemLevelFromActivity(activityID)
    if not C_WeeklyRewards or not C_WeeklyRewards.GetExampleRewardItemHyperlinks then
        return nil
    end

    local ok, link = pcall(C_WeeklyRewards.GetExampleRewardItemHyperlinks, activityID)
    if not ok or not link then
        return nil
    end

    if GetDetailedItemLevelInfo then
        local ilvl = GetDetailedItemLevelInfo(link)
        if type(ilvl) == "number" and ilvl > 0 then
            return ilvl
        end
    end

    return nil
end

local function GetVaultSlotsByType(vaultType, expectedThresholds)
    local slots = {}

    for i, threshold in ipairs(expectedThresholds) do
        slots[i] = {
            threshold = threshold,
            progress = 0,
            level = 0,
            unlocked = false,
            ilvl = nil,
        }
    end

    if not C_WeeklyRewards or not C_WeeklyRewards.GetActivities then
        return slots
    end

    local ok, activities = pcall(C_WeeklyRewards.GetActivities)
    if not ok or type(activities) ~= "table" then
        return slots
    end

    local foundByThreshold = {}

    for _, activity in ipairs(activities) do
        if type(activity) == "table" and activity.type == vaultType then
            local threshold = activity.threshold
            if threshold then
                foundByThreshold[threshold] = {
                    threshold = threshold,
                    progress = math.min(activity.progress or 0, threshold),
                    level = activity.level or 0,
                    unlocked = (activity.progress or 0) >= threshold,
                    ilvl = TryGetItemLevelFromActivity(activity.id),
                    id = activity.id,
                }
            end
        end
    end

    for i, threshold in ipairs(expectedThresholds) do
        if foundByThreshold[threshold] then
            slots[i] = foundByThreshold[threshold]
        end
    end

    return slots
end

local function BuildVaultText(slot)
    local progressText = string.format("%d/%d", slot.progress or 0, slot.threshold or 0)
    local parts = {}

    if slot.unlocked then
        table.insert(parts, "|cff3cff9aReady|r")
        table.insert(parts, "|cffb7ffd8" .. progressText .. "|r")
    else
        table.insert(parts, "|cffffffff" .. progressText .. "|r")
    end

    if slot.level and slot.level > 0 then
        table.insert(parts, "|cff66ccffTier " .. tostring(slot.level) .. "|r")
    end

    if slot.ilvl and slot.ilvl > 0 then
        table.insert(parts, "|cffffe066" .. tostring(slot.ilvl) .. "|r")
    end

    return table.concat(parts, "  |cff666666•|r  ")
end

local function UpdateSectionSummaries()
    local raidUnlocked = CountUnlockedSlots(latestVaultData.raidSlots)
    local dungeonUnlocked = CountUnlockedSlots(latestVaultData.dungeonSlots)
    local worldUnlocked = CountUnlockedSlots(latestVaultData.worldSlots)
    local totalUnlocked = raidUnlocked + dungeonUnlocked + worldUnlocked

    sections.greatvault.header.summaryText = string.format("|cff9fb0c0%d/9 ready|r", totalUnlocked)
    sections.raids.header.summaryText = string.format("|cff9fb0c0%d/3|r", raidUnlocked)
    sections.dungeons.header.summaryText = string.format("|cff9fb0c0%d/3|r", dungeonUnlocked)
    sections.world.header.summaryText = string.format("|cff9fb0c0%d/3|r", worldUnlocked)

    if not latestWeeklyBossData.known then
        sections.weeklyboss.header.summaryText = "|cffffff00Unknown|r"
    elseif latestWeeklyBossData.killed then
        sections.weeklyboss.header.summaryText = "|cff3cff9aKilled|r"
    else
        sections.weeklyboss.header.summaryText = "|cffff5f5fNot killed|r"
    end
end

-- =========================================
-- DATA UPDATE
-- =========================================

local function UpdateData()
    -- Keys
    SetRow(sections.keys.rows.restored, "Restored Key", FormatNumber(GetCurrencyByName("restored coffer key")), "|cffffd100")
    SetRow(sections.keys.rows.shards, "Key Shards", FormatNumber(GetCurrencyByName("coffer key shard")), "|cffffd100")

    -- Dawncrests
    SetRow(sections.dawncrests.rows.adventurer, "Adventurer", FormatNumber(GetCurrencyByName("adventurer dawncrest")), "|cff1eff00")
    SetRow(sections.dawncrests.rows.veteran, "Veteran", FormatNumber(GetCurrencyByName("veteran dawncrest")), "|cff0070dd")
    SetRow(sections.dawncrests.rows.champion, "Champion", FormatNumber(GetCurrencyByName("champion dawncrest")), "|cffa335ee")
    SetRow(sections.dawncrests.rows.hero, "Hero", FormatNumber(GetCurrencyByName("hero dawncrest")), "|cffff8000")

    -- Weekly Boss
    local weeklyKilled, sourceText, byQuest, known = GetWeeklyBossStatus()
    latestWeeklyBossData.killed = weeklyKilled and true or false
    latestWeeklyBossData.sourceText = sourceText or ""
    latestWeeklyBossData.byQuest = byQuest and true or false
    latestWeeklyBossData.known = known and true or false

    local weeklyValueText
    if not known then
        weeklyValueText = "|cffffff00Unknown|r  |cff9fb0c0(enable /dyg wbdebug to capture questID)|r"
    elseif weeklyKilled then
        weeklyValueText = "|cff3cff9aKilled|r"
        if sourceText and sourceText ~= "" then
            weeklyValueText = weeklyValueText .. "  |cff9fb0c0(" .. sourceText .. ")|r"
        end
    else
        weeklyValueText = "|cffff5f5fNot killed|r"
    end

    SetRow(sections.weeklyboss.rows.status, "This reset", weeklyValueText, "|cffff7f50")

    -- Great Vault
    latestVaultData.raidSlots = GetVaultSlotsByType(VAULT_TYPES.RAID, { 2, 4, 6 })
    latestVaultData.dungeonSlots = GetVaultSlotsByType(VAULT_TYPES.DUNGEON, { 1, 4, 8 })
    latestVaultData.worldSlots = GetVaultSlotsByType(VAULT_TYPES.WORLD, { 2, 4, 8 })

    SetRow(sections.raids.rows.slot1, "Slot 1", BuildVaultText(latestVaultData.raidSlots[1]), "|cffc8c8c8")
    SetRow(sections.raids.rows.slot2, "Slot 2", BuildVaultText(latestVaultData.raidSlots[2]), "|cffc8c8c8")
    SetRow(sections.raids.rows.slot3, "Slot 3", BuildVaultText(latestVaultData.raidSlots[3]), "|cffc8c8c8")

    SetRow(sections.dungeons.rows.slot1, "Slot 1", BuildVaultText(latestVaultData.dungeonSlots[1]), "|cffc8c8c8")
    SetRow(sections.dungeons.rows.slot2, "Slot 2", BuildVaultText(latestVaultData.dungeonSlots[2]), "|cffc8c8c8")
    SetRow(sections.dungeons.rows.slot3, "Slot 3", BuildVaultText(latestVaultData.dungeonSlots[3]), "|cffc8c8c8")

    SetRow(sections.world.rows.slot1, "Slot 1", BuildVaultText(latestVaultData.worldSlots[1]), "|cffc8c8c8")
    SetRow(sections.world.rows.slot2, "Slot 2", BuildVaultText(latestVaultData.worldSlots[2]), "|cffc8c8c8")
    SetRow(sections.world.rows.slot3, "Slot 3", BuildVaultText(latestVaultData.worldSlots[3]), "|cffc8c8c8")

    UpdateSectionSummaries()
end

-- =========================================
-- LAYOUT
-- =========================================

local function HideSectionRows(section)
    if section.divider then
        section.divider:Hide()
    end

    if section.rows and section.rowOrder then
        for _, rowKey in ipairs(section.rowOrder) do
            local row = section.rows[rowKey]
            if row then
                row:Hide()
            end
        end
    end

    if section.children then
        for _, child in ipairs(section.children) do
            child.header:Hide()
            HideSectionRows(child)
        end
    end
end

local function SetHeaderVisual(header, collapsed)
    header.icon:SetText(collapsed and "|cffb8c2cc+|r" or "|cffb8c2cc-|r")
    header.label:SetText("|cffd7dde4" .. header.labelText .. "|r")
    header.summary:SetText(header.summaryText or "")
end

local function IsSectionVisible(section)
    if not section or not section.visibilityKey then
        return true
    end

    if not DidYouGrindDB or not DidYouGrindDB.showSections then
        return true
    end

    return DidYouGrindDB.showSections[section.visibilityKey] ~= false
end

local function GetLayoutMetrics()
    if DidYouGrindDB and DidYouGrindDB.compactMode then
        return {
            headerHeight = 16,
            headerGap = 18,
            dividerGap = 6,
            rowHeight = 15,
            sectionGap = 5,
            childGap = 2,
        }
    end

    return {
        headerHeight = 18,
        headerGap = 20,
        dividerGap = 10,
        rowHeight = 18,
        sectionGap = 8,
        childGap = 4,
    }
end

local function LayoutSection(section, y, width, metrics)
    section.header:Show()
    section.header:ClearAllPoints()
    section.header:SetPoint("TOPLEFT", 0, y)
    section.header:SetSize(width, metrics.headerHeight)

    SetHeaderVisual(section.header, DidYouGrindDB.collapsed[section.key])

    y = y - metrics.headerGap

    if DidYouGrindDB.collapsed[section.key] then
        HideSectionRows(section)
        return y
    end

    if section.divider then
        section.divider:Show()
        section.divider:ClearAllPoints()
        section.divider:SetPoint("TOPLEFT", 0, y)
        section.divider:SetPoint("TOPRIGHT", 0, y)
        y = y - metrics.dividerGap
    end

    if section.rows and section.rowOrder then
        for _, rowKey in ipairs(section.rowOrder) do
            local row = section.rows[rowKey]
            if row then
                row:Show()
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, y)
                row:SetSize(width, metrics.rowHeight)
                y = y - metrics.rowHeight
            end
        end
    end

    if section.children then
        for _, child in ipairs(section.children) do
            if IsSectionVisible(child) then
                y = LayoutSection(child, y, width, metrics)
                y = y - metrics.childGap
            else
                child.header:Hide()
                HideSectionRows(child)
            end
        end
    end

    return y
end

local function LayoutUI()
    local metrics = GetLayoutMetrics()
    minimizeButton.text:SetText(DidYouGrindDB.minimized and "|cffb8c2cc+|r" or "|cffb8c2cc-|r")

    local frameWidth = DidYouGrindDB.width or 420
    local frameHeight = DidYouGrindDB.height or 320
    local contentWidth = math.max(frameWidth - 42, 260)

    if DidYouGrindDB.minimized then
        scrollFrame:Hide()
        resizeButton:Hide()
        configPanel:Hide()
        mainFrame:SetWidth(frameWidth)
        mainFrame:SetHeight(54)
        return
    end

    scrollFrame:Show()
    if DidYouGrindDB.locked then
        resizeButton:Hide()
    else
        resizeButton:Show()
    end

    mainFrame:SetWidth(frameWidth)
    mainFrame:SetHeight(frameHeight)

    local y = 0
    if DidYouGrindDB.showSections.keys then
        y = LayoutSection(sections.keys, y, contentWidth, metrics)
        y = y - metrics.sectionGap
    else
        sections.keys.header:Hide()
        HideSectionRows(sections.keys)
    end

    if DidYouGrindDB.showSections.dawncrests then
        y = LayoutSection(sections.dawncrests, y, contentWidth, metrics)
        y = y - metrics.sectionGap
    else
        sections.dawncrests.header:Hide()
        HideSectionRows(sections.dawncrests)
    end

    if DidYouGrindDB.showSections.weeklyboss then
        y = LayoutSection(sections.weeklyboss, y, contentWidth, metrics)
        y = y - metrics.sectionGap
    else
        sections.weeklyboss.header:Hide()
        HideSectionRows(sections.weeklyboss)
    end

    if DidYouGrindDB.showSections.greatvault then
        y = LayoutSection(sections.greatvault, y, contentWidth, metrics)
        y = y - metrics.sectionGap
    else
        sections.greatvault.header:Hide()
        HideSectionRows(sections.greatvault)
    end

    local usedHeight = math.abs(y)
    if usedHeight < 1 then
        usedHeight = 1
    end

    contentFrame:SetSize(contentWidth, usedHeight)
end

_G.DidYouGrind_Layout = LayoutUI

-- =========================================
-- BUTTONS
-- =========================================

local function SyncConfigPanelChecks()
    lockCheck:SetChecked(DidYouGrindDB.locked)
    startMinimizedCheck:SetChecked(DidYouGrindDB.startMinimized)
    autoRefreshCheck:SetChecked(DidYouGrindDB.autoRefresh)
    compactModeCheck:SetChecked(DidYouGrindDB.compactMode)
    showKeysCheck:SetChecked(DidYouGrindDB.showSections.keys)
    showDawncrestsCheck:SetChecked(DidYouGrindDB.showSections.dawncrests)
    showWeeklyBossCheck:SetChecked(DidYouGrindDB.showSections.weeklyboss)
    showGreatVaultCheck:SetChecked(DidYouGrindDB.showSections.greatvault)
    showRaidsCheck:SetChecked(DidYouGrindDB.showSections.raids)
    showDungeonsCheck:SetChecked(DidYouGrindDB.showSections.dungeons)
    showWorldCheck:SetChecked(DidYouGrindDB.showSections.world)

    local parentVisible = DidYouGrindDB.showSections.greatvault
    if parentVisible then
        showRaidsCheck:Enable()
        showDungeonsCheck:Enable()
        showWorldCheck:Enable()
        showRaidsCheck.label:SetTextColor(1, 1, 1)
        showDungeonsCheck.label:SetTextColor(1, 1, 1)
        showWorldCheck.label:SetTextColor(1, 1, 1)
    else
        showRaidsCheck:Disable()
        showDungeonsCheck:Disable()
        showWorldCheck:Disable()
        showRaidsCheck.label:SetTextColor(0.55, 0.55, 0.55)
        showDungeonsCheck.label:SetTextColor(0.55, 0.55, 0.55)
        showWorldCheck.label:SetTextColor(0.55, 0.55, 0.55)
    end
end

minimizeButton:SetScript("OnClick", function()
    DidYouGrindDB.minimized = not DidYouGrindDB.minimized
    LayoutUI()
end)

configButton:SetScript("OnClick", function()
    if configPanel:IsShown() then
        configPanel:Hide()
    else
        SyncConfigPanelChecks()
        configPanel:Show()
    end
end)

configButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("DidYouGrind Settings", 1, 1, 1)
    GameTooltip:AddLine("Configure frame behavior and section visibility.", 0.75, 0.82, 0.9, true)
    GameTooltip:Show()
end)

configButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

lockCheck:SetScript("OnClick", function(self)
    DidYouGrindDB.locked = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

startMinimizedCheck:SetScript("OnClick", function(self)
    DidYouGrindDB.startMinimized = self:GetChecked() and true or false
end)

autoRefreshCheck:SetScript("OnClick", function(self)
    DidYouGrindDB.autoRefresh = self:GetChecked() and true or false
end)

compactModeCheck:SetScript("OnClick", function(self)
    DidYouGrindDB.compactMode = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showKeysCheck:SetScript("OnClick", function(self)
    DidYouGrindDB.showSections.keys = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showDawncrestsCheck:SetScript("OnClick", function(self)
    DidYouGrindDB.showSections.dawncrests = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showWeeklyBossCheck:SetScript("OnClick", function(self)
    DidYouGrindDB.showSections.weeklyboss = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showGreatVaultCheck:SetScript("OnClick", function(self)
    DidYouGrindDB.showSections.greatvault = self:GetChecked() and true or false
    SyncConfigPanelChecks()
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showRaidsCheck:SetScript("OnClick", function(self)
    DidYouGrindDB.showSections.raids = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showDungeonsCheck:SetScript("OnClick", function(self)
    DidYouGrindDB.showSections.dungeons = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showWorldCheck:SetScript("OnClick", function(self)
    DidYouGrindDB.showSections.world = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

mainFrame:SetScript("OnHide", function()
    configPanel:Hide()
end)

-- =========================================
-- POSITION / SIZE
-- =========================================

local function ApplyPosition()
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(
        DidYouGrindDB.point or "CENTER",
        UIParent,
        DidYouGrindDB.relativePoint or "CENTER",
        DidYouGrindDB.x or 0,
        DidYouGrindDB.y or 0
    )

    mainFrame:SetSize(
        DidYouGrindDB.width or 420,
        DidYouGrindDB.height or 320
    )
end

-- =========================================
-- SLASH COMMANDS
-- =========================================

SLASH_DIDYOUGRIND1 = "/dyg"
SlashCmdList["DIDYOUGRIND"] = function(msg)
    msg = string.lower((msg or ""):gsub("^%s+", ""):gsub("%s+$", ""))

    if msg == "reset" then
        DidYouGrindDB.point = "CENTER"
        DidYouGrindDB.relativePoint = "CENTER"
        DidYouGrindDB.x = 0
        DidYouGrindDB.y = 0
        DidYouGrindDB.width = defaults.width
        DidYouGrindDB.height = defaults.height
        ApplyPosition()
        LayoutUI()
        print("DidYouGrind: position and size reset.")
    elseif msg == "min" then
        DidYouGrindDB.minimized = true
        LayoutUI()
    elseif msg == "max" then
        DidYouGrindDB.minimized = false
        LayoutUI()
    elseif msg == "toggle" then
        if mainFrame:IsShown() then
            mainFrame:Hide()
        else
            mainFrame:Show()
            UpdateData()
            LayoutUI()
        end
    elseif msg == "refresh" then
        UpdateData()
        LayoutUI()
        print("DidYouGrind: refreshed.")
    elseif msg == "wbdebug" then
        DidYouGrindDB.weeklyBossDebug = not DidYouGrindDB.weeklyBossDebug
        if DidYouGrindDB.weeklyBossDebug then
            print("DidYouGrind: weekly boss debug enabled. Kill/turn in and watch chat for quest IDs.")
        else
            print("DidYouGrind: weekly boss debug disabled.")
        end
    elseif msg == "config" or msg == "options" then
        if configPanel:IsShown() then
            configPanel:Hide()
        else
            SyncConfigPanelChecks()
            configPanel:Show()
        end
    else
        print("|cff00ff99DidYouGrind commands:|r")
        print("/dyg reset")
        print("/dyg min")
        print("/dyg max")
        print("/dyg toggle")
        print("/dyg refresh")
        print("/dyg wbdebug")
        print("/dyg config")
    end
end

-- =========================================
-- EVENTS
-- =========================================

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            DidYouGrindDB = CopyDefaults(defaults, DidYouGrindDB or {})
            if DidYouGrindDB.startMinimized then
                DidYouGrindDB.minimized = true
            end
            ApplyPosition()
            UpdateData()
            LayoutUI()
            mainFrame:Show()
        end
    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        if DidYouGrindDB and DidYouGrindDB.weeklyBossDebug then
            local title = nil
            if C_QuestLog and C_QuestLog.GetTitleForQuestID then
                title = C_QuestLog.GetTitleForQuestID(questID)
            end
            if title and title ~= "" then
                print("DidYouGrind WB Debug: QUEST_TURNED_IN questID=" .. tostring(questID) .. " title=\"" .. title .. "\"")
            else
                print("DidYouGrind WB Debug: QUEST_TURNED_IN questID=" .. tostring(questID))
            end
        end
    else
        if mainFrame:IsShown() and DidYouGrindDB and DidYouGrindDB.autoRefresh then
            UpdateData()
            LayoutUI()
        end
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
eventFrame:RegisterEvent("QUEST_TURNED_IN")

-- =========================================
-- POLLING
-- =========================================

local elapsed = 0
mainFrame:SetScript("OnUpdate", function(_, delta)
    if not mainFrame:IsShown() or not DidYouGrindDB or not DidYouGrindDB.autoRefresh then
        return
    end

    elapsed = elapsed + delta
    if elapsed > 5 then
        UpdateData()
        LayoutUI()
        elapsed = 0
    end
end)
