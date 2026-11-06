--------------------------------------------------------------------------------
--  DannerQuestLog
--
--  WoW Forever port of Extended QuestLog 3 (EQL3, Daniel Rehn / Vividz reskin).
--  WoW Forever runs the modern engine, so its quest log lives inside the world
--  map (QuestMapFrame). This addon gives the quest log key and the quest log
--  micro button a standalone EQL3 style window instead: a quest list on the
--  left, the selected quest's details on the right, no map. The world map key
--  still opens the map (with Blizzard's own quest panel) as before.
--
--  Taint: nothing here touches QuestMapFrame or WorldMapFrame. The quest log
--  key is taken over with an override binding click (as EllesmereUI's classic
--  talent window does); the micro button reaches us through ToggleQuestLog,
--  which is replaced -- the micro button's OnClick calls it last, so nothing
--  secure runs after our code. Our window is a plain, unprotected frame.
--
--  Files: Core (setup, events, openers), Data (quest log model), Widgets (flat
--  look helpers), List (left pane), Details (right pane), Frame (window),
--  Options (settings panel + slash command).
--------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.PREFIX = "|cff0cd29fDannerQuestLog|r: "
ns.ACCENT = { 0.05, 0.82, 0.62 }

--------------------------------------------------------------------------------
--  Strings (English; Blizzard globals where the client has them)
--------------------------------------------------------------------------------
local L = {
    TITLE = QUEST_LOG or "Quest Log",
    TRACK = TRACK_QUEST or "Track Quest",
    UNTRACK = UNTRACK_QUEST or "Untrack Quest",
    SHARE = SHARE_QUEST or "Share Quest",
    ABANDON = ABANDON_QUEST or "Abandon Quest",
    ABANDON_CONFIRM = ABANDON_QUEST_CONFIRM or "Abandon \"%s\"?",
    COMPLETE = COMPLETE or "Complete",
    FAILED = FAILED or "Failed",
    NO_QUESTS = QUESTLOG_NO_QUESTS_TEXT or "You have no quests.",
    DESCRIPTION = QUEST_DESCRIPTION or "Description",
    REWARDS = QUEST_REWARDS or "Rewards",
    REWARD_CHOICES = REWARD_CHOICES or "You will be able to choose one of these rewards:",
    REWARD_ITEMS = REWARD_ITEMS or "You will also receive:",
    REWARD_ITEMS_ONLY = REWARD_ITEMS_ONLY or "You will receive:",
    REQUIRED_MONEY = REQUIRED_MONEY or "Required Money:",
    TIME_REMAINING = TIME_REMAINING or "Time remaining:",
    LEVEL = LEVEL or "Level",
    EXPERIENCE = "Experience:",
    MONEY = "Money:",
    OTHER = OTHER or "Other",
    LINK = "Link to Chat",
    MOVE = "Move to Group",
    NEW_GROUP = "New Group...",
    NEW_GROUP_PROMPT = "Move \"%s\" to a new group named:",
    RESET_GROUP = "Reset to Original Group",
    RESET_ALL_GROUPS = "Reset All Quest Groups",
    TRACK_ALL = "Track All in Group",
    UNTRACK_ALL = "Untrack All in Group",
    COLLAPSE_ALL = "Collapse All",
    EXPAND_ALL = "Expand All",
    SEARCH = SEARCH or "Search",
    OPTIONS = "Options",
    SHOW_DETAILS = "Show quest details",
    HIDE_DETAILS = "Hide quest details",
    QUEST_COMPLETED = "%s completed!",
    PARTY_ON = PARTY_QUEST_STATUS_ON or "Party members on quest:",
    PARTY_NONE = PARTY_QUEST_STATUS_NONE or "No party members on quest",
    HELP_CLICKS = "Shift-click: track / link to chat\nCtrl-click: post progress to chat\nCtrl-Shift-click: track only this quest\nRight-click: more options",
}
ns.L = L

--------------------------------------------------------------------------------
--  Saved variables
--------------------------------------------------------------------------------
ns.DEFAULTS = {
    replaceQuestLog = true,   -- quest log key + micro button open this window
    showLevels = true,        -- "[12+] Title"
    showTags = true,          -- (Elite) / (Complete) / (Failed) after the title
    showPartyCount = true,    -- "[2]" party members on the quest
    showDetails = true,       -- window state: details pane open (EQL3 maximized)
    restoreOnSelect = true,   -- selecting a quest opens the details pane
    minimizeOnClose = false,  -- closing the window folds the details pane
    hideCompletedObjectives = false,
    locked = false,
    scale = 1,
    opacity = 0.95,           -- background opacity
    announceComplete = false, -- "<quest> completed!" + sound
    autoComplete = false,     -- turn in completable quests (Shift skips)
    point = nil,              -- { left, top } in UIParent coordinates
}
ns.CHAR_DEFAULTS = {
    collapsed = {},  -- [groupName] = true
    groups = {},     -- [questID] = custom group name (the EQL3 organizer)
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = CopyDefaults(v, {})
            else
                dst[k] = v
            end
        end
    end
    return dst
end

function ns.Print(msg)
    print(ns.PREFIX .. msg)
end

--------------------------------------------------------------------------------
--  Events
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
local handlers = {}
local afterCombat = {}

function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        events:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

-- Runs fn now, or once combat ends (one pending call per key).
function ns.AfterCombat(key, fn)
    if not InCombatLockdown() then
        fn()
        return
    end
    afterCombat[key] = fn
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_REGEN_ENABLED" and not handlers[event] then
        events:UnregisterEvent("PLAYER_REGEN_ENABLED")
        local queued = afterCombat
        afterCombat = {}
        for _, fn in pairs(queued) do fn() end
        return
    end
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do list[i](event, ...) end
end)

-- Coalesces bursts of quest events into one repaint on the next frame.
local refreshQueued = false
function ns.QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        if ns.Refresh then ns.Refresh() end
    end)
end

--------------------------------------------------------------------------------
--  Openers: the quest log key and the micro button
--------------------------------------------------------------------------------
local TOGGLE_NAME = "DannerQuestLogToggle"
local toggleButton, boundKeys

-- The quest log key clicks our toggle while replaceQuestLog is on. Setting an
-- override fires UPDATE_BINDINGS itself, so unchanged keys are left alone.
function ns.BindKeys()
    if InCombatLockdown() then
        ns.AfterCombat("bind", ns.BindKeys)
        return
    end
    if not toggleButton then
        toggleButton = CreateFrame("Button", TOGGLE_NAME, UIParent)
        -- The client delivers the binding's click on key down or key up
        -- depending on its key-down setting; act on whichever comes first.
        toggleButton:RegisterForClicks("AnyUp", "AnyDown")
        toggleButton:SetScript("OnClick", function(self, _, down)
            if down then
                self.sawDown = true
                ns.Toggle()
            elseif self.sawDown then
                self.sawDown = false
            else
                ns.Toggle()
            end
        end)
        toggleButton:SetScript("OnEvent", function() ns.BindKeys() end)
    end
    local on = ns.db.replaceQuestLog
    if on then
        toggleButton:RegisterEvent("UPDATE_BINDINGS")
    else
        toggleButton:UnregisterAllEvents()
    end
    local keys = on and table.concat({ GetBindingKey("TOGGLEQUESTLOG") }, " ") or ""
    if keys == boundKeys then return end
    boundKeys = keys
    ClearOverrideBindings(toggleButton)
    for key in keys:gmatch("%S+") do
        SetOverrideBindingClick(toggleButton, true, key, TOGGLE_NAME)
    end
end

-- The micro button (and anything else) calls the global ToggleQuestLog.
local blizzardToggle
local function OurToggleQuestLog()
    ns.Toggle()
end

function ns.ApplyReplacement()
    if type(ToggleQuestLog) ~= "function" then return end
    if ns.db.replaceQuestLog then
        if ToggleQuestLog ~= OurToggleQuestLog then
            blizzardToggle = ToggleQuestLog
            ToggleQuestLog = OurToggleQuestLog
        end
    elseif blizzardToggle and ToggleQuestLog == OurToggleQuestLog then
        ToggleQuestLog = blizzardToggle
    end
    ns.BindKeys()
end

--------------------------------------------------------------------------------
--  EQL3 extras: completion notice and auto turn-in
--------------------------------------------------------------------------------
local completeState = {}  -- [questID] = true once seen complete
local baselined = false

local function ScanCompletions()
    local num = C_QuestLog.GetNumQuestLogEntries()
    local seen = {}
    for i = 1, num do
        local info = C_QuestLog.GetInfo(i)
        local id = info and not info.isHeader and info.questID
        if id and id > 0 then
            seen[id] = true
            local done = C_QuestLog.IsComplete(id) == true
            if done and not completeState[id] and baselined and ns.db.announceComplete then
                local msg = L.QUEST_COMPLETED:format(info.title or "")
                UIErrorsFrame:AddMessage(msg, 1.0, 0.82, 0.0, 1.0)
                if SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE then
                    PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
                end
            end
            completeState[id] = done or nil
        end
    end
    for id in pairs(completeState) do
        if not seen[id] then completeState[id] = nil end
    end
    -- The log is empty for a moment at login; only treat what is there once it
    -- has loaded as already known.
    if num > 0 then baselined = true end
end

--------------------------------------------------------------------------------
--  Startup
--------------------------------------------------------------------------------
ns.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON_NAME then return end
    DannerQuestLogDB = CopyDefaults(ns.DEFAULTS, DannerQuestLogDB or {})
    DannerQuestLogCharDB = CopyDefaults(ns.CHAR_DEFAULTS, DannerQuestLogCharDB or {})
    ns.db = DannerQuestLogDB
    ns.cdb = DannerQuestLogCharDB
end)

ns.On("PLAYER_LOGIN", function()
    ns.CreateWindow()
    ns.ApplyReplacement()
end)

local function OnQuestChange()
    ScanCompletions()
    ns.QueueRefresh()
end
ns.On("QUEST_LOG_UPDATE", OnQuestChange)
ns.On("QUEST_WATCH_LIST_CHANGED", ns.QueueRefresh)
ns.On("QUEST_ACCEPTED", ns.QueueRefresh)
ns.On("GROUP_ROSTER_UPDATE", ns.QueueRefresh)
ns.On("PLAYER_LEVEL_UP", ns.QueueRefresh)
ns.On("PLAYER_MONEY", ns.QueueRefresh)
ns.On("UNIT_QUEST_LOG_CHANGED", function(_, unit)
    if unit == "player" or (unit and unit:find("^party")) then ns.QueueRefresh() end
end)
ns.On("QUEST_REMOVED", function(_, questID)
    if questID and ns.cdb then ns.cdb.groups[questID] = nil end
    ns.QueueRefresh()
end)

ns.On("QUEST_PROGRESS", function()
    if not ns.db.autoComplete or IsShiftKeyDown() then return end
    if IsQuestCompletable() then CompleteQuest() end
end)
ns.On("QUEST_COMPLETE", function()
    if not ns.db.autoComplete or IsShiftKeyDown() then return end
    -- Only when there is nothing to choose (one choice is taken as is).
    local choices = GetNumQuestChoices()
    if choices <= 1 then GetQuestReward(choices) end
end)
