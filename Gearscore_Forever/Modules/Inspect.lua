-- Inspect.lua - GearScore (Forever)
-- Inspection des autres joueurs et cache des scores par GUID.

local _, NS = ...

-- NS.cache[guid] = { score, ilvl, name, class, time }
NS.cache = {}

local CACHE_TTL = 300        -- secondes avant de réinspecter un joueur
local THROTTLE = 1.5         -- délai minimal entre deux NotifyInspect
local RETRY_DELAY = 0.4      -- attente du cache des objets inspectés
local MAX_RETRIES = 8

local lastRequest = 0
local pending             -- { guid, unit, print }
local listeners = {}      -- fonctions appelées quand un score est mis à jour

function NS.OnScoreUpdated(fn)
  listeners[#listeners + 1] = fn
end

local function Notify(guid, entry)
  for _, fn in ipairs(listeners) do
    pcall(fn, guid, entry)
  end
end

local function InspectFrameOpen()
  return InspectFrame and InspectFrame:IsShown()
end

local UNIT_TOKENS = { "mouseover", "target", "focus" }
for i = 1, 4 do UNIT_TOKENS[#UNIT_TOKENS + 1] = "party" .. i end
for i = 1, 40 do UNIT_TOKENS[#UNIT_TOKENS + 1] = "raid" .. i end

-- Retrouve un jeton d'unité valide pour un GUID.
function NS.FindUnit(guid, preferred)
  if preferred and NS.GUID(preferred) == guid then return preferred end
  if InspectFrameOpen() and InspectFrame.unit and NS.GUID(InspectFrame.unit) == guid then
    return InspectFrame.unit
  end
  for _, unit in ipairs(UNIT_TOKENS) do
    if NS.GUID(unit) == guid then return unit end
  end
end

function NS.GetCached(guid)
  local entry = guid and NS.cache[guid]
  if entry and GetTime() - entry.time < CACHE_TTL then
    return entry
  end
end

-- Score du joueur lui-même (toujours calculable, pas d'inspection).
function NS.GetPlayerEntry()
  local score, ilvl = NS.GetUnitScore("player")
  local _, class = UnitClass("player")
  return { score = score, ilvl = ilvl, name = UnitName("player"), class = class, time = GetTime() }
end

-- Lance une inspection. force = ignore l'option d'inspection automatique.
function NS.RequestInspect(unit, force, printResult)
  if not unit or InCombatLockdown() then return false end
  if not force and not NS.DB().autoInspect then return false end
  if InspectFrameOpen() then return false end
  if GetTime() - lastRequest < THROTTLE then return false end

  local ok, isPlayer = pcall(UnitIsPlayer, unit)
  if not ok or not NS.Safe(isPlayer) then return false end
  local guid = NS.GUID(unit)
  if not guid or guid == NS.GUID("player") then return false end
  if not force and NS.GetCached(guid) then return false end

  local okInspect, canInspect = pcall(CanInspect, unit)
  if not okInspect or not NS.Safe(canInspect) then return false end
  local okDist, inRange = pcall(CheckInteractDistance, unit, 1)
  if okDist and NS.Safe(inRange) == false then return false end

  lastRequest = GetTime()
  pending = { guid = guid, unit = unit, print = printResult }
  NotifyInspect(unit)
  return true
end

local function Finish(guid, unit, attempt)
  local isPending = pending and pending.guid == guid
  unit = NS.FindUnit(guid, unit)
  if not unit then
    if isPending then pending = nil end
    return
  end

  local score, ilvl, complete = NS.GetUnitScore(unit)
  if not complete and attempt < MAX_RETRIES then
    C_Timer.After(RETRY_DELAY, function() Finish(guid, unit, attempt + 1) end)
    return
  end

  local _, class = UnitClass(unit)
  local entry = { score = score, ilvl = ilvl, name = UnitName(unit), class = class, time = GetTime() }
  if score > 0 then
    NS.cache[guid] = entry
  end

  if isPending then
    if pending.print then NS.PrintEntry(entry) end
    pending = nil
    -- ne pas couper une inspection ouverte par le joueur
    if not InspectFrameOpen() then ClearInspectPlayer() end
  end
  Notify(guid, entry)
end

NS.RegisterEvents({
  INSPECT_READY = function(guid)
    guid = NS.Safe(guid)
    if not guid then return end
    local unit = pending and pending.guid == guid and pending.unit or nil
    Finish(guid, unit, 0)
  end,
})
