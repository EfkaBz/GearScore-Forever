-- Commands.lua - GearScore (Forever)
-- /gs and /gearscore commands.

local _, NS = ...
local L = NS.L

local OPTIONS = {
  item     = { key = "showItemTooltip", label = "GearScore in item tooltips" },
  player   = { key = "showUnitTooltip", label = "GearScore in player tooltips" },
  ilvl     = { key = "showItemLevel",   label = "Average item level" },
  auto     = { key = "autoInspect",     label = "Auto-inspect on mouseover" },
  sheet    = { key = "showPaperDoll",   label = "GearScore on character sheet" },
  inspect  = { key = "showInspect",     label = "GearScore on inspect window" },
  enchants = { key = "showEnchants",    label = "Enchants next to equipment slots" },
  minimap  = { key = "showMinimap",     label = "Minimap button" },
}
local OPTION_ORDER = { "item", "player", "ilvl", "auto", "sheet", "inspect", "enchants", "minimap" }
NS.OPTIONS, NS.OPTION_ORDER = OPTIONS, OPTION_ORDER
-- Former French command names, kept as aliases.
local ALIASES = { joueur = "player", fiche = "sheet", cible = "target", groupe = "group" }

local function ClassColored(name, class)
  local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if color then return NS.ColorText(name or "?", color.r, color.g, color.b) end
  return name or "?"
end

function NS.PrintEntry(entry)
  local r, g, b, desc = NS.GetQuality(entry.score)
  NS.Print(string.format(L["%s: %s (%s) - avg iLvl %d"],
    ClassColored(entry.name, entry.class),
    NS.ColorText(tostring(entry.score), r, g, b), desc, entry.ilvl))
end

local function Help()
  NS.Print(L["v%s - commands:"]:format(NS.VERSION))
  print(L["  /gs  - your GearScore"])
  print(L["  /gs target  - inspect and show your target's GearScore"])
  print(L["  /gs group (party, raid)  - known GearScores of party / raid members"])
  print(L["  /gs config  - open the options window"])
  print(L["  /gs options  - show option states"])
  print(L["  /gs <option>  - toggle: "] .. table.concat(OPTION_ORDER, ", "))
end

local function PrintGroup()
  local prefix, count
  if IsInRaid() then prefix, count = "raid", GetNumGroupMembers()
  elseif IsInGroup() then prefix, count = "party", GetNumSubgroupMembers()
  else NS.Print(L["You are not in a group."]) return end

  local rows = { NS.GetPlayerEntry() }
  local unknown = 0
  for i = 1, count do
    local unit = prefix .. i
    local guid = NS.GUID(unit)
    if guid and guid ~= NS.GUID("player") then
      local entry = NS.cache[guid]
      if entry then rows[#rows + 1] = entry else unknown = unknown + 1 end
    end
  end
  table.sort(rows, function(a, b) return a.score > b.score end)
  NS.Print(L["Group GearScore:"])
  for _, entry in ipairs(rows) do NS.PrintEntry(entry) end
  if unknown > 0 then
    print(string.format(L["  %d member(s) not inspected yet: mouse over them while in range."], unknown))
  end
end

local function RefreshDisplays()
  if NS.UpdatePaperDoll then NS.UpdatePaperDoll() end
  if NS.UpdateInspect then NS.UpdateInspect() end
  if NS.UpdateEnchants then NS.UpdateEnchants() end
  if NS.UpdateMinimap then NS.UpdateMinimap() end
  if NS.UpdateOptionsPanel then NS.UpdateOptionsPanel() end
end
NS.RefreshDisplays = RefreshDisplays

local function OnOff(value)
  return value and "|cff00ff00" .. L["enabled"] .. "|r" or "|cffff0000" .. L["disabled"] .. "|r"
end

SLASH_GEARSCOREFOREVER1 = "/gs"
SLASH_GEARSCOREFOREVER2 = "/gearscore"
SlashCmdList.GEARSCOREFOREVER = function(msg)
  local cmd = strlower(strtrim(msg or ""))
  cmd = ALIASES[cmd] or cmd
  local db = NS.DB()

  if cmd == "" then
    NS.PrintEntry(NS.GetPlayerEntry())
  elseif cmd == "target" then
    if not UnitExists("target") or not UnitIsPlayer("target") then
      NS.Print(L["Target a player."])
    elseif UnitIsUnit("target", "player") then
      NS.PrintEntry(NS.GetPlayerEntry())
    elseif not NS.RequestInspect("target", true, true) then
      local entry = NS.cache[NS.GUID("target") or ""]
      if entry then
        NS.PrintEntry(entry)
      else
        NS.Print(L["Cannot inspect (out of range, in combat or too soon)."])
      end
    end
  elseif cmd == "group" or cmd == "party" or cmd == "raid" then
    PrintGroup()
  elseif cmd == "options" then
    for _, name in ipairs(OPTION_ORDER) do
      local opt = OPTIONS[name]
      print(string.format("  %s: %s  |cff888888(/gs %s)|r", L[opt.label], OnOff(db[opt.key]), name))
    end
    print(string.format(L["  Automatic color bracket: %d points (best GS seen: %d)"],
      NS.GetBracket(), tonumber(db.maxScoreSeen) or 0))
  elseif cmd == "config" or cmd == "menu" then
    NS.ToggleOptions()
  elseif cmd == "debug" then
    NS.debug = not NS.debug
    NS.Print("Debug " .. (NS.debug and "enabled" or "disabled"))
    NS.DebugFrames()
  elseif OPTIONS[cmd] then
    local opt = OPTIONS[cmd]
    db[opt.key] = not db[opt.key]
    NS.Print(L[opt.label] .. ": " .. OnOff(db[opt.key]))
    RefreshDisplays()
  else
    Help()
  end
end
