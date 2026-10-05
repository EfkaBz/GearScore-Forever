-- Options.lua - GearScore (Forever)
-- Fenêtre d'options (cases à cocher) et bouton de la minicarte.

local _, NS = ...
local L = NS.L

local ICON = "Interface\\AddOns\\Gearscore_Forever\\Media\\icon.tga"

-- =========================================================
-- FENÊTRE D'OPTIONS
-- =========================================================
-- Même style que Books on map (Forever) : fond sombre, bordure dorée,
-- logo + titre, sections à bandeau doré.

local WIDTH = 440
local ROW_H, HEADER_H = 40, 26

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
  } },
}

local panel
local checks = {}
local langChecks = {}

-- Les libellés « English » / « Français » restent dans leur propre langue.
local LANGUAGES = {
  { value = "auto", label = "Automatic" },
  { value = "enUS", label = "English" },
  { value = "frFR", label = "Français" },
}

-- Les textes déjà affichés ne changent qu'au rechargement de l'interface.
StaticPopupDialogs["GEARSCOREFOREVER_RELOAD"] = {
  text = "%s",
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function() ReloadUI() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
}

local function SetLanguage(value)
  local db = NS.DB()
  local old = db.language or "auto"
  db.language = value
  NS.UpdateOptionsPanel()
  if value ~= old then
    StaticPopup_Show("GEARSCOREFOREVER_RELOAD", L["The interface will reload to apply the language."])
  end
end

local function CreateHeader(parent, text, y)
  local h = CreateFrame("Frame", nil, parent)
  h:SetPoint("TOPLEFT", 0, -y)
  h:SetPoint("TOPRIGHT", 0, -y)
  h:SetHeight(HEADER_H)

  local bg = h:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 0.82, 0, 0.12)

  local line = h:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetColorTexture(1, 0.82, 0, 0.5)

  local label = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("LEFT", 8, 0)
  label:SetText(text)
end

local function CreateRow(parent, name, desc, y)
  local opt = NS.OPTIONS[name]
  local row = CreateFrame("Button", nil, parent)
  row:SetPoint("TOPLEFT", 0, -y)
  row:SetPoint("TOPRIGHT", 0, -y)
  row:SetHeight(ROW_H)

  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)

  local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  cb:SetPoint("LEFT", 6, 0)

  local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", cb, "TOPRIGHT", 6, 0)
  title:SetText(L[opt.label])

  local sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
  sub:SetTextColor(0.65, 0.65, 0.65)
  sub:SetText(L[desc] .. "  |cff808080(/gs " .. name .. ")|r")

  local function Apply(value)
    NS.DB()[opt.key] = value
    NS.RefreshDisplays()
  end
  cb:SetScript("OnClick", function(self) Apply(self:GetChecked() and true or false) end)
  row:SetScript("OnClick", function() Apply(not NS.DB()[opt.key]) end)
  checks[opt.key] = { cb = cb, title = title }
end

local function CreatePanel()
  local f = CreateFrame("Frame", "GearscoreForeverOptions", UIParent, "BackdropTemplate")
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
      tile = true, tileSize = 32, edgeSize = 24,
      insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
  end
  tinsert(UISpecialFrames, "GearscoreForeverOptions") -- Échap ferme la fenêtre

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  -- En-tête : logo + titre
  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetSize(40, 40)
  logo:SetPoint("TOPLEFT", 16, -14)
  logo:SetTexture(ICON)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -4)
  title:SetText("GearScore (Forever)")

  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  sub:SetTextColor(0.7, 0.7, 0.7)
  sub:SetText("Options  -  v" .. (NS.VERSION or "?"))

  -- Liste des options
  local list = CreateFrame("Frame", nil, f, "BackdropTemplate")
  list:SetPoint("TOPLEFT", 14, -66)
  list:SetPoint("TOPRIGHT", -14, -66)
  if list.SetBackdrop then
    list:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    list:SetBackdropColor(0, 0, 0, 0.5)
    list:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.8)
  end

  local content = CreateFrame("Frame", nil, list)
  content:SetPoint("TOPLEFT", 6, -6)
  content:SetPoint("TOPRIGHT", -6, -6)

  local y = 0
  for _, section in ipairs(SECTIONS) do
    CreateHeader(content, L[section.label], y)
    y = y + HEADER_H + 2
    for _, o in ipairs(section.options) do
      CreateRow(content, o[1], o[2], y)
      y = y + ROW_H
    end
    y = y + 6
  end

  -- Langue : trois boutons, un seul coché
  CreateHeader(content, L["Language"], y)
  y = y + HEADER_H + 8
  local x = 6
  for _, choice in ipairs(LANGUAGES) do
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", x, -y)
    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    label:SetText(L[choice.label])
    cb:SetScript("OnClick", function() SetLanguage(choice.value) end)
    langChecks[choice.value] = cb
    x = x + 120
  end
  y = y + 34
  content:SetHeight(y)
  list:SetHeight(y + 12)

  -- Pied : commandes utiles
  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("BOTTOM", 0, 16)
  hint:SetTextColor(0.6, 0.6, 0.6)
  hint:SetText("/gs  -  /gs target  -  /gs group")

  f:SetSize(WIDTH, 66 + y + 12 + 40)
  f:SetScript("OnShow", NS.UpdateOptionsPanel)
  f:Hide()
  return f
end

function NS.UpdateOptionsPanel()
  local db = NS.DB()
  for key, c in pairs(checks) do
    c.cb:SetChecked(db[key])
    if db[key] then c.title:SetTextColor(1, 0.82, 0) else c.title:SetTextColor(0.5, 0.5, 0.5) end
  end
  local lang = db.language or "auto"
  for value, cb in pairs(langChecks) do cb:SetChecked(value == lang) end
end

function NS.ToggleOptions()
  panel = panel or CreatePanel()
  panel:SetShown(not panel:IsShown())
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
events:SetScript("OnEvent", NS.UpdateMinimap)
