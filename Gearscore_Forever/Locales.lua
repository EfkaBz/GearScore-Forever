-- Locales.lua - GearScore (Forever)
-- Textes en anglais par défaut, traduits en français sur un client frFR.
-- NS.L["texte anglais"] renvoie la traduction, ou le texte anglais.
-- La langue se choisit dans les options (auto = langue du client) ; elle
-- est lue à chaque appel, donc valable dès que les variables sont chargées.

local _, NS = ...

local FR = {}

function NS.GetLanguage()
  local lang = GearscoreForeverDB and GearscoreForeverDB.language
  if lang == "frFR" or lang == "enUS" then return lang end
  return GetLocale() == "frFR" and "frFR" or "enUS"
end

NS.L = setmetatable({}, { __index = function(_, key)
  if NS.GetLanguage() == "frFR" then return FR[key] or key end
  return key
end })

local L = FR

-- Qualité du score
L["Mythic"] = "Mythique"
L["Legendary"] = "Légendaire"
L["Epic"] = "Épique"
L["Superior"] = "Supérieur"
L["Uncommon"] = "Inhabituel"
L["Common"] = "Commun"
L["Poor"] = "Médiocre"

-- Infobulles
L["GearScore (hunter)"] = "GearScore (chasseur)"

-- Chat et commandes
L["v%s loaded. Type /gs for help."] = "v%s chargé. Tapez /gs pour l'aide."
L["%s: %s (%s) - avg iLvl %d"] = "%s : %s (%s) - iLvl moyen %d"
L["v%s - commands:"] = "v%s - commandes :"
L["  /gs  - your GearScore"] = "  /gs  - votre GearScore"
L["  /gs target  - inspect and show your target's GearScore"] = "  /gs target  - inspecte et affiche le GearScore de votre cible"
L["  /gs group (party, raid)  - known GearScores of party / raid members"] = "  /gs group (party, raid)  - GearScores connus du groupe / raid"
L["  /gs config  - open the options window"] = "  /gs config  - ouvre la fenêtre d'options"
L["  /gs options  - show option states"] = "  /gs options  - affiche l'état des options"
L["  /gs <option>  - toggle: "] = "  /gs <option>  - active / désactive : "
L["You are not in a group."] = "Vous n'êtes pas en groupe."
L["Group GearScore:"] = "GearScore du groupe :"
L["  %d member(s) not inspected yet: mouse over them while in range."] = "  %d membre(s) pas encore inspecté(s) : survolez-les à portée."
L["enabled"] = "activé"
L["disabled"] = "désactivé"
L["Target a player."] = "Ciblez un joueur."
L["Cannot inspect (out of range, in combat or too soon)."] = "Inspection impossible (hors de portée, en combat ou trop tôt)."
L["  Automatic color bracket: %d points (best GS seen: %d)"] = "  Palier de couleur automatique : %d points (meilleur GS vu : %d)"

-- Options
L["GearScore in item tooltips"] = "GearScore dans l'infobulle des objets"
L["GearScore in player tooltips"] = "GearScore dans l'infobulle des joueurs"
L["Average item level"] = "Niveau d'objet moyen"
L["Auto-inspect on mouseover"] = "Inspection automatique au survol"
L["GearScore on character sheet"] = "GearScore sur la fiche de personnage"
L["GearScore on inspect window"] = "GearScore sur la fenêtre d'inspection"
L["Enchants next to equipment slots"] = "Enchantements à côté des emplacements"
L["Minimap button"] = "Bouton de la minicarte"

L["Tooltips"] = "Infobulles"
L["Character & inspect"] = "Personnage et inspection"
L["Interface"] = "Interface"
L["Score of the item under the mouse"] = "Score de l'objet sous la souris"
L["Item level in item tooltips"] = "Niveau d'objet dans l'infobulle des objets"
L["Item level of the item under the mouse"] = "Niveau d'objet de l'objet sous la souris"
L["Item Level"] = "Niveau d'objet"
L["GS with iLvl below it on your character sheet"] = "GS et iLvl l'un sous l'autre sur la fiche"
L["GS with iLvl below it in the inspect window"] = "GS et iLvl l'un sous l'autre à l'inspection"
L["Score of players you mouse over"] = "Score des joueurs survolés"
L["Average item level next to the score"] = "Niveau d'objet moyen à côté du score"
L["Main talent tree and points per tree (Fire 0/48/3)"] = "Arbre principal et points par arbre (Feu 0/48/3)"
L["Talent spec in player tooltips"] = "Spécialisation dans l'infobulle des joueurs"
L["Inspect players automatically on mouseover"] = "Inspecte automatiquement les joueurs survolés"
L["GS and iLvl under your character model"] = "GS et iLvl sous votre personnage"
L["GS and iLvl in the inspect window"] = "GS et iLvl dans la fenêtre d'inspection"
L["Enchant name next to each equipment slot"] = "Enchantement à côté de chaque emplacement"
L["Show the minimap button"] = "Affiche le bouton de la minicarte"

-- Talents
L["Talents button on inspect window"] = "Bouton Talents sur la fenêtre d'inspection"
L["Opens the full talent trees of the inspected player"] = "Ouvre les arbres de talents complets du joueur inspecté"
L["  /gs talents  - talents of your target (yours without a target)"] = "  /gs talents  - talents de votre cible (les vôtres sans cible)"
L["Talents"] = "Talents"
L["%s: %d points"] = "%s : %d points"
L["Rank %d/%d"] = "Rang %d/%d"
L["%d points"] = "%d points"
L["Level %d"] = "Niveau %d"
L["Reading talents..."] = "Lecture des talents..."
L["Talents unavailable (out of range?)."] = "Talents indisponibles (hors de portée ?)."
L["Tree"] = "Arbre"
L["Arms"] = "Armes"
L["Fury"] = "Fureur"
L["Protection"] = "Protection"
L["Holy"] = "Sacré"
L["Retribution"] = "Vindicte"
L["Beast Mastery"] = "Maîtrise des bêtes"
L["Marksmanship"] = "Précision"
L["Survival"] = "Survie"
L["Assassination"] = "Assassinat"
L["Combat"] = "Combat"
L["Subtlety"] = "Finesse"
L["Discipline"] = "Discipline"
L["Shadow"] = "Ombre"
L["Elemental"] = "Élémentaire"
L["Enhancement"] = "Amélioration"
L["Restoration"] = "Restauration"
L["Arcane"] = "Arcanes"
L["Fire"] = "Feu"
L["Frost"] = "Givre"
L["Affliction"] = "Affliction"
L["Demonology"] = "Démonologie"
L["Destruction"] = "Destruction"
L["Balance"] = "Équilibre"
L["Feral Combat"] = "Combat farouche"

-- Bouton de la minicarte
L["Click: options"] = "Clic : options"
L["Drag: move"] = "Glisser : déplacer"

-- Choix de la langue
L["Language"] = "Langue"
L["Automatic"] = "Automatique"
L["The interface will reload to apply the language."] = "L'interface va être rechargée pour appliquer la langue."
L["Reload"] = "Recharger"

-- Choix du thème
L["Default"] = "Par défaut"
L["The interface will reload to apply the theme."] = "L'interface va être rechargée pour appliquer le thème."
L["Cancel"] = "Annuler"
