-- Options window. Built from plain frames so it looks and works the same
-- in WoW Forever and Retail. While it is open the overlay stays visible as a
-- live preview, and you can drag / resize / zoom it directly.

local _, ns = ...
local floor = math.floor

local widgets = {}
local frame

local function DB() return ns.db end

local function Changed(key)
	ns:SettingChanged(key)
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local COL_W = 250

local function Header(parent, text)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(COL_W, 26)
	local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	t:SetPoint("BOTTOMLEFT", 0, 4)
	t:SetText(text)
	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 0.82, 0, 0.35)
	line:SetPoint("BOTTOMLEFT")
	line:SetSize(COL_W, 1)
	return f
end

local function Slider(parent, key, label, minV, maxV, step, fmt)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(COL_W, 38)
	local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetPoint("TOPLEFT", 0, -2)
	text:SetText(label)
	local value = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	value:SetPoint("TOPRIGHT", 0, -2)

	local s = CreateFrame("Slider", nil, f)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(COL_W, 16)
	s:SetPoint("TOPLEFT", 0, -16)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	local thumb = s:GetThumbTexture()
	thumb:SetSize(32, 32)
	local track = s:CreateTexture(nil, "BACKGROUND")
	track:SetColorTexture(0, 0, 0, 0.6)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	track:SetHeight(6)
	local fill = s:CreateTexture(nil, "BORDER")
	fill:SetColorTexture(1, 0.82, 0, 0.5)
	fill:SetPoint("LEFT")
	fill:SetPoint("RIGHT", thumb, "CENTER")
	fill:SetHeight(6)

	fmt = fmt or function(v) return tostring(v) end
	s:SetScript("OnValueChanged", function(self, v)
		v = floor(v / step + 0.5) * step
		value:SetText(fmt(v))
		if f.updating then return end
		if DB()[key] ~= v then
			DB()[key] = v
			Changed(key)
		end
	end)
	s:EnableMouseWheel(true)
	s:SetScript("OnMouseWheel", function(self, delta)
		self:SetValue(self:GetValue() + delta * step)
	end)

	f.Refresh = function()
		f.updating = true
		s:SetValue(DB()[key])
		value:SetText(fmt(DB()[key]))
		f.updating = false
	end
	widgets[#widgets + 1] = f
	return f
end

local function Check(parent, key, label, tip)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(COL_W, 24)
	local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("LEFT", -4, 0)
	local t = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	t:SetPoint("LEFT", cb, "RIGHT", 2, 0)
	t:SetText(label)
	cb:SetScript("OnClick", function(self)
		DB()[key] = self:GetChecked() and true or false
		Changed(key)
	end)
	if tip then
		cb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(label, 1, 1, 1)
			GameTooltip:AddLine(tip, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	f.Refresh = function() cb:SetChecked(DB()[key] and true or false) end
	widgets[#widgets + 1] = f
	return f
end

-- button that cycles through choices; right-click goes back
local function Cycle(parent, key, label, choices)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(COL_W, 26)
	local t = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	t:SetPoint("LEFT")
	t:SetText(label)
	local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	b:SetSize(150, 22)
	b:SetPoint("RIGHT")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local function index()
		for i, c in ipairs(choices) do if c.value == DB()[key] then return i end end
		return 1
	end
	b:SetScript("OnClick", function(_, button)
		local i = index() + ((button == "RightButton") and -1 or 1)
		if i > #choices then i = 1 elseif i < 1 then i = #choices end
		DB()[key] = choices[i].value
		Changed(key)
		f.Refresh()
	end)
	f.Refresh = function() b:SetText(choices[index()].text) end
	widgets[#widgets + 1] = f
	return f
end

local function OpenColorPicker(r, g, b, callback)
	local CPF = ColorPickerFrame
	if CPF.SetupColorPickerAndShow then
		CPF:SetupColorPickerAndShow({
			r = r, g = g, b = b, hasOpacity = false,
			swatchFunc = function() callback(CPF:GetColorRGB()) end,
			cancelFunc = function(prev)
				if prev then callback(prev.r, prev.g, prev.b) else callback(r, g, b) end
			end,
		})
	else
		CPF.hasOpacity = false
		CPF.previousValues = { r = r, g = g, b = b }
		CPF.func = function() callback(CPF:GetColorRGB()) end
		CPF.opacityFunc = nil
		CPF.cancelFunc = function() callback(r, g, b) end
		CPF:SetColorRGB(r, g, b)
		CPF:Hide()
		CPF:Show()
	end
end

local function Color(parent, key, label)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(COL_W, 26)
	local t = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	t:SetPoint("LEFT")
	t:SetText(label)
	local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	reset:SetSize(60, 22)
	reset:SetPoint("RIGHT")
	reset:SetText("White")
	local sw = CreateFrame("Button", nil, f)
	sw:SetSize(80, 18)
	sw:SetPoint("RIGHT", reset, "LEFT", -6, 0)
	local edge = sw:CreateTexture(nil, "BACKGROUND")
	edge:SetAllPoints()
	edge:SetColorTexture(1, 1, 1, 0.8)
	local fill = sw:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMRIGHT", -1, 1)
	local function set(r, g, b)
		local c = DB()[key]
		c.r, c.g, c.b = r, g, b
		fill:SetColorTexture(r, g, b)
		Changed(key)
	end
	sw:SetScript("OnClick", function()
		local c = DB()[key]
		OpenColorPicker(c.r, c.g, c.b, set)
	end)
	reset:SetScript("OnClick", function() set(1, 1, 1) end)
	f.Refresh = function()
		local c = DB()[key]
		fill:SetColorTexture(c.r, c.g, c.b)
	end
	widgets[#widgets + 1] = f
	return f
end

-- click, then press a key (or controller button) to bind it; right-click clears it
local MODIFIER_KEYS = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	LMETA = true, RMETA = true, UNKNOWN = true,
}

-- controller buttons the client turns into Shift / Ctrl / Alt (Options > Gamepad)
local function IsEmulatedModifier(button)
	for _, cvar in ipairs({ "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }) do
		if GetCVar and GetCVar(cvar) == button then return true end
	end
end

local function WithModifiers(key)
	return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
		.. (IsShiftKeyDown() and "SHIFT-" or "") .. key
end
local function KeyButton(parent, label, action, tip)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(COL_W, 26)
	local t = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	t:SetPoint("LEFT")
	t:SetText(label)
	local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	b:SetSize(150, 22)
	b:SetPoint("RIGHT")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local function act() return type(action) == "function" and action() or action end
	local function stop()
		b.listening = false
		b.stoppedAt = GetTime()
		b:EnableKeyboard(false)
		if b.EnableGamePadButton then b:EnableGamePadButton(false) end
		f.Refresh()
	end
	local function take(key)
		if key == "ESCAPE" or key == "PAD2" then stop() return end -- Esc or B cancels
		if MODIFIER_KEYS[key] or IsEmulatedModifier(key) then return end -- wait for the real key
		ns:SetKey(act(), WithModifiers(key))
		stop()
	end
	b:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			if b.listening then stop() end
			ns:SetKey(act(), nil)
			f.Refresh()
			return
		end
		-- with a controller the button press that binds can also "click" this
		-- button: never let that cancel or restart listening
		if b.listening then return end
		if b.stoppedAt and GetTime() - b.stoppedAt < 0.4 then return end
		b.listening = true
		b:SetText("Press a key...")
		b:EnableKeyboard(true)
		if b.SetPropagateKeyboardInput then b:SetPropagateKeyboardInput(false) end
		if b.EnableGamePadButton then b:EnableGamePadButton(true) end
	end)
	b:SetScript("OnKeyDown", function(_, key) if b.listening then take(key) end end)
	if b.EnableGamePadButton then
		b:SetScript("OnGamePadButtonDown", function(_, key) if b.listening then take(key) end end)
	end
	b:SetScript("OnHide", function() if b.listening then stop() end end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(label, 1, 1, 1)
		GameTooltip:AddLine("Click, then press a key or controller button (hold a modifier for a combination). Right-click clears it, Esc or B cancels.", nil, nil, nil, true)
		if tip then GameTooltip:AddLine(tip, nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.Refresh = function()
		if b.listening then return end
		local k = GetBindingKey(act())
		b:SetText(k and (GetBindingText and GetBindingText(k) or k) or "Not bound")
	end
	widgets[#widgets + 1] = f
	return f
end

-- small tick box for one preset in the "switch look" list
local function PresetCheck(parent, name, text)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	local t = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	t:SetPoint("LEFT", cb, "RIGHT", 0, 0)
	t:SetText(text)
	cb.label = t
	cb:SetScript("OnClick", function(self)
		DB().cyclePresets[name] = self:GetChecked() and true or false
	end)
	cb.Refresh = function() cb:SetChecked(DB().cyclePresets[name] and true or false) end
	widgets[#widgets + 1] = cb
	return cb
end

local function Button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local pct = function(v) return floor(v * 100 + 0.5) .. "%" end
local px = function(v) return floor(v + 0.5) .. " px" end
local mult = function(v) return ("%.2fx"):format(v) end

local function Column(parent, x, items)
	local y = -48
	for _, w in ipairs(items) do
		w:SetParent(parent)
		w:ClearAllPoints()
		w:SetPoint("TOPLEFT", x, y)
		y = y - w:GetHeight() - 4
	end
	return y
end

local function Build()
	frame = CreateFrame("Frame", "OvermapOptions", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetSize(3 * COL_W + 4 * 24, 740)
	frame:SetPoint("CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetClampedToScreen(true)
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 14,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		frame:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
		frame:SetBackdropBorderColor(0.6, 0.6, 0.7, 1)
	end
	tinsert(UISpecialFrames, "OvermapOptions") -- Esc closes it

	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 18, -14)
	title:SetText("Overmap")
	local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("LEFT", title, "RIGHT", 12, 0)
	hint:SetPoint("RIGHT", frame, "RIGHT", -36, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText("Drag the map to move it, the corner to resize, the wheel to zoom, right-drag to pan. Outside this window: hold Shift.")

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -2)

	local x1, x2, x3 = 24, 24 * 2 + COL_W, 24 * 3 + COL_W * 2

	-- Column 1: look
	Column(frame, x1, {
		Header(frame, "Look"),
		Cycle(frame, "source", "Show", {
			{ value = "map", text = "World map" },
			{ value = "minimap", text = "Minimap (outlines)" },
		}),
		Slider(frame, "mapAlpha", "Map opacity", 0, 1, 0.01, pct),
		Slider(frame, "pinAlpha", "Marker opacity", 0, 1, 0.01, pct),
		Slider(frame, "bgAlpha", "Dark background", 0, 1, 0.01, pct),
		Slider(frame, "movingAlpha", "Opacity while moving", 0, 1, 0.01, pct),
		Cycle(frame, "shape", "Shape / edges", (function()
			local t = {}
			for _, s in ipairs(ns.shapes) do t[#t + 1] = { value = s.key, text = s.text } end
			return t
		end)()),
		Cycle(frame, "blend", "Drawing", {
			{ value = "BLEND", text = "Normal" },
			{ value = "ADD", text = "Glow (Diablo)" },
		}),
		Color(frame, "tint", "Colour"),
		Check(frame, "desaturate", "Black & white map", "Removes the map's colours, so the colour above tints it evenly."),
		Check(frame, "showExplored", "Show explored areas", "Draws the parts of the zone you have discovered."),
		Check(frame, "fogOnly", "Fog of war", "Only the areas you have explored are drawn, as in Diablo. Zones without explore data are drawn whole."),
	})

	-- Column 2: frame and view
	Column(frame, x2, {
		Header(frame, "Size & view"),
		Slider(frame, "width", "Width", 120, 2000, 10, px),
		Slider(frame, "height", "Height", 120, 1400, 10, px),
		Slider(frame, "scale", "Scale", 0.5, 2, 0.05, mult),
		Slider(frame, "zoom", "Zoom", 0.5, 12, 0.05, mult),
		Check(frame, "follow", "Follow me", "Keeps you in the middle, like a minimap. Not possible in dungeons where the game hides your position."),
		Check(frame, "clampEdges", "Stay inside the map", "Never shows empty space past the map's edges."),
		Cycle(frame, "strata", "Layer", {
			{ value = "BACKGROUND", text = "Below everything" },
			{ value = "LOW", text = "Below the UI" },
			{ value = "MEDIUM", text = "With the UI" },
			{ value = "HIGH", text = "Above the UI" },
		}),
		Check(frame, "locked", "Lock position", "When unlocked, the map can always be moved and catches the mouse."),
		Check(frame, "shiftInteract", "Shift to move / zoom", "Hold Shift over the map to drag, resize, zoom with the wheel or pan with the right button."),
		Check(frame, "hideMinimap", "Hide minimap while open"),
		Check(frame, "hideInCombat", "Hide in combat"),
		Check(frame, "showZoneText", "Zone name"),
		Check(frame, "showCoords", "Coordinates"),
	})

	-- Column 3: markers
	Column(frame, x3, {
		Header(frame, "Markers"),
		Slider(frame, "pinScale", "Marker size", 0.5, 3, 0.05, mult),
		Slider(frame, "arrowSize", "Arrow size", 10, 64, 1, px),
		Check(frame, "showQuests", "Quests"),
		Check(frame, "showVignettes", "Rares & treasures", "Rare mobs, treasures and events the game shows on the minimap."),
		Check(frame, "showPOIs", "Points of interest"),
		Check(frame, "showTaxi", "Flight masters"),
		Check(frame, "showGroup", "Party & raid", "Class-coloured dots for your group."),
		Check(frame, "showCorpse", "Your corpse"),
		Check(frame, "showWaypoint", "Map pin"),
		Check(frame, "showMarks", "Farm marks", "Your own marks: /om mark [1-8] [label] or the key binding."),
		Check(frame, "showTrail", "Walked trail", "Dots where you walked: handy to see which part of a farm route you did."),
		Slider(frame, "trailLength", "Trail length", 20, 1000, 10, function(v) return v .. " dots" end),
		Check(frame, "tooltips", "Marker names on hover"),
	})

	-- bottom: keys
	local keys = Header(frame, "Keys")
	keys:SetPoint("BOTTOMLEFT", 24, 150)
	local overlayKey = KeyButton(frame, "Overlay key", function() return ns:OverlayAction() end)
	overlayKey:SetPoint("BOTTOMLEFT", 24, 116)
	local mode = Cycle(frame, "keyMode", "Hold or tap", {
		{ value = "toggle", text = "Tap: on / off" },
		{ value = "hold", text = "Hold to show" },
	})
	mode:SetPoint("BOTTOMLEFT", x2, 116)
	local lookKey = KeyButton(frame, "Switch look key", "OVERMAP_PRESET",
		"Each press goes to the next ticked look.")
	lookKey:SetPoint("BOTTOMLEFT", 24, 86)
	local prevCheck
	for _, p in ipairs(ns.presets) do
		local cb = PresetCheck(frame, p.name, p.text)
		if prevCheck then
			cb:SetPoint("LEFT", prevCheck.label, "RIGHT", 10, 0)
		else
			cb:SetPoint("LEFT", lookKey, "RIGHT", 24 - 4, 0)
		end
		prevCheck = cb
	end

	-- bottom: presets
	local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("BOTTOMLEFT", 24, 52)
	label:SetText("Presets")
	local prev
	for _, p in ipairs(ns.presets) do
		local b = Button(frame, p.text, 100, function() ns:ApplyPreset(p.name) end)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("BOTTOMLEFT", 24, 22) end
		prev = b
	end

	local reset = Button(frame, "Defaults", 100, function() ns:ResetSettings() end)
	reset:SetPoint("BOTTOMRIGHT", -24, 22)
	local center = Button(frame, "Center", 100, function()
		local db = DB()
		db.point, db.relPoint, db.x, db.y = "CENTER", "CENTER", 0, 30
		ns:ApplyAll()
	end)
	center:SetPoint("RIGHT", reset, "LEFT", -6, 0)

	local more = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	more:SetPoint("BOTTOMRIGHT", -24, 52)
	more:SetText("More keys (zoom, opacity, ...): Key Bindings > AddOns > Overmap")

	frame:SetScript("OnShow", function()
		ns.optionsOpen = true
		frame.openedMap = not ns:IsOpen()
		ns:Open()
		ns:RefreshOptions()
	end)
	frame:SetScript("OnHide", function()
		ns.optionsOpen = false
		if frame.openedMap then ns:Close() end
		frame.openedMap = nil
	end)
	frame:Hide()
end

function ns:RefreshOptions()
	if not frame or not frame:IsShown() then return end
	for _, w in ipairs(widgets) do w.Refresh() end
end

function ns:ToggleOptions()
	if not frame then Build() end
	frame:SetShown(not frame:IsShown())
end

---------------------------------------------------------------------------
-- Entry in the game's Options > AddOns list
---------------------------------------------------------------------------

local panel = CreateFrame("Frame")
panel.name = "Overmap"
local pt = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
pt:SetPoint("TOPLEFT", 16, -16)
pt:SetText("Overmap")
local pd = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
pd:SetPoint("TOPLEFT", pt, "BOTTOMLEFT", 0, -8)
pd:SetJustifyH("LEFT")
pd:SetText("A see-through map you can toggle or hold with a key, like Diablo 2.\nAll settings are in its own window, so you can watch the map while you change them.")
local pb = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
pb:SetSize(200, 26)
pb:SetPoint("TOPLEFT", pd, "BOTTOMLEFT", 0, -16)
pb:SetText("Open Overmap options")
pb:SetScript("OnClick", function()
	if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
	if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() and HideUIPanel then HideUIPanel(InterfaceOptionsFrame) end
	if not frame then Build() end
	frame:Show()
end)

if Settings and Settings.RegisterCanvasLayoutCategory then
	local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
	InterfaceOptions_AddCategory(panel)
end
