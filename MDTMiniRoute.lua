local ADDON_NAME = ...

local TITLE = "MDTMiniRoute"
local MAP_WIDTH = 840
local MAP_HEIGHT = 555
local HEADER_HEIGHT = 22
local PADDING = 4
local SIDEBAR_SPACING = 4
local SIDEBAR_HEADER_HEIGHT = 24
local SIDEBAR_DEFAULT_WIDTH = 96
local SIDEBAR_MIN_WIDTH = 42
local SIDEBAR_MAX_WIDTH = 260
local SIDEBAR_DEFAULT_HEIGHT = 240
local SIDEBAR_MIN_HEIGHT = 80
local SIDEBAR_MAX_HEIGHT = 640
local SIDEBAR_MIN_SCALE = 0.5
local SIDEBAR_MAX_SCALE = 1.8
local MIN_WIDTH = 220
local MAX_WIDTH = 720
local FONT_DEFAULT_NAME = "Default"
local FONT_SIZE_MIN = 6
local FONT_SIZE_MAX = 32
local REFRESH_INTERVAL = 0.35

local CIRCLE_TEXTURE = "Interface\\AddOns\\MythicDungeonTools\\Textures\\Circle_White"
local SQUARE_TEXTURE = "Interface\\AddOns\\MythicDungeonTools\\Textures\\Square_White"
local POI_FALLBACK_TEXTURE = "Interface\\MINIMAP\\POIIcons"

local FALLBACK_FONT_CHOICES = {
  { text = FONT_DEFAULT_NAME, value = FONT_DEFAULT_NAME },
  { text = "Blizzard Friz Quadrata", value = "Fonts\\FRIZQT__.TTF" },
  { text = "Blizzard Arial Narrow", value = "Fonts\\ARIALN.TTF" },
  { text = "Blizzard Morpheus", value = "Fonts\\MORPHEUS.TTF" },
  { text = "Blizzard Skurri", value = "Fonts\\SKURRI.TTF" },
  { text = "ElvUI Expressway", value = "Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Fonts\\Expressway.ttf" },
  { text = "ElvUI PTSans Narrow", value = "Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Fonts\\PTSansNarrow.ttf" },
  { text = "ElvUI Continuum", value = "Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Fonts\\ContinuumMedium.ttf" },
  { text = "ElvUI Action Man", value = "Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Fonts\\ActionMan.ttf" },
  { text = "ElvUI Die Die Die", value = "Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Fonts\\DieDieDie.ttf" },
  { text = "ElvUI Homespun", value = "Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Fonts\\Homespun.ttf" },
}

local DEFAULTS = {
  shown = true,
  locked = false,
  showAllPulls = true,
  showEnemies = false,
  showUnpulledEnemies = false,
  showEnemyDots = false,
  showEnemyPortraits = false,
  showPOIs = false,
  showPullOutlines = true,
  showPullNumbers = true,
  showRouteLines = false,
  showFrameArtwork = true,
  showOnMouseoverOnly = false,
  onlyShowOutOfCombat = false,
  autoSelectPull = false,
  autoPullUseProximity = false,
  autoPullProximityRadius = 85,
  autoPullDriftWatcher = true,
  autoPullDriftThreshold = 6,
  autoPullAnchorActive = false,
  autoPullAnchorPull = 0,
  autoPullTrashOffset = 0,
  autoPullBossOffset = 0,
  recoveryMode = false,
  showRecoveryButton = true,
  recoveryButtonMouseoverOnly = false,
  recoveryButtonBorderStyle = "ARTWORK",
  recoveryButtonBorderSize = 3,
  recoveryButtonBorderColor = { 0.15, 0.85, 1 },
  onlyShowInMatchingDungeon = false,
  showPullSidebar = true,
  showPullPercent = true,
  pullSidebarOnLeft = false,
  pullSidebarDetached = false,
  pullSidebarLocked = false,
  pullSidebarWidth = SIDEBAR_DEFAULT_WIDTH,
  pullSidebarHeight = 0,
  pullSidebarScale = 1,
  pullSidebarPoint = "BOTTOMLEFT",
  pullSidebarRelativePoint = "BOTTOMLEFT",
  pullSidebarX = 392,
  pullSidebarY = 245,
  sidebarFont = FONT_DEFAULT_NAME,
  sidebarFontSize = 13,
  sidebarFontOutline = "OUTLINE",
  sidebarFontShadow = false,
  mapFont = FONT_DEFAULT_NAME,
  mapFontSize = 10,
  mapFontOutline = "OUTLINE",
  mapFontShadow = false,
  alpha = 0.95,
  iconAlpha = 1,
  dungeonLayouts = {},
  width = 348,
  point = "BOTTOMLEFT",
  relativePoint = "BOTTOMLEFT",
  x = 32,
  y = 245,
  settingsPoint = "CENTER",
  settingsRelativePoint = "CENTER",
  settingsX = 430,
  settingsY = 0,
}

local FALLBACK_COLORS = {
  { 1.000, 0.245, 1.000 },
  { 0.245, 1.000, 0.622 },
  { 1.000, 0.245, 0.245 },
  { 0.245, 0.622, 1.000 },
  { 1.000, 0.987, 0.245 },
  { 0.245, 1.000, 0.245 },
  { 1.000, 0.245, 0.622 },
  { 0.245, 1.000, 1.000 },
  { 1.000, 0.610, 0.245 },
  { 0.245, 0.245, 1.000 },
}

local db
local frame
local header
local headerTexture
local titleText
local closeButton
local mapViewport
local mapBg
local canvas
local pullSidebar
local pullSidebarShowAllButton
local pullSidebarScroll
local pullSidebarContent
local statusText
local settingsFrame
local settingsControls = {}
local contextMenuFrame
local pickerMenuFrame
local monitorFrame
local smallTiles = {}
local largeTiles = {}
local hooksInstalled
local initialized
local dirty = true
local lastSignature
local elapsedSinceRefresh = 0
local monitorElapsed = 0
local settingsUpdating
local settingsOpenedWithMDT
local lastMDTShown
local activeLayoutDungeonIdx
local applyingDungeonLayout

local linePool, markerPool, dotPool, enemyPool, poiPool = {}, {}, {}, {}, {}
local usedLines, usedMarkers, usedDots, usedEnemies, usedPOIs = 0, 0, 0, 0, 0
local pullSidebarRows = {}
local ResetPosition, ToggleShown, SetLocked, ShowSettingsWindow, ShowContextMenu
local SaveActiveDungeonLayout, UpdateOverlayVisibility
local ApplySize, RefreshIfNeeded, RefreshSettingsWindow
local SelectPull, UpdatePullSidebar, LayoutPullSidebar, UpdatePullSidebarHeader
local UpdateAutoPullFromProgress
local UpdateFontSettingControls

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffMDTMiniRoute:|r "..msg)
end

local function CopyDefaults(defaults, target)
  if type(target) ~= "table" then
    target = {}
  end

  for key, value in pairs(defaults) do
    if target[key] == nil then
      if type(value) == "table" then
        target[key] = CopyDefaults(value, {})
      else
        target[key] = value
      end
    end
  end

  return target
end

local function Clamp(value, minValue, maxValue)
  value = tonumber(value) or minValue
  if value < minValue then return minValue end
  if value > maxValue then return maxValue end
  return value
end

local function UseFrameArtwork()
  return not db or db.showFrameArtwork ~= false
end

local function RouteAlpha(alpha)
  return (alpha or 1) * Clamp(db and db.iconAlpha or DEFAULTS.iconAlpha, 0.2, 1)
end

local function IsPlayerInCombat()
  return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

local function FrameIsMouseOver(target)
  if not target or not target:IsShown() then return false end
  if target.IsMouseOver then
    return target:IsMouseOver()
  end
  if MouseIsOver then
    return MouseIsOver(target)
  end
  return false
end

local function OverlayIsMouseOver()
  return FrameIsMouseOver(frame) or FrameIsMouseOver(pullSidebar)
end

local function ApplyOverlayVisualAlpha()
  if not frame or not db then return end

  local visible = db.showOnMouseoverOnly ~= true or OverlayIsMouseOver()
  local alpha = visible and 1 or 0
  frame:SetAlpha(alpha)

  if pullSidebar then
    pullSidebar:SetAlpha((db.pullSidebarDetached and db.showOnMouseoverOnly == true) and alpha or 1)
  end
  if MDTMiniRouteApplyRecoveryButtonAppearance then
    MDTMiniRouteApplyRecoveryButtonAppearance()
  end
end

local function QueueOverlayVisualAlpha()
  if C_Timer and C_Timer.After then
    C_Timer.After(0.05, ApplyOverlayVisualAlpha)
  else
    ApplyOverlayVisualAlpha()
  end
end

local function WatchOverlayMouseover(target)
  if not target or not target.HookScript then return end
  target:HookScript("OnEnter", ApplyOverlayVisualAlpha)
  target:HookScript("OnLeave", QueueOverlayVisualAlpha)
end

local function GetLibSharedMedia()
  if type(LibStub) == "function" then
    return LibStub("LibSharedMedia-3.0", true)
  end
end

local function ResolveFontPath(fontName)
  if fontName and fontName ~= FONT_DEFAULT_NAME then
    local LSM = GetLibSharedMedia()
    if LSM and type(LSM.Fetch) == "function" then
      local ok, path = pcall(LSM.Fetch, LSM, "font", fontName, true)
      if ok and path then return path end
    end
    if type(fontName) == "string" and fontName:find("\\", 1, true) then
      return fontName
    end
  end

  return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function AddFontChoice(choices, seen, text, value)
  value = tostring(value or FONT_DEFAULT_NAME)
  if value == "" then value = FONT_DEFAULT_NAME end
  text = tostring(text or value)
  if not seen[value] then
    choices[#choices + 1] = { text = text, value = value }
    seen[value] = true
  end
end

local function GetFontChoices()
  local choices = {}
  local seen = {}
  local LSM = GetLibSharedMedia()

  for _, choice in ipairs(FALLBACK_FONT_CHOICES) do
    AddFontChoice(choices, seen, choice.text, choice.value)
  end

  if LSM and type(LSM.List) == "function" then
    local ok, fonts = pcall(LSM.List, LSM, "font")
    if ok and type(fonts) == "table" then
      for _, name in ipairs(fonts) do
        if type(name) == "string" then
          AddFontChoice(choices, seen, name, name)
        end
      end
    end
  end

  table.sort(choices, function(a, b)
    if a.value == FONT_DEFAULT_NAME then return true end
    if b.value == FONT_DEFAULT_NAME then return false end
    return a.text < b.text
  end)

  return choices
end

local function NormalizeFontName(fontName)
  if type(fontName) ~= "string" or fontName == "" then
    return FONT_DEFAULT_NAME
  end
  return fontName
end

local function FontLabel(fontName)
  fontName = NormalizeFontName(fontName)
  for _, choice in ipairs(GetFontChoices()) do
    if choice.value == fontName then return choice.text end
  end

  local label = fontName:match("[^\\]+$") or fontName
  label = label:gsub("%.ttf$", ""):gsub("%.TTF$", "")
  return label
end

local function NormalizeOutline(outline)
  if outline == "NONE" or outline == "OUTLINE" or outline == "THICKOUTLINE" then
    return outline
  end
  return "OUTLINE"
end

local function OutlineLabel(outline)
  outline = NormalizeOutline(outline)
  if outline == "NONE" then return "None" end
  if outline == "THICKOUTLINE" then return "Thick" end
  return "Thin"
end

local function OutlineFlag(outline)
  outline = NormalizeOutline(outline)
  if outline == "NONE" then return "" end
  return outline
end

local function ApplyTextStyle(fontString, prefix, fallbackSize, scale, sizeOffset)
  if not fontString or not db then return end

  scale = scale or 1
  local fontName = NormalizeFontName(db[prefix.."Font"] or DEFAULTS[prefix.."Font"])
  local size = Clamp((db[prefix.."FontSize"] or fallbackSize) + (sizeOffset or 0), FONT_SIZE_MIN, FONT_SIZE_MAX) * scale
  local outline = NormalizeOutline(db[prefix.."FontOutline"] or DEFAULTS[prefix.."FontOutline"])

  local fontSize = math.max(FONT_SIZE_MIN, math.floor(size + 0.5))
  local fontFlags = OutlineFlag(outline)
  if not fontString:SetFont(ResolveFontPath(fontName), fontSize, fontFlags) then
    fontString:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", fontSize, fontFlags)
  end
  if db[prefix.."FontShadow"] then
    fontString:SetShadowColor(0, 0, 0, 0.85)
    fontString:SetShadowOffset(1, -1)
  else
    fontString:SetShadowColor(0, 0, 0, 0)
    fontString:SetShadowOffset(0, 0)
  end
end

local function GetViewportWidth()
  local width = db and db.width or DEFAULTS.width
  if UseFrameArtwork() then
    return width - (PADDING * 2)
  end
  return width
end

local function GetViewportHeight()
  return GetViewportWidth() * (MAP_HEIGHT / MAP_WIDTH)
end

local function GetPullSidebarWidth()
  if not db or db.showPullSidebar == false then return 0 end
  return Clamp(db.pullSidebarWidth or SIDEBAR_DEFAULT_WIDTH, SIDEBAR_MIN_WIDTH, SIDEBAR_MAX_WIDTH) * Clamp(db.pullSidebarScale or 1, SIDEBAR_MIN_SCALE, SIDEBAR_MAX_SCALE)
end

local function GetPullSidebarHeight()
  if not db or db.showPullSidebar == false then return 0 end

  local height = tonumber(db.pullSidebarHeight) or 0
  if height <= 0 then
    height = GetViewportHeight()
  end
  return Clamp(height, SIDEBAR_MIN_HEIGHT, SIDEBAR_MAX_HEIGHT) * Clamp(db.pullSidebarScale or 1, SIDEBAR_MIN_SCALE, SIDEBAR_MAX_SCALE)
end

local function GetPullSidebarTotalWidth()
  local width = GetPullSidebarWidth()
  if db and db.pullSidebarDetached then return 0 end
  if width <= 0 then return 0 end
  return SIDEBAR_SPACING + width
end

local function ApplyMapAlpha()
  if not db then return end

  db.alpha = Clamp(db.alpha, 0.2, 1)
  for i = 1, #smallTiles do
    smallTiles[i]:SetAlpha(db.alpha)
  end
  for row = 1, #largeTiles do
    for col = 1, #(largeTiles[row] or {}) do
      largeTiles[row][col]:SetAlpha(db.alpha)
    end
  end
  if mapBg then
    mapBg:SetAlpha(UseFrameArtwork() and db.alpha or 0)
  end
end

local function ApplyFrameArtwork()
  if not frame or not db then return end

  local showArtwork = UseFrameArtwork()
  if showArtwork then
    frame:SetBackdropColor(0.02, 0.025, 0.03, 0.82)
    frame:SetBackdropBorderColor(0, 0, 0, 0.85)
    if header then header:Show() end
    if headerTexture then headerTexture:Show() end
    if titleText then titleText:Show() end
    if closeButton then closeButton:Show() end
    if mapBg then
      mapBg:SetColorTexture(0, 0, 0, 0.65)
    end
  else
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)
    if header then header:Hide() end
    if headerTexture then headerTexture:Hide() end
    if titleText then titleText:Hide() end
    if closeButton then closeButton:Hide() end
    if mapBg then
      mapBg:SetColorTexture(0, 0, 0, 0)
    end
  end

  if mapViewport then
    local sidebarTotalWidth = GetPullSidebarTotalWidth()
    local leftSidebarWidth = db.pullSidebarOnLeft and sidebarTotalWidth or 0
    local rightSidebarWidth = db.pullSidebarOnLeft and 0 or sidebarTotalWidth
    mapViewport:ClearAllPoints()
    if showArtwork then
      mapViewport:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + leftSidebarWidth, -HEADER_HEIGHT)
      mapViewport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PADDING + rightSidebarWidth), PADDING)
    else
      mapViewport:SetPoint("TOPLEFT", frame, "TOPLEFT", leftSidebarWidth, 0)
      mapViewport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -rightSidebarWidth, 0)
    end
  end

  if pullSidebar then
    local sidebarWidth = GetPullSidebarWidth()
    local sidebarHeight = GetPullSidebarHeight()
    pullSidebar:ClearAllPoints()
    if sidebarWidth > 0 then
      pullSidebar:SetSize(sidebarWidth, sidebarHeight)
      LayoutPullSidebar()
      if db.pullSidebarDetached then
        pullSidebar:SetParent(UIParent)
        pullSidebar:SetPoint(db.pullSidebarPoint or DEFAULTS.pullSidebarPoint, UIParent, db.pullSidebarRelativePoint or DEFAULTS.pullSidebarRelativePoint, db.pullSidebarX or DEFAULTS.pullSidebarX, db.pullSidebarY or DEFAULTS.pullSidebarY)
      else
        pullSidebar:SetParent(frame)
        if db.pullSidebarOnLeft then
          pullSidebar:SetPoint("TOPRIGHT", mapViewport, "TOPLEFT", -SIDEBAR_SPACING, 0)
        else
          pullSidebar:SetPoint("TOPLEFT", mapViewport, "TOPRIGHT", SIDEBAR_SPACING, 0)
        end
      end
      pullSidebar:Show()
    else
      pullSidebar:Hide()
    end
  end

  ApplyMapAlpha()
  ApplyOverlayVisualAlpha()
end

local function RequestRefresh()
  dirty = true
end

local function SavePosition()
  if not frame or not db then return end
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  db.point = point or DEFAULTS.point
  db.relativePoint = relativePoint or DEFAULTS.relativePoint
  db.x = x or DEFAULTS.x
  db.y = y or DEFAULTS.y
  if SaveActiveDungeonLayout then
    SaveActiveDungeonLayout()
  end
end

local function SaveSidebarPosition()
  if not pullSidebar or not db or not db.pullSidebarDetached then return end
  local point, _, relativePoint, x, y = pullSidebar:GetPoint(1)
  db.pullSidebarPoint = point or DEFAULTS.pullSidebarPoint
  db.pullSidebarRelativePoint = relativePoint or DEFAULTS.pullSidebarRelativePoint
  db.pullSidebarX = x or DEFAULTS.pullSidebarX
  db.pullSidebarY = y or DEFAULTS.pullSidebarY
  if SaveActiveDungeonLayout then
    SaveActiveDungeonLayout()
  end
end

local function GetMDT()
  return _G.MDT
end

local function GetMDTDB()
  local MDT = GetMDT()
  if not MDT or type(MDT.GetDB) ~= "function" then return end
  local ok, mdtDB = pcall(MDT.GetDB, MDT)
  if ok then return mdtDB end
end

local function GetCurrentPreset()
  local MDT = GetMDT()
  if not MDT or type(MDT.GetCurrentPreset) ~= "function" then return end
  local ok, preset = pcall(MDT.GetCurrentPreset, MDT)
  if ok then return preset end
end

local function GetRouteDungeonIdx()
  local mdtDB = GetMDTDB()
  local preset = GetCurrentPreset()
  local dungeonIdx = preset and preset.value and preset.value.currentDungeonIdx
  return tonumber(dungeonIdx or (mdtDB and mdtDB.currentDungeonIdx))
end

local function GetPlayerDungeonIdx()
  local MDT = GetMDT()
  if not MDT or type(MDT.zoneIdToDungeonIdx) ~= "table" then return end
  if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function" then return end

  local zoneId = C_Map.GetBestMapForUnit("player")
  return zoneId and MDT.zoneIdToDungeonIdx[zoneId], zoneId
end

local function IsInMatchingDungeon()
  local routeDungeonIdx = GetRouteDungeonIdx()
  local playerDungeonIdx = GetPlayerDungeonIdx()
  return routeDungeonIdx and playerDungeonIdx and routeDungeonIdx == playerDungeonIdx, routeDungeonIdx, playerDungeonIdx
end

local function EnsureDungeonLayouts()
  if type(db.dungeonLayouts) ~= "table" then
    db.dungeonLayouts = {}
  end
  return db.dungeonLayouts
end

local function LayoutKey(dungeonIdx)
  return tostring(dungeonIdx)
end

local function CopyCurrentLayout()
  return {
    point = db.point or DEFAULTS.point,
    relativePoint = db.relativePoint or DEFAULTS.relativePoint,
    x = db.x or DEFAULTS.x,
    y = db.y or DEFAULTS.y,
    width = db.width or DEFAULTS.width,
    alpha = db.alpha or DEFAULTS.alpha,
    iconAlpha = db.iconAlpha or DEFAULTS.iconAlpha,
    showFrameArtwork = db.showFrameArtwork ~= false,
    pullSidebarOnLeft = db.pullSidebarOnLeft == true,
    pullSidebarDetached = db.pullSidebarDetached == true,
    pullSidebarLocked = db.pullSidebarLocked == true,
    pullSidebarWidth = db.pullSidebarWidth or DEFAULTS.pullSidebarWidth,
    pullSidebarHeight = db.pullSidebarHeight or DEFAULTS.pullSidebarHeight,
    pullSidebarScale = db.pullSidebarScale or DEFAULTS.pullSidebarScale,
    pullSidebarPoint = db.pullSidebarPoint or DEFAULTS.pullSidebarPoint,
    pullSidebarRelativePoint = db.pullSidebarRelativePoint or DEFAULTS.pullSidebarRelativePoint,
    pullSidebarX = db.pullSidebarX or DEFAULTS.pullSidebarX,
    pullSidebarY = db.pullSidebarY or DEFAULTS.pullSidebarY,
  }
end

local function SaveDungeonLayout(dungeonIdx)
  if not db or applyingDungeonLayout or not dungeonIdx then return end

  local layouts = EnsureDungeonLayouts()
  layouts[LayoutKey(dungeonIdx)] = CopyCurrentLayout()
end

SaveActiveDungeonLayout = function()
  if not db or not db.onlyShowInMatchingDungeon then return end
  SaveDungeonLayout(activeLayoutDungeonIdx)
end

local function ApplyDungeonLayout(dungeonIdx)
  if not db or not dungeonIdx then return end

  local layouts = EnsureDungeonLayouts()
  local key = LayoutKey(dungeonIdx)
  local layout = layouts[key]
  if type(layout) ~= "table" then
    layout = CopyCurrentLayout()
    layouts[key] = layout
  end

  applyingDungeonLayout = true
  db.point = layout.point or DEFAULTS.point
  db.relativePoint = layout.relativePoint or DEFAULTS.relativePoint
  db.x = layout.x or DEFAULTS.x
  db.y = layout.y or DEFAULTS.y
  db.width = Clamp(layout.width or DEFAULTS.width, MIN_WIDTH, MAX_WIDTH)
  db.alpha = Clamp(layout.alpha or DEFAULTS.alpha, 0.2, 1)
  db.iconAlpha = Clamp(layout.iconAlpha or DEFAULTS.iconAlpha, 0.2, 1)
  db.showFrameArtwork = layout.showFrameArtwork ~= false
  db.pullSidebarOnLeft = layout.pullSidebarOnLeft == true
  db.pullSidebarDetached = layout.pullSidebarDetached == true
  db.pullSidebarLocked = layout.pullSidebarLocked == true
  db.pullSidebarWidth = Clamp(layout.pullSidebarWidth or DEFAULTS.pullSidebarWidth, SIDEBAR_MIN_WIDTH, SIDEBAR_MAX_WIDTH)
  db.pullSidebarHeight = Clamp(layout.pullSidebarHeight or DEFAULTS.pullSidebarHeight, 0, SIDEBAR_MAX_HEIGHT)
  db.pullSidebarScale = Clamp(layout.pullSidebarScale or DEFAULTS.pullSidebarScale, SIDEBAR_MIN_SCALE, SIDEBAR_MAX_SCALE)
  db.pullSidebarPoint = layout.pullSidebarPoint or DEFAULTS.pullSidebarPoint
  db.pullSidebarRelativePoint = layout.pullSidebarRelativePoint or DEFAULTS.pullSidebarRelativePoint
  db.pullSidebarX = layout.pullSidebarX or DEFAULTS.pullSidebarX
  db.pullSidebarY = layout.pullSidebarY or DEFAULTS.pullSidebarY

  if frame then
    frame:ClearAllPoints()
    frame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
    ApplySize(db.width)
  end

  applyingDungeonLayout = false
  RefreshSettingsWindow()
end

local function SwitchDungeonLayout(dungeonIdx)
  if not db or not db.onlyShowInMatchingDungeon or not dungeonIdx then return end
  if activeLayoutDungeonIdx == dungeonIdx then return end

  SaveDungeonLayout(activeLayoutDungeonIdx)
  activeLayoutDungeonIdx = dungeonIdx
  ApplyDungeonLayout(dungeonIdx)
end

UpdateOverlayVisibility = function(force)
  if not frame or not db then return end

  local canShow = db.shown == true
  if db.onlyShowInMatchingDungeon then
    local matches, routeDungeonIdx = IsInMatchingDungeon()
    canShow = canShow and matches == true
    if db.shown == true and matches == true then
      SwitchDungeonLayout(routeDungeonIdx)
    elseif matches ~= true and activeLayoutDungeonIdx then
      SaveDungeonLayout(activeLayoutDungeonIdx)
      activeLayoutDungeonIdx = nil
    end
  elseif activeLayoutDungeonIdx then
    SaveDungeonLayout(activeLayoutDungeonIdx)
    activeLayoutDungeonIdx = nil
  end

  if canShow and db.onlyShowOutOfCombat == true and IsPlayerInCombat() then
    canShow = false
  end

  if canShow then
    frame:Show()
    RefreshIfNeeded(force == true)
    ApplyOverlayVisualAlpha()
  else
    frame:Hide()
    if pullSidebar then
      pullSidebar:Hide()
    end
  end
end

local function GetCurrentPull(preset)
  return preset and preset.value and preset.value.currentPull
end

local function GetSelection(preset)
  if preset and preset.value then
    if type(preset.value.selection) == "table" and #preset.value.selection > 0 then
      return preset.value.selection
    end
    if preset.value.currentPull then
      return { preset.value.currentPull }
    end
  end

  return {}
end

local function HexToRGB(hex)
  if type(hex) ~= "string" or #hex ~= 6 then return end
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  if not r or not g or not b then return end
  return r / 255, g / 255, b / 255
end

local function GetPullColor(pulls, pullIdx)
  local MDT = GetMDT()
  if MDT and type(MDT.DungeonEnemies_GetPullColor) == "function" then
    local ok, r, g, b = pcall(MDT.DungeonEnemies_GetPullColor, MDT, pullIdx, pulls)
    if ok and r and g and b then
      return r, g, b
    end
  end

  local pull = pulls and pulls[pullIdx]
  if pull and pull.color then
    local r, g, b = HexToRGB(pull.color)
    if r then return r, g, b end
  end

  local color = FALLBACK_COLORS[((pullIdx or 1) - 1) % #FALLBACK_COLORS + 1]
  return color[1], color[2], color[3]
end

local function HidePool(pool, usedCount)
  for i = usedCount + 1, #pool do
    pool[i]:Hide()
  end
end

local function ResetDrawnRoute()
  usedLines = 0
  usedMarkers = 0
  usedDots = 0
  usedEnemies = 0
  usedPOIs = 0
  if MDTMiniRouteResetHitFrames then
    MDTMiniRouteResetHitFrames()
  end

  for i = 1, #linePool do
    linePool[i]:Hide()
  end
  for i = 1, #markerPool do
    markerPool[i]:Hide()
  end
  for i = 1, #dotPool do
    dotPool[i]:Hide()
  end
  for i = 1, #enemyPool do
    enemyPool[i]:Hide()
  end
  for i = 1, #poiPool do
    poiPool[i]:Hide()
  end
end

local function AcquireLine()
  usedLines = usedLines + 1
  local texture = linePool[usedLines]
  if not texture then
    texture = canvas:CreateTexture(nil, "ARTWORK", nil, 2)
    linePool[usedLines] = texture
  end
  texture:ClearAllPoints()
  texture:SetRotation(0)
  texture:SetTexCoord(0, 1, 0, 1)
  texture:SetTexture(SQUARE_TEXTURE)
  texture:Show()
  return texture
end

local function AcquireDot()
  usedDots = usedDots + 1
  local texture = dotPool[usedDots]
  if not texture then
    texture = canvas:CreateTexture(nil, "OVERLAY", nil, 1)
    dotPool[usedDots] = texture
  end
  texture:ClearAllPoints()
  texture:SetTexture(CIRCLE_TEXTURE)
  texture:SetTexCoord(0, 1, 0, 1)
  texture:Show()
  return texture
end

local function AcquireMarker()
  usedMarkers = usedMarkers + 1
  local marker = markerPool[usedMarkers]
  if not marker then
    marker = CreateFrame("Frame", nil, canvas)
    marker:SetFrameLevel(canvas:GetFrameLevel() + 8)
    marker.icon = marker:CreateTexture(nil, "OVERLAY", nil, 2)
    marker.icon:SetTexture(CIRCLE_TEXTURE)
    marker.icon:SetAllPoints()
    marker.text = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    marker.text:SetPoint("CENTER", marker, "CENTER", 0, 0)
    markerPool[usedMarkers] = marker
  end
  marker:ClearAllPoints()
  marker:Show()
  return marker
end

local function AcquireEnemyIcon()
  usedEnemies = usedEnemies + 1
  local enemyIcon = enemyPool[usedEnemies]
  if not enemyIcon then
    enemyIcon = CreateFrame("Frame", nil, canvas)
    enemyIcon:SetFrameLevel(canvas:GetFrameLevel() + 5)
    enemyIcon.bg = enemyIcon:CreateTexture(nil, "ARTWORK", nil, 1)
    enemyIcon.bg:SetTexture(CIRCLE_TEXTURE)
    enemyIcon.bg:SetAllPoints()
    enemyIcon.icon = enemyIcon:CreateTexture(nil, "ARTWORK", nil, 2)
    enemyIcon.icon:SetPoint("TOPLEFT", enemyIcon, "TOPLEFT", 2, -2)
    enemyIcon.icon:SetPoint("BOTTOMRIGHT", enemyIcon, "BOTTOMRIGHT", -2, 2)
    enemyIcon.count = enemyIcon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enemyIcon.count:SetPoint("CENTER", enemyIcon, "CENTER", 0, 0)
    enemyIcon.count:SetFont(enemyIcon.count:GetFont(), 8, "OUTLINE")
    enemyPool[usedEnemies] = enemyIcon
  end
  enemyIcon:ClearAllPoints()
  enemyIcon:SetAlpha(1)
  enemyIcon.icon:SetTexCoord(0, 1, 0, 1)
  enemyIcon:Show()
  return enemyIcon
end

local function AcquirePOIIcon()
  usedPOIs = usedPOIs + 1
  local poiIcon = poiPool[usedPOIs]
  if not poiIcon then
    poiIcon = canvas:CreateTexture(nil, "OVERLAY", nil, 3)
    poiPool[usedPOIs] = poiIcon
  end
  poiIcon:ClearAllPoints()
  poiIcon:SetTexCoord(0, 1, 0, 1)
  poiIcon:Show()
  return poiIcon
end

local function DrawLine(x1, y1, x2, y2, scale, r, g, b, a, thickness)
  local sx, sy = x1 * scale, y1 * scale
  local ex, ey = x2 * scale, y2 * scale
  local dx, dy = ex - sx, ey - sy
  local length = math.sqrt(dx * dx + dy * dy)
  if length < 2 then return end

  local line = AcquireLine()
  line:SetVertexColor(r, g, b, RouteAlpha(a))
  line:SetSize(length, thickness)
  line:SetPoint("CENTER", canvas, "TOPLEFT", (sx + ex) / 2, (sy + ey) / 2)
  line:SetRotation(math.atan2(dy, dx))
end

local function DrawDot(x, y, scale, r, g, b, a, size)
  local dot = AcquireDot()
  dot:SetSize(size, size)
  dot:SetVertexColor(r, g, b, RouteAlpha(a))
  dot:SetPoint("CENTER", canvas, "TOPLEFT", x * scale, y * scale)
  return dot
end

local function DrawMarker(x, y, scale, pullIdx, r, g, b, active, selected)
  local marker = AcquireMarker()
  local size = active and 20 or selected and 18 or 15
  local fontSize = Clamp(db.mapFontSize or DEFAULTS.mapFontSize, FONT_SIZE_MIN, FONT_SIZE_MAX)
  local alpha = active and 1 or selected and 0.92 or 0.72
  local scaledSize = math.max(size, fontSize + 8, math.floor(size * scale * 1.8))

  marker:SetSize(scaledSize, scaledSize)
  marker:SetPoint("CENTER", canvas, "TOPLEFT", x * scale, y * scale)
  marker:SetAlpha(RouteAlpha(alpha))
  marker.icon:SetVertexColor(r, g, b, 0.92)
  marker.text:SetText(pullIdx)
  marker.text:SetTextColor(1, 1, 1, 1)
  ApplyTextStyle(marker.text, "map", DEFAULTS.mapFontSize, 1)
end

local function DrawEnemyIcon(enemy, clone, scale, pullInfo, selected)
  local enemyIcon = AcquireEnemyIcon()
  local baseScale = (clone.scale or 1) * (enemy.scale or 1) * (enemy.isBoss and 1.45 or 1)
  local size = math.max(7, math.min(18, 10 * baseScale * scale * 2.15))
  local r, g, b = 0.86, 0.86, 0.86
  local alpha = 0.78

  if pullInfo then
    r, g, b = pullInfo.r, pullInfo.g, pullInfo.b
    alpha = selected and 1 or 0.88
  elseif not db.showUnpulledEnemies then
    enemyIcon:Hide()
    return
  end

  enemyIcon:SetSize(size, size)
  enemyIcon:SetPoint("CENTER", canvas, "TOPLEFT", clone.x * scale, clone.y * scale)
  enemyIcon:SetAlpha(RouteAlpha(alpha))
  enemyIcon.bg:SetVertexColor(r, g, b, pullInfo and 0.95 or 0.55)

  if db.showEnemyPortraits and enemy.displayId then
    SetPortraitTextureFromCreatureDisplayID(enemyIcon.icon, enemy.displayId)
    enemyIcon.icon:SetVertexColor(1, 1, 1, pullInfo and 0.95 or 0.72)
  else
    enemyIcon.icon:SetTexture(CIRCLE_TEXTURE)
    enemyIcon.icon:SetVertexColor(r, g, b, pullInfo and 0.9 or 0.55)
  end

  if enemy.count and enemy.count > 0 and size >= 11 then
    enemyIcon.count:SetText(enemy.count)
    enemyIcon.count:SetTextColor(1, 1, 1, 0.9)
    enemyIcon.count:Show()
  else
    enemyIcon.count:Hide()
  end
end

local function DrawPOI(poi, scale)
  if not poi or not poi.x or not poi.y then return end
  local icon = AcquirePOIIcon()
  local size = poi.size or (poi.info and poi.info.size) or 16
  local texture = poi.texture or (poi.info and poi.info.texture)

  icon:SetSize(math.max(8, size * scale * 1.45), math.max(8, size * scale * 1.45))
  icon:SetPoint("CENTER", canvas, "TOPLEFT", poi.x * scale, poi.y * scale)

  if texture then
    icon:SetTexture(texture)
    icon:SetVertexColor(1, 1, 1, RouteAlpha(0.9))
  else
    icon:SetTexture(POI_FALLBACK_TEXTURE)
    icon:SetTexCoord(0, 0.25, 0, 0.25)
    icon:SetVertexColor(0.35, 0.72, 1, RouteAlpha(0.8))
  end
end

local function HidePullSidebarRows()
  for i = 1, #pullSidebarRows do
    pullSidebarRows[i]:Hide()
  end
end

local function GetPullSidebarRowHeight()
  local fontSize = Clamp(db and db.sidebarFontSize or DEFAULTS.sidebarFontSize, FONT_SIZE_MIN, FONT_SIZE_MAX)
  return math.max(18, math.floor((fontSize + 11) * Clamp(db and db.pullSidebarScale or 1, SIDEBAR_MIN_SCALE, SIDEBAR_MAX_SCALE) + 0.5))
end

local function GetPullSidebarHeaderHeight()
  local fontSize = Clamp(db and db.sidebarFontSize or DEFAULTS.sidebarFontSize, FONT_SIZE_MIN, FONT_SIZE_MAX)
  return math.max(20, math.floor(math.max(SIDEBAR_HEADER_HEIGHT, fontSize + 10) * Clamp(db and db.pullSidebarScale or 1, SIDEBAR_MIN_SCALE, SIDEBAR_MAX_SCALE) + 0.5))
end

UpdatePullSidebarHeader = function()
  if not pullSidebarShowAllButton or not db then return end

  local active = db.showAllPulls == true
  local scale = Clamp(db.pullSidebarScale or 1, SIDEBAR_MIN_SCALE, SIDEBAR_MAX_SCALE)
  pullSidebarShowAllButton:SetBackdropColor(active and 0.08 or 0.025, active and 0.22 or 0.03, active and 0.34 or 0.045, active and 0.92 or 0.86)
  pullSidebarShowAllButton:SetBackdropBorderColor(active and 0.2 or 0, active and 0.82 or 0, active and 1 or 0, active and 0.95 or 0.65)
  if pullSidebarShowAllButton.text then
    pullSidebarShowAllButton.text:SetText("All Pulls")
    pullSidebarShowAllButton.text:SetTextColor(active and 1 or 0.75, active and 0.9 or 0.78, active and 0.15 or 0.85, 1)
    ApplyTextStyle(pullSidebarShowAllButton.text, "sidebar", DEFAULTS.sidebarFontSize, scale, -1)
  end
end

LayoutPullSidebar = function()
  if not pullSidebar or not pullSidebarScroll then return end

  local headerHeight = GetPullSidebarHeaderHeight()
  if pullSidebarShowAllButton then
    pullSidebarShowAllButton:ClearAllPoints()
    pullSidebarShowAllButton:SetPoint("TOPLEFT", pullSidebar, "TOPLEFT", 2, -2)
    pullSidebarShowAllButton:SetPoint("TOPRIGHT", pullSidebar, "TOPRIGHT", -2, -2)
    pullSidebarShowAllButton:SetHeight(math.max(18, headerHeight - 3))
  end

  pullSidebarScroll:ClearAllPoints()
  pullSidebarScroll:SetPoint("TOPLEFT", pullSidebar, "TOPLEFT", 2, -(headerHeight + 2))
  pullSidebarScroll:SetPoint("BOTTOMRIGHT", pullSidebar, "BOTTOMRIGHT", -2, 2)
  UpdatePullSidebarHeader()
end

local function IsCloneIncluded(MDT, enemyIdx, cloneIdx)
  if MDT and type(MDT.IsCloneIncluded) == "function" then
    local ok, included = pcall(MDT.IsCloneIncluded, MDT, enemyIdx, cloneIdx)
    if ok then return included == true end
  end
  return true
end

local function GetPullForces(MDT, mdtDB, preset, pullIdx, currentOnly)
  if MDT and type(MDT.CountForces) == "function" then
    local ok, forces = pcall(MDT.CountForces, MDT, pullIdx, currentOnly == true)
    if ok and forces then return forces end
  end

  local total = 0
  local pulls = preset and preset.value and preset.value.pulls
  local enemies = MDT and MDT.dungeonEnemies and mdtDB and MDT.dungeonEnemies[mdtDB.currentDungeonIdx]
  if type(pulls) ~= "table" or type(enemies) ~= "table" then return 0 end

  for i = 1, #pulls do
    if (currentOnly and i == pullIdx) or ((not currentOnly) and i <= pullIdx) then
      for enemyIdx, clones in pairs(pulls[i]) do
        local numericEnemyIdx = tonumber(enemyIdx)
        local enemy = numericEnemyIdx and enemies[numericEnemyIdx]
        if enemy and type(clones) == "table" then
          for _, cloneIdx in pairs(clones) do
            if enemy.clones and enemy.clones[cloneIdx] and IsCloneIncluded(MDT, numericEnemyIdx, cloneIdx) then
              total = total + (enemy.count or 0)
            end
          end
        end
      end
    elseif i > pullIdx then
      break
    end
  end
  return total
end

local function FormatPercent(forces, maxForces)
  if not maxForces or maxForces <= 0 then return "" end
  return string.format("%.2f%%", (forces / maxForces) * 100)
end

MDTMiniRouteRecoveryState = MDTMiniRouteRecoveryState or { undo = {}, redo = {} }

function MDTMiniRouteDeepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end

  local copy = {}
  seen[value] = copy
  for key, child in pairs(value) do
    copy[MDTMiniRouteDeepCopy(key, seen)] = MDTMiniRouteDeepCopy(child, seen)
  end
  return copy
end

function MDTMiniRouteGetScenarioPercent()
  if not C_Scenario or type(C_Scenario.GetStepInfo) ~= "function" then return end
  if not C_ScenarioInfo or type(C_ScenarioInfo.GetCriteriaInfo) ~= "function" then return end

  local ok, stepName, currentStage, criteriaCount = pcall(C_Scenario.GetStepInfo)
  if not ok or not criteriaCount or criteriaCount <= 0 then return end

  local value
  for criteriaIdx = 1, criteriaCount do
    local criteriaOk, info = pcall(C_ScenarioInfo.GetCriteriaInfo, criteriaIdx)
    local text = criteriaOk and info and info.quantityString
    local percent = type(text) == "string" and tonumber(text:match("([%d%.]+)%s*%%"))
    if percent then
      value = math.max(value or 0, percent)
    end
  end
  return value
end

function MDTMiniRouteGetTankMapPosition()
  if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function" or type(C_Map.GetPlayerMapPosition) ~= "function" then return end

  local unit = "player"
  if UnitGroupRolesAssigned then
    if UnitExists("player") and UnitGroupRolesAssigned("player") == "TANK" then
      unit = "player"
    else
      local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
      local raid = IsInRaid and IsInRaid()
      for i = 1, math.min(groupSize, raid and 40 or 4) do
        local candidate = raid and ("raid"..i) or ("party"..i)
        if UnitExists(candidate) and UnitIsConnected(candidate) and UnitGroupRolesAssigned(candidate) == "TANK" then
          unit = candidate
          break
        end
      end
    end
  end

  local mapId = C_Map.GetBestMapForUnit(unit) or C_Map.GetBestMapForUnit("player")
  local position = mapId and C_Map.GetPlayerMapPosition(mapId, unit)
  if not position then return end

  local x, y = position:GetXY()
  if not x or not y or (x == 0 and y == 0) then return end
  return x * MAP_WIDTH, -y * MAP_HEIGHT
end

function MDTMiniRouteGetMaxForces()
  local MDT = GetMDT()
  local mdtDB = GetMDTDB()
  local dungeonIdx = mdtDB and mdtDB.currentDungeonIdx
  return MDT and MDT.dungeonTotalCount and dungeonIdx and MDT.dungeonTotalCount[dungeonIdx] and MDT.dungeonTotalCount[dungeonIdx].normal
end

function MDTMiniRouteCountPullsForces(pulls, pullIdx, currentOnly)
  local MDT = GetMDT()
  local mdtDB = GetMDTDB()
  local dungeonIdx = mdtDB and mdtDB.currentDungeonIdx
  local enemies = MDT and MDT.dungeonEnemies and dungeonIdx and MDT.dungeonEnemies[dungeonIdx]
  if type(pulls) ~= "table" or type(enemies) ~= "table" then return 0 end

  local total = 0
  pullIdx = pullIdx or 1000
  for idx, pull in pairs(pulls) do
    if type(idx) == "number" and idx <= pullIdx and (not currentOnly or idx == pullIdx) and type(pull) == "table" then
      for enemyIdx, clones in pairs(pull) do
        local numericEnemyIdx = tonumber(enemyIdx)
        local enemy = numericEnemyIdx and enemies[numericEnemyIdx]
        if enemy and type(clones) == "table" then
          for _, cloneIdx in pairs(clones) do
            if IsCloneIncluded(MDT, numericEnemyIdx, cloneIdx) then
              total = total + (tonumber(enemy.count) or 0)
            end
          end
        end
      end
    end
  end
  return total
end

function MDTMiniRouteSnapshotRoute()
  local preset = GetCurrentPreset()
  if not preset or not preset.value then return end
  return MDTMiniRouteDeepCopy(preset.value)
end

function MDTMiniRouteRestoreRoute(snapshot)
  if type(snapshot) ~= "table" then return end

  local MDT = GetMDT()
  local preset = GetCurrentPreset()
  if not preset then return end

  preset.value = MDTMiniRouteDeepCopy(snapshot)
  if MDT and type(MDT.UpdateMap) == "function" then
    pcall(MDT.UpdateMap, MDT)
  end
  RequestRefresh()
  RefreshIfNeeded(true)
  if MDTMiniRouteRefreshRecoveryFrame then
    MDTMiniRouteRefreshRecoveryFrame()
  end
end

function MDTMiniRouteEnsureRecoveryState()
  if type(MDTMiniRouteRecoveryState) ~= "table" then
    MDTMiniRouteRecoveryState = {}
  end
  if type(MDTMiniRouteRecoveryState.undo) ~= "table" then MDTMiniRouteRecoveryState.undo = {} end
  if type(MDTMiniRouteRecoveryState.redo) ~= "table" then MDTMiniRouteRecoveryState.redo = {} end
  return MDTMiniRouteRecoveryState
end

function MDTMiniRouteBeginRecoveryEdit()
  local state = MDTMiniRouteEnsureRecoveryState()
  if not state.baseline then
    state.baseline = MDTMiniRouteSnapshotRoute()
  end
  local snapshot = MDTMiniRouteSnapshotRoute()
  if snapshot then
    table.insert(state.undo, snapshot)
    state.redo = {}
  end
end

function MDTMiniRouteUndoRecovery()
  local state = MDTMiniRouteEnsureRecoveryState()
  local snapshot = table.remove(state.undo)
  if not snapshot then
    Print("no recovery edit to undo")
    return
  end
  local current = MDTMiniRouteSnapshotRoute()
  if current then table.insert(state.redo, current) end
  MDTMiniRouteRestoreRoute(snapshot)
end

function MDTMiniRouteRedoRecovery()
  local state = MDTMiniRouteEnsureRecoveryState()
  local snapshot = table.remove(state.redo)
  if not snapshot then
    Print("no recovery edit to redo")
    return
  end
  local current = MDTMiniRouteSnapshotRoute()
  if current then table.insert(state.undo, current) end
  MDTMiniRouteRestoreRoute(snapshot)
end

function MDTMiniRouteRevertRecovery()
  local state = MDTMiniRouteEnsureRecoveryState()
  if not state.baseline then
    Print("no recovery changes to revert")
    return
  end
  MDTMiniRouteRestoreRoute(state.baseline)
  state.baseline = nil
  state.undo = {}
  state.redo = {}
  Print("recovery changes reverted")
end

function MDTMiniRouteSetRecoveryMode(enabled)
  if not db then return end
  db.recoveryMode = enabled == true
  if db.recoveryMode then
    db.showEnemyDots = true
    Print("recovery mode on")
  else
    Print("recovery mode off")
  end
  RequestRefresh()
  RefreshIfNeeded(true)
  if MDTMiniRouteRefreshRecoveryFrame then
    MDTMiniRouteRefreshRecoveryFrame()
  end
end

function MDTMiniRouteSetAnchorPull(pullIdx)
  if not db then return end
  pullIdx = tonumber(pullIdx)
  if not pullIdx then return end

  local previousAutoSelect = db.autoSelectPull
  db.autoSelectPull = false
  SelectPull(pullIdx)
  db.autoSelectPull = previousAutoSelect
  db.autoPullUseProximity = true
  db.autoPullAnchorActive = true
  db.autoPullAnchorPull = pullIdx
  db.autoSelectPull = true
  Print("auto selector anchored to pull "..pullIdx)
end

function MDTMiniRoutePullContainsClone(pulls, enemyIdx, cloneIdx)
  if type(pulls) ~= "table" then return end
  enemyIdx = tonumber(enemyIdx)
  for pullIdx, pull in pairs(pulls) do
    local clones = type(pull) == "table" and pull[enemyIdx]
    if type(clones) == "table" then
      for _, currentCloneIdx in pairs(clones) do
        if currentCloneIdx == cloneIdx then
          return pullIdx
        end
      end
    end
  end
end

function MDTMiniRouteRemoveCloneFromPulls(pulls, enemyIdx, cloneIdx)
  if type(pulls) ~= "table" then return end
  enemyIdx = tonumber(enemyIdx)
  for _, pull in pairs(pulls) do
    local clones = type(pull) == "table" and pull[enemyIdx]
    if type(clones) == "table" then
      for i = #clones, 1, -1 do
        if clones[i] == cloneIdx then
          table.remove(clones, i)
        end
      end
    end
  end
end

function MDTMiniRouteAddRecoveryClone(enemyIdx, cloneIdx, targetPull)
  local MDT = GetMDT()
  local mdtDB = GetMDTDB()
  local preset = GetCurrentPreset()
  local pulls = preset and preset.value and preset.value.pulls
  local enemies = MDT and mdtDB and MDT.dungeonEnemies and MDT.dungeonEnemies[mdtDB.currentDungeonIdx]
  enemyIdx = tonumber(enemyIdx)
  if not MDT or not preset or type(pulls) ~= "table" or type(enemies) ~= "table" or not enemyIdx or not cloneIdx then return end

  targetPull = tonumber(targetPull or GetCurrentPull(preset)) or 1
  pulls[targetPull] = pulls[targetPull] or {}
  MDTMiniRouteBeginRecoveryEdit()

  local function addOne(addEnemyIdx, addCloneIdx)
    MDTMiniRouteRemoveCloneFromPulls(pulls, addEnemyIdx, addCloneIdx)
    pulls[targetPull][addEnemyIdx] = pulls[targetPull][addEnemyIdx] or {}
    for _, currentCloneIdx in pairs(pulls[targetPull][addEnemyIdx]) do
      if currentCloneIdx == addCloneIdx then return end
    end
    table.insert(pulls[targetPull][addEnemyIdx], addCloneIdx)
  end

  addOne(enemyIdx, cloneIdx)
  local clickedClone = enemies[enemyIdx] and enemies[enemyIdx].clones and enemies[enemyIdx].clones[cloneIdx]
  if clickedClone and clickedClone.g then
    for otherEnemyIdx, otherEnemy in pairs(enemies) do
      if type(otherEnemy) == "table" and type(otherEnemy.clones) == "table" then
        for otherCloneIdx, otherClone in pairs(otherEnemy.clones) do
          if otherClone and otherClone.g == clickedClone.g then
            addOne(otherEnemyIdx, otherCloneIdx)
          end
        end
      end
    end
  end

  if MDT and type(MDT.SetSelectionToPull) == "function" then
    pcall(MDT.SetSelectionToPull, MDT, targetPull)
  else
    preset.value.currentPull = targetPull
    preset.value.selection = { targetPull }
  end
  RequestRefresh()
  RefreshIfNeeded(true)
  if MDTMiniRouteRefreshRecoveryFrame then MDTMiniRouteRefreshRecoveryFrame() end
end

function MDTMiniRouteRemoveRecoveryClone(enemyIdx, cloneIdx)
  local preset = GetCurrentPreset()
  local pulls = preset and preset.value and preset.value.pulls
  if type(pulls) ~= "table" then return end

  MDTMiniRouteBeginRecoveryEdit()
  MDTMiniRouteRemoveCloneFromPulls(pulls, enemyIdx, cloneIdx)
  RequestRefresh()
  RefreshIfNeeded(true)
  if MDTMiniRouteRefreshRecoveryFrame then MDTMiniRouteRefreshRecoveryFrame() end
end

function MDTMiniRouteRecoveryMobVisible(clone)
  if not db or db.recoveryMode ~= true or not clone then return false end
  local tankX, tankY = MDTMiniRouteGetTankMapPosition()
  if not tankX or not tankY then return true end

  local radius = math.max(150, (db.autoPullProximityRadius or DEFAULTS.autoPullProximityRadius) * 2)
  local dx, dy = clone.x - tankX, clone.y - tankY
  return ((dx * dx) + (dy * dy)) <= (radius * radius)
end

function MDTMiniRouteResetHitFrames()
  if type(MDTMiniRouteHitPool) ~= "table" then return end
  MDTMiniRouteHitPool.used = 0
  for _, hit in ipairs(MDTMiniRouteHitPool.frames or {}) do
    hit:Hide()
  end
end

function MDTMiniRouteAcquireHitFrame()
  if not canvas then return end
  if type(MDTMiniRouteHitPool) ~= "table" then
    MDTMiniRouteHitPool = { used = 0, frames = {} }
  end

  MDTMiniRouteHitPool.used = (MDTMiniRouteHitPool.used or 0) + 1
  local hit = MDTMiniRouteHitPool.frames[MDTMiniRouteHitPool.used]
  if not hit then
    hit = CreateFrame("Button", nil, canvas)
    hit:SetFrameLevel(canvas:GetFrameLevel() + 20)
    hit:EnableMouse(true)
    hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hit.highlight = hit:CreateTexture(nil, "HIGHLIGHT")
    hit.highlight:SetAllPoints()
    hit.highlight:SetColorTexture(1, 1, 1, 0.12)
    hit:SetScript("OnClick", function(self, button)
      if self.hitPullIdx then
        if button == "LeftButton" and IsShiftKeyDown() then
          MDTMiniRouteSetAnchorPull(self.hitPullIdx)
          return
        end
        if button == "LeftButton" then
          SelectPull(self.hitPullIdx)
          return
        end
      end

      if self.hitEnemyIdx and self.hitCloneIdx and db and db.recoveryMode == true then
        if button == "LeftButton" and not self.hitPullIdx then
          MDTMiniRouteAddRecoveryClone(self.hitEnemyIdx, self.hitCloneIdx)
        elseif button == "RightButton" and self.hitPullIdx then
          MDTMiniRouteRemoveRecoveryClone(self.hitEnemyIdx, self.hitCloneIdx)
        end
      end
    end)
    hit:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      if self.hitType == "pull" then
        GameTooltip:AddLine("Pull "..tostring(self.hitPullIdx), 1, 0.85, 0.1)
        GameTooltip:AddLine("Left-click: show planned pull", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Shift-left-click: anchor auto selector here", 0.55, 0.85, 1)
      elseif self.hitType == "mob" then
        GameTooltip:AddLine(self.hitName or "Mob", 1, 1, 1)
        if self.hitPercent then
          GameTooltip:AddLine(string.format("%.2f%% forces", self.hitPercent), 0.7, 0.9, 1)
        end
        if self.hitPullIdx then
          GameTooltip:AddLine("Route pull "..tostring(self.hitPullIdx), 1, 0.85, 0.1)
          GameTooltip:AddLine("Left-click: show pull", 0.8, 0.8, 0.8)
          GameTooltip:AddLine("Shift-left-click: anchor auto selector", 0.55, 0.85, 1)
          if db and db.recoveryMode == true then
            GameTooltip:AddLine("Right-click: remove from route", 1, 0.45, 0.45)
          end
        elseif db and db.recoveryMode == true then
          GameTooltip:AddLine("Left-click: add to current pull", 0.55, 1, 0.65)
        end
      end
      GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    MDTMiniRouteHitPool.frames[MDTMiniRouteHitPool.used] = hit
  end

  hit:ClearAllPoints()
  hit.hitType = nil
  hit.hitPullIdx = nil
  hit.hitEnemyIdx = nil
  hit.hitCloneIdx = nil
  hit.hitName = nil
  hit.hitPercent = nil
  hit:Show()
  return hit
end

function MDTMiniRoutePlacePullHit(pullIdx, vertices, center, scale)
  if not center or not scale then return end
  local hit = MDTMiniRouteAcquireHitFrame()
  if not hit then return end

  local minX, maxX = center.x, center.x
  local minY, maxY = center.y, center.y
  for _, vertex in ipairs(vertices or {}) do
    minX = math.min(minX, vertex[1] or minX)
    maxX = math.max(maxX, vertex[1] or maxX)
    minY = math.min(minY, vertex[2] or minY)
    maxY = math.max(maxY, vertex[2] or maxY)
  end

  local width = math.max(28, (maxX - minX) * scale + 20)
  local height = math.max(28, (maxY - minY) * scale + 20)
  hit:SetSize(width, height)
  hit:SetPoint("CENTER", canvas, "TOPLEFT", ((minX + maxX) / 2) * scale, ((minY + maxY) / 2) * scale)
  hit.hitType = "pull"
  hit.hitPullIdx = pullIdx
end

function MDTMiniRoutePlaceMobHit(enemyIdx, cloneIdx, enemy, clone, scale, pullInfo)
  if not enemy or not clone or not clone.x or not clone.y or not scale then return end
  local hit = MDTMiniRouteAcquireHitFrame()
  if not hit then return end

  local maxForces = MDTMiniRouteGetMaxForces()
  local count = tonumber(enemy.count) or 0
  hit:SetSize(math.max(12, 18 * scale), math.max(12, 18 * scale))
  hit:SetPoint("CENTER", canvas, "TOPLEFT", clone.x * scale, clone.y * scale)
  hit.hitType = "mob"
  hit.hitEnemyIdx = tonumber(enemyIdx)
  hit.hitCloneIdx = cloneIdx
  hit.hitPullIdx = pullInfo and pullInfo.pullIdx
  hit.hitName = enemy.name or enemy.creatureName or ("Mob "..tostring(enemy.id or enemyIdx))
  hit.hitPercent = maxForces and maxForces > 0 and ((count / maxForces) * 100) or nil
end

MDTMiniRouteSuggestRecovery = function()
  if not db then return end

  local MDT = GetMDT()
  local mdtDB = GetMDTDB()
  local preset = GetCurrentPreset()
  local pulls = preset and preset.value and preset.value.pulls
  local dungeonIdx = mdtDB and mdtDB.currentDungeonIdx
  local enemies = MDT and MDT.dungeonEnemies and dungeonIdx and MDT.dungeonEnemies[dungeonIdx]
  local maxForces = MDT and MDT.dungeonTotalCount and dungeonIdx and MDT.dungeonTotalCount[dungeonIdx] and MDT.dungeonTotalCount[dungeonIdx].normal
  if not MDT or not mdtDB or type(pulls) ~= "table" or type(enemies) ~= "table" or not maxForces or maxForces <= 0 then
    Print("recovery hint needs an active MDT route with enemy forces data")
    return
  end

  local function scenarioPercent()
    if not C_Scenario or type(C_Scenario.GetStepInfo) ~= "function" then return end
    if not C_ScenarioInfo or type(C_ScenarioInfo.GetCriteriaInfo) ~= "function" then return end

    local ok, stepName, currentStage, criteriaCount = pcall(C_Scenario.GetStepInfo)
    if not ok or not criteriaCount or criteriaCount <= 0 then return end

    local value
    for criteriaIdx = 1, criteriaCount do
      local criteriaOk, info = pcall(C_ScenarioInfo.GetCriteriaInfo, criteriaIdx)
      local text = criteriaOk and info and info.quantityString
      local percent = type(text) == "string" and tonumber(text:match("([%d%.]+)%s*%%"))
      if percent then
        value = math.max(value or 0, percent)
      end
    end
    return value
  end

  local actualPercent = scenarioPercent()
  if not actualPercent then
    Print("recovery hint needs active Mythic+ enemy forces progress")
    return
  end

  local currentPull = math.floor(Clamp(tonumber(GetCurrentPull(preset)) or 1, 1, #pulls))
  local startForces = currentPull > 1 and GetPullForces(MDT, mdtDB, preset, currentPull - 1, false) or 0
  local endForces = GetPullForces(MDT, mdtDB, preset, currentPull, false)
  local startPercent = (startForces / maxForces) * 100
  local endPercent = (endForces / maxForces) * 100
  local threshold = Clamp(db.autoPullDriftThreshold or DEFAULTS.autoPullDriftThreshold, 1, 25)
  local deficit = startPercent - actualPercent
  local surplus = actualPercent - endPercent

  if deficit <= threshold and surplus <= threshold then
    Print(string.format("route progress looks aligned: %.2f%% actual, pull %d expects %.2f-%.2f%%", actualPercent, currentPull, startPercent, endPercent))
    return
  end

  local function tankPosition()
    if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function" or type(C_Map.GetPlayerMapPosition) ~= "function" then return end
    local unit = "player"
    if UnitGroupRolesAssigned then
      local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
      for i = 1, math.min(groupSize, IsInRaid and IsInRaid() and 40 or 4) do
        local candidate = (IsInRaid and IsInRaid()) and ("raid"..i) or ("party"..i)
        if UnitExists(candidate) and UnitIsConnected(candidate) and UnitGroupRolesAssigned(candidate) == "TANK" then
          unit = candidate
          break
        end
      end
    end
    local mapId = C_Map.GetBestMapForUnit(unit) or C_Map.GetBestMapForUnit("player")
    local position = mapId and C_Map.GetPlayerMapPosition(mapId, unit)
    if not position then return end
    local x, y = position:GetXY()
    if not x or not y or (x == 0 and y == 0) then return end
    return x * MAP_WIDTH, -y * MAP_HEIGHT
  end

  local tankX, tankY = tankPosition()
  local sublevel = preset.value.currentSublevel or 1

  if deficit > threshold then
    local routeClones = {}
    for _, pull in ipairs(pulls) do
      if type(pull) == "table" then
        for enemyIdx, clones in pairs(pull) do
          if type(clones) == "table" then
            for _, cloneIdx in pairs(clones) do
              routeClones[tostring(enemyIdx)..":"..tostring(cloneIdx)] = true
            end
          end
        end
      end
    end

    local candidates = {}
    for enemyIdx, enemy in pairs(enemies) do
      if type(enemy) == "table" and type(enemy.clones) == "table" and not enemy.isBoss then
        for cloneIdx, clone in pairs(enemy.clones) do
          local key = tostring(enemyIdx)..":"..tostring(cloneIdx)
          if not routeClones[key] and clone and clone.x and clone.y and (clone.sublevel == sublevel or clone.sublevel == nil) then
            local count = tonumber(enemy.count) or 0
            if count > 0 then
              local distance = 99999
              if tankX and tankY then
                local dx, dy = clone.x - tankX, clone.y - tankY
                distance = math.sqrt((dx * dx) + (dy * dy))
              end
              local spellPenalty = type(enemy.spells) == "table" and 160 or 0
              local score = distance + spellPenalty + math.max(0, count - ((deficit / 100) * maxForces)) * 8
              candidates[#candidates + 1] = {
                name = enemy.name or enemy.creatureName or ("Mob "..tostring(enemy.id or enemyIdx)),
                count = count,
                percent = (count / maxForces) * 100,
                distance = distance,
                score = score,
              }
            end
          end
        end
      end
    end

    table.sort(candidates, function(a, b) return a.score < b.score end)
    Print(string.format("behind by about %.2f%%. Nearby unpulled options:", deficit))
    for i = 1, math.min(3, #candidates) do
      local candidate = candidates[i]
      Print(string.format("%d) %s - %.2f%%, distance %.0f", i, candidate.name, candidate.percent, candidate.distance))
    end
    if #candidates == 0 then
      Print("no nearby unpulled non-boss mobs found in MDT data")
    end
    return
  end

  local candidates = {}
  for pullIdx = currentPull + 1, #pulls do
    local pullForces = GetPullForces(MDT, mdtDB, preset, pullIdx, true)
    if pullForces and pullForces > 0 then
      candidates[#candidates + 1] = {
        pullIdx = pullIdx,
        percent = (pullForces / maxForces) * 100,
        score = math.abs(((surplus / 100) * maxForces) - pullForces) + (pullIdx - currentPull) * 2,
      }
    end
  end
  table.sort(candidates, function(a, b) return a.score < b.score end)
  Print(string.format("ahead by about %.2f%%. Possible future skip candidates:", surplus))
  for i = 1, math.min(3, #candidates) do
    local candidate = candidates[i]
    Print(string.format("%d) pull %d - %.2f%% route value", i, candidate.pullIdx, candidate.percent))
  end
  if #candidates == 0 then
    Print("no future route pulls found to suggest skipping")
  end
end

UpdateAutoPullFromProgress = function(force, correctionPullIdx)
  if not db or not db.autoSelectPull then return end

  if IsInMatchingDungeon() ~= true then return end

  local MDT = GetMDT()
  local mdtDB = GetMDTDB()
  local preset = GetCurrentPreset()
  local pulls = preset and preset.value and preset.value.pulls
  local enemies = MDT and MDT.dungeonEnemies and mdtDB and MDT.dungeonEnemies[mdtDB.currentDungeonIdx]
  if not MDT or not mdtDB or type(pulls) ~= "table" or #pulls == 0 or type(enemies) ~= "table" then return end
  local maxForces = MDT.dungeonTotalCount and MDT.dungeonTotalCount[mdtDB.currentDungeonIdx] and MDT.dungeonTotalCount[mdtDB.currentDungeonIdx].normal

  local function criteriaPercent(info)
    local text = info and info.quantityString
    if type(text) ~= "string" then return end

    local value = text:match("([%d%.]+)%s*%%")
    return value and tonumber(value)
  end

  local function scenarioProgress()
    if not C_Scenario or type(C_Scenario.GetStepInfo) ~= "function" then return end
    if not C_ScenarioInfo or type(C_ScenarioInfo.GetCriteriaInfo) ~= "function" then return end

    local ok, stepName, currentStage, criteriaCount = pcall(C_Scenario.GetStepInfo)
    if not ok or not criteriaCount or criteriaCount <= 0 then return end

    local enemyForces
    local defeatedBosses = 0
    for criteriaIdx = 1, criteriaCount do
      local criteriaOk, info = pcall(C_ScenarioInfo.GetCriteriaInfo, criteriaIdx)
      if criteriaOk and type(info) == "table" then
        local percent = criteriaPercent(info)
        if percent then
          enemyForces = math.max(enemyForces or 0, percent)
        elseif info.completed and (info.criteriaType == 0 or info.criteriaType == 165) then
          defeatedBosses = defeatedBosses + 1
        end
      end
    end

    return enemyForces, defeatedBosses
  end

  local function pullProgressCost(pull)
    if type(pull) ~= "table" then return 0, false end

    local trash = 0
    local hasBoss = false
    for enemyIdx, clones in pairs(pull) do
      local numericEnemyIdx = tonumber(enemyIdx)
      local enemy = numericEnemyIdx and enemies[numericEnemyIdx]
      if enemy and type(clones) == "table" and type(enemy.clones) == "table" then
        local bossIncluded
        for _, cloneIdx in pairs(clones) do
          if enemy.clones[cloneIdx] and IsCloneIncluded(MDT, numericEnemyIdx, cloneIdx) then
            if enemy.isBoss then
              bossIncluded = true
            else
              trash = trash + (tonumber(enemy.count) or 0)
            end
          end
        end
        hasBoss = hasBoss or bossIncluded == true
      end
    end

    return trash, hasBoss
  end

  local function progressPullIndex(enemyForces, bosses)
    if not enemyForces then return end

    local trashLeft = enemyForces + (tonumber(db.autoPullTrashOffset) or 0)
    local bossesLeft = (bosses or 0) + (tonumber(db.autoPullBossOffset) or 0)
    local epsilon = 0.001

    for idx = 1, #pulls do
      local pullTrash, hasBoss = pullProgressCost(pulls[idx])
      local trashCovered = (trashLeft + epsilon) >= pullTrash
      local bossCovered = not hasBoss or bossesLeft > 0
      if trashCovered and bossCovered then
        trashLeft = trashLeft - pullTrash
        if hasBoss then
          bossesLeft = bossesLeft - 1
        end
      else
        return idx
      end
    end

    return #pulls
  end

  local function validUnit(unit)
    return unit and UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)
  end

  local function tankUnit()
    if UnitGroupRolesAssigned then
      if validUnit("player") and UnitGroupRolesAssigned("player") == "TANK" then
        return "player"
      end

      local groupSize = GetNumGroupMembers and GetNumGroupMembers() or 0
      if IsInRaid and IsInRaid() then
        for i = 1, math.min(groupSize, 40) do
          local unit = "raid"..i
          if validUnit(unit) and UnitGroupRolesAssigned(unit) == "TANK" then
            return unit
          end
        end
      else
        for i = 1, math.min(groupSize, 4) do
          local unit = "party"..i
          if validUnit(unit) and UnitGroupRolesAssigned(unit) == "TANK" then
            return unit
          end
        end
      end
    end

    return validUnit("player") and "player" or nil
  end

  local function unitMapPosition(unit)
    if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function" or type(C_Map.GetPlayerMapPosition) ~= "function" then return end

    local mapId = C_Map.GetBestMapForUnit(unit) or C_Map.GetBestMapForUnit("player")
    local position = mapId and C_Map.GetPlayerMapPosition(mapId, unit)
    if not position then return end

    local x, y = position:GetXY()
    if not x or not y or (x == 0 and y == 0) then return end
    return x * MAP_WIDTH, -y * MAP_HEIGHT
  end

  local function pullCenter(pull)
    if type(pull) ~= "table" then return end

    local wantedSublevel = preset.value.currentSublevel or 1
    for pass = 1, 2 do
      local sumX, sumY, count = 0, 0, 0
      for enemyIdx, clones in pairs(pull) do
        local numericEnemyIdx = tonumber(enemyIdx)
        local enemy = numericEnemyIdx and enemies[numericEnemyIdx]
        if enemy and type(clones) == "table" and type(enemy.clones) == "table" then
          for _, cloneIdx in pairs(clones) do
            local clone = enemy.clones[cloneIdx]
            local sameSublevel = clone and (clone.sublevel == wantedSublevel or clone.sublevel == nil)
            if clone and clone.x and clone.y and (sameSublevel or pass == 2) and IsCloneIncluded(MDT, numericEnemyIdx, cloneIdx) then
              sumX = sumX + clone.x
              sumY = sumY + clone.y
              count = count + 1
            end
          end
        end
      end
      if count > 0 then
        return sumX / count, sumY / count
      end
    end
  end

  local function proximityPull(anchorPullIdx, lookBehind, lookAhead, closest)
    if db.autoPullUseProximity ~= true then return end

    local unit = tankUnit()
    local x, y = unitMapPosition(unit)
    if not x or not y then return end

    local radius = Clamp(db.autoPullProximityRadius or DEFAULTS.autoPullProximityRadius, 25, 240)
    local maxDistance = radius * radius

    local firstPull = tonumber(anchorPullIdx) or tonumber(GetCurrentPull(preset)) or 1
    firstPull = math.floor(Clamp(firstPull, 1, #pulls))
    local lastPull = math.min(#pulls, firstPull + (lookAhead or 1))
    firstPull = math.max(1, firstPull - (lookBehind or 0))
    local bestPull, bestDistance

    for idx = firstPull, lastPull do
      local centerX, centerY = pullCenter(pulls[idx])
      if centerX and centerY then
        local dx, dy = centerX - x, centerY - y
        local distance = (dx * dx) + (dy * dy)
        if distance <= maxDistance then
          if closest then
            if not bestDistance or distance < bestDistance then
              bestPull = idx
              bestDistance = distance
            end
          else
            return idx
          end
        end
      end
    end

    return bestPull
  end

  local function routePercent(pullIdx)
    if not maxForces or maxForces <= 0 then return end
    if not pullIdx or pullIdx <= 0 then return 0 end
    return (GetPullForces(MDT, mdtDB, preset, math.min(pullIdx, #pulls), false) / maxForces) * 100
  end

  local function routeDrifted(actualPercent)
    if db.autoPullDriftWatcher == false or not actualPercent then return false end
    local currentPull = math.floor(Clamp(tonumber(GetCurrentPull(preset)) or 1, 1, #pulls))
    local startPercent = routePercent(currentPull - 1)
    local endPercent = routePercent(currentPull)
    if not startPercent or not endPercent then return false end

    local threshold = Clamp(db.autoPullDriftThreshold or DEFAULTS.autoPullDriftThreshold, 1, 25)
    if actualPercent < startPercent - threshold or actualPercent > endPercent + threshold then
      return true, currentPull
    end
    return false, currentPull
  end

  local enemyPercent, bosses = scenarioProgress()
  local enemyForces = enemyPercent
  if enemyPercent and maxForces and maxForces > 0 then
    enemyForces = (enemyPercent / 100) * maxForces
  end

  if correctionPullIdx then
    if not enemyForces then return end

    local trashBefore = 0
    local bossesBefore = 0
    for idx = 1, math.max(0, correctionPullIdx - 1) do
      local pullTrash, hasBoss = pullProgressCost(pulls[idx])
      trashBefore = trashBefore + pullTrash
      if hasBoss then
        bossesBefore = bossesBefore + 1
      end
    end
    db.autoPullTrashOffset = trashBefore - enemyForces
    db.autoPullBossOffset = bossesBefore - (bosses or 0)
    return
  end

  local expectedPullIdx = progressPullIndex(enemyForces, bosses)
  local drifted, currentPull = routeDrifted(enemyPercent)
  local pullIdx
  if db.autoPullAnchorActive and db.autoPullAnchorPull and db.autoPullAnchorPull > 0 then
    if enemyPercent and not drifted then
      db.autoPullAnchorActive = false
      db.autoPullAnchorPull = 0
    else
      local anchorPull = math.floor(Clamp(db.autoPullAnchorPull, 1, #pulls))
      pullIdx = proximityPull(anchorPull, 0, 1, false) or anchorPull
      if pullIdx and pullIdx > anchorPull then
        db.autoPullAnchorPull = pullIdx
      end
    end
  end

  if not pullIdx and drifted then
    pullIdx = proximityPull(currentPull, 2, 2, true) or expectedPullIdx
  elseif not pullIdx then
    pullIdx = proximityPull(expectedPullIdx) or expectedPullIdx
  end

  if not pullIdx then return end

  if not preset or not preset.value or not preset.value.pulls or not preset.value.pulls[pullIdx] then return end
  if tonumber(GetCurrentPull(preset)) == pullIdx then return end

  local ok
  if MDT and type(MDT.SetSelectionToPull) == "function" then
    ok = pcall(MDT.SetSelectionToPull, MDT, pullIdx)
  end
  if not ok then
    preset.value.currentPull = pullIdx
    preset.value.selection = { pullIdx }
  end

  RequestRefresh()
  RefreshIfNeeded(true)
end

local function ScrollPullSidebar(delta)
  if not pullSidebarScroll or not pullSidebarContent then return end
  local maxScroll = math.max(0, (pullSidebarContent:GetHeight() or 0) - (pullSidebarScroll:GetHeight() or 0))
  local current = pullSidebarScroll:GetVerticalScroll() or 0
  local nextValue = current - (delta or 0) * 42
  if nextValue < 0 then nextValue = 0 end
  if nextValue > maxScroll then nextValue = maxScroll end
  pullSidebarScroll:SetVerticalScroll(nextValue)
end

local function AcquirePullSidebarRow(index)
  local row = pullSidebarRows[index]
  if row then return row end

  row = CreateFrame("Button", nil, pullSidebarContent, "BackdropTemplate")
  row:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  row:SetBackdropBorderColor(0, 0, 0, 0.55)
  row.highlight = row:CreateTexture(nil, "OVERLAY")
  row.highlight:SetAllPoints()
  row.highlight:SetColorTexture(1, 1, 1, 0.16)
  row.highlight:Hide()

  row.number = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.number:SetPoint("LEFT", row, "LEFT", 5, 0)
  row.number:SetJustifyH("LEFT")

  row.percent = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.percent:SetPoint("RIGHT", row, "RIGHT", -5, 0)
  row.percent:SetJustifyH("RIGHT")

  row:SetScript("OnMouseWheel", function(_, delta)
    ScrollPullSidebar(delta)
  end)
  row:SetScript("OnEnter", function(self)
    self.highlight:Show()
    local MDT = GetMDT()
    if MDT and type(MDT.PullClickAreaOnEnter) == "function" and self.pullIdx then
      pcall(MDT.PullClickAreaOnEnter, MDT, self.pullIdx)
    end
  end)
  row:SetScript("OnLeave", function(self)
    self.highlight:Hide()
    local MDT = GetMDT()
    if MDT and type(MDT.PullClickAreaOnLeave) == "function" then
      pcall(MDT.PullClickAreaOnLeave, MDT)
    end
  end)
  row:SetScript("OnClick", function(self)
    if self.pullIdx and SelectPull then
      SelectPull(self.pullIdx)
    end
  end)

  pullSidebarRows[index] = row
  return row
end

UpdatePullSidebar = function(mdtDB, preset)
  if not pullSidebar or not pullSidebarContent or not db then return end
  if db.showPullSidebar == false then
    HidePullSidebarRows()
    return
  end

  local MDT = GetMDT()
  local pulls = preset and preset.value and preset.value.pulls
  if not MDT or not mdtDB or type(pulls) ~= "table" then
    HidePullSidebarRows()
    return
  end

  local sidebarWidth = GetPullSidebarWidth()
  local rowWidth = math.max(1, sidebarWidth - 4)
  local rowHeight = GetPullSidebarRowHeight()
  local sidebarScale = Clamp(db.pullSidebarScale or 1, SIDEBAR_MIN_SCALE, SIDEBAR_MAX_SCALE)
  local rowGap = 2
  local maxForces = MDT.dungeonTotalCount and MDT.dungeonTotalCount[mdtDB.currentDungeonIdx] and MDT.dungeonTotalCount[mdtDB.currentDungeonIdx].normal
  local currentPull = tonumber(GetCurrentPull(preset)) or 1
  local contentHeight = math.max(1, (#pulls * (rowHeight + rowGap)) - rowGap)

  pullSidebar:SetWidth(sidebarWidth)
  pullSidebarContent:SetSize(rowWidth, contentHeight)

  for pullIdx = 1, #pulls do
    local row = AcquirePullSidebarRow(pullIdx)
    local r, g, b = GetPullColor(pulls, pullIdx)
    local isCurrent = pullIdx == currentPull

    row.pullIdx = pullIdx
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", pullSidebarContent, "TOPLEFT", 0, -((pullIdx - 1) * (rowHeight + rowGap)))
    row:SetSize(rowWidth, rowHeight)
    row:SetBackdropColor(r, g, b, isCurrent and 0.88 or 0.58)
    row:SetBackdropBorderColor(isCurrent and 1 or 0, isCurrent and 0.9 or 0, isCurrent and 0.25 or 0, isCurrent and 0.95 or 0.45)

    row.number:SetText(pullIdx)
    row.number:SetTextColor(1, 0.84, 0.05, 1)
    row.number:ClearAllPoints()
    row.number:SetPoint("LEFT", row, "LEFT", math.max(5, 6 * sidebarScale), 0)
    row.number:SetWidth(db.showPullPercent == false and rowWidth - 10 or math.max(26, 30 * sidebarScale))
    ApplyTextStyle(row.number, "sidebar", DEFAULTS.sidebarFontSize, sidebarScale)

    if db.showPullPercent == false then
      row.percent:Hide()
    else
      row.percent:SetText(FormatPercent(GetPullForces(MDT, mdtDB, preset, pullIdx, false), maxForces))
      ApplyTextStyle(row.percent, "sidebar", DEFAULTS.sidebarFontSize, sidebarScale, -2)
      row.percent:Show()
    end

    row:Show()
  end

  for i = #pulls + 1, #pullSidebarRows do
    pullSidebarRows[i]:Hide()
  end

  ScrollPullSidebar(0)
end

local function IsLowerLeft(a, b)
  if a[1] < b[1] then return true end
  if a[1] > b[1] then return false end
  return a[2] < b[2]
end

local function IsLeftOf(a, b, c)
  local u1 = b[1] - a[1]
  local v1 = b[2] - a[2]
  local u2 = c[1] - a[1]
  local v2 = c[2] - a[2]
  return u1 * v2 - v1 * u2 < 0
end

local function ConvexHull(points)
  if not points or #points == 0 then return end
  if #points <= 2 then return points end

  local lowerLeft = 1
  for i = 2, #points do
    if IsLowerLeft(points[i], points[lowerLeft]) then lowerLeft = i end
  end

  local hull = {}
  local final = 1
  local tries = 0
  repeat
    table.insert(hull, lowerLeft)
    final = 1
    for i = 2, #points do
      if lowerLeft == final or IsLeftOf(points[lowerLeft], points[final], points[i]) then
        final = i
      end
    end
    lowerLeft = final
    tries = tries + 1
  until final == hull[1] or tries > 100

  local result = {}
  for _, index in ipairs(hull) do
    table.insert(result, points[index])
  end
  return result
end

local function ExpandPolygon(points, pointCount)
  local expanded = {}
  local index = 1
  for _, point in ipairs(points or {}) do
    local radius = (point[3] or 1) * 8
    local adjustedPointCount = math.max(6, math.floor(pointCount * (point[3] or 1)))
    for i = 1, adjustedPointCount do
      local angle = 2 * math.pi / adjustedPointCount * i
      expanded[index] = {
        point[1] + radius * math.cos(angle),
        point[2] + radius * math.sin(angle),
        radius,
      }
      index = index + 1
    end
  end
  return expanded
end

local function DrawPullOutline(vertices, r, g, b, scale, active)
  if not db.showPullOutlines then return end
  if not vertices or #vertices == 0 then return end
  local hull = ConvexHull(vertices)
  if not hull then return end
  if #hull > 2 then
    hull = ConvexHull(ExpandPolygon(hull, 16))
  end
  if not hull then return end

  local alpha = active and 0.95 or 0.56
  local thickness = math.max(2, scale * 5)

  if #hull == 1 then
    DrawDot(hull[1][1], hull[1][2], scale, r, g, b, alpha, math.max(12, scale * 28))
    return
  end

  for i = 1, #hull do
    local a = hull[i]
    local bPoint = hull[i == #hull and 1 or i + 1]
    DrawLine(a[1], a[2], bPoint[1], bPoint[2], scale, r, g, b, alpha, thickness)
  end
end

local function LayoutTiles()
  if not canvas or not db then return end
  local viewportWidth = GetViewportWidth()
  local scale = viewportWidth / MAP_WIDTH
  local smallTileSize = (viewportWidth / 4) + (5 * scale)
  local largeTileSize = viewportWidth / 15

  for i = 1, 12 do
    local tile = smallTiles[i]
    tile:ClearAllPoints()
    tile:SetSize(smallTileSize, smallTileSize)
  end

  smallTiles[1]:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
  smallTiles[2]:SetPoint("TOPLEFT", smallTiles[1], "TOPRIGHT", 0, 0)
  smallTiles[3]:SetPoint("TOPLEFT", smallTiles[2], "TOPRIGHT", 0, 0)
  smallTiles[4]:SetPoint("TOPLEFT", smallTiles[3], "TOPRIGHT", 0, 0)
  smallTiles[5]:SetPoint("TOPLEFT", smallTiles[1], "BOTTOMLEFT", 0, 0)
  smallTiles[6]:SetPoint("TOPLEFT", smallTiles[5], "TOPRIGHT", 0, 0)
  smallTiles[7]:SetPoint("TOPLEFT", smallTiles[6], "TOPRIGHT", 0, 0)
  smallTiles[8]:SetPoint("TOPLEFT", smallTiles[7], "TOPRIGHT", 0, 0)
  smallTiles[9]:SetPoint("TOPLEFT", smallTiles[5], "BOTTOMLEFT", 0, 0)
  smallTiles[10]:SetPoint("TOPLEFT", smallTiles[9], "TOPRIGHT", 0, 0)
  smallTiles[11]:SetPoint("TOPLEFT", smallTiles[10], "TOPRIGHT", 0, 0)
  smallTiles[12]:SetPoint("TOPLEFT", smallTiles[11], "TOPRIGHT", 0, 0)

  for row = 1, 10 do
    for col = 1, 15 do
      local tile = largeTiles[row][col]
      tile:ClearAllPoints()
      tile:SetSize(largeTileSize, largeTileSize)
      if row == 1 and col == 1 then
        tile:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
      elseif col == 1 then
        tile:SetPoint("TOPLEFT", largeTiles[row - 1][col], "BOTTOMLEFT", 0, 0)
      else
        tile:SetPoint("TOPLEFT", largeTiles[row][col - 1], "TOPRIGHT", 0, 0)
      end
    end
  end
end

ApplySize = function(width)
  if not frame or not db then return end

  db.width = Clamp(width or db.width, MIN_WIDTH, MAX_WIDTH)
  local viewportWidth = GetViewportWidth()
  local viewportHeight = GetViewportHeight()
  local showArtwork = UseFrameArtwork()
  local sidebarTotalWidth = GetPullSidebarTotalWidth()

  frame:SetSize(db.width + sidebarTotalWidth, showArtwork and (HEADER_HEIGHT + viewportHeight + PADDING) or viewportHeight)
  canvas:SetSize(viewportWidth, viewportHeight)
  ApplyFrameArtwork()
  LayoutTiles()
  RequestRefresh()
  SaveActiveDungeonLayout()
end

local function ShowStatus(message)
  ResetDrawnRoute()
  if UpdatePullSidebar then
    UpdatePullSidebar(nil, nil)
  end
  statusText:SetText(message or "")
  statusText:Show()
end

local function HideStatus()
  statusText:Hide()
end

local function SetTileVisibility(tileFormat)
  local useSmall = tileFormat == 4
  local useLarge = tileFormat == 15

  for i = 1, 12 do
    if useSmall then
      smallTiles[i]:Show()
    else
      smallTiles[i]:Hide()
    end
  end

  for row = 1, 10 do
    for col = 1, 15 do
      if useLarge then
        largeTiles[row][col]:Show()
      else
        largeTiles[row][col]:Hide()
      end
    end
  end
end

local function UpdateMapTextures(mdtDB, preset)
  local MDT = GetMDT()
  if not MDT or not mdtDB or not preset or not preset.value then return false end

  local dungeonIdx = mdtDB.currentDungeonIdx
  local sublevel = preset.value.currentSublevel or 1
  local dungeonMaps = MDT.dungeonMaps and MDT.dungeonMaps[dungeonIdx]
  if not dungeonMaps then return false end

  local textureInfo = dungeonMaps[sublevel]
  if not textureInfo and sublevel ~= 1 then
    sublevel = 1
    textureInfo = dungeonMaps[sublevel]
  end
  if not textureInfo then return false end

  if type(textureInfo) == "string" then
    local mapName = dungeonMaps[0] or ""
    local path = "Interface\\WorldMap\\"..mapName.."\\"
    local tileFormat = 4
    if type(MDT.GetTileFormat) == "function" then
      local ok, result = pcall(MDT.GetTileFormat, MDT, dungeonIdx, sublevel)
      if ok and result then tileFormat = result end
    end

    SetTileVisibility(tileFormat)
    if tileFormat == 4 then
      for i = 1, 12 do
        smallTiles[i]:SetTexture(path..textureInfo..i)
      end
    elseif tileFormat == 15 then
      for row = 1, 10 do
        for col = 1, 15 do
          local suffix = ((row - 1) * 15) + col
          largeTiles[row][col]:SetTexture(path..textureInfo..suffix)
        end
      end
    end
  elseif type(textureInfo) == "table" and textureInfo.customTextures then
    SetTileVisibility(15)
    for row = 1, 10 do
      for col = 1, 15 do
        local suffix = ((row - 1) * 15) + col
        largeTiles[row][col]:SetTexture(textureInfo.customTextures.."\\"..sublevel.."_"..suffix..".png")
      end
    end
  else
    return false
  end

  return true
end

local function SelectionSet(selection)
  local set = {}
  for _, pullIdx in ipairs(selection or {}) do
    if type(pullIdx) == "number" then
      set[pullIdx] = true
    end
  end
  return set
end

local function ShouldDrawPull(pullIdx, selectedSet)
  if db.showAllPulls then return true end
  return selectedSet[pullIdx] == true
end

local function BuildPullVisualData(mdtDB, preset, selectedSet, scale)
  local MDT = GetMDT()
  local centers, pullVertices, clonePullMap = {}, {}, {}
  if not MDT or not mdtDB or not preset or not preset.value then return centers, pullVertices, clonePullMap end

  local pulls = preset.value.pulls
  local enemies = MDT.dungeonEnemies and MDT.dungeonEnemies[mdtDB.currentDungeonIdx]
  local sublevel = preset.value.currentSublevel or 1
  if type(pulls) ~= "table" or type(enemies) ~= "table" then return centers, pullVertices, clonePullMap end

  for pullIdx, pull in ipairs(pulls) do
    if type(pull) == "table" then
      local sumX, sumY, count = 0, 0, 0
      local r, g, b = GetPullColor(pulls, pullIdx)
      pullVertices[pullIdx] = {}

      for enemyIdx, clones in pairs(pull) do
        local numericEnemyIdx = tonumber(enemyIdx)
        local enemy = numericEnemyIdx and enemies[numericEnemyIdx]
        if enemy and type(clones) == "table" and type(enemy.clones) == "table" then
          for _, cloneIdx in pairs(clones) do
            local clone = enemy.clones[cloneIdx]
            if clone and (clone.sublevel == sublevel or clone.sublevel == nil) and clone.x and clone.y then
              sumX = sumX + clone.x
              sumY = sumY + clone.y
              count = count + 1
              table.insert(pullVertices[pullIdx], { clone.x, clone.y, (clone.scale or 1) * (enemy.scale or 1) })
              clonePullMap[numericEnemyIdx..":"..cloneIdx] = {
                pullIdx = pullIdx,
                r = r,
                g = g,
                b = b,
              }
            end
          end
        end
      end

      if count > 0 and ShouldDrawPull(pullIdx, selectedSet) then
        centers[pullIdx] = {
          x = sumX / count,
          y = sumY / count,
          r = r,
          g = g,
          b = b,
        }
      end
    end
  end

  return centers, pullVertices, clonePullMap
end

local function DrawEnemies(mdtDB, preset, selectedSet, scale, clonePullMap)
  local recoveryMode = db and db.recoveryMode == true
  if not db.showEnemies and not db.showEnemyDots and not recoveryMode then return end
  local MDT = GetMDT()
  local enemies = MDT and MDT.dungeonEnemies and MDT.dungeonEnemies[mdtDB.currentDungeonIdx]
  local sublevel = preset.value.currentSublevel or 1
  if type(enemies) ~= "table" then return end

  for enemyIdx, enemy in pairs(enemies) do
    if type(enemy) == "table" and type(enemy.clones) == "table" then
      for cloneIdx, clone in pairs(enemy.clones) do
        if clone and (clone.sublevel == sublevel or clone.sublevel == nil) and clone.x and clone.y then
          local pullInfo = clonePullMap[enemyIdx..":"..cloneIdx]
          local selected = pullInfo and selectedSet[pullInfo.pullIdx] == true
          local showRecoveryMob = recoveryMode and not pullInfo and MDTMiniRouteRecoveryMobVisible(clone)
          if pullInfo or db.showUnpulledEnemies or showRecoveryMob then
            if db.showEnemies then
              DrawEnemyIcon(enemy, clone, scale, pullInfo, selected)
            elseif db.showEnemyDots or showRecoveryMob then
              local r, g, b = 0.75, 0.75, 0.75
              if pullInfo then r, g, b = pullInfo.r, pullInfo.g, pullInfo.b end
              if showRecoveryMob then r, g, b = 0.35, 1, 0.95 end
              DrawDot(clone.x, clone.y, scale, r, g, b, pullInfo and 0.72 or showRecoveryMob and 0.86 or 0.34, pullInfo and 5 or showRecoveryMob and 5 or 3)
            end
            MDTMiniRoutePlaceMobHit(enemyIdx, cloneIdx, enemy, clone, scale, pullInfo)
          end
        end
      end
    end
  end
end

local function DrawPOIs(mdtDB, preset, scale)
  if not db.showPOIs then return end
  local MDT = GetMDT()
  local pois = MDT and MDT.mapPOIs and MDT.mapPOIs[mdtDB.currentDungeonIdx]
  local sublevel = preset.value.currentSublevel or 1
  if type(pois) ~= "table" or type(pois[sublevel]) ~= "table" then return end

  for _, poi in pairs(pois[sublevel]) do
    DrawPOI(poi, scale)
  end
end

local function DrawRoute(mdtDB, preset)
  ResetDrawnRoute()

  if not preset or not preset.value or type(preset.value.pulls) ~= "table" then
    return
  end

  local viewportWidth = GetViewportWidth()
  local scale = viewportWidth / MAP_WIDTH
  local currentPull = GetCurrentPull(preset)
  local selection = GetSelection(preset)
  local selectedSet = SelectionSet(selection)
  local centers, pullVertices, clonePullMap = BuildPullVisualData(mdtDB, preset, selectedSet, scale)
  local previousCenter

  DrawPOIs(mdtDB, preset, scale)

  for pullIdx = 1, #preset.value.pulls do
    local vertices = pullVertices[pullIdx]
    local center = centers[pullIdx]
    if vertices and center and ShouldDrawPull(pullIdx, selectedSet) then
      DrawPullOutline(vertices, center.r, center.g, center.b, scale, pullIdx == currentPull or selectedSet[pullIdx])
      MDTMiniRoutePlacePullHit(pullIdx, vertices, center, scale)
    end
  end

  DrawEnemies(mdtDB, preset, selectedSet, scale, clonePullMap)

  for pullIdx = 1, #preset.value.pulls do
    local center = centers[pullIdx]
    if center then
      if previousCenter and db.showAllPulls and db.showRouteLines then
        DrawLine(previousCenter.x, previousCenter.y, center.x, center.y, scale, 1, 0.88, 0.25, 0.66, math.max(2, scale * 5))
      end
      previousCenter = center
    end
  end

  for pullIdx = 1, #preset.value.pulls do
    local center = centers[pullIdx]
    if center and db.showPullNumbers then
      DrawMarker(center.x, center.y, scale, pullIdx, center.r, center.g, center.b, pullIdx == currentPull, selectedSet[pullIdx])
    end
  end

  HidePool(linePool, usedLines)
  HidePool(markerPool, usedMarkers)
  HidePool(dotPool, usedDots)
  HidePool(enemyPool, usedEnemies)
  HidePool(poiPool, usedPOIs)
end

local function GetDungeonName(mdtDB)
  local MDT = GetMDT()
  if not MDT or not mdtDB then return "MDT Route" end

  if type(MDT.GetDungeonName) == "function" then
    local ok, name = pcall(MDT.GetDungeonName, MDT, mdtDB.currentDungeonIdx, true)
    if ok and name then return name end
  end

  return (MDT.dungeonList and MDT.dungeonList[mdtDB.currentDungeonIdx]) or "MDT Route"
end

local function Refresh()
  if not frame or not frame:IsShown() then return end

  local MDT = GetMDT()
  if not MDT then
    ShowStatus("MDT not loaded")
    return
  end

  local mdtDB = GetMDTDB()
  local preset = GetCurrentPreset()
  if not mdtDB or not preset then
    ShowStatus("No MDT route")
    return
  end

  titleText:SetText(GetDungeonName(mdtDB))
  frame:SetAlpha(1)
  ApplyFrameArtwork()

  if not UpdateMapTextures(mdtDB, preset) then
    ShowStatus("No map")
    return
  end

  ApplyMapAlpha()
  HideStatus()
  DrawRoute(mdtDB, preset)
  UpdatePullSidebar(mdtDB, preset)
  if MDTMiniRouteRefreshRecoveryFrame then
    MDTMiniRouteRefreshRecoveryFrame()
  end
end

local function BuildSignature()
  local mdtDB = GetMDTDB()
  local preset = GetCurrentPreset()
  if not mdtDB or not preset or not preset.value then return "no-route" end

  local selection = GetSelection(preset)
  local selected = {}
  for i, pullIdx in ipairs(selection) do
    selected[i] = tostring(pullIdx)
  end

  return table.concat({
    tostring(mdtDB.currentDungeonIdx),
    tostring(mdtDB.currentPreset and mdtDB.currentPreset[mdtDB.currentDungeonIdx] or ""),
    tostring(preset.uid or ""),
    tostring(preset.value.currentSublevel or ""),
    tostring(preset.value.currentPull or ""),
    tostring(#(preset.value.pulls or {})),
    table.concat(selected, ","),
    tostring(db.showAllPulls),
    tostring(db.showEnemies),
    tostring(db.showUnpulledEnemies),
    tostring(db.showEnemyDots),
    tostring(db.showEnemyPortraits),
    tostring(db.showPOIs),
    tostring(db.showPullOutlines),
    tostring(db.showPullNumbers),
    tostring(db.showRouteLines),
    tostring(db.showFrameArtwork),
    tostring(db.autoSelectPull),
    tostring(db.autoPullUseProximity),
    tostring(db.autoPullProximityRadius),
    tostring(db.autoPullDriftWatcher),
    tostring(db.autoPullDriftThreshold),
    tostring(db.autoPullAnchorActive),
    tostring(db.autoPullAnchorPull),
    tostring(db.recoveryMode),
    tostring(db.showRecoveryButton),
    tostring(db.recoveryButtonMouseoverOnly),
    tostring(db.recoveryButtonBorderStyle),
    tostring(db.recoveryButtonBorderSize),
    tostring((db.recoveryButtonBorderColor or {})[1]),
    tostring((db.recoveryButtonBorderColor or {})[2]),
    tostring((db.recoveryButtonBorderColor or {})[3]),
    tostring(db.onlyShowInMatchingDungeon),
    tostring(db.showPullSidebar),
    tostring(db.showPullPercent),
    tostring(db.pullSidebarOnLeft),
    tostring(db.pullSidebarDetached),
    tostring(db.pullSidebarLocked),
    tostring(db.pullSidebarWidth),
    tostring(db.pullSidebarHeight),
    tostring(db.pullSidebarScale),
    tostring(db.sidebarFont),
    tostring(db.sidebarFontSize),
    tostring(db.sidebarFontOutline),
    tostring(db.sidebarFontShadow),
    tostring(db.mapFont),
    tostring(db.mapFontSize),
    tostring(db.mapFontOutline),
    tostring(db.mapFontShadow),
    tostring(db.alpha),
    tostring(db.iconAlpha),
    tostring(activeLayoutDungeonIdx),
    tostring(select(2, IsInMatchingDungeon())),
    tostring(db.width),
  }, ":")
end

RefreshIfNeeded = function(force)
  if not frame or not frame:IsShown() then return end
  local signature = BuildSignature()
  if force or dirty or signature ~= lastSignature then
    dirty = false
    lastSignature = signature
    Refresh()
  end
end

local function HookMDT()
  -- Keep Mini Route passive toward MDT's own UI/bootstrap path. Polling via
  -- BuildSignature/OnUpdate is enough for the overlay and avoids blocking /mdt.
  return
end

local function HookMDTDisabled()
  if hooksInstalled then return end
  local MDT = GetMDT()
  if not MDT then return end

  local hookNames = {
    "UpdateMap",
    "UpdateToDungeon",
    "SetSelectionToPull",
    "ColorPull",
    "ColorAllPulls",
    "PresetsAddPull",
    "PresetsMergePulls",
    "PresetsDeletePull",
    "PresetsSwapPulls",
    "AddPull",
    "ClearPull",
    "MovePullUp",
    "MovePullDown",
    "DeletePull",
    "ImportPreset",
    "ReturnToLivePreset",
    "SetLivePreset",
    "DungeonEnemies_AddOrRemoveBlipToCurrentPull",
  }

  for _, name in ipairs(hookNames) do
    if type(MDT[name]) == "function" then
      pcall(hooksecurefunc, MDT, name, RequestRefresh)
    end
  end

  hooksInstalled = true
end

local nativeControlIndex = 0

local function NextControlName(prefix)
  nativeControlIndex = nativeControlIndex + 1
  return "MDTMiniRoute"..prefix..nativeControlIndex
end

local function ControlText(control)
  return control.Text or (control.GetName and _G[control:GetName().."Text"])
end

local function SetControlText(control, text)
  local fontString = ControlText(control)
  if fontString then
    fontString:SetText(text)
  end
end

local function SaveSettingsPosition()
  if not settingsFrame or not db then return end

  local point, _, relativePoint, x, y = settingsFrame:GetPoint(1)
  db.settingsPoint = point or DEFAULTS.settingsPoint
  db.settingsRelativePoint = relativePoint or DEFAULTS.settingsRelativePoint
  db.settingsX = x or DEFAULTS.settingsX
  db.settingsY = y or DEFAULTS.settingsY
end

local function SetBooleanOption(key, value, silent)
  if not db then return end

  db[key] = value == true
  if key == "shown" then
    UpdateOverlayVisibility(true)
  elseif key == "locked" then
    if SetLocked then
      SetLocked(db.locked, silent)
    end
  elseif key == "showOnMouseoverOnly" or key == "onlyShowOutOfCombat" then
    UpdateOverlayVisibility(true)
  elseif key == "showRecoveryButton" or key == "recoveryButtonMouseoverOnly" then
    if MDTMiniRouteApplyRecoveryButtonAppearance then
      MDTMiniRouteApplyRecoveryButtonAppearance()
    end
  elseif key == "autoSelectPull" then
    db.autoPullTrashOffset = 0
    db.autoPullBossOffset = 0
    UpdateAutoPullFromProgress(true)
    RequestRefresh()
    RefreshIfNeeded(true)
  elseif key == "autoPullUseProximity" then
    UpdateAutoPullFromProgress(true)
    RequestRefresh()
    RefreshIfNeeded(true)
  elseif key == "onlyShowInMatchingDungeon" then
    if not db.onlyShowInMatchingDungeon then
      SaveDungeonLayout(activeLayoutDungeonIdx)
      activeLayoutDungeonIdx = nil
    end
    UpdateOverlayVisibility(true)
  elseif key == "showFrameArtwork" or key == "showPullSidebar" or key == "showPullPercent" or key == "pullSidebarOnLeft" or key == "pullSidebarDetached" then
    ApplySize(db.width)
    RefreshIfNeeded(true)
  elseif key == "pullSidebarLocked" then
    SaveActiveDungeonLayout()
  elseif key == "showAllPulls" then
    UpdatePullSidebarHeader()
    RequestRefresh()
    RefreshIfNeeded(true)
  else
    RequestRefresh()
    RefreshIfNeeded(true)
  end
end

local function UpdateSettingsControlVisibility()
  if not settingsControls.checks then return end

  local sidebarLockCheck = settingsControls.checks.pullSidebarLocked
  if sidebarLockCheck then
    if db and db.pullSidebarDetached then
      sidebarLockCheck:Show()
    else
      sidebarLockCheck:Hide()
    end
  end

  local unpulledDotsCheck = settingsControls.checks.showUnpulledEnemies
  if unpulledDotsCheck then
    if db and db.showEnemyDots then
      unpulledDotsCheck:Show()
    else
      unpulledDotsCheck:Hide()
    end
  end

  local proximityCheck = settingsControls.checks.autoPullUseProximity
  if proximityCheck then
    if db and db.autoSelectPull then
      proximityCheck:Show()
    else
      proximityCheck:Hide()
    end
  end
end

RefreshSettingsWindow = function()
  if not settingsFrame or not db then return end

  settingsUpdating = true
  if settingsControls.checks then
    for key, check in pairs(settingsControls.checks) do
      check:SetChecked(db[key] == true)
    end
  end
  if settingsControls.widthSlider then
    settingsControls.widthSlider:SetValue(db.width or DEFAULTS.width)
  end
  if settingsControls.alphaSlider then
    settingsControls.alphaSlider:SetValue(db.alpha or DEFAULTS.alpha)
  end
  if settingsControls.iconAlphaSlider then
    settingsControls.iconAlphaSlider:SetValue(db.iconAlpha or DEFAULTS.iconAlpha)
  end
  if settingsControls.recoveryBorderSizeSlider then
    settingsControls.recoveryBorderSizeSlider:SetValue(db.recoveryButtonBorderSize or DEFAULTS.recoveryButtonBorderSize)
  end
  if settingsControls.sidebarWidthSlider then
    settingsControls.sidebarWidthSlider:SetValue(db.pullSidebarWidth or DEFAULTS.pullSidebarWidth)
  end
  if settingsControls.sidebarHeightSlider then
    settingsControls.sidebarHeightSlider:SetValue((db.pullSidebarHeight and db.pullSidebarHeight > 0) and db.pullSidebarHeight or SIDEBAR_DEFAULT_HEIGHT)
  end
  if settingsControls.sidebarScaleSlider then
    settingsControls.sidebarScaleSlider:SetValue(db.pullSidebarScale or DEFAULTS.pullSidebarScale)
  end
  if UpdatePullSidebarHeader then
    UpdatePullSidebarHeader()
  end
  if settingsControls.recoveryBorderButton then
    settingsControls.recoveryBorderButton:SetText("Border: "..MDTMiniRouteRecoveryBorderLabel(db.recoveryButtonBorderStyle))
  end
  if settingsControls.recoveryColorButton then
    local r, g, b = MDTMiniRouteGetRecoveryBorderColor()
    settingsControls.recoveryColorButton:SetText("Border Color")
    if settingsControls.recoveryColorSwatch then
      settingsControls.recoveryColorSwatch:SetColorTexture(r, g, b, 1)
    end
  end
  UpdateFontSettingControls()
  UpdateSettingsControlVisibility()
  settingsUpdating = false
end

local function MakeNativeCheck(parent, label, key, x, y)
  settingsControls.checks = settingsControls.checks or {}

  local check = CreateFrame("CheckButton", NextControlName("Check"), parent, "UICheckButtonTemplate")
  check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  SetControlText(check, label)
  check:SetScript("OnClick", function(button)
    if settingsUpdating then return end
    SetBooleanOption(key, button:GetChecked() == true, true)
    RefreshSettingsWindow()
  end)
  settingsControls.checks[key] = check
  return check
end

local function MakeNativeButton(parent, text, x, y, width, callback)
  local button = CreateFrame("Button", NextControlName("Button"), parent, "UIPanelButtonTemplate")
  button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  button:SetSize(width or 120, 24)
  button:SetText(text)
  button:SetScript("OnClick", callback)
  return button
end

local function ShortText(text, maxLength)
  text = tostring(text or "")
  if #text <= maxLength then return text end
  return text:sub(1, maxLength - 3).."..."
end

local function SetFontSetting(prefix, key, value)
  if not db then return end

  db[prefix..key] = value
  RequestRefresh()
  RefreshIfNeeded(true)
  RefreshSettingsWindow()
end

local function AdjustFontSize(prefix, delta)
  if not db then return end

  local key = prefix.."FontSize"
  db[key] = Clamp((db[key] or DEFAULTS[key]) + delta, FONT_SIZE_MIN, FONT_SIZE_MAX)
  RequestRefresh()
  RefreshIfNeeded(true)
  RefreshSettingsWindow()
end

UpdateFontSettingControls = function()
  if not db then return end

  local fontButtons = settingsControls.fontButtons
  if fontButtons then
    if fontButtons.sidebar then
      fontButtons.sidebar:SetText("Font: "..ShortText(FontLabel(db.sidebarFont), 16))
    end
    if fontButtons.map then
      fontButtons.map:SetText("Font: "..ShortText(FontLabel(db.mapFont), 16))
    end
  end

  local outlineButtons = settingsControls.outlineButtons
  if outlineButtons then
    if outlineButtons.sidebar then
      outlineButtons.sidebar:SetText("Outline: "..OutlineLabel(db.sidebarFontOutline))
    end
    if outlineButtons.map then
      outlineButtons.map:SetText("Outline: "..OutlineLabel(db.mapFontOutline))
    end
  end

  local sizeTexts = settingsControls.fontSizeTexts
  if sizeTexts then
    if sizeTexts.sidebar then
      sizeTexts.sidebar:SetText("Size: "..tostring(math.floor((db.sidebarFontSize or DEFAULTS.sidebarFontSize) + 0.5)))
    end
    if sizeTexts.map then
      sizeTexts.map:SetText("Size: "..tostring(math.floor((db.mapFontSize or DEFAULTS.mapFontSize) + 0.5)))
    end
  end
end

local function ShowPickerMenu(anchor, values, currentValue, onPick)
  if not pickerMenuFrame then
    pickerMenuFrame = CreateFrame("Frame", "MDTMiniRoutePickerMenu", UIParent, "UIDropDownMenuTemplate")
  end

  local menu = {}
  for _, value in ipairs(values) do
    local text = type(value) == "table" and value.text or value
    local storedValue = type(value) == "table" and value.value or value
    menu[#menu + 1] = {
      text = text,
      checked = storedValue == currentValue,
      isNotRadio = false,
      func = function()
        onPick(storedValue)
      end,
    }
  end

  if EasyMenu then
    EasyMenu(menu, pickerMenuFrame, anchor or "cursor", 0, 0, "MENU", 2)
  elseif values[1] then
    local first = type(values[1]) == "table" and values[1].value or values[1]
    onPick(first)
  end
end

local function ShowFontPicker(anchor, prefix)
  ShowPickerMenu(anchor, GetFontChoices(), NormalizeFontName(db[prefix.."Font"]), function(value)
    SetFontSetting(prefix, "Font", NormalizeFontName(value))
  end)
end

local function CycleOutline(prefix)
  local current = NormalizeOutline(db[prefix.."FontOutline"])
  local nextOutline = "OUTLINE"

  if current == "OUTLINE" then
    nextOutline = "THICKOUTLINE"
  elseif current == "THICKOUTLINE" then
    nextOutline = "NONE"
  end

  SetFontSetting(prefix, "FontOutline", nextOutline)
end

local function MakeFontControls(parent, title, prefix, x, y)
  settingsControls.fontButtons = settingsControls.fontButtons or {}
  settingsControls.outlineButtons = settingsControls.outlineButtons or {}
  settingsControls.fontSizeTexts = settingsControls.fontSizeTexts or {}

  local section = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  section:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  section:SetText(title)

  settingsControls.fontButtons[prefix] = MakeNativeButton(parent, "", x, y - 22, 150, function(button)
    ShowFontPicker(button, prefix)
  end)
  settingsControls.outlineButtons[prefix] = MakeNativeButton(parent, "", x + 156, y - 22, 106, function()
    CycleOutline(prefix)
  end)
  MakeNativeCheck(parent, "Shadow", prefix.."FontShadow", x + 266, y - 23)

  MakeNativeButton(parent, "-", x, y - 52, 28, function()
    AdjustFontSize(prefix, -1)
  end)

  local sizeText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sizeText:SetPoint("LEFT", parent, "TOPLEFT", x + 38, y - 64)
  sizeText:SetWidth(68)
  sizeText:SetJustifyH("LEFT")
  settingsControls.fontSizeTexts[prefix] = sizeText

  MakeNativeButton(parent, "+", x + 110, y - 52, 28, function()
    AdjustFontSize(prefix, 1)
  end)
end

local function FormatSliderValue(value, step)
  if step and step < 1 then
    return string.format("%.2f", value)
  end
  return tostring(math.floor((value or 0) + 0.5))
end

local function MakeNativeSlider(parent, label, minValue, maxValue, step, x, y, callback)
  local slider = CreateFrame("Slider", NextControlName("Slider"), parent, "OptionsSliderTemplate")
  slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  slider:SetWidth(230)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(step)
  if slider.SetObeyStepOnDrag then
    slider:SetObeyStepOnDrag(true)
  end

  local name = slider:GetName()
  _G[name.."Text"]:SetText(label)
  _G[name.."Low"]:SetText(tostring(minValue))
  _G[name.."High"]:SetText(tostring(maxValue))

  slider.valueText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  slider.valueText:SetPoint("LEFT", slider, "RIGHT", 12, 0)

  slider:SetScript("OnValueChanged", function(control, value)
    if step >= 1 then
      value = math.floor(value + 0.5)
    end
    control.valueText:SetText(FormatSliderValue(value, step))
    if settingsUpdating then return end
    callback(value)
    RefreshSettingsWindow()
  end)

  return slider
end

SelectPull = function(pullIdx)
  pullIdx = tonumber(pullIdx)
  if not pullIdx then return end

  local MDT = GetMDT()
  local preset = GetCurrentPreset()
  if not preset or not preset.value or not preset.value.pulls or not preset.value.pulls[pullIdx] then return end

  local ok
  if MDT and type(MDT.SetSelectionToPull) == "function" then
    ok = pcall(MDT.SetSelectionToPull, MDT, pullIdx)
  end
  if not ok then
    preset.value.currentPull = pullIdx
    preset.value.selection = { pullIdx }
  end
  if db.autoSelectPull and UpdateAutoPullFromProgress then
    UpdateAutoPullFromProgress(false, pullIdx)
  end

  db.showAllPulls = false
  RequestRefresh()
  RefreshIfNeeded(true)
  RefreshSettingsWindow()
end

function MDTMiniRouteShowSettingsTab(tabName)
  if not settingsControls.pages then return end
  tabName = tabName or settingsControls.activeTab or "General"
  settingsControls.activeTab = tabName

  for name, page in pairs(settingsControls.pages) do
    if name == tabName then
      page:Show()
    else
      page:Hide()
    end
  end

  if settingsControls.tabs then
    for name, tab in pairs(settingsControls.tabs) do
      tab:SetEnabled(name ~= tabName)
    end
  end
end

local function CreateSettingsWindow()
  if settingsFrame then return end

  settingsFrame = CreateFrame("Frame", "MDTMiniRouteSettingsFrame", UIParent, "BackdropTemplate")
  settingsFrame:SetFrameStrata("DIALOG")
  settingsFrame:SetClampedToScreen(true)
  settingsFrame:SetMovable(true)
  settingsFrame:EnableMouse(true)
  settingsFrame:RegisterForDrag("LeftButton")
  settingsFrame:SetSize(430, 500)
  settingsFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  settingsFrame:SetBackdropColor(0.02, 0.025, 0.03, 0.97)
  settingsFrame:SetBackdropBorderColor(0.85, 0.68, 0.28, 0.95)
  settingsFrame:SetPoint(db.settingsPoint or DEFAULTS.settingsPoint, UIParent, db.settingsRelativePoint or DEFAULTS.settingsRelativePoint, db.settingsX or DEFAULTS.settingsX, db.settingsY or DEFAULTS.settingsY)
  settingsFrame:Hide()

  settingsFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  settingsFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveSettingsPosition()
  end)

  local header = settingsFrame:CreateTexture(nil, "BACKGROUND")
  header:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 8, -7)
  header:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -8, -7)
  header:SetHeight(30)
  header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  header:SetTexCoord(0.22, 0.78, 0, 0.72)

  local title = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 16, -15)
  title:SetText("Mini Route Options")

  local close = CreateFrame("Button", nil, settingsFrame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function()
    settingsOpenedWithMDT = false
    settingsFrame:Hide()
  end)

  settingsControls.pages = {}
  settingsControls.tabs = {}

  local tabNames = { "General", "Map", "Sidebar", "Recovery", "Fonts" }
  for i, tabName in ipairs(tabNames) do
    local tab = CreateFrame("Button", nil, settingsFrame, "UIPanelButtonTemplate")
    tab:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 14 + ((i - 1) * 80), -42)
    tab:SetSize(76, 22)
    tab:SetText(tabName)
    tab:SetScript("OnClick", function()
      MDTMiniRouteShowSettingsTab(tabName)
    end)
    settingsControls.tabs[tabName] = tab

    local page = CreateFrame("Frame", nil, settingsFrame)
    page:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 14, -74)
    page:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -14, 44)
    page:Hide()
    settingsControls.pages[tabName] = page
  end

  local general = settingsControls.pages.General
  local map = settingsControls.pages.Map
  local sidebar = settingsControls.pages.Sidebar
  local recovery = settingsControls.pages.Recovery
  local fonts = settingsControls.pages.Fonts

  MakeNativeCheck(general, "Show mini route overlay", "shown", 4, -4)
  MakeNativeCheck(general, "Lock overlay position", "locked", 4, -30)
  MakeNativeCheck(general, "Only show on mouseover", "showOnMouseoverOnly", 4, -56)
  MakeNativeCheck(general, "Only show outside combat", "onlyShowOutOfCombat", 4, -82)
  MakeNativeCheck(general, "Only show in matching dungeon", "onlyShowInMatchingDungeon", 4, -108)
  MakeNativeCheck(general, "Auto-select pull from progress", "autoSelectPull", 4, -148)
  MakeNativeCheck(general, "Use tank proximity for auto-pull", "autoPullUseProximity", 24, -174)
  MakeNativeButton(general, "Reset Position", 4, -226, 126, function()
    ResetPosition()
    RequestRefresh()
    RefreshIfNeeded(true)
    RefreshSettingsWindow()
  end)

  MakeNativeCheck(map, "Show frame and title", "showFrameArtwork", 4, -4)
  MakeNativeCheck(map, "Show pull numbers on map", "showPullNumbers", 4, -30)
  MakeNativeCheck(map, "Show MDT-style pull outlines", "showPullOutlines", 4, -56)
  MakeNativeCheck(map, "Show route connection lines", "showRouteLines", 4, -82)
  MakeNativeCheck(map, "Show mob dots on map", "showEnemyDots", 4, -108)
  MakeNativeCheck(map, "Include unpulled mob dots", "showUnpulledEnemies", 24, -134)

  settingsControls.widthSlider = MakeNativeSlider(map, "Overlay width", MIN_WIDTH, MAX_WIDTH, 1, 16, -188, function(value)
    ApplySize(value)
    SavePosition()
    RequestRefresh()
    RefreshIfNeeded(true)
  end)
  settingsControls.alphaSlider = MakeNativeSlider(map, "Map alpha", 0.2, 1, 0.05, 16, -244, function(value)
    db.alpha = Clamp(value, 0.2, 1)
    ApplyMapAlpha()
    SaveActiveDungeonLayout()
  end)
  settingsControls.iconAlphaSlider = MakeNativeSlider(map, "Icon alpha", 0.2, 1, 0.05, 16, -300, function(value)
    db.iconAlpha = Clamp(value, 0.2, 1)
    SaveActiveDungeonLayout()
    RequestRefresh()
    RefreshIfNeeded(true)
  end)

  MakeNativeCheck(sidebar, "Show pull sidebar", "showPullSidebar", 4, -4)
  MakeNativeCheck(sidebar, "Sidebar on left", "pullSidebarOnLeft", 4, -30)
  MakeNativeCheck(sidebar, "Detach sidebar", "pullSidebarDetached", 4, -56)
  MakeNativeCheck(sidebar, "Lock detached sidebar", "pullSidebarLocked", 24, -82)
  MakeNativeCheck(sidebar, "Show pull percentages", "showPullPercent", 4, -122)
  MakeNativeCheck(sidebar, "Show all pulls", "showAllPulls", 4, -148)

  settingsControls.sidebarWidthSlider = MakeNativeSlider(sidebar, "Sidebar width", SIDEBAR_MIN_WIDTH, SIDEBAR_MAX_WIDTH, 1, 16, -202, function(value)
    db.pullSidebarWidth = Clamp(value, SIDEBAR_MIN_WIDTH, SIDEBAR_MAX_WIDTH)
    ApplySize(db.width)
    RefreshIfNeeded(true)
  end)
  settingsControls.sidebarHeightSlider = MakeNativeSlider(sidebar, "Sidebar length", SIDEBAR_MIN_HEIGHT, SIDEBAR_MAX_HEIGHT, 1, 16, -258, function(value)
    db.pullSidebarHeight = Clamp(value, SIDEBAR_MIN_HEIGHT, SIDEBAR_MAX_HEIGHT)
    ApplySize(db.width)
    RefreshIfNeeded(true)
  end)
  settingsControls.sidebarScaleSlider = MakeNativeSlider(sidebar, "Sidebar scale", SIDEBAR_MIN_SCALE, SIDEBAR_MAX_SCALE, 0.05, 16, -314, function(value)
    db.pullSidebarScale = Clamp(value, SIDEBAR_MIN_SCALE, SIDEBAR_MAX_SCALE)
    ApplySize(db.width)
    RefreshIfNeeded(true)
  end)

  MakeNativeCheck(recovery, "Show recovery button", "showRecoveryButton", 4, -4)
  MakeNativeCheck(recovery, "Only show recovery button on mouseover", "recoveryButtonMouseoverOnly", 4, -30)
  settingsControls.recoveryBorderButton = MakeNativeButton(recovery, "", 4, -72, 150, MDTMiniRouteCycleRecoveryBorderStyle)
  settingsControls.recoveryColorButton = MakeNativeButton(recovery, "Border Color", 4, -104, 150, MDTMiniRouteOpenRecoveryBorderColorPicker)
  settingsControls.recoveryColorSwatch = recovery:CreateTexture(nil, "ARTWORK")
  settingsControls.recoveryColorSwatch:SetPoint("LEFT", settingsControls.recoveryColorButton, "RIGHT", 10, 0)
  settingsControls.recoveryColorSwatch:SetSize(18, 18)
  settingsControls.recoveryColorSwatch:SetColorTexture(0.15, 0.85, 1, 1)
  settingsControls.recoveryBorderSizeSlider = MakeNativeSlider(recovery, "Border size", 0, 10, 1, 16, -158, function(value)
    db.recoveryButtonBorderSize = Clamp(value, 0, 10)
    MDTMiniRouteApplyRecoveryButtonAppearance()
  end)
  MakeNativeButton(recovery, "Open Recovery Panel", 4, -224, 160, MDTMiniRouteToggleRecoveryFrame)
  MakeNativeButton(recovery, "Suggest Recovery", 172, -224, 150, function()
    if MDTMiniRouteSuggestRecovery then MDTMiniRouteSuggestRecovery() end
  end)
  MakeNativeButton(recovery, "Undo", 4, -256, 70, MDTMiniRouteUndoRecovery)
  MakeNativeButton(recovery, "Redo", 82, -256, 70, MDTMiniRouteRedoRecovery)
  MakeNativeButton(recovery, "Revert", 160, -256, 86, MDTMiniRouteRevertRecovery)

  MakeFontControls(fonts, "Sidebar font", "sidebar", 4, -4)
  MakeFontControls(fonts, "Minimap font", "map", 4, -112)

  MDTMiniRouteShowSettingsTab(settingsControls.activeTab or "General")
end

ShowSettingsWindow = function(autoOpened)
  if not db then return end

  CreateSettingsWindow()
  RefreshSettingsWindow()
  if not settingsFrame:IsShown() then
    settingsOpenedWithMDT = autoOpened == true
  elseif not autoOpened then
    settingsOpenedWithMDT = false
  end
  settingsFrame:Show()
end

local function ToggleMenuOption(key)
  SetBooleanOption(key, not db[key], false)
  RefreshSettingsWindow()
end

ShowContextMenu = function(anchor)
  if not db then return end

  if not contextMenuFrame then
    contextMenuFrame = CreateFrame("Frame", "MDTMiniRouteContextMenu", UIParent, "UIDropDownMenuTemplate")
  end

  local menu = {
    { text = TITLE, isTitle = true, notCheckable = true },
    { text = "Options", notCheckable = true, func = function() ShowSettingsWindow(false) end },
    { text = db.shown and "Hide overlay" or "Show overlay", notCheckable = true, func = ToggleShown },
    { text = db.locked and "Unlock overlay" or "Lock overlay", notCheckable = true, func = function() SetLocked(not db.locked) RefreshSettingsWindow() end },
    { text = "Only show on mouseover", checked = db.showOnMouseoverOnly, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("showOnMouseoverOnly") end },
    { text = "Only show outside combat", checked = db.onlyShowOutOfCombat, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("onlyShowOutOfCombat") end },
    { text = "Auto-select pull from progress", checked = db.autoSelectPull, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("autoSelectPull") end },
    { text = "Use tank proximity for auto-pull", checked = db.autoPullUseProximity, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("autoPullUseProximity") end },
    { text = "Only show in matching dungeon", checked = db.onlyShowInMatchingDungeon, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("onlyShowInMatchingDungeon") end },
    { text = "Show frame and title", checked = db.showFrameArtwork, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("showFrameArtwork") end },
    { text = "Show pull sidebar", checked = db.showPullSidebar, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("showPullSidebar") end },
    { text = "Sidebar on left", checked = db.pullSidebarOnLeft, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("pullSidebarOnLeft") end },
    { text = "Detach sidebar", checked = db.pullSidebarDetached, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("pullSidebarDetached") end },
    { text = "Show pull percentages", checked = db.showPullPercent, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("showPullPercent") end },
    { text = "Show all pulls", checked = db.showAllPulls, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("showAllPulls") end },
    { text = "Show pull numbers", checked = db.showPullNumbers, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("showPullNumbers") end },
    { text = "Show pull outlines", checked = db.showPullOutlines, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("showPullOutlines") end },
    { text = "Show route lines", checked = db.showRouteLines, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("showRouteLines") end },
    { text = "Show mob dots on map", checked = db.showEnemyDots, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("showEnemyDots") end },
    { text = "Include unpulled mob dots", checked = db.showUnpulledEnemies, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("showUnpulledEnemies") end },
    { text = "Reset position", notCheckable = true, func = function() ResetPosition() RequestRefresh() RefreshIfNeeded(true) RefreshSettingsWindow() end },
  }

  if db.pullSidebarDetached then
    table.insert(menu, 14, { text = "Lock detached sidebar", checked = db.pullSidebarLocked, isNotRadio = true, keepShownOnClick = true, func = function() ToggleMenuOption("pullSidebarLocked") end })
  end

  if EasyMenu then
    EasyMenu(menu, contextMenuFrame, anchor or "cursor", 0, 0, "MENU", 2)
  else
    ShowSettingsWindow(false)
  end
end

local function CreateMDTMonitor()
  if monitorFrame then return end

  lastMDTShown = false
  monitorFrame = CreateFrame("Frame")
  monitorFrame:SetScript("OnUpdate", function(_, elapsed)
    if not db then return end

    monitorElapsed = monitorElapsed + elapsed
    if monitorElapsed < 0.25 then return end
    monitorElapsed = 0

    UpdateOverlayVisibility(false)
    UpdateAutoPullFromProgress(false)

    local MDT = GetMDT()
    local mdtShown = MDT and MDT.main_frame and MDT.main_frame:IsShown() == true
    if mdtShown and not lastMDTShown then
      ShowSettingsWindow(true)
    elseif not mdtShown and lastMDTShown and settingsOpenedWithMDT and settingsFrame then
      settingsFrame:Hide()
      settingsOpenedWithMDT = false
    end
    lastMDTShown = mdtShown
  end)
end

ResetPosition = function()
  if not frame or not db then return end
  db.point = DEFAULTS.point
  db.relativePoint = DEFAULTS.relativePoint
  db.x = DEFAULTS.x
  db.y = DEFAULTS.y
  db.width = DEFAULTS.width
  db.pullSidebarWidth = DEFAULTS.pullSidebarWidth
  db.pullSidebarHeight = DEFAULTS.pullSidebarHeight
  db.pullSidebarScale = DEFAULTS.pullSidebarScale
  db.pullSidebarLocked = DEFAULTS.pullSidebarLocked
  db.pullSidebarPoint = DEFAULTS.pullSidebarPoint
  db.pullSidebarRelativePoint = DEFAULTS.pullSidebarRelativePoint
  db.pullSidebarX = DEFAULTS.pullSidebarX
  db.pullSidebarY = DEFAULTS.pullSidebarY
  frame:ClearAllPoints()
  frame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
  ApplySize(db.width)
end

ToggleShown = function()
  db.shown = not db.shown
  UpdateOverlayVisibility(true)
  Print(db.shown and "shown" or "hidden")
end

SetLocked = function(locked, silent)
  db.locked = locked
  if db.locked then
    frame:SetMovable(false)
  else
    frame:SetMovable(true)
  end
  if not silent then
    Print(db.locked and "locked" or "unlocked")
  end
end

local function HandleSlash(input)
  input = (input or ""):lower()
  local command, rest = input:match("^(%S*)%s*(.-)$")

  if command == "" or command == "toggle" then
    ToggleShown()
  elseif command == "options" or command == "settings" or command == "config" then
    ShowSettingsWindow(false)
  elseif command == "show" then
    db.shown = true
    UpdateOverlayVisibility(true)
  elseif command == "hide" then
    db.shown = false
    UpdateOverlayVisibility(false)
  elseif command == "lock" then
    SetLocked(true)
  elseif command == "unlock" then
    SetLocked(false)
  elseif command == "pull" then
    local pullIdx = tonumber(rest)
    if pullIdx then
      SelectPull(pullIdx)
    else
      Print("usage: /mdtmini pull 3")
    end
  elseif command == "all" then
    db.showAllPulls = not db.showAllPulls
    Print(db.showAllPulls and "showing all pulls" or "showing selected pull only")
    UpdatePullSidebarHeader()
    RefreshIfNeeded(true)
  elseif command == "enemies" then
    db.showEnemies = false
    Print("enemy icons are disabled in this build")
    RefreshIfNeeded(true)
  elseif command == "unpulled" then
    SetBooleanOption("showUnpulledEnemies", not db.showUnpulledEnemies, false)
    Print(db.showUnpulledEnemies and "including unpulled mob dots" or "showing pulled mob dots only")
    RefreshSettingsWindow()
  elseif command == "dots" then
    SetBooleanOption("showEnemyDots", not db.showEnemyDots, false)
    Print(db.showEnemyDots and "mob dots shown on map" or "mob dots hidden")
    RefreshSettingsWindow()
  elseif command == "pois" then
    db.showPOIs = false
    Print("POIs are disabled in this build")
    RefreshIfNeeded(true)
  elseif command == "outlines" then
    db.showPullOutlines = not db.showPullOutlines
    Print(db.showPullOutlines and "pull outlines on" or "pull outlines off")
    RefreshIfNeeded(true)
  elseif command == "lines" then
    db.showRouteLines = not db.showRouteLines
    Print(db.showRouteLines and "route lines on" or "route lines off")
    RefreshIfNeeded(true)
  elseif command == "numbers" then
    db.showPullNumbers = not db.showPullNumbers
    Print(db.showPullNumbers and "pull numbers on" or "pull numbers off")
    RefreshIfNeeded(true)
  elseif command == "frame" or command == "chrome" then
    SetBooleanOption("showFrameArtwork", not db.showFrameArtwork, false)
    RefreshSettingsWindow()
    Print(db.showFrameArtwork and "frame and title shown" or "frame and title hidden")
  elseif command == "dungeon" or command == "dungeononly" then
    SetBooleanOption("onlyShowInMatchingDungeon", not db.onlyShowInMatchingDungeon, false)
    RefreshSettingsWindow()
    Print(db.onlyShowInMatchingDungeon and "only showing in matching dungeon" or "showing outside dungeons too")
  elseif command == "mouseover" or command == "hover" then
    SetBooleanOption("showOnMouseoverOnly", not db.showOnMouseoverOnly, false)
    RefreshSettingsWindow()
    Print(db.showOnMouseoverOnly and "only showing on mouseover" or "mouseover-only disabled")
  elseif command == "combat" or command == "outofcombat" then
    SetBooleanOption("onlyShowOutOfCombat", not db.onlyShowOutOfCombat, false)
    RefreshSettingsWindow()
    Print(db.onlyShowOutOfCombat and "hidden in combat" or "combat visibility disabled")
  elseif command == "autopull" or command == "progress" then
    SetBooleanOption("autoSelectPull", not db.autoSelectPull, false)
    RefreshSettingsWindow()
    Print(db.autoSelectPull and "auto-selecting pull from dungeon progress" or "auto pull selection disabled")
  elseif command == "proximity" or command == "prox" then
    SetBooleanOption("autoPullUseProximity", not db.autoPullUseProximity, false)
    RefreshSettingsWindow()
    Print(db.autoPullUseProximity and "tank proximity auto-pull on" or "tank proximity auto-pull off")
  elseif command == "proxradius" or command == "proximityradius" then
    local radius = tonumber(rest)
    if radius then
      db.autoPullProximityRadius = Clamp(radius, 25, 240)
      UpdateAutoPullFromProgress(true)
      RequestRefresh()
      RefreshIfNeeded(true)
      Print("proximity radius "..db.autoPullProximityRadius)
    else
      Print("usage: /mdtmini proxradius 85")
    end
  elseif command == "drift" or command == "driftwatcher" then
    local threshold = tonumber(rest)
    if threshold then
      db.autoPullDriftThreshold = Clamp(threshold, 1, 25)
      db.autoPullDriftWatcher = true
      Print("route drift watcher threshold "..db.autoPullDriftThreshold.."%")
    else
      SetBooleanOption("autoPullDriftWatcher", db.autoPullDriftWatcher == false, false)
      Print(db.autoPullDriftWatcher and "route drift watcher on" or "route drift watcher off")
    end
  elseif command == "recovery" or command == "recoverpanel" then
    MDTMiniRouteToggleRecoveryFrame()
  elseif command == "recoverymode" then
    MDTMiniRouteSetRecoveryMode(not (db and db.recoveryMode == true))
  elseif command == "recover" or command == "suggest" then
    if MDTMiniRouteSuggestRecovery then
      MDTMiniRouteSuggestRecovery()
    end
  elseif command == "revert" then
    MDTMiniRouteRevertRecovery()
  elseif command == "undo" then
    MDTMiniRouteUndoRecovery()
  elseif command == "redo" then
    MDTMiniRouteRedoRecovery()
  elseif command == "sidebar" then
    SetBooleanOption("showPullSidebar", not db.showPullSidebar, false)
    RefreshSettingsWindow()
    Print(db.showPullSidebar and "pull sidebar shown" or "pull sidebar hidden")
  elseif command == "sidebarside" or command == "side" then
    SetBooleanOption("pullSidebarOnLeft", not db.pullSidebarOnLeft, false)
    RefreshSettingsWindow()
    Print(db.pullSidebarOnLeft and "sidebar on left" or "sidebar on right")
  elseif command == "detach" then
    SetBooleanOption("pullSidebarDetached", not db.pullSidebarDetached, false)
    RefreshSettingsWindow()
    Print(db.pullSidebarDetached and "sidebar detached" or "sidebar attached")
  elseif command == "sidebarlock" or command == "locksidebar" then
    SetBooleanOption("pullSidebarLocked", not db.pullSidebarLocked, false)
    RefreshSettingsWindow()
    Print(db.pullSidebarLocked and "detached sidebar locked" or "detached sidebar unlocked")
  elseif command == "percent" or command == "percents" then
    SetBooleanOption("showPullPercent", not db.showPullPercent, false)
    RefreshSettingsWindow()
    Print(db.showPullPercent and "pull percentages shown" or "pull percentages hidden")
  elseif command == "size" then
    local size = tonumber(rest)
    if size then
      ApplySize(size)
      SavePosition()
      RefreshIfNeeded(true)
    else
      Print("usage: /mdtmini size 348")
    end
  elseif command == "alpha" then
    local alpha = tonumber(rest)
    if alpha then
      db.alpha = Clamp(alpha, 0.2, 1)
      ApplyMapAlpha()
      SaveActiveDungeonLayout()
      Print("map alpha "..db.alpha)
    else
      Print("usage: /mdtmini alpha 0.85")
    end
  elseif command == "iconalpha" or command == "iconsalpha" then
    local alpha = tonumber(rest)
    if alpha then
      db.iconAlpha = Clamp(alpha, 0.2, 1)
      SaveActiveDungeonLayout()
      RequestRefresh()
      RefreshIfNeeded(true)
      Print("icon alpha "..db.iconAlpha)
    else
      Print("usage: /mdtmini iconalpha 0.85")
    end
  elseif command == "reset" then
    ResetPosition()
    RefreshIfNeeded(true)
  else
    Print("/mdtmini options | toggle | show | hide | lock | unlock | pull <number> | all | outlines | lines | numbers | dots | unpulled | frame | dungeon | mouseover | combat | autopull | proximity | proxradius <25-240> | drift <1-25> | recovery | recoverymode | recover | undo | redo | revert | sidebar | side | detach | sidebarlock | percent | size <width> | alpha <0.2-1> | iconalpha <0.2-1> | reset")
  end
end

function MDTMiniRouteGetAdjustedRouteText()
  local preset = GetCurrentPreset()
  local pulls = preset and preset.value and preset.value.pulls
  local maxForces = MDTMiniRouteGetMaxForces()
  if type(pulls) ~= "table" or not maxForces or maxForces <= 0 then
    return "Route: --"
  end

  local currentForces = MDTMiniRouteCountPullsForces(pulls, #pulls, false)
  local currentPercent = (currentForces / maxForces) * 100
  local state = MDTMiniRouteEnsureRecoveryState()
  local baselinePercent
  if state and state.baseline and type(state.baseline.pulls) == "table" then
    baselinePercent = (MDTMiniRouteCountPullsForces(state.baseline.pulls, #state.baseline.pulls, false) / maxForces) * 100
  end

  if baselinePercent then
    return string.format("Route: %.2f%% (%+.2f%%)", currentPercent, currentPercent - baselinePercent)
  end
  return string.format("Route: %.2f%%", currentPercent)
end

function MDTMiniRouteRefreshRecoveryFrame()
  local recoveryFrame = _G.MDTMiniRouteRecoveryFrame
  if not recoveryFrame then return end

  if recoveryFrame.modeButton then
    recoveryFrame.modeButton:SetText((db and db.recoveryMode) and "Recovery: On" or "Recovery: Off")
  end
  if recoveryFrame.percentText then
    recoveryFrame.percentText:SetText(MDTMiniRouteGetAdjustedRouteText())
  end
  if recoveryFrame.anchorText then
    if db and db.autoPullAnchorActive and db.autoPullAnchorPull and db.autoPullAnchorPull > 0 then
      recoveryFrame.anchorText:SetText("Anchor: Pull "..db.autoPullAnchorPull)
    else
      recoveryFrame.anchorText:SetText("Anchor: none")
    end
  end
end

function MDTMiniRouteCreateRecoveryFrame()
  if _G.MDTMiniRouteRecoveryFrame then return _G.MDTMiniRouteRecoveryFrame end

  local recoveryFrame = CreateFrame("Frame", "MDTMiniRouteRecoveryFrame", UIParent, "BackdropTemplate")
  recoveryFrame:SetFrameStrata("DIALOG")
  recoveryFrame:SetClampedToScreen(true)
  recoveryFrame:SetMovable(true)
  recoveryFrame:EnableMouse(true)
  recoveryFrame:RegisterForDrag("LeftButton")
  recoveryFrame:SetSize(276, 148)
  recoveryFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  recoveryFrame:SetBackdropColor(0.025, 0.03, 0.04, 0.94)
  recoveryFrame:SetBackdropBorderColor(0, 0, 0, 0.95)
  if frame then
    recoveryFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -6)
  else
    recoveryFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
  recoveryFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  recoveryFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  recoveryFrame:Hide()

  local title = recoveryFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", recoveryFrame, "TOPLEFT", 10, -10)
  title:SetText("Mini Route Recovery")

  local close = CreateFrame("Button", nil, recoveryFrame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", recoveryFrame, "TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() recoveryFrame:Hide() end)

  recoveryFrame.modeButton = CreateFrame("Button", nil, recoveryFrame, "UIPanelButtonTemplate")
  recoveryFrame.modeButton:SetPoint("TOPLEFT", recoveryFrame, "TOPLEFT", 10, -34)
  recoveryFrame.modeButton:SetSize(116, 22)
  recoveryFrame.modeButton:SetScript("OnClick", function()
    MDTMiniRouteSetRecoveryMode(not (db and db.recoveryMode == true))
  end)

  local suggest = CreateFrame("Button", nil, recoveryFrame, "UIPanelButtonTemplate")
  suggest:SetPoint("LEFT", recoveryFrame.modeButton, "RIGHT", 8, 0)
  suggest:SetSize(110, 22)
  suggest:SetText("Suggest")
  suggest:SetScript("OnClick", function()
    if MDTMiniRouteSuggestRecovery then MDTMiniRouteSuggestRecovery() end
  end)

  recoveryFrame.percentText = recoveryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  recoveryFrame.percentText:SetPoint("TOPLEFT", recoveryFrame, "TOPLEFT", 12, -64)
  recoveryFrame.percentText:SetWidth(248)
  recoveryFrame.percentText:SetJustifyH("LEFT")

  recoveryFrame.anchorText = recoveryFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  recoveryFrame.anchorText:SetPoint("TOPLEFT", recoveryFrame, "TOPLEFT", 12, -84)
  recoveryFrame.anchorText:SetWidth(248)
  recoveryFrame.anchorText:SetJustifyH("LEFT")

  local undo = CreateFrame("Button", nil, recoveryFrame)
  undo:SetPoint("BOTTOMLEFT", recoveryFrame, "BOTTOMLEFT", 12, 10)
  undo:SetSize(24, 24)
  undo:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
  undo:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
  undo:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  undo:SetScript("OnClick", MDTMiniRouteUndoRecovery)

  local redo = CreateFrame("Button", nil, recoveryFrame)
  redo:SetPoint("LEFT", undo, "RIGHT", 8, 0)
  redo:SetSize(24, 24)
  redo:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  redo:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
  redo:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  redo:SetScript("OnClick", MDTMiniRouteRedoRecovery)

  local revert = CreateFrame("Button", nil, recoveryFrame, "UIPanelButtonTemplate")
  revert:SetPoint("LEFT", redo, "RIGHT", 10, 0)
  revert:SetSize(74, 22)
  revert:SetText("Revert")
  revert:SetScript("OnClick", MDTMiniRouteRevertRecovery)

  local clearAnchor = CreateFrame("Button", nil, recoveryFrame, "UIPanelButtonTemplate")
  clearAnchor:SetPoint("LEFT", revert, "RIGHT", 8, 0)
  clearAnchor:SetSize(94, 22)
  clearAnchor:SetText("Clear Anchor")
  clearAnchor:SetScript("OnClick", function()
    if db then
      db.autoPullAnchorActive = false
      db.autoPullAnchorPull = 0
      Print("auto selector anchor cleared")
      MDTMiniRouteRefreshRecoveryFrame()
    end
  end)

  _G.MDTMiniRouteRecoveryFrame = recoveryFrame
  MDTMiniRouteRefreshRecoveryFrame()
  return recoveryFrame
end

function MDTMiniRouteToggleRecoveryFrame()
  local recoveryFrame = MDTMiniRouteCreateRecoveryFrame()
  MDTMiniRouteRefreshRecoveryFrame()
  if recoveryFrame:IsShown() then
    recoveryFrame:Hide()
  else
    recoveryFrame:Show()
  end
end

function MDTMiniRouteNormalizeRecoveryBorderStyle(style)
  if style == "NONE" or style == "1PX" or style == "ARTWORK" then
    return style
  end
  return "ARTWORK"
end

function MDTMiniRouteRecoveryBorderLabel(style)
  style = MDTMiniRouteNormalizeRecoveryBorderStyle(style)
  if style == "NONE" then return "No border" end
  if style == "1PX" then return "1px border" end
  return "Round border"
end

function MDTMiniRouteGetRecoveryBorderColor()
  if not db or type(db.recoveryButtonBorderColor) ~= "table" then
    return 0.15, 0.85, 1
  end
  return db.recoveryButtonBorderColor[1] or 0.15, db.recoveryButtonBorderColor[2] or 0.85, db.recoveryButtonBorderColor[3] or 1
end

function MDTMiniRouteCycleRecoveryBorderStyle()
  if not db then return end
  local style = MDTMiniRouteNormalizeRecoveryBorderStyle(db.recoveryButtonBorderStyle)
  if style == "ARTWORK" then
    db.recoveryButtonBorderStyle = "1PX"
  elseif style == "1PX" then
    db.recoveryButtonBorderStyle = "NONE"
  else
    db.recoveryButtonBorderStyle = "ARTWORK"
  end
  MDTMiniRouteApplyRecoveryButtonAppearance()
  RefreshSettingsWindow()
end

function MDTMiniRouteOpenRecoveryBorderColorPicker()
  if not db then return end
  local r, g, b = MDTMiniRouteGetRecoveryBorderColor()
  local previous = { r = r, g = g, b = b }

  local function applyColor(color)
    local nr, ng, nb
    if type(color) == "table" then
      nr = color.r or color[1]
      ng = color.g or color[2]
      nb = color.b or color[3]
    else
      nr, ng, nb = ColorPickerFrame:GetColorRGB()
    end
    db.recoveryButtonBorderColor = { nr or previous.r, ng or previous.g, nb or previous.b }
    MDTMiniRouteApplyRecoveryButtonAppearance()
    RefreshSettingsWindow()
  end

  if not ColorPickerFrame then
    return
  end

  if ColorPickerFrame.SetupColorPickerAndShow then
    ColorPickerFrame:SetupColorPickerAndShow({
      r = r,
      g = g,
      b = b,
      swatchFunc = function() applyColor() end,
      cancelFunc = function(color) applyColor(color or previous) end,
    })
  else
    ColorPickerFrame.func = function() applyColor() end
    ColorPickerFrame.cancelFunc = function(color) applyColor(color or previous) end
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
  end
end

function MDTMiniRouteApplyRecoveryButtonAppearance()
  local button = _G.MDTMiniRouteRecoveryButton
  if not button or not db then return end

  if db.showRecoveryButton == false then
    button:Hide()
    return
  end

  button:Show()
  local mouseoverHidden = db.recoveryButtonMouseoverOnly == true and not OverlayIsMouseOver()
  button:SetAlpha(mouseoverHidden and 0 or 1)

  local style = MDTMiniRouteNormalizeRecoveryBorderStyle(db.recoveryButtonBorderStyle)
  local r, g, b = MDTMiniRouteGetRecoveryBorderColor()
  local borderSize = Clamp(db.recoveryButtonBorderSize or DEFAULTS.recoveryButtonBorderSize, 0, 10)
  local iconSize = 22
  local buttonSize = math.max(24, iconSize + (borderSize * 2) + 2)

  button:SetSize(buttonSize, buttonSize)
  if button.icon then
    button.icon:ClearAllPoints()
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon:SetSize(iconSize, iconSize)
  end

  if button.borderRing then
    button.borderRing:SetShown(style == "ARTWORK" and borderSize > 0)
    button.borderRing:SetSize(iconSize + borderSize * 2, iconSize + borderSize * 2)
    button.borderRing:SetVertexColor(r, g, b, 1)
  end

  if button.innerRing then
    button.innerRing:SetShown(style == "ARTWORK" and borderSize > 0)
    button.innerRing:SetSize(math.max(iconSize, iconSize + borderSize), math.max(iconSize, iconSize + borderSize))
    button.innerRing:SetVertexColor(0, 0, 0, 0.82)
  end

  if style == "1PX" then
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = math.max(1, borderSize),
    })
    button:SetBackdropColor(0, 0, 0, 0.25)
    button:SetBackdropBorderColor(r, g, b, 1)
  else
    button:SetBackdrop(nil)
  end
end

function MDTMiniRouteCreateRecoveryButton()
  if _G.MDTMiniRouteRecoveryButton or not frame then return end

  local button = CreateFrame("Button", "MDTMiniRouteRecoveryButton", frame, "BackdropTemplate")
  button:SetFrameLevel(frame:GetFrameLevel() + 30)
  button:SetSize(24, 24)
  button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  button.borderRing = button:CreateTexture(nil, "BACKGROUND", nil, 1)
  button.borderRing:SetTexture(CIRCLE_TEXTURE)
  button.borderRing:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.innerRing = button:CreateTexture(nil, "BACKGROUND", nil, 2)
  button.innerRing:SetTexture(CIRCLE_TEXTURE)
  button.innerRing:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetTexture("Interface\\Icons\\INV_Misc_Head_Murloc_01")
  button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  button:SetScript("OnClick", MDTMiniRouteToggleRecoveryFrame)
  button:SetScript("OnEnter", function(self)
    MDTMiniRouteApplyRecoveryButtonAppearance()
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:AddLine("Mini Route Recovery", 1, 0.85, 0.1)
    GameTooltip:AddLine("Open recovery tools", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
    if C_Timer and C_Timer.After then
      C_Timer.After(0.05, MDTMiniRouteApplyRecoveryButtonAppearance)
    else
      MDTMiniRouteApplyRecoveryButtonAppearance()
    end
  end)
  WatchOverlayMouseover(button)
  _G.MDTMiniRouteRecoveryButton = button
  MDTMiniRouteApplyRecoveryButtonAppearance()
end

local function CreateOverlay()
  frame = CreateFrame("Frame", "MDTMiniRouteFrame", UIParent, "BackdropTemplate")
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(not db.locked)
  frame:EnableMouse(true)
  frame:EnableMouseWheel(true)
  frame:SetResizable(false)
  frame:SetAlpha(1)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.02, 0.025, 0.03, 0.82)
  frame:SetBackdropBorderColor(0, 0, 0, 0.85)
  frame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)

  header = CreateFrame("Frame", nil, frame)
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  header:SetHeight(HEADER_HEIGHT - 2)
  header:EnableMouse(true)
  header:EnableMouseWheel(true)
  header:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and not db.locked then
      frame:StartMoving()
    elseif button == "RightButton" then
      ShowContextMenu(header)
    end
  end)
  header:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
      frame:StopMovingOrSizing()
      SavePosition()
    end
  end)
  header:SetScript("OnMouseWheel", function(_, delta)
    local step = IsShiftKeyDown() and 8 or 24
    ApplySize((db.width or DEFAULTS.width) + (delta > 0 and step or -step))
    SavePosition()
    RefreshIfNeeded(true)
  end)
  WatchOverlayMouseover(header)

  headerTexture = header:CreateTexture(nil, "BACKGROUND")
  headerTexture:SetAllPoints()
  headerTexture:SetColorTexture(0.035, 0.045, 0.06, 0.92)

  titleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  titleText:SetPoint("LEFT", header, "LEFT", 7, 0)
  titleText:SetPoint("RIGHT", header, "RIGHT", -24, 0)
  titleText:SetJustifyH("LEFT")
  titleText:SetText(TITLE)

  closeButton = CreateFrame("Button", nil, header)
  closeButton:SetPoint("RIGHT", header, "RIGHT", -2, 0)
  closeButton:SetSize(18, 18)
  closeButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
  closeButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
  closeButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
  closeButton:SetScript("OnClick", ToggleShown)

  frame:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and not db.locked then
      frame:StartMoving()
    elseif button == "RightButton" then
      ShowContextMenu(frame)
    end
  end)
  frame:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
      frame:StopMovingOrSizing()
      SavePosition()
    end
  end)
  frame:SetScript("OnMouseWheel", function(_, delta)
    local step = IsShiftKeyDown() and 8 or 24
    ApplySize((db.width or DEFAULTS.width) + (delta > 0 and step or -step))
    SavePosition()
    RefreshIfNeeded(true)
  end)
  WatchOverlayMouseover(frame)

  mapViewport = CreateFrame("ScrollFrame", nil, frame)
  mapViewport:EnableMouse(false)
  if mapViewport.SetClipsChildren then
    mapViewport:SetClipsChildren(true)
  end

  mapBg = mapViewport:CreateTexture(nil, "BACKGROUND")
  mapBg:SetAllPoints()
  mapBg:SetColorTexture(0, 0, 0, 0.65)

  pullSidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  pullSidebar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  pullSidebar:SetBackdropColor(0.015, 0.018, 0.022, 0.72)
  pullSidebar:SetBackdropBorderColor(0, 0, 0, 0.75)
  pullSidebar:SetClampedToScreen(true)
  pullSidebar:SetMovable(true)
  pullSidebar:EnableMouse(true)
  pullSidebar:EnableMouseWheel(true)
  pullSidebar:RegisterForDrag("LeftButton")
  pullSidebar:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and db.pullSidebarDetached and not db.pullSidebarLocked then
      pullSidebar:StartMoving()
    elseif button == "RightButton" then
      ShowContextMenu(pullSidebar)
    end
  end)
  pullSidebar:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
      pullSidebar:StopMovingOrSizing()
      SaveSidebarPosition()
    end
  end)
  pullSidebar:SetScript("OnMouseWheel", function(_, delta)
    ScrollPullSidebar(delta)
  end)
  WatchOverlayMouseover(pullSidebar)

  pullSidebarShowAllButton = CreateFrame("Button", nil, pullSidebar, "BackdropTemplate")
  pullSidebarShowAllButton:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  pullSidebarShowAllButton:EnableMouse(true)
  pullSidebarShowAllButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  pullSidebarShowAllButton:RegisterForDrag("LeftButton")
  pullSidebarShowAllButton.text = pullSidebarShowAllButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  pullSidebarShowAllButton.text:SetPoint("CENTER", pullSidebarShowAllButton, "CENTER", 0, 0)
  pullSidebarShowAllButton.text:SetJustifyH("CENTER")
  pullSidebarShowAllButton:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      ShowContextMenu(self)
      return
    end
    SetBooleanOption("showAllPulls", not db.showAllPulls, false)
    RefreshSettingsWindow()
  end)
  pullSidebarShowAllButton:SetScript("OnDragStart", function()
    if db.pullSidebarDetached and not db.pullSidebarLocked then
      pullSidebar:StartMoving()
    end
  end)
  pullSidebarShowAllButton:SetScript("OnDragStop", function()
    pullSidebar:StopMovingOrSizing()
    SaveSidebarPosition()
  end)
  pullSidebarShowAllButton:SetScript("OnMouseWheel", function(_, delta)
    ScrollPullSidebar(delta)
  end)
  WatchOverlayMouseover(pullSidebarShowAllButton)

  pullSidebarScroll = CreateFrame("ScrollFrame", nil, pullSidebar)
  pullSidebarScroll:EnableMouseWheel(true)
  pullSidebarScroll:SetScript("OnMouseWheel", function(_, delta)
    ScrollPullSidebar(delta)
  end)
  WatchOverlayMouseover(pullSidebarScroll)

  pullSidebarContent = CreateFrame("Frame", nil, pullSidebarScroll)
  pullSidebarContent:SetPoint("TOPLEFT", pullSidebarScroll, "TOPLEFT", 0, 0)
  pullSidebarScroll:SetScrollChild(pullSidebarContent)
  LayoutPullSidebar()

  MDTMiniRouteCreateRecoveryButton()

  canvas = CreateFrame("Frame", nil, mapViewport)
  mapViewport:SetScrollChild(canvas)

  for i = 1, 12 do
    smallTiles[i] = canvas:CreateTexture(nil, "BACKGROUND", nil, 0)
  end

  for row = 1, 10 do
    largeTiles[row] = {}
    for col = 1, 15 do
      largeTiles[row][col] = canvas:CreateTexture(nil, "BACKGROUND", nil, 0)
    end
  end

  statusText = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  statusText:SetPoint("CENTER", canvas, "CENTER", 0, 0)
  statusText:SetTextColor(1, 1, 1, 0.85)
  statusText:Hide()

  frame:SetScript("OnShow", function()
    RequestRefresh()
    RefreshIfNeeded(true)
  end)
  frame:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceRefresh = elapsedSinceRefresh + elapsed
    if elapsedSinceRefresh >= REFRESH_INTERVAL then
      elapsedSinceRefresh = 0
      RefreshIfNeeded(false)
      ApplyOverlayVisualAlpha()
    end
  end)

  ApplySize(db.width)
  UpdateOverlayVisibility(true)
end

local function Initialize()
  if initialized then return end
  initialized = true

  MDTMiniRouteDB = CopyDefaults(DEFAULTS, MDTMiniRouteDB)
  db = MDTMiniRouteDB
  db.width = Clamp(db.width, MIN_WIDTH, MAX_WIDTH)
  db.alpha = Clamp(db.alpha, 0.2, 1)
  db.iconAlpha = Clamp(db.iconAlpha, 0.2, 1)
  db.showFrameArtwork = db.showFrameArtwork ~= false
  db.showOnMouseoverOnly = db.showOnMouseoverOnly == true
  db.onlyShowOutOfCombat = db.onlyShowOutOfCombat == true
  db.autoSelectPull = db.autoSelectPull == true
  db.autoPullUseProximity = db.autoPullUseProximity == true
  db.autoPullProximityRadius = Clamp(db.autoPullProximityRadius or DEFAULTS.autoPullProximityRadius, 25, 240)
  db.autoPullDriftWatcher = db.autoPullDriftWatcher ~= false
  db.autoPullDriftThreshold = Clamp(db.autoPullDriftThreshold or DEFAULTS.autoPullDriftThreshold, 1, 25)
  db.autoPullAnchorActive = db.autoPullAnchorActive == true
  db.autoPullAnchorPull = tonumber(db.autoPullAnchorPull) or 0
  db.autoPullTrashOffset = tonumber(db.autoPullTrashOffset) or 0
  db.autoPullBossOffset = tonumber(db.autoPullBossOffset) or 0
  db.recoveryMode = db.recoveryMode == true
  db.showRecoveryButton = db.showRecoveryButton ~= false
  db.recoveryButtonMouseoverOnly = db.recoveryButtonMouseoverOnly == true
  db.recoveryButtonBorderStyle = MDTMiniRouteNormalizeRecoveryBorderStyle(db.recoveryButtonBorderStyle)
  db.recoveryButtonBorderSize = Clamp(db.recoveryButtonBorderSize or DEFAULTS.recoveryButtonBorderSize, 0, 10)
  if type(db.recoveryButtonBorderColor) ~= "table" then
    db.recoveryButtonBorderColor = CopyDefaults(DEFAULTS.recoveryButtonBorderColor, {})
  end
  db.onlyShowInMatchingDungeon = db.onlyShowInMatchingDungeon == true
  db.showPullSidebar = db.showPullSidebar ~= false
  db.showPullPercent = db.showPullPercent ~= false
  db.pullSidebarOnLeft = db.pullSidebarOnLeft == true
  db.pullSidebarDetached = db.pullSidebarDetached == true
  db.pullSidebarLocked = db.pullSidebarLocked == true
  db.pullSidebarWidth = Clamp(db.pullSidebarWidth or DEFAULTS.pullSidebarWidth, SIDEBAR_MIN_WIDTH, SIDEBAR_MAX_WIDTH)
  db.pullSidebarHeight = Clamp(db.pullSidebarHeight or DEFAULTS.pullSidebarHeight, 0, SIDEBAR_MAX_HEIGHT)
  db.pullSidebarScale = Clamp(db.pullSidebarScale or DEFAULTS.pullSidebarScale, SIDEBAR_MIN_SCALE, SIDEBAR_MAX_SCALE)
  db.pullSidebarPoint = db.pullSidebarPoint or DEFAULTS.pullSidebarPoint
  db.pullSidebarRelativePoint = db.pullSidebarRelativePoint or DEFAULTS.pullSidebarRelativePoint
  db.pullSidebarX = db.pullSidebarX or DEFAULTS.pullSidebarX
  db.pullSidebarY = db.pullSidebarY or DEFAULTS.pullSidebarY
  db.sidebarFont = NormalizeFontName(db.sidebarFont)
  db.sidebarFontSize = Clamp(db.sidebarFontSize or DEFAULTS.sidebarFontSize, FONT_SIZE_MIN, FONT_SIZE_MAX)
  db.sidebarFontOutline = NormalizeOutline(db.sidebarFontOutline)
  db.sidebarFontShadow = db.sidebarFontShadow == true
  db.mapFont = NormalizeFontName(db.mapFont)
  db.mapFontSize = Clamp(db.mapFontSize or DEFAULTS.mapFontSize, FONT_SIZE_MIN, FONT_SIZE_MAX)
  db.mapFontOutline = NormalizeOutline(db.mapFontOutline)
  db.mapFontShadow = db.mapFontShadow == true
  db.showUnpulledEnemies = db.showUnpulledEnemies == true
  db.showEnemyDots = db.showEnemyDots == true
  if type(db.dungeonLayouts) ~= "table" then
    db.dungeonLayouts = {}
  end
  db.showEnemies = false
  db.showEnemyPortraits = false
  db.showPOIs = false

  CreateOverlay()
  CreateMDTMonitor()
  HookMDT()

  SLASH_MDTMINIROUTE1 = "/mdtmini"
  SLASH_MDTMINIROUTE2 = "/mdtroute"
  SlashCmdList.MDTMINIROUTE = HandleSlash

  RequestRefresh()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("WORLD_STATE_TIMER_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
eventFrame:RegisterEvent("SCENARIO_COMPLETED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    Initialize()
  elseif event == "PLAYER_LOGIN" then
    Initialize()
    HookMDT()
    RequestRefresh()
    RefreshIfNeeded(true)
    self:UnregisterEvent("PLAYER_LOGIN")
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    if initialized then
      UpdateOverlayVisibility(true)
    end
  elseif event == "PLAYER_ENTERING_WORLD"
      or event == "ZONE_CHANGED_NEW_AREA"
      or event == "WORLD_STATE_TIMER_START"
      or event == "CHALLENGE_MODE_START"
      or event == "GROUP_ROSTER_UPDATE"
      or event == "SCENARIO_CRITERIA_UPDATE"
      or event == "SCENARIO_COMPLETED" then
    if initialized then
      if event == "PLAYER_ENTERING_WORLD"
          or event == "ZONE_CHANGED_NEW_AREA"
          or event == "CHALLENGE_MODE_START"
          or event == "SCENARIO_COMPLETED" then
        db.autoPullTrashOffset = 0
        db.autoPullBossOffset = 0
      end
      UpdateAutoPullFromProgress(true)
      RequestRefresh()
      RefreshIfNeeded(true)
    end
  end
end)
