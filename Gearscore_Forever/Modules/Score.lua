-- Score.lua - GearScore (Forever)
-- Calcul du GearScore, repris de GearScoreLite (Mirrikat45) tel qu'utilisé
-- par les addons Classic / TBC Classic (TacoTip).
--
-- Principe : le score d'un objet ne dépend QUE de son niveau d'objet, de sa
-- qualité et de son emplacement :
--
--   score = floor( (ilvl - A) / B * SlotMOD * 1.8618 * QualityScale )
--
-- A et B dépendent de la qualité et de la tranche de niveau d'objet (table
-- GS_Formula). Les nouveaux objets de Forever (expertise, puissance des sorts,
-- toucher unifié, etc.) sont donc notés automatiquement : seules comptent les
-- données renvoyées par le client (ilvl, qualité, emplacement).
--
-- Le total d'un personnage est la somme de ses emplacements (hors chemise et
-- tabard). Seule l'échelle des couleurs change selon la version du jeu :
-- 200 points par palier sur Classic (niveau 60), 400 sur TBC, 1000 sur WotLK.
--
-- Forever ajoute du contenu au-dessus de Naxxramas : le palier est donc
-- automatique. Il part de l'échelle Classic (200) et s'élargit avec le
-- meilleur GearScore jamais rencontré (soi-même ou joueurs inspectés), pour
-- que ce score reste au milieu de l'orange, comme un équipement complet de
-- Naxxramas sur Classic. Il ne redescend jamais.

local _, NS = ...
local floor = math.floor

local MIN_BRACKET = 200     -- échelle Classic
local BEST_POSITION = 5.5   -- le meilleur score vu = 5,5 paliers (orange)
local BRACKET_STEP = 25     -- arrondi du palier
local PINK_THRESHOLD = 2000 -- au-delà : rose

local BRACKET_SIZE = MIN_BRACKET
local MAX_SCORE = BRACKET_SIZE * 6 - 1

local function ApplyBracket(maxSeen)
  local size = math.ceil((maxSeen or 0) / BEST_POSITION / BRACKET_STEP) * BRACKET_STEP
  -- plafonné pour que l'orange s'arrête à 2000, là où commence le rose
  local maxBracket = floor(PINK_THRESHOLD / 6 / BRACKET_STEP) * BRACKET_STEP
  BRACKET_SIZE = math.min(maxBracket, math.max(MIN_BRACKET, size))
  MAX_SCORE = BRACKET_SIZE * 6 - 1
end

function NS.GetBracket()
  return BRACKET_SIZE
end

-- Recharge le palier depuis la sauvegarde (appelé à la connexion).
function NS.LoadBracket()
  ApplyBracket(tonumber(NS.DB().maxScoreSeen))
end

-- Mémorise un GearScore complet ; élargit le palier si c'est un record.
function NS.NoteScore(score)
  local db = NS.DB()
  if score and score > (tonumber(db.maxScoreSeen) or 0) then
    db.maxScoreSeen = score
    local old = BRACKET_SIZE
    ApplyBracket(score)
    if BRACKET_SIZE ~= old and NS.RefreshDisplays then NS.RefreshDisplays() end
  end
end

local GS_ItemTypes = {
  INVTYPE_RELIC          = 0.3164,
  INVTYPE_TRINKET        = 0.5625,
  INVTYPE_2HWEAPON       = 2.0000,
  INVTYPE_WEAPONMAINHAND = 1.0000,
  INVTYPE_WEAPONOFFHAND  = 1.0000,
  INVTYPE_RANGED         = 0.3164,
  INVTYPE_THROWN         = 0.3164,
  INVTYPE_RANGEDRIGHT    = 0.3164,
  INVTYPE_SHIELD         = 1.0000,
  INVTYPE_WEAPON         = 1.0000,
  INVTYPE_HOLDABLE       = 1.0000,
  INVTYPE_HEAD           = 1.0000,
  INVTYPE_NECK           = 0.5625,
  INVTYPE_SHOULDER       = 0.7500,
  INVTYPE_CHEST          = 1.0000,
  INVTYPE_ROBE           = 1.0000,
  INVTYPE_WAIST          = 0.7500,
  INVTYPE_LEGS           = 1.0000,
  INVTYPE_FEET           = 0.7500,
  INVTYPE_WRIST          = 0.5625,
  INVTYPE_HAND           = 0.7500,
  INVTYPE_FINGER         = 0.5625,
  INVTYPE_CLOAK          = 0.5625,
  INVTYPE_BODY           = 0,
}
NS.SlotMOD = GS_ItemTypes

local GS_Formula = {
  A = { -- objets de haut niveau (au-delà de ce qu'offre le niveau 60)
    [4] = { A = 91.4500, B = 0.6500 },
    [3] = { A = 81.3750, B = 0.8125 },
    [2] = { A = 73.0000, B = 1.0000 },
  },
  B = {
    [4] = { A = 26.0000, B = 1.2000 },
    [3] = { A = 0.7500,  B = 1.8000 },
    [2] = { A = 8.0000,  B = 2.0000 },
    [1] = { A = 0.0000,  B = 2.2500 },
  },
  C = { -- épiques de niveau d'objet < 100 (tout le contenu niveau 60)
    [4] = { A = 0.2500, B = 1.6275 },
  },
}

-- Dégradé de couleur par palier : { valeur de départ, origine, pente, sens }
local GS_Quality = {
  [6] = { Red = { 0.94, 5, 0.00006, 1 }, Green = { 0, 0, 0, 0 },         Blue = { 0.47, 5, 0.00047, -1 }, desc = "Legendary" },
  [5] = { Red = { 0.69, 4, 0.00025, 1 }, Green = { 0.97, 4, 0.00096, -1 }, Blue = { 0.28, 4, 0.00019, 1 },  desc = "Epic" },
  [4] = { Red = { 0.0, 3, 0.00069, 1 },  Green = { 1, 3, 0.00003, -1 },    Blue = { 0.5, 3, 0.00022, -1 },  desc = "Superior" },
  [3] = { Red = { 0.12, 2, 0.00012, -1 }, Green = { 0, 2, 0.001, 1 },      Blue = { 1, 2, 0.00050, -1 },    desc = "Uncommon" },
  [2] = { Red = { 1, 1, 0.00088, -1 },   Green = { 1, 1, 0.001, -1 },      Blue = { 1, 0, 0, 0 },           desc = "Common" },
  [1] = { Red = { 0.55, 0, 0.00045, 1 }, Green = { 0.55, 0, 0.00045, 1 },  Blue = { 0.55, 0, 0.00045, 1 },  desc = "Poor" },
}

local function clamp(v)
  if v < 0 then return 0 elseif v > 1 then return 1 end
  return v
end

local function channel(c, score)
  return clamp(c[1] + (score - c[2] * BRACKET_SIZE) * c[3] * c[4])
end

-- Couleur (r, g, b) et libellé d'un GearScore. Même rendu que GearScoreLite :
-- gris -> blanc -> vert -> bleu -> violet -> orange.
function NS.GetQuality(score)
  score = tonumber(score)
  if not score or score <= 0 then
    return 0.55, 0.55, 0.55, NS.L[GS_Quality[1].desc]
  end
  -- Au-delà de 2000, rose fixe, quelle que soit l'échelle automatique.
  if score > PINK_THRESHOLD then
    return 1.00, 0.41, 0.71, NS.L["Mythic"]
  end
  if score > MAX_SCORE then score = MAX_SCORE end
  local q = GS_Quality[math.ceil(score / BRACKET_SIZE)]
  -- Dans la table d'origine les rangées « Green » et « Blue » sont inversées
  -- par rapport à leur nom ; on reproduit ce comportement tel quel.
  return channel(q.Red, score), channel(q.Blue, score), channel(q.Green, score), NS.L[q.desc]
end

-- Niveau d'objet effectif (tient compte des objets à niveau variable).
local function EffectiveItemLevel(link, baseLevel)
  if NS.GetDetailedItemLevelInfo then
    local ok, level = pcall(NS.GetDetailedItemLevelInfo, link)
    if ok and type(level) == "number" and level > 0 then
      return level
    end
  end
  return baseLevel
end

-- GearScore d'un objet.
-- Renvoie score, ilvl, r, g, b, equipLoc ; ou nil si l'objet n'est pas encore
-- en cache (une requête de chargement est alors envoyée).
function NS.GetItemScore(link)
  if not link then return nil end
  local _, _, rarity, baseLevel, _, _, _, _, equipLoc = NS.GetItemInfo(link)
  if not rarity or not baseLevel then
    NS.RequestItem(link)
    return nil
  end

  local slotMod = GS_ItemTypes[equipLoc]
  if not slotMod then
    return 0, 0, 0.55, 0.55, 0.55, equipLoc
  end

  local itemLevel = EffectiveItemLevel(link, baseLevel)
  local qualityScale = 1
  if rarity == 5 or rarity == 6 then     -- légendaire / artefact
    qualityScale = 1.3
    rarity = 4
  elseif rarity == 7 then                -- héritage : noté comme un bleu
    rarity = 3
  elseif rarity <= 1 then                -- gris / blanc : quasi nul
    qualityScale = 0.005
    rarity = 2
  end

  local tbl
  if itemLevel < 100 and rarity == 4 then
    tbl = GS_Formula.C
  elseif itemLevel < 168 and rarity == 4 then
    tbl = GS_Formula.B
  elseif itemLevel < 148 and rarity == 3 then
    tbl = GS_Formula.B
  elseif itemLevel < 138 and rarity == 2 then
    tbl = GS_Formula.B
  elseif itemLevel <= 120 then
    tbl = GS_Formula.B
  else
    tbl = GS_Formula.A
  end
  local f = tbl[rarity] or GS_Formula.B[rarity]
  if not f then
    return 0, itemLevel, 0.55, 0.55, 0.55, equipLoc
  end

  local base = (itemLevel - f.A) / f.B * 1.8618
  local score = floor(base * slotMod * qualityScale)
  local r, g, b = NS.GetQuality(floor(base) * 11.25)
  if score < 0 then
    score = 0
    r, g, b = NS.GetQuality(1)
  end
  return score, itemLevel, r, g, b, equipLoc
end

-- Pondération chasseur : les armes de mêlée comptent peu, l'arme à distance
-- beaucoup (x5.3224 sur un emplacement valant 0.3164, soit ~1.68).
local HUNTER_MELEE = {
  INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
  INVTYPE_WEAPON = true, INVTYPE_HOLDABLE = true,
}
local HUNTER_RANGED = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }

function NS.GetItemHunterScore(link)
  local score, itemLevel, r, g, b, equipLoc = NS.GetItemScore(link)
  if not score then return nil end
  if HUNTER_MELEE[equipLoc] then
    score = floor(score * 0.3164)
  elseif HUNTER_RANGED[equipLoc] then
    score = floor(score * 5.3224)
  end
  return score, itemLevel, r, g, b, equipLoc
end

local SLOT_MAINHAND, SLOT_OFFHAND, SLOT_RANGED = 16, 17, 18

local function EquipLoc(link)
  if not link then return nil end
  return select(9, NS.GetItemInfo(link))
end

-- GearScore total d'une unité (joueur ou unité inspectée).
-- Renvoie score, ilvl moyen, complet (false si des objets manquent encore).
function NS.GetUnitScore(unit)
  local _, class = UnitClass(unit)
  local isHunter = (class == "HUNTER")
  local total, count, levelTotal = 0, 0, 0
  local complete = true

  -- Deux armes à deux mains (Poigne de titan) : chacune compte pour moitié.
  local titanGrip = 1
  local mhLink = GetInventoryItemLink(unit, SLOT_MAINHAND)
  local ohLink = GetInventoryItemLink(unit, SLOT_OFFHAND)
  if mhLink and ohLink
    and (EquipLoc(mhLink) == "INVTYPE_2HWEAPON" or EquipLoc(ohLink) == "INVTYPE_2HWEAPON") then
    titanGrip = 0.5
  end

  for slot = 1, 18 do
    if slot ~= 4 then -- chemise
      local link = GetInventoryItemLink(unit, slot)
      if link then
        local score, itemLevel = NS.GetItemScore(link)
        if score then
          if isHunter then
            if slot == SLOT_MAINHAND or slot == SLOT_OFFHAND then
              score = score * 0.3164
            elseif slot == SLOT_RANGED then
              score = score * 5.3224
            end
          end
          if slot == SLOT_MAINHAND or slot == SLOT_OFFHAND then
            score = score * titanGrip
          end
          total = total + score
          count = count + 1
          levelTotal = levelTotal + itemLevel
        else
          complete = false
        end
      elseif GetInventoryItemID(unit, slot) then
        -- l'objet est connu mais son lien n'est pas encore disponible
        complete = false
        NS.RequestItem(GetInventoryItemID(unit, slot))
      end
    end
  end

  local avg = count > 0 and floor(levelTotal / count) or 0
  if complete then NS.NoteScore(floor(total)) end
  return floor(total), avg, complete
end
