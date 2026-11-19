-- Overmap: a Diablo 2 style, click-through map drawn over the world.
-- It does not touch the game's WorldMapFrame: it draws the map art itself,
-- so it never taints, works in combat and your normal map (M) stays as it is.
-- In minimap mode it borrows the game's Minimap instead and shows it big and see-through.

local addonName, ns = ...
_G.Overmap = ns

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
ns.DOT = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
ns.ARROW = "Interface\\Minimap\\MinimapArrow"

local issecret = _G.issecretvalue or function() return false end
local floor, min, max, abs, sqrt = math.floor, math.min, math.max, math.abs, math.sqrt

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

ns.defaults = {
	-- frame
	width = 900, height = 900, scale = 1,
	point = "CENTER", relPoint = "CENTER", x = 0, y = 30,
	strata = "LOW",
	locked = true,
	shiftInteract = true,
	-- look
	source = "minimap", -- "map": world map art, "minimap": the game's minimap, big and see-through
	mapAlpha = 0.5,
	pinAlpha = 1,
	bgAlpha = 0,
	movingAlpha = 0.8,
	shape = "OvalSofter",
	blend = "BLEND",
	desaturate = false,
	tint = { r = 1, g = 1, b = 1 },
	showExplored = true,
	fogOnly = false,
	-- view
	zoom = 1,
	follow = true,
	clampEdges = true,
	-- markers
	pinScale = 1,
	arrowSize = 28,
	showQuests = true,
	showVignettes = true,
	showPOIs = true,
	showTaxi = true,
	showGroup = true,
	showCorpse = true,
	showWaypoint = true,
	showMarks = true,
	showTrail = false,
	trailLength = 200,
	tooltips = true,
	-- extras
	showZoneText = false,
	showCoords = false,
	hideMinimap = false,
	hideInCombat = false,
	-- keys
	keyMode = "toggle", -- "toggle": tap to show / hide, "hold": shown while held
	cyclePresets = { Minimap = true, Diablo = true }, -- presets the "switch look" key goes through
}
-- settings that belong to the player, not to a look: presets and /om save skip them
ns.notInLook = { keyMode = true, cyclePresets = true }

-- shape key -> mask file + how the markers fade near the edge
ns.shapes = {
	{ key = "Rect",          text = "Square",              kind = "rect",    fade = 0 },
	{ key = "RectSoft",      text = "Square, soft edge",   kind = "rect",    fade = 0.18 },
	{ key = "RectSofter",    text = "Square, very soft",   kind = "rect",    fade = 0.40 },
	{ key = "Oval",          text = "Oval",                kind = "oval",    fade = 0 },
	{ key = "OvalSoft",      text = "Oval, soft edge",     kind = "oval",    fade = 0.18 },
	{ key = "OvalSofter",    text = "Oval, very soft",     kind = "oval",    fade = 0.40 },
	{ key = "DiamondSoft",   text = "Diamond, soft edge",  kind = "diamond", fade = 0.18 },
	{ key = "DiamondSofter", text = "Diamond, very soft",  kind = "diamond", fade = 0.40 },
}
local shapeByKey = {}
for _, s in ipairs(ns.shapes) do shapeByKey[s.key] = s end

ns.presets = {
	{ name = "Minimap", text = "Minimap", settings = {
		source = "minimap",
		width = 900, height = 900, point = "CENTER", relPoint = "CENTER", x = 0, y = 30,
		mapAlpha = 0.5, pinAlpha = 1, bgAlpha = 0, movingAlpha = 0.8,
		shape = "OvalSofter", follow = true, showZoneText = false, showCoords = false, strata = "LOW",
	} },
	{ name = "Diablo", text = "Diablo", settings = {
		source = "map",
		width = 900, height = 640, point = "CENTER", relPoint = "CENTER", x = 0, y = 30,
		mapAlpha = 0.6, pinAlpha = 0.95, bgAlpha = 0, movingAlpha = 0.85,
		shape = "OvalSofter", blend = "ADD", desaturate = true, tint = { r = 1, g = 0.72, b = 0.4 },
		showExplored = true, fogOnly = true, zoom = 1.8, follow = true, clampEdges = false,
		showTrail = false, showZoneText = false, showCoords = false, strata = "LOW",
	} },
	{ name = "Overlay", text = "See-through", settings = {
		source = "map",
		width = 820, height = 580, point = "CENTER", relPoint = "CENTER", x = 0, y = 30,
		mapAlpha = 0.45, pinAlpha = 1, bgAlpha = 0, movingAlpha = 1,
		shape = "RectSoft", blend = "BLEND", desaturate = false, tint = { r = 1, g = 1, b = 1 },
		showExplored = true, fogOnly = false, zoom = 1, follow = true, clampEdges = true,
		showZoneText = true, showCoords = true, strata = "LOW",
	} },
	{ name = "Farming", text = "Farming", settings = {
		source = "map",
		width = 1000, height = 700, point = "CENTER", relPoint = "CENTER", x = 0, y = 20,
		mapAlpha = 0.3, pinAlpha = 1, bgAlpha = 0, movingAlpha = 0.7,
		shape = "RectSofter", blend = "BLEND", desaturate = true, tint = { r = 0.75, g = 0.9, b = 1 },
		showExplored = true, fogOnly = false, zoom = 1, follow = false, clampEdges = true,
		showVignettes = true, showMarks = true, showTrail = true, showZoneText = true, showCoords = true,
		strata = "LOW",
	} },
	{ name = "Corner", text = "Corner", settings = {
		source = "map",
		width = 300, height = 300, point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -230, y = -20,
		mapAlpha = 0.9, pinAlpha = 1, bgAlpha = 0.5, movingAlpha = 1,
		shape = "OvalSoft", blend = "BLEND", desaturate = false, tint = { r = 1, g = 1, b = 1 },
		showExplored = true, fogOnly = false, zoom = 3, follow = true, clampEdges = false,
		showZoneText = false, showCoords = true, strata = "MEDIUM",
	} },
}

local function CopyValue(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = CopyValue(x) end
	return t
end
ns.CopyValue = CopyValue

local function FillDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			FillDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local db -- the active settings table (OvermapDB.settings)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffOvermap|r: " .. tostring(msg))
end
ns.Print = Print

-- pcall that returns the results, or nothing when the call fails / the API is missing
local function try(f, ...)
	if not f then return end
	local ok, a, b, c, d = pcall(f, ...)
	if ok then return a, b, c, d end
end
ns.try = try

-- x, y of a map position vector; nothing when unknown or hidden (secret) in instances
local function XY(pos)
	if pos == nil then return end
	local ok, x, y = pcall(function() return pos:GetXY() end)
	if not ok or x == nil or y == nil then return end
	if issecret(x) or issecret(y) then return end
	if x == 0 and y == 0 then return end
	return x, y
end
ns.XY = XY

function ns.UnitPos(mapID, unit)
	if not (C_Map and C_Map.GetPlayerMapPosition) then return end
	return XY(try(C_Map.GetPlayerMapPosition, mapID, unit))
end

local function Clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
ns.Clamp = Clamp

local function Smooth(t)
	t = Clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

---------------------------------------------------------------------------
-- State and frames
---------------------------------------------------------------------------

local S = {
	open = false,
	mapID = nil,
	layerW = 1000, layerH = 667,
	tileW = 256, tileH = 256,
	hasArt = false, hasExplored = false,
	px = nil, py = nil,          -- player position (0..1)
	panX = 0, panY = 0,          -- user panning, in map pixels
	zoom = 1,                    -- animated zoom
	moveMul = 1, fade = 1,
	interactive = nil,
	layoutKey = nil,
	pinsDirty = true,
}
ns.state = S

local root, bgFrame, canvas, miniHolder, trailLayer, pinLayer, topLayer
local arrow, zoneText, coordText, grip, border
local masks = {}
local tiles, explored = {}, {}
local trailTex = {}
local pinFrames = {}
ns.slowPins, ns.fastPins = {}, {}

local function MakeMask(frame)
	local m = frame:CreateMaskTexture()
	m:SetAllPoints(root)
	masks[#masks + 1] = m
	return m
end

local function CreateFrames()
	root = CreateFrame("Frame", "OvermapFrame", UIParent)
	root:Hide()
	root:SetClipsChildren(true)
	root:SetMovable(true)
	root:SetResizable(true)
	if root.SetResizeBounds then
		root:SetResizeBounds(120, 120, 3000, 2000)
	elseif root.SetMinResize then
		root:SetMinResize(120, 120)
	end
	root:SetClampedToScreen(true)
	root:EnableMouse(false)
	root:RegisterForDrag("LeftButton")
	ns.root = root

	-- background darkening, its own frame so its opacity is separate from the map's
	bgFrame = CreateFrame("Frame", nil, root)
	bgFrame:SetAllPoints()
	local bg = bgFrame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 1)
	bg:AddMaskTexture(MakeMask(bgFrame))

	-- the map art
	canvas = CreateFrame("Frame", nil, root)
	canvas:SetAllPoints()
	canvas.mask = MakeMask(canvas)

	-- holds the game's minimap in minimap mode. Not a child of root: the minimap
	-- draws no terrain inside a frame that clips its children (only black).
	miniHolder = CreateFrame("Frame", nil, UIParent)
	miniHolder:SetPoint("CENTER", root, "CENTER")
	miniHolder:Hide()
	root:HookScript("OnShow", function() miniHolder:Show() end)
	root:HookScript("OnHide", function() miniHolder:Hide() end)

	-- markers
	trailLayer = CreateFrame("Frame", nil, root)
	trailLayer:SetAllPoints()
	pinLayer = CreateFrame("Frame", nil, root)
	pinLayer:SetAllPoints()

	topLayer = CreateFrame("Frame", nil, root)
	topLayer:SetAllPoints()
	topLayer:SetFrameLevel(root:GetFrameLevel() + 10)

	arrow = topLayer:CreateTexture(nil, "OVERLAY")
	arrow:SetTexture(ns.ARROW)

	zoneText = topLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	zoneText:SetPoint("TOP", 0, -10)
	zoneText:SetShadowOffset(1, -1)
	coordText = topLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	coordText:SetPoint("BOTTOM", 0, 10)
	coordText:SetShadowOffset(1, -1)

	-- shown while you can move / resize (Shift held or unlocked)
	border = topLayer:CreateTexture(nil, "BORDER")
	border:SetAllPoints()
	border:SetColorTexture(0.4, 0.8, 1, 0.08)
	border:Hide()

	grip = CreateFrame("Button", nil, topLayer)
	grip:SetSize(18, 18)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:Hide()
	grip:SetScript("OnMouseDown", function() root:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function()
		root:StopMovingOrSizing()
		db.width, db.height = floor(root:GetWidth() + 0.5), floor(root:GetHeight() + 0.5)
		ns:SavePosition()
		ns:RefreshOptions()
	end)

	root:SetScript("OnDragStart", function(self)
		if S.interactive then self:StartMoving() end
	end)
	root:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		ns:SavePosition()
	end)
	root:SetScript("OnMouseWheel", function(_, delta)
		ns:Zoom(delta)
	end)
	root:SetScript("OnMouseDown", function(_, button)
		if button == "RightButton" then
			local x, y = GetCursorPosition()
			S.panning = { x = x, y = y, panX = S.panX, panY = S.panY }
		elseif button == "MiddleButton" then
			S.panX, S.panY = 0, 0
		end
	end)
	root:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then S.panning = nil end
	end)
	root:SetScript("OnSizeChanged", function()
		S.layoutKey = nil
		ns:PlaceMinimap()
	end)
	root:SetScript("OnUpdate", function(_, elapsed) ns:OnUpdate(elapsed) end)
end

---------------------------------------------------------------------------
-- Map art
---------------------------------------------------------------------------

local function GetTex(list, i, layer, sub)
	local t = list[i]
	if not t then
		t = canvas:CreateTexture(nil, layer, nil, sub)
		t:AddMaskTexture(canvas.mask)
		list[i] = t
	end
	t.used = true
	return t
end

local function ReleaseAll(list)
	for _, t in ipairs(list) do t.used = false; t:Hide() end
end

function ns:LoadMap(mapID)
	S.mapID = mapID
	S.layoutKey = nil
	S.pinsDirty = true
	S.panX, S.panY = 0, 0
	ReleaseAll(tiles)
	ReleaseAll(explored)
	S.hasArt, S.hasExplored = false, false

	local info = mapID and try(C_Map.GetMapInfo, mapID)
	zoneText:SetText(info and info.name or "")

	local layers = mapID and try(C_Map.GetMapArtLayers, mapID)
	local L = layers and layers[1]
	if not L then
		S.layerW, S.layerH = 1000, 667
		return
	end
	S.layerW, S.layerH = L.layerWidth, L.layerHeight
	S.tileW, S.tileH = L.tileWidth, L.tileHeight

	-- base tiles
	local files = try(C_Map.GetMapArtLayerTextures, mapID, 1) or {}
	local cols = math.ceil(L.layerWidth / L.tileWidth)
	local rows = math.ceil(L.layerHeight / L.tileHeight)
	local i = 0
	for r = 1, rows do
		for c = 1, cols do
			i = i + 1
			local fid = files[i]
			if fid then
				local t = GetTex(tiles, i, "BACKGROUND", 1)
				t:SetTexture(fid)
				t:SetTexCoord(0, 1, 0, 1)
				t.mx, t.my = (c - 1) * L.tileWidth, (r - 1) * L.tileHeight
				t.mw, t.mh = L.tileWidth, L.tileHeight
				S.hasArt = true
			end
		end
	end

	-- explored-area overlays (same maths as the game's own map)
	local TW, TH = L.tileWidth, L.tileHeight
	local ex = C_MapExplorationInfo and try(C_MapExplorationInfo.GetExploredMapTextures, mapID)
	local n = 0
	for _, e in ipairs(ex or {}) do
		if not e.isShownByMouseOver and e.fileDataIDs then
			local wide = math.ceil(e.textureWidth / TW)
			local tall = math.ceil(e.textureHeight / TH)
			for j = 1, tall do
				local ph, fh
				if j < tall then
					ph, fh = TH, TH
				else
					ph = e.textureHeight % TH
					if ph == 0 then ph = TH end
					fh = 16
					while fh < ph do fh = fh * 2 end
				end
				for k = 1, wide do
					local pw, fw
					if k < wide then
						pw, fw = TW, TW
					else
						pw = e.textureWidth % TW
						if pw == 0 then pw = TW end
						fw = 16
						while fw < pw do fw = fw * 2 end
					end
					local fid = e.fileDataIDs[(j - 1) * wide + k]
					if fid then
						n = n + 1
						local t = GetTex(explored, n, "BORDER", 0)
						t:SetTexture(fid)
						t:SetTexCoord(0, pw / fw, 0, ph / fh)
						t.mx, t.my = e.offsetX + TW * (k - 1), e.offsetY + TH * (j - 1)
						t.mw, t.mh = pw, ph
					end
				end
			end
		end
	end
	S.hasExplored = n > 0
	ns:ApplyLook()
end

-- colour, blend mode and fog of war on all map textures
function ns:ApplyLook()
	if not canvas then return end
	local r, g, b = db.tint.r, db.tint.g, db.tint.b
	local showBase = not (db.fogOnly and S.hasExplored)
	local showEx = db.showExplored or db.fogOnly
	local function style(t, shown)
		t:SetBlendMode(db.blend)
		t:SetDesaturated(db.desaturate)
		t:SetVertexColor(r, g, b)
		t:SetShown(shown)
	end
	for _, t in ipairs(tiles) do if t.used then style(t, showBase) end end
	for _, t in ipairs(explored) do if t.used then style(t, showEx) end end
end

function ns:ApplyShape()
	local s = shapeByKey[db.shape] or shapeByKey.RectSoft
	for _, m in ipairs(masks) do
		m:SetTexture(MEDIA .. s.key, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	end
	S.shape = s
	S.pinsDirty = true
	ns:PlaceMinimap()
end

-- 0..1: how visible a marker at screen point (sx, sy) is inside the shape
local function EdgeFactor(sx, sy)
	local W, H = S.W, S.H
	local u, v = sx / W * 2 - 1, sy / H * 2 - 1
	local s = S.shape
	local d
	if s.kind == "oval" then
		d = 1 - sqrt(u * u + v * v)
	elseif s.kind == "diamond" then
		d = 1 - (abs(u) + abs(v))
	else
		d = min(1 - abs(u), 1 - abs(v))
	end
	if d < 0 then return 0 end
	if s.fade <= 0 then return 1 end
	return Smooth(d / s.fade)
end

---------------------------------------------------------------------------
-- Layout: map pixels -> screen
---------------------------------------------------------------------------

-- normalized map coords -> offset from the overlay's top-left (y down)
local function ToScreen(nx, ny)
	return (nx * S.layerW - S.cx) * S.scale + S.W / 2, (ny * S.layerH - S.cy) * S.scale + S.H / 2
end
ns.ToScreen = ToScreen

local function PlaceTex(t)
	local s = S.scale
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", canvas, "TOPLEFT", (t.mx - S.cx) * s + S.W / 2, -((t.my - S.cy) * s + S.H / 2))
	t:SetSize(t.mw * s, t.mh * s)
end

function ns:Layout()
	local W, H = root:GetSize()
	if W <= 0 or H <= 0 then return end
	local s = min(W / S.layerW, H / S.layerH) * S.zoom
	local cx, cy
	if db.follow and S.px then
		cx, cy = S.px * S.layerW, S.py * S.layerH
	else
		cx, cy = S.layerW / 2, S.layerH / 2
	end
	cx, cy = cx + S.panX, cy + S.panY
	if db.clampEdges then
		local hw, hh = W / 2 / s, H / 2 / s
		cx = (S.layerW > 2 * hw) and Clamp(cx, hw, S.layerW - hw) or S.layerW / 2
		cy = (S.layerH > 2 * hh) and Clamp(cy, hh, S.layerH - hh) or S.layerH / 2
	end

	-- only move textures when the view really changed
	local key = floor(cx * 10) .. ":" .. floor(cy * 10) .. ":" .. floor(s * 10000) .. ":" .. W .. ":" .. H
	S.cx, S.cy, S.scale, S.W, S.H = cx, cy, s, W, H
	if key ~= S.layoutKey then
		S.layoutKey = key
		for _, t in ipairs(tiles) do if t.used then PlaceTex(t) end end
		for _, t in ipairs(explored) do if t.used then PlaceTex(t) end end
		S.pinsDirty = true
	end
end

---------------------------------------------------------------------------
-- Markers
---------------------------------------------------------------------------

local function PinEnter(self)
	local d = self.data
	if not d or not d.title then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	pcall(GameTooltip.SetText, GameTooltip, d.title, 1, 1, 1)
	if d.desc and d.desc ~= "" then pcall(GameTooltip.AddLine, GameTooltip, d.desc, nil, nil, nil, true) end
	GameTooltip:Show()
end

local function PinLeave()
	GameTooltip:Hide()
end

local SPLIT_MOUSE = UIParent.SetMouseClickEnabled ~= nil

local function SetPinMouse(p)
	local want = db.tooltips and p.data and p.data.title ~= nil
	if SPLIT_MOUSE then
		p:SetMouseClickEnabled(false)
		p:SetMouseMotionEnabled(want and true or false)
	else
		-- old clients cannot split clicks from hover: only while Shift is held
		p:EnableMouse((want and S.interactive) and true or false)
	end
end

local function GetPin(i)
	local p = pinFrames[i]
	if not p then
		p = CreateFrame("Frame", nil, pinLayer)
		p.tex = p:CreateTexture(nil, "ARTWORK")
		p.tex:SetAllPoints()
		p:SetScript("OnEnter", PinEnter)
		p:SetScript("OnLeave", PinLeave)
		pinFrames[i] = p
	end
	return p
end

local hasAtlas = C_Texture and C_Texture.GetAtlasInfo
local function SetIcon(tex, d)
	tex:SetTexCoord(0, 1, 0, 1)
	if d.atlas and hasAtlas and try(C_Texture.GetAtlasInfo, d.atlas) then
		tex:SetAtlas(d.atlas)
	else
		tex:SetTexture(d.file or ns.DOT)
		if d.coords then tex:SetTexCoord(unpack(d.coords)) end
	end
	tex:SetVertexColor(d.r or 1, d.g or 1, d.b or 1)
end

local function PlacePins()
	local n = 0
	local scale = db.pinScale
	for _, list in ipairs({ ns.slowPins, ns.fastPins }) do
		for _, d in ipairs(list) do
			local sx, sy = ToScreen(d.x, d.y)
			local e = EdgeFactor(sx, sy)
			if e > 0.02 then
				n = n + 1
				local p = GetPin(n)
				if p.data ~= d then
					p.data = d
					SetIcon(p.tex, d)
					local size = (d.size or 16) * scale
					p:SetSize(size, size)
					p:SetFrameLevel(pinLayer:GetFrameLevel() + (d.level or 1))
				end
				p:ClearAllPoints()
				p:SetPoint("CENTER", pinLayer, "TOPLEFT", sx, -sy)
				p:SetAlpha(e)
				SetPinMouse(p)
				p:Show()
			end
		end
	end
	for i = n + 1, #pinFrames do
		pinFrames[i]:Hide()
		pinFrames[i].data = nil
	end
end

local function PlaceTrail()
	local n = 0
	local trail = db.showTrail and S.mapID and ns.trail[S.mapID]
	if trail then
		local count = #trail
		local size = 5 * db.pinScale
		for i, pt in ipairs(trail) do
			local sx, sy = ToScreen(pt[1], pt[2])
			local e = EdgeFactor(sx, sy)
			if e > 0.02 then
				n = n + 1
				local t = trailTex[n]
				if not t then
					t = trailLayer:CreateTexture(nil, "ARTWORK")
					t:SetTexture(ns.DOT)
					trailTex[n] = t
				end
				t:SetVertexColor(1, 0.85, 0.3)
				t:SetSize(size, size)
				t:ClearAllPoints()
				t:SetPoint("CENTER", trailLayer, "TOPLEFT", sx, -sy)
				t:SetAlpha(e * (0.25 + 0.75 * i / count))
				t:Show()
			end
		end
	end
	for i = n + 1, #trailTex do trailTex[i]:Hide() end
end

function ns:CollectSlow()
	wipe(ns.slowPins)
	if S.mapID then
		for _, p in ipairs(ns.providers) do
			if db[p.key] then pcall(p.fn, S.mapID, ns.slowPins, db) end
		end
	end
	S.pinsDirty = true
end

function ns:CollectFast()
	wipe(ns.fastPins)
	if S.mapID and db.showGroup then pcall(ns.CollectGroup, S.mapID, ns.fastPins) end
	S.pinsDirty = true
end

---------------------------------------------------------------------------
-- Player, update loop
---------------------------------------------------------------------------

local function PlayerFacing()
	local f = try(GetPlayerFacing)
	if f == nil or issecret(f) then return end
	return f
end

function ns:UpdatePlayer()
	local x, y
	if S.mapID then x, y = ns.UnitPos(S.mapID, "player") end
	S.px, S.py = x, y
end

function ns:PlaceArrow()
	local x, y = S.px, S.py
	if x then
		local sx, sy = ToScreen(x, y)
		local size = db.arrowSize
		arrow:ClearAllPoints()
		arrow:SetPoint("CENTER", topLayer, "TOPLEFT", sx, -sy)
		arrow:SetSize(size, size)
		local f = PlayerFacing()
		if f then arrow:SetRotation(f) end
		arrow:SetAlpha(db.pinAlpha * S.moveMul * S.fade * EdgeFactor(sx, sy))
		arrow:SetShown(not ns:MinimapBorrowed()) -- the minimap draws its own arrow
		if db.showCoords then
			coordText:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
		end
	else
		arrow:Hide()
		coordText:SetText("")
	end
	coordText:SetShown(db.showCoords)
	zoneText:SetShown(db.showZoneText)
end

function ns:CheckMap(force)
	local mapID = C_Map and try(C_Map.GetBestMapForUnit, "player")
	if mapID and issecret(mapID) then mapID = nil end
	if force or mapID ~= S.mapID then
		ns:LoadMap(mapID)
		ns:CollectSlow()
	end
end

function ns:IsInteractive()
	return (not db.locked) or ns.optionsOpen or (db.shiftInteract and IsShiftKeyDown())
end

function ns:ApplyInteract()
	local want = ns:IsInteractive() and true or false
	if want == S.interactive then return end
	S.interactive = want
	root:EnableMouse(want)
	root:EnableMouseWheel(want)
	grip:SetShown(want)
	border:SetShown(want)
	if not want then
		S.panning = nil
		if root.StopMovingOrSizing then root:StopMovingOrSizing() end
	end
	for _, p in ipairs(pinFrames) do if p:IsShown() then SetPinMouse(p) end end
end

local slowAcc, fastAcc, mapAcc = 0, 0, 0
function ns:OnUpdate(elapsed)
	mapAcc = mapAcc + elapsed
	if mapAcc > 0.25 then mapAcc = 0; ns:CheckMap() end
	slowAcc = slowAcc + elapsed
	if slowAcc > 0.5 then slowAcc = 0; ns:CollectSlow() end
	fastAcc = fastAcc + elapsed
	if fastAcc > 0.1 then fastAcc = 0; ns:CollectFast() end

	-- smooth zoom
	if abs(S.zoom - db.zoom) > 0.001 then
		S.zoom = S.zoom + (db.zoom - S.zoom) * min(1, elapsed * 12)
	else
		S.zoom = db.zoom
	end

	-- Shift + right-drag pans the map
	if S.panning then
		local x, y = GetCursorPosition()
		local k = root:GetEffectiveScale() * S.scale
		S.panX = S.panning.panX - (x - S.panning.x) / k
		S.panY = S.panning.panY + (y - S.panning.y) / k
	end

	-- fade while moving, fade in on open
	local sp = try(GetUnitSpeed, "player") or 0
	if issecret(sp) then sp = 0 end
	local target = (sp > 0) and db.movingAlpha or 1
	S.moveMul = S.moveMul + (target - S.moveMul) * min(1, elapsed * 6)
	S.fade = min(1, S.fade + elapsed * 8)
	local mul = S.moveMul * S.fade
	canvas:SetAlpha(db.mapAlpha * mul)
	bgFrame:SetAlpha(db.bgAlpha * mul)
	pinLayer:SetAlpha(db.pinAlpha * mul)
	trailLayer:SetAlpha(db.pinAlpha * mul)
	topLayer:SetAlpha(S.fade)
	ns:UpdateMinimapAlpha(db.mapAlpha * S.moveMul)

	ns:ApplyInteract()
	ns:UpdatePlayer()
	ns:Layout()
	ns:PlaceArrow()
	if S.pinsDirty then
		S.pinsDirty = false
		PlacePins()
		PlaceTrail()
	end
end

---------------------------------------------------------------------------
-- Minimap hiding
---------------------------------------------------------------------------

local miniHidden, miniShowLater
local function MinimapFrame() return MinimapCluster or Minimap end

local function SetMinimapHidden(hide)
	local f = MinimapFrame()
	if not f then return end
	local locked = InCombatLockdown() and f:IsProtected()
	if hide then
		if miniShowLater then
			-- still hidden from last time (combat kept us from showing it)
			miniShowLater = nil
			miniHidden = { hidden = true }
			return
		end
		if miniHidden or not f:IsShown() then return end
		if locked then
			miniHidden = { alpha = f:GetAlpha() }
			f:SetAlpha(0)
		else
			miniHidden = { hidden = true }
			f:Hide()
		end
		miniShowLater = nil
	elseif miniHidden then
		if miniHidden.alpha then
			f:SetAlpha(miniHidden.alpha)
		elseif locked then
			miniShowLater = true
		else
			f:Show()
		end
		miniHidden = nil
	end
end

---------------------------------------------------------------------------
-- Minimap mode: the game's own minimap, big and see-through over the world.
-- Indoors it draws the outlines of rooms and corridors, like the Diablo map.
---------------------------------------------------------------------------

local borrowed -- the minimap's own state while it is in the overlay

local function WantMinimapMode()
	return S.open and db.source == "minimap" and Minimap ~= nil
end

function ns:MinimapBorrowed() return borrowed ~= nil end

local function DefaultMinimapMask()
	if MinimapCluster and MinimapCluster.MinimapContainer then
		return "Interface\\CharacterFrame\\TempPortraitAlphaMask" -- Retail
	end
	return "Textures\\MinimapMask"
end

-- the minimap only redraws its terrain at a new size after a zoom change
local function RedrawNow(m)
	local z = m:GetZoom()
	m:SetZoom(z > 0 and z - 1 or z + 1)
	m:SetZoom(z)
end

-- the client may only pick up the new size on a later frame, so redraw again then
local function RedrawMinimap(m)
	RedrawNow(m)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function() RedrawNow(m) end)
		C_Timer.After(0.2, function() RedrawNow(m) end)
	end
end

-- the empty minimap border stays behind, hide it while the minimap is ours
local function WantClusterHidden()
	if borrowed then return MinimapCluster ~= nil end -- never hide the borrowed minimap itself
	return db.hideMinimap
end

function ns:PlaceMinimap()
	if not borrowed then return end
	local m = Minimap
	if m:GetParent() ~= miniHolder then m:SetParent(miniHolder) end
	local W, H = root:GetSize()
	local side = min(W, H) -- the minimap is always square
	miniHolder:SetScale(root:GetScale())
	miniHolder:SetSize(side, side)
	miniHolder:SetFrameStrata(root:GetFrameStrata())
	miniHolder:SetFrameLevel(root:GetFrameLevel() + 2)
	miniHolder:SetShown(root:IsShown())
	m:SetSize(side, side)
	m:SetScale(1)
	m:ClearAllPoints()
	m:SetPoint("CENTER", miniHolder, "CENTER")
	m:SetFrameStrata(root:GetFrameStrata())
	m:SetFrameLevel(miniHolder:GetFrameLevel() + 1)
	S.miniMask = nil
	ns:UpdateMinimapAlpha(db.mapAlpha * S.moveMul)
	RedrawMinimap(m)
end

local function BorrowMinimap()
	local m = Minimap
	if borrowed or not m then return end
	if InCombatLockdown() and m:IsProtected() then return end
	borrowed = {
		parent = m:GetParent(), points = {},
		w = m:GetWidth(), h = m:GetHeight(), scale = m:GetScale(), alpha = m:GetAlpha(),
		strata = m:GetFrameStrata(), level = m:GetFrameLevel(),
		mouse = m:IsMouseEnabled(), wheel = m:IsMouseWheelEnabled(),
		zoom = m:GetZoom(),
	}
	for i = 1, m:GetNumPoints() do borrowed.points[i] = { m:GetPoint(i) } end
	m:SetParent(miniHolder)
	-- the border ring, zoom buttons etc. hang on the minimap itself: hide them
	borrowed.hidden = {}
	local function stash(list)
		for _, o in ipairs(list) do
			if o:IsShown() and pcall(o.Hide, o) then borrowed.hidden[#borrowed.hidden + 1] = o end
		end
	end
	stash({ m:GetChildren() })
	stash({ m:GetRegions() })
	-- click-through, like the rest of the overlay
	m:EnableMouse(false)
	m:EnableMouseWheel(false)
	if db.miniZoom then m:SetZoom(Clamp(db.miniZoom, 0, m:GetZoomLevels() - 1)) end
	m:SetAlpha(1)
	miniHolder:SetAlpha(1)
	m:Show()
	ns:PlaceMinimap()
end

local function ReturnMinimap()
	local b = borrowed
	if not b then return end
	if InCombatLockdown() and Minimap:IsProtected() then return end
	borrowed = nil
	local m = Minimap
	db.miniZoom = m:GetZoom()
	m:SetParent(b.parent)
	m:ClearAllPoints()
	for _, p in ipairs(b.points) do m:SetPoint(unpack(p)) end
	m:SetSize(b.w, b.h)
	m:SetScale(b.scale)
	m:SetAlpha(b.alpha)
	m:SetFrameStrata(b.strata)
	m:SetFrameLevel(b.level)
	m:EnableMouse(b.mouse)
	m:EnableMouseWheel(b.wheel)
	for _, o in ipairs(b.hidden) do pcall(o.Show, o) end
	pcall(m.SetMaskTexture, m, DefaultMinimapMask())
	m:SetZoom(b.zoom)
	RedrawMinimap(m)
end

-- The minimap draws no terrain at all when it (or a parent) is even slightly
-- transparent. Its mask's alpha does work, so opacity picks a mask with the
-- shape at 10%, 20% ... 100% (Media\Mini). The markers are not masked.
function ns:UpdateMinimapAlpha(a)
	if not borrowed then return end
	-- the game may put the minimap back in its own frame (e.g. Edit Mode)
	if Minimap:GetParent() ~= miniHolder then ns:PlaceMinimap() return end
	Minimap:SetAlpha(1)
	miniHolder:SetAlpha(1)
	local level = Clamp(floor(a * 10 + 0.5), 1, 10) * 10
	local key = (S.shape and S.shape.key or "RectSoft") .. level
	if key ~= S.miniMask then
		S.miniMask = key
		pcall(Minimap.SetMaskTexture, Minimap, MEDIA .. "Mini\\" .. key)
	end
end

-- switch between drawing the map art and showing the minimap
function ns:UpdateSource()
	if WantMinimapMode() then BorrowMinimap() else ReturnMinimap() end
	local art = not borrowed
	canvas:SetShown(art)
	pinLayer:SetShown(art)
	trailLayer:SetShown(art)
	if S.open then SetMinimapHidden(WantClusterHidden()) end
end

---------------------------------------------------------------------------
-- Open / close / actions
---------------------------------------------------------------------------

function ns:Open()
	if S.open then return end
	if not S.holdOpened and not ns.optionsOpen then OvermapDB.open = true end
	S.open = true
	S.fade = 0
	S.panX, S.panY = 0, 0
	S.zoom = db.zoom
	S.interactive = nil
	ns:CheckMap(true)
	if db.hideInCombat and InCombatLockdown() and not ns.optionsOpen then
		S.combatHidden = true
	else
		root:Show()
	end
	ns:UpdateSource()
end

function ns:Close()
	if not S.open then return end
	if ns.optionsOpen then return end -- stays visible as a live preview
	if not S.holdOpened then OvermapDB.open = false end
	S.open = false
	S.combatHidden = false
	S.holdOpened = false
	root:Hide()
	GameTooltip:Hide()
	ns:UpdateSource()
	SetMinimapHidden(false)
end

function ns:IsOpen() return S.open end

function ns:Toggle()
	if S.open then ns:Close() else ns:Open() end
end

function ns:Zoom(dir)
	if borrowed then
		local m = Minimap
		local z = Clamp(m:GetZoom() + ((dir > 0) and 1 or -1), 0, m:GetZoomLevels() - 1)
		m:SetZoom(z)
		db.miniZoom = z
		return
	end
	local z = db.zoom * ((dir > 0) and 1.25 or 0.8)
	db.zoom = Clamp(floor(z * 100 + 0.5) / 100, 0.5, 12)
	ns:RefreshOptions()
end

function ns:ChangeAlpha(delta)
	db.mapAlpha = Clamp(floor((db.mapAlpha + delta) * 100 + 0.5) / 100, 0, 1)
	Print(("map opacity %d%%"):format(db.mapAlpha * 100))
	ns:RefreshOptions()
end

function ns:SavePosition()
	local p, _, rp, x, y = root:GetPoint()
	db.point, db.relPoint, db.x, db.y = p, rp, floor(x + 0.5), floor(y + 0.5)
	ns:RefreshOptions()
end

-- apply every setting to the frame
function ns:ApplyAll()
	if not root then return end
	root:ClearAllPoints()
	root:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
	root:SetSize(db.width, db.height)
	root:SetScale(db.scale)
	root:SetFrameStrata(db.strata)
	ns:ApplyShape()
	ns:ApplyLook()
	S.layoutKey = nil
	S.pinsDirty = true
	if S.open then
		ns:UpdateSource()
		ns:PlaceMinimap()
		ns:CollectSlow()
	end
end

function ns:ApplyPreset(name)
	for _, p in ipairs(ns.presets) do
		if p.name:lower() == tostring(name):lower() then
			for k, v in pairs(p.settings) do db[k] = CopyValue(v) end
			OvermapDB.lastPreset = p.name
			ns:ApplyAll()
			ns:RefreshOptions()
			Print("preset: " .. p.text)
			return true
		end
	end
	local custom = OvermapDB.custom[name]
	if custom then
		for k, v in pairs(custom) do db[k] = CopyValue(v) end
		ns:ApplyAll()
		ns:RefreshOptions()
		Print("loaded: " .. name)
		return true
	end
end

function ns:NextPreset()
	local list = {}
	for _, p in ipairs(ns.presets) do
		if db.cyclePresets[p.name] then list[#list + 1] = p end
	end
	if #list == 0 then list = ns.presets end
	local idx = 0
	for i, p in ipairs(list) do if p.name == OvermapDB.lastPreset then idx = i end end
	idx = idx % #list + 1
	ns:ApplyPreset(list[idx].name)
end

function ns:ResetSettings()
	wipe(db)
	FillDefaults(db, ns.defaults)
	ns:SyncKeyMode()
	ns:ApplyAll()
	ns:RefreshOptions()
	Print("settings reset")
end

-- options call this after changing a value
function ns:SettingChanged(key)
	if key == "width" or key == "height" then
		root:SetSize(db.width, db.height)
	elseif key == "scale" then
		root:SetScale(db.scale)
		ns:PlaceMinimap()
	elseif key == "strata" then
		root:SetFrameStrata(db.strata)
		ns:PlaceMinimap()
	elseif key == "source" then
		ns:UpdateSource()
	elseif key == "shape" then
		ns:ApplyShape()
	elseif key == "blend" or key == "desaturate" or key == "tint" or key == "showExplored" or key == "fogOnly" then
		ns:ApplyLook()
	elseif key == "hideMinimap" then
		if S.open then SetMinimapHidden(WantClusterHidden()) end
	elseif key == "pinScale" then
		for _, p in ipairs(pinFrames) do p.data = nil end
	elseif key == "follow" then
		S.panX, S.panY = 0, 0
	elseif key == "keyMode" then
		ns:SwapOverlayKeyMode()
	end
	if key:find("^show") or key == "tooltips" then ns:CollectSlow() end
	S.layoutKey = nil
	S.pinsDirty = true
end

function ns:RefreshOptions() end -- replaced by Options.lua

---------------------------------------------------------------------------
-- Breadcrumb trail (records while the map is closed too)
---------------------------------------------------------------------------

ns.trail = {}
local function RecordTrail()
	if not db or not db.showTrail then return end
	local mapID = C_Map and try(C_Map.GetBestMapForUnit, "player")
	if not mapID or issecret(mapID) then return end
	local x, y = ns.UnitPos(mapID, "player")
	if not x then return end
	local t = ns.trail[mapID]
	if not t then t = {}; ns.trail[mapID] = t end
	local last = t[#t]
	if last then
		local dx, dy = x - last[1], y - last[2]
		if dx * dx + dy * dy < 0.004 * 0.004 then return end
	end
	t[#t + 1] = { x, y }
	while #t > db.trailLength do table.remove(t, 1) end
	if mapID == S.mapID then S.pinsDirty = true end
end

---------------------------------------------------------------------------
-- Farm marks
---------------------------------------------------------------------------

function ns:AddMark(icon, label)
	local mapID = C_Map and try(C_Map.GetBestMapForUnit, "player")
	local x, y
	if mapID then x, y = ns.UnitPos(mapID, "player") end
	if not x then Print("your position is not known here.") return end
	icon = Clamp(tonumber(icon) or 1, 1, 8)
	local list = OvermapDB.marks[mapID] or {}
	OvermapDB.marks[mapID] = list
	list[#list + 1] = { x = x, y = y, icon = icon, label = (label and label ~= "") and label or nil }
	Print(("mark added at %.1f, %.1f"):format(x * 100, y * 100))
	if mapID == S.mapID then ns:CollectSlow() end
end

function ns:RemoveNearestMark()
	local mapID = C_Map and try(C_Map.GetBestMapForUnit, "player")
	local list = mapID and OvermapDB.marks[mapID]
	local x, y
	if mapID then x, y = ns.UnitPos(mapID, "player") end
	if not list or #list == 0 or not x then Print("no marks here.") return end
	local best, bestD
	for i, m in ipairs(list) do
		local d = (m.x - x) ^ 2 + (m.y - y) ^ 2
		if not bestD or d < bestD then best, bestD = i, d end
	end
	table.remove(list, best)
	Print("nearest mark removed")
	ns:CollectSlow()
end

function ns:ClearMarks()
	local mapID = C_Map and try(C_Map.GetBestMapForUnit, "player")
	if mapID then OvermapDB.marks[mapID] = nil end
	Print("marks on this map removed")
	ns:CollectSlow()
end

---------------------------------------------------------------------------
-- Key bindings (Bindings.xml)
---------------------------------------------------------------------------

BINDING_HEADER_OVERMAP = "Overmap"
BINDING_NAME_OVERMAP_TOGGLE = "Show / hide the overlay (press)"
BINDING_NAME_OVERMAP_HOLD = "Show the overlay while held"
BINDING_NAME_OVERMAP_ZOOMIN = "Zoom in"
BINDING_NAME_OVERMAP_ZOOMOUT = "Zoom out"
BINDING_NAME_OVERMAP_ALPHAUP = "More opaque"
BINDING_NAME_OVERMAP_ALPHADOWN = "More transparent"
BINDING_NAME_OVERMAP_FOLLOW = "Follow me on / off"
BINDING_NAME_OVERMAP_FOG = "Fog of war on / off"
BINDING_NAME_OVERMAP_PRESET = "Next preset"
BINDING_NAME_OVERMAP_MARK = "Add a farm mark here"
BINDING_NAME_OVERMAP_OPTIONS = "Open options"

function Overmap_Toggle()
	S.holdOpened = false
	ns:Toggle()
end

function Overmap_Hold(keystate)
	if keystate == "down" then
		-- someone who holds a key does not want it open after a reload
		OvermapDB.open = false
		S.holdOpened = true -- also when it was already open: letting go closes it
		if not S.open then ns:Open() end
	elseif S.holdOpened then
		ns:Close()
	end
end

function Overmap_Zoom(dir) ns:Zoom(dir) end
function Overmap_Alpha(d) ns:ChangeAlpha(d) end
function Overmap_ToggleFollow()
	db.follow = not db.follow
	ns:SettingChanged("follow")
	ns:RefreshOptions()
	Print("follow me " .. (db.follow and "on" or "off"))
end
function Overmap_ToggleFog()
	db.fogOnly = not db.fogOnly
	ns:SettingChanged("fogOnly")
	ns:RefreshOptions()
	Print("fog of war " .. (db.fogOnly and "on" or "off"))
end
function Overmap_NextPreset() ns:NextPreset() end
function Overmap_Mark() ns:AddMark(1) end
function Overmap_Options() ns:ToggleOptions() end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local HELP = {
	"/om - options",
	"/om toggle | show | hide",
	"/om preset minimap | diablo | overlay | farming | corner",
	"/om mode map | minimap - draw the world map or show the minimap",
	"/om save <name>, /om load <name> - your own presets",
	"/om bind <key> - bind the toggle key, e.g. /om bind TAB",
	"/om hold <key> - bind a hold-to-show key",
	"/om mark [1-8] [label] - farm mark (raid icon) at your spot",
	"/om unmark - remove the nearest mark, /om clearmarks - all on this map",
	"/om cleartrail - clear the walked trail",
	"/om reset - default settings, /om center - back to the middle",
}

-- the overlay key is bound to OVERMAP_TOGGLE or OVERMAP_HOLD, depending on keyMode
function ns:OverlayAction()
	return (db.keyMode == "hold") and "OVERMAP_HOLD" or "OVERMAP_TOGGLE"
end

local function SaveKeys()
	local set = GetCurrentBindingSet and GetCurrentBindingSet()
	if set and SaveBindings then SaveBindings(set) end
end

local function ClearAction(action)
	local keys = { GetBindingKey(action) }
	for _, k in ipairs(keys) do SetBinding(k) end
	return keys
end

-- bind key to action (nil key: clear it). Returns true when it worked.
function ns:SetKey(action, key)
	if InCombatLockdown() then Print("key bindings cannot change in combat") return end
	ClearAction(action)
	if action == "OVERMAP_TOGGLE" or action == "OVERMAP_HOLD" then
		-- one overlay key: never on both
		ClearAction(action == "OVERMAP_TOGGLE" and "OVERMAP_HOLD" or "OVERMAP_TOGGLE")
	end
	local ok = true
	if key then ok = SetBinding(key, action) and true or false end
	SaveKeys()
	if not ok then Print("could not bind " .. key) end
	return ok
end

-- match keyMode to what is bound (e.g. a hold key set in the Key Bindings window)
function ns:SyncKeyMode()
	local toggleKey, holdKey = GetBindingKey("OVERMAP_TOGGLE"), GetBindingKey("OVERMAP_HOLD")
	if holdKey and not toggleKey then db.keyMode = "hold" elseif toggleKey and not holdKey then db.keyMode = "toggle" end
end

-- tap <-> hold: move the overlay key to the other action
function ns:SwapOverlayKeyMode()
	if InCombatLockdown() then Print("key bindings cannot change in combat") return end
	local new = ns:OverlayAction()
	local old = (new == "OVERMAP_HOLD") and "OVERMAP_TOGGLE" or "OVERMAP_HOLD"
	local keys = ClearAction(old)
	for _, k in ipairs(keys) do SetBinding(k, new) end
	SaveKeys()
	if new == "OVERMAP_HOLD" then
		OvermapDB.open = false -- a hold key user does not want it open after a reload
		if S.open and not ns.optionsOpen then ns:Close() end
	end
	ns:RefreshOptions()
end

local function Bind(key, action)
	if not key or key == "" then Print("give a key, e.g. /om bind TAB") return end
	key = key:upper()
	db.keyMode = (action == "OVERMAP_HOLD") and "hold" or "toggle"
	if ns:SetKey(action, key) then
		if action == "OVERMAP_HOLD" then OvermapDB.open = false end
		Print(key .. " now " .. (action == "OVERMAP_HOLD" and "shows the overlay while held" or "toggles the overlay"))
	end
	ns:RefreshOptions()
end

SLASH_OVERMAP1 = "/om"
SLASH_OVERMAP2 = "/overmap"
SlashCmdList.OVERMAP = function(msg)
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "" or cmd == "options" or cmd == "config" then
		ns:ToggleOptions()
	elseif cmd == "toggle" then ns:Toggle()
	elseif cmd == "show" then ns:Open()
	elseif cmd == "hide" then ns:Close()
	elseif cmd == "preset" then
		if not ns:ApplyPreset(rest) then Print("unknown preset: " .. rest) end
	elseif cmd == "mode" then
		rest = rest:lower()
		if rest ~= "map" and rest ~= "minimap" then
			rest = (db.source == "minimap") and "map" or "minimap"
		end
		db.source = rest
		ns:SettingChanged("source")
		ns:RefreshOptions()
		Print("mode: " .. rest)
	elseif cmd == "save" then
		if rest == "" then Print("give a name") return end
		local t = {}
		for k in pairs(ns.defaults) do
			if not ns.notInLook[k] then t[k] = CopyValue(db[k]) end
		end
		OvermapDB.custom[rest] = t
		Print("saved as '" .. rest .. "' (load it with /om load " .. rest .. ")")
	elseif cmd == "load" then
		if not ns:ApplyPreset(rest) then Print("nothing saved as '" .. rest .. "'") end
	elseif cmd == "bind" then Bind(rest, "OVERMAP_TOGGLE")
	elseif cmd == "hold" then Bind(rest, "OVERMAP_HOLD")
	elseif cmd == "mark" then
		local icon, label = rest:match("^(%d)%s*(.*)$")
		if icon then ns:AddMark(icon, label) else ns:AddMark(1, rest) end
	elseif cmd == "unmark" then ns:RemoveNearestMark()
	elseif cmd == "clearmarks" then ns:ClearMarks()
	elseif cmd == "cleartrail" then wipe(ns.trail); S.pinsDirty = true; Print("trail cleared")
	elseif cmd == "reset" then ns:ResetSettings()
	elseif cmd == "center" then
		db.point, db.relPoint, db.x, db.y = "CENTER", "CENTER", 0, 30
		ns:ApplyAll()
	else
		for _, line in ipairs(HELP) do Print(line) end
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		OvermapDB = OvermapDB or {}
		OvermapDB.settings = OvermapDB.settings or {}
		OvermapDB.marks = OvermapDB.marks or {}
		OvermapDB.custom = OvermapDB.custom or {}
		db = OvermapDB.settings
		FillDefaults(db, ns.defaults)
		ns.db = db
		ns.getDB = function() return db end
		CreateFrames()
		ns:ApplyAll()
	elseif event == "PLAYER_LOGIN" then
		ns:SyncKeyMode()
		if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(0.5, RecordTrail) end
		if not OvermapDB.welcomed then
			OvermapDB.welcomed = true
			Print("type /om for options, or /om bind TAB to toggle the map with Tab.")
		end
		-- open again after login / reload if it was open (and on first use);
		-- a moment later, so the game has placed its own minimap first
		if OvermapDB.open ~= false then
			if C_Timer and C_Timer.After then
				C_Timer.After(1, function() if OvermapDB.open ~= false then ns:Open() end end)
			else
				ns:Open()
			end
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if db.hideInCombat and S.open and not ns.optionsOpen then
			S.combatHidden = true
			root:Hide()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if S.combatHidden then
			S.combatHidden = false
			if S.open then root:Show() end
		end
		if not S.open and ns:MinimapBorrowed() then ns:UpdateSource() end -- could not give it back in combat
		if miniShowLater then
			miniShowLater = nil
			local f = MinimapFrame()
			if f and not S.open then f:Show() end
		end
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		if S.open then ns:CheckMap() end
	end
end)
