--------------------------------------------------------------------------------
--  DannerQuestLog: options panel (gear button on the window, or /dql options)
--  and the slash command.
--------------------------------------------------------------------------------
local _, ns = ...
local L = ns.L
local A = ns.ACCENT

local panel

-- { key, label, tooltip, onChange }
local CHECKS = {
    { "replaceQuestLog", "Replace the map quest log",
        "The quest log key and the quest log micro button open this window instead of the world map's quest log. The world map key still opens the map.",
        function() ns.ApplyReplacement() end },
    { "showLevels", "Show quest levels", "Prefix quest titles with their level, e.g. [24+]. A + marks elite / group quests." },
    { "showTags", "Show quest tags", "Show tags such as (Elite) or (Dungeon) after the title." },
    { "showXP", "Show quest experience", "Show the experience each quest rewards on the right of its row." },
    { "showPartyCount", "Show party members on quest", "Show [n] for the number of party members who have the quest." },
    { "restoreOnSelect", "Open details on select", "Selecting a quest opens the details pane when it is folded away." },
    { "minimizeOnClose", "Fold details on close", "Closing the window folds the details pane away." },
    { "hideCompletedObjectives", "Hide completed objectives", "Hide objectives that are already done in the details pane." },
    { "announceComplete", "Announce completed quests", "Show \"<quest> completed!\" on screen with a sound when a quest's objectives are all done." },
    { "autoComplete", "Auto turn-in quests", "Turn in completed quests automatically when talking to the quest giver, unless there is a reward to choose. Hold Shift to skip." },
}

local function Refresh()
    ns.ApplyLook()
    ns.QueueRefresh()
end

local function Create()
    panel = CreateFrame("Frame", "DannerQuestLogOptions", ns.frame, "BackdropTemplate")
    panel:SetSize(270, 470)
    panel:SetPoint("TOPLEFT", ns.frame, "TOPRIGHT", 4, 0)
    panel:SetFrameLevel(ns.frame:GetFrameLevel() + 20)
    panel:EnableMouse(true)
    ns.ThemedBackdrop(panel, "bg", 0.97)
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText(L.TITLE .. " " .. L.OPTIONS)
    ns.Themed(title, function(t) t:SetTextColor(A[1], A[2], A[3]) end)
    local close = ns.CreateIconButton(panel, 18, "x")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() panel:Hide() end)

    local y = -32
    panel.checks = {}
    for _, def in ipairs(CHECKS) do
        local key, label, tip, onChange = def[1], def[2], def[3], def[4]
        local cb = ns.CreateCheck(panel, label, tip)
        cb:SetPoint("TOPLEFT", 8, y)
        cb:SetScript("OnClick", function(self)
            ns.db[key] = self:GetChecked() and true or false
            if onChange then onChange() end
            Refresh()
        end)
        cb.key = key
        panel.checks[#panel.checks + 1] = cb
        y = y - 26
    end

    y = y - 6
    local scale = ns.CreateSlider(panel, "Scale", 0.6, 1.5, 0.05, 240)
    scale:SetPoint("TOPLEFT", 14, y)
    scale.slider:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v * 100 + 0.5) / 100
        scale.valueText:SetText(("%d%%"):format(v * 100))
        if ns.db.scale ~= v then
            ns.db.scale = v
            ns.ApplyLook()
        end
    end)
    panel.scale = scale
    y = y - 42

    local opacity = ns.CreateSlider(panel, "Background opacity", 0.2, 1, 0.05, 240)
    opacity:SetPoint("TOPLEFT", 14, y)
    opacity.slider:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v * 100 + 0.5) / 100
        opacity.valueText:SetText(("%d%%"):format(v * 100))
        if ns.db.opacity ~= v then
            ns.db.opacity = v
            ns.ApplyLook()
        end
    end)
    panel.opacity = opacity
    y = y - 46

    local resetGroups = ns.CreateButton(panel, "Reset quest groups", 130, 22)
    resetGroups:SetPoint("TOPLEFT", 14, y)
    resetGroups:SetScript("OnClick", function() ns.ResetAllGroups() end)
    resetGroups.tooltip = "Move every quest back to its original zone group."

    -- Theme switch (was a swatch on the title bar).
    local theme = ns.CreateButton(panel, "", 112, 22)
    theme:SetPoint("LEFT", resetGroups, "RIGHT", 6, 0)
    theme:SetScript("OnClick", function(self)
        ns.CycleTheme()
        if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
    end)
    ns.Themed(theme, function(self)
        local cur, nxt = ns.THEMES[ns.ThemeName()], ns.THEMES[ns.NextThemeName()]
        self:SetText(L.THEME_BUTTON:format(cur.name))
        self.tooltip = L.THEME_TOOLTIP:format(cur.name, nxt.name)
    end)
    y = y - 32

    -- Click help (was the "?" on the title bar).
    local help = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 14, y)
    help:SetWidth(240)
    help:SetJustifyH("LEFT")
    help:SetText(L.HELP_CLICKS)
    ns.Themed(help, function(t) t:SetTextColor(ns.COLORS.dim[1], ns.COLORS.dim[2], ns.COLORS.dim[3]) end)
    y = y - help:GetStringHeight() + 10

    panel:SetHeight(-y + 22 + 12)
    panel:SetScript("OnShow", function(self)
        for _, cb in ipairs(self.checks) do cb:SetChecked(ns.db[cb.key] and true or false) end
        self.scale.slider:SetValue(ns.db.scale or 1)
        self.opacity.slider:SetValue(ns.db.opacity or 0.95)
        -- Initial SetValue may not fire OnValueChanged when unchanged.
        self.scale.valueText:SetText(("%d%%"):format((ns.db.scale or 1) * 100))
        self.opacity.valueText:SetText(("%d%%"):format((ns.db.opacity or 0.95) * 100))
    end)
end

function ns.ToggleOptions()
    if not panel then Create() end
    panel:SetShown(not panel:IsShown())
end

function ns.HideOptions()
    if panel then panel:Hide() end
end

--------------------------------------------------------------------------------
--  Slash command
--------------------------------------------------------------------------------
SLASH_DANNERQUESTLOG1 = "/dql"
SLASH_DANNERQUESTLOG2 = "/dannerquestlog"
SlashCmdList.DANNERQUESTLOG = function(msg)
    msg = strtrim((msg or ""):lower())
    if msg == "" or msg == "toggle" then
        ns.Toggle()
    elseif msg == "options" or msg == "config" then
        ns.OpenWindow()
        ns.ToggleOptions()
    elseif msg == "theme" or msg == "dark" or msg == "standard" then
        if msg == "theme" then ns.CycleTheme() else ns.SetTheme(msg) end
        ns.Print("theme: " .. ns.THEMES[ns.ThemeName()].name)
    elseif msg == "replace" then
        ns.db.replaceQuestLog = not ns.db.replaceQuestLog
        ns.ApplyReplacement()
        ns.Print("replace map quest log: " .. (ns.db.replaceQuestLog and "on" or "off"))
    else
        ns.Print("/dql - toggle the quest log")
        ns.Print("/dql options - open the options")
        ns.Print("/dql replace - toggle replacing the map quest log")
        ns.Print("/dql theme - switch between the dark and standard colours")
    end
end
