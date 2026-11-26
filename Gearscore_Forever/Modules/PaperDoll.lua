-- PaperDoll.lua - GearScore (Forever)
-- GS et iLvl sur la fiche de personnage et la fenêtre d'inspection.

local _, NS = ...

-- =========================================================
-- FICHE DE PERSONNAGE ET INSPECTION
-- =========================================================
-- Deux textes de part et d'autre de la rangée d'armes, en bas du modèle :
-- « GS : 200 » à gauche de la main droite, « iLvl : 20 » à droite de la
-- dernière case (munitions ou arme à distance).
--
-- L'interface de Forever ne reprend pas forcément les noms de cadres de
-- Classic (CharacterMainHandSlot...) : si les noms connus sont absents, on
-- cherche les boutons d'emplacement par leur ID d'inventaire.

local SLOT_MAINHAND = 16

local S = NS.Skin
local LABEL = "|cffa3afbf%s|r  %s"
local LINE_GAP = 16 -- écart vertical entre la ligne GS et la ligne iLvl

local function Walk(frame, fn, depth)
  if depth > 12 then return end
  for _, child in ipairs({ frame:GetChildren() }) do
    fn(child)
    Walk(child, fn, depth + 1)
  end
end

local function IsSlotButton(frame)
  return frame.GetID and frame.IsObjectType
    and (frame:IsObjectType("Button") or frame:IsObjectType("ItemButton"))
end

-- Cherche une case d'équipement : d'abord par son nom Classic, sinon par
-- son ID d'inventaire parmi les descendants du cadre.
local function FindSlot(root, prefix, slotName, slotID)
  local slot = _G[prefix .. slotName]
  if slot or not root then return slot end
  Walk(root, function(child)
    if not slot and IsSlotButton(child) and child:GetID() == slotID then
      local name = child:GetName()
      if not name or name:find("Slot") then slot = child end
    end
  end, 0)
  return slot
end
NS.FindSlot = FindSlot

-- Renvoie les cases qui délimitent les deux coins du bas :
--   gauche : poignets (bas de la colonne gauche) -> main droite
--   droite : dernière case de la rangée d'armes -> bijou 2 (bas de la colonne droite)
local function FindCorners(root, prefix)
  local mainHand = FindSlot(root, prefix, "MainHandSlot", 16)
  if not mainHand then return nil end

  local right = _G[prefix .. "AmmoSlot"] or _G[prefix .. "RangedSlot"] or _G[prefix .. "SecondaryHandSlot"]
  local parent = mainHand:GetParent()
  local _, mhY = mainHand:GetCenter()
  if parent and mhY then
    -- la case la plus à droite alignée avec la main droite
    local best, bestX = right, right and right:GetCenter() or mainHand:GetCenter()
    for _, child in ipairs({ parent:GetChildren() }) do
      if IsSlotButton(child) and child:IsShown() then
        local x, y = child:GetCenter()
        if x and y and math.abs(y - mhY) < 6 and x > bestX then
          best, bestX = child, x
        end
      end
    end
    right = best
  end

  return {
    mainHand = mainHand,
    rowEnd = right or mainHand,
    leftColumn = FindSlot(root, prefix, "WristSlot", 9),
    rightColumn = FindSlot(root, prefix, "Trinket1Slot", 14),
  }
end

-- Centre un texte horizontalement entre deux bords (en pixels écran du
-- parent), à la hauteur de la rangée d'armes. Réduit la police si besoin.
local function PlaceInGap(fs, rowButton, fromX, toX, fallbackPoint, fallbackX, xOffset, yOffset, size)
  size = size or 15
  fs:ClearAllPoints()
  fs:SetFontObject(S.Font(size))
  local rowLeft = rowButton:GetLeft()
  if not (fromX and toX and rowLeft) or toX - fromX < 20 then
    fs:SetPoint(fallbackPoint == "LEFT" and "RIGHT" or "LEFT", rowButton, fallbackPoint, fallbackX + xOffset, yOffset)
    return
  end
  local gap = toX - fromX
  if fs:GetStringWidth() > gap - 4 then fs:SetFontObject(S.Font(size - 2)) end
  if fs:GetStringWidth() > gap - 4 then fs:SetFontObject(S.Font(size - 4)) end
  local center = (fromX + toX) / 2
  fs:SetPoint("CENTER", rowButton, "LEFT", center - rowLeft + xOffset, yOffset)
end

-- yOffset : décalage vertical de la ligne GS (négatif = plus bas).
-- gsX : décalage horizontal du bloc (négatif = vers la gauche).
-- size / lineGap : taille de police et écart entre la ligne GS et la ligne iLvl.
local function CreateScoreBlock(corners, yOffset, gsX, size, lineGap)
  yOffset = yOffset or 0
  gsX = gsX or 0
  size = size or 15
  lineGap = lineGap or LINE_GAP
  local parent = corners.mainHand:GetParent()
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints(parent)
  f:SetFrameLevel(parent:GetFrameLevel() + 20)

  f.gs = S.Text(f, size)
  f.ilvl = S.Text(f, size)

  -- GS et iLvl empilés au même endroit (à gauche de la main droite) :
  -- le GS à sa place habituelle, l'iLvl juste en dessous, même taille de police.
  function f:Layout()
    local c = corners
    local fromX, toX = c.leftColumn and c.leftColumn:GetRight(), c.mainHand:GetLeft()
    PlaceInGap(self.gs, c.mainHand, fromX, toX, "LEFT", -10, gsX, yOffset, size)
    if self.ilvl:GetText() == "" then return end
    PlaceInGap(self.ilvl, c.mainHand, fromX, toX, "LEFT", -10, gsX, yOffset - lineGap, size)
    -- aligner les deux lignes sur la plus petite police retenue
    local gsSize = select(2, self.gs:GetFont()) or size
    local ilvlSize = select(2, self.ilvl:GetFont()) or size
    if gsSize ~= ilvlSize then
      local font = S.Font(math.floor(math.min(gsSize, ilvlSize) + 0.5))
      self.gs:SetFontObject(font)
      self.ilvl:SetFontObject(font)
    end
  end

  -- countUp : le score défile depuis l'ancienne valeur au lieu d'un simple fondu.
  function f:SetEntry(score, ilvl, countUp)
    local known = score and score > 0
    if known then
      self.gs:SetText(LABEL:format("GS", score))
      self.ilvl:SetText(NS.DB().showItemLevel and LABEL:format("iLvl", ilvl) or "")
    else
      self.gs:SetText(LABEL:format("GS", "..."))
      self.ilvl:SetText("")
    end
    self:Layout()
    -- SetFontObject remet la couleur par défaut : on la réapplique
    if known then
      local r, g, b = NS.GetQuality(score) -- 4e valeur : le libellé
      self.gs:SetTextColor(r, g, b)
    else
      self.gs:SetTextColor(S.Color(S.C.dim))
    end
    self.ilvl:SetTextColor(S.Color(S.C.text))

    local previous = self.shownScore
    self.shownScore = known and score or nil
    if previous == self.shownScore or not self:IsVisible() then return end
    if countUp and previous and known then
      S.Tween(self.gs, { dur = 0.45, from = previous, to = score, set = function(v)
        self.gs:SetText(LABEL:format("GS", math.floor(v + 0.5)))
      end })
    else
      S.StopTween(self.gs)
      self:SetAlpha(0)
      S.FadeTo(self, 1, 0.2)
    end
  end
  return f
end

local paperDollBlock
local function UpdatePaperDoll()
  if not paperDollBlock then return end
  if not NS.DB().showPaperDoll then paperDollBlock:Hide() return end
  local score, ilvl = NS.GetUnitScore("player")
  paperDollBlock:SetEntry(score, ilvl, true)
  paperDollBlock:Show()
end
NS.UpdatePaperDoll = UpdatePaperDoll

local function SetupPaperDoll()
  if paperDollBlock then return true end
  local corners = FindCorners(CharacterFrame or PaperDollFrame, "Character")
  if not corners then return false end
  --                                       hauteur, X, police, écart
  paperDollBlock = CreateScoreBlock(corners, -8, -30, 15, 16)
  paperDollBlock:SetScript("OnShow", UpdatePaperDoll)
  UpdatePaperDoll()
  return true
end

local inspectBlock
local function UpdateInspect()
  if not inspectBlock then return end
  if not NS.DB().showInspect then inspectBlock:Hide() return end
  local unit = InspectFrame and InspectFrame.unit
  local guid = unit and NS.GUID(unit)
  local entry = guid and NS.cache[guid]
  inspectBlock:SetEntry(entry and entry.score, entry and entry.ilvl)
  inspectBlock:Show()
end
NS.UpdateInspect = UpdateInspect

local function SetupInspect()
  if inspectBlock then return true end
  local corners = FindCorners(InspectFrame or InspectPaperDollFrame, "Inspect")
  if not corners then return false end
  -- moins de place sous le modèle : police plus petite et bloc remonté
  -- pour que la ligne iLvl ne soit pas coupée par le bas de la fenêtre
  --                                     hauteur, X, police, écart
  inspectBlock = CreateScoreBlock(corners, -8, -30, 10, 11)
  inspectBlock:SetScript("OnShow", UpdateInspect)
  UpdateInspect()
  return true
end

NS.OnScoreUpdated(function(guid)
  local unit = InspectFrame and InspectFrame:IsShown() and InspectFrame.unit
  if not unit or NS.GUID(unit) ~= guid then return end
  SetupInspect()
  UpdateInspect()
end)

-- La fiche de personnage peut être créée après la connexion : on retente la
-- mise en place à chaque ouverture.
if ToggleCharacter then
  hooksecurefunc("ToggleCharacter", function()
    C_Timer.After(0, function()
      if SetupPaperDoll() then UpdatePaperDoll() end
    end)
  end)
end

local function HookCharacterFrame()
  if not CharacterFrame or CharacterFrame.gsfHooked then return end
  CharacterFrame.gsfHooked = true
  CharacterFrame:HookScript("OnShow", function()
    -- attendre une image que la disposition des cases soit calculée
    C_Timer.After(0, function()
      if SetupPaperDoll() then UpdatePaperDoll() end
    end)
  end)
end

local function HookInspectFrame()
  if not InspectFrame or InspectFrame.gsfHooked then return end
  InspectFrame.gsfHooked = true
  InspectFrame:HookScript("OnShow", function()
    C_Timer.After(0, function()
      if SetupInspect() then UpdateInspect() end
    end)
  end)
end

-- Diagnostic : /gs debug
function NS.DebugFrames()
  local function name(f) return f and (f:GetName() or tostring(f)) or "|cffff0000missing|r" end
  NS.Print("CharacterFrame: " .. name(CharacterFrame) .. ", PaperDollFrame: " .. name(PaperDollFrame))
  NS.Print("CharacterMainHandSlot: " .. name(CharacterMainHandSlot))
  local c = FindCorners(CharacterFrame or PaperDollFrame, "Character") or {}
  NS.Print("Main hand: " .. name(c.mainHand) .. ", row end: " .. name(c.rowEnd))
  NS.Print("Wrists: " .. name(c.leftColumn) .. ", trinket 2: " .. name(c.rightColumn))
  NS.Print("Block created: " .. (paperDollBlock and "yes" or "no")
    .. ", score: " .. (NS.GetUnitScore("player")))
end

local function IsLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
  return IsAddOnLoaded and IsAddOnLoaded(name)
end

local function RefreshIfVisible()
  if paperDollBlock and paperDollBlock:IsVisible() then UpdatePaperDoll() end
end

NS.RegisterEvents({
  PLAYER_LOGIN = function()
    NS.DB()
    NS.LoadBracket()
    NS.Print(NS.L["v%s loaded. Type /gs for help."]:format(NS.VERSION))
    HookCharacterFrame()
    if IsLoaded("Blizzard_InspectUI") then HookInspectFrame() end
  end,
  ADDON_LOADED = function(name)
    if name == "Blizzard_InspectUI" then HookInspectFrame() end
    HookCharacterFrame()
  end,
  PLAYER_EQUIPMENT_CHANGED = RefreshIfVisible,
  GET_ITEM_INFO_RECEIVED = RefreshIfVisible,
})
