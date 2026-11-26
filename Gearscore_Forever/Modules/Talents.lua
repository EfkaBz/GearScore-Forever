-- Talents.lua - GearScore (Forever)
-- Talents complets du joueur inspecté : une fenêtre, un onglet par arbre.
--
-- Forever range les trois arbres Classic côte à côte dans un seul arbre de
-- talents moderne (C_Traits). On relit chaque talent avec sa position, puis :
--   * les talents cachés placés loin des arbres sont écartés ;
--   * les trois arbres sont séparés aux deux plus grands écarts entre colonnes ;
--   * dans chaque arbre, la position donne la colonne et la ligne de la grille.
-- Les talents d'un joueur inspecté sont lus avec la configuration spéciale
-- INSPECT_TRAIT_CONFIG_ID, puis copiés : ils restent consultables après la
-- fin de l'inspection.
--
-- Exception voulue à l'interface personnalisée de l'addon : cette fenêtre et
-- son onglet reprennent l'interface de base du jeu, comme la fenêtre
-- d'inspection à laquelle ils sont accolés.

local _, NS = ...
local L = NS.L

-- Noms des arbres, de gauche à droite (Forever ne les nomme pas).
local TREE_NAMES = {
  WARRIOR = { "Arms", "Fury", "Protection" },
  PALADIN = { "Holy", "Protection", "Retribution" },
  HUNTER  = { "Beast Mastery", "Marksmanship", "Survival" },
  ROGUE   = { "Assassination", "Combat", "Subtlety" },
  PRIEST  = { "Discipline", "Holy", "Shadow" },
  SHAMAN  = { "Elemental", "Enhancement", "Restoration" },
  MAGE    = { "Arcane", "Fire", "Frost" },
  WARLOCK = { "Affliction", "Demonology", "Destruction" },
  DRUID   = { "Balance", "Feral Combat", "Restoration" },
}

local READ_DELAYS = { 0, 0.3, 1 } -- le jeu peut finir de remplir les talents un peu après INSPECT_READY
local WAIT_TIMEOUT = 4

-- talentCache[guid] = { guid, name, class, className, level, trees, total, time }
local talentCache = {}

-- =========================================================
-- LECTURE
-- =========================================================
local function Call(fn, ...)
  if not fn then return nil end
  local ok, a = pcall(fn, ...)
  if ok then return NS.Safe(a) end
end

local function Num(v)
  v = NS.Safe(v)
  return type(v) == "number" and v or 0
end

local function SpellName(spellID)
  if C_Spell and C_Spell.GetSpellName then return Call(C_Spell.GetSpellName, spellID) end
  return GetSpellInfo and Call(GetSpellInfo, spellID)
end

local function SpellIcon(spellID)
  if C_Spell and C_Spell.GetSpellTexture then return Call(C_Spell.GetSpellTexture, spellID) end
  return GetSpellTexture and Call(GetSpellTexture, spellID)
end

local function InspectConfigID()
  return Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID or -1
end

local function PlayerConfigID()
  if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
    return Call(C_ClassTalents.GetActiveConfigID)
  end
end

local function ReadNode(configID, nodeID)
  local info = Call(C_Traits.GetNodeInfo, configID, nodeID)
  if type(info) ~= "table" then return nil end
  local x, y = NS.Safe(info.posX), NS.Safe(info.posY)
  local maxRank = Num(info.maxRanks)
  if type(x) ~= "number" or type(y) ~= "number" or maxRank <= 0 then return nil end

  local entryID = info.activeEntry and NS.Safe(info.activeEntry.entryID)
  if not entryID and type(info.entryIDs) == "table" then entryID = NS.Safe(info.entryIDs[1]) end
  if not entryID then return nil end

  local entry = Call(C_Traits.GetEntryInfo, configID, entryID)
  local defID = type(entry) == "table" and NS.Safe(entry.definitionID)
  local def = defID and Call(C_Traits.GetDefinitionInfo, defID)
  local spellID = type(def) == "table" and NS.Safe(def.spellID)
  local name = type(def) == "table" and NS.Safe(def.overrideName)
  local icon = type(def) == "table" and NS.Safe(def.overrideIcon)
  if spellID then
    name = name or SpellName(spellID)
    icon = icon or SpellIcon(spellID)
  end

  local edges = {}
  if type(info.visibleEdges) == "table" then
    for _, e in ipairs(info.visibleEdges) do
      local target = type(e) == "table" and NS.Safe(e.targetNode)
      if target then edges[#edges + 1] = { target = target, active = NS.Safe(e.isActive) == true } end
    end
  end

  return {
    id = nodeID, x = x, y = y, maxRank = maxRank,
    purchased = Num(info.ranksPurchased),
    active = math.max(Num(info.activeRank), Num(info.currentRank)),
    entryID = entryID, spellID = spellID,
    name = name or "?", icon = icon or 134400, -- point d'interrogation
    edges = edges,
  }
end

local function Median(list)
  if #list == 0 then return 0 end
  table.sort(list)
  return list[math.ceil(#list / 2)]
end

-- Range les talents en arbres, colonnes et lignes.
local function BuildTrees(nodes, class)
  -- rang : les points achetés, ou le rang actif si l'inspection n'en donne pas
  local purchasedTotal = 0
  for _, n in ipairs(nodes) do purchasedTotal = purchasedTotal + n.purchased end
  for _, n in ipairs(nodes) do
    n.rank = math.min(n.maxRank, purchasedTotal > 0 and n.purchased or n.active)
  end

  -- Écarte les talents cachés placés très loin des arbres : ils fausseraient
  -- tout le calcul de la grille. Filtre par écart interquartile.
  local function Keep(field)
    local vals = {}
    for _, n in ipairs(nodes) do vals[#vals + 1] = n[field] end
    table.sort(vals)
    local count = #vals
    local q1 = vals[math.max(1, math.ceil(count * 0.25))]
    local q3 = vals[math.max(1, math.ceil(count * 0.75))]
    local med = vals[math.max(1, math.ceil(count * 0.5))]
    local iqr = q3 - q1
    if iqr <= 0 then return nil end
    return med - iqr * 2.5, med + iqr * 2.5
  end
  local xLo, xHi = Keep("x")
  local yLo, yHi = Keep("y")
  local inRange = {}
  for _, n in ipairs(nodes) do
    if (not xLo or (n.x >= xLo and n.x <= xHi)) and (not yLo or (n.y >= yLo and n.y <= yHi)) then
      inRange[#inRange + 1] = n
    end
  end
  nodes = inRange

  -- Regroupe des positions proches (petits décalages entre talents d'une
  -- même colonne ou ligne). Renvoie les centres des groupes, triés.
  local function Cluster(values, tolerance)
    table.sort(values)
    local groups = {}
    for _, v in ipairs(values) do
      local g = groups[#groups]
      if g and v - g.first <= tolerance then
        g.sum, g.count = g.sum + v, g.count + 1
      else
        groups[#groups + 1] = { first = v, sum = v, count = 1 }
      end
    end
    local centers = {}
    for i, g in ipairs(groups) do centers[i] = g.sum / g.count end
    return centers
  end
  local function Nearest(centers, v)
    local best, dist = 1, math.huge
    for i, c in ipairs(centers) do
      if math.abs(c - v) < dist then best, dist = i, math.abs(c - v) end
    end
    return best
  end

  -- pas de base : le plus petit écart « franc » entre deux positions X
  local xsRaw, minX, maxX = {}, math.huge, -math.huge
  for _, n in ipairs(nodes) do
    xsRaw[#xsRaw + 1] = n.x
    minX, maxX = math.min(minX, n.x), math.max(maxX, n.x)
  end
  local spread = math.max(1, maxX - minX)
  local cols = Cluster(xsRaw, spread * 0.02)
  local gaps = {}
  for i = 2, #cols do gaps[#gaps + 1] = { i = i, d = cols[i] - cols[i - 1] } end

  -- trois arbres : coupure aux deux plus grands écarts entre colonnes
  local names = TREE_NAMES[class or ""] or {}
  local treeCount = math.min(#names > 0 and #names or 3, #cols)
  local sorted = {}
  for i, g in ipairs(gaps) do sorted[i] = g end
  table.sort(sorted, function(p, q) return p.d > q.d end)
  local split = {}
  for i = 1, treeCount - 1 do
    if sorted[i] then split[sorted[i].i] = true end
  end
  local treeOfCol, colInTree, treeIndex, inner = {}, {}, 1, {}
  for i = 1, #cols do
    if split[i] then treeIndex = treeIndex + 1 end
    treeOfCol[i] = treeIndex
  end
  for _, g in ipairs(gaps) do
    if not split[g.i] then inner[#inner + 1] = g.d end
  end
  local colStep = Median(inner)
  if colStep <= 0 then colStep = spread / 11 end

  -- colonne dans l'arbre : distance au bord gauche de l'arbre, en pas
  local treeLeft = {}
  for i, c in ipairs(cols) do
    local t = treeOfCol[i]
    treeLeft[t] = treeLeft[t] and math.min(treeLeft[t], c) or c
  end
  for i, c in ipairs(cols) do
    colInTree[i] = math.floor((c - treeLeft[treeOfCol[i]]) / colStep + 0.5)
  end

  -- lignes : grille commune aux trois arbres
  local ysRaw = {}
  for _, n in ipairs(nodes) do ysRaw[#ysRaw + 1] = n.y end
  local rowCenters = Cluster(ysRaw, colStep * 0.4)
  local rowGaps = {}
  for i = 2, #rowCenters do rowGaps[#rowGaps + 1] = rowCenters[i] - rowCenters[i - 1] end
  local rowStep = Median(rowGaps)
  if rowStep <= 0 then rowStep = colStep end
  local top = rowCenters[1] or 0

  local trees, byID = {}, {}
  for i = 1, treeIndex do
    trees[i] = { name = L[names[i] or "Tree"] .. (names[i] and "" or (" " .. i)), nodes = {}, points = 0,
      cols = 4, rows = 1 }
  end
  for _, n in ipairs(nodes) do
    local ci = Nearest(cols, n.x)
    n.tree = treeOfCol[ci]
    n.col = colInTree[ci]
    n.row = math.floor((rowCenters[Nearest(rowCenters, n.y)] - top) / rowStep + 0.5)
    -- garde-fou : un talent caché très loin ne doit pas étirer la grille
    if n.row <= 10 and n.col <= 6 then
      local t = trees[n.tree]
      t.nodes[#t.nodes + 1] = n
      t.points = t.points + n.rank
      t.cols = math.max(t.cols, n.col + 1)
      t.rows = math.max(t.rows, n.row + 1)
      byID[n.id] = n
    end
  end

  for _, t in ipairs(trees) do
    -- liens vers les talents du même arbre uniquement
    for _, n in ipairs(t.nodes) do
      local kept = {}
      for _, e in ipairs(n.edges) do
        local target = byID[e.target]
        if target and target.tree == n.tree then
          kept[#kept + 1] = { node = target, active = e.active or (n.rank >= n.maxRank and n.rank > 0) }
        end
      end
      n.edges = kept
    end
  end
  return trees
end

-- Lit une configuration de talents. Renvoie les arbres et le total, ou nil.
local function ReadConfig(configID, class)
  if not (configID and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes) then return nil end
  local config = Call(C_Traits.GetConfigInfo, configID)
  if type(config) ~= "table" or type(config.treeIDs) ~= "table" then return nil end

  local nodes = {}
  for _, treeID in ipairs(config.treeIDs) do
    local ids = Call(C_Traits.GetTreeNodes, NS.Safe(treeID))
    if type(ids) == "table" then
      for _, nodeID in ipairs(ids) do
        local n = NS.Safe(nodeID) and ReadNode(configID, nodeID)
        if n then nodes[#nodes + 1] = n end
      end
    end
  end
  if #nodes == 0 then return nil end

  local trees = BuildTrees(nodes, class)
  local total = 0
  for _, t in ipairs(trees) do total = total + t.points end
  return trees, total
end

local function Snapshot(unit, guid, configID)
  local className, class = UnitClass(unit)
  class, className = NS.Safe(class), NS.Safe(className)
  local ok, trees, total = pcall(ReadConfig, configID, class)
  if not ok or not trees then return nil end
  return {
    guid = guid, name = NS.Safe(UnitName(unit)), class = class, className = className,
    level = NS.Safe(UnitLevel(unit)), trees = trees, total = total, time = GetTime(),
  }
end

-- =========================================================
-- FENÊTRE (interface de base du jeu, comme la fenêtre d'inspection)
-- =========================================================
-- Cadre à portrait du jeu, onglets du jeu en bas (un par arbre) et, dans
-- chaque arbre, les boutons de talents à la manière de la fenêtre de
-- talents Classic : case colorée, rang dans un petit cadre, fond de l'arbre.

local BTN, CELL = 37, 58            -- bouton de talent, pas de la grille
local INSET_L, INSET_R, INSET_T, INSET_B = 4, 6, 60, 26
local GRID_TOP, GRID_BOTTOM = 40, 22
local MIN_WIDTH = 338               -- largeur de la fenêtre d'inspection

-- Fonds des arbres Classic (Interface\TalentFrame\<nom>-TopLeft, etc.).
local TREE_BACKGROUNDS = {
  WARRIOR = { "WarriorArms", "WarriorFury", "WarriorProtection" },
  PALADIN = { "PaladinHoly", "PaladinProtection", "PaladinCombat" },
  HUNTER  = { "HunterBeastMastery", "HunterMarksmanship", "HunterSurvival" },
  ROGUE   = { "RogueAssassination", "RogueCombat", "RogueSubtlety" },
  PRIEST  = { "PriestDiscipline", "PriestHoly", "PriestShadow" },
  SHAMAN  = { "ShamanElementalCombat", "ShamanEnhancement", "ShamanRestoration" },
  MAGE    = { "MageArcane", "MageFire", "MageFrost" },
  WARLOCK = { "WarlockCurses", "WarlockSummoning", "WarlockDestruction" },
  DRUID   = { "DruidBalance", "DruidFeralCombat", "DruidRestoration" },
}

local COLOR_MAX     = { 1, 0.82, 0 }      -- jaune : talent au maximum
local COLOR_PARTIAL = { 0.1, 1, 0.1 }     -- vert : talent commencé
local COLOR_NONE    = { 0.5, 0.5, 0.5 }   -- gris : aucun point

local window, shown -- shown = instantané affiché
local waitingGUID, waitingSince
local Render
local DockOffset, SyncChecked -- définies avec le bouton d'inspection

local function ClassColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

local function ShowTooltip(button)
  local n = button.node
  if not n then return end
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  local shownRank = math.max(1, n.rank)
  local ok = GameTooltip.SetTraitEntry and pcall(GameTooltip.SetTraitEntry, GameTooltip, n.entryID, shownRank)
  if not ok or GameTooltip:NumLines() == 0 then
    if n.spellID and GameTooltip.SetSpellByID then
      pcall(GameTooltip.SetSpellByID, GameTooltip, n.spellID)
    end
    if GameTooltip:NumLines() == 0 then GameTooltip:AddLine(n.name, 1, 1, 1) end
  end
  local col = n.rank >= n.maxRank and COLOR_MAX or (n.rank > 0 and COLOR_PARTIAL or COLOR_NONE)
  GameTooltip:AddLine(L["Rank %d/%d"]:format(n.rank, n.maxRank), col[1], col[2], col[3])
  GameTooltip:Show()
end

-- Crée un cadre avec le premier modèle du jeu disponible.
local function NewFrame(frameType, parent, templates)
  for _, tpl in ipairs(templates) do
    local ok, f = pcall(CreateFrame, frameType, nil, parent, tpl)
    if ok and f then return f, tpl end
  end
  return CreateFrame(frameType, nil, parent), nil
end

local function SetFrameTitle(f, text)
  if f.SetTitle then
    if pcall(f.SetTitle, f, text) then return end
  end
  local fs = f.TitleText or (f.TitleContainer and f.TitleContainer.TitleText)
  if fs then fs:SetText(text) end
end

local function SetFramePortrait(f, unit, class)
  local tex = (f.PortraitContainer and f.PortraitContainer.portrait) or f.portrait or f.Portrait
  if not tex then return end
  if unit and UnitExists(unit) and pcall(SetPortraitTexture, tex, unit) then
    tex:SetTexCoord(0, 1, 0, 1)
    return
  end
  local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
  if coords then
    tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    tex:SetTexCoord(unpack(coords))
  end
end

-- Bouton de talent façon Classic.
local function CreateTalentButton(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(BTN, BTN)

  b.slot = b:CreateTexture(nil, "BACKGROUND")
  b.slot:SetSize(64, 64)
  b.slot:SetPoint("CENTER")
  b.slot:SetTexture("Interface\\Buttons\\UI-EmptySlot-White")

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()

  b.rankBorder = b:CreateTexture(nil, "OVERLAY")
  b.rankBorder:SetSize(32, 32)
  b.rankBorder:SetPoint("CENTER", b, "BOTTOMRIGHT")
  b.rankBorder:SetTexture("Interface\\TalentFrame\\TalentFrame-RankBorder")

  b.rank = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.rank:SetPoint("CENTER", b.rankBorder, "CENTER", 0, 0)

  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnEnter", ShowTooltip)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local function PaintTalentButton(b, n)
  b.node = n
  b.icon:SetTexture(n.icon)
  local col
  if n.rank >= n.maxRank then col = COLOR_MAX
  elseif n.rank > 0 then col = COLOR_PARTIAL
  else col = COLOR_NONE end
  b.slot:SetVertexColor(col[1], col[2], col[3])
  b.icon:SetDesaturated(n.rank == 0)
  b.rank:SetText(n.rank)
  b.rank:SetTextColor(col[1], col[2], col[3])
  b.rank:SetShown(n.rank > 0)
  b.rankBorder:SetShown(n.rank > 0)
end

-- Fond de l'arbre en quatre morceaux, étiré sur la zone de l'arbre.
local function CreateBackground(page)
  page.bg = {}
  for _, part in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight" }) do
    page.bg[part] = page:CreateTexture(nil, "BACKGROUND")
  end
  page.bg.TopLeft:SetPoint("TOPLEFT")
  page.bg.TopRight:SetPoint("TOPLEFT", page.bg.TopLeft, "TOPRIGHT")
  page.bg.BottomLeft:SetPoint("TOPLEFT", page.bg.TopLeft, "BOTTOMLEFT")
  page.bg.BottomRight:SetPoint("TOPLEFT", page.bg.TopLeft, "BOTTOMRIGHT")
end

local function PaintBackground(page, file, w, h)
  local ok = file ~= nil
  for part, tex in pairs(page.bg) do
    if ok then
      local loaded = tex:SetTexture("Interface\\TalentFrame\\" .. file .. "-" .. part)
      if loaded == false or not tex:GetTexture() then ok = false end
    end
  end
  for _, tex in pairs(page.bg) do tex:SetShown(ok) end
  if not ok then return end
  -- Morceaux d'origine : 256 + 64 de large, 256 + 128 de haut, mais les
  -- morceaux de droite et du bas ne sont dessinés qu'en partie (le reste est
  -- noir). On les recadre sur le dessin, puis l'ensemble est étiré sur toute
  -- la zone de l'arbre.
  local RIGHT, BOTTOM = 0.70, 0.58 -- part dessinée des morceaux droit / bas
  local leftW = 256 / (256 + 64 * RIGHT)
  local topH = 256 / (256 + 128 * BOTTOM)
  page.bg.TopLeft:SetTexCoord(0, 1, 0, 1)
  page.bg.TopRight:SetTexCoord(0, RIGHT, 0, 1)
  page.bg.BottomLeft:SetTexCoord(0, 1, 0, BOTTOM)
  page.bg.BottomRight:SetTexCoord(0, RIGHT, 0, BOTTOM)
  page.bg.TopLeft:SetSize(w * leftW, h * topH)
  page.bg.TopRight:SetSize(w * (1 - leftW), h * topH)
  page.bg.BottomLeft:SetSize(w * leftW, h * (1 - topH))
  page.bg.BottomRight:SetSize(w * (1 - leftW), h * (1 - topH))
end

local function CreatePage(parent)
  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints(parent)
  page.buttons, page.lines = {}, {}
  CreateBackground(page)
  page.header = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  page.header:SetPoint("TOP", 0, -14)
  page.grid = CreateFrame("Frame", nil, page)
  page.grid:SetFrameLevel(page:GetFrameLevel() + 2)
  return page
end

local function FillPage(page, tree, class, index, w, h)
  local files = TREE_BACKGROUNDS[class or ""]
  PaintBackground(page, files and files[index], w, h)
  page.header:SetText(L["%s: %d points"]:format(tree.name, tree.points))

  local grid = page.grid
  grid:SetSize(tree.cols * CELL - (CELL - BTN), tree.rows * CELL - (CELL - BTN))
  grid:ClearAllPoints()
  grid:SetPoint("TOP", page, "TOP", 0, -GRID_TOP)

  local buttonOf = {}
  for i, n in ipairs(tree.nodes) do
    local b = page.buttons[i] or CreateTalentButton(grid)
    page.buttons[i] = b
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", n.col * CELL, -n.row * CELL)
    PaintTalentButton(b, n)
    b:Show()
    buttonOf[n] = b
  end
  for i = #tree.nodes + 1, #page.buttons do page.buttons[i]:Hide() end

  -- liens de prérequis, sous les boutons
  local li = 0
  if grid.CreateLine then
    for _, n in ipairs(tree.nodes) do
      for _, e in ipairs(n.edges) do
        local a, b = buttonOf[n], buttonOf[e.node]
        if a and b then
          li = li + 1
          local line = page.lines[li] or grid:CreateLine(nil, "BACKGROUND")
          page.lines[li] = line
          line:SetThickness(4)
          line:SetTexture("Interface\\Buttons\\WHITE8x8")
          line:SetStartPoint("CENTER", a)
          line:SetEndPoint("CENTER", b)
          if e.active then line:SetVertexColor(COLOR_MAX[1], COLOR_MAX[2], COLOR_MAX[3], 0.9)
          else line:SetVertexColor(0.45, 0.45, 0.45, 0.9) end
          line:Show()
        end
      end
    end
  end
  for i = li + 1, #page.lines do page.lines[i]:Hide() end
end

local function SelectTree(index)
  local f = window
  if not (f and shown and shown.trees[index]) then return end
  f.selected = index
  for i, page in ipairs(f.pages) do page:SetShown(i == index) end
  if PanelTemplates_SetTab and f.Tabs then pcall(PanelTemplates_SetTab, f, index) end
end

local function CreateTreeTab(f, i)
  local tab, tpl = NewFrame("Button", f, { "PanelTabButtonTemplate", "CharacterFrameTabButtonTemplate" })
  tab:SetID(i)
  if i == 1 then
    tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 11, 2)
  else
    tab:SetPoint("TOPLEFT", f.Tabs[i - 1], "TOPRIGHT", tpl == "PanelTabButtonTemplate" and 3 or -15, 0)
  end
  tab:SetScript("OnClick", function(self)
    SelectTree(self:GetID())
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
      PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    end
  end)
  return tab
end

local function CreateWindow()
  local f = NewFrame("Frame", UIParent, { "ButtonFrameTemplate", "PortraitFrameTemplate", "BasicFrameTemplateWithInset" })
  _G.GearscoreForeverTalents = f
  tinsert(UISpecialFrames, "GearscoreForeverTalents") -- Échap ferme la fenêtre
  f:SetSize(MIN_WIDTH, 420)
  f:SetPoint("TOP", UIParent, "TOP", 0, -104)
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.docked = false
  end)

  -- zone intérieure : l'encart du modèle, ou la même place sans lui
  f.content = f.Inset
  if not f.content then
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", INSET_L, -INSET_T)
    f.content:SetPoint("BOTTOMRIGHT", -INSET_R, INSET_B)
  end

  f.subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.subtitle:SetPoint("TOP", f, "TOP", 0, -36)

  f.message = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.message:SetPoint("CENTER")

  f.pages, f.Tabs = {}, {}

  f:SetScript("OnHide", function()
    waitingGUID = nil
    GameTooltip:Hide()
    if SyncChecked then SyncChecked() end
  end)
  f:Hide()
  return f
end

-- Affiche un instantané (ou un message s'il n'y en a pas).
function Render(data, message)
  local f = window
  shown = data
  if not data then
    for _, page in ipairs(f.pages) do page:Hide() end
    for _, tab in ipairs(f.Tabs) do tab:Hide() end
    SetFrameTitle(f, L["Talents"])
    f.subtitle:SetText("")
    f.message:SetText(message or "")
    f.message:Show()
    f:SetSize(MIN_WIDTH, 220)
    return
  end
  f.message:Hide()

  local r, g, b = ClassColor(data.class)
  SetFrameTitle(f, NS.ColorText(data.name or "?", r, g, b))
  local unit = data.guid == NS.GUID("player") and "player" or (data.guid and NS.FindUnit(data.guid))
  SetFramePortrait(f, unit, data.class)

  local parts, cols, rows, best = {}, 4, 1, 1
  for i, t in ipairs(data.trees) do
    parts[i] = t.points
    cols = math.max(cols, t.cols)
    rows = math.max(rows, t.rows)
    if t.points > data.trees[best].points then best = i end
  end
  local sub = table.concat(parts, " / ") .. "   -   " .. L["%d points"]:format(data.total)
  local entry = data.guid and NS.GetCached(data.guid)
  if data.guid == NS.GUID("player") then entry = NS.GetPlayerEntry() end
  if entry and entry.score and entry.score > 0 then
    local qr, qg, qb = NS.GetQuality(entry.score)
    sub = sub .. "   -   " .. NS.ColorText("GS " .. entry.score, qr, qg, qb)
  end
  f.subtitle:SetText(sub)

  -- taille : la grille la plus grande des trois arbres
  local w = math.max(MIN_WIDTH - INSET_L - INSET_R, cols * CELL - (CELL - BTN) + 60)
  local h = GRID_TOP + rows * CELL - (CELL - BTN) + GRID_BOTTOM
  f:SetSize(w + INSET_L + INSET_R, h + INSET_T + INSET_B)

  for i, tree in ipairs(data.trees) do
    local page = f.pages[i] or CreatePage(f.content)
    f.pages[i] = page
    FillPage(page, tree, data.class, i, w, h)
    local tab = f.Tabs[i] or CreateTreeTab(f, i)
    f.Tabs[i] = tab
    tab:SetText(tree.name)
    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
    tab:Show()
  end
  for i = #data.trees + 1, #f.pages do f.pages[i]:Hide() end
  for i = #data.trees + 1, #f.Tabs do f.Tabs[i]:Hide() end
  if PanelTemplates_SetNumTabs then pcall(PanelTemplates_SetNumTabs, f, #data.trees) end

  SelectTree(best)
end

local function Open(anchorToInspect)
  window = window or CreateWindow()
  if anchorToInspect and InspectFrame and InspectFrame:IsShown() and (not window:IsShown() or window.docked) then
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", InspectFrame, "TOPRIGHT", DockOffset(), 0)
    window.docked = true
  elseif not anchorToInspect and window.docked then
    window:ClearAllPoints()
    window:SetPoint("TOP", UIParent, "TOP", 0, -104)
    window.docked = false
  end
  window:Show()
end

-- Attend les talents d'un joueur en cours d'inspection.
local function Wait(guid)
  waitingGUID, waitingSince = guid, GetTime()
  Render(nil, L["Reading talents..."])
  C_Timer.After(WAIT_TIMEOUT, function()
    if waitingGUID == guid and window and window:IsShown() and not shown then
      waitingGUID = nil
      Render(nil, L["Talents unavailable (out of range?)."])
    end
  end)
end

local function ShowData(data, anchorToInspect)
  Open(anchorToInspect)
  waitingGUID = nil
  Render(data)
end

-- =========================================================
-- CAPTURE (appelée par Inspect.lua sur INSPECT_READY)
-- =========================================================
local function Store(guid, unit, configID)
  unit = NS.FindUnit(guid, unit)
  if not unit then return end
  local data = Snapshot(unit, guid, configID)
  if not data then return end
  local old = talentCache[guid]
  -- une relecture qui trouve moins de points vient d'une inspection effacée
  if old and GetTime() - old.time < 2 and old.total > data.total then return end
  talentCache[guid] = data
  if NS.NotifyTalents then NS.NotifyTalents(guid) end

  if not (window and window:IsShown()) then return end
  local showingThis = shown and shown.guid == guid
  if waitingGUID == guid or (showingThis and data.total ~= shown.total) then
    local keep = showingThis and window.selected
    ShowData(data, window.docked)
    if keep and keep ~= window.selected then SelectTree(keep, false) end
  end
end

-- Résumé pour les infobulles : arbre principal et points par arbre.
-- Renvoie « Feu », « 0/48/3 », r, g, b (couleur de classe), ou nil.
local playerSnap, playerSnapTime = nil, 0
function NS.GetTalentSummary(guid)
  if not guid then return nil end
  local data
  if guid == NS.GUID("player") then
    if GetTime() - playerSnapTime > 5 then
      playerSnap = Snapshot("player", guid, PlayerConfigID())
      playerSnapTime = GetTime()
    end
    data = playerSnap
  else
    data = talentCache[guid]
  end
  if not data or not data.total or data.total <= 0 or #data.trees == 0 then return nil end
  local parts, best = {}, 1
  for i, t in ipairs(data.trees) do
    parts[i] = t.points
    if t.points > data.trees[best].points then best = i end
  end
  local r, g, b = ClassColor(data.class)
  return data.trees[best].name, table.concat(parts, "/"), r, g, b
end

function NS.CaptureTalents(guid, unit)
  for _, delay in ipairs(READ_DELAYS) do
    if delay == 0 then
      Store(guid, unit, InspectConfigID())
    else
      C_Timer.After(delay, function() Store(guid, unit, InspectConfigID()) end)
    end
  end
end

-- =========================================================
-- OUVERTURE
-- =========================================================
-- Talents de la fenêtre d'inspection ouverte.
local function ShowInspected()
  local unit = InspectFrame and InspectFrame.unit
  local guid = unit and NS.GUID(unit)
  if not guid then return end
  local data = Snapshot(unit, guid, InspectConfigID())
  if data and data.total > 0 then talentCache[guid] = data end
  data = talentCache[guid] or data
  if data then
    ShowData(data, true)
  else
    Open(true)
    Wait(guid)
  end
end

-- /gs talents : la cible, ou soi-même sans cible joueur.
function NS.ShowTalents(unit)
  if not unit or not UnitExists(unit) or not NS.Safe(UnitIsPlayer(unit)) or NS.Safe(UnitIsUnit(unit, "player")) then
    local data = Snapshot("player", NS.GUID("player"), PlayerConfigID())
    if data then ShowData(data) else NS.Print(L["Talents unavailable (out of range?)."]) end
    return
  end
  local guid = NS.GUID(unit)
  if not guid then return end
  if InspectFrame and InspectFrame:IsShown() and InspectFrame.unit and NS.GUID(InspectFrame.unit) == guid then
    ShowInspected()
    return
  end
  local cached = talentCache[guid]
  if NS.RequestInspect(unit, true) then
    if cached then ShowData(cached) else Open(); Wait(guid) end
  elseif cached then
    ShowData(cached)
  else
    NS.Print(L["Cannot inspect (out of range, in combat or too soon)."])
  end
end

-- =========================================================
-- BOUTON SUR LA FENÊTRE D'INSPECTION
-- =========================================================
-- Le bouton reprend l'apparence des onglets latéraux de la fenêtre
-- d'inspection (Personnage, JcJ, Guilde) et se range sous le dernier.
-- Le style est copié à l'exécution depuis l'onglet du dessous : il suit
-- donc ce que Forever affiche, quel que soit le nom de ses textures.
local inspectButton
local TALENT_ICON = "Interface\\Icons\\INV_Misc_Book_11" -- repli

-- Icône de talents du jeu (celle du bouton Talents de la barre de menus).
-- On essaie chaque source et on garde la première que le jeu sait charger.
local TALENT_ICONS = {
  -- texture Classic 32x64 : le dessin occupe le bas, recadré en carré
  { file = "Interface\\Buttons\\UI-MicroButton-Talents-Up", coords = { 0.06, 0.94, 0.42, 0.94 } },
  { atlas = "UI-HUD-MicroMenu-SpecTalents-Up" },
  { file = TALENT_ICON, coords = { 0.08, 0.92, 0.08, 0.92 } },
}

local function ApplyTalentIcon(tex)
  for _, src in ipairs(TALENT_ICONS) do
    if src.atlas then
      local exists = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(src.atlas)
      if exists and tex:SetAtlas(src.atlas, false) ~= false then return end
    else
      -- pas de mode de filtrage ici : SetTexture(..., "TRILINEAR") fait
      -- planter le client Forever
      local ok, loaded = pcall(tex.SetTexture, tex, src.file)
      if ok and loaded ~= false and tex:GetTexture() then
        tex:SetTexCoord(unpack(src.coords))
        return
      end
    end
  end
end

-- Les cadres « interdits » (protégés par le jeu, ex. CommunitiesAddDialog)
-- lèvent une erreur dès qu'on appelle leurs méthodes : on les saute.
local function IsForbidden(f)
  return f.IsForbidden and f:IsForbidden()
end

local function Walk(frame, fn, depth, maxDepth)
  if depth > maxDepth or IsForbidden(frame) then return end
  local ok, children = pcall(function() return { frame:GetChildren() } end)
  if not ok then return end
  for _, child in ipairs(children) do
    fn(child)
    Walk(child, fn, depth + 1, maxDepth)
  end
end

-- Bord droit de la colonne d'emplacements de droite : les onglets latéraux
-- sont au-delà. (Le cadre InspectFrame peut être plus large que ce qu'on
-- voit : son bord droit ne sert pas de repère.)
local function SlotsRight()
  local best
  for _, s in ipairs({ { "HandsSlot", 10 }, { "Finger0Slot", 11 }, { "Trinket1Slot", 14 } }) do
    local slot = NS.FindSlot and NS.FindSlot(InspectFrame, "Inspect", s[1], s[2])
    local r = slot and slot:IsVisible() and slot:GetRight()
    if r and (not best or r > best) then best = r end
  end
  return best
end

local function IsCloseButton(f)
  local name = f:GetName()
  return f == InspectFrame.CloseButton or f == _G.InspectFrameCloseButton
    or (name and name:find("Close")) or false
end

-- Position et taille d'un cadre dans l'échelle de la fenêtre d'inspection
-- (les onglets latéraux sont souvent des onglets 32 px agrandis par SetScale).
local function Rect(f)
  local l, bottom, w, h = f:GetRect()
  if not (l and bottom and w and h) then return nil end
  local k = f:GetEffectiveScale() / InspectFrame:GetEffectiveScale()
  return { l = l * k, r = (l + w) * k, b = bottom * k, t = (bottom + h) * k,
    w = w * k, h = h * k, x = (l + w / 2) * k, y = (bottom + h / 2) * k, k = k }
end

-- Un onglet latéral : cadre à peu près carré, à droite de la colonne
-- d'emplacements, à la hauteur de la fenêtre d'inspection.
local function IsSideTab(f, minX)
  if f == inspectButton or (window and f == window) or not f.GetRect or not f:IsVisible()
    or IsCloseButton(f) then
    return false
  end
  local top, bottom = InspectFrame:GetTop(), InspectFrame:GetBottom()
  local r = Rect(f)
  if not (top and r) then return false end
  return r.x > minX and r.x < minX + 160 and r.y < top and r.y > bottom
    and r.w >= 26 and r.w <= 110 and r.h >= 26 and r.h <= 110 and math.abs(r.w - r.h) <= 20
end

local function HasAncestor(f, set)
  local p = f:GetParent()
  while p do
    if set[p] then return true end
    p = p:GetParent()
  end
  return false
end

-- Onglets latéraux visibles, du haut vers le bas. Ils peuvent dépendre de
-- la fenêtre d'inspection ou être posés directement sur l'écran.
local function FindSideTabs()
  local found, seen = {}, {}
  local right = InspectFrame:GetRight()
  if not right then return {} end
  local minX = (SlotsRight() or (right - 90)) + 4
  local function consider(f)
    if type(f) == "table" and not seen[f] then
      seen[f] = true
      local ok, yes = pcall(IsSideTab, f, minX)
      if ok and yes then found[f] = true end
    end
  end
  for i = 1, 6 do consider(_G["InspectFrameTab" .. i]) end
  if type(InspectFrame.Tabs) == "table" then
    for _, t in pairs(InspectFrame.Tabs) do consider(t) end
  end
  Walk(InspectFrame, consider, 0, 5)
  Walk(UIParent, consider, 0, 1)
  -- un onglet et son icône peuvent être retenus tous les deux : on garde l'onglet
  local tabs = {}
  for f in pairs(found) do
    if not HasAncestor(f, found) then tabs[#tabs + 1] = f end
  end
  table.sort(tabs, function(a, b) return Rect(a).t > Rect(b).t end)
  -- Deux cadres posés au même endroit (l'onglet et un cadre de surbrillance
  -- ou de sélection plus grand, trouvé sous UIParent) ne comptent que pour
  -- un onglet : on garde le plus petit, sinon le bouton hérite de la taille
  -- du grand cadre et se colle à l'onglet du dessus (écart nul).
  local unique = {}
  for _, f in ipairs(tabs) do
    local r, prev = Rect(f), unique[#unique]
    local pr = prev and Rect(prev)
    if pr and math.abs(r.y - pr.y) < math.min(r.h, pr.h) / 2 then
      if r.w < pr.w then unique[#unique] = f end
    else
      unique[#unique + 1] = f
    end
  end
  return unique
end

-- /gs debug : ce que l'addon voit à droite de la fenêtre d'inspection.
function NS.DebugTalentTabs()
  if not (InspectFrame and InspectFrame:IsShown()) then
    NS.Print("Talents tab: open an inspect window first.")
    return
  end
  local tabs = FindSideTabs()
  NS.Print("Talents tab: " .. #tabs .. " side tab(s) found, button "
    .. (inspectButton and (inspectButton:IsVisible() and "visible" or "hidden") or "missing")
    .. ", slots right " .. tostring(SlotsRight()) .. ", frame right " .. tostring(InspectFrame:GetRight()))
  for i, t in ipairs(tabs) do
    local r = Rect(t)
    print(string.format("  %d. %s (%s) %dx%d scale %.2f", i, t:GetName() or tostring(t),
      t:GetObjectType(), r.w, r.h, r.k))
  end
  -- détail du dernier onglet : ses textures et leur cadrage, pour copier son look
  local last = tabs[#tabs]
  if last then
    local keys = {}
    for k, v in pairs(last) do if type(v) == "table" then keys[v] = k end end
    local function dump(region, indent)
      local w, h = region:GetSize()
      local line = string.format("%s%s %s %dx%d", indent, keys[region] or region:GetName() or "?",
        region:GetObjectType(), w or 0, h or 0)
      if region:IsObjectType("Texture") then
        local p, rel, rp, x, y = region:GetPoint(1)
        line = line .. string.format(" tex=%s atlas=%s layer=%s pt=%s/%s %d,%d shown=%s",
          tostring(region:GetTexture()), tostring(region:GetAtlas()), tostring(region:GetDrawLayer()),
          tostring(p), tostring(rp), x or 0, y or 0, tostring(region:IsShown()))
      end
      print(line)
    end
    for _, region in ipairs({ last:GetRegions() }) do dump(region, "    ") end
    for _, child in ipairs({ last:GetChildren() }) do
      dump(child, "    ")
      for _, region in ipairs({ child:GetRegions() }) do dump(region, "      ") end
    end
  end
end

-- Style des onglets latéraux (comme ceux du grimoire Classic) : l'icône,
-- le fond qui dépasse à droite, la surbrillance et l'état sélectionné.
-- Tout est proportionnel à la taille des onglets voisins.
local function StyleTab(b, w, h)
  b:SetSize(w, h)
  local k = w / 32
  if not b.bg then
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    ApplyTalentIcon(b.icon)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    if b.SetCheckedTexture then
      b:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
      -- texture à fond noir prévue pour l'ajout : sans ce mode, elle cache l'icône
      local checked = b:GetCheckedTexture()
      if checked then
        checked:SetBlendMode("ADD")
        checked:SetDrawLayer("OVERLAY")
      end
    end
    local hl = b:GetHighlightTexture()
    if hl then hl:SetBlendMode("ADD") end
  end
  b.bg:SetSize(64 * k, 64 * k)
  b.bg:ClearAllPoints()
  b.bg:SetPoint("TOPLEFT", -3 * k, 11 * k)
end

function SyncChecked()
  if inspectButton and inspectButton.SetChecked then
    inspectButton:SetChecked(window and window:IsShown() and window.docked or false)
  end
end

local TAB_SHRINK = 0.8     -- taille du bouton par rapport aux onglets voisins
local TAB_EXTRA_DOWN = 40-- pixels ajoutés sous l'onglet du dessus

-- Place le bouton sous le dernier onglet visible, au même écart qu'entre eux.
local function PlaceInspectButton()
  local b = inspectButton
  if not b then return end
  local tabs = FindSideTabs()
  local last = tabs[#tabs]
  b:ClearAllPoints()
  if not last then
    -- aucun onglet repéré : 4e place estimée d'après la disposition de Forever
    b:SetScale(1.35)
    StyleTab(b, 32, 32)
    b:SetPoint("TOPLEFT", InspectFrame, "TOPRIGHT", 2 / 1.35, -226 / 1.35)
    return
  end
  -- même échelle et même taille que le plus petit onglet (l'onglet
  -- sélectionné peut être affiché plus grand)
  local lr = Rect(last)
  local ref = last
  for _, t in ipairs(tabs) do
    if Rect(t).w < Rect(ref).w then ref = t end
  end
  -- réglages à l'œil : la taille copiée ressort plus grande que les
  -- onglets voisins, on la réduit et on descend un peu le bouton
  b:SetScale(ref:GetEffectiveScale() / InspectFrame:GetEffectiveScale() * TAB_SHRINK)
  StyleTab(b, ref:GetSize())
  -- même écart qu'entre les deux derniers onglets (dans l'écran de l'inspection)
  local gap = 17 * lr.k
  local prev = tabs[#tabs - 1]
  if prev then
    local g = Rect(prev).b - lr.t
    if g > 2 then gap = g end
  end
  gap = gap + TAB_EXTRA_DOWN
  b:SetPoint("TOP", last, "BOTTOM", 0, -gap / lr.k * (last:GetEffectiveScale() / b:GetEffectiveScale()))
end

-- La fenêtre des talents se colle à droite des onglets.
function DockOffset()
  local right = InspectFrame:GetRight()
  local r = inspectButton and inspectButton:IsShown() and Rect(inspectButton)
  -- le fond de l'onglet dépasse à droite d'environ 90 % de sa largeur
  if right and r then return math.max(4, r.r + r.w * 0.9 + 6 - right) end
  return 4
end

function NS.UpdateTalentButton()
  if not inspectButton then return end
  inspectButton:SetShown(NS.DB().showTalentButton and true or false)
  if not NS.DB().showTalentButton and window and window:IsShown()
    and window.docked then
    window:Hide()
  end
end

local function SetupInspectButton()
  if inspectButton or not InspectFrame then return end
  inspectButton = CreateFrame("CheckButton", "GearscoreForeverTalentsTab", InspectFrame)
  inspectButton:SetFrameLevel(InspectFrame:GetFrameLevel() + 10)
  inspectButton:SetScript("OnClick", function()
    if window and window:IsShown() and shown and InspectFrame.unit
      and shown.guid == NS.GUID(InspectFrame.unit) then
      window:Hide()
    else
      ShowInspected()
    end
    C_Timer.After(0, SyncChecked)
  end)
  inspectButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Talents"], 1, 1, 1)
    GameTooltip:Show()
  end)
  inspectButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  NS.UpdateTalentButton()
  C_Timer.After(0, PlaceInspectButton)

  InspectFrame:HookScript("OnHide", function()
    if window and window:IsShown() and window.docked then
      window:Hide()
    end
  end)
  -- autre joueur inspecté pendant que la fenêtre des talents est ouverte
  InspectFrame:HookScript("OnShow", function()
    C_Timer.After(0, PlaceInspectButton) -- l'onglet Guilde peut apparaître ou disparaître
    C_Timer.After(0.1, function()
      if window and window:IsShown() and window.docked then
        local guid = InspectFrame.unit and NS.GUID(InspectFrame.unit)
        if guid and not (shown and shown.guid == guid) then ShowInspected() end
      end
    end)
  end)
end

local function IsLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
  return IsAddOnLoaded and IsAddOnLoaded(name)
end

local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "PLAYER_LOGIN")
pcall(events.RegisterEvent, events, "ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_LOGIN" then
    if IsLoaded("Blizzard_InspectUI") then SetupInspectButton() end
  elseif name == "Blizzard_InspectUI" then
    SetupInspectButton()
  end
end)
