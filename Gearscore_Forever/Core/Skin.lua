-- Skin.lua - GearScore (Forever)
-- Interface entièrement personnalisée, sans modèle Blizzard : palette sobre tirée
-- de l'icône, fenêtres arrondies en 9-slice, animations courtes et discrètes.
-- Textures : Media/UI (blanches, teintées à l'exécution).

local ADDON_NAME, NS = ...

local S = {}
NS.Skin = S

local WHITE = "Interface\\Buttons\\WHITE8x8"
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\UI\\"
S.MEDIA = MEDIA

-- =========================================================
-- PALETTE
-- =========================================================
local function hex(h, a)
  return {
    tonumber(h:sub(2, 3), 16) / 255,
    tonumber(h:sub(4, 5), 16) / 255,
    tonumber(h:sub(6, 7), 16) / 255,
    a or 1,
  }
end

local C = {
  bg1     = hex("#141C28"), -- fenêtre, haut
  bg2     = hex("#0D131C"), -- fenêtre, bas
  card1   = hex("#18212E"), -- section, haut
  card2   = hex("#151D29"), -- section, bas
  well    = hex("#0B1018"), -- creux (sélecteurs, interrupteur éteint)
  border  = hex("#2A3647"),
  hover   = hex("#44597A"),
  accent  = hex("#5AA5E6"), -- le bleu de l'icône, désaturé
  accent2 = hex("#3F83C4"),
  title   = hex("#A9C6E3"),
  text    = hex("#E2E8F0"),
  muted   = hex("#8A98AA"),
  dim     = hex("#5C6A7C"),
  enchant = hex("#7CC790"),
}
S.C = C

local function color(t, a) return t[1], t[2], t[3], a or t[4] end
S.Color = color

local function lerp(a, b, p) return a + (b - a) * p end

local function lerpColor(c1, c2, p)
  return lerp(c1[1], c2[1], p), lerp(c1[2], c2[2], p), lerp(c1[3], c2[3], p), lerp(c1[4] or 1, c2[4] or 1, p)
end
S.LerpColor = lerpColor

-- Dégradé c1 -> c2, de haut en bas (de gauche à droite si horizontal).
local function gradient(tex, c1, c2, horizontal, keepTexture)
  if not keepTexture then tex:SetTexture(WHITE) end
  tex:SetVertexColor(1, 1, 1, 1)
  local orientation = horizontal and "HORIZONTAL" or "VERTICAL"
  local a, b = c1, c2
  if not horizontal then a, b = c2, c1 end -- VERTICAL va de bas en haut
  if tex.SetGradient then
    local function col(c) return { r = c[1], g = c[2], b = c[3], a = c[4] or 1 } end
    if pcall(tex.SetGradient, tex, orientation, col(a), col(b)) then return end
  end
  tex:SetVertexColor(color(c1))
end

-- =========================================================
-- ANIMATIONS
-- =========================================================
local ease = {
  linear = function(p) return p end,
  outCubic = function(p) return 1 - (1 - p) ^ 3 end,
  inOutCubic = function(p) return p < 0.5 and 4 * p ^ 3 or 1 - (-2 * p + 2) ^ 3 / 2 end,
}

local tweens, running = {}, {}
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self, elapsed)
  -- copie : les rappels peuvent lancer ou remplacer des animations
  wipe(running)
  for key, t in pairs(tweens) do running[key] = t end
  for key, t in pairs(running) do
    if tweens[key] == t then
      t.t = t.t + elapsed
      local p = math.min(1, t.t / t.dur)
      t.set(lerp(t.from, t.to, t.ease(p)), p)
      if p >= 1 and tweens[key] == t then
        tweens[key] = nil
        if t.done then t.done() end
      end
    end
  end
  if not next(tweens) then self:Hide() end
end)

-- S.Tween(clé, { dur, from, to, ease, set(valeur, p), done }) ; même clé = remplace.
function S.Tween(key, a)
  a.t, a.dur = 0, a.dur or 0.2
  a.ease = ease[a.ease or "outCubic"]
  tweens[key] = a
  driver:Show()
end

function S.StopTween(key) tweens[key] = nil end

function S.FadeTo(region, alpha, dur, done)
  S.Tween(region, { dur = dur or 0.15, from = region:GetAlpha(), to = alpha,
    set = function(v) region:SetAlpha(v) end, done = done })
end

function S.HoverFade(frame, region, alpha)
  region:SetAlpha(0)
  frame:HookScript("OnEnter", function() S.FadeTo(region, alpha or 1, 0.1) end)
  frame:HookScript("OnLeave", function() S.FadeTo(region, 0, 0.2) end)
end

-- =========================================================
-- POLICE ET TEXTE
-- =========================================================
local fonts = {}

function S.Font(size)
  if not fonts[size] then
    local f = CreateFont("GearscoreForeverFont" .. size)
    f:SetFont(STANDARD_TEXT_FONT, size, "")
    f:SetShadowColor(0, 0, 0, 0.8)
    f:SetShadowOffset(1, -1)
    fonts[size] = f
  end
  return fonts[size]
end

function S.Text(parent, size, col, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFontObject(S.Font(size or 12))
  fs:SetTextColor(color(C[col or "text"]))
  fs:SetJustifyH("LEFT")
  return fs
end

-- =========================================================
-- BOÎTES ARRONDIES
-- =========================================================
local POINTS = {
  { "TOPLEFT", "TOP" }, { "TOP", "TOP" }, { "TOPRIGHT", "TOP" },
  { "LEFT", "MID" }, { "CENTER", "MID" }, { "RIGHT", "MID" },
  { "BOTTOMLEFT", "BOTTOM" }, { "BOTTOM", "BOTTOM" }, { "BOTTOMRIGHT", "BOTTOM" },
}

-- Texture carrée de `size` px, coins de `margin` px, affichés sur `cs` px.
local function slice9(f, file, size, margin, cs, layer, sub)
  local m = margin / size
  local u = { 0, m, 1 - m, 1 }
  local tex = {}
  for i, p in ipairs(POINTS) do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local t = f:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(file)
    t:SetTexCoord(u[col + 1], u[col + 2], u[row + 1], u[row + 2])
    t.row = p[2]
    tex[p[1]] = t
  end
  for _, k in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
    tex[k]:SetSize(cs, cs)
    tex[k]:SetPoint(k)
  end
  tex.TOP:SetPoint("TOPLEFT", tex.TOPLEFT, "TOPRIGHT")
  tex.TOP:SetPoint("BOTTOMRIGHT", tex.TOPRIGHT, "BOTTOMLEFT")
  tex.BOTTOM:SetPoint("TOPLEFT", tex.BOTTOMLEFT, "TOPRIGHT")
  tex.BOTTOM:SetPoint("BOTTOMRIGHT", tex.BOTTOMRIGHT, "BOTTOMLEFT")
  tex.LEFT:SetPoint("TOPLEFT", tex.TOPLEFT, "BOTTOMLEFT")
  tex.LEFT:SetPoint("BOTTOMRIGHT", tex.BOTTOMLEFT, "TOPRIGHT")
  tex.RIGHT:SetPoint("TOPLEFT", tex.TOPRIGHT, "BOTTOMLEFT")
  tex.RIGHT:SetPoint("BOTTOMRIGHT", tex.BOTTOMRIGHT, "TOPRIGHT")
  tex.CENTER:SetPoint("TOPLEFT", tex.TOPLEFT, "BOTTOMRIGHT")
  tex.CENTER:SetPoint("BOTTOMRIGHT", tex.BOTTOMRIGHT, "TOPLEFT")
  return tex
end

-- Deux jeux de textures, affichés au pixel près : rayon 10 ou rayon 6.
local ROUND = {
  [10] = { fill = "Round10Fill", edge = "Round10Edge", size = 64, margin = 16 },
  [6] = { fill = "Round6Fill", edge = "Round6Edge", size = 32, margin = 8 },
}

local function setBorderColor(f, r, g, b, a)
  for _, t in pairs(f.edge) do t:SetVertexColor(r, g, b, a or 1) end
end

-- Fond en dégradé (top -> bottom) et bordure de 1 px (border = false : aucune).
function S.Rounded(f, radius, top, bottom, border)
  local r = ROUND[radius]
  for _, t in pairs(slice9(f, MEDIA .. r.fill, r.size, r.margin, r.margin, "BACKGROUND", -7)) do
    if t.row == "TOP" then t:SetVertexColor(color(top))
    elseif t.row == "BOTTOM" then t:SetVertexColor(color(bottom))
    else gradient(t, top, bottom, false, true) end
  end
  if border ~= false then
    f.edge = slice9(f, MEDIA .. r.edge, r.size, r.margin, r.margin, "BORDER", 1)
    f.SetBorderColor = setBorderColor
    f:SetBorderColor(color(border or C.border))
  end
  return f
end

-- Ombre douce autour d'un cadre.
function S.Shadow(f, size, alpha)
  local holder = CreateFrame("Frame", nil, f)
  holder:SetPoint("TOPLEFT", -size, size)
  holder:SetPoint("BOTTOMRIGHT", size, -size)
  holder:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
  for _, t in pairs(slice9(holder, MEDIA .. "Shadow", 64, 16, size * 16 / 12, "BACKGROUND", -8)) do
    t:SetVertexColor(0, 0, 0, alpha)
  end
  return holder
end

-- Filet de 1 px qui s'estompe sur les deux côtés.
function S.Rule(parent, col, alpha)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetHeight(1)
  local c1, c2 = { col[1], col[2], col[3], 0 }, { col[1], col[2], col[3], alpha or 1 }
  local l = holder:CreateTexture(nil, "ARTWORK")
  l:SetPoint("TOPLEFT")
  l:SetPoint("BOTTOMRIGHT", holder, "BOTTOM")
  gradient(l, c1, c2, true)
  local r = holder:CreateTexture(nil, "ARTWORK")
  r:SetPoint("TOPLEFT", holder, "TOP")
  r:SetPoint("BOTTOMRIGHT")
  gradient(r, c2, c1, true)
  return holder
end

-- =========================================================
-- FENÊTRE
-- =========================================================
local function restoreHome(f)
  local h = f.home
  if not h then return end
  f:ClearAllPoints()
  f:SetPoint(h[1], h[2], h[3], h[4], h[5])
end

local function animateOpen(f)
  -- réouverture pendant la fermeture : on repart de l'opacité courante
  local from = f.closing and f:GetAlpha() or 0
  f.closing = nil
  f:SetAlpha(from) -- évite une image pleine opacité avant la première étape
  S.Tween(f, { dur = 0.18, from = from, to = 1, set = function(v)
    local h = f.home
    f:SetAlpha(v)
    f:ClearAllPoints()
    f:SetPoint(h[1], h[2], h[3], h[4], h[5] - 8 * (1 - v))
  end })
end

function S.Close(f)
  if not f:IsShown() or f.closing then return end
  f.closing = true
  S.Tween(f, { dur = 0.12, from = 0, to = 1, ease = "linear", set = function(v)
    local h = f.home
    f:SetAlpha(1 - v)
    f:ClearAllPoints()
    f:SetPoint(h[1], h[2], h[3], h[4], h[5] - 5 * v)
  end, done = function() f:Hide() end })
end

function S.Toggle(f)
  if not f:IsShown() then f:Show()
  elseif f.closing then animateOpen(f)
  else S.Close(f) end
end

local function CloseButton(parent, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(24, 24)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(MEDIA .. "Disc")
  bg:SetVertexColor(1, 1, 1, 0.07)
  S.HoverFade(b, bg)
  local x = b:CreateTexture(nil, "ARTWORK")
  x:SetSize(14, 14)
  x:SetPoint("CENTER")
  x:SetTexture(MEDIA .. "Close")
  x:SetVertexColor(color(C.muted))
  b:HookScript("OnEnter", function() x:SetVertexColor(color(C.text)) end)
  b:HookScript("OnLeave", function() x:SetVertexColor(color(C.muted)) end)
  b:SetScript("OnClick", onClick)
  return b
end

-- Fenêtre arrondie, déplaçable, ancrée par le haut (son bord haut ne bouge pas
-- quand sa hauteur change).
function S.Window(name, width, height)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(width, height)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(10)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f.home = { "TOP", UIParent, "TOP", 0, -130 }
  restoreHome(f)

  S.Shadow(f, 18, 0.55)
  S.Rounded(f, 10, C.bg1, C.bg2)
  for _, t in pairs(slice9(f, MEDIA .. "InnerGlow", 128, 32, 32, "BACKGROUND", -5)) do
    t:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.05)
  end

  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    S.StopTween(self)
    self.closing = nil
    self:SetAlpha(1)
    restoreHome(self)
    self:StartMoving()
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.home = { "TOPLEFT", UIParent, "BOTTOMLEFT", self:GetLeft(), self:GetTop() }
    restoreHome(self)
  end)

  f.close = CloseButton(f, function() S.Close(f) end)
  f.close:SetPoint("TOPRIGHT", -8, -8)

  f:SetScript("OnShow", animateOpen)
  -- Échap cache directement la fenêtre : on remet tout d'aplomb.
  f:SetScript("OnHide", function(self)
    S.StopTween(self)
    self.closing = nil
    self:SetAlpha(1)
    restoreHome(self)
  end)
  f:Hide()
  return f
end

-- =========================================================
-- SECTION REPLIABLE
-- =========================================================
local SECTION_HEADER = 30

-- bodyHeight : hauteur du contenu. isOpen() / setOpen(bool) : état mémorisé.
-- onStep() est appelé à chaque image de l'animation.
function S.Section(parent, text, bodyHeight, isOpen, setOpen, onStep)
  local s = CreateFrame("Frame", nil, parent)
  S.Rounded(s, 6, C.card1, C.card2)

  local header = CreateFrame("Button", nil, s)
  header:SetPoint("TOPLEFT")
  header:SetPoint("TOPRIGHT")
  header:SetHeight(SECTION_HEADER)

  local chevron = header:CreateTexture(nil, "ARTWORK")
  chevron:SetSize(14, 14)
  chevron:SetPoint("LEFT", 9, 0)
  chevron:SetTexture(MEDIA .. "Chevron")
  chevron:SetVertexColor(color(C.dim))

  local label = S.Text(header, 12, "title")
  label:SetPoint("LEFT", chevron, "RIGHT", 5, 0)
  label:SetText(text)

  header:SetScript("OnEnter", function()
    label:SetTextColor(color(C.text))
    chevron:SetVertexColor(color(C.accent))
  end)
  header:SetScript("OnLeave", function()
    label:SetTextColor(color(C.title))
    chevron:SetVertexColor(color(C.dim))
  end)

  local body = CreateFrame("Frame", nil, s)
  body:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
  body:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
  if body.SetClipsChildren then pcall(body.SetClipsChildren, body, true) end
  s.body = body

  local shown = isOpen() and 1 or 0
  local function apply(p)
    shown = p
    chevron:SetRotation(math.rad(90) * (1 - p)) -- bas = ouvert, droite = replié
    body:SetHeight(math.max(0.01, bodyHeight * p))
    body:SetAlpha(p)
    body:SetShown(p > 0.01)
    s:SetHeight(SECTION_HEADER + bodyHeight * p)
  end
  apply(shown)

  header:SetScript("OnClick", function()
    local open = not isOpen()
    setOpen(open)
    S.Tween(s, { dur = 0.22, from = shown, to = open and 1 or 0, ease = "inOutCubic", set = function(v)
      apply(v)
      onStep()
    end })
  end)
  return s
end

-- =========================================================
-- COMMANDES
-- =========================================================
-- Interrupteur 32 x 16. Sans souris : c'est la ligne qui reçoit le clic.
-- onStep(p) : 0 = éteint, 1 = allumé, à chaque image.
function S.Switch(parent, onStep)
  local w = CreateFrame("Frame", nil, parent)
  w:SetSize(32, 16)

  local track = w:CreateTexture(nil, "ARTWORK", nil, 0)
  track:SetAllPoints()
  track:SetTexture(MEDIA .. "PillFill")
  local edge = w:CreateTexture(nil, "ARTWORK", nil, 1)
  edge:SetAllPoints()
  edge:SetTexture(MEDIA .. "PillEdge")
  local knob = w:CreateTexture(nil, "ARTWORK", nil, 2)
  knob:SetSize(12, 12)
  knob:SetTexture(MEDIA .. "Disc")

  local shown
  local function apply(p)
    shown = p
    knob:ClearAllPoints()
    knob:SetPoint("LEFT", 2 + 16 * p, 0)
    track:SetVertexColor(lerpColor(C.well, C.accent2, p))
    edge:SetVertexColor(lerpColor(C.border, C.accent, p))
    knob:SetVertexColor(lerpColor(C.muted, C.text, p))
    if onStep then onStep(p) end
  end

  function w:SetOn(on, animate)
    local to = on and 1 or 0
    if shown == to then return end
    if animate and shown then
      S.Tween(self, { dur = 0.16, from = shown, to = to, set = apply })
    else
      S.StopTween(self)
      apply(to)
    end
  end
  return w
end

-- Bouton arrondi. primary : fond bleu.
function S.Button(parent, text, width, onClick, primary)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, 24)
  S.Rounded(b, 6,
    primary and C.accent2 or C.card1,
    primary and hex("#336DA6") or C.card2,
    primary and C.accent or C.border)
  local wash = b:CreateTexture(nil, "ARTWORK")
  wash:SetPoint("TOPLEFT", 2, -2)
  wash:SetPoint("BOTTOMRIGHT", -2, 2)
  wash:SetColorTexture(1, 1, 1, 0.06)
  S.HoverFade(b, wash)
  b.text = S.Text(b, 12)
  b.text:SetPoint("CENTER")
  b.text:SetText(text)
  if not primary then
    b:HookScript("OnEnter", function(self) self:SetBorderColor(color(C.hover)) end)
    b:HookScript("OnLeave", function(self) self:SetBorderColor(color(C.border)) end)
  end
  b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 0, -1) end)
  b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER") end)
  b:SetScript("OnClick", onClick)
  return b
end

-- Sélecteur à choix unique : le repère glisse sous l'option choisie.
-- options = { { value = ..., label = ... }, ... }
function S.Segmented(parent, options, segWidth, onSelect)
  local h = 24
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(segWidth * #options, h)
  S.Rounded(f, 6, C.well, C.well)

  local marker = CreateFrame("Frame", nil, f)
  marker:SetSize(segWidth - 4, h - 4)
  S.Rounded(marker, 6, C.card1, C.card2, C.hover)

  local buttons = {}
  local current
  local x = 0
  local function place(v)
    x = v
    marker:ClearAllPoints()
    marker:SetPoint("LEFT", v + 2, 0)
  end

  local function paint()
    for value, b in pairs(buttons) do
      b.text:SetTextColor(color(value == current and C.text or C.muted))
    end
  end

  function f:SetValue(value, animate)
    if value == current then return end
    current = value
    for i, o in ipairs(options) do
      if o.value == value then
        local to = (i - 1) * segWidth
        if animate then
          S.Tween(marker, { dur = 0.18, from = x, to = to, set = place })
        else
          S.StopTween(marker)
          place(to)
        end
      end
    end
    paint()
  end

  for i, o in ipairs(options) do
    local b = CreateFrame("Button", nil, f)
    b:SetSize(segWidth, h)
    b:SetPoint("LEFT", (i - 1) * segWidth, 0)
    b:SetFrameLevel(marker:GetFrameLevel() + 1)
    b.text = S.Text(b, 11, "muted")
    b.text:SetPoint("CENTER")
    b.text:SetText(o.label)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(color(C.text)) end)
    b:SetScript("OnLeave", paint)
    b:SetScript("OnClick", function()
      if o.value ~= current then onSelect(o.value) end
    end)
    buttons[o.value] = b
  end
  return f
end

-- Question posée par-dessus une fenêtre : voile sombre et petite carte.
-- Renvoie un objet avec :Ask(texte, onAccept, onCancel).
function S.Confirm(window, acceptLabel, cancelLabel)
  local veil = CreateFrame("Frame", nil, window)
  veil:SetAllPoints()
  veil:SetFrameLevel(window:GetFrameLevel() + 40)
  veil:EnableMouse(true)
  local black = { 0, 0, 0, 0.55 }
  S.Rounded(veil, 10, black, black, false)

  local card = CreateFrame("Frame", nil, veil)
  card:SetSize(300, 104)
  card:SetFrameLevel(veil:GetFrameLevel() + 2)
  S.Shadow(card, 12, 0.5)
  S.Rounded(card, 10, C.bg1, C.bg2, C.hover)

  local msg = S.Text(card, 12)
  msg:SetPoint("TOPLEFT", 18, -18)
  msg:SetPoint("TOPRIGHT", -18, -18)
  msg:SetJustifyH("CENTER")

  local onAccept, onCancel
  local function dismiss(fn)
    S.FadeTo(veil, 0, 0.12, function()
      veil:Hide()
      if fn then fn() end
    end)
  end
  local accept = S.Button(card, acceptLabel, 110, function() dismiss(onAccept) end, true)
  accept:SetPoint("BOTTOMRIGHT", card, "BOTTOM", -4, 16)
  local cancel = S.Button(card, cancelLabel, 110, function() dismiss(onCancel) end)
  cancel:SetPoint("BOTTOMLEFT", card, "BOTTOM", 4, 16)

  -- Fenêtre fermée pendant la question (Échap) : vaut annulation.
  veil:SetScript("OnHide", function(self)
    S.StopTween(self)
    self:SetAlpha(1)
  end)
  window:HookScript("OnHide", function()
    if veil:IsShown() then
      veil:Hide()
      if onCancel then onCancel() end
    end
  end)
  veil:Hide()

  local dialog = {}
  function dialog:Ask(text, acceptFn, cancelFn)
    onAccept, onCancel = acceptFn, cancelFn
    msg:SetText(text)
    veil:SetAlpha(0)
    veil:Show()
    S.Tween(veil, { dur = 0.16, from = 0, to = 1, set = function(v)
      veil:SetAlpha(v)
      card:ClearAllPoints()
      card:SetPoint("CENTER", 0, -6 * (1 - v))
    end })
  end
  return dialog
end
