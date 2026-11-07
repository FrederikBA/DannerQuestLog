--------------------------------------------------------------------------------
--  DannerQuestLog: themes and widgets.
--
--  "standard" is the game's own window look: Blizzard's portrait frame chrome,
--  red panel buttons, a stone backdrop behind the details with the quest fonts
--  in light colours. "dark" is the flat Vividz / EllesmereUI look (1px borders,
--  accent colour).
--------------------------------------------------------------------------------
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"

--------------------------------------------------------------------------------
--  Themes
--
--  ns.COLORS and ns.ACCENT are updated in place, so code that reads them while
--  painting always sees the active theme. Widgets that are coloured once at
--  creation register a painter with ns.Themed to be recoloured on a switch.
--------------------------------------------------------------------------------
ns.THEMES = {
    standard = {
        name = "Standard",
        blizzard = true,             -- Blizzard frame chrome and panel buttons
        accent = { 1, 0.82, 0 },
        bg = { 0, 0, 0 },
        panel = { 0, 0, 0, 0.7 },
        border = { 0.33, 0.27, 0.16, 1 },
        button = { 0.42, 0.04, 0.02, 1 },
        buttonHover = { 0.58, 0.07, 0.04, 1 },
        buttonText = { 1, 0.82, 0 },
        titleStrip = { 0, 0, 0, 0 },
        title = { 1, 1, 1 },
        header = { 0.75, 0.75, 0.75 },
        headerCount = false,
        text = { 1, 1, 1 },
        dim = { 0.5, 0.5, 0.5 },
        boxBorder = { 0.62, 0.50, 0.24, 1 },
        selectByDifficulty = true,   -- bar tinted with the quest's own colour
        selectedText = { 1, 1, 1 },  -- the game whitens the selected title
        detailBg = "stone",
        questFonts = true,           -- Morpheus headings, quest body font
        detailTitle = { 1, 0.86, 0.56 },
        detailHeading = { 1, 0.86, 0.56 },
        detailText = { 0.94, 0.94, 0.94 },
        detailObjective = { 0.94, 0.94, 0.94 },
        detailDim = { 0.62, 0.62, 0.62 },
        detailLevelByDifficulty = false,
        good = "33ff33",
        bad = { 1, 0.25, 0.25 },
        itemBg = { 0, 0, 0, 0.55 },
    },
    dark = {
        name = "Dark",
        blizzard = false,
        accent = { 0.05, 0.82, 0.62 },
        bg = { 0.06, 0.06, 0.07 },
        panel = { 0.10, 0.10, 0.11, 0.6 },
        border = { 0, 0, 0, 1 },
        button = { 0.15, 0.15, 0.16, 1 },
        buttonHover = { 0.22, 0.22, 0.24, 1 },
        buttonText = { 1, 1, 1 },
        titleStrip = { 0, 0, 0, 0.35 },
        title = "accent",
        header = { 1, 1, 1 },
        headerCount = true,
        text = { 0.88, 0.88, 0.88 },
        dim = { 0.55, 0.55, 0.55 },
        boxBorder = { 0, 0, 0, 1 },
        selectByDifficulty = false,  -- accent tint + accent bar on the left
        selectedText = nil,          -- keep the difficulty colour
        detailBg = nil,
        questFonts = false,
        detailTitle = { 1, 0.82, 0 },
        detailHeading = "accent",
        detailText = { 0.88, 0.88, 0.88 },
        detailObjective = { 1, 1, 1 },
        detailDim = { 0.55, 0.55, 0.55 },
        detailLevelByDifficulty = true,
        good = "33ff33",
        bad = { 1, 0.2, 0.2 },
        itemBg = { 0.12, 0.12, 0.13, 0.9 },
    },
}
ns.THEME_ORDER = { "standard", "dark" }
ns.DEFAULT_THEME = "standard"

ns.COLORS = {}
local C = ns.COLORS
local A = ns.ACCENT
local painters = {}

local function Copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = x end
    return t
end

local function LoadTheme(name)
    local t = ns.THEMES[name] or ns.THEMES[ns.DEFAULT_THEME]
    for k in pairs(C) do C[k] = nil end
    for k, v in pairs(t) do C[k] = Copy(v) end
    for _, k in ipairs({ "detailHeading", "title" }) do
        if C[k] == "accent" then C[k] = Copy(t.accent) end
    end
    A[1], A[2], A[3] = t.accent[1], t.accent[2], t.accent[3]
end
LoadTheme(ns.DEFAULT_THEME)

function ns.ThemeName()
    local name = ns.db and ns.db.theme
    return (name and ns.THEMES[name]) and name or ns.DEFAULT_THEME
end

-- Runs fn(obj) now and again whenever the theme changes.
function ns.Themed(obj, fn)
    painters[#painters + 1] = { obj, fn }
    fn(obj)
end

function ns.SetTheme(name)
    if not ns.THEMES[name] then name = ns.DEFAULT_THEME end
    if ns.db then ns.db.theme = name end
    LoadTheme(name)
    for i = 1, #painters do painters[i][2](painters[i][1]) end
    if ns.ApplyLook then ns.ApplyLook() end
    if ns.Refresh then ns.Refresh() end
end

function ns.NextThemeName()
    local cur = ns.ThemeName()
    for i, name in ipairs(ns.THEME_ORDER) do
        if name == cur then return ns.THEME_ORDER[i % #ns.THEME_ORDER + 1] end
    end
    return ns.DEFAULT_THEME
end

function ns.CycleTheme()
    ns.SetTheme(ns.NextThemeName())
end

--------------------------------------------------------------------------------
--  Textures
--------------------------------------------------------------------------------
ns.TEX = {
    MINUS = "Interface\\Buttons\\UI-MinusButton-Up",
    PLUS = "Interface\\Buttons\\UI-PlusButton-Up",
    EXPAND_HL = "Interface\\Buttons\\UI-PlusButton-Hilight",
    TITLE_HL = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight",
    STONE = "Interface\\FrameGeneral\\UI-Background-Rock",
    BOOK = "Interface\\QuestFrame\\UI-QuestLog-BookIcon",
    BOOK_FALLBACK = "Interface\\Icons\\INV_Misc_Book_09",
}

-- SetTexture returns false for a file the client does not have.
function ns.TrySetTexture(tex, path, ...)
    return tex:SetTexture(path, ...) and true or false
end

--------------------------------------------------------------------------------
--  Widgets
--------------------------------------------------------------------------------
function ns.Backdrop(frame, r, g, b, a)
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(r or C.panel[1], g or C.panel[2], b or C.panel[3], a or C.panel[4])
    frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
end

-- Backdrop that follows the theme: fill from C[key] (alpha overridable).
function ns.ThemedBackdrop(frame, key, alpha, borderKey)
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    ns.Themed(frame, function(f)
        local c = C[key]
        local e = C[borderKey or "border"]
        f:SetBackdropColor(c[1], c[2], c[3], alpha or c[4] or 1)
        f:SetBackdropBorderColor(e[1], e[2], e[3], e[4] or 1)
    end)
end

function ns.Solid(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- The art of a UIPanelButtonTemplate button: shown in the standard theme,
-- faded out for the flat one.
local function SetTemplateArt(b, show)
    local a = show and 1 or 0
    for _, k in ipairs({ "Left", "Middle", "Right" }) do
        if b[k] and b[k].SetAlpha then b[k]:SetAlpha(a) end
    end
    if b.NineSlice then b.NineSlice:SetAlpha(a) end
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local t = b[get] and b[get](b)
        if t then t:SetAlpha(a) end
    end
end

local function UsesTemplate(b)
    return b.blizz and C.blizzard
end

local function PaintButton(b)
    if UsesTemplate(b) then
        SetTemplateArt(b, true)
        b:SetBackdropColor(0, 0, 0, 0)
        b:SetBackdropBorderColor(0, 0, 0, 0)
    else
        if b.blizz then SetTemplateArt(b, false) end
        b:SetBackdropColor(C.button[1], C.button[2], C.button[3], C.button[4])
        b:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
    end
    if b:IsEnabled() then
        b.label:SetTextColor(C.buttonText[1], C.buttonText[2], C.buttonText[3])
    else
        b.label:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    end
end

local function Button_OnEnter(self)
    if self:IsEnabled() and not UsesTemplate(self) then
        self:SetBackdropColor(C.buttonHover[1], C.buttonHover[2], C.buttonHover[3], C.buttonHover[4])
        self:SetBackdropBorderColor(A[1], A[2], A[3], 0.8)
    end
    if self.tooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.tooltip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end
end

local function Button_OnLeave(self)
    PaintButton(self)
    GameTooltip_Hide()
end

-- Text button: the game's red panel button in the standard theme, flat in the
-- dark one. flatOnly skips the Blizzard art (small icon buttons).
function ns.CreateButton(parent, text, width, height, flatOnly)
    local b
    if not flatOnly then
        local ok, made = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate,BackdropTemplate")
        if ok and made then
            b = made
            b.blizz = true
        end
    end
    if not b then b = CreateFrame("Button", nil, parent, "BackdropTemplate") end
    b:SetSize(width or 80, height or 22)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    if b.blizz then
        b:SetText(text or "")
        b.label = b:GetFontString() or b.Text
    end
    if not b.label then
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("CENTER")
        fs:SetText(text or "")
        b:SetFontString(fs)
        b.label = fs
    end
    ns.Themed(b, PaintButton)
    b:SetScript("OnEnter", Button_OnEnter)
    b:SetScript("OnLeave", Button_OnLeave)
    return b
end

-- Enable/disable a button, greying its text while disabled.
function ns.SetButtonEnabled(b, on)
    b:SetEnabled(on and true or false)
    PaintButton(b)
end

-- Small square button with a text glyph or a texture.
function ns.CreateIconButton(parent, size, glyph, texture)
    local b = ns.CreateButton(parent, glyph or "", size, size, true)
    b.label:SetFontObject("GameFontNormal")
    PaintButton(b)
    if texture then
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOPLEFT", 3, -3)
        t:SetPoint("BOTTOMRIGHT", -3, 3)
        t:SetTexture(texture)
        b.icon = t
    end
    return b
end

-- Expand / collapse marker: the game's plus / minus button art in the
-- standard theme, an accent "+" / "-" glyph in the dark one.
function ns.CreateExpandMarker(parent, size)
    local m = {}
    m.icon = parent:CreateTexture(nil, "OVERLAY")
    m.icon:SetSize(size, size)
    m.glyph = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    m.glyph:SetPoint("CENTER", m.icon, "CENTER")
    return m
end

function ns.SetExpandMarker(m, collapsed, r, g, b)
    if C.blizzard then
        m.icon:SetTexture(collapsed and ns.TEX.PLUS or ns.TEX.MINUS)
        m.icon:Show()
        m.glyph:Hide()
    else
        m.icon:Hide()
        m.glyph:SetText(collapsed and "+" or "-")
        m.glyph:SetTextColor(r or A[1], g or A[2], b or A[3])
        m.glyph:Show()
    end
end

-- Scroll frame with a scroll child of fixed width.
function ns.CreateScroll(parent, childWidth)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(childWidth, 1)
    sf:SetScrollChild(child)
    sf.child = child
    -- Flat theme: a dark track behind the bar.
    local bar = sf.ScrollBar
    if bar then
        local track = ns.Solid(bar, "BACKGROUND", 0, 0, 0, 0.35)
        track:SetPoint("TOPLEFT", 0, 16)
        track:SetPoint("BOTTOMRIGHT", 0, -16)
        ns.Themed(track, function(t) t:SetShown(not C.blizzard) end)
    end
    return sf, child
end

-- Checkbox with a label (own label: template field names vary by client).
function ns.CreateCheck(parent, label, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    fs:SetText(label)
    cb.labelText = fs
    if cb.Text then cb.Text:SetText("") end
    if cb.text then cb.text:SetText("") end
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end
    return cb
end

-- Flat horizontal slider with a label and value readout.
function ns.CreateSlider(parent, label, minV, maxV, step, width)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width or 200, 34)

    local title = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)
    local value = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("TOPRIGHT", 0, 0)
    holder.valueText = value

    local s = CreateFrame("Slider", nil, holder, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("BOTTOMLEFT", 0, 4)
    s:SetPoint("BOTTOMRIGHT", 0, 4)
    s:SetHeight(10)
    ns.ThemedBackdrop(s, "button")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepMinMaxValues(true)
    s:EnableMouseWheel(true)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(8, 14)
    ns.Themed(thumb, function(t) t:SetColorTexture(A[1], A[2], A[3], 1) end)
    s:SetThumbTexture(thumb)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + delta * step)
    end)
    holder.slider = s
    return holder
end

function ns.CreateSearchBox(parent, width)
    local ok, eb = pcall(CreateFrame, "EditBox", nil, parent, "SearchBoxTemplate")
    if not ok or not eb then
        eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        eb:SetAutoFocus(false)
    end
    eb:SetSize(width or 150, 20)
    eb:SetMaxLetters(60)
    return eb
end
