local ADDON_NAME = ...

local TITLE = "MDT Mini Route"
local MAP_WIDTH = 840
local MAP_HEIGHT = 555
local HEADER_HEIGHT = 22
local PADDING = 4
local MIN_WIDTH = 220
local MAX_WIDTH = 720
local REFRESH_INTERVAL = 0.35

local CIRCLE_TEXTURE = "Interface\\AddOns\\MythicDungeonTools\\Textures\\Circle_White"
local SQUARE_TEXTURE = "Interface\\AddOns\\MythicDungeonTools\\Textures\\Square_White"
local POI_FALLBACK_TEXTURE = "Interface\\MINIMAP\\POIIcons"

local DEFAULTS = {
  shown = true,
  locked = false,
  showAllPulls = true,
  showEnemies = true,
  showUnpulledEnemies = true,
  showEnemyDots = false,
  showEnemyPortraits = true,
  showPOIs = true,
  showPullOutlines = true,
  showPullNumbers = true,
  showRouteLines = false,
  alpha = 0.95,
  width = 348,
  point = "BOTTOMLEFT",
  relativePoint = "BOTTOMLEFT",
  x = 32,
  y = 245,
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
local titleText
local mapViewport
local canvas
local statusText
local smallTiles = {}
local largeTiles = {}
local hooksInstalled
local mdtSettingsInjected
local initialized
local dirty = true
local lastSignature
local elapsedSinceRefresh = 0

local linePool, markerPool, dotPool, enemyPool, poiPool = {}, {}, {}, {}, {}
local usedLines, usedMarkers, usedDots, usedEnemies, usedPOIs = 0, 0, 0, 0, 0
local ResetPosition, ToggleShown, SetLocked

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffMDT Mini Route:|r "..msg)
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
    marker.text:SetFont(marker.text:GetFont(), 10, "OUTLINE")
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
  line:SetVertexColor(r, g, b, a)
  line:SetSize(length, thickness)
  line:SetPoint("CENTER", canvas, "TOPLEFT", (sx + ex) / 2, (sy + ey) / 2)
  line:SetRotation(math.atan2(dy, dx))
end

local function DrawDot(x, y, scale, r, g, b, a, size)
  local dot = AcquireDot()
  dot:SetSize(size, size)
  dot:SetVertexColor(r, g, b, a)
  dot:SetPoint("CENTER", canvas, "TOPLEFT", x * scale, y * scale)
end

local function DrawMarker(x, y, scale, pullIdx, r, g, b, active, selected)
  local marker = AcquireMarker()
  local size = active and 20 or selected and 18 or 15
  local alpha = active and 1 or selected and 0.92 or 0.72
  local scaledSize = math.max(size, math.floor(size * scale * 1.8))

  marker:SetSize(scaledSize, scaledSize)
  marker:SetPoint("CENTER", canvas, "TOPLEFT", x * scale, y * scale)
  marker:SetAlpha(alpha)
  marker.icon:SetVertexColor(r, g, b, 0.92)
  marker.text:SetText(pullIdx)
  marker.text:SetTextColor(1, 1, 1, 1)
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
  enemyIcon:SetAlpha(alpha)
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
    icon:SetVertexColor(1, 1, 1, 0.9)
  else
    icon:SetTexture(POI_FALLBACK_TEXTURE)
    icon:SetTexCoord(0, 0.25, 0, 0.25)
    icon:SetVertexColor(0.35, 0.72, 1, 0.8)
  end
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
  local viewportWidth = db.width - (PADDING * 2)
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

local function ApplySize(width)
  if not frame or not db then return end

  db.width = Clamp(width or db.width, MIN_WIDTH, MAX_WIDTH)
  local viewportWidth = db.width - (PADDING * 2)
  local viewportHeight = viewportWidth * (MAP_HEIGHT / MAP_WIDTH)

  frame:SetSize(db.width, HEADER_HEIGHT + viewportHeight + PADDING)
  mapViewport:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -HEADER_HEIGHT)
  mapViewport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING)
  canvas:SetSize(viewportWidth, viewportHeight)
  LayoutTiles()
  RequestRefresh()
end

local function ShowStatus(message)
  ResetDrawnRoute()
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
  if not db.showEnemies and not db.showEnemyDots then return end
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
          if pullInfo or db.showUnpulledEnemies then
            if db.showEnemies then
              DrawEnemyIcon(enemy, clone, scale, pullInfo, selected)
            elseif db.showEnemyDots then
              local r, g, b = 0.75, 0.75, 0.75
              if pullInfo then r, g, b = pullInfo.r, pullInfo.g, pullInfo.b end
              DrawDot(clone.x, clone.y, scale, r, g, b, pullInfo and 0.72 or 0.34, pullInfo and 5 or 3)
            end
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

  local viewportWidth = db.width - (PADDING * 2)
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
  frame:SetAlpha(db.alpha or DEFAULTS.alpha)

  if not UpdateMapTextures(mdtDB, preset) then
    ShowStatus("No map")
    return
  end

  HideStatus()
  DrawRoute(mdtDB, preset)
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
    tostring(db.width),
  }, ":")
end

local function RefreshIfNeeded(force)
  if not frame or not frame:IsShown() then return end
  local signature = BuildSignature()
  if force or dirty or signature ~= lastSignature then
    dirty = false
    lastSignature = signature
    Refresh()
  end
end

local function HookMDT()
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

local function AddCheckbox(parent, label, key, callback)
  local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
  if not AceGUI then return end

  local checkbox = AceGUI:Create("CheckBox")
  checkbox:SetLabel(label)
  checkbox:SetWidth(parent.settingWidth or 320)
  checkbox:SetValue(db[key] == true)
  checkbox:SetCallback("OnValueChanged", function(_, _, value)
    db[key] = value == true
    if callback then callback(db[key]) end
    RequestRefresh()
    RefreshIfNeeded(true)
  end)
  parent:AddChild(checkbox)
  return checkbox
end

local function AddButton(parent, text, callback)
  local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
  if not AceGUI then return end

  local button = AceGUI:Create("Button")
  button:SetText(text)
  button:SetWidth(parent.settingWidth or 220)
  button:SetCallback("OnClick", callback)
  parent:AddChild(button)
  return button
end

local function AddSlider(parent, label, minValue, maxValue, step, value, callback)
  local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
  if not AceGUI then return end

  local slider = AceGUI:Create("Slider")
  slider:SetLabel(label)
  slider:SetWidth(parent.settingWidth or 320)
  slider:SetSliderValues(minValue, maxValue, step)
  slider:SetValue(value)
  slider:SetCallback("OnMouseUp", function(_, _, newValue)
    callback(newValue)
    RequestRefresh()
    RefreshIfNeeded(true)
  end)
  parent:AddChild(slider)
  return slider
end

local function InjectMDTSettings()
  if mdtSettingsInjected then return end
  local MDT = GetMDT()
  local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
  local mdtFrame = MDT and MDT.main_frame
  local parent = mdtFrame and mdtFrame.settingsGeneralColumn
  if not MDT or not AceGUI or not parent then return end

  mdtSettingsInjected = true

  local heading = AceGUI:Create("Heading")
  heading:SetText("Mini Route")
  heading:SetFullWidth(true)
  parent:AddChild(heading)

  local label = AceGUI:Create("Label")
  label:SetText("Mini Route is loaded as a separate MDT plugin. These controls only affect the mini overlay.")
  label:SetFullWidth(true)
  parent:AddChild(label)

  AddCheckbox(parent, "Show mini route overlay", "shown", function(value)
    if frame then
      if value then frame:Show() else frame:Hide() end
    end
  end)
  AddCheckbox(parent, "Lock overlay position", "locked", function(value)
    if frame then frame:SetMovable(not value) end
  end)
  AddCheckbox(parent, "Show all pulls", "showAllPulls")
  AddCheckbox(parent, "Show pull numbers", "showPullNumbers")
  AddCheckbox(parent, "Show MDT-style pull outlines", "showPullOutlines")
  AddCheckbox(parent, "Show route connection lines", "showRouteLines")
  AddCheckbox(parent, "Show enemy icons", "showEnemies")
  AddCheckbox(parent, "Use enemy portraits", "showEnemyPortraits")
  AddCheckbox(parent, "Show unpulled enemies", "showUnpulledEnemies")
  AddCheckbox(parent, "Show tiny enemy dots when icons are off", "showEnemyDots")
  AddCheckbox(parent, "Show POIs", "showPOIs")

  AddSlider(parent, "Mini Route width", MIN_WIDTH, MAX_WIDTH, 1, db.width, function(value)
    ApplySize(value)
    SavePosition()
  end)
  AddSlider(parent, "Mini Route alpha", 0.2, 1, 0.05, db.alpha, function(value)
    db.alpha = Clamp(value, 0.2, 1)
    if frame then frame:SetAlpha(db.alpha) end
  end)

  AddButton(parent, "Reset Mini Route Position", function()
    ResetPosition()
    RequestRefresh()
    RefreshIfNeeded(true)
  end)

  if parent.DoLayout then parent:DoLayout() end
  if MDT.Settings_RefreshLayout then MDT:Settings_RefreshLayout() end
end

local function QueueMDTSettingsInjection()
  local MDT = GetMDT()
  if not MDT then return end

  if MDT.main_frame and MDT.main_frame.settingsGeneralColumn then
    pcall(InjectMDTSettings)
  elseif type(MDT.RunAfterFramesInitialized) == "function" then
    MDT:RunAfterFramesInitialized(function()
      pcall(InjectMDTSettings)
    end)
  end
end

ResetPosition = function()
  if not frame or not db then return end
  db.point = DEFAULTS.point
  db.relativePoint = DEFAULTS.relativePoint
  db.x = DEFAULTS.x
  db.y = DEFAULTS.y
  db.width = DEFAULTS.width
  frame:ClearAllPoints()
  frame:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
  ApplySize(db.width)
end

ToggleShown = function()
  db.shown = not db.shown
  if db.shown then
    frame:Show()
    RefreshIfNeeded(true)
  else
    frame:Hide()
  end
  Print(db.shown and "shown" or "hidden")
end

SetLocked = function(locked)
  db.locked = locked
  if db.locked then
    frame:SetMovable(false)
  else
    frame:SetMovable(true)
  end
  Print(db.locked and "locked" or "unlocked")
end

local function HandleSlash(input)
  input = (input or ""):lower()
  local command, rest = input:match("^(%S*)%s*(.-)$")

  if command == "" or command == "toggle" then
    ToggleShown()
  elseif command == "show" then
    db.shown = true
    frame:Show()
    RefreshIfNeeded(true)
  elseif command == "hide" then
    db.shown = false
    frame:Hide()
  elseif command == "lock" then
    SetLocked(true)
  elseif command == "unlock" then
    SetLocked(false)
  elseif command == "all" then
    db.showAllPulls = not db.showAllPulls
    Print(db.showAllPulls and "showing all pulls" or "showing selected pull only")
    RefreshIfNeeded(true)
  elseif command == "enemies" then
    db.showEnemies = not db.showEnemies
    Print(db.showEnemies and "enemy icons on" or "enemy icons off")
    RefreshIfNeeded(true)
  elseif command == "unpulled" then
    db.showUnpulledEnemies = not db.showUnpulledEnemies
    Print(db.showUnpulledEnemies and "unpulled enemies on" or "unpulled enemies off")
    RefreshIfNeeded(true)
  elseif command == "dots" then
    db.showEnemyDots = not db.showEnemyDots
    Print(db.showEnemyDots and "enemy dots on" or "enemy dots off")
    RefreshIfNeeded(true)
  elseif command == "pois" then
    db.showPOIs = not db.showPOIs
    Print(db.showPOIs and "POIs on" or "POIs off")
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
      frame:SetAlpha(db.alpha)
      Print("alpha "..db.alpha)
    else
      Print("usage: /mdtmini alpha 0.85")
    end
  elseif command == "reset" then
    ResetPosition()
    RefreshIfNeeded(true)
  else
    Print("/mdtmini toggle | show | hide | lock | unlock | all | enemies | unpulled | dots | pois | outlines | lines | numbers | size <width> | alpha <0.2-1> | reset")
  end
end

local function CreateOverlay()
  frame = CreateFrame("Frame", "MDTMiniRouteFrame", UIParent, "BackdropTemplate")
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(not db.locked)
  frame:EnableMouse(true)
  frame:SetResizable(false)
  frame:SetAlpha(db.alpha or DEFAULTS.alpha)
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
      ToggleShown()
    end
  end)
  header:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    SavePosition()
  end)
  header:SetScript("OnMouseWheel", function(_, delta)
    local step = IsShiftKeyDown() and 8 or 24
    ApplySize((db.width or DEFAULTS.width) + (delta > 0 and step or -step))
    SavePosition()
    RefreshIfNeeded(true)
  end)

  local headerTexture = header:CreateTexture(nil, "BACKGROUND")
  headerTexture:SetAllPoints()
  headerTexture:SetColorTexture(0.035, 0.045, 0.06, 0.92)

  titleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  titleText:SetPoint("LEFT", header, "LEFT", 7, 0)
  titleText:SetPoint("RIGHT", header, "RIGHT", -24, 0)
  titleText:SetJustifyH("LEFT")
  titleText:SetText(TITLE)

  local close = CreateFrame("Button", nil, header)
  close:SetPoint("RIGHT", header, "RIGHT", -2, 0)
  close:SetSize(18, 18)
  close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
  close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
  close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
  close:SetScript("OnClick", ToggleShown)

  mapViewport = CreateFrame("ScrollFrame", nil, frame)
  mapViewport:EnableMouse(false)
  if mapViewport.SetClipsChildren then
    mapViewport:SetClipsChildren(true)
  end

  local mapBg = mapViewport:CreateTexture(nil, "BACKGROUND")
  mapBg:SetAllPoints()
  mapBg:SetColorTexture(0, 0, 0, 0.65)

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
    end
  end)

  ApplySize(db.width)
  if db.shown then
    frame:Show()
  else
    frame:Hide()
  end
end

local function Initialize()
  if initialized then return end
  initialized = true

  MDTMiniRouteDB = CopyDefaults(DEFAULTS, MDTMiniRouteDB)
  db = MDTMiniRouteDB
  db.width = Clamp(db.width, MIN_WIDTH, MAX_WIDTH)
  db.alpha = Clamp(db.alpha, 0.2, 1)

  CreateOverlay()
  HookMDT()
  QueueMDTSettingsInjection()

  SLASH_MDTMINIROUTE1 = "/mdtmini"
  SLASH_MDTMINIROUTE2 = "/mdtroute"
  SlashCmdList.MDTMINIROUTE = HandleSlash

  RequestRefresh()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    Initialize()
  elseif event == "PLAYER_LOGIN" then
    Initialize()
    QueueMDTSettingsInjection()
    HookMDT()
    RequestRefresh()
    RefreshIfNeeded(true)
    self:UnregisterEvent("PLAYER_LOGIN")
  end
end)
