--------------------------------------------------------------------------------
--  DannerQuestLog: quest log model
--
--  Reads the game's quest log into groups (the game's zone headers, or a custom
--  group from the EQL3 organizer) and flattens them into list rows. Collapsing
--  is our own state, so the map's quest log is left as the player set it.
--------------------------------------------------------------------------------
local _, ns = ...
local L = ns.L

ns.log = { groups = {}, quests = {}, numQuests = 0, numEntries = 0 }
local expandedOnce = {}  -- game headers we have already expanded this session

--------------------------------------------------------------------------------
--  Per-quest helpers
--------------------------------------------------------------------------------
local function QuestXP(questID)
    if not GetQuestLogRewardXP then return 0 end
    return GetQuestLogRewardXP(questID) or 0
end

local function QuestTag(questID)
    if not C_QuestLog.GetQuestTagInfo then return end
    local info = C_QuestLog.GetQuestTagInfo(questID)
    if info and info.tagName and info.tagName ~= "" then return info.tagName end
end

function ns.IsWatched(questID)
    return C_QuestLog.GetQuestWatchType(questID) ~= nil
end

local function MaxWatches()
    local c = Constants and Constants.QuestWatchConsts
    return (c and c.MAX_QUEST_WATCHES) or 25
end

-- Returns false when the tracker is full.
function ns.SetWatched(questID, on)
    if on == ns.IsWatched(questID) then return true end
    if on then
        local max = MaxWatches()
        if C_QuestLog.GetNumQuestWatches() >= max then
            local msg = QUEST_WATCH_TOO_MANY and QUEST_WATCH_TOO_MANY:format(max) or "Too many quests tracked."
            UIErrorsFrame:AddMessage(msg, 1.0, 0.1, 0.1, 1.0)
            return false
        end
        C_QuestLog.AddQuestWatch(questID)
    else
        C_QuestLog.RemoveQuestWatch(questID)
    end
    return true
end

-- Ctrl-Shift-click (EQL3): clear the tracker, then track only this quest.
function ns.WatchOnly(questID)
    for i = C_QuestLog.GetNumQuestWatches(), 1, -1 do
        local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if id and id ~= questID then C_QuestLog.RemoveQuestWatch(id) end
    end
    ns.SetWatched(questID, true)
end

-- Shift-click on a group: track the whole group, or untrack it when every
-- quest in it is already tracked.
function ns.ToggleGroupWatch(group)
    local allWatched = true
    for _, q in ipairs(group.quests) do
        if not ns.IsWatched(q.questID) then allWatched = false break end
    end
    for _, q in ipairs(group.quests) do
        if not ns.SetWatched(q.questID, not allWatched) then break end
    end
end

function ns.PartyMembersOnQuest(questID)
    local names = {}
    if not IsInGroup() or IsInRaid() or not C_QuestLog.IsUnitOnQuest then return names end
    for i = 1, GetNumSubgroupMembers() do
        local unit = "party" .. i
        if UnitExists(unit) and C_QuestLog.IsUnitOnQuest(unit, questID) then
            names[#names + 1] = UnitName(unit)
        end
    end
    return names
end

function ns.CanShare(questID)
    return IsInGroup() and C_QuestLog.IsPushableQuest and C_QuestLog.IsPushableQuest(questID) and true or false
end

function ns.Share(questID)
    if not ns.CanShare(questID) or not QuestLogPushQuest then return end
    C_QuestLog.SetSelectedQuest(questID)
    QuestLogPushQuest()
end

StaticPopupDialogs["DANNERQUESTLOG_ABANDON"] = {
    text = L.ABANDON_CONFIRM,
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, questID)
        if not questID then return end
        C_QuestLog.SetSelectedQuest(questID)
        C_QuestLog.SetAbandonQuest()
        C_QuestLog.AbandonQuest()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
}

function ns.Abandon(questID)
    local title = C_QuestLog.GetTitleForQuestID(questID) or ""
    StaticPopup_Show("DANNERQUESTLOG_ABANDON", title, nil, questID)
end

-- Quest difficulty colour, as the game colours quest titles.
function ns.DifficultyColor(level)
    if GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(level or 0)
        if c then return c.r, c.g, c.b end
    end
    return 1, 0.82, 0
end

--------------------------------------------------------------------------------
--  Chat
--------------------------------------------------------------------------------
local function ActiveEditBox()
    if ChatFrameUtil and ChatFrameUtil.GetActiveWindow then
        return ChatFrameUtil.GetActiveWindow()
    end
    if ChatEdit_GetActiveWindow then return ChatEdit_GetActiveWindow() end
end
ns.ActiveEditBox = ActiveEditBox

function ns.InsertLink(link)
    if not link then return false end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then return ChatFrameUtil.InsertLink(link) end
    if ChatEdit_InsertLink then return ChatEdit_InsertLink(link) end
    return false
end

function ns.LinkQuest(questID)
    local link = GetQuestLink and GetQuestLink(questID)
    if link and ActiveEditBox() then
        ns.InsertLink(link)
        return true
    end
    if link and ChatFrameUtil and ChatFrameUtil.OpenChat then
        ChatFrameUtil.OpenChat(link)
        return true
    elseif link and ChatFrame_OpenChat then
        ChatFrame_OpenChat(link)
        return true
    end
    return false
end

-- Ctrl-click (EQL3): "(Complete) Title: 3/8 Kobold slain, ..." into chat.
function ns.InsertStatus(questID)
    local box = ActiveEditBox()
    if not box then return false end
    local text = C_QuestLog.GetTitleForQuestID(questID) or ""
    if C_QuestLog.IsComplete(questID) then text = "(" .. L.COMPLETE .. ") " .. text end
    local objectives = C_QuestLog.GetQuestObjectives(questID) or {}
    local parts = {}
    for _, o in ipairs(objectives) do
        if o.text and o.text ~= "" then parts[#parts + 1] = o.text end
    end
    if #parts > 0 then text = text .. ": " .. table.concat(parts, ", ") end
    box:Insert(text)
    return true
end

--------------------------------------------------------------------------------
--  Organizer (custom groups)
--------------------------------------------------------------------------------
function ns.MoveQuest(questID, groupName)
    local q = ns.log.quests[questID]
    if not q or not groupName or groupName == "" then return end
    if groupName == q.header then
        ns.cdb.groups[questID] = nil
    else
        ns.cdb.groups[questID] = groupName
    end
    ns.QueueRefresh()
end

function ns.ResetQuestGroup(questID)
    ns.cdb.groups[questID] = nil
    ns.QueueRefresh()
end

function ns.ResetAllGroups()
    wipe(ns.cdb.groups)
    ns.QueueRefresh()
end

--------------------------------------------------------------------------------
--  Build
--------------------------------------------------------------------------------
function ns.BuildLog()
    local groupsByName, order, quests = {}, {}, {}
    local function Group(name)
        local g = groupsByName[name]
        if not g then
            g = { name = name, quests = {} }
            groupsByName[name] = g
            order[#order + 1] = g
        end
        return g
    end

    local numEntries, numQuests = C_QuestLog.GetNumQuestLogEntries()
    local header = L.OTHER
    local toExpand
    local custom = ns.cdb.groups

    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then
                header = info.title or L.OTHER
                Group(header)
                -- A header collapsed in the map's quest log may hide its quests
                -- from the list; open it once so they show here.
                if info.isCollapsed and not expandedOnce[header] then
                    local nextInfo = C_QuestLog.GetInfo(i + 1)
                    if not nextInfo or nextInfo.isHeader then
                        expandedOnce[header] = true
                        toExpand = toExpand or {}
                        toExpand[#toExpand + 1] = i
                    end
                end
            elseif not info.isHidden and not info.isTask and not info.isBounty
                and info.questID and info.questID > 0 then
                local id = info.questID
                local q = {
                    questID = id,
                    logIndex = i,
                    title = info.title or "",
                    level = info.level or 0,
                    header = header,
                    suggestedGroup = info.suggestedGroup,
                    complete = C_QuestLog.IsComplete(id) == true,
                    failed = C_QuestLog.IsFailed and C_QuestLog.IsFailed(id) == true,
                    tag = QuestTag(id),
                    xp = QuestXP(id),
                    watched = ns.IsWatched(id),
                    custom = custom[id] ~= nil,
                }
                quests[id] = q
                local g = Group(custom[id] or header)
                g.quests[#g.quests + 1] = q
            end
        end
    end

    local groups = {}
    for _, g in ipairs(order) do
        if #g.quests > 0 then groups[#groups + 1] = g end
    end

    ns.log = {
        groups = groups,
        quests = quests,
        numQuests = numQuests or 0,
        numEntries = numEntries or 0,
    }

    if toExpand and C_QuestLog.ExpandQuestHeader then
        -- Bottom up so earlier indexes stay valid; the game sends
        -- QUEST_LOG_UPDATE afterwards, which rebuilds.
        for k = #toExpand, 1, -1 do C_QuestLog.ExpandQuestHeader(toExpand[k]) end
    end
    return ns.log
end

function ns.MaxQuests()
    if C_QuestLog.GetMaxNumQuestsCanAccept then
        local n = C_QuestLog.GetMaxNumQuestsCanAccept()
        if n and n > 0 then return n end
    end
    return MAX_QUESTLOG_QUESTS or 20
end

-- Flattens the groups into list rows. A search shows every match, ignoring
-- collapsed groups.
function ns.BuildRows(filter)
    local rows = {}
    filter = filter and filter ~= "" and filter:lower() or nil
    for _, g in ipairs(ns.log.groups) do
        local shown = g.quests
        if filter then
            shown = {}
            local groupMatch = g.name:lower():find(filter, 1, true)
            for _, q in ipairs(g.quests) do
                if groupMatch or q.title:lower():find(filter, 1, true) then
                    shown[#shown + 1] = q
                end
            end
        end
        if #shown > 0 then
            local collapsed = not filter and ns.cdb.collapsed[g.name] or false
            rows[#rows + 1] = { header = true, group = g, collapsed = collapsed, count = #shown }
            if not collapsed then
                for _, q in ipairs(shown) do
                    rows[#rows + 1] = { quest = q, group = g }
                end
            end
        end
    end
    return rows
end

function ns.AllCollapsed()
    for _, g in ipairs(ns.log.groups) do
        if not ns.cdb.collapsed[g.name] then return false end
    end
    return #ns.log.groups > 0
end

function ns.SetAllCollapsed(collapsed)
    for _, g in ipairs(ns.log.groups) do
        ns.cdb.collapsed[g.name] = collapsed or nil
    end
    ns.QueueRefresh()
end
