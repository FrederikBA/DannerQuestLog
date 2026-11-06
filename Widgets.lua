--------------------------------------------------------------------------------
--  DannerQuestLog: flat widgets (dark panel, 1px black borders, teal accent),
--  in the spirit of the Vividz EQL3 reskin and EllesmereUI.
--------------------------------------------------------------------------------
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local AR, AG, AB = ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3]

ns.COLORS = {
    bg = { 0.06, 0.06, 0.07 },
    panel = { 0.10, 0.10, 0.11, 0.9 },
    border = { 0, 0, 0, 1 },
    button = { 0.15, 0.15, 0.16, 1 },
    buttonHover = { 0.22, 0.22, 0.24, 1 },
    header = { 1, 1, 1 },
    text = { 0.88, 0.88, 0.88 },
    dim = { 0.55, 0.55, 0.55 },
}
local C = ns.COLORS

function ns.Backdrop(frame, r, g, b, a)
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(r or C.panel[1], g or C.panel[2], b or C.panel[3], a or C.panel[4])
    frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
end

function ns.Solid(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- Flat text button.
function ns.CreateButton(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 80, height or 20)
    ns.Backdrop(b, C.button[1], C.button[2], C.button[3], C.button[4])
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER")
    fs:SetText(text or "")
    b:SetFontString(fs)
    b.label = fs
    b:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(C.buttonHover[1], C.buttonHover[2], C.buttonHover[3], C.buttonHover[4])
            self:SetBackdropBorderColor(AR, AG, AB, 0.8)
        end
        if self.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C.button[1], C.button[2], C.button[3], C.button[4])
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
        GameTooltip_Hide()
    end)
    return b
end

-- Enable/disable a flat button, greying its text while disabled.
function ns.SetButtonEnabled(b, on)
    b:SetEnabled(on and true or false)
    if on then
        b.label:SetTextColor(1, 1, 1)
    else
        b.label:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
        b:SetBackdropColor(C.button[1], C.button[2], C.button[3], C.button[4])
        b:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
    end
end

-- Small square title-bar button with a text glyph or a texture.
function ns.CreateIconButton(parent, size, glyph, texture)
    local b = ns.CreateButton(parent, glyph or "", size, size)
    b.label:SetFontObject("GameFontNormal")
    b.label:SetTextColor(1, 1, 1)
    if texture then
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOPLEFT", 3, -3)
        t:SetPoint("BOTTOMRIGHT", -3, 3)
        t:SetTexture(texture)
        b.icon = t
    end
    return b
end

-- Scroll frame with a scroll child of fixed width.
function ns.CreateScroll(parent, childWidth)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(childWidth, 1)
    sf:SetScrollChild(child)
    sf.child = child
    -- Flatten the template's bar a little: dark track behind it.
    local bar = sf.ScrollBar
    if bar then
        local track = ns.Solid(bar, "BACKGROUND", 0, 0, 0, 0.35)
        track:SetPoint("TOPLEFT", 0, 16)
        track:SetPoint("BOTTOMRIGHT", 0, -16)
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
    ns.Backdrop(s, 0.15, 0.15, 0.16, 1)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepMinMaxValues(true)
    s:EnableMouseWheel(true)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(AR, AG, AB, 1)
    thumb:SetSize(8, 14)
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
