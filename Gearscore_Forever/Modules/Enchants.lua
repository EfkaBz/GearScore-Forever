-- Enchants.lua - GearScore (Forever)
-- Nom de l'enchantement à côté de chaque case d'équipement (fiche de
-- personnage et fenêtre d'inspection).

local _, NS = ...

-- =========================================================
-- LECTURE DE L'ENCHANTEMENT
-- =========================================================
-- Classic n'a pas d'API pour le nom d'un enchantement : on compare
-- l'infobulle de l'objet avec celle du même objet sans enchantement.
-- La ligne verte en plus est l'enchantement.

local scanner = CreateFrame("GameTooltip", "GearscoreForeverEnchantScanner", nil, "GameTooltipTemplate")
scanner:SetOwner(WorldFrame, "ANCHOR_NONE")

local function TooltipLines(link)
  scanner:ClearLines()
  scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
  scanner:SetHyperlink(link)
  local lines = {}
  for i = 2, scanner:NumLines() do
    local fs = _G["GearscoreForeverEnchantScannerTextLeft" .. i]
    local text = fs and fs:GetText()
    if text and text ~= "" then
      local r, g, b = fs:GetTextColor()
      lines[#lines + 1] = { text = text, green = g > 0.8 and r < 0.2 and b < 0.2 }
    end
  end
  return lines
end

local cache = {}

-- Abréviations appliquées dans l'ordre (les plus longues d'abord).
local ABBREVIATIONS = {
  { "Damage and Healing Spells", "SP" }, { "Ranged Attack Power", "RAP" }, { "Attack Power", "AP" },
  { "Puissance d'attaque à distance", "PAD" }, { "Puissance d'attaque", "PA" },
  { "All Stats", "Stats" }, { "All Resistances", "All Res" },
  { "Healing Spells", "Heal" }, { "Healing", "Heal" }, { "Spell Damage", "SP" },
  { "Spell Power", "SP" },
  { "Mana every 5 sec%.?", "MP5" }, { "Mana per 5 sec%.?", "MP5" }, { "mana per 5 sec%.?", "MP5" },
  { "Hit Rating", "Hit" }, { "Critical Strike", "Crit" }, { "Defense Rating", "Def" },
  { "Defense", "Def" }, { "Strength", "Str" }, { "Agility", "Agi" },
  { "Stamina", "Sta" }, { "Intellect", "Int" }, { "Spirit", "Spi" },
  { "Resistance", "Res" }, { "Damage", "Dmg" },
  { "Weapon", "Wpn" }, { "Minor Speed Increase", "Speed" }, { "Run Speed", "Speed" },
  { "Force", "For" }, { "Agilité", "Agi" }, { "Endurance", "End" },
  { "Intelligence", "Int" }, { "Esprit", "Esp" }, { "Armure", "Arm" },
  { "Résistance", "Rés" }, { "Dégâts", "Dég" }, { "Soins", "Soin" },
  { "Toutes les caractéristiques", "Stats" }, { "Défense", "Déf" },
  { " and ", " & " }, { " et ", " & " },
}

local function GetEnchantText(link)
  if not link then return nil end
  local enchantID = link:match("item:%d+:(%d*)")
  if not enchantID or enchantID == "" or enchantID == "0" then return nil end
  if cache[link] then return cache[link] end

  local plain = link:gsub("(item:%d+):%d*", "%1:")
  local seen = {}
  for _, line in ipairs(TooltipLines(plain)) do
    seen[line.text] = (seen[line.text] or 0) + 1
  end
  for _, line in ipairs(TooltipLines(link)) do
    if seen[line.text] and seen[line.text] > 0 then
      seen[line.text] = seen[line.text] - 1
    elseif line.green then
      -- retire le préfixe « Enchanted: » / « Enchanté : »
      local text = line.text:gsub("^[^:]-%s?:%s*", "", 1)
      if text == "" then text = line.text end
      for _, abbr in ipairs(ABBREVIATIONS) do
        text = text:gsub(abbr[1], abbr[2])
      end
      cache[link] = text
      return text
    end
  end
  return nil -- objet pas encore en cache : on réessaiera
end

-- =========================================================
-- AFFICHAGE
-- =========================================================
-- Colonne gauche : texte à droite de la case ; colonne droite : à gauche ;
-- armes : sous la case.

local LEFT_SLOTS = { 1, 2, 3, 15, 5, 4, 19, 9 }
local RIGHT_SLOTS = { 10, 6, 7, 8, 11, 12, 13, 14 }
local WEAPON_SLOTS = { 16, 17, 18 }
local SLOT_NAMES = {
  [1] = "HeadSlot", [2] = "NeckSlot", [3] = "ShoulderSlot", [15] = "BackSlot",
  [5] = "ChestSlot", [4] = "ShirtSlot", [19] = "TabardSlot", [9] = "WristSlot",
  [10] = "HandsSlot", [6] = "WaistSlot", [7] = "LegsSlot", [8] = "FeetSlot",
  [11] = "Finger0Slot", [12] = "Finger1Slot", [13] = "Trinket0Slot", [14] = "Trinket1Slot",
  [16] = "MainHandSlot", [17] = "SecondaryHandSlot", [18] = "RangedSlot",
}

local TEXT_WIDTH = 90

local function CreateLabels(root, prefix, gap)
  gap = gap or 6
  local labels = {}
  local function Add(slotID, side)
    local button = NS.FindSlot(root, prefix, SLOT_NAMES[slotID], slotID)
    if not button then return end
    local fs = button:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(NS.Skin.Font(10))
    fs:SetTextColor(NS.Skin.Color(NS.Skin.C.enchant))
    fs:SetWordWrap(true)
    if fs.SetMaxLines then fs:SetMaxLines(2) end
    if side == "left" then
      fs:SetWidth(TEXT_WIDTH)
      fs:SetJustifyH("LEFT")
      fs:SetPoint("LEFT", button, "RIGHT", gap, 0)
    elseif side == "right" then
      fs:SetWidth(TEXT_WIDTH)
      fs:SetJustifyH("RIGHT")
      fs:SetPoint("RIGHT", button, "LEFT", -gap, 0)
    else
      fs:SetWidth(button:GetWidth())
      if fs.SetMaxLines then fs:SetMaxLines(3) end
      fs:SetJustifyH("CENTER")
      fs:SetPoint("BOTTOM", button, "TOP", 0, 2)
    end
    labels[slotID] = fs
  end
  for _, id in ipairs(LEFT_SLOTS) do Add(id, "left") end
  for _, id in ipairs(RIGHT_SLOTS) do Add(id, "right") end
  for _, id in ipairs(WEAPON_SLOTS) do Add(id, "above") end
  return next(labels) and labels or nil
end

local function Fill(labels, unit)
  local show = NS.DB().showEnchants and unit
  for slotID, fs in pairs(labels) do
    local text = show and GetEnchantText(GetInventoryItemLink(unit, slotID))
    fs:SetText(text or "")
  end
end

local playerLabels, inspectLabels

local function UpdatePlayer()
  if not playerLabels then
    if not (CharacterFrame and CharacterFrame:IsShown()) then return end
    playerLabels = CreateLabels(CharacterFrame or PaperDollFrame, "Character")
    if not playerLabels then return end
  end
  Fill(playerLabels, "player")
end

local function UpdateInspectLabels()
  if not (InspectFrame and InspectFrame:IsShown()) then return end
  if not inspectLabels then
    inspectLabels = CreateLabels(InspectFrame or InspectPaperDollFrame, "Inspect", 12)
    if not inspectLabels then return end
  end
  Fill(inspectLabels, InspectFrame.unit)
end

local function UpdateEnchants()
  UpdatePlayer()
  UpdateInspectLabels()
end
NS.UpdateEnchants = UpdateEnchants

local function HookFrame(frame, fn)
  if not frame or frame.gsfEnchantHooked then return end
  frame.gsfEnchantHooked = true
  frame:HookScript("OnShow", function() C_Timer.After(0, fn) end)
end

local function Later() C_Timer.After(0.2, UpdateEnchants) end

-- Cadre d'événements propre : NS.RegisterEvents ne garde qu'une fonction
-- par événement et PaperDoll.lua utilise déjà les mêmes.
local handlers = {
  PLAYER_LOGIN = function()
    HookFrame(CharacterFrame, UpdatePlayer)
    HookFrame(InspectFrame, UpdateInspectLabels)
  end,
  ADDON_LOADED = function(name)
    HookFrame(CharacterFrame, UpdatePlayer)
    if name == "Blizzard_InspectUI" then HookFrame(InspectFrame, UpdateInspectLabels) end
  end,
  PLAYER_EQUIPMENT_CHANGED = Later,
  GET_ITEM_INFO_RECEIVED = Later,
  INSPECT_READY = Later,
}
local events = CreateFrame("Frame")
for event in pairs(handlers) do pcall(events.RegisterEvent, events, event) end
events:SetScript("OnEvent", function(_, event, ...) handlers[event](...) end)
