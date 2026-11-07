--------------------------------------------------------------------------------
--  DannerQuestLog: quest list (left pane)
--
--  Clicks follow EQL3:
--    click              select the quest (opens details if folded and the
--                       "open details on select" option is on)
--    shift-click        insert a quest link if chat is open, else track/untrack
--    ctrl-click         insert "(Complete) Title: objectives" if chat is open
--    ctrl-shift-click   clear the tracker and track only this quest
--    right-click        menu: track, share, link, move to group, abandon
--    group: click       collapse/expand; shift-click tracks/untracks the group
--------------------------------------------------------------------------------
local _, ns = ...
local L = ns.L
local C = ns.COLORS
local A = ns.ACCENT

local ROW_H = 18
ns.ROW_H = ROW_H
local HEADER_TEXT_X = 22  -- after the plus / minus marker
local QUEST_TEXT_X = 28   -- quests sit indented under their header
local rows = {}

--------------------------------------------------------------------------------
--  Menus
--------------------------------------------------------------------------------
StaticPopupDialogs["DANNERQUESTLOG_NEWGROUP"] = {
    text = L.NEW_GROUP_PROMPT,
    button1 = ACCEPT or OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 48,
    OnShow = function(self)
        local eb = self.GetEditBox and self:GetEditBox() or self.editBox
        if eb then
            eb:SetText("")
            eb:SetFocus()
        end
    end,
    OnAccept = function(self, questID)
        local eb = self.GetEditBox and self:GetEditBox() or self.editBox
        local name = eb and strtrim(eb:GetText() or "")
        if name and name ~= "" then ns.MoveQuest(questID, name) end
    end,
    EditBoxOnEnterPressed = function(self, questID)
        local name = strtrim(self:GetText() or "")
        if name ~= "" then ns.MoveQuest(questID, name) end
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

local function QuestMenu(owner, q)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local id = q.questID
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(q.title)
        local watched = ns.IsWatched(id)
        root:CreateButton(watched and L.UNTRACK or L.TRACK, function()
            ns.SetWatched(id, not watched)
        end)
        if ns.CanShare(id) then
            root:CreateButton(L.SHARE, function() ns.Share(id) end)
        end
        root:CreateButton(L.LINK, function() ns.LinkQuest(id) end)

        local move = root:CreateButton(L.MOVE)
        local current = ns.cdb.groups[id] or q.header
        local listed = { [current] = true }
        local function Add(name)
            if listed[name] then return end
            listed[name] = true
            move:CreateButton(name, function() ns.MoveQuest(id, name) end)
        end
        Add(q.header)
        for _, g in ipairs(ns.log.groups) do Add(g.name) end
        move:CreateDivider()
        move:CreateButton(L.NEW_GROUP, function()
            StaticPopup_Show("DANNERQUESTLOG_NEWGROUP", q.title, nil, id)
        end)
        if q.custom then
            root:CreateButton(L.RESET_GROUP, function() ns.ResetQuestGroup(id) end)
        end
        if next(ns.cdb.groups) then
            root:CreateButton(L.RESET_ALL_GROUPS, function() ns.ResetAllGroups() end)
        end
        root:CreateDivider()
        root:CreateButton("|cffff5555" .. L.ABANDON .. "|r", function() ns.Abandon(id) end)
    end)
end

local function GroupMenu(owner, group)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(group.name)
        root:CreateButton(L.TRACK_ALL, function()
            for _, q in ipairs(group.quests) do
                if not ns.SetWatched(q.questID, true) then break end
            end
        end)
        root:CreateButton(L.UNTRACK_ALL, function()
            for _, q in ipairs(group.quests) do ns.SetWatched(q.questID, false) end
        end)
        root:CreateDivider()
        root:CreateButton(L.COLLAPSE_ALL, function() ns.SetAllCollapsed(true) end)
        root:CreateButton(L.EXPAND_ALL, function() ns.SetAllCollapsed(false) end)
    end)
end

--------------------------------------------------------------------------------
--  Rows
--------------------------------------------------------------------------------
local function Row_OnClick(self, button)
    local data = self.data
    if not data then return end

    if data.header then
        local g = data.group
        if button == "RightButton" then
            GroupMenu(self, g)
        elseif IsShiftKeyDown() then
            ns.ToggleGroupWatch(g)
        elseif not ns.filterText or ns.filterText == "" then
            ns.cdb.collapsed[g.name] = (not ns.cdb.collapsed[g.name]) or nil
            ns.QueueRefresh()
        end
        return
    end

    local q = data.quest
    local id = q.questID
    if button == "RightButton" then
        ns.Select(id, true)
        QuestMenu(self, q)
        return
    end

    local shift, ctrl = IsShiftKeyDown(), IsControlKeyDown()
    if shift and ctrl then
        ns.WatchOnly(id)
    elseif shift then
        if not (ns.ActiveEditBox() and ns.LinkQuest(id)) then
            ns.SetWatched(id, not ns.IsWatched(id))
        end
    elseif ctrl then
        if not ns.InsertStatus(id) then ns.Select(id, true) end
    else
        ns.Select(id, true)
    end
end

local function Row_OnEnter(self)
    local data = self.data
    if not data or data.header then return end
    local q = data.quest
    local party = ns.PartyMembersOnQuest(q.questID)
    local truncated = self.text:IsTruncated()
    if not truncated and not IsInGroup() then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(q.title, ns.DifficultyColor(q.level))
    if IsInGroup() and not IsInRaid() then
        if #party > 0 then
            GameTooltip:AddLine(L.PARTY_ON, 1, 1, 1)
            for _, name in ipairs(party) do GameTooltip:AddLine(name, 1, 1, 0.6) end
        else
            GameTooltip:AddLine(L.PARTY_NONE, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function CreateRow(index)
    local child = ns.listChild
    local r = CreateFrame("Button", nil, child)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(index - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -(index - 1) * ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    r.band = ns.Solid(r, "BACKGROUND", 1, 1, 1, 0.05)
    r.band:SetAllPoints()
    r.sel = r:CreateTexture(nil, "BORDER")
    r.sel:SetAllPoints()
    r.selBar = ns.Solid(r, "ARTWORK", A[1], A[2], A[3], 1)
    r.selBar:SetPoint("TOPLEFT")
    r.selBar:SetPoint("BOTTOMLEFT")
    r.selBar:SetWidth(2)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)

    r.marker = ns.CreateExpandMarker(r, 14)
    r.marker.icon:SetPoint("LEFT", 3, 0)

    r.check = r:CreateTexture(nil, "OVERLAY")
    r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    r.check:SetSize(14, 14)
    r.check:SetPoint("LEFT", QUEST_TEXT_X - 15, 0)

    r.xp = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.xp:SetPoint("RIGHT", -4, 0)
    r.xp:SetJustifyH("RIGHT")

    r.tag = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.tag:SetPoint("RIGHT", r.xp, "LEFT", 0, 0)
    r.tag:SetJustifyH("RIGHT")

    r.party = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.party:SetPoint("RIGHT", r.tag, "LEFT", -3, 0)

    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("LEFT", QUEST_TEXT_X, 0)
    r.text:SetPoint("RIGHT", r.party, "LEFT", -4, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)

    r:SetScript("OnClick", Row_OnClick)
    r:SetScript("OnEnter", Row_OnEnter)
    r:SetScript("OnLeave", GameTooltip_Hide)
    return r
end

-- Selection bar: the game's quest title highlight tinted with the quest's
-- difficulty colour (standard), or an accent tint with a left bar (dark).
local function PaintSelection(r, cr, cg, cb)
    local sel = r.sel
    if C.selectByDifficulty then
        if ns.TrySetTexture(sel, ns.TEX.TITLE_HL) then
            sel:SetBlendMode("ADD")
            sel:SetVertexColor(cr, cg, cb, 0.9)
            return
        end
        sel:SetColorTexture(cr, cg, cb, 0.4)
    else
        sel:SetColorTexture(A[1], A[2], A[3], 0.22)
        r.selBar:SetColorTexture(A[1], A[2], A[3], 1)
    end
    sel:SetBlendMode("BLEND")
    sel:SetVertexColor(1, 1, 1, 1)
end

local function SetupHeader(r, data)
    r.band:SetShown(not C.blizzard)
    r.sel:Hide()
    r.selBar:Hide()
    r.check:Hide()
    if C.selectByDifficulty then
        ns.SetExpandMarker(r.marker, data.collapsed, C.header[1], C.header[2], C.header[3])
    else
        ns.SetExpandMarker(r.marker, data.collapsed)
    end
    r.text:SetFontObject("GameFontNormal")
    r.text:SetPoint("LEFT", HEADER_TEXT_X, 0)
    r.text:SetText(data.group.name)
    r.text:SetTextColor(C.header[1], C.header[2], C.header[3])
    r.party:SetText("")
    r.xp:SetText("")
    r.tag:SetText(C.headerCount and data.count or "")
    r.tag:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
end

local function SetupQuest(r, data)
    local db = ns.db
    local q = data.quest
    local selected = q.questID == ns.selectedQuestID

    r.band:Hide()
    r.marker.icon:Hide()
    r.marker.glyph:Hide()
    local cr, cg, cb = ns.DifficultyColor(q.level)
    r.sel:SetShown(selected)
    r.selBar:SetShown(selected and not C.selectByDifficulty)
    if selected then PaintSelection(r, cr, cg, cb) end
    r.check:SetShown(q.watched)

    local title = q.title
    if db.showLevels then
        local plus = (q.tag or (q.suggestedGroup and q.suggestedGroup > 1)) and "+" or ""
        title = "[" .. q.level .. plus .. "] " .. title
    end
    r.text:SetFontObject("GameFontHighlight")
    r.text:SetPoint("LEFT", QUEST_TEXT_X, 0)
    r.text:SetText(title)
    if selected and C.selectedText then
        cr, cg, cb = C.selectedText[1], C.selectedText[2], C.selectedText[3]
    end
    r.text:SetTextColor(cr, cg, cb)

    local tag
    if q.failed then
        tag = "|cffff3333(" .. L.FAILED .. ")|r"
    elseif q.complete then
        tag = "|cff33ff33(" .. L.COMPLETE .. ")|r"
    elseif db.showTags and q.tag then
        tag = "(" .. q.tag .. ")"
    end
    r.tag:SetText(tag or "")
    r.tag:SetTextColor(cr, cg, cb)

    local xp = db.showXP and q.xp or 0
    if xp > 0 then
        r.xp:SetText(" " .. (BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or xp) .. " xp")
    else
        r.xp:SetText("")
    end
    r.xp:SetTextColor(C.dim[1], C.dim[2], C.dim[3])

    local n = 0
    if db.showPartyCount and IsInGroup() and not IsInRaid() then
        n = #ns.PartyMembersOnQuest(q.questID)
    end
    r.party:SetText(n > 0 and ("[" .. n .. "]") or "")
    r.party:SetTextColor(cr, cg, cb)
end

function ns.UpdateList()
    if not ns.listChild then return end
    local data = ns.BuildRows(ns.filterText)
    ns.listRows = data
    for i, d in ipairs(data) do
        local r = rows[i]
        if not r then
            r = CreateRow(i)
            rows[i] = r
        end
        r.data = d
        if d.header then SetupHeader(r, d) else SetupQuest(r, d) end
        r:Show()
    end
    for i = #data + 1, #rows do
        rows[i].data = nil
        rows[i]:Hide()
    end
    ns.listChild:SetHeight(math.max(1, #data * ROW_H))
    ns.emptyText:SetShown(ns.log.numQuests == 0)
end

-- Scrolls the list so the selected quest's row is visible.
function ns.ScrollToSelected()
    local sf = ns.listScroll
    if not (sf and ns.listRows) then return end
    for i, d in ipairs(ns.listRows) do
        if d.quest and d.quest.questID == ns.selectedQuestID then
            local top = (i - 1) * ROW_H
            local view = sf:GetHeight()
            local cur = sf:GetVerticalScroll()
            if top < cur then
                sf:SetVerticalScroll(top)
            elseif top + ROW_H > cur + view then
                sf:SetVerticalScroll(math.min(top + ROW_H - view, sf:GetVerticalScrollRange()))
            end
            return
        end
    end
end
