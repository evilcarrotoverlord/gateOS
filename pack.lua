local outputFile = "installer.lua"
local targets = { "lib", "startup.lua", "gateOS.lua" }
local function parseVersion(content)
	if not content then return nil end
	return content:match('_G%.OS_VERSION%s*=%s*"%s*([^"]-)%s*"')
end
local function getPackVersion()
	local path = "lib/main-menu.lua"
	if fs.exists(path) then
		local f = fs.open(path, "r")
		local ver = parseVersion(f.readAll())
		f.close()
		return ver or "???"
	end
	return "???"
end
local currentVersion = getPackVersion()
local function getFiles(dir)
	local files = {}
	if not fs.exists(dir) then return files end
	if fs.isDir(dir) then
		local list = fs.list(dir)
		for _, name in ipairs(list) do
			local path = fs.combine(dir, name)
			local subFiles = getFiles(path)
			for _, sPath in ipairs(subFiles) do table.insert(files, sPath) end
		end
	else
		table.insert(files, dir)
	end
	return files
end
local allFiles = {}
for _, target in ipairs(targets) do
	local found = getFiles(target)
	for _, path in ipairs(found) do table.insert(allFiles, path) end
end
local out = fs.open(outputFile, "w")
out.writeLine("local files = {}")
out.writeLine(string.format("local VERSION = %q", currentVersion))

for _, path in ipairs(allFiles) do
	local f = fs.open(path, "r")
	if f then
		local data = f.readAll()
		f.close()
		out.writeLine(string.format("files[%q] = %q", path, data))
	end
end
out.writeLine([[
local term = term
local w, h = term.getSize()

local function getExistingVersion()
	local path = "lib/main-menu.lua"
	if fs.exists(path) then
		local f = fs.open(path, "r")
		local content = f.readAll()
		f.close()
		return content:match('_G%.OS_VERSION%s*=%s*"%s*([^"]-)%s*"')
	end
	return nil
end
local oldVersion = getExistingVersion()
local mode = "INSTALL"
if oldVersion then
	if oldVersion == VERSION then mode = "REINSTALL" else mode = "UPDATE" end
end
local function drawBackground()
	term.setBackgroundColor(colors.blue)
	term.clear()
	term.setCursorPos(1, 1)
	term.setTextColor(colors.white)
	term.write("GateOS " .. VERSION .. " Setup")
	term.setCursorPos(1, 2)
	term.write(string.rep("=", w))	
	term.setCursorPos(1, h)
	term.setBackgroundColor(colors.lightGray)
	term.setTextColor(colors.black)
	term.clearLine()
	term.write(" ENTER=Continue  F3=Exit")
end

local function drawWindow(x, y, width, height, title)
	term.setBackgroundColor(colors.black)
	for i = 1, height do
		term.setCursorPos(x + 1, y + i)
		term.write(string.rep(" ", width))
	end
	term.setBackgroundColor(colors.lightGray)
	term.setTextColor(colors.black)
	for i = 0, height - 1 do
		term.setCursorPos(x, y + i)
		term.write(string.rep(" ", width))
	end
	term.setCursorPos(x, y); term.write(string.rep("-", width))
	term.setCursorPos(x, y + height - 1); term.write(string.rep("-", width))
	if title then
		term.setCursorPos(x + (width / 2) - (#title / 2) - 1, y)
		term.write(" " .. title .. " ")
	end
end
local function getSettings()
	local autostart = true
	local cleanGates = false
	local cleanOptions = false	
	while true do
		drawBackground()		
		term.setBackgroundColor(colors.blue)
		term.setTextColor(colors.white)
		term.setCursorPos(5, 4)
		term.write("Setup needs to configure the files on your")
		term.setCursorPos(5, 5)
		term.write("hard disk for use with GateOS. None of your")
		term.setCursorPos(5, 6)
		term.write("existing user data will be affected.")
		drawWindow(8, 8, 36, 9, "Configuration")
		local optX, optY = 10, 10		
		term.setCursorPos(optX, optY)
		term.write(autostart and "[X] Run at startup" or "[ ] Run at startup")		
		term.setCursorPos(optX, optY + 1)
		term.write(cleanOptions and "[X] Reset options.lua" or "[ ] Reset options.lua")		
		if oldVersion then
			term.setCursorPos(optX, optY + 2)
			term.write(cleanGates and "[X] Delete gates.lua" or "[ ] Delete gates.lua")
		end
		local btnY = optY + 4
		term.setCursorPos(optX, btnY)
		term.setBackgroundColor(colors.gray)
		term.setTextColor(colors.white)
		term.write("  " .. mode .. "  ")
		local btnX = optX		
		term.setCursorPos(optX + 15, btnY)
		term.write("  CANCEL  ")
		local cancelX = optX + 15
		local event, p1, p2, p3 = os.pullEvent()
		if event == "key" then
			if p1 == keys.enter then return true, autostart, cleanGates, cleanOptions
			elseif p1 == keys.f3 then return false
			end
		elseif event == "mouse_click" then
			local mx, my = p2, p3
			if my == optY and mx >= optX and mx <= optX + 18 then autostart = not autostart
			elseif my == optY + 1 and mx >= optX and mx <= optX + 21 then cleanOptions = not cleanOptions
			elseif my == optY + 2 and mx >= optX and mx <= optX + 20 and oldVersion then cleanGates = not cleanGates
			elseif my == btnY then
				if mx >= btnX and mx <= btnX + 10 then return true, autostart, cleanGates, cleanOptions
				elseif mx >= cancelX and mx <= cancelX + 10 then return false end
			end
		end
	end
end
local proceed, useAutostart, useCleanGates, useCleanOptions = getSettings()
if not proceed then
	term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
	print("Setup cancelled."); return
end
if useCleanGates and fs.exists("gates.lua") then fs.delete("gates.lua") end
if useCleanOptions and fs.exists("options.lua") then fs.delete("options.lua") end
drawBackground()
drawWindow(8, 8, 36, 6, mode .. " IN PROGRESS")
local total = 0
for _ in pairs(files) do total = total + 1 end
local count = 0
for path, data in pairs(files) do
	if path ~= "startup.lua" or useAutostart then
		count = count + 1
		term.setBackgroundColor(colors.lightGray)
		term.setTextColor(colors.black)
		term.setCursorPos(10, 10)
		term.write("Writing: " .. path:sub(1, 20) .. "...")		
		local barWidth = 30
		local progress = math.floor((count / total) * barWidth)
		term.setCursorPos(10, 12)
		term.setBackgroundColor(colors.gray)
		term.write(string.rep(" ", barWidth))
		term.setCursorPos(10, 12)
		term.setBackgroundColor(colors.black)
		term.write(string.rep(" ", progress))		
		local dir = path:match("(.+)/")
		if dir and not fs.exists(dir) then fs.makeDir(dir) end
		local f = fs.open(path, "w")
		f.write(data)
		f.close()
		sleep(0.05)
	end
end
drawBackground()
drawWindow(10, 8, 32, 6, "Success")
term.setCursorPos(12, 10)
term.write("GateOS " .. VERSION .. " installed.")
term.setCursorPos(12, 12)
term.write("Click/Press key to reboot.")
os.pullEvent()
os.reboot()
]])
out.close()
print("Created " .. outputFile .. " for gateOS (Version: " .. currentVersion .. ")")