_G.OS_VERSION = "1.0"
local GUI = require("lib/gui")
local GateRenderer = require("lib/gate-renderer")
local glyph_data = require("lib/glyph")
local config = { gateName = "Gate", idc = "", irisMode = 1, debug = false, theme = {
        theme1 = colors.gray, theme2 = colors.lightGray, themep = colors.red, themecsb = colors.lightGray,
        thement = colors.cyan, themept = colors.gray, themepwt = colors.white, themecst = colors.lightGray,
        thememt = colors.black, themelb = colors.lightGray, themelt = colors.white, themecdt = colors.blue,
        themese = colors.gray, themesb = colors.black, themenill = colors.green, themenil = colors.green }}
return function(stargate, Gates, display, shell)
    local display = display or term
    local w, h = display.getSize()
    local localType = stargate.getGateType()
    local glyphID = stargate.glyphID()
    local gateOpen = false
	local currentPage = 1
    local selectedAddress = nil 
	local selectedThemeIdx = 1
	local activeWindow = nil
	local busyTimer = nil
	local isBusy = false
	local lastRedstoneState = false
    local ui = GUI.new(display)
    local self = {}
	local quitConfirmed = false
	local quitTimer = nil
	local energyCache = {}
	if fs.exists("options.lua") then
		local f = fs.open("options.lua", "r")
		local rawData = f.readAll()
		f.close()
		local processedData = rawData:gsub("^return%s+", "")
		data = textutils.unserialize(processedData) or {}
	end
    local activeChevrons = {}
    local dialingState = {active = false, isComplete = false, lockedStr = "", name = "", address = {}, status = "", sequence = ""}
    local colors_map = {MilkyWay = colors.orange, Pegasus = colors.cyan, Universe = colors.white, Tollan = colors.cyan, Movie = colors.orange}
    local activeColor = colors_map[localType] or colors.orange
    Logger.log("States Initialized", "SYS")
	local function loadOptions()
        if not fs.exists("options.lua") then
            return
        end
        local f = fs.open("options.lua", "r")
        if f then
            local rawData = f.readAll()
            f.close()
            local data = textutils.unserialize(rawData)
            
            if type(data) == "table" then 
				config.gateName = data.gateName or "Gate"
                config.debug = data.debug or false 
                _G.DEBUG_MODE = config.debug	
                config.idc = tostring(data.idc or "0000")
                config.irisMode = tonumber(data.irisMode) or 1
                if data.theme then
                    for k, v in pairs(data.theme) do config.theme[k] = v end
                end
                stargate.idc = config.idc
                stargate.irisMode = config.irisMode
            end
        end
    end
    local function getGateTypeLabel()
        local gType = stargate.getGateType()
        if gType == "Pegasus" then return "Pegasus"
        elseif gType == "Universe" then return "Universe"
        else return "MilkyWay" end
    end
	function self.updateEnergyCache(addressName)
		if energyCache[addressName] then return end		
		local entry = Gates[addressName]
		if not entry then return end
		local gateTypeLabel = getGateTypeLabel()
		local addr = entry.addresses and entry.addresses[gateTypeLabel]		
		if type(addr) == "table" and #addr > 0 then
			local totalLength = 7
			local destType = entry.gateType
			if gateTypeLabel == "Universe" or destType == "Universe" then totalLength = 9
			elseif (gateTypeLabel == "MilkyWay" and destType == "Pegasus") or 
				   (gateTypeLabel == "Pegasus" and destType == "MilkyWay") then totalLength = 8
			elseif entry.isIntergalactic then totalLength = 8 end
			local finalAddress = {}
			for i = 1, totalLength - 1 do finalAddress[i] = addr[i] end
			local success, response, energyMap = stargate.getEnergyRequiredToDial(finalAddress)
				if success and type(energyMap) == "table" and energyMap.open then
				energyCache[addressName] = energyMap
			end
		end
	end
	local sortedKeys = {}
    for name in pairs(Gates) do table.insert(sortedKeys, name) end
    local totalGates = #sortedKeys
	for i, name in ipairs(sortedKeys) do
        display.setBackgroundColor(colors.black)
        display.clear()
        local barW = 20
        local progressRatio = i / totalGates
        local progressPercent = math.floor(progressRatio * barW)
        local glyphCount = math.floor(progressRatio * 9)
        local loadingSequence = ""
        for n = 1, glyphCount do
            loadingSequence = loadingSequence .. n
        end
        if GateRenderer and GateRenderer.draw then
            GateRenderer.draw(loadingSequence, localType, 31, 12, false, "OPENED", "none", stargate.glyphID())
        end		
		display.setBackgroundColor(colors.gray)
		for y,x,l in ("032A07042909052902053002062902063101072905082A07090404090A02090F01091302092D050A04010A0C010A0E030A12010A15010A29010A30020B04010B06020B0A030B0F010B12040B29020B30020C04010C07010C09010C0C010C0F010C12010C29090D04040D0A030D10010D13030D2A07"):gmatch"(..)(..)(..)" do
			display.setCursorPos(tonumber(x,16),tonumber(y,16))
			display.write((" "):rep(tonumber(l,16)))
		end
        display.setCursorPos(16, 15) 
        display.write(string.rep(" ", barW))
        display.setCursorPos(16, 15)
        display.setBackgroundColor(colors.green)
        display.write(string.rep(" ", progressPercent))
        display.setBackgroundColor(colors.black)
        display.setTextColor(colors.white)
        local statusText = "Initializing: " .. name
        display.setCursorPos(26 - (#statusText/2), 17)
        display.write(statusText)
		local verText = "v" .. _G.OS_VERSION
		display.setTextColor(colors.gray)
		display.setCursorPos(w - #verText, h)
		display.write(verText)
        self.updateEnergyCache(name)
        sleep(0.05)
		Logger.log("Main Menu Initialized", "SYS")
    end
    sortedInit = {}
    for name, data in pairs(Gates) do
        table.insert(sortedInit, { name = name, order = data.order or 999 })
    end
    table.sort(sortedInit, function(a, b) return a.order < b.order end)
    if #sortedInit > 0 then
        selectedAddress = sortedInit[1].name
    end
    Logger.log("Gates precalculated", "SYS")
	for name, data in pairs(Gates) do
        table.insert(sortedInit, { name = name, order = data.order or 999 })
        self.updateEnergyCache(name)
    end
    table.sort(sortedInit, function(a, b) return a.order < b.order end)
	if #sortedInit > 0 then
		selectedAddress = sortedInit[1].name
	end
    local function saveOptions()
        Logger.log("Saving options", "SYS")
        local f = fs.open("options.lua", "w")
        if f then
            f.write(textutils.serialize(config))
            f.close()
        end
    end
	loadOptions()
    local function saveAddressBook()
        local f = fs.open("gates.lua", "w")
        if f then
            f.write("return " .. textutils.serialize(Gates))
            f.close()
        else
            Logger.log("Export Error", "")
        end
    end
	local function getSyncStatus(localName, diskData)
		local localEntry = Gates[localName]
		if not localEntry then return "[ ]" end
		local function getComparableString(tbl)
			if not tbl then return "" end
			local keys = {}
			for k in pairs(tbl) do
				if k ~= "order" and k ~= "isRedial" and k ~= "isIntergalactic" then 
					table.insert(keys, k) 
				end
			end
			table.sort(keys)
			local parts = {}
			for _, k in ipairs(keys) do
				local v = tbl[k]
				if k == "addresses" and type(v) == "table" then
					local addrKeys = {}
					for g in pairs(v) do table.insert(addrKeys, g) end
					table.sort(addrKeys)
					
					local addrParts = {}
					for _, g in ipairs(addrKeys) do
						table.insert(addrParts, g .. "=" .. textutils.serialize(v[g]))
					end
					table.insert(parts, "addresses={" .. table.concat(addrParts, ",") .. "}")
				elseif type(v) == "table" then
					table.insert(parts, k .. "=" .. textutils.serialize(v))
				else
					table.insert(parts, k .. "=" .. tostring(v))
				end
			end
			return table.concat(parts, "|")
		end
		if getComparableString(localEntry) == getComparableString(diskData) then
			return "[*]"
		else
			return "[-]"
		end
	end
	local function exportEntryToDisk(entryName, entryData)
		local driveSide = nil
		for _, side in ipairs(peripheral.getNames()) do
			if peripheral.getType(side) == "drive" and disk.isPresent(side) then
				driveSide = side
				break
			end
		end
		if not driveSide then
			Logger.log("No Disk Found", "")
			return
		end
		local mountPath = disk.getMountPath(driveSide)
		local fullPath = fs.combine(mountPath, "gates.lua")
		local diskGates = {}
		if fs.exists(fullPath) then
			local f = fs.open(fullPath, "r")
			local content = f.readAll()
			f.close()
			local processed = content:gsub("^return%s+", "")
			diskGates = textutils.unserialize(processed) or {}
		end
		local exportData = {}
		for k, v in pairs(entryData) do
			if k ~= "isRedial" and k ~= "order" and k ~= "isIntergalactic" then
				exportData[k] = v
			end
		end
		diskGates[entryName] = exportData
		local f = fs.open(fullPath, "w")
		if f then
			f.write("return " .. textutils.serialize(diskGates))
			f.close()
			Logger.log("Saved " .. entryName .. " to Disk", "")
		end
	end
	local function getDiskData()
		for _, side in ipairs(peripheral.getNames()) do
			if peripheral.getType(side) == "drive" and disk.isPresent(side) then
				local mountPath = disk.getMountPath(side)
				if mountPath then
					local fullPath = fs.combine(mountPath, "gates.lua")
					if fs.exists(fullPath) then
						local f = fs.open(fullPath, "r")
						local content = f.readAll()
						f.close()
						local processed = content:gsub("^return%s+", "")
						return textutils.unserialize(processed) or {}, true
					end
					return {}, true
				end
			end
		end
		return nil, false
	end
	local function importEntry(name, data)
		local function finalizeImport(isIntergalactic)
			local existing = Gates[name]
			local newEntry = {}
			for k, v in pairs(data) do newEntry[k] = v end
			newEntry.isIntergalactic = isIntergalactic
			if existing then
				newEntry.order = existing.order
				newEntry.isRedial = existing.isRedial
				Logger.log("Updated: " .. name, "")
			else
				local usedOrders = {}
				for _, gate in pairs(Gates) do
					if gate.order then
						usedOrders[gate.order] = true
					end
				end
				local nextFreeOrder = 1
				while usedOrders[nextFreeOrder] do
					nextFreeOrder = nextFreeOrder + 1
				end
				newEntry.order = nextFreeOrder
				newEntry.isRedial = false
				Logger.log("Imported: " .. name, "")
			end
			Gates[name] = newEntry
			saveAddressBook()
			self.updateEnergyCache(name)
			ui.closeWindow()
		end
		ui.openWindow({
			title = "Dimension Check",
			customRender = function()
				display.setCursorPos(13, 7)
				display.setTextColor(colors.white)
				display.setBackgroundColor(colors.black)
				display.write("Is this gate in another dimension?")
				
				display.setCursorPos(15, 10)
				display.setBackgroundColor(colors.red)
				display.write("  YES  ")
				ui.registerArea(15, 10, 7, 1, function() finalizeImport(true) end)
				
				display.setCursorPos(28, 10)
				display.setBackgroundColor(colors.green)
				display.write("  NO   ")
				ui.registerArea(28, 10, 7, 1, function() finalizeImport(false) end)
			end
		}, { frame = colors.gray, title = colors.blue, text = colors.white })
	end
	local function openDiskBrowser()
		local diskPage = 1
		local itemsPerPage = 10
		local deleteConfirm = nil 
		local function renderDiskContent()
			local diskGates, driveAvailable = getDiskData()
		
			if not driveAvailable then
				display.setCursorPos(21, 9)
				display.setTextColor(colors.red)
				display.write("NO DISK DETECTED")
				return
			end
			local sortedDiskNames = {}
			for name in pairs(diskGates) do table.insert(sortedDiskNames, name) end
			table.sort(sortedDiskNames)
			local totalPages = math.max(1, math.ceil(#sortedDiskNames / itemsPerPage))
			local startIdx = ((diskPage - 1) * itemsPerPage) + 1
			local endIdx = math.min(startIdx + itemsPerPage - 1, #sortedDiskNames)
			display.setCursorPos(12, 4)
			display.setBackgroundColor(colors.blue)
			display.setTextColor(colors.white)
			display.write(" ADDRESS NAME         STATUS     OPT  ")
			for i = startIdx, endIdx do
				local name = sortedDiskNames[i]
				local diskEntry = diskGates[name]
				local y = 5 + (i - startIdx)
				local status = getSyncStatus(name, diskEntry)
				display.setCursorPos(12, y)
				display.setBackgroundColor(i % 2 == 0 and colors.gray or colors.lightGray)
				display.setTextColor(colors.white)
				display.write(string.format(" %-19s", name:sub(1,19)))
				display.setBackgroundColor(colors.gray)
				display.setCursorPos(32, y)
				if status == "[*]" then
					display.setTextColor(colors.green)
					display.write(" SYNCED  ")
				elseif status == "[-]" then
					display.setTextColor(colors.yellow)
					display.write(" MODIFIED")
				else
					display.setTextColor(colors.lightGray)
					display.write(" MISSING ")
				end
				ui.registerArea(12, y, 29, 1, function()
					importEntry(name, diskEntry)
					deleteConfirm = nil
				end)
				display.setCursorPos(41, y)
				if deleteConfirm == name then
					display.setBackgroundColor(colors.red)
					display.setTextColor(colors.white)
					display.write(" CONFIRM ")
					ui.registerArea(41, y, 9, 1, function()
						local driveSide = nil
						for _, side in ipairs(peripheral.getNames()) do
							if peripheral.getType(side) == "drive" and disk.isPresent(side) then driveSide = side; break end
						end
						if driveSide then
							local mountPath = disk.getMountPath(driveSide)
							local fullPath = fs.combine(mountPath, "gates.lua")
							diskGates[name] = nil
							local f = fs.open(fullPath, "w")
							f.write("return " .. textutils.serialize(diskGates))
							f.close()
							deleteConfirm = nil
						end
					end)
				else
					display.setBackgroundColor(colors.black)
					display.setTextColor(colors.red)
					display.write(" DELETE  ")
					ui.registerArea(41, y, 9, 1, function() deleteConfirm = name end)
				end
			end
			display.setCursorPos(12, 17)
			display.setBackgroundColor(colors.lightGray)
			display.write(string.rep(" ", 38))
			display.setCursorPos(12, 17)
			display.setBackgroundColor(colors.green)
			display.setTextColor(colors.black)
			display.write(" [ DUMP LOCAL ADDRESS ] ")
			ui.registerArea(12, 17, 24, 1, function()
				local rawAddr = stargate.getStargateAddress()
				local driveSide = nil
				for _, side in ipairs(peripheral.getNames()) do
					if peripheral.getType(side) == "drive" and disk.isPresent(side) then driveSide = side; break end
				end
				if driveSide and rawAddr then
					local dumpName = config.gateName
					local mountPath = disk.getMountPath(driveSide)
					local fullPath = fs.combine(mountPath, "gates.lua")
					
					local function convertToIds(addressTable, gType)
						local idTable = {}
						if not addressTable then return idTable end
						for _, gName in ipairs(addressTable) do
							local id = ui.nameToId(gType, gName, glyph_data)
							table.insert(idTable, tonumber(id) or gName)
						end
						return idTable
					end

					local diskData = getDiskData()
					diskData[dumpName] = {
						name = dumpName,
						addresses = {
							MilkyWay = convertToIds(rawAddr.milkyway, "MilkyWay"),
							Pegasus = convertToIds(rawAddr.pegasus, "Pegasus"),
							Universe = convertToIds(rawAddr.universe, "Universe")
						},
						gateType = stargate.getGateType(),
						isIntergalactic = (#(rawAddr.universe or {}) > 7),
						irisCode = ""
					}
					local f = fs.open(fullPath, "w")
					f.write("return " .. textutils.serialize(diskData))
					f.close()
				end
			end)
			display.setBackgroundColor(colors.blue)
			display.setBackgroundColor(colors.blue)
			display.setTextColor(colors.white)
			display.setCursorPos(38, 17)
			display.write(" < ")
			ui.registerArea(38, 17, 3, 1, function() if diskPage > 1 then diskPage = diskPage - 1 end end)
			display.setCursorPos(42, 17)
			display.write(" > ")
			ui.registerArea(42, 17, 3, 1, function() if diskPage < totalPages then diskPage = diskPage + 1 end end)
			display.setCursorPos(46, 17)
			display.setBackgroundColor(colors.red)
			display.write(" X ")
			ui.registerArea(46, 17, 4, 1, function() ui.closeWindow() end)
		end
		ui.openWindow({
			title = "External Storage Manager",
			customRender = renderDiskContent
		}, { frame = colors.gray, title = colors.blue, text = colors.white })
	end
	local function openScannerWindow()
		local scanPage = 1
		local itemsPerPage = 5
		local flatGates = {}
		local hasScanned = false
		local isFullScan = false
		local lastRawResults = {}
		local function getNormalizedCategory(gType)
			if gType == "Pegasus" then return "Pegasus" end
			if gType == "Universe" then return "Universe" end
			return "MilkyWay"
		end
		local function doScan()
			display.setCursorPos(15, 8)
			display.setTextColor(colors.yellow)
			display.setBackgroundColor(colors.black)
			display.write("Scanning Network...    ")		
			local results = stargate.getNearbyGates("", true, not isFullScan)
			if type(results) ~= "table" then
				local _, _, backup = stargate.getNearbyGates("", true, not isFullScan)
				results = backup
			end		
			lastRawResults = results
			flatGates = {}
			if type(results) == "table" then
				local typeCounters = { MilkyWay = 0, Pegasus = 0, Universe = 0 }
				local tempSort = {}
				for gType, gates in pairs(results) do
					for addrTable, distance in pairs(gates) do
						if type(addrTable) == "table" then
							table.insert(tempSort, {
								gType = gType,
								addrTable = addrTable,
								distance = distance
							})
						end
					end
				end
				table.sort(tempSort, function(a, b) return a.distance < b.distance end)
				for _, entry in ipairs(tempSort) do
					local saveCategory = getNormalizedCategory(entry.gType)
					typeCounters[saveCategory] = typeCounters[saveCategory] + 1
					local incrementalName = saveCategory .. "_" .. typeCounters[saveCategory]
					local ids = {}
					for _, glyphName in ipairs(entry.addrTable) do
						local id = ui.nameToId(saveCategory, glyphName, glyph_data)
						if id then 
							table.insert(ids, tonumber(id)) 
						else
							id = ui.nameToId("MilkyWay", glyphName, glyph_data)
							if id then table.insert(ids, tonumber(id)) end
						end
					end
					local isSaved = false
					for name, gateEntry in pairs(Gates) do
						local savedIds = gateEntry.addresses and (gateEntry.addresses[saveCategory] or gateEntry.addresses["MilkyWay"])
						if savedIds and #savedIds == #ids then
							local match = true
							for i = 1, #savedIds do
								if savedIds[i] ~= ids[i] then match = false; break end
							end
							if match then isSaved = true; break end
						end
					end
					table.insert(flatGates, {
						gateType = entry.gType,
						saveCategory = saveCategory,
						incrementalName = incrementalName,
						ids = ids,
						distance = entry.distance,
						isSaved = isSaved
					})
				end
			end
			hasScanned = true
		end
		local function renderScannerContent()
			if not hasScanned then doScan() end
			if #flatGates == 0 then
				display.setCursorPos(15, 8)
				display.setTextColor(colors.red)
				display.setBackgroundColor(colors.black)
				display.write("NO GATES FOUND")
			else
				local totalPages = math.max(1, math.ceil(#flatGates / itemsPerPage))
				local startIdx = ((scanPage - 1) * itemsPerPage) + 1
				local endIdx = math.min(startIdx + itemsPerPage - 1, #flatGates)
				for i = startIdx, endIdx do
					local gate = flatGates[i]
					local y = 5 + ((i - startIdx) * 2)
					display.setCursorPos(13, y)
					display.setBackgroundColor(colors.gray)
					display.setTextColor(colors.white)
					local rowText = string.format("%s (%s)", gate.incrementalName, gate.distance)
					display.write(string.format(" %-24s", rowText:sub(1,24)))
					if gate.isSaved then
						display.setTextColor(colors.green)
						display.write("[*] ")
					else
						display.write("    ")
					end
					display.setCursorPos(42, y)
					display.setBackgroundColor(gate.isSaved and colors.lightGray or colors.blue)
					display.setTextColor(gate.isSaved and colors.gray or colors.white)
					display.write(" SAVE ")
					if not gate.isSaved then
						ui.registerArea(42, y, 6, 1, function()
							local newName = ui.inputKeyboard("Save Address", "Enter Name", 12, 4, 14, gate.incrementalName)
							if newName and newName ~= "" then
								local newEntry = {
									name = newName,
									addresses = {
										MilkyWay = {},
										Pegasus = {},
										Universe = {}
									},
									isIntergalactic = (#gate.ids > 7),
									gateType = gate.saveCategory,
									irisCode = ""
								}
								newEntry.addresses[gate.saveCategory] = gate.ids
								local maxOrder = 0
								for _, g in pairs(Gates) do
									if g.order and g.order > maxOrder then maxOrder = g.order end
								end
								newEntry.order = maxOrder + 1
								Gates[newName] = newEntry
								if type(saveAddressBook) == "function" then 
									saveAddressBook() 
								end
								gate.isSaved = true
							end
						end)
					end
				end
				display.setTextColor(colors.white)
				if scanPage > 1 then
					display.setCursorPos(13, 16)
					display.setBackgroundColor(colors.blue)
					display.write(" < ")
					ui.registerArea(13, 16, 3, 1, function() scanPage = scanPage - 1 end)
				end
				if scanPage < totalPages then
					display.setCursorPos(17, 16)
					display.setBackgroundColor(colors.blue)
					display.write(" > ")
					ui.registerArea(17, 16, 3, 1, function() scanPage = scanPage + 1 end)
				end
			end
			display.setCursorPos(21, 16)
			display.setBackgroundColor(colors.red)
			display.setTextColor(colors.white)
			display.write(" FULL SCAN ")
			ui.registerArea(21, 16, 11, 1, function()
				isFullScan = true
				hasScanned = false
				scanPage = 1
			end)
			if config.debug then
				display.setCursorPos(33, 16)
				display.setBackgroundColor(colors.yellow)
				display.setTextColor(colors.black)
				display.write(" DEBUG DUMP ")
				ui.registerArea(33, 16, 12, 1, function()
					local f = fs.open("scan_dump.txt", "w")
					f.write(textutils.serialize(lastRawResults))
					f.close()
				end)
			end
		end
		ui.openWindow({
			title = "Network Scanner",
			customRender = renderScannerContent
		}, {
			frame = colors.lightGray,
			title = colors.blue,
			text = colors.white
		})
	end	
	local function drawThemeContent()
		local items = {
			{key = "theme1",   label = "Accent 1"},{key = "theme2",   label = "Accent 2"},{key = "themep",   label = "Power Fill"},
			{key = "themecsb", label = "Chevron Bar"},{key = "thement",  label = "Header Text"},{key = "themept",  label = "Page Text"},
			{key = "themepwt", label   = "Power % Text"},{key = "themecst", label = "Chevron Text"},{key = "thememt",  label = "Bar Text"},
			{key = "themelb",  label = "Log BG"},{key = "themelt",  label = "Log Text"},{key = "themecdt", label = "Dim. Text"},
			{key = "themese",  label = "Selected Row"},{key = "themesb",  label = "Address BG"}
		}
		for i, item in ipairs(items) do
			local y = 3 + i
			if y > 17 then break end
			local isSelected = (i == selectedThemeIdx)
			display.setCursorPos(13, y)
			display.setBackgroundColor(isSelected and colors.blue or colors.black)
			display.setTextColor(isSelected and colors.white or colors.gray)
			display.write(string.format(" %-12s ", item.label))
			display.setBackgroundColor(config.theme[item.key] or colors.black)
			display.write("  ")
			ui.registerArea(13, y, 16, 1, function() selectedThemeIdx = i end)
		end
		local colorList = {1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768}
		local startX, startY = 32, 5
		for i, colorVal in ipairs(colorList) do
			local x = startX + ((i-1) % 4) * 4
			local y = startY + math.floor((i-1) / 4) * 2
			display.setCursorPos(x, y)
			display.setBackgroundColor(colorVal)
			display.write("    ")
			display.setCursorPos(x, y+1)
			display.write("    ")
			ui.registerArea(x, y, 4, 2, function()
				config.theme[items[selectedThemeIdx].key] = colorVal
				saveOptions()
				ui.clear()
				self.renderMenu()
			end)
		end
		display.setCursorPos(32, 16)
		display.setBackgroundColor(colors.black)
		display.setTextColor(colors.yellow)
		display.write("Select a color")
	end
	local function irisToggle ()
        config.irisMode = (config.irisMode % 3) + 1
        stargate.irisMode = config.irisMode
        local irisStatus = stargate.getStatusString()
        if config.irisMode == 1 and irisStatus == "CLOSED" then
            stargate.toggleIris() 
        elseif config.irisMode == 3 and irisStatus == "OPENED" then
            stargate.toggleIris() 
        end
        saveOptions()
        self.renderMenu()
    end
	local function moveEntryOrder(entry, direction)
		local currentOrder = entry.order or 1
		local targetOrder = currentOrder + direction
		if targetOrder < 1 then return end
		local swapEntryName = nil
		local maxOrder = 0
		for name, data in pairs(Gates) do
			if data.order == targetOrder then swapEntryName = name end
			if (data.order or 0) > maxOrder then maxOrder = data.order end
		end
		if direction > 0 and targetOrder > maxOrder then return end
		if swapEntryName then
			Gates[swapEntryName].order = currentOrder
		end
		entry.order = targetOrder
		saveAddressBook()
		ui.clear()
        self.renderMenu()
	end
	local function addNewEntry()
		local entryData = {
			name = "New Gate",
			addresses = { MilkyWay = {}, Pegasus = {}, Universe = {} },
			isIntergalactic = false,
			irisCode = "",
			gateType = getGateTypeLabel()
		}
		local function renderNewContent()
			local gateColors = { MilkyWay = colors.orange, Pegasus = colors.cyan, Universe = colors.white }
			display.setCursorPos(13, 4)
			display.setBackgroundColor(colors.lightGray)
			display.setTextColor(colors.white)
			display.write(string.format(" NAME: %-21s ", entryData.name:sub(1,21)))
			ui.registerArea(13, 4, 28, 1, function()
				local res = ui.inputKeyboard("New Entry", "Enter Name", 12, 4, 14, entryData.name)
				if res and res ~= "" then entryData.name = res end
			end)
			local function getAddrStr(t) 
				local a = entryData.addresses[t]
				if a and #a > 0 then
					local formatted = {}
					for _, v in ipairs(a) do
						table.insert(formatted, string.format("%2d", v))
					end
					return table.concat(formatted, ":")
				else
					return "--:--:--:--:--:--:--:--"
				end
			end
			local addrTypes = {{"MilkyWay", colors.orange, "MW"}, {"Pegasus", colors.cyan, "PG"}, {"Universe", colors.white, "UN"}}
			for i, info in ipairs(addrTypes) do
				local y = 5 + i 
				display.setCursorPos(13, y)
				display.setBackgroundColor(info[2])
				display.setTextColor(colors.black)
				display.write(string.format(" %s: %-23s ", info[3], getAddrStr(info[1]):sub(1, 23)))
				ui.registerArea(13, y, 28, 1, function()
					local res = ui.inputNumpad(info[1], "Enter Address", entryData.addresses[info[1]], true)
					if res then entryData.addresses[info[1]] = res end
				end)
			end
			display.setBackgroundColor(entryData.isIntergalactic and colors.blue or colors.gray)
			display.setTextColor(colors.white)
			display.setCursorPos(13, 10) display.write("             ") 
			display.setCursorPos(13, 11) display.write(entryData.isIntergalactic and "[DIMENSIONAL]" or "[   LOCAL   ]")
			ui.registerArea(13, 10, 13, 2, function()
				entryData.isIntergalactic = not entryData.isIntergalactic
			end)
			local detType = getGateTypeLabel()
			display.setBackgroundColor(colors.green)
			display.setTextColor(colors.black)
			display.setCursorPos(31, 10) display.write(" DHD Entry ")
			display.setCursorPos(31, 11) display.write(" " .. string.format("%-9s", detType:sub(1,9)) .. " ")
			ui.registerArea(31, 10, 11, 2, function()
				local IDs = ui.inputGlyphAddress(stargate, detType, 12, 4)
				if IDs then entryData.addresses[detType] = IDs end
			end)
			local savedType = entryData.gateType
			display.setBackgroundColor(gateColors[savedType] or colors.gray)
			display.setTextColor(colors.black)
			display.setCursorPos(13, 13) display.write(" GateType: ")
			display.setCursorPos(13, 14) display.write(" " .. string.format("%-9s", savedType) .. " ")
			ui.registerArea(13, 13, 11, 2, function()
				local types = {"MilkyWay", "Pegasus", "Universe"}
				local curIdx = 1
				for i, t in ipairs(types) do if t == savedType then curIdx = i end end
				entryData.gateType = types[(curIdx % #types) + 1]
			end)
			display.setBackgroundColor(colors.blue)
			display.setTextColor(colors.white)
			display.setCursorPos(25, 13) display.write(" IDC CODE ")
			display.setCursorPos(25, 14) display.write(" " .. string.format("%-8s", entryData.irisCode) .. " ")
			ui.registerArea(25, 13, 10, 2, function()
				entryData.irisCode = ui.inputNumpad("Security", "Enter IDC", entryData.irisCode, false)
			end)
			display.setBackgroundColor(colors.green)
			display.setTextColor(colors.black)
			display.setCursorPos(13, 16) display.write(" [ SAVE NEW ENTRY ] ")
			display.setCursorPos(13, 17) display.write("   ADD TO ADDRESSES ")
			ui.registerArea(13, 16, 20, 2, function()
				if not Gates[entryData.name] then
					local nextOrder = 1
					local used = {}
					for _, g in pairs(Gates) do if g.order then used[g.order] = true end end
					while used[nextOrder] do nextOrder = nextOrder + 1 end
					entryData.order = nextOrder
					Gates[entryData.name] = entryData
					saveAddressBook()
					selectedAddress = entryData.name
					ui.closeWindow()
				end
			end)
			display.setBackgroundColor(colors.red)
			display.setTextColor(colors.white)
			display.setCursorPos(35, 16) display.write("  CANCEL  ")
			display.setCursorPos(35, 17) display.write("  DISCARD ")
			ui.registerArea(35, 16, 10, 2, function() ui.closeWindow() end)
		end
		ui.openWindow({ title = "Create New Entry", customRender = renderNewContent }, 
		{ frame = colors.gray, title = colors.blue, text = colors.white, close = colors.red })
		ui.clear()
		self.renderMenu()
	end
	local function editEntry()
		local entry = Gates[selectedAddress]
		if not entry then return end 
		if not entry.addresses then entry.addresses = {} end
		local entryData = entry
		local deleteConfirm = false
		local function renderEditContent()
			local textCol = colors.white
			local diskGates, driveAvailable = getDiskData()
			local gateColors = { MilkyWay = colors.orange, Pegasus = colors.cyan, Universe = colors.white }
			local exportLabel = ""
			local labelColor = colors.white

			if not driveAvailable then
				exportLabel = "NO DRIVE"
				labelColor = colors.red
			else
				local diskEntry = diskGates and diskGates[selectedAddress]
				if not diskEntry then
					exportLabel = "MISSING"
					labelColor = colors.yellow
				else
					local status = getSyncStatus(selectedAddress, diskEntry)
					if status == "[*]" then
						exportLabel = "SYNCED"
						labelColor = colors.green
					else
						exportLabel = "MODIFIED"
						labelColor = colors.orange
					end
				end
			end
			display.setCursorPos(13, 4)
			display.setBackgroundColor(colors.lightGray)
			display.setTextColor(colors.white)
			display.write(string.format(" NAME: %-21s ", selectedAddress:sub(1,21)))
			ui.registerArea(13, 4, 28, 1, function()
				local newName = ui.inputKeyboard("Rename", "Enter Name", 12, 4, 14, entry.name)
				if newName and newName ~= "" and newName ~= selectedAddress then
					energyCache[selectedAddress] = nil
					Gates[newName] = entry
					Gates[selectedAddress] = nil
					selectedAddress = newName
					entry.name = newName
					energyCache[newName] = nil
					saveAddressBook()
				end
			end)
			local function getAddrStr(t) 
				local a = entry.addresses[t]
				if a and #a > 0 then
					local formatted = {}
					for _, v in ipairs(a) do
						table.insert(formatted, string.format("%2d", v))
					end
					return table.concat(formatted, ":")
				else
					return "--:--:--:--:--:--:--:--"
				end
			end
			local addrTypes = {
				{"MilkyWay", colors.orange, "MW"}, 
				{"Pegasus", colors.cyan, "PG"}, 
				{"Universe", colors.white, "UN"}
			}
			for i, info in ipairs(addrTypes) do
				local y = 5 + i 
				display.setCursorPos(13, y)
				display.setBackgroundColor(info[2])
				display.setTextColor(colors.black)
				display.write(string.format(" %s: %-23s ", info[3], getAddrStr(info[1]):sub(1, 23)))
				ui.registerArea(13, y, 28, 1, function()
					local res = ui.inputNumpad(info[1], "Enter Address", entry.addresses[info[1]], true)
					if res then 
						entry.addresses[info[1]] = res
						energyCache[selectedAddress] = nil
						saveAddressBook() 
					end
				end)
			end
			display.setBackgroundColor(entry.isIntergalactic and colors.blue or colors.gray)
			display.setTextColor(textCol)
			display.setCursorPos(13, 10) display.write("             ") 
			display.setCursorPos(13, 11) display.write(entry.isIntergalactic and "[DIMENSIONAL]" or "   [LOCAL]   ")
			ui.registerArea(13, 10, 13, 2, function()
				entry.isIntergalactic = not entry.isIntergalactic
				energyCache[selectedAddress] = nil
				saveAddressBook()
			end)
			local detType = getGateTypeLabel()
			display.setBackgroundColor(colors.green)
			display.setTextColor(colors.black)
			display.setCursorPos(27, 10) display.write(" DHD Entry ")
			display.setCursorPos(27, 11) display.write(" " .. string.format("%-9s", detType:sub(1,9)) .. " ")
			ui.registerArea(27, 10, 11, 2, function()
				local IDs = ui.inputGlyphAddress(stargate, detType, 12, 4)
				if IDs then entry.addresses[detType] = IDs; saveAddressBook() end
			end)
			if config.debug then
				display.setBackgroundColor(colors.yellow)
				display.setTextColor(colors.black)
				display.setCursorPos(39, 10) display.write("RECALC")
				display.setCursorPos(39, 11) display.write("ENERGY")
				ui.registerArea(39, 10, 6, 2, function()
					energyCache[selectedAddress] = nil
					self.updateEnergyCache(selectedAddress)
					Logger.log("Recalculated: " .. selectedAddress, "SYS")
				end)
			end
			display.setTextColor(colors.black)
			display.setBackgroundColor(colors.lightGray)
			display.setCursorPos(45, 5) display.write("  ")
			display.setCursorPos(44, 6) display.write("    ")
			display.setCursorPos(43, 7) display.write("  UP  ")
			display.setCursorPos(45, 8) display.write("  ")
			display.setCursorPos(45, 9) display.write("  ")
			ui.registerArea(43, 5, 7, 5, function() moveEntryOrder(entry, -1) end)
			display.setBackgroundColor(colors.gray)
			display.setTextColor(colors.black)
			display.setCursorPos(45, 12) display.write("  ")
			display.setCursorPos(45, 13) display.write("  ")
			display.setCursorPos(43, 14) display.write(" DOWN ")
			display.setCursorPos(44, 15) display.write("    ")
			display.setCursorPos(45, 16) display.write("  ")
			ui.registerArea(43, 11, 7, 6, function() moveEntryOrder(entry, 1) end)
			local savedType = entry.gateType or "Error"
			display.setBackgroundColor(gateColors[savedType] or colors.gray)
			display.setTextColor(colors.black)
			display.setCursorPos(13, 13) display.write("GateType:")
			display.setCursorPos(13, 14) display.write("" .. string.format("%-9s", savedType) .. "")
			ui.registerArea(13, 13, 9, 2, function()
				local types = {"MilkyWay", "Pegasus", "Universe"}
				local curIdx = 1
				for i, t in ipairs(types) do if t == savedType then curIdx = i end end
				entry.gateType = types[(curIdx % #types) + 1]
				energyCache[selectedAddress] = nil
				saveAddressBook()
			end)
			display.setBackgroundColor(colors.blue)
			display.setTextColor(colors.white)
			display.setCursorPos(23, 13) display.write("IDC CODE ")
			display.setCursorPos(23, 14) display.write("" .. string.format("%-8s", entry.irisCode or "NONE") .. " ")
			ui.registerArea(23, 13, 9, 2, function()
				entry.irisCode = ui.inputNumpad("Security", "Enter IDC", entry.irisCode, false)
				saveAddressBook()
			end)
			display.setBackgroundColor(entry.isRedial and colors.red or colors.gray)
			display.setCursorPos(33, 13) display.write(" REDSTONE")
			display.setCursorPos(33, 14) display.write(" DIAL:" .. (entry.isRedial and "ON " or "OFF"))
			ui.registerArea(33, 13, 11, 2, function()
				local newState = not entry.isRedial
				for _, data in pairs(Gates) do data.isRedial = false end
				entry.isRedial = newState; saveAddressBook()
			end)
			display.setBackgroundColor(colors.green)
			display.setTextColor(colors.black)
			display.setCursorPos(13, 16) display.write("[SAVE]")
			display.setCursorPos(13, 17) display.write(" DATA ")
			ui.registerArea(13, 16, 6, 2, function()
				saveAddressBook()
				ui.closeWindow()
			end)
			display.setBackgroundColor(colors.gray)
			display.setTextColor(colors.white)
			display.setCursorPos(23, 16)
			display.write("[EXPORT]")
			display.setCursorPos(23, 17)
			display.setTextColor(labelColor)
			display.write("" .. string.format("%-8s", exportLabel) .. "")
			if driveAvailable then ui.registerArea(23, 16, 8, 2, function() exportEntryToDisk(selectedAddress, entry) end) end
			display.setBackgroundColor(deleteConfirm and colors.red or colors.gray)
			display.setTextColor(deleteConfirm and colors.white or colors.red)
			display.setCursorPos(33, 16) display.write("[DELETE]")
			display.setCursorPos(33, 17) display.write(deleteConfirm and " SURE?  " or " REMOVE ")
			ui.registerArea(33, 16, 8, 2, function()
				if deleteConfirm then
					local deletedOrder = entry.order or 999
					Gates[selectedAddress] = nil
					for name, data in pairs(Gates) do
						if data.order and data.order > deletedOrder then data.order = data.order - 1 end
					end
					saveAddressBook()
					selectedAddress = next(Gates)
					ui.closeWindow()
				else
					deleteConfirm = true
				end
			end)
		end
		ui.openWindow({ title = "Gate Configuration", customRender = renderEditContent }, 
		{ frame = colors.gray, title = colors.blue, text = colors.white, close = colors.red })
		ui.clear(); self.renderMenu()
	end
	local function drawGate()
		if ui.activeWindow ~= nil then return end
		local gateX, gateY = w - 20, 12
		local irisState = stargate.getStatusString()
		local irisTypeTable = stargate.getIrisType()
		local irisMaterial = type(irisTypeTable) == "table" and irisTypeTable[1] or irisTypeTable
		local isAnimating = GateRenderer.draw(
			dialingState.lockedStr, 
			localType, 
			gateX, 
			gateY, 
			gateOpen,
			irisState, 
			irisMaterial, 
			stargate.glyphID()
		)
		self.isAnimating = isAnimating
	end	
	function self.renderMenu()	
		sortedKeys = {}
        local gateColors = { MilkyWay = colors.orange, Pegasus = colors.cyan, Universe = colors.white, Tollan = colors.cyan, Movie = colors.orange }
        local activeColor = gateColors[localType] or colors.orange
		local energy = stargate.getEnergy()
		local theme1, theme2 = config.theme.theme1, config.theme.theme2
		local themep, themecsb = config.theme.themep, config.theme.themecsb
		local thement, themept = config.theme.thement, config.theme.themept
		local themepwt, themecst = config.theme.themepwt, config.theme.themecst
		local thememt, themelb = config.theme.thememt, config.theme.themelb
		local themelt, themecdt = config.theme.themelt, config.theme.themecdt
		local themese, themesb = config.theme.themese, config.theme.themesb
		local maxEnergy = stargate.getMaxEnergy()
		local totalGates = #sortedKeys
		local totalPages = math.max(1, math.ceil(#sortedKeys / 16))
		local energyPercent = math.max(0, math.min(1, energy / maxEnergy))
		local irisTypeTable = stargate.getIrisType()
		local irisMaterial = type(irisTypeTable) == "table" and irisTypeTable[1] or irisTypeTable
		local hasIris = (irisMaterial ~= nil and irisMaterial ~= "NONE" and irisMaterial ~= "")
		local irisLabel = (irisMaterial == "SHIELD") and "shield" or " iris "
		local fillWidth = math.floor(energyPercent * 20)
		local drainX = nil
		for name in pairs(Gates) do table.insert(sortedKeys, name) end
		if selectedAddress and energyCache[selectedAddress] then
			local costTable = energyCache[selectedAddress]
			local costPercent = costTable.open / maxEnergy
			drainX = math.floor((energyPercent - costPercent) * 19)
			if drainX < 1 then drainX = 1 end
		end
		local barText = string.format("Power %d%%", math.floor(energyPercent * 100))
		local textX = 1
		if drainX and drainX < 10 then
			textX = 10
		end
		display.setCursorPos(1, 2)
		for i = 1, 19 do
			if i <= fillWidth then
				display.setBackgroundColor(config.theme.themep)
				display.setTextColor(config.theme.themepwt)
			else
				display.setBackgroundColor(config.theme.theme2)
				display.setTextColor(colors.gray)
			end
			local char = " "
			if drainX and i == drainX then
				char = "|"
				display.setBackgroundColor(config.theme.themep)
				display.setTextColor(config.theme.themepwt)
			elseif i >= textX and i < textX + #barText then
				char = barText:sub(i - textX + 1, i - textX + 1)
			end
			display.write(char)
		end
        display.setBackgroundColor(config.theme.theme1)
		display.setTextColor(config.theme.thement)
		display.setCursorPos(1, 1)
		display.write("GateOS | " .. config.gateName .. string.rep(" ", w - 15))
		display.setCursorPos(22, 1) 
		display.setTextColor(config.theme.thememt)
		display.write("[New] ")
		ui.registerArea(22, 1, 5, 1, addNewEntry)
		if selectedAddress and Gates[selectedAddress] then
			display.setCursorPos(28, 1)
			display.write("[Edit] ")
			ui.registerArea(28, 1, 6, 1, editEntry)
		else
			display.setCursorPos(28, 1)
			display.write("       ")
		end
		display.setCursorPos(35, 1)
		display.write("[Options] ")
		ui.registerArea(35, 1, 9, 1, function() self.openOptions() end)
		if quitConfirmed then
			display.setTextColor(colors.red)
		else
			display.setTextColor(config.theme.thememt)
		end
		display.setCursorPos(45, 1)
		display.write("[Quit] ")
		ui.registerArea(45, 1, 6, 1, function() 
			if quitConfirmed then
				self.running = false
			else
				quitConfirmed = true
				quitTimer = os.startTimer(10)
				self.renderMenu()
			end
		end)
		display.setCursorPos(28, 16) 
		display.setBackgroundColor(colors.black)
		display.setTextColor(colors.black)
		display.write("Reserved")
		display.setCursorPos(28, 17) 
		display.write("       ")
		display.setCursorPos(35, 16) 
		if isBusy then
			display.setBackgroundColor(colors.lightGray)
			display.setTextColor(colors.gray)
			display.write("      ")
			display.setCursorPos(35, 17) 
			display.write(" BUSY ") 
		else
			display.setBackgroundColor(dialingState.active and colors.red or colors.blue) 
			display.setTextColor(colors.white)
			display.write("      ") 
			display.setCursorPos(35, 17) 
			display.write(dialingState.active and " ABORT"  or " DIAL ") 
		end
		ui.registerArea(35, 16, 8, 2, function()
		if dialingState.active then
			isBusy = true
			local duration = (localType == "Universe") and 8 or 2
			busyTimer = os.startTimer(duration)
			stargate.disengage()
			dialingState.active = false
			dialingState.sequence = ""
			dialingState.lockedStr = ""
			Logger.log("Dialing Aborted", "SYS")
			self.renderMenu()
			return 
		end
		if isBusy then 
			Logger.log("Gate is Busy", "ERR")
			return 
		end	
		if selectedAddress and Gates[selectedAddress] then
			local entry = Gates[selectedAddress]
			local success, err = stargate.onDialAddress(entry, energyCache[selectedAddress])
			if success then
				dialingState.active = true
				local duration = (localType == "Universe") and 8 or 4
				busyTimer = os.startTimer(duration)
				Logger.log("Dialing: " .. selectedAddress, "")
			else
				dialingState.active = false
				Logger.log("Dial Fail: " .. (err or "Unknown"), "")
			end
		end
		self.renderMenu()
	end)
		display.setBackgroundColor(colors.gray)
		display.setCursorPos(22, 16)
		if not hasIris then
			display.setBackgroundColor(colors.lightGray)
			display.setTextColor(colors.gray)
			display.write("" .. irisLabel .. "")
			display.setCursorPos(22, 17)
			display.write(" NONE ")
		else
			local modeColors = { colors.green, colors.yellow, colors.red }
			local modeLabels = { " OPEN ", " AUTO ", "CLOSED" }
			local currentMode = config.irisMode or 1
			display.setBackgroundColor(modeColors[currentMode])
			display.setTextColor(colors.black)
			display.write("" .. irisLabel .. "")
			display.setCursorPos(22, 17)
			display.write(modeLabels[currentMode])
			ui.registerArea(22, 16, 8, 2, function() irisToggle() end)
		end
		for vLine = 2, 15 do
            display.setCursorPos(22, vLine)
            display.setBackgroundColor(colors.black) display.write(" ")
            display.setCursorPos(40, vLine)
            display.setBackgroundColor(colors.black) display.write(" ")
        end
		for vLine = 2, 17 do
            display.setCursorPos(41, vLine)
            display.setBackgroundColor(config.theme.theme1) display.write(" ")
        end
        for vLine = 2, 19 do
            display.setCursorPos(20, vLine)
            display.setBackgroundColor(config.theme.theme2) display.write(" ")
            display.setBackgroundColor(config.theme.theme1) display.write(" ")
            display.setBackgroundColor(colors.black)
        end display.setCursorPos(1, 19)
		display.setBackgroundColor(config.theme.theme2)
		display.setTextColor(config.theme.themept)
        display.write("<<|             |>>")
		display.setCursorPos(4, 19)
        display.write(string.format("  page %d/%d ", currentPage, totalPages))
        ui.registerArea(1, 19, 3, 1, function()
            if currentPage > 1 then
                currentPage = currentPage - 1
                self.renderMenu()
            end
        end)
        ui.registerArea(17, 19, 3, 1, function()
            if currentPage < totalPages then
                currentPage = currentPage + 1
                self.renderMenu()
            end
        end)
		display.setCursorPos(22, 15) display.setBackgroundColor(colors.black) display.write("                   ")
		display.setCursorPos(22, 18) display.setBackgroundColor(config.theme.theme1) display.write("                              ")
		display.setCursorPos(22, 2) display.setBackgroundColor(colors.black) display.write("                  ")
		table.sort(sortedKeys, function(a, b)
			local orderA = Gates[a].order or 999
			local orderB = Gates[b].order or 999
			return orderA < orderB
		end)
        if currentPage > totalPages then currentPage = totalPages end
        for i = 1, 16 do
            local yPos = 2 + i
            local entryIdx = ((currentPage - 1) * 16) + i
            local nameKey = sortedKeys[entryIdx]
            local entry = nameKey and Gates[nameKey]
            local isSelected = (nameKey == selectedAddress)
            display.setCursorPos(1, yPos)
            if entry then
                display.setBackgroundColor(isSelected and themese or themesb)
				ui.registerArea(1, yPos, 20, 1, function()
					if not dialingState.active then 
						selectedAddress = nameKey
						self.renderMenu() 
					end
				end)
                local function hasAddr(addr) return addr and type(addr) == "table" and #addr > 0 end
                local isM = hasAddr(entry.addresses and entry.addresses.MilkyWay)
                display.setTextColor(isM and colors.orange or colors.lightGray) 
                display.write("M")
                local isU = hasAddr(entry.addresses and entry.addresses.Universe)
                display.setTextColor(isU and colors.white or colors.lightGray) 
                display.write("U")
                local isP = hasAddr(entry.addresses and entry.addresses.Pegasus)
                display.setTextColor(isP and colors.cyan or colors.lightGray) 
                display.write("P")
                display.setTextColor(isSelected and colors.white or colors.gray)
				if entry.isRedial then
					display.setTextColor(colors.red)
				else
					display.setTextColor(isSelected and colors.white or themesb)
				end
                display.write(isSelected and ">" or ".")
                display.setTextColor(gateColors[entry.gateType] or colors.lightGray)
                display.write(nameKey:sub(1, 12)) 
                local currentX = 5 + #nameKey:sub(1, 12)
                display.setBackgroundColor(isSelected and themese or themesb)
                display.write(string.rep(" ", 20 - currentX))
                display.setCursorPos(20, yPos)
                if entry.isIntergalactic then
                    display.setBackgroundColor(config.theme.theme2) 
                    display.setTextColor(config.theme.themecdt) 
                    display.write("D")
                else
                    display.setBackgroundColor(config.theme.theme2) 
                    display.write(" ")
                end
            else
                display.setBackgroundColor(themesb)
                display.write(string.rep(" ", 20))
                display.setCursorPos(20, yPos)
                display.setBackgroundColor(config.theme.theme2)
                display.write(" ")
            end
        end
		display.setCursorPos(22, 19)
		display.setBackgroundColor(config.theme.themelb)
		local lastLine, logCol, logType = Logger.getLastLog()
		if logType == "DEBUG" and not config.debug then
			lastLine = "System Ready"
			logCol = colors.gray
		end
		display.setTextColor(logCol)
		display.write(lastLine .. string.rep(" ", 30 - #lastLine))
		ui.registerArea(23, 19, 30, 1, function()
			Logger.log("Accessing Logs", "SYS")
			viewLogs() 
			display.clear()
			self.renderMenu() 
		end)		
		display.setBackgroundColor(colors.black) 
		for y = 2, 17 do
			display.setCursorPos(42, y)
			display.write("          ")
		end
		local address = stargate.dialQueue or {}
		local currentIdx = stargate.currentDialIndex or 0
		local startX = 44
		local startY = 4
		local spacingX = 5
		local spacingY = 4
		GateRenderer.setTarget(display)
		GateRenderer.init()
		for i = 0, 7 do
			local col = i % 2
			local row = math.floor(i / 2)
			local drawX = startX + (col * spacingX)
			local drawY = startY + (row * spacingY)
			local glyphIdx = i + 1
			local glyphID = address[glyphIdx]
			if glyphID then
				local isLocked = (glyphIdx < currentIdx) or gateOpen
				local isDialing = (glyphIdx == currentIdx) and not gateOpen
				local glyphColor = activeColor
				if isDialing then
					glyphColor = colors.yellow
					glyphID = stargate.glyphID() or glyphID
				elseif not isLocked and not isDialing then
					glyphColor = colors.gray
				end
				Logger.log("Sidebar Slot " .. glyphIdx .. ": ID " .. tostring(glyphID), "SYS")
				local gType = localType or "MilkyWay"
				GateRenderer.drawGlyph(gType, glyphID, drawX, drawY, glyphColor)
			else
				display.setCursorPos(drawX, drawY)
				display.setBackgroundColor(colors.black)
				display.setTextColor(colors.gray)
				display.write(".")
			end
		end
		GateRenderer.render()
		display.setBackgroundColor(colors.black)
	end
	function self.openOptions()
	local function renderOptionsContent()
			local startX = 13
			local startY = 5
			local col1Width = 18
			local col2Width = 17
			local btnHeight = 2
			local releaseList = {}
			local currentReleasePage = 1
			local isFetching = false
			local function getCleanVersion(ver)
				return tostring(ver or ""):gsub("[^%d%.]", "")
			end
			local function isNewer(current, remote)
				local function parse(s)
					local t = {}
					for part in getCleanVersion(s):gmatch("%d+") do
						table.insert(t, tonumber(part))
					end
					return t
				end
				local cParts, rParts = parse(current), parse(remote)
				for i = 1, math.max(#cParts, #rParts) do
					local cV, rV = cParts[i] or 0, rParts[i] or 0
					if rV > cV then return true end
					if cV > rV then return false end
				end
				return false
			end
			local function fetchAllReleases()
				if isFetching then return end
				isFetching = true
				currentReleasePage = 1
				local response = http.get("https://api.github.com/repos/evilcarrotoverlord/gateOS/releases")
				if response then
					local contents = response.readAll()
					response.close()
					local data = textutils.unserialiseJSON(contents)
					releaseList = {}
					if data and type(data) == "table" then
						local currentOSClean = getCleanVersion(_G.OS_VERSION)
						for i, release in ipairs(data) do
							local relName = (release.name or release.tag_name or "Unknown")
							local relClean = getCleanVersion(relName)
							local downloadUrl = nil
							for _, asset in ipairs(release.assets or {}) do
								if asset.name == "installer.lua" then
									downloadUrl = asset.browser_download_url
									break
								end
							end							
							local textColor = colors.white
							local bgColor = colors.gray
							local isCurrent = (relClean == currentOSClean)
							local isActualUpdate = (i == 1 and isNewer(currentOSClean, relClean))
							if isCurrent then textColor = colors.lime end
							if isActualUpdate then
								bgColor = colors.green
								textColor = colors.white
							end
							table.insert(releaseList, {
								label = relName:upper(),
								tColor = textColor,
								bColor = bgColor,
								isCurrent = isCurrent,
								isNewUpdate = isActualUpdate,
								action = function()
									if downloadUrl then
										ui.clear()
										display.setCursorPos(1, 1)
										print("Downloading: " .. relName)
										local res = http.get(downloadUrl)
										if res then
											local f = fs.open("installer.lua", "w")
											f.write(res.readAll())
											f.close()
											res.close()
											if shell then shell.run("installer.lua") else os.run({}, "installer.lua") end
											os.reboot()
										end
									end
								end
							})
						end
					end
				end
				isFetching = false
			end
			local function renderReleaseList()
				local rStartY = 5
				local rStartX = 13
				local btnWidth = 36
				local perPage = 5
				if #releaseList == 0 then
					display.setCursorPos(rStartX, rStartY)
					display.setTextColor(colors.white)
					display.write(isFetching and "Fetching releases..." or "No releases found.")
					return
				end
				local startIndex = (currentReleasePage - 1) * perPage + 1
				local endIndex = math.min(startIndex + perPage - 1, #releaseList)
				for i = startIndex, endIndex do
					local release = releaseList[i]
					display.setCursorPos(rStartX, rStartY)
					display.setBackgroundColor(release.bColor)
					display.setTextColor(release.tColor)
					local tag = ""
					if release.isCurrent then tag = " (CURRENT)"
					elseif release.isNewUpdate then tag = " (UPDATE!)" end
					display.write(string.format(" %-34s", (release.label .. tag):sub(1, 34)))
					ui.registerArea(rStartX, rStartY, btnWidth, 1, function() release.action() end)
					rStartY = rStartY + 2
				end
				local controlY = 15
				if currentReleasePage > 1 then
					display.setCursorPos(rStartX, controlY)
					display.setBackgroundColor(colors.lightGray)
					display.setTextColor(colors.gray)
					display.write(" <<< PREV ")
					ui.registerArea(rStartX, controlY, 10, 1, function() currentReleasePage = currentReleasePage - 1 end)
				end
				if endIndex < #releaseList then
					display.setCursorPos(rStartX + 26, controlY)
					display.setBackgroundColor(colors.lightGray)
					display.setTextColor(colors.gray)
					display.write(" NEXT >>> ")
					ui.registerArea(rStartX + 26, controlY, 10, 1, function() currentReleasePage = currentReleasePage + 1 end)
				end
			end
			local options = {
				{label = "RENAME GATE",	sub = config.gateName or "Gate",
					action = function()
						local newName = ui.inputKeyboard("Rename Gate", "Enter Name", 12, 4, 14)
						if newName and newName ~= "" then
							config.gateName = newName
							saveOptions()
							Logger.log("Gate Renamed", "SYS")
						end
					end
				},
				{label = "SECURITY IDC", sub = "Code: " .. (config.idc or "None"),
					action = function()
						local newCode = ui.inputNumpad("Security Settings", "Enter IDC", "", false)
						if newCode and #newCode > 0 then
							config.idc = newCode
							stargate.idc = newCode
							saveOptions()
						end
					end
				},
				{label = "THEME EDITOR", sub = "UI Colors",
					action = function()
						ui.openWindow({ 
							title = "Theme Editor", 
							customRender = function() drawThemeContent() end 
						}, { frame = colors.gray, title = colors.red, text = colors.white, close = colors.red })
					end
				},
				{
					label = "EXTERNAL DISK",
					sub = (function()
						local _, driveAvailable = getDiskData()
						return driveAvailable and "Storage Mgr" or "NO DISK/DRIVE"
					end)(),
					action = function() 
						local _, driveAvailable = getDiskData()
						if driveAvailable then openDiskBrowser() end 
					end,
					customColors = (function()
						local _, driveAvailable = getDiskData()
						if not driveAvailable then
							return {bg = colors.lightGray, text = colors.red, sub = colors.red}
						end
						return nil
					end)()
				},
				{label = "NET SCANNER",	sub = "Find Gates",
					action = function() openScannerWindow() end
				},
				{label = "OS UPDATES",
					sub = "Check Ver",
					action = function()
						fetchAllReleases()
						ui.openWindow({ 
							title = "GateOS - " .. (_G.OS_VERSION or "v??"), 
							customRender = renderReleaseList 
						}, { frame = colors.gray, title = colors.blue, text = colors.white, close = colors.red })
					end
				}
			}
			for i, opt in ipairs(options) do
				local isCol2 = (i - 1) % 2 == 1
				local col = (i - 1) % 2
				local row = math.floor((i - 1) / 2)
				local currentWidth = isCol2 and col2Width or col1Width
				local x = startX + (col * (col1Width + 1))
				local y = startY + (row * (btnHeight + 1))
				local bgCol = (opt.customColors and opt.customColors.bg) or colors.gray
				local mainTextCol = (opt.customColors and opt.customColors.text) or colors.white
				local subTextCol = (opt.customColors and opt.customColors.sub) or colors.lightGray
				display.setBackgroundColor(bgCol)
				display.setTextColor(mainTextCol)
				display.setCursorPos(x, y)
				display.write(string.format(" %-" .. (currentWidth - 2) .. "s ", opt.label))
				display.setCursorPos(x, y + 1)
				display.setTextColor(subTextCol)
				display.write(string.format(" %-" .. (currentWidth - 2) .. "s ", opt.sub:sub(1, currentWidth - 2)))
				ui.registerArea(x, y, currentWidth, btnHeight, opt.action)
			end
			local bottomY = 17
			display.setCursorPos(13, bottomY)
			display.setBackgroundColor(colors.lightGray)
			display.setTextColor(colors.gray)
			display.write(string.format(" GateOS %-28s", _G.OS_VERSION))
			ui.registerArea(13, bottomY, 25, 1, function()
				ui.openWindow({
					title = "About",
					items = {
						{ label = "GateOS " .. _G.OS_VERSION .. " - inspired by ssgd" },
						{ label = "------------------------------------" },
						{ label = "A CC:Tweaked JSG Dialing Computer." },
						{ label = "!! half the code is done with ai !!" },
						{ label = "finally got the menus reworked" },
						{ label = "and biggest of all smaller subpixels" },
						{ label = "for rendering, so now even more fancy" },
						{ label = "glyphs! and a new lock in sidebar!" },
						{ label = "also propperly implemented exporting" },
						{ label = "and made it a bit more efficient" },
						{ label = "other then that just small stuff" },
						{ label = "" },
						{ label = "" },
						{ label = "BACK", action = function() return true end }
					}
				}, { frame = colors.lightGray, title = colors.white, text = colors.cyan, close = colors.red })
			end)
			local debugLabel = config.debug and "DEBUG:ON " or "DEBUG:OFF"
			display.setCursorPos(40, bottomY)
			display.setBackgroundColor(config.debug and colors.red or colors.lightGray)
			display.setTextColor(colors.gray)
			display.write(debugLabel)
			ui.registerArea(40, bottomY, 9, 1, function()
				config.debug = not config.debug
				_G.DEBUG_MODE = config.debug
				saveOptions()
			end)
		end
        ui.openWindow({ 
            title = "System Options", 
            customRender = renderOptionsContent 
        })
        ui.clear()
        self.renderMenu()
    end
	function self.openThemeMenu() currentOpt = 1 activeWindow = "theme" end

    -- ==========================================
    -- MAIN EVENT LOOP
    -- ==========================================
	self.running = true
    self.renderMenu()    
    local refreshTimer = os.startTimer(0.1)
    Logger.log("Main loop started.", "SYS")
    while self.running do
        local eventData = {os.pullEvent()}
        Logger.updateBuffer(eventData)
        while #Logger.eventBuffer > 0 do
            local currentEvent = table.remove(Logger.eventBuffer, 1)
            local event, p1, p2, p3 = unpack(currentEvent)
            local needsRender = false
        local event, p1, p2, p3 = unpack(eventData)
		local needsRender = false
		local currentRS = false
        for _, side in ipairs(redstone.getSides()) do
            if redstone.getInput(side) then 
                currentRS = true 
                break 
            end
        end
		if currentRS and not lastRedstoneState then
			if not dialingState.active then
				local redialName = nil
				local redialData = nil
				for name, data in pairs(Gates) do
					if data.isRedial == true then
						redialName = name
						redialData = data
						break
					end
				end
				if redialName and redialData then
					Logger.log("Redstone: Dialing " .. redialName, "")
					selectedAddress = redialName
					dialingState.active = true
					stargate.onDialAddress(redialData)
					needsRender = true
				else
					Logger.log("Redstone: No target", "")
				end
			end
		end
        lastRedstoneState = currentRS
        stargate.handleEvents(event, p1, p2, p3)
            if p1 == refreshTimer then
                refreshTimer = os.startTimer(self.isAnimating and 0.05 or 10)
                needsRender = true
            elseif p1 == self.idcTimer then
                if self.pendingIDC and self.pendingIDC ~= "" then
                    stargate.sendIrisCode(self.pendingIDC) 
                    Logger.log("IDC Sent: " .. self.pendingIDC, "")
                end
                self.idcTimer = nil
                self.pendingIDC = nil
			elseif event == "stargate_wormhole_incoming" then
				gateOpen = true
				Logger.log("Incoming Wormhole")
				local status = stargate.getStatusString()
				if status ~= "UNKNOWN" and config.irisMode == 2 then
					if status == "OPENED" or status == "OPEN" then
						stargate.toggleIris()
						Logger.log("Auto-Iris: Closing", "SYS")
					end
				end
				needsRender = true
			elseif event == "stargate_spin_start" then
				if not dialingState.active then
					isBusy = true
					busyTimer = os.startTimer(8)
					needsRender = true
				end
			elseif event == "stargate_spin_stop" then
				if isBusy and not dialingState.active then
					isBusy = false
					busyTimer = nil 
					needsRender = true
				end
			elseif event == "timer" and p1 == quitTimer then
				quitConfirmed = false
				quitTimer = nil
				needsRender = true
			elseif event == "timer" and p1 == busyTimer then
				isBusy = false
				busyTimer = nil
				needsRender = true
			elseif event == "stargate_wormhole_open_unstable" or event == "stargate_wormhole_open_fully" then
				gateOpen = true
				Logger.log("Stargate Engaged", "SYS")
				if dialingState.active then
					local entry = Gates[selectedAddress]
					if entry and entry.irisCode and entry.irisCode ~= "" then
						self.pendingIDC = tostring(entry.irisCode)
						Logger.log("Sending IDC: " .. self.pendingIDC, "SYS")
					else
						Logger.log("No saved IDC")
					end
					
					self.idcTimer = os.startTimer(1)
				end			
				needsRender = true
			elseif event == "stargate_chevron_lit" then
				local chevIdx = p2 or #dialingState.sequence
				activeChevrons[chevIdx + 1] = true
				if localType == "Universe" then
					dialingState.lockedStr = dialingState.sequence
				else
					dialingState.lockedStr = stargate.getLockedString()
				end
				if localType ~= "Universe" then
					stargate.onChevronLit(chevIdx + 1)
				end
				self.renderMenu()
				needsRender = true
			elseif event == "stargate_chevron_engaged" then
				if localType == "Universe" then
					if dialingState.active then
						local nextIndex = #dialingState.sequence + 1
						dialingState.sequence = dialingState.sequence .. nextIndex
						stargate.onChevronLit(nextIndex) 
						dialingState.lockedStr = dialingState.sequence
						Logger.log("Locked: " .. dialingState.sequence, "")
						needsRender = true
					end
				end
			elseif event == "stargate_chevron_dim" then
				local currentLocked = stargate.getLockedString()
				dialingState.lockedStr = currentLocked
				if p2 then
					activeChevrons[p2] = false
				end
				if #currentLocked == 0 then
					dialingState.active = false
					dialingState.sequence = ""
					dialingState.lockedStr = ""
				end
				needsRender = true
			elseif event == "stargate_wormhole_close_unstable" or event == "stargate_wormhole_close_fully" then
				stargate.disengage()
				gateOpen = false
				dialingState.active = false
				dialingState.sequence = ""
				dialingState.lockedStr = ""
				if config.irisMode == 2 then
					if stargate.getStatusString() == "CLOSED" then
						stargate.toggleIris()
						Logger.log("Auto-Iris: Re-opening", "SYS")
					end
				end
				Logger.log("Stargate Disengaged", "SYS")
				needsRender = true
			elseif event == "stargate_iris_state_change" then
				needsRender = true
			elseif event == "stargate_iris_code_received" then
				local receivedCode = tostring(p2 or "")
				if receivedCode == "" then
					Logger.log("IDC: No IDC", "")
				else
					Logger.log("IDC: " .. receivedCode, "")
				end
				if receivedCode ~= "" and receivedCode == tostring(config.idc) then 
					stargate.toggleIris() 
					Logger.log("Granted: Opening", "")
				else
					Logger.log("Denied: Invalid IDC", "")
				end
				needsRender = true
			elseif ui.handleEvent(event, p1, p2, p3) then
				needsRender = true
			elseif event == "key" then
				if p1 == keys.q then self.running = false end
			end
			if needsRender then self.renderMenu() drawGate() end 
		end
    end
    display.clear()
    display.setCursorPos(1, 1)
    display.write("GateOS Shutdown Complete")
end
