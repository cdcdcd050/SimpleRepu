local ADDON_NAME, SR = ...
local LDB = LibStub("LibDataBroker-1.1")
local LibQTip = LibStub("LibQTip-1.0")
local isKoKR = (GetLocale() == "koKR")
local _GetMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local VERSION = _GetMeta and _GetMeta(ADDON_NAME, "Version") or "unknown"

-- ============================================================
-- Constants
-- ============================================================
local FRAME_WIDTH = 420
local ROW_HEIGHT = 18
local HEADER_HEIGHT = 20
local DUNGEON_HEIGHT = 14
local TITLE_HEIGHT = 24
local PADDING = 10
local CONTENT_WIDTH = FRAME_WIDTH - PADDING * 2

local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
local POPUP_BACKDROP = {
    bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local BAR_HEIGHT = 3

local defaults = {
    minimapPos = 180,
    popupPos = nil,
    collapsedCategories = {},
}

-- ============================================================
-- State
-- ============================================================
local sessionData = {}
local sessionReady = false
local popup
local allRows, usedRows = {}, 0
local demoMode = false
local demoData = {}

-- Forward declarations
local RefreshPopup, TogglePopup, UpdateLDB

-- ============================================================
-- Helpers
-- ============================================================
local function L(en, kr)
    if isKoKR and kr then return kr end
    return en
end

local function GetStandingLabel(standingID)
    return _G["FACTION_STANDING_LABEL" .. (standingID or 4)] or UNKNOWN
end

local function GetStandingColor(standingID)
    local c = SR.STANDING_COLORS[standingID]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function GenerateDemoData()
    wipe(demoData)
    local presets = {
        [946]  = { standing = 6, current = 8500,  maximum = 12000 }, -- Honor Hold
        [947]  = { standing = 5, current = 4200,  maximum = 6000 },  -- Thrallmar
        [942]  = { standing = 7, current = 15600, maximum = 21000 }, -- Cenarion Expedition
        [1011] = { standing = 5, current = 2100,  maximum = 6000 },  -- Lower City
        [935]  = { standing = 4, current = 1800,  maximum = 3000 },  -- The Sha'tar
        [989]  = { standing = 8, current = 999,   maximum = 999 },   -- Keepers of Time
        [932]  = { standing = 6, current = 5500,  maximum = 12000 }, -- The Aldor
        [934]  = { standing = 3, current = 1500,  maximum = 3000 },  -- The Scryers
        [1012] = { standing = 4, current = 500,   maximum = 3000 },  -- Ashtongue Deathsworn
        [990]  = { standing = 5, current = 3000,  maximum = 6000 },  -- The Scale of the Sands
        [967]  = { standing = 7, current = 18200, maximum = 21000 }, -- The Violet Eye
    }
    for id, p in pairs(presets) do
        local barMin = 0
        local barMax = p.maximum
        local barValue = p.current
        -- Try to get localized name from API, fall back to name_en
        local apiName = GetFactionInfoByID(id)
        local name = apiName
        if not name then
            for _, f in ipairs(SR.FACTIONS) do
                if f.id == id then name = f.name_en; break end
            end
        end
        demoData[id] = {
            name = name or ("Faction " .. id),
            standingID = p.standing,
            current = p.current,
            maximum = p.maximum,
            percent = p.current / p.maximum,
            barValue = barValue,
        }
    end
end

local function GetFactionData(factionID)
    if demoMode and demoData[factionID] then
        return demoData[factionID]
    end
    local name, _, standingID, barMin, barMax, barValue = GetFactionInfoByID(factionID)
    if not name then return nil end
    local current = barValue - barMin
    local maximum = barMax - barMin
    if maximum <= 0 then maximum = 1 end
    return {
        name = name,
        standingID = standingID,
        current = current,
        maximum = maximum,
        percent = current / maximum,
        barValue = barValue,
    }
end

local function IsFactionRelevant(faction)
    if demoMode then return true end
    local pf = UnitFactionGroup("player")
    if faction.alliance and pf ~= "Alliance" then return false end
    if faction.horde and pf ~= "Horde" then return false end
    return true
end

local function ApplyColor(tex, r, g, b, a)
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a or 1)
    else
        tex:SetTexture(r, g, b, a or 1)
    end
end

-- ============================================================
-- Session Tracking (relative value based, like Broker_Everything)
-- ============================================================
local function UpdateSession(factionID, repData)
    if not repData or not sessionReady then return end
    local s = sessionData[factionID]
    if not s then
        sessionData[factionID] = {
            standingID = repData.standingID,
            value = repData.current,
            max = repData.maximum,
            diff = 0,
        }
    else
        -- Handle standing change: adjust baseline for new standing range
        if s.standingID ~= repData.standingID then
            s.standingID = repData.standingID
            s.value = repData.current - s.max
            s.max = repData.maximum
        end
        -- Only update diff when value actually changed
        if repData.current ~= s.value then
            s.diff = repData.current - s.value
        end
    end
end

local function GetSessionDiff(factionID)
    local s = sessionData[factionID]
    return s and s.diff ~= 0 and s.diff or nil
end

local function ResetSession()
    wipe(sessionData)
    -- Re-initialize baselines with current values
    for _, faction in ipairs(SR.FACTIONS) do
        if IsFactionRelevant(faction) then
            local repData = GetFactionData(faction.id)
            if repData then
                UpdateSession(faction.id, repData)
            end
        end
    end
    if RefreshPopup then RefreshPopup() end
    if UpdateLDB then UpdateLDB() end
end

local function UpdateAllSessions()
    for _, faction in ipairs(SR.FACTIONS) do
        if IsFactionRelevant(faction) then
            local repData = GetFactionData(faction.id)
            if repData then
                UpdateSession(faction.id, repData)
            end
        end
    end
end

-- ============================================================
-- Row Pool
-- ============================================================
local function ReleaseAllRows()
    for i = 1, usedRows do
        allRows[i]:Hide()
        allRows[i]:ClearAllPoints()
        allRows[i]:SetScript("OnMouseUp", nil)
        allRows[i]:SetScript("OnEnter", nil)
        allRows[i]:SetScript("OnLeave", nil)
        allRows[i].standingText:SetText("")
    end
    usedRows = 0
end

local function AcquireRow(parent)
    usedRows = usedRows + 1
    if allRows[usedRows] then
        allRows[usedRows]:SetParent(parent)
        allRows[usedRows]:Show()
        return allRows[usedRows]
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function() if popup then popup:StartMoving() end end)
    row:SetScript("OnDragStop", function()
        if popup then
            popup:StopMovingOrSizing()
            local point, _, relPoint, x, y = popup:GetPoint()
            SimpleRepuDB.popupPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)

    -- Bar background (thin gauge at bottom of row)
    row.barBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.barBg:SetHeight(BAR_HEIGHT)
    row.barBg:SetPoint("BOTTOMLEFT", 0, 0)
    row.barBg:SetPoint("BOTTOMRIGHT", 0, 0)
    ApplyColor(row.barBg, 0.2, 0.2, 0.2, 0.6)

    -- Bar fill (thin gauge at bottom of row)
    row.barFill = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    row.barFill:SetHeight(BAR_HEIGHT)
    row.barFill:SetPoint("BOTTOMLEFT", 0, 0)
    row.barFill:SetWidth(1)

    -- Left text
    row.leftText = row:CreateFontString(nil, "OVERLAY")
    row.leftText:SetFontObject(GameTooltipText)
    row.leftText:SetPoint("LEFT", 6, 0)
    row.leftText:SetJustifyH("LEFT")
    row.leftText:SetWordWrap(false)

    -- Right text (value, far right, fixed width)
    row.rightText = row:CreateFontString(nil, "OVERLAY")
    row.rightText:SetFontObject(GameTooltipText)
    row.rightText:SetPoint("RIGHT", -6, 0)
    row.rightText:SetJustifyH("RIGHT")
    row.rightText:SetWidth(90)

    -- Standing text (right-aligned, left of value)
    row.standingText = row:CreateFontString(nil, "OVERLAY")
    row.standingText:SetFontObject(GameTooltipText)
    row.standingText:SetPoint("RIGHT", row.rightText, "LEFT", -10, 0)
    row.standingText:SetJustifyH("LEFT")

    allRows[usedRows] = row
    return row
end

-- ============================================================
-- Row Setup
-- ============================================================
local function SetupHeader(row, cat, isCollapsed)
    row:SetHeight(HEADER_HEIGHT)
    row.barBg:Hide()
    row.barFill:Hide()
    local arrow = isCollapsed and "|cffaaaaaa\226\150\182 " or "|cffffff00\226\150\188 " -- ▶ / ▼
    row.leftText:SetFontObject(GameFontNormal)
    row.leftText:SetText(arrow .. L(cat.en, cat.kr) .. "|r")
    row.leftText:SetWidth(CONTENT_WIDTH)
    row.rightText:SetText("")
    row.standingText:SetText("")
    row:SetScript("OnMouseUp", function()
        SimpleRepuDB.collapsedCategories[cat.key] = not SimpleRepuDB.collapsedCategories[cat.key] or nil
        RefreshPopup()
    end)
    row:SetScript("OnEnter", function(self)
        row.leftText:SetTextColor(1, 1, 1)
    end)
    row:SetScript("OnLeave", function(self)
        row.leftText:SetTextColor(1, 0.82, 0)
    end)
end

local function SetupFaction(row, faction, repData)
    row:SetHeight(ROW_HEIGHT)

    local factionName = repData and repData.name or faction.name_en

    row.leftText:SetFontObject(GameTooltipText)
    row.leftText:SetWidth(CONTENT_WIDTH * 0.55)

    if repData then
        local standing = GetStandingLabel(repData.standingID)
        local r, g, b = GetStandingColor(repData.standingID)

        row.leftText:SetText(factionName)
        row.standingText:SetText("|cffaaaaaa" .. standing .. "|r")

        if repData.standingID == 8 then
            row.rightText:SetText("")
        else
            local diff = GetSessionDiff(faction.id)
            if diff and diff > 0 then
                row.rightText:SetText(string.format("|cff44ff44%d|r / %d", repData.current, repData.maximum))
            else
                row.rightText:SetText(string.format("%d / %d", repData.current, repData.maximum))
            end
        end

        -- Progress bar (thin gauge at bottom)
        if repData.standingID < 8 then
            row.barBg:Show()
            row.barFill:Show()
            ApplyColor(row.barBg, 0.25, 0.25, 0.25, 0.8)
            ApplyColor(row.barFill, r, g, b, 0.8)
            row.barFill:SetWidth(math.max(1, CONTENT_WIDTH * repData.percent))
        else
            row.barBg:Hide()
            row.barFill:Hide()
        end

        -- Hover tooltip
        if repData.standingID < 8 then
            local factionID = faction.id
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(repData.name, 1, 1, 1)
                local need = repData.maximum - repData.current
                GameTooltip:AddDoubleLine(L("Need for next standing", "다음 평판까지 필요"), tostring(need), 0.7, 0.7, 0.7, 1, 1, 1)
                local diff = GetSessionDiff(factionID)
                if diff then
                    local prefix = diff > 0 and "+" or ""
                    local cr, cg, cb = 0.27, 1, 0.27
                    if diff < 0 then cr, cg, cb = 1, 0.27, 0.27 end
                    GameTooltip:AddDoubleLine(L("Gained", "획득"), prefix .. diff, 0.7, 0.7, 0.7, cr, cg, cb)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        else
            row:SetScript("OnEnter", nil)
            row:SetScript("OnLeave", nil)
        end
    else
        row.leftText:SetText(factionName)
        row.standingText:SetText("")
        row.rightText:SetText("|cff808080" .. L("Not discovered", "미발견") .. "|r")
        row.barBg:Hide()
        row.barFill:Hide()
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
    end
end

local function SetupSubInfo(row, faction)
    row:SetHeight(DUNGEON_HEIGHT)
    row.barBg:Hide()
    row.barFill:Hide()
    row.standingText:SetText("")

    local parts = {}
    for _, d in ipairs(faction.dungeons) do
        table.insert(parts, L(d.en, d.kr))
    end
    if faction.items then
        for _, item in ipairs(faction.items) do
            table.insert(parts, L(item.en, item.kr))
        end
    end

    row.leftText:SetFontObject(GameFontDisableSmall)
    row.leftText:SetText("    |cff888888" .. table.concat(parts, ", ") .. "|r")
    row.leftText:SetWidth(CONTENT_WIDTH - 12)
    row.rightText:SetText("")
end

-- ============================================================
-- Popup Frame
-- ============================================================
local function CreatePopup()
    local f = CreateFrame("Frame", "SimpleRepuPopup", UIParent, backdropTemplate)
    f:SetWidth(FRAME_WIDTH)
    f:SetHeight(300)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    if f.SetBackdrop then
        f:SetBackdrop(POPUP_BACKDROP)
        f:SetBackdropColor(0.08, 0.08, 0.12, 1)
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end

    -- Title bar
    f.titleBar = CreateFrame("Frame", nil, f)
    f.titleBar:SetHeight(TITLE_HEIGHT)
    f.titleBar:SetPoint("TOPLEFT", PADDING, -PADDING)
    f.titleBar:SetPoint("TOPRIGHT", -PADDING - 24, -PADDING)

    f.titleText = f.titleBar:CreateFontString(nil, "OVERLAY")
    f.titleText:SetFontObject(GameFontNormal)
    f.titleText:SetPoint("LEFT", 2, 0)
    f.titleText:SetText("|cff00ccff" .. L("Simple Repu", "평판 가이드") .. " v" .. VERSION .. "|r")

    f.titleSep = f:CreateTexture(nil, "ARTWORK")
    f.titleSep:SetHeight(1)
    f.titleSep:SetPoint("TOPLEFT", PADDING, -(PADDING + TITLE_HEIGHT + 2))
    f.titleSep:SetPoint("TOPRIGHT", -PADDING, -(PADDING + TITLE_HEIGHT + 2))
    ApplyColor(f.titleSep, 0.4, 0.4, 0.5, 0.6)

    -- Close button
    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.closeBtn:SetPoint("TOPRIGHT", -1, -1)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Drag save helper
    local function SavePopupPos(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        SimpleRepuDB.popupPos = { point = point, relPoint = relPoint, x = x, y = y }
    end

    -- Dragging (frame body)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", SavePopupPos)

    -- Title bar also draggable
    f.titleBar:EnableMouse(true)
    f.titleBar:RegisterForDrag("LeftButton")
    f.titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    f.titleBar:SetScript("OnDragStop", function() SavePopupPos(f) end)

    -- ESC to close
    tinsert(UISpecialFrames, "SimpleRepuPopup")

    return f
end

RefreshPopup = function()
    if not popup or not popup:IsShown() then return end

    ReleaseAllRows()

    local yOffset = -(PADDING + TITLE_HEIGHT + 6)

    for _, cat in ipairs(SR.CATEGORIES) do
        -- Check if category has relevant factions
        local hasRelevant = false
        for _, faction in ipairs(SR.FACTIONS) do
            if faction.category == cat.key and IsFactionRelevant(faction) then
                hasRelevant = true
                break
            end
        end

        if hasRelevant then
            local isCollapsed = SimpleRepuDB.collapsedCategories[cat.key]

            -- Category header
            local hRow = AcquireRow(popup)
            SetupHeader(hRow, cat, isCollapsed)
            hRow:SetPoint("TOPLEFT", popup, "TOPLEFT", PADDING, yOffset)
            hRow:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -PADDING, yOffset)
            yOffset = yOffset - HEADER_HEIGHT - 2

            if not isCollapsed then
                for _, faction in ipairs(SR.FACTIONS) do
                    if faction.category == cat.key and IsFactionRelevant(faction) then
                        local repData = GetFactionData(faction.id)
                        if repData then
                            UpdateSession(faction.id, repData)
                        end

                        -- Faction row
                        local fRow = AcquireRow(popup)
                        SetupFaction(fRow, faction, repData)
                        fRow:SetPoint("TOPLEFT", popup, "TOPLEFT", PADDING, yOffset)
                        fRow:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -PADDING, yOffset)
                        yOffset = yOffset - ROW_HEIGHT - 1

                        -- Dungeon / item sub-row
                        local hasSubInfo = #faction.dungeons > 0 or (faction.items and #faction.items > 0)
                        if repData and repData.standingID < 8 and hasSubInfo then
                            local dRow = AcquireRow(popup)
                            SetupSubInfo(dRow, faction)
                            dRow:SetPoint("TOPLEFT", popup, "TOPLEFT", PADDING, yOffset)
                            dRow:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -PADDING, yOffset)
                            yOffset = yOffset - DUNGEON_HEIGHT - 1
                        end
                    end
                end
            end

            yOffset = yOffset - 4 -- gap between categories
        end
    end

    -- Footer hint
    yOffset = yOffset - 2
    local hintRow = AcquireRow(popup)
    hintRow:SetHeight(14)
    hintRow.barBg:Hide()
    hintRow.barFill:Hide()
    hintRow.leftText:SetFontObject(GameFontDisableSmall)
    hintRow.leftText:SetText("|cff666666" .. L("Help: eomma-so", "도움: 엄마소") .. "|r")
    hintRow.leftText:SetWidth(CONTENT_WIDTH)
    hintRow.rightText:SetText("")
    hintRow:SetPoint("TOPLEFT", popup, "TOPLEFT", PADDING, yOffset)
    hintRow:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -PADDING, yOffset)
    yOffset = yOffset - 14

    popup:SetHeight(-yOffset + PADDING)
end

TogglePopup = function()
    if popup and popup:IsShown() then
        popup:Hide()
        return
    end

    if not popup then
        popup = CreatePopup()
    end

    popup:ClearAllPoints()
    local pos = SimpleRepuDB and SimpleRepuDB.popupPos
    if pos then
        popup:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        popup:SetPoint("CENTER")
    end

    popup:Show()
    RefreshPopup()
end

-- ============================================================
-- Tooltip (LibQTip — minimap / LDB hover)
-- ============================================================
local activeTooltip = nil
local subTooltip = nil

local function GetSubTooltip()
    if not subTooltip then
        subTooltip = CreateFrame("GameTooltip", "SimpleRepuSubTooltip", UIParent, "GameTooltipTemplate")
        subTooltip:SetFrameStrata("TOOLTIP")
    end
    return subTooltip
end

local function HideTooltip()
    if subTooltip then subTooltip:Hide() end
    if activeTooltip then
        LibQTip:Release(activeTooltip)
        activeTooltip = nil
    end
end

local function OnLineEnter(self, data)
    local faction = data.faction
    local repData = data.repData
    if not faction then return end

    local st = GetSubTooltip()
    st:SetOwner(activeTooltip, "ANCHOR_NONE")
    st:ClearAllPoints()
    st:SetPoint("TOPLEFT", activeTooltip, "TOPRIGHT", 4, 0)

    local name = repData and repData.name or faction.name_en
    st:AddLine(name, 1, 1, 1)

    if repData and repData.standingID < 8 then
        local need = repData.maximum - repData.current
        st:AddDoubleLine(L("Need for next standing", "다음 평판까지 필요"), tostring(need), 0.7, 0.7, 0.7, 1, 1, 1)
    end

    local diff = GetSessionDiff(faction.id)
    if diff then
        local prefix = diff > 0 and "+" or ""
        local cr, cg, cb = 0.27, 1, 0.27
        if diff < 0 then cr, cg, cb = 1, 0.27, 0.27 end
        st:AddDoubleLine(L("Gained", "획득"), prefix .. diff, 0.7, 0.7, 0.7, cr, cg, cb)
    end

    if #faction.dungeons > 0 then
        st:AddLine(" ")
        for _, d in ipairs(faction.dungeons) do
            local dr, dg, db = 1, 1, 1
            if d.raid then dr, dg, db = 1, 0.4, 0.4 end
            st:AddLine("  " .. L(d.en, d.kr), dr, dg, db)
        end
    end

    st:Show()
end

local function OnLineLeave()
    if subTooltip then subTooltip:Hide() end
end

local function ShowQTip(anchor)
    HideTooltip()

    local tt = LibQTip:Acquire("SimpleRepuTooltip", 3, "LEFT", "LEFT", "RIGHT")
    activeTooltip = tt

    tt:AddHeader("|cff00ccff" .. L("Simple Repu", "평판 가이드") .. " v" .. VERSION .. "|r")
    tt:AddSeparator()

    for _, cat in ipairs(SR.CATEGORIES) do
        local hasRelevant = false
        for _, faction in ipairs(SR.FACTIONS) do
            if faction.category == cat.key and IsFactionRelevant(faction) then
                hasRelevant = true
                break
            end
        end

        if hasRelevant then
            tt:AddLine(" ")
            local line = tt:AddLine()
            tt:SetCell(line, 1, "|cffd4a017" .. L(cat.en, cat.kr) .. "|r", nil, "LEFT", 3)

            for _, faction in ipairs(SR.FACTIONS) do
                if faction.category == cat.key and IsFactionRelevant(faction) then
                    local repData = GetFactionData(faction.id)
                    local factionName = repData and repData.name or faction.name_en

                    if repData then
                        local standing = GetStandingLabel(repData.standingID)
                        local r, g, b = GetStandingColor(repData.standingID)
                        local standingHex = string.format("|cff%02x%02x%02x", r*255, g*255, b*255)

                        local valueStr = ""
                        if repData.standingID < 8 then
                            local diff = GetSessionDiff(faction.id)
                            if diff and diff > 0 then
                                valueStr = string.format("|cff44ff44%d|r / %d", repData.current, repData.maximum)
                            else
                                valueStr = string.format("%d / %d", repData.current, repData.maximum)
                            end
                        end

                        line = tt:AddLine(
                            "  " .. factionName,
                            standingHex .. standing .. "|r",
                            valueStr
                        )
                    else
                        line = tt:AddLine(
                            "  |cff808080" .. factionName .. "|r",
                            "",
                            "|cff808080" .. L("Not discovered", "미발견") .. "|r"
                        )
                    end

                    tt:SetLineScript(line, "OnEnter", OnLineEnter, { faction = faction, repData = repData })
                    tt:SetLineScript(line, "OnLeave", OnLineLeave)
                end
            end
        end
    end

    tt:SetAutoHideDelay(0.25, anchor, function()
        if subTooltip then subTooltip:Hide() end
    end)
    tt:SmartAnchorTo(anchor)
    tt:Show()
end

-- ============================================================
-- LDB Data Object
-- ============================================================
UpdateLDB = function()
    -- no-op for now; text is static
end

local dataObj = LDB:NewDataObject("SimpleRepu", {
    type = "data source",
    text = L("Simple Repu", "평판 가이드"),
    label = L("Simple Repu", "평판 가이드"),
    icon = "Interface\\Icons\\Achievement_Reputation_01",
    OnEnter = function(self)
        ShowQTip(self)
    end,
    OnLeave = function(self)
        -- LibQTip handles auto-hide
    end,
    OnClick = function(self, button)
        if button == "LeftButton" then
            TogglePopup()
        end
    end,
})

-- ============================================================
-- Event Frame, Minimap Button, Slash Commands
-- ============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Init saved variables
        if not SimpleRepuDB then
            SimpleRepuDB = CopyTable(defaults)
        end
        for k, v in pairs(defaults) do
            if SimpleRepuDB[k] == nil then
                SimpleRepuDB[k] = type(v) == "table" and CopyTable(v) or v
            end
        end
        if type(SimpleRepuDB.collapsedCategories) ~= "table" then
            SimpleRepuDB.collapsedCategories = {}
        end

        -- Delay session init until faction data is stable
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        -- Register UPDATE_FACTION for real-time updates
        self:RegisterEvent("UPDATE_FACTION")

        -- Slash commands
        SLASH_SIMPLEREPU1 = "/sr"
        SLASH_SIMPLEREPU2 = "/simplerepu"
        SlashCmdList["SIMPLEREPU"] = function(msg)
            msg = (msg or ""):trim():lower()
            if msg == "reset" then
                ResetSession()
                print("|cff00ccff[SimpleRepu]|r " .. L("Session reset.", "세션이 초기화되었습니다."))
            elseif msg == "demo" then
                demoMode = not demoMode
                if demoMode then
                    GenerateDemoData()
                    wipe(sessionData)
                    -- Fake session diffs for demo
                    sessionData[942]  = { standingID = 7, value = 15600 - 350, max = 21000, diff = 350 }
                    sessionData[967]  = { standingID = 7, value = 18200 - 120, max = 21000, diff = 120 }
                    sessionData[1011] = { standingID = 5, value = 2100 - 75,   max = 6000,  diff = 75 }
                    print("|cff00ccff[SimpleRepu]|r " .. L("Demo mode ON", "데모 모드 켜짐"))
                else
                    wipe(demoData)
                    wipe(sessionData)
                    UpdateAllSessions()
                    print("|cff00ccff[SimpleRepu]|r " .. L("Demo mode OFF", "데모 모드 꺼짐"))
                end
                if not popup or not popup:IsShown() then
                    TogglePopup()
                else
                    RefreshPopup()
                end
            else
                TogglePopup()
            end
        end

        -- ======== Minimap Button ========
        local minimapBtn = CreateFrame("Button", "SimpleRepuMinimapBtn", Minimap)
        minimapBtn:SetSize(32, 32)
        minimapBtn:SetFrameStrata("MEDIUM")
        minimapBtn:SetFrameLevel(8)
        minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

        local bg = minimapBtn:CreateTexture(nil, "BACKGROUND")
        bg:SetSize(24, 24)
        bg:SetPoint("CENTER", 0, 0)
        bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

        local overlay = minimapBtn:CreateTexture(nil, "OVERLAY")
        overlay:SetSize(54, 54)
        overlay:SetPoint("TOPLEFT")
        overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

        local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(25, 25)
        icon:SetPoint("CENTER", 0, 0)
        icon:SetTexture("Interface\\Icons\\Achievement_Reputation_01")

        local function UpdateMinimapPos()
            local angle = math.rad(SimpleRepuDB.minimapPos)
            minimapBtn:ClearAllPoints()
            minimapBtn:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(angle), 80 * math.sin(angle))
        end
        UpdateMinimapPos()

        minimapBtn:RegisterForDrag("RightButton")
        minimapBtn:RegisterForClicks("LeftButtonUp")

        minimapBtn:SetScript("OnClick", function()
            TogglePopup()
        end)

        minimapBtn:SetScript("OnEnter", function(btn)
            ShowQTip(btn)
        end)
        minimapBtn:SetScript("OnLeave", function()
            -- LibQTip handles auto-hide
        end)

        minimapBtn:SetScript("OnDragStart", function(btn)
            btn:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local cx, cy = GetCursorPosition()
                local scale = Minimap:GetEffectiveScale()
                cx, cy = cx / scale, cy / scale
                SimpleRepuDB.minimapPos = math.deg(math.atan2(cy - my, cx - mx))
                UpdateMinimapPos()
            end)
        end)
        minimapBtn:SetScript("OnDragStop", function(btn)
            btn:SetScript("OnUpdate", nil)
        end)

        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Faction data is now stable; initialize session baselines
        sessionReady = true
        UpdateAllSessions()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

    elseif event == "UPDATE_FACTION" then
        UpdateAllSessions()
        RefreshPopup()
    end
end)
