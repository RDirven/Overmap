-- Marker providers. Each one adds { x, y, atlas|file, size, title, desc, r, g, b } entries.
-- Every API is checked first, so missing ones (WoW Forever vs Retail) are simply skipped.

local _, ns = ...
local try, XY = ns.try, ns.XY

local function add(out, x, y, d)
	d.x, d.y = x, y
	out[#out + 1] = d
end

ns.providers = {}
local P = ns.providers

-- Quests (objective areas and turn-ins)
P[#P + 1] = { key = "showQuests", fn = function(mapID, out)
	if not (C_QuestLog and C_QuestLog.GetQuestsOnMap) then return end
	for _, q in ipairs(try(C_QuestLog.GetQuestsOnMap, mapID) or {}) do
		if q.x and q.y then
			local id = q.questID
			local title = C_QuestLog.GetTitleForQuestID and try(C_QuestLog.GetTitleForQuestID, id)
			local done
			if C_QuestLog.IsComplete then done = try(C_QuestLog.IsComplete, id)
			elseif IsQuestComplete then done = try(IsQuestComplete, id) end
			if done then
				add(out, q.x, q.y, { file = "Interface\\GossipFrame\\ActiveQuestIcon", size = 18, title = title, desc = "Ready to turn in", level = 4 })
			else
				add(out, q.x, q.y, { file = ns.DOT, size = 11, r = 1, g = 0.82, b = 0, title = title, level = 3 })
			end
		end
	end
end }

-- Rares, treasures, events (vignettes): great for farming
P[#P + 1] = { key = "showVignettes", fn = function(mapID, out)
	if not (C_VignetteInfo and C_VignetteInfo.GetVignettes) then return end
	for _, guid in ipairs(try(C_VignetteInfo.GetVignettes) or {}) do
		local info = try(C_VignetteInfo.GetVignetteInfo, guid)
		if info and (info.onMinimap or info.onWorldMap) then
			local x, y = XY(try(C_VignetteInfo.GetVignettePosition, guid, mapID))
			if x then
				add(out, x, y, { atlas = info.atlasName, file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", size = 20, title = info.name, level = 5 })
			end
		end
	end
end }

-- Points of interest (towns, events, portals...)
P[#P + 1] = { key = "showPOIs", fn = function(mapID, out)
	if not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap) then return end
	for _, id in ipairs(try(C_AreaPoiInfo.GetAreaPOIForMap, mapID) or {}) do
		local info = try(C_AreaPoiInfo.GetAreaPOIInfo, mapID, id)
		if info then
			local x, y = XY(info.position)
			if x then
				local d = { atlas = info.atlasName, size = 18, title = info.name, desc = info.description, level = 2 }
				if not info.atlasName and info.textureIndex and GetPOITextureCoords then
					local l, r, t, b = GetPOITextureCoords(info.textureIndex)
					if l then
						d.file = "Interface\\Minimap\\POIIcons"
						d.coords = { l, r, t, b }
					end
				end
				if d.atlas or d.file then add(out, x, y, d) end
			end
		end
	end
end }

-- Flight masters (only your faction's and neutral ones)
P[#P + 1] = { key = "showTaxi", fn = function(mapID, out)
	if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return end
	local mine = UnitFactionGroup("player")
	local myFaction = (mine == "Horde" and 1) or (mine == "Alliance" and 2) or nil
	for _, n in ipairs(try(C_TaxiMap.GetTaxiNodesForMap, mapID) or {}) do
		local f = n.faction
		if f == nil or f == 0 or f == myFaction then
			local x, y = XY(n.position)
			if x then
				add(out, x, y, { atlas = n.atlasName, file = "Interface\\Minimap\\Tracking\\FlightMaster", size = 16, title = n.name, level = 2 })
			end
		end
	end
end }

-- Your corpse
P[#P + 1] = { key = "showCorpse", fn = function(mapID, out)
	if not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition) then return end
	if not UnitIsDeadOrGhost("player") then return end
	local x, y = XY(try(C_DeathInfo.GetCorpseMapPosition, mapID))
	if x then
		add(out, x, y, { file = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", size = 20, title = "Your corpse", level = 6 })
	end
end }

-- Map pin you placed (Retail: Ctrl-click on the world map)
P[#P + 1] = { key = "showWaypoint", fn = function(mapID, out)
	if not (C_Map.HasUserWaypoint and C_Map.GetUserWaypoint) then return end
	if not try(C_Map.HasUserWaypoint) then return end
	local p = try(C_Map.GetUserWaypoint)
	if p and p.uiMapID == mapID then
		local x, y = XY(p.position)
		if x then
			add(out, x, y, { atlas = "Waypoint-MapPin-Untracked", file = ns.DOT, r = 1, g = 0.9, b = 0.2, size = 20, title = "Map pin", level = 6 })
		end
	end
end }

-- Your own farm marks (/om mark)
local ICON_NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
P[#P + 1] = { key = "showMarks", fn = function(mapID, out)
	for _, m in ipairs(OvermapDB.marks[mapID] or {}) do
		add(out, m.x, m.y, {
			file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. (m.icon or 1),
			size = 16, level = 5,
			title = m.label or ("Farm mark (" .. (ICON_NAMES[m.icon or 1] or "") .. ")"),
			desc = ("%.1f, %.1f  -  /om unmark removes the nearest"):format(m.x * 100, m.y * 100),
		})
	end
end }

-- Party and raid members, coloured by class (updated often)
function ns.CollectGroup(mapID, out)
	local raid = IsInRaid()
	local prefix = raid and "raid" or "party"
	local count = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
	for i = 1, count do
		local unit = prefix .. i
		if UnitExists(unit) and not UnitIsUnit(unit, "player") then
			local x, y = ns.UnitPos(mapID, unit)
			if x then
				local _, class = UnitClass(unit)
				local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
				add(out, x, y, {
					file = ns.DOT, size = 10, level = 7,
					r = c and c.r or 0.4, g = c and c.g or 0.7, b = c and c.b or 1,
					title = UnitName(unit),
				})
			end
		end
	end
end
