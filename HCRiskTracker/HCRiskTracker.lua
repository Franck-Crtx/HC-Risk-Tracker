local ADDON_NAME = ...

local HCRT = {}

HCRT_DB = HCRT_DB or {}
if HCRT_DB.locked == nil then
    HCRT_DB.locked = true
end

HCRT.defaultPoint = { point = "TOPLEFT", rel = "PlayerFrame", relPoint = "BOTTOMLEFT", x = 106, y = -8 }

HCRT.elapsed = 0
HCRT.UPDATE_INTERVAL = 0.5

HCRT.THRESH = { Y_IN = 35, Y_OUT = 25, R_IN = 70, R_OUT = 55 }

HCRT.REQUIRES_PET = {
    WARLOCK = true,
    HUNTER = true,
}

HCRT.REQUIRES_POISONS = {
    ROGUE = true,
}

local LOCALE = GetLocale and GetLocale() or "enUS"
local IS_FR = (LOCALE == "frFR")

local L = {
    PREFIX = "[HC Risk Tracker]"
    RISK_LABEL = IS_FR and "RISQUE" or "RISK",

    -- UI
    MISSING_LABEL = IS_FR and "MANQUE:" or "MISSING:",
    PET_LABEL = IS_FR and "Familier" or "Pet",
    POISONS_LABEL = IS_FR and "Poisons (2 armes)" or "Poisons (2 weapons)",
    THREAT_LABEL = IS_FR and "MENACES" or "THREATS",

    -- Tooltip
    TOOLTIP_TITLE = "HC Risk Tracker",
    TOOLTIP_THREATS = IS_FR and "Menaces visibles" or "Visible threats",
    TOOLTIP_ELITES = IS_FR and "Elites" or "Elites",
    TOOLTIP_INDOOR = IS_FR and "Interieur" or "Indoors",
    TOOLTIP_COMBAT = IS_FR and "En combat" or "In combat",
    YES = IS_FR and "Oui" or "Yes",
    NO = IS_FR and "Non" or "No",

    -- Alerts
    MISSING_CHAT = IS_FR and "Manque:" or "Missing:",
    LOW_RISK = IS_FR and "Risque faible" or "Low risk",
    HIGH_RISK = IS_FR and "Risque eleve" or "High risk",
    CRIT_RISK = IS_FR and "DANGER critique" or "CRITICAL danger",

    -- System
    LOADED = IS_FR and "Charge. Classe: " or "Loaded. Class: ",
    POS_SAVED = IS_FR and "Position sauvegardee: %s %s %s (%.0f, %.0f)" or "Position saved: %s %s %s (%.0f, %.0f)",
    POS_RESET = IS_FR and "Position reinitialisee." or "Position reset.",
    LOCKED = IS_FR and "Verrouille." or "Locked.",
    UNLOCKED = IS_FR and "Deverrouille : deplacement actif." or "Unlocked: drag enabled.",
    CMDS = IS_FR and "Commandes: /hcrt reset | /hcrt lock | /hcrt unlock" or "Commands: /hcrt reset | /hcrt lock | /hcrt unlock",
}


local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00" .. L.PREFIX .. "|r " .. msg)
end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function GetBand(score)
    if score >= 61 then
        return "RED"
    elseif score >= 31 then
        return "YELLOW"
    else
        return "GREEN"
    end
end

local function GetBandStable(score, lastBand)
    if not lastBand then
        return GetBand(score)
    end

    if lastBand == "GREEN" then
        if score >= HCRT.THRESH.Y_IN then return "YELLOW" end
        return "GREEN"
    end

    if lastBand == "YELLOW" then
        if score >= HCRT.THRESH.R_IN then return "RED" end
        if score <= HCRT.THRESH.Y_OUT then return "GREEN" end
        return "YELLOW"
    end

    if score <= HCRT.THRESH.R_OUT then return "YELLOW" end
    return "RED"
end

HCRT.playerClass = select(2, UnitClass("player"))

HCRT.CLASS_BUFFS = {
    PALADIN = {
        { id = 19740, key = "BLESS_MIGHT" },  -- Blessing of Might
        { id = 19742, key = "BLESS_WISDOM" }, -- Blessing of Wisdom
        { id = 465, key = "DEV_AURA" },       -- Devotion Aura
    },
    WARRIOR = {
        { id = 6673, key = "BATTLE_SHOUT" },  -- Battle Shout
    },
    MAGE = {
        { id = 1459, key = "AI" },            -- Arcane Intellect
        { id = 168, key = "FROST_ARMOR" },    -- Frost Armor
    },
    PRIEST = {
        { id = 1243, key = "FORT" },          -- Power Word: Fortitude
        { id = 588, key = "INNER_FIRE" },     -- Inner Fire
    },
    DRUID = {
        { id = 1126, key = "MOTW" },          -- Mark of the Wild
    },
    HUNTER = {
        { id = 13165, key = "ASPECT_HAWK" },  -- Aspect of the Hawk (MVP)
    },
    SHAMAN = {
        { id = 324, key = "LIGHTNING_SHIELD" }, -- Lightning Shield
    },
    WARLOCK = {
        { id = 687, key = "DEMON_SKIN" },       -- Demon Skin
        { id = 706, key = "DEMON_ARMOR" },      -- Demon Armor
    },
    ROGUE = {},
}

HCRT.REQUIRED_KEYS = {
    PALADIN = { "BLESS_MIGHT", "BLESS_WISDOM", "DEV_AURA" },
    WARRIOR = { "BATTLE_SHOUT" },
    MAGE = { "AI", "FROST_ARMOR" },
    PRIEST = { "FORT", "INNER_FIRE" },
    DRUID = { "MOTW" },
    HUNTER = { "ASPECT_HAWK" },
    SHAMAN = { "LIGHTNING_SHIELD" },
    WARLOCK = { "DEMON_SKIN_OR_ARMOR" },
    ROGUE = {},
}

HCRT.classBuffs = HCRT.CLASS_BUFFS[HCRT.playerClass] or {}
HCRT.requiredKeys = HCRT.REQUIRED_KEYS[HCRT.playerClass] or {}

HCRT.requiredByKey = {}
do
    for _, b in ipairs(HCRT.classBuffs) do
        HCRT.requiredByKey[b.key] = b.id
    end
end

HCRT.lastScan = {
    threats = 0,
    elites = 0,
    indoors = false,
    inCombat = false,
}

HCRT.frame = CreateFrame("Frame", "HCRiskTrackerFrame", UIParent)

HCRT.bar = CreateFrame("StatusBar", "HCRiskTrackerBar", UIParent)
HCRT.bar:SetSize(160, 16)
HCRT.bar:SetMinMaxValues(0, 100)
HCRT.bar:SetValue(0)
HCRT.bar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")

HCRT.bg = HCRT.bar:CreateTexture(nil, "BACKGROUND")
HCRT.bg:SetAllPoints(true)
HCRT.bg:SetTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
HCRT.bg:SetVertexColor(0, 0, 0, 0.5)

HCRT.text = HCRT.bar:CreateFontString(nil, "OVERLAY")
HCRT.text:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
HCRT.text:SetPoint("CENTER", HCRT.bar, "CENTER", 0, 0)
HCRT.text:SetText(L.RISK_LABEL .. " 0")

HCRT.detail = HCRT.bar:CreateFontString(nil, "OVERLAY")
HCRT.detail:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
HCRT.detail:SetPoint("TOPLEFT", HCRT.bar, "BOTTOMLEFT", 0, -5)
HCRT.detail:SetText("")

local function ApplyPosition()
    HCRT.bar:ClearAllPoints()

    local p = HCRT_DB.pos
    if not p then
        p = HCRT.defaultPoint
    end

    local relFrame = _G[p.rel] or PlayerFrame
    HCRT.bar:SetPoint(p.point, relFrame, p.relPoint, p.x, p.y)
end

local function ApplyLockState()
  if HCRT_DB.locked then
    HCRT.bar:EnableMouse(false)
    HCRT.bar:RegisterForDrag()
  else
    HCRT.bar:EnableMouse(true)
    HCRT.bar:RegisterForDrag("LeftButton")
  end
end

ApplyPosition()
HCRT.bar:SetMovable(true)
ApplyLockState()

HCRT.bar:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

HCRT.bar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    local point, relTo, relPoint, xOfs, yOfs = self:GetPoint(1)
    HCRT_DB.pos = {
        point = point,
        rel = (relTo and relTo.GetName and relTo:GetName()) or "UIParent",
        relPoint = relPoint,
        x = xOfs,
        y = yOfs,
    }

    Print(string.format(L.POS_SAVED, HCRT_DB.pos.point, HCRT_DB.pos.rel, HCRT_DB.pos.relPoint, HCRT_DB.pos.x, HCRT_DB.pos.y))
end)

HCRT.bar:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:ClearLines()

    GameTooltip:AddLine(L.TOOLTIP_TITLE, 1, 0.82, 0)
    GameTooltip:AddLine(
        string.format("%s: %d", L.TOOLTIP_THREATS, HCRT.lastScan.threats or 0),
        1, 1, 1
    )
    GameTooltip:AddLine(
        string.format("%s: %d", L.TOOLTIP_ELITES, HCRT.lastScan.elites or 0),
        1, 1, 1
    )
    GameTooltip:AddLine(
        string.format("%s: %s", L.TOOLTIP_INDOOR, (HCRT.lastScan.indoors and L.YES or L.NO)),
        1, 1, 1
    )
    GameTooltip:AddLine(
        string.format("%s: %s", L.TOOLTIP_COMBAT, (HCRT.lastScan.inCombat and L.YES or L.NO)),
        1, 1, 1
    )

    GameTooltip:Show()
end)

HCRT.bar:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local function ScanPlayerBuffs()
    local present = {}
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        if spellId then
            present[spellId] = true
        end
    end
    return present
end

local function HasAnyBuff(present, spellIds)
    for _, id in ipairs(spellIds) do
        if present[id] then return true end
    end
    return false
end

local function PlayerRequiresPet()
    return HCRT.REQUIRES_PET[HCRT.playerClass] == true
end

local function IsPetOK()
    return UnitExists("pet") and not UnitIsDead("pet")
end

local function PlayerRequiresPoisons()
    return HCRT.REQUIRES_POISONS[HCRT.playerClass] == true
end

local function HasPoisonOnSlot(slotId)
    local hasMainHandEnchant, _, _, hasOffHandEnchant = GetWeaponEnchantInfo()
    if slotId == 17 then
        return hasOffHandEnchant == true
    end
    return hasMainHandEnchant == true
end

local function HasTwoPoisons()
    local offhandLink = GetInventoryItemLink("player", 17)
    local mhOk = HasPoisonOnSlot(16)

    if not offhandLink then
        return mhOk
    end

    local ohOk = HasPoisonOnSlot(17)
    return mhOk and ohOk
end

local function RogueHasPoisonsSkill()
    if HCRT.playerClass ~= "ROGUE" then
        return false
    end

    local targetName = "Poisons"
    for i = 1, 200 do
        local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
        if not name then
            break
        end
        if name == targetName then
            return true
        end
    end

    return false
end

local function GetMissingEssentialBuffs()
    if #HCRT.requiredKeys == 0 then
        return {}
    end

    local present = ScanPlayerBuffs()
    local missing = {}

    for _, key in ipairs(HCRT.requiredKeys) do
        if key == "DEMON_SKIN_OR_ARMOR" then
            local ids = { 687, 706 } 
            if (IsSpellKnown(687) or IsSpellKnown(706)) and not HasAnyBuff(present, ids) then
                table.insert(missing, 687)
            end
        else
            local spellId = HCRT.requiredByKey[key]
            if spellId and IsSpellKnown(spellId) and not present[spellId] then
                table.insert(missing, spellId)
            end
        end
    end

    return missing
end

local function GetNamePlateUnit(frame)
    if not frame then return nil end

    if frame.namePlateUnitToken then
        return frame.namePlateUnitToken
    end

    if frame.UnitFrame and frame.UnitFrame.unit then
        return frame.UnitFrame.unit
    end

    if frame.unit then
        return frame.unit
    end

    return nil
end

local function IsStrictHostile(unit)
    local r = UnitReaction(unit, "player")
    return r and r <= 2
end

local function AddUnitEnemyRisk(unit, playerLevel, inCombat)
    if not UnitExists(unit) then return 0, 0, 0 end
    if not UnitCanAttack("player", unit) then return 0, 0, 0 end
    if UnitIsDead(unit) then return 0, 0, 0 end

    local lvl = UnitLevel(unit) or playerLevel
    local diff = lvl - playerLevel

    local classif = UnitClassification(unit)
    local isElite = (classif == "elite" or classif == "rareelite")

    if not inCombat and not isElite then
        if not IsStrictHostile(unit) and diff < 3 then
            return 0, 0, 0
        end
    end

    local r = 8

    if diff >= 3 then
        r = r + 25
    elseif diff >= 1 then
        if inCombat then
            r = r + 12
        end
    end

    if isElite then
        r = r + 25
    end

    local eliteCount = isElite and 1 or 0
    return r, 1, eliteCount
end

local function ComputeEnemyRisk()
    local risk = 0
    local count = 0
    local elites = 0
    local seen = {}

    local playerLevel = UnitLevel("player") or 1
    local inCombat = UnitAffectingCombat("player")

    local add, c, e

    local function AddUnique(unit)
        if not UnitExists(unit) then return 0, 0, 0 end
        local guid = UnitGUID(unit)
        if guid and seen[guid] then
            return 0, 0, 0
        end
        if guid then
            seen[guid] = true
        end
        return AddUnitEnemyRisk(unit, playerLevel, inCombat)
    end

    add, c, e = AddUnique("target")
    risk = risk + add
    count = count + c
    elites = elites + e

    add, c, e = AddUnique("mouseover")
    risk = risk + add
    count = count + c
    elites = elites + e

    add, c, e = AddUnique("focus")
    risk = risk + add
    count = count + c
    elites = elites + e

    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        for _, plate in ipairs(plates) do
            if plate and plate:IsShown() then
                local unit = GetNamePlateUnit(plate)
                if unit then
                    add, c, e = AddUnique(unit)
                    risk = risk + add
                    count = count + c
                    elites = elites + e
                else
                    risk = risk + (inCombat and 6 or 3)
                    count = count + 1
                end
            end
        end
    else
        for i = 1, 40 do
            local plate = _G["NamePlate" .. i]
            if plate and plate:IsShown() then
                local unit = GetNamePlateUnit(plate)
                if unit then
                    add, c, e = AddUnique(unit)
                    risk = risk + add
                    count = count + c
                    elites = elites + e
                else
                    risk = risk + (inCombat and 6 or 3)
                    count = count + 1
                end
            end
        end
    end

    if IsIndoors() and (risk > 0 or count > 0) then
        risk = risk + 8
    end

    HCRT.lastScan.threats = count
    HCRT.lastScan.elites = elites
    HCRT.lastScan.indoors = IsIndoors() and true or false
    HCRT.lastScan.inCombat = inCombat and true or false

    return risk, count, elites
end

local function FirstMissingLabel(missing)
    if not missing or #missing == 0 then
        return nil
    end

    local first = missing[1]

    if first == "POISONS_MISSING" then
        return L.POISONS_LABEL
    end

    if first == "PET_MISSING" then
        return L.PET_LABEL
    end

    return GetSpellInfo(first) or "Buff"
end

local function ComputeRisk()
    local hp = UnitHealth("player")
    local hpMax = UnitHealthMax("player")
    local hpPct = (hpMax > 0) and (hp / hpMax * 100) or 100

    local power = UnitPower("player")
    local powerMax = UnitPowerMax("player")
    local powerPct = (powerMax > 0) and (power / powerMax * 100) or 100

    local inCombat = UnitAffectingCombat("player")

    local risk = 0

    if hpPct < 20 then
        risk = risk + 70
    elseif hpPct < 40 then
        risk = risk + 45
    elseif hpPct < 60 then
        risk = risk + 25
    elseif hpPct < 80 then
        risk = risk + 10
    end

    if powerPct < 30 then
        risk = risk + 25
    elseif powerPct < 60 then
        risk = risk + 10
    end

    if inCombat and hpPct < 30 then
        risk = risk + 15
    end

    local missing = GetMissingEssentialBuffs()

    if PlayerRequiresPet() and not IsPetOK() then
        table.insert(missing, "PET_MISSING")
        risk = risk + 15
    end

    if PlayerRequiresPoisons() and RogueHasPoisonsSkill() and not HasTwoPoisons() then
        table.insert(missing, "POISONS_MISSING")
        risk = risk + 12
    end

    risk = risk + (#missing * 10)

    local envRisk, threatCount = ComputeEnemyRisk()
    risk = risk + envRisk

    return Clamp(risk, 0, 100), missing, threatCount
end

local function UpdateUI(risk, missing, threatCount)
    if not HCRT.text or not HCRT.detail then
        return
    end

    HCRT.bar:SetValue(risk)

    threatCount = threatCount or 0
    if threatCount > 0 then
        HCRT.text:SetText(string.format("%s %d  [%s:%d]", L.RISK_LABEL, risk, L.THREAT_LABEL, threatCount))
    else
        HCRT.text:SetText(string.format("%s %d", L.RISK_LABEL, risk))
    end

    if risk >= 61 then
        HCRT.bar:SetStatusBarColor(1, 0.2, 0.2, 1)
    elseif risk >= 31 then
        HCRT.bar:SetStatusBarColor(1, 0.85, 0.2, 1)
    else
        HCRT.bar:SetStatusBarColor(0.2, 1, 0.2, 1)
    end

    local label = FirstMissingLabel(missing)
    if label then
        HCRT.detail:SetText("|cffff4444" .. L.MISSING_LABEL .. "|r " .. label)
        HCRT.detail:SetTextColor(1, 0.27, 0.27, 1)
    else
        HCRT.detail:SetText("")
    end
end

HCRT.lastBand = nil
HCRT.lastMissingKey = nil

local function UpdateAlerts(risk, missing)
    local band = GetBandStable(risk, HCRT.lastBand)

    if risk < 60 then
        HCRT.lastBand = band
        HCRT.lastMissingKey = nil
        return
    end

    if HCRT.lastBand ~= band then
        if band == "GREEN" then
            Print("|cff00ff00" .. L.LOW_RISK .. "|r (" .. risk .. ")")
        elseif band == "YELLOW" then
            Print("|cffffff00" .. L.HIGH_RISK .. "|r (" .. risk .. ")")
        else
            Print("|cffff3333" .. L.CRIT_RISK .. "|r (" .. risk .. ")")
        end
        HCRT.lastBand = band
    end

    local missingKey = nil
    if missing and #missing > 0 then
        missingKey = tostring(missing[1])
    end

    if missingKey ~= HCRT.lastMissingKey then
        if missingKey then
            local label = FirstMissingLabel(missing) or "Buff"
            Print("|cffff3333" .. L.MISSING_CHAT .. "|r " .. label)
        end
        HCRT.lastMissingKey = missingKey
    end
end

HCRT.frame:SetScript("OnUpdate", function(_, elapsed)
    HCRT.elapsed = HCRT.elapsed + elapsed
    if HCRT.elapsed < HCRT.UPDATE_INTERVAL then return end
    HCRT.elapsed = 0

    local risk, missing, threatCount = ComputeRisk()
    UpdateUI(risk, missing, threatCount)
    UpdateAlerts(risk, missing)
end)

local initPrinted = false
HCRT.frame:RegisterEvent("PLAYER_LOGIN")
HCRT.frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" and not initPrinted then
        initPrinted = true
        Print(L.LOADED .. (HCRT.playerClass or "?"))
    end
end)

SLASH_HCRT1 = "/hcrt"
SlashCmdList["HCRT"] = function(msg)
    msg = (msg or ""):lower()

    if msg == "reset" then
        HCRT_DB.pos = nil
        ApplyPosition()
        Print(L.POS_RESET)
        return
    end

    if msg == "lock" then
        HCRT_DB.locked = true
        ApplyLockState()
        Print(L.LOCKED)
        return
    end

    if msg == "unlock" then
        HCRT_DB.locked = false
        ApplyLockState()
        Print(L.UNLOCKED)
        return
    end

    Print(L.CMDS)
end