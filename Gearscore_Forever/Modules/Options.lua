-- Options.lua - GearScore (Forever)
-- Fenêtre d'options et bouton de la minicarte.

local _, NS = ...
local L = NS.L
local S, C = NS.Skin, NS.Skin.C

local ICON = "Interface\\AddOns\\Gearscore_Forever\\Media\\icon.tga"

-- =========================================================
-- FENÊTRE D'OPTIONS
-- =========================================================

local WIDTH = 424
local HEADER_H, FOOTER_H, PADDING, GAP = 62, 30, 14, 8
local ROW_H = 40

local SECTIONS = {
  { label = "Tooltips", options = {
    { "item",    "Score of the item under the mouse" },
    { "player",  "Score of players you mouse over" },
    { "ilvl",    "Average item level next to the score" },
    { "auto",    "Inspect players automatically on mouseover" },
  } },
  { label = "Character & inspect", options = {
    { "sheet",    "GS and iLvl under your character model" },
    { "inspect",  "GS and iLvl in the inspect window" },
    { "enchants", "Enchant name next to each equipment slot" },
  } },
  { label = "Interface", options = {
    { "minimap", "Show the minimap button" },
  }, language = true },
}

local panel
local switches = {}
local languageSelector, confirm, scoreValue, scoreSub

-- Les libellés « English » / « Français » restent dans leur propre langue.
local LANGUAGES = {
  { value = "auto", label = "Automatic" },
  { value = "enUS", label = "English" },
  { value = "frFR", label = "Français" },
}

-- Les textes déjà affichés ne changent qu'au rechargement de l'interface :
-- la langue n'est enregistrée qu'une fois le rechargement accepté.
local function SelectLanguage(value)
  languageSelector:SetValue(value, true)
  confirm:Ask(L["The interface will reload to apply the language."], function()
    NS.DB().language = value
    ReloadUI()
  end, function()
    languageSelector:SetValue(NS.DB().language or "auto", true)
  end)
end

local function CreateRow(parent, name, desc, y)
  local opt = NS.OPTIONS[name]
  local row = CreateFrame("Button", nil, parent)
  row:SetPoint("TOPLEFT", 4, -y)
  row:SetPoint("TOPRIGHT", -4, -y)
  row:SetHeight(ROW_H)

  local wash = row:CreateTexture(nil, "BACKGROUND")
  wash:SetAllPoints()
  wash:SetColorTexture(1, 1, 1, 0.035)
  S.HoverFade(row, wash)

  local title = S.Text(row, 13)
  local switch = S.Switch(row, function(p)
    title:SetTextColor(S.LerpColor(C.muted, C.text, p))
  end)
  switch:SetPoint("RIGHT", -10, 0)

  title:SetPoint("TOPLEFT", 10, -6)
  title:SetPoint("RIGHT", switch, "LEFT", -10, 0)
  title:SetWordWrap(false)
  title:SetText(L[opt.label])

  local sub = S.Text(row, 11, "muted")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
  sub:SetPoint("RIGHT", switch, "LEFT", -10, 0)
  sub:SetWordWrap(false)
  sub:SetText(L[desc] .. "  |cff5c6a7c/gs " .. name .. "|r")

  row:SetScript("OnClick", function()
    local db = NS.DB()
    db[opt.key] = not db[opt.key]
    NS.RefreshDisplays()
  end)
  switches[opt.key] = switch
end

local function CreateLanguageRow(parent, y)
  local label = S.Text(parent, 13)
  label:SetPoint("TOPLEFT", 14, -y - 13)
  label:SetText(L["Language"])

  local choices = {}
  for i, choice in ipairs(LANGUAGES) do
    choices[i] = { value = choice.value, label = L[choice.label] }
  end
  languageSelector = S.Segmented(parent, choices, 84, SelectLanguage)
  languageSelector:SetPoint("TOPRIGHT", -14, -y - 8)
end

local function CreateHeader(f)
  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetSize(38, 38)
  logo:SetPoint("TOPLEFT", 14, -12)
  logo:SetTexture(S.MEDIA .. "Logo")

  local title = S.Text(f, 15)
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -3)
  title:SetText("GearScore")

  local sub = S.Text(f, 11, "muted")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
  sub:SetText("Forever  ·  v" .. (NS.VERSION or "?"))

  -- Résumé du personnage, à gauche du bouton de fermeture
  scoreValue = S.Text(f, 18)
  scoreValue:SetPoint("TOPRIGHT", -42, -12)
  scoreValue:SetJustifyH("RIGHT")

  scoreSub = S.Text(f, 11, "muted")
  scoreSub:SetPoint("TOPRIGHT", scoreValue, "BOTTOMRIGHT", 0, -2)
  scoreSub:SetJustifyH("RIGHT")

  local rule = S.Rule(f, C.border, 1)
  rule:SetPoint("TOPLEFT", PADDING, -HEADER_H + 1)
  rule:SetPoint("TOPRIGHT", -PADDING, -HEADER_H + 1)
end

local function CreatePanel()
  local f = S.Window("GearscoreForeverOptions", WIDTH, 400)
  tinsert(UISpecialFrames, "GearscoreForeverOptions") -- Échap ferme la fenêtre

  CreateHeader(f)

  local db = NS.DB()
  db.collapsed = type(db.collapsed) == "table" and db.collapsed or {}

  -- La fenêtre suit la hauteur des sections pendant qu'elles se replient.
  local sections = {}
  local function Relayout()
    local total = HEADER_H + 4 + FOOTER_H
    for _, s in ipairs(sections) do total = total + s:GetHeight() + GAP end
    f:SetHeight(total)
  end

  local previous
  for i, section in ipairs(SECTIONS) do
    local key = section.label
    local bodyHeight = #section.options * ROW_H + 4 + (section.language and ROW_H or 0)
    local s = S.Section(f, L[section.label], bodyHeight,
      function() return not NS.DB().collapsed[key] end,
      function(open) NS.DB().collapsed[key] = (not open) or nil end,
      Relayout)
    if previous then
      s:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -GAP)
      s:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -GAP)
    else
      s:SetPoint("TOPLEFT", PADDING, -HEADER_H - 4)
      s:SetPoint("TOPRIGHT", -PADDING, -HEADER_H - 4)
    end

    local y = 0
    for _, o in ipairs(section.options) do
      CreateRow(s.body, o[1], o[2], y)
      y = y + ROW_H
    end
    if section.language then CreateLanguageRow(s.body, y) end

    sections[i] = s
    previous = s
  end
  Relayout()

  -- Pied : commandes utiles
  local hint = S.Text(f, 11, "dim")
  hint:SetPoint("BOTTOM", 0, 12)
  hint:SetText("/gs   ·   /gs target   ·   /gs group")

  confirm = S.Confirm(f, L["Reload"], L["Cancel"])

  f:HookScript("OnShow", function() NS.UpdateOptionsPanel() end)
  return f
end

function NS.UpdateOptionsPanel()
  if not (panel and panel:IsVisible()) then return end
  local db = NS.DB()
  for key, switch in pairs(switches) do
    switch:SetOn(db[key], true)
  end
  languageSelector:SetValue(db.language or "auto", true)

  local entry = NS.GetPlayerEntry()
  if entry.score > 0 then
    scoreValue:SetText(entry.score)
    local r, g, b = NS.GetQuality(entry.score) -- 4e valeur : le libellé
    scoreValue:SetTextColor(r, g, b)
    scoreSub:SetText("GS  ·  iLvl " .. entry.ilvl)
  else
    scoreValue:SetText("-")
    scoreValue:SetTextColor(S.Color(C.dim))
    scoreSub:SetText("GS")
  end
end

function NS.ToggleOptions()
  panel = panel or CreatePanel()
  S.Toggle(panel)
end

-- =========================================================
-- BOUTON DE LA MINICARTE
-- =========================================================
-- Clic gauche : options. Glisser : déplacer autour de la minicarte.

local button

local function PlaceButton()
  local angle = math.rad(NS.DB().minimapAngle or 220)
  local radius = (Minimap:GetWidth() / 2) + 10
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
  local mx, my = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale
  NS.DB().minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
  PlaceButton()
end

local function CreateButton()
  local b = CreateFrame("Button", "GearscoreForeverMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 7, -5)
  icon:SetTexture(ICON)

  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  b:SetScript("OnClick", NS.ToggleOptions)
  b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("GearScore (Forever)")
    GameTooltip:AddLine(L["Click: options"], 1, 1, 1)
    GameTooltip:AddLine(L["Drag: move"], 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

function NS.UpdateMinimap()
  if not Minimap then return end
  if not NS.DB().showMinimap then
    if button then button:Hide() end
    return
  end
  button = button or CreateButton()
  PlaceButton()
  button:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    NS.UpdateMinimap()
  else
    NS.UpdateOptionsPanel() -- le score du personnage a changé
  end
end)
