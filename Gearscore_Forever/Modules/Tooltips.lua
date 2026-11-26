-- Tooltips.lua - GearScore (Forever)
-- GearScore dans les infobulles des objets et des joueurs.

local _, NS = ...

local L_GS = "GearScore"

-- =========================================================
-- 1. INFOBULLE D'OBJET
-- =========================================================
local function OnItemTooltip(tooltip)
  local db = NS.DB()
  if not (db.showItemTooltip or db.showItemLevelTooltip) or not tooltip.GetItem then return end
  local _, link = tooltip:GetItem()
  link = NS.Safe(link)
  if not link then return end

  local score, _, r, g, b, equipLoc = NS.GetItemScore(link)
  if not score or not NS.SlotMOD[equipLoc] or equipLoc == "INVTYPE_BODY" then return end

  if db.showItemLevelTooltip then
    local level = NS.GetItemLevel(link)
    if level and level > 0 then
      tooltip:AddLine(NS.L["Item Level"] .. " : " .. math.floor(level + 0.5), 1, 0.82, 0)
    end
  end
  if not db.showItemTooltip then return end

  tooltip:AddLine(L_GS .. " : " .. score, r, g, b)
  local _, class = UnitClass("player")
  if class == "HUNTER" then
    local hunterScore = NS.GetItemHunterScore(link)
    if hunterScore and hunterScore ~= score then
      tooltip:AddLine(NS.L["GearScore (hunter)"] .. " : " .. hunterScore, r, g, b)
    end
  end
end

-- =========================================================
-- 2. INFOBULLE DE JOUEUR
-- =========================================================
local function AddUnitLines(tooltip, entry)
  local r, g, b = NS.GetQuality(entry.score)
  if NS.DB().showItemLevel then
    tooltip:AddDoubleLine(L_GS .. " : " .. entry.score, "iLvl " .. entry.ilvl, r, g, b, 1, 0.82, 0)
  else
    tooltip:AddLine(L_GS .. " : " .. entry.score, r, g, b)
  end
end

-- Ligne « Feu 0/48/3 » sous le GearScore (une seule fois par infobulle).
local function AddTalentLine(tooltip, guid)
  if tooltip.gsfTalents == guid or not NS.DB().showTalentTooltip or not NS.GetTalentSummary then return false end
  local spec, points, r, g, b = NS.GetTalentSummary(guid)
  if not spec then return false end
  tooltip:AddLine(NS.ColorText(spec, r, g, b) .. " " .. points, 1, 1, 1)
  tooltip.gsfTalents = guid
  return true
end

local function TooltipUnit(tooltip)
  local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
  if not ok then return nil end
  return NS.Safe(unit)
end

local function OnUnitTooltip(tooltip)
  if tooltip ~= GameTooltip or not NS.DB().showUnitTooltip then return end
  local unit = TooltipUnit(tooltip)
  if not unit then return end
  local ok, isPlayer = pcall(UnitIsPlayer, unit)
  if not ok or not NS.Safe(isPlayer) then return end
  local guid = NS.GUID(unit)
  if not guid then return end

  local entry
  if guid == NS.GUID("player") then
    entry = NS.GetPlayerEntry()
  else
    entry = NS.GetCached(guid)
    if not entry then
      NS.RequestInspect(unit)
      entry = NS.cache[guid] -- ancien score, en attendant le nouveau
    end
  end
  if entry and entry.score > 0 then
    AddUnitLines(tooltip, entry)
    tooltip.gsfGuid = guid
  end
  AddTalentLine(tooltip, guid)
end

-- Quand une inspection se termine, compléter l'infobulle déjà affichée.
NS.OnScoreUpdated(function(guid, entry)
  if not GameTooltip:IsShown() or GameTooltip.gsfGuid == guid then return end
  if not NS.DB().showUnitTooltip or entry.score <= 0 then return end
  local unit = TooltipUnit(GameTooltip)
  if unit and NS.GUID(unit) == guid then
    AddUnitLines(GameTooltip, entry)
    GameTooltip.gsfGuid = guid
    AddTalentLine(GameTooltip, guid)
    GameTooltip:Show()
  end
end)

-- Talents lus un peu après le score (relectures différées de Talents.lua).
function NS.NotifyTalents(guid)
  if not GameTooltip:IsShown() or GameTooltip.gsfTalents == guid then return end
  local unit = TooltipUnit(GameTooltip)
  if unit and NS.GUID(unit) == guid and AddTalentLine(GameTooltip, guid) then
    GameTooltip:Show()
  end
end

GameTooltip:HookScript("OnTooltipCleared", function(self) self.gsfGuid = nil; self.gsfTalents = nil end)

local function SafeCall(fn)
  return function(tooltip, ...)
    local ok, err = pcall(fn, tooltip, ...)
    if not ok and NS.debug then NS.Print(err) end
  end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, SafeCall(OnItemTooltip))
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, SafeCall(OnUnitTooltip))
else
  -- ancien moteur (Classic) : scripts OnTooltipSet*
  for _, tt in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
    if tt then tt:HookScript("OnTooltipSetItem", SafeCall(OnItemTooltip)) end
  end
  GameTooltip:HookScript("OnTooltipSetUnit", SafeCall(OnUnitTooltip))
end
