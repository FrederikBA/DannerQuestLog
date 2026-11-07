--------------------------------------------------------------------------------
--  DannerQuestLog: the window
--
--  Laid out like the game's own quest log: a portrait frame titled "Quest
--  Log", a controls row ("All" collapse toggle, Track Quest, the quest count),
--  the quest list on the left, the selected quest's details on the right, and
--  Abandon / Share / Map / Close along the bottom. The details pane can be
--  folded away (EQL3's minimize / maximize switch).
--
--  The standard theme shows Blizzard's PortraitFrameTemplate chrome; the dark
--  theme hides it and draws a flat backdrop on the same layout instead.
--------------------------------------------------------------------------------
local _, ns = ...
local L = ns.L
local C = ns.COLORS
local A = ns.ACCENT
local TEX = ns.TEX

local LIST_W = 340
local DETAIL_W = 380
local HEIGHT = 540
local TOP_H = 62          -- title bar + controls row
local BOTTOM_H = 30       -- button row
local PAD = 6
local SCROLLBAR_W = 22
local CONTROLS_Y = -41    -- centre line of the controls row
local PORTRAIT_X = 60     -- controls start right of the portrait

local frame
local buttons = {}
local lastDetailQuest

--------------------------------------------------------------------------------
--  Position and look
--
--  The window is a standard UI panel (UIPanelWindows, like EQL3's own frame):
--  the game places it on the left, pushes it aside or closes it when the
--  character pane, spellbook, full screen map and so on open, and closes it on
--  Escape. It cannot be dragged. ShowUIPanel is refused for addon frames in
--  combat, so there we fall back to a plain Show at the default panel spot.
--------------------------------------------------------------------------------
UIPanelWindows["DannerQuestLogFrame"] = { area = "left", pushable = 1, whileDead = 1 }

local function DefaultAnchor()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
end

-- Re-run the panel layout after a size or scale change.
local function Relayout()
    if frame:IsShown() and not InCombatLockdown() and UpdateUIPanelPositions then
        UpdateUIPanelPositions(frame)
    end
end

function ns.OpenWindow()
    if frame:IsShown() then return end
    if InCombatLockdown() or not ShowUIPanel then
        frame:Show()
    else
        ShowUIPanel(frame)
    end
    if not frame:IsShown() then
        -- The panel manager refused it; show it on its own instead.
        DefaultAnchor()
        frame:Show()
    end
end

function ns.CloseWindow()
    if not frame:IsShown() then return end
    if InCombatLockdown() or not HideUIPanel then
        frame:Hide()
    else
        HideUIPanel(frame)
    end
    if frame:IsShown() then frame:Hide() end
end

-- The template's chrome pieces, shown in the standard theme only.
local function ChromeParts()
    local parts = {}
    for _, key in ipairs({ "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "portrait",
                           "PortraitFrame", "CloseButton" }) do
        if frame[key] then parts[#parts + 1] = frame[key] end
    end
    return parts
end

function ns.ApplyLook()
    if not frame then return end
    frame:SetScale(ns.db.scale or 1)
    local opacity = ns.db.opacity or 0.95
    local chrome = frame.hasChrome and C.blizzard
    for _, part in ipairs(ChromeParts()) do part:SetShown(chrome) end
    if frame.Bg then frame.Bg:SetAlpha(opacity) end
    if chrome then
        frame:SetBackdropColor(0, 0, 0, 0)
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    else
        frame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], opacity)
        frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
    end
    frame.flatStrip:SetShown(not chrome)
    frame.flatLine:SetShown(not chrome)
    frame.flatClose:SetShown(not chrome)
    -- Without the portrait the controls move to the left edge.
    buttons.collapse:ClearAllPoints()
    buttons.collapse:SetPoint("LEFT", frame, "TOPLEFT", chrome and PORTRAIT_X or PAD + 2, CONTROLS_Y)
    Relayout()
end

function ns.SetDetailsShown(show)
    ns.db.showDetails = show and true or false
    frame:SetWidth(LIST_W + (show and DETAIL_W or 0))
    Relayout()
    ns.detailPane:SetShown(show)
    -- Folded, the list's own buttons fill the bottom row; the X still closes.
    buttons.close:SetShown(show)
    buttons.details.label:SetText(show and "<" or ">")
    buttons.details.tooltip = show and L.HIDE_DETAILS or L.SHOW_DETAILS
    if show then
        lastDetailQuest = nil
        ns.UpdateDetails()
    end
end

-- Opens the world map at the quest (the game's own map quest log).
function ns.ShowOnMap(questID)
    if not questID then return end
    if InCombatLockdown() then
        ns.Print(ERR_NOT_IN_COMBAT or "You can't do that while in combat.")
        return
    end
    ns.CloseWindow()
    if QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(questID)
    elseif OpenWorldMap then
        local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        OpenWorldMap(mapID)
    elseif ToggleWorldMap then
        ToggleWorldMap()
    end
end

--------------------------------------------------------------------------------
--  State updates
--------------------------------------------------------------------------------
function ns.UpdateButtons()
    local id = ns.selectedQuestID
    local has = id and ns.log.quests[id] and true or false
    local canAbandon = has and (not C_QuestLog.CanAbandonQuest or C_QuestLog.CanAbandonQuest(id))
    ns.SetButtonEnabled(buttons.abandon, canAbandon)
    ns.SetButtonEnabled(buttons.share, has and ns.CanShare(id))
    ns.SetButtonEnabled(buttons.map, has)

    local track = buttons.track
    track:SetEnabled(has)
    track:SetChecked(has and ns.IsWatched(id) or false)
    local c = has and C.text or C.dim
    track.labelText:SetTextColor(c[1], c[2], c[3])

    local all = ns.AllCollapsed()
    ns.SetExpandMarker(buttons.collapse.marker, all)
    buttons.collapse.tooltip = all and L.EXPAND_ALL or L.COLLAPSE_ALL

    ns.countText:SetText(L.QUEST_COUNT:format(ns.log.numQuests, ns.MaxQuests()))
    local box = ns.countText:GetParent()
    box:SetWidth(math.ceil(ns.countText:GetStringWidth()) + 18)
end

local function FirstQuest()
    for _, g in ipairs(ns.log.groups) do
        if g.quests[1] then return g.quests[1].questID end
    end
end

local function UpdateDetailsFor(id)
    ns.UpdateDetails(id == lastDetailQuest)
    lastDetailQuest = id
end

function ns.Select(questID, fromClick)
    ns.selectedQuestID = questID
    if questID then C_QuestLog.SetSelectedQuest(questID) end
    if fromClick and not ns.db.showDetails and ns.db.restoreOnSelect then
        ns.SetDetailsShown(true)
    end
    ns.UpdateList()
    UpdateDetailsFor(questID)
    ns.UpdateButtons()
end

function ns.Refresh()
    if not (frame and frame:IsShown()) then return end
    ns.BuildLog()
    local sel = ns.selectedQuestID
    if not (sel and ns.log.quests[sel]) then
        sel = C_QuestLog.GetSelectedQuest()
        if not (sel and ns.log.quests[sel]) then sel = FirstQuest() end
        ns.selectedQuestID = sel
    end
    ns.UpdateList()
    UpdateDetailsFor(sel)
    ns.UpdateButtons()
end

function ns.Toggle()
    if not frame then return end
    if frame:IsShown() then
        ns.CloseWindow()
    else
        ns.OpenWindow()
    end
end

function ns.Show(questID)
    if not frame then return end
    if questID then ns.selectedQuestID = questID end
    ns.OpenWindow()
    ns.Refresh()
    ns.ScrollToSelected()
end

--------------------------------------------------------------------------------
--  Create
--------------------------------------------------------------------------------
local function CreateChromeFrame()
    local ok, f = pcall(CreateFrame, "Frame", "DannerQuestLogFrame", UIParent, "PortraitFrameTemplate")
    if ok and f then
        f.hasChrome = true
    else
        f = CreateFrame("Frame", "DannerQuestLogFrame", UIParent)
    end
    -- Flat backdrop for the dark theme (transparent under the chrome).
    ns.Backdrop(f, 0, 0, 0, 0)
    return f
end

local function SetupTitle()
    local title = (frame.TitleContainer and frame.TitleContainer.TitleText) or frame.TitleText
    if not title then
        title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -6)
    end
    if frame.SetTitle then frame:SetTitle(L.TITLE) else title:SetText(L.TITLE) end
    ns.Themed(title, function(t) t:SetTextColor(C.title[1], C.title[2], C.title[3]) end)

    -- Book portrait.
    local portrait = (frame.PortraitContainer and frame.PortraitContainer.portrait) or frame.portrait
    if portrait then
        local probe = frame:CreateTexture()
        local path = ns.TrySetTexture(probe, TEX.BOOK) and TEX.BOOK or TEX.BOOK_FALLBACK
        probe:Hide()
        if frame.SetPortraitToAsset then
            frame:SetPortraitToAsset(path)
        elseif SetPortraitToTexture then
            SetPortraitToTexture(portrait, path)
        else
            portrait:SetTexture(path)
        end
    end

    -- Dark theme title strip.
    local strip = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    strip:SetPoint("TOPLEFT", 1, -1)
    strip:SetPoint("TOPRIGHT", -1, -1)
    strip:SetHeight(23)
    local line = frame:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", strip, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT")
    line:SetHeight(1)
    ns.Themed(strip, function(s)
        local c = C.titleStrip
        s:SetColorTexture(c[1], c[2], c[3], c[4])
        line:SetColorTexture(A[1], A[2], A[3], 0.6)
    end)
    frame.flatStrip, frame.flatLine = strip, line
end

local function SetupTitleButtons()
    if frame.CloseButton then
        frame.CloseButton:SetScript("OnClick", function() ns.CloseWindow() end)
    end
    local flatClose = ns.CreateIconButton(frame, 18, "x")
    flatClose:SetPoint("TOPRIGHT", -4, -3)
    flatClose:SetScript("OnClick", function() ns.CloseWindow() end)
    flatClose.tooltip = CLOSE
    frame.flatClose = flatClose

    local options = ns.CreateIconButton(frame, 17, nil, "Interface\\Buttons\\UI-OptionsButton")
    options:SetPoint("TOPRIGHT", -28, -3)
    options:SetScript("OnClick", function() ns.ToggleOptions() end)
    options.tooltip = L.OPTIONS

    local details = ns.CreateIconButton(frame, 17, "<")
    details:SetPoint("RIGHT", options, "LEFT", -3, 0)
    details:SetScript("OnClick", function() ns.SetDetailsShown(not ns.db.showDetails) end)
    buttons.details = details
end

local function SetupControls()
    -- "All": collapse / expand every group.
    local collapse = CreateFrame("Button", nil, frame, "BackdropTemplate")
    collapse:SetSize(52, 22)
    ns.ThemedBackdrop(collapse, "panel", nil, "boxBorder")
    collapse.marker = ns.CreateExpandMarker(collapse, 16)
    collapse.marker.icon:SetPoint("LEFT", 4, 0)
    local hl = collapse:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(collapse.marker.icon)
    hl:SetTexture(TEX.EXPAND_HL)
    hl:SetBlendMode("ADD")
    local label = collapse:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", collapse.marker.icon, "RIGHT", 4, 0)
    label:SetText(L.ALL)
    ns.Themed(label, function(t) t:SetTextColor(A[1], A[2], A[3]) end)
    collapse:SetWidth(math.ceil(label:GetStringWidth()) + 34)
    collapse:SetScript("OnClick", function() ns.SetAllCollapsed(not ns.AllCollapsed()) end)
    collapse:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.tooltip or "", 1, 1, 1)
        GameTooltip:Show()
    end)
    collapse:SetScript("OnLeave", GameTooltip_Hide)
    buttons.collapse = collapse

    -- Track Quest.
    local track = ns.CreateCheck(frame, L.TRACK)
    track:SetSize(24, 24)
    track:SetPoint("LEFT", collapse, "RIGHT", 10, 0)
    track:SetScript("OnClick", function(self)
        local id = ns.selectedQuestID
        if id then
            ns.SetWatched(id, not ns.IsWatched(id))
        else
            self:SetChecked(false)
        end
    end)
    buttons.track = track

    -- Quest count box.
    local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box:SetSize(90, 22)
    box:SetPoint("RIGHT", frame, "TOPRIGHT", -PAD - 2, CONTROLS_Y)
    ns.ThemedBackdrop(box, "bg", 0.75, "boxBorder")
    ns.countText = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ns.countText:SetPoint("CENTER", 0, 0)
    ns.Themed(ns.countText, function(t) t:SetTextColor(A[1], A[2], A[3]) end)
end

local function SetupList()
    local listPane = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listPane:SetPoint("TOPLEFT", PAD, -TOP_H)
    listPane:SetPoint("BOTTOMLEFT", PAD, BOTTOM_H)
    listPane:SetWidth(LIST_W - PAD * 2)
    ns.ThemedBackdrop(listPane, "panel")

    local search = ns.CreateSearchBox(listPane)
    search:SetPoint("TOPLEFT", 10, -5)
    search:SetPoint("TOPRIGHT", -6, -5)
    if search.Instructions then search.Instructions:SetText(L.SEARCH) end
    search:HookScript("OnTextChanged", function(self)
        ns.filterText = strtrim(self:GetText() or "")
        ns.UpdateList()
    end)
    search:HookScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame.search = search

    local listInnerW = LIST_W - PAD * 2 - 6 - SCROLLBAR_W
    local listScroll, listChild = ns.CreateScroll(listPane, listInnerW)
    listScroll:SetPoint("TOPLEFT", 4, -30)
    listScroll:SetPoint("BOTTOMLEFT", 4, 4)
    listScroll:SetWidth(listInnerW)
    ns.listScroll, ns.listChild = listScroll, listChild

    ns.emptyText = listPane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ns.emptyText:SetPoint("CENTER")
    ns.emptyText:SetText(L.NO_QUESTS)
    ns.Themed(ns.emptyText, function(t) t:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end)
    ns.emptyText:Hide()
end

local function SetupBottomButtons()
    local gap = 2
    local bw = math.floor((LIST_W - PAD * 2 - gap * 2) / 3)
    local abandon = ns.CreateButton(frame, L.ABANDON_SHORT, bw, 22)
    abandon:SetPoint("BOTTOMLEFT", PAD, 4)
    abandon:SetScript("OnClick", function()
        if ns.selectedQuestID then ns.Abandon(ns.selectedQuestID) end
    end)
    local share = ns.CreateButton(frame, L.SHARE_SHORT, bw, 22)
    share:SetPoint("LEFT", abandon, "RIGHT", gap, 0)
    share:SetScript("OnClick", function()
        if ns.selectedQuestID then ns.Share(ns.selectedQuestID) end
    end)
    local map = ns.CreateButton(frame, L.MAP, bw, 22)
    map:SetPoint("LEFT", share, "RIGHT", gap, 0)
    map:SetScript("OnClick", function() ns.ShowOnMap(ns.selectedQuestID) end)
    map.tooltip = L.MAP_TOOLTIP
    local close = ns.CreateButton(frame, CLOSE or "Close", 96, 22)
    close:SetPoint("BOTTOMRIGHT", -PAD, 4)
    close:SetScript("OnClick", function() ns.CloseWindow() end)
    buttons.abandon, buttons.share, buttons.map, buttons.close = abandon, share, map, close
end

local function SetupDetails()
    local detailPane = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    detailPane:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_W - PAD + 4, -TOP_H)
    detailPane:SetPoint("BOTTOMRIGHT", -PAD, BOTTOM_H)
    ns.ThemedBackdrop(detailPane, "panel")
    ns.detailPane = detailPane

    -- Standard theme: the stone backdrop of the game's window art.
    local stone = detailPane:CreateTexture(nil, "BACKGROUND", nil, 1)
    stone:SetPoint("TOPLEFT", 1, -1)
    stone:SetPoint("BOTTOMRIGHT", -1, 1)
    if ns.TrySetTexture(stone, TEX.STONE, "REPEAT", "REPEAT") then
        stone:SetHorizTile(true)
        stone:SetVertTile(true)
    else
        stone:SetColorTexture(0.22, 0.22, 0.23, 1)
    end
    ns.Themed(stone, function(t) t:SetShown(C.detailBg == "stone") end)

    local paneW = DETAIL_W - 4
    local detailInnerW = paneW - 6 - SCROLLBAR_W
    local detailScroll = ns.CreateDetails(detailPane, detailInnerW)
    detailScroll:SetPoint("TOPLEFT", 4, -4)
    detailScroll:SetPoint("BOTTOMLEFT", 4, 4)
    detailScroll:SetWidth(detailInnerW)
end

function ns.CreateWindow()
    if frame then return frame end
    frame = CreateChromeFrame()
    ns.frame = frame
    frame:Hide()
    frame:SetSize(LIST_W + DETAIL_W, HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    -- Escape closes it even when it was opened outside the panel system.
    tinsert(UISpecialFrames, "DannerQuestLogFrame")

    SetupTitle()
    SetupTitleButtons()
    SetupControls()
    SetupList()
    SetupBottomButtons()
    SetupDetails()

    frame:SetScript("OnShow", function()
        if SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_OPEN then PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN) end
        lastDetailQuest = nil
        ns.Refresh()
        ns.ScrollToSelected()
    end)
    frame:SetScript("OnHide", function()
        if SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_CLOSE then PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE) end
        if ns.db.minimizeOnClose and ns.db.showDetails then ns.SetDetailsShown(false) end
        if ns.HideOptions then ns.HideOptions() end
        frame.search:ClearFocus()
    end)

    DefaultAnchor()
    ns.ApplyLook()
    ns.SetDetailsShown(ns.db.showDetails)
    return frame
end
