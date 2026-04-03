-- =========================================
-- DidYouGrind - lightweight weekly tracker
-- =========================================

local addonName = ...
local eventFrame = CreateFrame("Frame")

-- =========================================
-- DATABASE DEFAULTS
-- =========================================

local layoutDefaults = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    width = 420,
    height = 320,
}

local characterDefaults = {
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
    layout = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = 420,
        height = 320,
    },
}

local defaults = {
    accountWideLayout = true,
    globalLayout = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = 420,
        height = 320,
    },
    weeklyBossQuestIDs = {},
    hiddenAltKeys = {},
    characterProfiles = {},
    characterSnapshots = {},
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

local activeCharacterProfile = nil
local activeLayoutProfile = nil
local currentCharacterKey = nil
local SyncConfigPanelChecks = nil
local UpdateData = nil
local LayoutUI = nil

local function GetCharacterDisplayNameFromKey(key)
    if type(key) ~= "string" then
        return "Unknown"
    end
    local realm, name = string.match(key, "^(.+)%-(.+)$")
    if realm and name then
        return name .. " (" .. realm .. ")"
    end
    return key
end

local function GetCharacterKey()
    local name, realm = UnitFullName("player")
    name = name or UnitName("player") or "Unknown"
    realm = realm or GetRealmName() or "UnknownRealm"
    realm = realm:gsub("%s+", "")
    return realm .. "-" .. name
end

local function MigrateLegacyIntoCharacterProfile(profile, root)
    local hasLegacy = root.point ~= nil or root.minimized ~= nil or root.showSections ~= nil
    if not hasLegacy then
        return
    end

    profile.minimized = root.minimized
    profile.startMinimized = root.startMinimized
    profile.autoRefresh = root.autoRefresh
    profile.compactMode = root.compactMode
    profile.locked = root.locked
    profile.weeklyBossDebug = root.weeklyBossDebug
    profile.showSections = CopyDefaults(root.showSections or {}, profile.showSections or {})
    profile.collapsed = CopyDefaults(root.collapsed or {}, profile.collapsed or {})
    profile.layout = CopyDefaults({
        point = root.point,
        relativePoint = root.relativePoint,
        x = root.x,
        y = root.y,
        width = root.width,
        height = root.height,
    }, profile.layout or {})
end

local function RefreshActiveProfiles()
    if not DidYouGrindDB then
        return
    end

    DidYouGrindDB = CopyDefaults(defaults, DidYouGrindDB)
    DidYouGrindDB.globalLayout = CopyDefaults(layoutDefaults, DidYouGrindDB.globalLayout)

    local charKey = GetCharacterKey()
    currentCharacterKey = charKey
    DidYouGrindDB.characterProfiles[charKey] = CopyDefaults(characterDefaults, DidYouGrindDB.characterProfiles[charKey] or {})
    local charProfile = DidYouGrindDB.characterProfiles[charKey]
    charProfile.layout = CopyDefaults(layoutDefaults, charProfile.layout)

    activeCharacterProfile = charProfile
    if DidYouGrindDB.accountWideLayout then
        activeLayoutProfile = DidYouGrindDB.globalLayout
    else
        activeLayoutProfile = charProfile.layout
    end

end

local function GetCharacterProfile()
    return activeCharacterProfile or characterDefaults
end

local function GetLayoutProfile()
    return activeLayoutProfile or layoutDefaults
end

local function GetShowSections()
    local profile = GetCharacterProfile()
    profile.showSections = CopyDefaults(characterDefaults.showSections, profile.showSections or {})
    return profile.showSections
end

local function GetCollapsedSections()
    local profile = GetCharacterProfile()
    profile.collapsed = CopyDefaults(characterDefaults.collapsed, profile.collapsed or {})
    return profile.collapsed
end

local function IsProfileReady()
    return activeCharacterProfile ~= nil and activeLayoutProfile ~= nil
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
    if GetCharacterProfile().locked then
        return
    end
    self:StartMoving()
end)

mainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    local point, _, relativePoint, x, y = self:GetPoint()
    local layout = GetLayoutProfile()
    layout.point = point
    layout.relativePoint = relativePoint
    layout.x = x
    layout.y = y
end)

-- Resize handle
local resizeButton = CreateFrame("Button", nil, mainFrame)
resizeButton:SetSize(16, 16)
resizeButton:SetPoint("BOTTOMRIGHT", -4, 4)
resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

resizeButton:SetScript("OnMouseDown", function()
    if GetCharacterProfile().locked then
        return
    end
    mainFrame:StartSizing("BOTTOMRIGHT")
end)

resizeButton:SetScript("OnMouseUp", function()
    mainFrame:StopMovingOrSizing()
    local layout = GetLayoutProfile()
    layout.width = mainFrame:GetWidth()
    layout.height = mainFrame:GetHeight()
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
configButton:SetPoint("TOPRIGHT", -34, -8)

configButton.icon = configButton:CreateTexture(nil, "ARTWORK")
configButton.icon:SetSize(16, 16)
configButton.icon:SetPoint("CENTER", 0, 0)
configButton.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
configButton.icon:SetVertexColor(0.85, 0.90, 0.95, 1)

configButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

local altsButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
altsButton:SetSize(44, 18)
altsButton:SetPoint("TOPRIGHT", -62, -10)
altsButton:SetText("ALTS")

local configPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
configPanel:SetSize(220, 285)
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
sectionTitle:SetPoint("TOPLEFT", 10, -122)
sectionTitle:SetText("|cff9fb0c0Sections|r")

local profileTitle = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
profileTitle:SetPoint("TOPLEFT", 10, -28)
profileTitle:SetText("|cff9fb0c0Profiles|r")

local profileHint = configPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
profileHint:SetPoint("TOPLEFT", 26, -48)
profileHint:SetText("Use ALTS button for character board")

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

local accountWideLayoutCheck = CreateConfigCheckbox(configPanel, "Account-wide layout", -62)
local lockCheck = CreateConfigCheckbox(configPanel, "Lock frame", -82)
local startMinimizedCheck = CreateConfigCheckbox(configPanel, "Start minimized", -102)
local autoRefreshCheck = CreateConfigCheckbox(configPanel, "Auto refresh", -122)
local compactModeCheck = CreateConfigCheckbox(configPanel, "Compact mode", -142)

local showKeysCheck = CreateConfigCheckbox(configPanel, "Show Keys", -162)
local showDawncrestsCheck = CreateConfigCheckbox(configPanel, "Show Dawncrests", -182)
local showWeeklyBossCheck = CreateConfigCheckbox(configPanel, "Show Weekly Boss", -202)
local showGreatVaultCheck = CreateConfigCheckbox(configPanel, "Show Great Vault", -222)
local showRaidsCheck = CreateConfigCheckbox(configPanel, "  - Raids", -242)
local showDungeonsCheck = CreateConfigCheckbox(configPanel, "  - Dungeons", -262)
local showWorldCheck = CreateConfigCheckbox(configPanel, "  - World / Delves", -282)

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
-- ALTS BOARD
-- =========================================

local altsBoardFrame = CreateFrame("Frame", "DidYouGrindAltsBoard", UIParent, "BackdropTemplate")
altsBoardFrame:SetSize(760, 470)
altsBoardFrame:SetPoint("CENTER")
altsBoardFrame:SetFrameStrata("DIALOG")
altsBoardFrame:SetMovable(true)
altsBoardFrame:EnableMouse(true)
altsBoardFrame:RegisterForDrag("LeftButton")
altsBoardFrame:SetClampedToScreen(true)
altsBoardFrame:SetBackdrop({
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
altsBoardFrame:SetBackdropColor(0, 0, 0, 0.94)
altsBoardFrame:Hide()

altsBoardFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

altsBoardFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

local altsTitle = altsBoardFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
altsTitle:SetPoint("TOPLEFT", 12, -10)
altsTitle:SetText("|cff00ff99DidYouGrind Alts|r")

local altsSub = altsBoardFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
altsSub:SetPoint("TOPLEFT", 12, -30)
altsSub:SetText("|cffaaaaaaSnapshots per character|r")

local altsClose = CreateFrame("Button", nil, altsBoardFrame, "UIPanelCloseButton")
altsClose:SetPoint("TOPRIGHT", -4, -4)

local altsListPanel = CreateFrame("Frame", nil, altsBoardFrame, "BackdropTemplate")
altsListPanel:SetPoint("TOPLEFT", 12, -54)
altsListPanel:SetPoint("BOTTOMLEFT", 12, 12)
altsListPanel:SetWidth(250)
altsListPanel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = {
        left = 2,
        right = 2,
        top = 2,
        bottom = 2
    }
})
altsListPanel:SetBackdropColor(0, 0, 0, 0.5)

local altsListTitle = altsListPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
altsListTitle:SetPoint("TOPLEFT", 10, -8)
altsListTitle:SetText("|cffd7dde4Characters|r")

local altsListScroll = CreateFrame("ScrollFrame", nil, altsListPanel, "UIPanelScrollFrameTemplate")
altsListScroll:SetPoint("TOPLEFT", 8, -28)
altsListScroll:SetPoint("BOTTOMRIGHT", -26, 8)

local altsListContent = CreateFrame("Frame", nil, altsListScroll)
altsListContent:SetSize(1, 1)
altsListScroll:SetScrollChild(altsListContent)

local altsDetailPanel = CreateFrame("Frame", nil, altsBoardFrame, "BackdropTemplate")
altsDetailPanel:SetPoint("TOPLEFT", 274, -54)
altsDetailPanel:SetPoint("BOTTOMRIGHT", -12, 12)
altsDetailPanel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = {
        left = 2,
        right = 2,
        top = 2,
        bottom = 2
    }
})
altsDetailPanel:SetBackdropColor(0, 0, 0, 0.5)

local altsDetailTitle = altsDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
altsDetailTitle:SetPoint("TOPLEFT", 12, -10)
altsDetailTitle:SetText("Select an alt")

local altsDetailMeta = altsDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
altsDetailMeta:SetPoint("TOPLEFT", 12, -34)
altsDetailMeta:SetText("|cffaaaaaaNo snapshot selected|r")

local altsDetailBody = altsDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
altsDetailBody:SetPoint("TOPLEFT", 12, -58)
altsDetailBody:SetPoint("BOTTOMRIGHT", -12, 12)
altsDetailBody:SetJustifyH("LEFT")
altsDetailBody:SetJustifyV("TOP")
altsDetailBody:SetText("")

local altsSelectedKey = nil
local altRowButtons = {}

local function GetVisibleAltKeys()
    local keys = {}
    if not DidYouGrindDB or type(DidYouGrindDB.characterSnapshots) ~= "table" then
        return keys
    end

    local hidden = DidYouGrindDB.hiddenAltKeys or {}
    for key, _ in pairs(DidYouGrindDB.characterSnapshots) do
        if key ~= currentCharacterKey and not hidden[key] then
            table.insert(keys, key)
        end
    end

    table.sort(keys)
    return keys
end

local function SetAltsDetailFromSnapshot(key)
    local snap = DidYouGrindDB and DidYouGrindDB.characterSnapshots and DidYouGrindDB.characterSnapshots[key]
    if not snap then
        altsDetailTitle:SetText("No snapshot")
        altsDetailMeta:SetText("|cffaaaaaaNo data for this character yet.|r")
        altsDetailBody:SetText("")
        return
    end

    local rows = snap.rows or {}
    local realm, name = string.match(key, "^(.+)%-(.+)$")
    altsDetailTitle:SetText(name or GetCharacterDisplayNameFromKey(key))
    local stamp = snap.updatedAt or "unknown time"
    altsDetailMeta:SetText(string.format("|cffaaaaaa%s | Last synced: %s|r", realm or "UnknownRealm", stamp))

    local text = table.concat({
        "|cffd7dde4Keys|r",
        string.format("Restored Key: %s", rows.keys_restored or "|cff666666--|r"),
        string.format("Key Shards: %s", rows.keys_shards or "|cff666666--|r"),
        " ",
        "|cffd7dde4Dawncrests|r",
        string.format("Adventurer: %s", rows.dawn_adventurer or "|cff666666--|r"),
        string.format("Veteran: %s", rows.dawn_veteran or "|cff666666--|r"),
        string.format("Champion: %s", rows.dawn_champion or "|cff666666--|r"),
        string.format("Hero: %s", rows.dawn_hero or "|cff666666--|r"),
        " ",
        "|cffd7dde4Weekly Boss|r",
        string.format("This reset: %s", rows.weekly_status or "|cff666666--|r"),
        " ",
        "|cffd7dde4Great Vault|r",
        string.format("Raids: %s | %s | %s", rows.raid_slot1 or "--", rows.raid_slot2 or "--", rows.raid_slot3 or "--"),
        string.format("Dungeons: %s | %s | %s", rows.dungeon_slot1 or "--", rows.dungeon_slot2 or "--", rows.dungeon_slot3 or "--"),
        string.format("World/Delves: %s | %s | %s", rows.world_slot1 or "--", rows.world_slot2 or "--", rows.world_slot3 or "--"),
    }, "\n")

    altsDetailBody:SetText(text)
end

local function RefreshAltsBoard()
    if not DidYouGrindDB then
        return
    end

    local keys = GetVisibleAltKeys()
    altsSub:SetText(string.format("|cffaaaaaa%d alts tracked|r", #keys))
    local rowHeight = 44
    local width = math.max(altsListPanel:GetWidth() - 36, 180)
    local y = 0

    for i, key in ipairs(keys) do
        local row = altRowButtons[i]
        if not row then
            row = CreateFrame("Button", nil, altsListContent, "BackdropTemplate")
            row:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 8,
                insets = {
                    left = 1,
                    right = 1,
                    top = 1,
                    bottom = 1
                }
            })
            row:SetBackdropColor(0, 0, 0, 0.3)

            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.name:SetPoint("TOPLEFT", 8, -6)
            row.name:SetJustifyH("LEFT")

            row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.meta:SetPoint("TOPLEFT", 8, -22)
            row.meta:SetJustifyH("LEFT")

            row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.remove:SetSize(18, 18)
            row.remove:SetPoint("TOPRIGHT", -4, -4)
            row.remove:SetText("x")

            row:SetScript("OnClick", function(self)
                altsSelectedKey = self.key
                SetAltsDetailFromSnapshot(self.key)
                RefreshAltsBoard()
            end)

            row.remove:SetScript("OnClick", function(self)
                local k = self:GetParent().key
                if type(DidYouGrindDB.hiddenAltKeys) ~= "table" then
                    DidYouGrindDB.hiddenAltKeys = {}
                end
                DidYouGrindDB.hiddenAltKeys[k] = true
                if altsSelectedKey == k then
                    altsSelectedKey = nil
                end
                RefreshAltsBoard()
            end)

            altRowButtons[i] = row
        end

        local snap = DidYouGrindDB.characterSnapshots[key]
        row.key = key
        row:Show()
        row:SetSize(width, rowHeight - 2)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, y)
        row:SetBackdropBorderColor(altsSelectedKey == key and 0.25 or 0.12, altsSelectedKey == key and 0.8 or 0.12, 0.95, 1)

        row.name:SetText("|cffd7dde4" .. GetCharacterDisplayNameFromKey(key) .. "|r")
        row.meta:SetText("|cff9fb0c0" .. (snap and snap.updatedAt or "No snapshot date") .. "|r")
        y = y - rowHeight
    end

    for i = #keys + 1, #altRowButtons do
        altRowButtons[i]:Hide()
    end

    if #keys == 0 then
        altsSelectedKey = nil
        altsDetailTitle:SetText("No alts yet")
        altsDetailMeta:SetText("|cffaaaaaaLog into another character to generate a snapshot.|r")
        altsDetailBody:SetText("")
    elseif not altsSelectedKey or not DidYouGrindDB.characterSnapshots[altsSelectedKey] or DidYouGrindDB.hiddenAltKeys[altsSelectedKey] then
        altsSelectedKey = keys[1]
        SetAltsDetailFromSnapshot(altsSelectedKey)
    else
        SetAltsDetailFromSnapshot(altsSelectedKey)
    end

    local usedHeight = math.max(math.abs(y), 1)
    altsListContent:SetSize(width, usedHeight)
end

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

local function CreateSectionHeader(parent, key, text, indent, categoryIconPath)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(18)

    button.indent = indent or 0
    button.key = key
    button.labelText = text
    button.summaryText = ""
    button.categoryIconPath = categoryIconPath

    button.icon = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.icon:SetPoint("LEFT", button.indent, 0)
    button.icon:SetJustifyH("LEFT")

    button.categoryIcon = button:CreateTexture(nil, "ARTWORK")
    button.categoryIcon:SetSize(12, 12)
    button.categoryIcon:SetPoint("LEFT", button.indent + 14, 0)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label:SetPoint("LEFT", button.indent + 30, 0)
    button.label:SetJustifyH("LEFT")

    button.summary = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.summary:SetPoint("RIGHT", 0, 0)
    button.summary:SetJustifyH("RIGHT")

    button:SetScript("OnClick", function(self)
        local collapsed = GetCollapsedSections()
        collapsed[self.key] = not collapsed[self.key]
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
    header = CreateSectionHeader(contentFrame, "keys", "Keys", 0, "Interface\\Icons\\INV_Misc_Key_14"),
    divider = CreateDivider(contentFrame),
    rows = {
        restored = CreateRow(contentFrame),
        shards = CreateRow(contentFrame),
    },
    rowOrder = { "restored", "shards" },
}

sections.dawncrests = {
    key = "dawncrests",
    header = CreateSectionHeader(contentFrame, "dawncrests", "Dawncrests", 0, "Interface\\Icons\\INV_Misc_Coin_01"),
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
    header = CreateSectionHeader(contentFrame, "weeklyboss", "Weekly Boss", 0, "Interface\\Icons\\Achievement_Boss_Anubarak"),
    divider = CreateDivider(contentFrame),
    rows = {
        status = CreateRow(contentFrame),
    },
    rowOrder = { "status" },
}

sections.greatvault = {
    key = "greatvault",
    header = CreateSectionHeader(contentFrame, "greatvault", "Great Vault", 0, "Interface\\Icons\\INV_Chest_Cloth_17"),
    divider = CreateDivider(contentFrame),
    children = {}
}

sections.raids = {
    key = "raids",
    visibilityKey = "raids",
    header = CreateSectionHeader(contentFrame, "raids", "Raids", 12, "Interface\\Icons\\Ability_Racial_BloodRage"),
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
    header = CreateSectionHeader(contentFrame, "dungeons", "Dungeons", 12, "Interface\\Icons\\INV_Misc_Map02"),
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
    header = CreateSectionHeader(contentFrame, "world", "World / Delves", 12, "Interface\\Icons\\Achievement_Zone_DragonIsles_01"),
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
local WEEKLY_BOSS_QUEST_IDS = {
    92034, -- Thorm'belan
}

local WEEKLY_BOSS_NAME_MATCHES = {
    "thorm'belan",
    "lu'ashal",
    "predaxas",
    "cragpine",
}

local function IsQuestCompleted(questID)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return C_QuestLog.IsQuestFlaggedCompleted(questID)
    end

    if IsQuestFlaggedCompleted then
        return IsQuestFlaggedCompleted(questID)
    end

    return false
end

local function GetAllWeeklyBossQuestIDs()
    local merged = {}
    local seen = {}

    local function AddID(id)
        if type(id) ~= "number" then
            return
        end
        if seen[id] then
            return
        end
        seen[id] = true
        table.insert(merged, id)
    end

    for _, id in ipairs(WEEKLY_BOSS_QUEST_IDS) do
        AddID(id)
    end

    if DidYouGrindDB and type(DidYouGrindDB.weeklyBossQuestIDs) == "table" then
        for _, id in ipairs(DidYouGrindDB.weeklyBossQuestIDs) do
            AddID(id)
        end
    end

    return merged
end

local function IsKnownWeeklyBossTitle(title)
    if type(title) ~= "string" or title == "" then
        return false
    end

    local normalized = string.lower(title):gsub("’", "'")
    for _, namePart in ipairs(WEEKLY_BOSS_NAME_MATCHES) do
        if string.find(normalized, namePart, 1, true) then
            return true
        end
    end

    return false
end

local function LearnWeeklyBossQuestID(questID, title)
    if not DidYouGrindDB or type(questID) ~= "number" then
        return false
    end

    if type(DidYouGrindDB.weeklyBossQuestIDs) ~= "table" then
        DidYouGrindDB.weeklyBossQuestIDs = {}
    end

    local knownIDs = GetAllWeeklyBossQuestIDs()
    for _, id in ipairs(knownIDs) do
        if id == questID then
            return false
        end
    end

    table.insert(DidYouGrindDB.weeklyBossQuestIDs, questID)

    local label = (title and title ~= "") and (" (" .. title .. ")") or ""
    print("DidYouGrind: learned weekly boss questID=" .. tostring(questID) .. label)
    return true
end

local function GetWeeklyBossStatus()
    local knownQuestIDs = GetAllWeeklyBossQuestIDs()
    local hasQuestIDs = #knownQuestIDs > 0

    for _, questID in ipairs(knownQuestIDs) do
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

local function SaveCurrentSnapshot()
    if not DidYouGrindDB then
        return
    end

    if type(DidYouGrindDB.characterSnapshots) ~= "table" then
        DidYouGrindDB.characterSnapshots = {}
    end
    if type(DidYouGrindDB.hiddenAltKeys) ~= "table" then
        DidYouGrindDB.hiddenAltKeys = {}
    end

    local key = currentCharacterKey or GetCharacterKey()
    local snapshot = {
        key = key,
        displayName = GetCharacterDisplayNameFromKey(key),
        updatedAt = date("%Y-%m-%d %H:%M:%S"),
        rows = {
            keys_restored = sections.keys.rows.restored.value:GetText(),
            keys_shards = sections.keys.rows.shards.value:GetText(),
            dawn_adventurer = sections.dawncrests.rows.adventurer.value:GetText(),
            dawn_veteran = sections.dawncrests.rows.veteran.value:GetText(),
            dawn_champion = sections.dawncrests.rows.champion.value:GetText(),
            dawn_hero = sections.dawncrests.rows.hero.value:GetText(),
            weekly_status = sections.weeklyboss.rows.status.value:GetText(),
            raid_slot1 = sections.raids.rows.slot1.value:GetText(),
            raid_slot2 = sections.raids.rows.slot2.value:GetText(),
            raid_slot3 = sections.raids.rows.slot3.value:GetText(),
            dungeon_slot1 = sections.dungeons.rows.slot1.value:GetText(),
            dungeon_slot2 = sections.dungeons.rows.slot2.value:GetText(),
            dungeon_slot3 = sections.dungeons.rows.slot3.value:GetText(),
            world_slot1 = sections.world.rows.slot1.value:GetText(),
            world_slot2 = sections.world.rows.slot2.value:GetText(),
            world_slot3 = sections.world.rows.slot3.value:GetText(),
        },
        summaries = {
            weeklyboss = sections.weeklyboss.header.summaryText,
            greatvault = sections.greatvault.header.summaryText,
            raids = sections.raids.header.summaryText,
            dungeons = sections.dungeons.header.summaryText,
            world = sections.world.header.summaryText,
        },
    }

    DidYouGrindDB.characterSnapshots[key] = snapshot
    DidYouGrindDB.hiddenAltKeys[key] = nil
end

UpdateData = function()
    subtitle:SetText("|cffaaaaaa(Probably not)|r")

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
    SaveCurrentSnapshot()
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

local function HideSectionContent(section)
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
    if header.categoryIconPath and header.categoryIconPath ~= "" then
        header.categoryIcon:Show()
        header.categoryIcon:SetTexture(header.categoryIconPath)
        header.label:ClearAllPoints()
        header.label:SetPoint("LEFT", header.indent + 30, 0)
    else
        header.categoryIcon:Hide()
        header.label:ClearAllPoints()
        header.label:SetPoint("LEFT", header.indent + 18, 0)
    end
    header.label:SetText("|cffd7dde4" .. header.labelText .. "|r")
    header.summary:SetText(header.summaryText or "")
end

local function IsSectionVisible(section)
    if not section or not section.visibilityKey then
        return true
    end

    local showSections = GetShowSections()
    return showSections[section.visibilityKey] ~= false
end

local function GetLayoutMetrics()
    if GetCharacterProfile().compactMode then
        return {
            headerHeight = 16,
            headerGap = 18,
            rowHeight = 15,
            sectionGap = 5,
            childGap = 2,
        }
    end

    return {
        headerHeight = 18,
        headerGap = 20,
        rowHeight = 18,
        sectionGap = 8,
        childGap = 4,
    }
end

local function LayoutSection(section, y, width, metrics)
    local collapsed = GetCollapsedSections()

    if section.divider then
        section.divider:Show()
        section.divider:ClearAllPoints()
        section.divider:SetPoint("TOPLEFT", 0, y + 6)
        section.divider:SetPoint("TOPRIGHT", 0, y + 6)
    end

    section.header:Show()
    section.header:ClearAllPoints()
    section.header:SetPoint("TOPLEFT", 0, y)
    section.header:SetSize(width, metrics.headerHeight)

    SetHeaderVisual(section.header, collapsed[section.key])

    y = y - metrics.headerGap

    if collapsed[section.key] then
        HideSectionContent(section)
        return y
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

LayoutUI = function()
    local metrics = GetLayoutMetrics()
    local profile = GetCharacterProfile()
    local layout = GetLayoutProfile()
    local showSections = GetShowSections()
    minimizeButton.text:SetText(profile.minimized and "|cffb8c2cc+|r" or "|cffb8c2cc-|r")

    local frameWidth = layout.width or 420
    local frameHeight = layout.height or 320
    local contentWidth = math.max(frameWidth - 42, 260)

    if profile.minimized then
        scrollFrame:Hide()
        resizeButton:Hide()
        configPanel:Hide()
        mainFrame:SetWidth(frameWidth)
        mainFrame:SetHeight(54)
        return
    end

    scrollFrame:Show()
    if profile.locked then
        resizeButton:Hide()
    else
        resizeButton:Show()
    end

    mainFrame:SetWidth(frameWidth)
    mainFrame:SetHeight(frameHeight)

    local y = 0
    if showSections.keys then
        y = LayoutSection(sections.keys, y, contentWidth, metrics)
        y = y - metrics.sectionGap
    else
        sections.keys.header:Hide()
        HideSectionRows(sections.keys)
    end

    if showSections.dawncrests then
        y = LayoutSection(sections.dawncrests, y, contentWidth, metrics)
        y = y - metrics.sectionGap
    else
        sections.dawncrests.header:Hide()
        HideSectionRows(sections.dawncrests)
    end

    if showSections.weeklyboss then
        y = LayoutSection(sections.weeklyboss, y, contentWidth, metrics)
        y = y - metrics.sectionGap
    else
        sections.weeklyboss.header:Hide()
        HideSectionRows(sections.weeklyboss)
    end

    if showSections.greatvault then
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

SyncConfigPanelChecks = function()
    local profile = GetCharacterProfile()
    local showSections = GetShowSections()

    accountWideLayoutCheck:SetChecked(DidYouGrindDB and DidYouGrindDB.accountWideLayout)
    lockCheck:SetChecked(profile.locked)
    startMinimizedCheck:SetChecked(profile.startMinimized)
    autoRefreshCheck:SetChecked(profile.autoRefresh)
    compactModeCheck:SetChecked(profile.compactMode)
    showKeysCheck:SetChecked(showSections.keys)
    showDawncrestsCheck:SetChecked(showSections.dawncrests)
    showWeeklyBossCheck:SetChecked(showSections.weeklyboss)
    showGreatVaultCheck:SetChecked(showSections.greatvault)
    showRaidsCheck:SetChecked(showSections.raids)
    showDungeonsCheck:SetChecked(showSections.dungeons)
    showWorldCheck:SetChecked(showSections.world)

    local parentVisible = showSections.greatvault
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
    local profile = GetCharacterProfile()
    profile.minimized = not profile.minimized
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

altsButton:SetScript("OnClick", function()
    if altsBoardFrame:IsShown() then
        altsBoardFrame:Hide()
    else
        configPanel:Hide()
        RefreshAltsBoard()
        altsBoardFrame:Show()
    end
end)

altsButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Alt Board", 1, 1, 1)
    GameTooltip:AddLine("Browse snapshots from your other characters.", 0.75, 0.82, 0.9, true)
    GameTooltip:Show()
end)

altsButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

lockCheck:SetScript("OnClick", function(self)
    GetCharacterProfile().locked = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

startMinimizedCheck:SetScript("OnClick", function(self)
    GetCharacterProfile().startMinimized = self:GetChecked() and true or false
end)

autoRefreshCheck:SetScript("OnClick", function(self)
    GetCharacterProfile().autoRefresh = self:GetChecked() and true or false
end)

compactModeCheck:SetScript("OnClick", function(self)
    GetCharacterProfile().compactMode = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showKeysCheck:SetScript("OnClick", function(self)
    GetShowSections().keys = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showDawncrestsCheck:SetScript("OnClick", function(self)
    GetShowSections().dawncrests = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showWeeklyBossCheck:SetScript("OnClick", function(self)
    GetShowSections().weeklyboss = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showGreatVaultCheck:SetScript("OnClick", function(self)
    GetShowSections().greatvault = self:GetChecked() and true or false
    SyncConfigPanelChecks()
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showRaidsCheck:SetScript("OnClick", function(self)
    GetShowSections().raids = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showDungeonsCheck:SetScript("OnClick", function(self)
    GetShowSections().dungeons = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

showWorldCheck:SetScript("OnClick", function(self)
    GetShowSections().world = self:GetChecked() and true or false
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

accountWideLayoutCheck:SetScript("OnClick", function(self)
    DidYouGrindDB.accountWideLayout = self:GetChecked() and true or false
    RefreshActiveProfiles()
    local layout = GetLayoutProfile()
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(
        layout.point or "CENTER",
        UIParent,
        layout.relativePoint or "CENTER",
        layout.x or 0,
        layout.y or 0
    )
    mainFrame:SetSize(
        layout.width or 420,
        layout.height or 320
    )
    SyncConfigPanelChecks()
    if _G.DidYouGrind_Layout then
        _G.DidYouGrind_Layout()
    end
end)

mainFrame:SetScript("OnHide", function()
    configPanel:Hide()
    altsBoardFrame:Hide()
end)

-- =========================================
-- POSITION / SIZE
-- =========================================

local function ApplyPosition()
    local layout = GetLayoutProfile()
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(
        layout.point or "CENTER",
        UIParent,
        layout.relativePoint or "CENTER",
        layout.x or 0,
        layout.y or 0
    )

    mainFrame:SetSize(
        layout.width or 420,
        layout.height or 320
    )
end

-- =========================================
-- SLASH COMMANDS
-- =========================================

SLASH_DIDYOUGRIND1 = "/dyg"
SlashCmdList["DIDYOUGRIND"] = function(msg)
    msg = string.lower((msg or ""):gsub("^%s+", ""):gsub("%s+$", ""))

    if msg == "reset" then
        local layout = GetLayoutProfile()
        layout.point = "CENTER"
        layout.relativePoint = "CENTER"
        layout.x = 0
        layout.y = 0
        layout.width = layoutDefaults.width
        layout.height = layoutDefaults.height
        ApplyPosition()
        LayoutUI()
        print("DidYouGrind: position and size reset.")
    elseif msg == "min" then
        GetCharacterProfile().minimized = true
        LayoutUI()
    elseif msg == "max" then
        GetCharacterProfile().minimized = false
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
        local profile = GetCharacterProfile()
        profile.weeklyBossDebug = not profile.weeklyBossDebug
        if profile.weeklyBossDebug then
            print("DidYouGrind: weekly boss debug enabled. Kill/turn in and watch chat for quest IDs.")
        else
            print("DidYouGrind: weekly boss debug disabled.")
        end
    elseif msg == "wbids" then
        local ids = GetAllWeeklyBossQuestIDs()
        if #ids == 0 then
            print("DidYouGrind: no weekly boss quest IDs known yet.")
        else
            table.sort(ids)
            print("DidYouGrind: known weekly boss quest IDs: " .. table.concat(ids, ", "))
        end
    elseif msg == "layoutscope" then
        if DidYouGrindDB.accountWideLayout then
            print("DidYouGrind: layout scope is account-wide.")
        else
            print("DidYouGrind: layout scope is character-specific.")
        end
    elseif msg == "alts" then
        if altsBoardFrame:IsShown() then
            altsBoardFrame:Hide()
        else
            configPanel:Hide()
            RefreshAltsBoard()
            altsBoardFrame:Show()
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
        print("/dyg wbids")
        print("/dyg layoutscope")
        print("/dyg alts")
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
            DidYouGrindDB = DidYouGrindDB or {}
            local currentCharKey = GetCharacterKey()
            DidYouGrindDB.characterProfiles = DidYouGrindDB.characterProfiles or {}

            if DidYouGrindDB.point ~= nil then
                DidYouGrindDB.globalLayout = CopyDefaults({
                    point = DidYouGrindDB.point,
                    relativePoint = DidYouGrindDB.relativePoint,
                    x = DidYouGrindDB.x,
                    y = DidYouGrindDB.y,
                    width = DidYouGrindDB.width,
                    height = DidYouGrindDB.height,
                }, DidYouGrindDB.globalLayout or {})
            end

            local migratedProfile = CopyDefaults(characterDefaults, DidYouGrindDB.characterProfiles[currentCharKey] or {})
            MigrateLegacyIntoCharacterProfile(migratedProfile, DidYouGrindDB)
            DidYouGrindDB.characterProfiles[currentCharKey] = migratedProfile
            RefreshActiveProfiles()
            if GetCharacterProfile().startMinimized then
                GetCharacterProfile().minimized = true
            end
            ApplyPosition()
            UpdateData()
            LayoutUI()
            mainFrame:Show()
        end
    elseif event == "QUEST_TURNED_IN" then
        if not IsProfileReady() then
            return
        end

        local questID = ...
        local title = nil
        if C_QuestLog and C_QuestLog.GetTitleForQuestID then
            title = C_QuestLog.GetTitleForQuestID(questID)
        end

        if IsKnownWeeklyBossTitle(title) then
            LearnWeeklyBossQuestID(questID, title)
        end

        if GetCharacterProfile().weeklyBossDebug then
            if title and title ~= "" then
                print("DidYouGrind WB Debug: QUEST_TURNED_IN questID=" .. tostring(questID) .. " title=\"" .. title .. "\"")
            else
                print("DidYouGrind WB Debug: QUEST_TURNED_IN questID=" .. tostring(questID))
            end
        end
    else
        if IsProfileReady() and mainFrame:IsShown() and GetCharacterProfile().autoRefresh then
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
    if not IsProfileReady() or not mainFrame:IsShown() or not GetCharacterProfile().autoRefresh then
        return
    end

    elapsed = elapsed + delta
    if elapsed > 5 then
        UpdateData()
        LayoutUI()
        elapsed = 0
    end
end)
