--------------------------------------------------------------------------------
--  DannerQuestLog: quest details (right pane)
--
--  Title, level/tag line, objectives summary, timer, objective list, required
--  money, description, then rewards (choices, items, spells, money, XP), laid
--  out top to bottom in one scroll child.
--------------------------------------------------------------------------------
local _, ns = ...
local L = ns.L
local C = ns.COLORS
local AR, AG, AB = ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3]

local PAD = 6
local ITEM_H = 38
local child, width
local strings = {}   -- pooled font strings
local items = {}     -- pooled reward buttons
local usedStrings, usedItems = 0, 0
local indent = 0     -- extra left inset for the objective lines
local timer = { expires = nil, fs = nil, elapsed = 0 }

local function CoinString(copper)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper)
    end
    if GetMoneyString then return GetMoneyString(copper) end
    return tostring(copper)
end

--------------------------------------------------------------------------------
--  Pools
--------------------------------------------------------------------------------
local function NextString(font)
    usedStrings = usedStrings + 1
    local fs = strings[usedStrings]
    if not fs then
        fs = child:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        strings[usedStrings] = fs
    end
    fs:SetFontObject(font or "GameFontHighlight")
    fs:SetTextColor(C.text[1], C.text[2], C.text[3])
    fs:SetWidth(width - PAD * 2 - indent)
    fs:SetWordWrap(true)
    fs:Show()
    return fs
end

local function Item_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.spellID then
        GameTooltip:SetSpellByID(self.spellID)
    else
        GameTooltip:SetQuestLogItem(self.kind, self.index, ns.selectedQuestID)
    end
    GameTooltip:Show()
end

local function Item_OnClick(self)
    if self.spellID then
        if IsModifiedClick("CHATLINK") and C_Spell and C_Spell.GetSpellLink then
            ns.InsertLink(C_Spell.GetSpellLink(self.spellID))
        end
        return
    end
    local link = GetQuestLogItemLink and GetQuestLogItemLink(self.kind, self.index)
    if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
end

local function NextItem()
    usedItems = usedItems + 1
    local b = items[usedItems]
    if not b then
        b = CreateFrame("Button", nil, child, "BackdropTemplate")
        ns.Backdrop(b, 0.12, 0.12, 0.13, 0.9)
        b:SetSize(math.floor((width - PAD * 2 - 4) / 2), ITEM_H)

        local iconHolder = CreateFrame("Frame", nil, b, "BackdropTemplate")
        iconHolder:SetSize(ITEM_H - 6, ITEM_H - 6)
        iconHolder:SetPoint("LEFT", 3, 0)
        ns.Backdrop(iconHolder, 0, 0, 0, 1)
        b.iconHolder = iconHolder
        b.icon = iconHolder:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1)
        b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        b.count = iconHolder:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        b.count:SetPoint("BOTTOMRIGHT", -1, 1)

        b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.name:SetPoint("LEFT", iconHolder, "RIGHT", 5, 0)
        b.name:SetPoint("RIGHT", -3, 0)
        b.name:SetJustifyH("LEFT")
        b.name:SetMaxLines(2)

        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", 1, -1)
        hl:SetPoint("BOTTOMRIGHT", -1, 1)
        hl:SetColorTexture(1, 1, 1, 0.08)

        b:SetScript("OnEnter", Item_OnEnter)
        b:SetScript("OnLeave", GameTooltip_Hide)
        b:SetScript("OnClick", Item_OnClick)
        items[usedItems] = b
    end
    b.kind, b.index, b.spellID = nil, nil, nil
    b:Show()
    return b
end

local function SetItem(b, name, texture, count, quality, isUsable)
    b.icon:SetTexture(texture)
    b.count:SetText((count and count > 1) and count or "")
    b.name:SetText(name or "")
    local r, g, bl = 1, 1, 1
    if quality and C_Item and C_Item.GetItemQualityColor then
        local qr, qg, qb = C_Item.GetItemQualityColor(quality)
        if qr then r, g, bl = qr, qg, qb end
    end
    b.name:SetTextColor(r, g, bl)
    if isUsable == false then
        b.icon:SetVertexColor(0.9, 0.2, 0.2)
    else
        b.icon:SetVertexColor(1, 1, 1)
    end
    if quality and quality > 1 and C_Item and C_Item.GetItemQualityColor then
        b.iconHolder:SetBackdropBorderColor(r, g, bl, 1)
    else
        b.iconHolder:SetBackdropBorderColor(0, 0, 0, 1)
    end
end

--------------------------------------------------------------------------------
--  Layout
--------------------------------------------------------------------------------
local y
local function Place(region, gap, height)
    y = y - (gap or 0)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", child, "TOPLEFT", PAD + indent, y)
    local h = height or region:GetHeight()
    if region.GetStringHeight then
        h = region:GetStringHeight()
        region:SetHeight(h)
    end
    y = y - h
end

local function Text(str, font, gap, r, g, b)
    local fs = NextString(font)
    fs:SetText(str)
    if r then fs:SetTextColor(r, g, b) end
    Place(fs, gap)
    return fs
end

local function Heading(str, gap)
    return Text(str, "GameFontNormalLarge", gap or 12, AR, AG, AB)
end

-- Two-column grid of reward buttons, starting below the current position.
local function ItemGrid(list)
    local colW = math.floor((width - PAD * 2 - 4) / 2)
    y = y - 4
    for i, entry in ipairs(list) do
        local b = NextItem()
        b.kind, b.index, b.spellID = entry.kind, entry.index, entry.spellID
        SetItem(b, entry.name, entry.texture, entry.count, entry.quality, entry.isUsable)
        local col = (i - 1) % 2
        local rowY = y - math.floor((i - 1) / 2) * (ITEM_H + 4)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", child, "TOPLEFT", PAD + col * (colW + 4), rowY)
    end
    local numRows = math.ceil(#list / 2)
    y = y - numRows * (ITEM_H + 4)
end

local function Rewards(questID)
    local choices, rewards, spells = {}, {}, {}

    local numChoices = GetNumQuestLogChoices and GetNumQuestLogChoices(questID, true) or 0
    for i = 1, numChoices do
        local name, texture, count, quality, isUsable = GetQuestLogChoiceInfo(i)
        if name or texture then
            choices[#choices + 1] = { kind = "choice", index = i, name = name, texture = texture,
                count = count, quality = quality, isUsable = isUsable }
        end
    end

    local numRewards = GetNumQuestLogRewards and GetNumQuestLogRewards(questID) or 0
    for i = 1, numRewards do
        local name, texture, count, quality, isUsable = GetQuestLogRewardInfo(i, questID)
        if name or texture then
            rewards[#rewards + 1] = { kind = "reward", index = i, name = name, texture = texture,
                count = count, quality = quality, isUsable = isUsable }
        end
    end

    if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardSpells then
        for _, spellID in ipairs(C_QuestInfoSystem.GetQuestRewardSpells(questID) or {}) do
            local info = C_QuestInfoSystem.GetQuestRewardSpellInfo
                and C_QuestInfoSystem.GetQuestRewardSpellInfo(questID, spellID)
            if info then
                spells[#spells + 1] = { spellID = spellID, name = info.name, texture = info.texture }
            end
        end
    end

    local money = GetQuestLogRewardMoney and GetQuestLogRewardMoney(questID) or 0
    local xp = GetQuestLogRewardXP and GetQuestLogRewardXP(questID) or 0

    if #choices + #rewards + #spells == 0 and money == 0 and xp == 0 then return end

    Heading(L.REWARDS, 14)
    if #choices > 0 then
        Text(L.REWARD_CHOICES, "GameFontHighlightSmall", 6)
        ItemGrid(choices)
    end
    if #rewards + #spells > 0 then
        Text(#choices > 0 and L.REWARD_ITEMS or L.REWARD_ITEMS_ONLY, "GameFontHighlightSmall", 6)
        local all = {}
        for _, e in ipairs(rewards) do all[#all + 1] = e end
        for _, e in ipairs(spells) do all[#all + 1] = e end
        ItemGrid(all)
    end
    if money > 0 then
        Text(L.MONEY .. " " .. CoinString(money), "GameFontHighlight", 6)
    end
    if xp > 0 then
        Text(L.EXPERIENCE .. " " .. (BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or xp), "GameFontHighlight", 4)
    end
end

local function TimeLeft(questID)
    if C_QuestLog.GetTimeAllowed then
        local total, elapsed = C_QuestLog.GetTimeAllowed(questID)
        if total and elapsed and total > 0 then return total - elapsed end
    end
end

--------------------------------------------------------------------------------
--  Update
--------------------------------------------------------------------------------
function ns.UpdateDetails(keepScroll)
    if not child or not ns.detailPane:IsShown() then return end
    for i = 1, usedStrings do strings[i]:Hide() end
    for i = 1, usedItems do items[i]:Hide() end
    usedStrings, usedItems = 0, 0
    timer.expires, timer.fs = nil, nil

    local id = ns.selectedQuestID
    local q = id and ns.log.quests[id]
    if not q then
        child:SetHeight(1)
        return
    end
    -- The reward and item-link calls read the game's selected quest.
    if C_QuestLog.GetSelectedQuest() ~= id then C_QuestLog.SetSelectedQuest(id) end
    y = -PAD

    -- Title and level line
    local title = q.title
    if q.failed then title = title .. " - (" .. L.FAILED .. ")" end
    Text(title, "GameFontNormalLarge", 0, 1, 0.82, 0)
    local sub = L.LEVEL .. " " .. q.level
    if q.tag then sub = sub .. "  " .. q.tag end
    if q.suggestedGroup and q.suggestedGroup > 1 then
        sub = sub .. "  (" .. q.suggestedGroup .. ")"
    end
    if q.complete then sub = sub .. "  |cff33ff33" .. L.COMPLETE .. "|r" end
    Text(sub, "GameFontHighlightSmall", 2, ns.DifficultyColor(q.level))

    -- Objectives summary and timer
    local description, objectivesText = GetQuestLogQuestText(q.logIndex)
    if objectivesText and objectivesText ~= "" then
        Text(objectivesText, "GameFontHighlight", 10)
    end
    local left = TimeLeft(id)
    if left then
        timer.fs = Text(L.TIME_REMAINING .. " " .. SecondsToTime(left), "GameFontHighlight", 8, 1, 0.82, 0)
        timer.expires = GetTime() + left
    end

    -- Objective lines
    local objectives = C_QuestLog.GetQuestObjectives(id) or {}
    local first = true
    indent = 8
    for _, o in ipairs(objectives) do
        local text = o.text
        if not text or text == "" then text = o.type or "" end
        if not (o.finished and ns.db.hideCompletedObjectives) then
            local gap = first and 10 or 2
            if o.finished then
                Text(text .. " (" .. L.COMPLETE .. ")", "GameFontHighlight", gap, C.dim[1], C.dim[2], C.dim[3])
            else
                Text(text, "GameFontHighlight", gap, 1, 1, 1)
            end
            first = false
        end
    end
    indent = 0

    -- Required money
    local reqMoney = (C_QuestLog.GetRequiredMoney and C_QuestLog.GetRequiredMoney(id))
        or (GetQuestLogRequiredMoney and GetQuestLogRequiredMoney()) or 0
    if reqMoney > 0 then
        local fs = Text(L.REQUIRED_MONEY .. " " .. CoinString(reqMoney), "GameFontHighlight", 8)
        if GetMoney() < reqMoney then fs:SetTextColor(1, 0.2, 0.2) end
    end

    -- Description
    if description and description ~= "" then
        Heading(L.DESCRIPTION)
        Text(description, "GameFontHighlight", 6)
    end

    Rewards(id)

    child:SetHeight(-y + PAD)
    if not keepScroll then ns.detailScroll:SetVerticalScroll(0) end
end

--------------------------------------------------------------------------------
--  Create
--------------------------------------------------------------------------------
function ns.CreateDetails(parent, paneWidth)
    local sf, c = ns.CreateScroll(parent, paneWidth)
    child, width = c, paneWidth
    ns.detailScroll = sf
    ns.detailChild = c
    -- Quest timer countdown.
    sf:HookScript("OnUpdate", function(_, elapsed)
        if not timer.expires then return end
        timer.elapsed = timer.elapsed + elapsed
        if timer.elapsed < 0.5 then return end
        timer.elapsed = 0
        local left = math.max(0, timer.expires - GetTime())
        timer.fs:SetText(L.TIME_REMAINING .. " " .. SecondsToTime(left))
    end)
    return sf
end
