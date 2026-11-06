-- Core.lua - GearScore (Forever)
-- Espace de noms, base de données et couche de compatibilité.
--
-- Forever tourne sur le moteur Retail (API 12.x, interface 16001) :
--   1. RegisterEvent sur un événement inconnu LÈVE UNE ERREUR. -> NS.RegisterEvents()
--   2. Certaines valeurs d'unité sont « secrètes » en combat : les comparer ou
--      s'en servir comme clé de table déclenche une erreur. -> NS.Safe()
--   3. Les SavedVariables peuvent ne pas être relues au démarrage (bug de la
--      bêta) : on passe par un accesseur auto-réparant. -> NS.DB()
--   4. GetItemInfo global est remplacé par C_Item.GetItemInfo.

local ADDON_NAME, NS = ...

NS.ADDON_NAME = ADDON_NAME
NS.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata
  and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "1.1.0"

-- =========================================================
-- 1. BASE DE DONNÉES (SavedVariables)
-- =========================================================
GearscoreForeverDB = GearscoreForeverDB or {}

local DB_DEFAULTS = {
  showItemTooltip = true,   -- GearScore de l'objet dans son infobulle
  showUnitTooltip = true,   -- GearScore des joueurs survolés
  showItemLevel = true,     -- niveau d'objet moyen à côté du GearScore
  autoInspect = true,       -- inspection automatique des joueurs survolés
  showPaperDoll = true,     -- GearScore sur la fiche de personnage
  showInspect = true,       -- GearScore sur la fenêtre d'inspection
  showEnchants = true,      -- nom des enchantements à côté des cases
  showMinimap = true,       -- bouton autour de la minicarte
  minimapAngle = 220,       -- position du bouton (degrés)
}

function NS.DB()
  if type(GearscoreForeverDB) ~= "table" then
    GearscoreForeverDB = {}
  end
  for key, default in pairs(DB_DEFAULTS) do
    if GearscoreForeverDB[key] == nil then
      GearscoreForeverDB[key] = default
    end
  end
  return GearscoreForeverDB
end

-- =========================================================
-- 2. VALEURS SECRÈTES
-- =========================================================
local issecret = issecretvalue or function() return false end

-- Renvoie v, ou nil si v est une valeur secrète inutilisable.
function NS.Safe(v)
  if v == nil or issecret(v) then return nil end
  return v
end

-- UnitGUID sans risque : nil si l'unité n'existe pas ou si le GUID est secret.
function NS.GUID(unit)
  local ok, guid = pcall(UnitGUID, unit)
  if not ok then return nil end
  return NS.Safe(guid)
end

-- =========================================================
-- 3. API OBJETS
-- =========================================================
NS.GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
NS.GetDetailedItemLevelInfo = (C_Item and C_Item.GetDetailedItemLevelInfo)
  or GetDetailedItemLevelInfo

function NS.RequestItem(item)
  if C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, item)
  end
end

-- =========================================================
-- 4. ÉVÉNEMENTS
-- =========================================================
local eventFrame = CreateFrame("Frame")
local handlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local fn = handlers[event]
  if fn then fn(...) end
end)

-- Enregistre chaque événement dans un pcall : un événement absent de ce
-- client est ignoré au lieu de casser le chargement de l'addon.
function NS.RegisterEvents(map)
  for event, fn in pairs(map) do
    if pcall(eventFrame.RegisterEvent, eventFrame, event) then
      handlers[event] = fn
    end
  end
end

-- =========================================================
-- 5. CHAT
-- =========================================================
local PREFIX = "|cff5aa5e6GearScore|r : "

function NS.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

function NS.ColorText(text, r, g, b)
  return string.format("|cff%02x%02x%02x%s|r",
    math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), text)
end
