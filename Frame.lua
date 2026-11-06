--------------------------------------------------------------------------------
--  DannerQuestLog: the window
--
--  EQL3's two-part window: the quest list on the left, and a details pane on
--  the right that can be folded away (EQL3's minimize / maximize switch).
--------------------------------------------------------------------------------
local _, ns = ...
local L = ns.L
local C = ns.COLORS
local AR, AG, AB = ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3]

local LIST_W = 340
local DETAIL_W = 380
local HEIGHT = 540
local TITLE_H = 26
local BAR_H = 28
local PAD = 8
local SCROLLBAR_W = 22

local frame
local buttons = {}
local lastDetailQuest

--------------------------------------------------------------------------------
--  Position and look
--------------------------------------------------------------------------------
local function SavePosition()
    local left, top = frame:GetLeft(), frame:GetTop()
    if left and top then ns.db.point = { left, top } end
end

function ns.RestorePosition()
    frame:ClearAllPoints()
    local p = ns.db.point
    if p and p[1] and p[2] then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2])
    else
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    end
end

function ns.ResetPosition()
    ns.db.point = nil
    ns.RestorePosition()
end

function ns.ApplyLook()
    if not frame then return end
    frame:SetScale(ns.db.scale or 1)
    frame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], ns.db.opacity or 0.95)
end

function ns.SetDetailsShown(show)
    ns.db.showDetails = show and true or false
    frame:SetWidth(LIST_W + (show and DETAIL_W or 0))
    ns.detailPane:SetShown(show)
    buttons.details.label:SetText(show and "<" or ">")
    buttons.details.tooltip = show and L.HIDE_DETAILS or L.SHOW_DETAILS
    if show then
        lastDetailQuest = nil
        ns.UpdateDetails()
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
    ns.SetButtonEnabled(buttons.track, has)
    buttons.track.label:SetText(has and ns.IsWatched(id) and L.UNTRACK or L.TRACK)
    buttons.collapse.label:SetText(ns.AllCollapsed() and "+" or "-")
    buttons.collapse.tooltip = ns.AllCollapsed() and L.EXPAND_ALL or L.COLLAPSE_ALL
    ns.countText:SetText(("%d/%d"):format(ns.log.numQuests, ns.MaxQuests()))
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
        frame:Hide()
    else
        frame:Show()
    end
end

function ns.Show(questID)
    if not frame then return end
    if questID then ns.selectedQuestID = questID end
    frame:Show()
    ns.Refresh()
    ns.ScrollToSelected()
end

--------------------------------------------------------------------------------
--  Create
--------------------------------------------------------------------------------
function ns.CreateWindow()
    if frame then return frame end
    frame = CreateFrame("Frame", "DannerQuestLogFrame", UIParent, "BackdropTemplate")
    ns.frame = frame
    frame:Hide()
    frame:SetSize(LIST_W + DETAIL_W, HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    ns.Backdrop(frame, C.bg[1], C.bg[2], C.bg[3], 0.95)
    tinsert(UISpecialFrames, "DannerQuestLogFrame")

    -- Title bar (drag handle)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(TITLE_H)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function()
        if not ns.db.locked then frame:StartMoving() end
    end)
    bar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        frame:SetUserPlaced(false)  -- our saved variables hold the position
        SavePosition()
        -- StartMoving re-anchors to the screen; restore our TOPLEFT anchor so
        -- folding the details pane keeps the left edge in place.
        ns.RestorePosition()
    end)
    local strip = ns.Solid(bar, "BACKGROUND", 0, 0, 0, 0.35)
    strip:SetAllPoints()
    local line = ns.Solid(bar, "BORDER", AR, AG, AB, 0.6)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)

    local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 10, 0)
    title:SetText(L.TITLE)
    title:SetTextColor(AR, AG, AB)
    ns.countText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ns.countText:SetPoint("LEFT", title, "RIGHT", 8, 0)
    ns.countText:SetTextColor(C.dim[1], C.dim[2], C.dim[3])

    local close = ns.CreateIconButton(bar, 18, "x")
    close:SetPoint("RIGHT", -4, 0)
    close:SetScript("OnClick", function() frame:Hide() end)
    close.tooltip = CLOSE

    local details = ns.CreateIconButton(bar, 18, "<")
    details:SetPoint("RIGHT", close, "LEFT", -3, 0)
    details:SetScript("OnClick", function() ns.SetDetailsShown(not ns.db.showDetails) end)
    buttons.details = details

    local options = ns.CreateIconButton(bar, 18, nil, "Interface\\Buttons\\UI-OptionsButton")
    options:SetPoint("RIGHT", details, "LEFT", -3, 0)
    options:SetScript("OnClick", function() ns.ToggleOptions() end)
    options.tooltip = L.OPTIONS

    local help = ns.CreateIconButton(bar, 18, "?")
    help:SetPoint("RIGHT", options, "LEFT", -3, 0)
    help.tooltip = L.HELP_CLICKS
    help:SetScript("OnClick", nil)

    -- List pane
    local listPane = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listPane:SetPoint("TOPLEFT", PAD, -(TITLE_H + PAD))
    listPane:SetPoint("BOTTOMLEFT", PAD, BAR_H + PAD)
    listPane:SetWidth(LIST_W - PAD * 2)
    ns.Backdrop(listPane, C.panel[1], C.panel[2], C.panel[3], 0.6)

    local collapse = ns.CreateIconButton(listPane, 20, "-")
    collapse:SetPoint("TOPLEFT", 4, -4)
    collapse:SetScript("OnClick", function() ns.SetAllCollapsed(not ns.AllCollapsed()) end)
    buttons.collapse = collapse

    local search = ns.CreateSearchBox(listPane)
    search:SetPoint("LEFT", collapse, "RIGHT", 10, 0)
    search:SetPoint("RIGHT", listPane, "TOPRIGHT", -6, -14)
    if search.Instructions then search.Instructions:SetText(L.SEARCH) end
    search:HookScript("OnTextChanged", function(self)
        ns.filterText = strtrim(self:GetText() or "")
        ns.UpdateList()
    end)
    search:HookScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local listInnerW = LIST_W - PAD * 2 - 8 - SCROLLBAR_W
    local listScroll, listChild = ns.CreateScroll(listPane, listInnerW)
    listScroll:SetPoint("TOPLEFT", 4, -30)
    listScroll:SetPoint("BOTTOMLEFT", 4, 4)
    listScroll:SetWidth(listInnerW)
    ns.listScroll, ns.listChild = listScroll, listChild

    ns.emptyText = listPane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ns.emptyText:SetPoint("CENTER")
    ns.emptyText:SetText(L.NO_QUESTS)
    ns.emptyText:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    ns.emptyText:Hide()

    -- Bottom bar
    local bw = math.floor((LIST_W - PAD * 2 - 8) / 3)
    local abandon = ns.CreateButton(frame, L.ABANDON, bw, 22)
    abandon:SetPoint("BOTTOMLEFT", PAD, PAD - 2)
    abandon:SetScript("OnClick", function()
        if ns.selectedQuestID then ns.Abandon(ns.selectedQuestID) end
    end)
    local share = ns.CreateButton(frame, L.SHARE, bw, 22)
    share:SetPoint("LEFT", abandon, "RIGHT", 4, 0)
    share:SetScript("OnClick", function()
        if ns.selectedQuestID then ns.Share(ns.selectedQuestID) end
    end)
    local track = ns.CreateButton(frame, L.TRACK, bw, 22)
    track:SetPoint("LEFT", share, "RIGHT", 4, 0)
    track:SetScript("OnClick", function()
        local id = ns.selectedQuestID
        if id then ns.SetWatched(id, not ns.IsWatched(id)) end
    end)
    buttons.abandon, buttons.share, buttons.track = abandon, share, track

    -- Details pane
    local detailPane = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    detailPane:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_W, -(TITLE_H + PAD))
    detailPane:SetPoint("BOTTOMRIGHT", -PAD, PAD - 2)
    ns.Backdrop(detailPane, C.panel[1], C.panel[2], C.panel[3], 0.6)
    ns.detailPane = detailPane
    local detailInnerW = DETAIL_W - PAD - 8 - SCROLLBAR_W
    local detailScroll = ns.CreateDetails(detailPane, detailInnerW)
    detailScroll:SetPoint("TOPLEFT", 4, -4)
    detailScroll:SetPoint("BOTTOMLEFT", 4, 4)
    detailScroll:SetWidth(detailInnerW)

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
        search:ClearFocus()
    end)

    ns.RestorePosition()
    ns.ApplyLook()
    ns.SetDetailsShown(ns.db.showDetails)
    return frame
end
