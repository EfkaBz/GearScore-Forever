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

-- Les enchantements sont toujours affichés en anglais (plus courts) : sur un
-- client français, le texte de l'infobulle est d'abord traduit. Appliqué dans
-- l'ordre (les plus longs d'abord), sans tenir compte de la casse de la 1re
-- lettre.
local FR_TO_EN = {
  -- enchantements nommés
  { "Croisé", "Crusader" }, { "Vol de vie", "Lifestealing" }, { "Mangouste", "Mongoose" },
  { "Tueur de démons", "Demonslaying" }, { "Arme flamboyante", "Fiery Weapon" },
  { "Arme de feu", "Fiery Weapon" }, { "Froid glacial", "Icy Chill" }, { "Impie", "Unholy" },
  { "Tueur de bêtes", "Beastslaying" }, { "Tueur d'élémentaires", "Elemental Slayer" },
  { "Marche sur l'eau", "Water Walking" }, { "Vitesse de monture", "Mount Speed" },
  { "Vitesse d'attaque", "Attack Speed" },
  { "Augmentation mineure de la vitesse", "Speed" }, { "Vitesse de déplacement", "Speed" },
  { "Vitesse de course", "Speed" }, { "Augmentation de la vitesse", "Speed" },
  -- caractéristiques
  { "dégâts et soins des sorts", "SP" }, { "dégâts des sorts et soins", "SP" },
  { "puissance des sorts", "SP" }, { "dégâts des sorts", "SP" }, { "sorts de soins", "Heal" },
  { "puissance d'attaque à distance", "RAP" }, { "puissance d'attaque", "AP" },
  { "toutes les caractéristiques", "Stats" }, { "toutes les résistances", "All Res" },
  { "mana toutes les 5 sec%.?", "MP5" }, { "mana toutes les 5 secondes", "MP5" },
  { "points de mana", "Mana" }, { "points de vie", "HP" },
  { "score de coup critique", "Crit" }, { "coup critique", "Crit" }, { "critique", "Crit" },
  { "score de toucher", "Hit" }, { "toucher", "Hit" },
  { "score de défense", "Def" }, { "défense", "Def" }, { "Défense", "Def" },
  { "résistance au feu", "Fire Res" }, { "résistance au givre", "Frost Res" },
  { "résistance à la nature", "Nature Res" }, { "résistance à l'ombre", "Shadow Res" },
  { "résistance aux arcanes", "Arcane Res" }, { "Résistance", "Res" }, { "résistance", "Res" },
  { "dégâts de l'arme", "Wpn Dmg" }, { "dégâts", "Dmg" }, { "Dégâts", "Dmg" },
  { "soins", "Heal" }, { "esquive", "Dodge" }, { "parade", "Parry" }, { "blocage", "Block" },
  { "force", "Str" }, { "agilité", "Agi" }, { "endurance", "Sta" },
  { "intelligence", "Int" }, { "esprit", "Spi" }, { "armure", "Armor" },
}

-- Motif insensible à la casse de la première lettre (si elle est ASCII).
local function FirstLetterAnyCase(s)
  local c = s:sub(1, 1)
  if c:match("%a") then return "[" .. c:upper() .. c:lower() .. "]" .. s:sub(2) end
  return s
end
for _, pair in ipairs(FR_TO_EN) do pair[1] = FirstLetterAnyCase(pair[1]) end

-- Mots de liaison français entre le nombre et la caractéristique.
local CONNECTORS = {
  "%s+à%s+la%s+", "%s+à%s+l'", "%s+aux%s+", "%s+au%s+", "%s+à%s+", "%s+en%s+",
  "%s+de%s+", "%s+d'", "%s+points?%s+de%s+",
}

local function ToEnglish(text)
  -- le client écrit « d’attaque » (apostrophe typographique) et met des
  -- espaces insécables : on les ramène à ' et à l'espace simple
  text = text:gsub("\226\128\153", "'"):gsub("\194\160", " "):gsub("\226\128\175", " ")
  for _, pair in ipairs(FR_TO_EN) do
    text = text:gsub(pair[1], pair[2])
  end
  for _, c in ipairs(CONNECTORS) do
    text = text:gsub("(%d)" .. c, "%1 ")
  end
  text = text:gsub("%%%s+de%s+", "%% ") -- « +1 % de Crit » -> « +1 % Crit »
  return text
end

-- Abréviations appliquées dans l'ordre (les plus longues d'abord).
local ABBREVIATIONS = {
  -- vitesse d'attaque (libram) : « Attack Speed +1% » -> « 1%AS »
  { "Attack Speed%s*%+?(%d+)%s?%%", "%1%%AS" }, { "%+?(%d+)%s?%%%s*Attack Speed", "%1%%AS" },
  { "Damage and Healing Spells", "SP" }, { "Ranged Attack Power", "RAP" }, { "Attack Power", "AP" },
  { "All Stats", "Stats" }, { "All Resistances", "All Res" },
  { "Healing Spells", "Heal" }, { "Healing", "Heal" }, { "Spell Damage", "SP" },
  { "Spell Power", "SP" },
  { "Mana every 5 sec%.?", "MP5" }, { "Mana per 5 sec%.?", "MP5" }, { "mana per 5 sec%.?", "MP5" },
  { "Hit Rating", "Hit" }, { "Critical Strike", "Crit" }, { "Defense Rating", "Def" },
  { "Defense", "Def" }, { "Strength", "Str" }, { "Agility", "Agi" },
  { "Stamina", "Sta" }, { "Intellect", "Int" }, { "Spirit", "Spi" },
  { "Resistance", "Res" }, { "Damage", "Dmg" },
  { "Weapon", "Wpn" }, { "Minor Speed Increase", "Speed" }, { "Run Speed", "Speed" },
  { " and ", " & " }, { " et ", " & " },
}

local function Shorten(text)
  -- retire le préfixe « Enchanted: » / « Enchanté : »
  local short = text:gsub("^[^:]-%s?:%s*", "", 1)
  if short == "" then short = text end
  short = ToEnglish(short)
  for _, abbr in ipairs(ABBREVIATIONS) do
    short = short:gsub(abbr[1], abbr[2])
  end
  return short
end

-- Lignes vertes propres à l'objet (« Équipé : », « Utiliser : », « Chance
-- quand vous touchez : », bonus d'ensemble) : jamais un enchantement.
local EFFECT_PREFIXES = {}
for _, key in ipairs({ "ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONUSE",
  "ITEM_SPELL_TRIGGER_ONPROC", "ITEM_SET_BONUS", "ITEM_SET_BONUS_GRAY" }) do
  local s = _G[key]
  if type(s) == "string" then
    -- « Ensemble : %s » -> « Ensemble : » ; « (%d) Ensemble : %s » -> « (%d+) Ensemble : »
    s = s:gsub("%%s.*$", ""):gsub("\194\160", " "):gsub("\226\128\175", " "):gsub("%s+$", "")
    s = s:gsub("[%(%)%.%[%]%*%+%-%?%^%$]", "%%%0"):gsub("%%d", "%%d+")
    if s ~= "" then EFFECT_PREFIXES[#EFFECT_PREFIXES + 1] = "^" .. s end
  end
end
local function IsItemEffectLine(text)
  text = text:gsub("\194\160", " "):gsub("\226\128\175", " ")
  for _, p in ipairs(EFFECT_PREFIXES) do
    if text:find(p) then return true end
  end
  return false
end

-- Compare l'infobulle de l'objet porté avec celle de l'objet de base (sans
-- enchantement ni libram) : chaque ligne verte en plus est affichée. Les
-- librams de tête et de jambes ne passent pas toujours par le champ
-- d'enchantement du lien, d'où la comparaison avec l'objet nu.
local function GetEnchantText(link)
  if not link then return nil end
  local cached = cache[link]
  if cached then return cached ~= "" and cached or nil end

  local itemString = link:match("item:[%-%d:]+")
  if not itemString then return nil end
  -- objet nu : on vide seulement l'enchantement et les 4 gemmes et on garde
  -- le reste (suffixe, uniqueID, niveau), sinon les valeurs des suffixes
  -- aléatoires changent et leurs lignes passent pour un enchantement
  local plain, n = itemString:gsub("^item:(%d+):[^:]*:[^:]*:[^:]*:[^:]*:[^:]*", "item:%1:::::", 1)
  if n == 0 then plain = "item:" .. itemString:match("item:(%d+)") end

  local seen = {}
  local plainLines = TooltipLines(plain)
  -- objet nu pas encore chargé : toutes ses lignes vertes passeraient pour un
  -- enchantement (et resteraient en cache) ; on attendra GET_ITEM_INFO_RECEIVED
  if #plainLines == 0 then return nil end
  for _, line in ipairs(plainLines) do
    seen[line.text] = (seen[line.text] or 0) + 1
  end
  local found = {}
  for _, line in ipairs(TooltipLines(link)) do
    if seen[line.text] and seen[line.text] > 0 then
      seen[line.text] = seen[line.text] - 1
    elseif line.green and not IsItemEffectLine(line.text) then
      found[#found + 1] = Shorten(line.text)
    end
  end

  if #found > 0 then
    local text = table.concat(found, "\n")
    cache[link] = text
    return text
  end
  -- rien trouvé : on ne mémorise que si l'objet est bien chargé
  local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if #plainLines > 0 and GetInfo and GetInfo(link) then cache[link] = "" end
  return nil
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
    if fs.SetMaxLines then fs:SetMaxLines(3) end
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
      if fs.SetMaxLines then fs:SetMaxLines(4) end
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
