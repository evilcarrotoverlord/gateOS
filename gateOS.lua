local stargate, display
local modem
local config = {}
_G.clientPCID = nil
_G.Logger = { file = "Logger.log", maxLines = 64, lastTime = "", lastColor = colors.white, eventBuffer = {}, maxBuffer = 20}
_G.DEBUG_MODE = true
local monitorID = nil
function Logger.log(msg, tag, adv)
	local tag = tag and tag:upper() or "INFO"
	if (tag == "SYS" or tag == "DEBUG") and not _G.DEBUG_MODE then 
        return 
    end
    local logs = {}
    if fs.exists(Logger.file) then
        local f = fs.open(Logger.file, "r")
        local line = f.readLine()
        while line do table.insert(logs, line) line = f.readLine() end
        f.close()
    end
    local currentTime = os.date("%H:%M.%S")
    local prefix = ""    
    if currentTime == Logger.lastTime then
        prefix = "/\\|"
    else
        prefix = currentTime .. (tag and (" " .. tag .. ":") or "")
        Logger.lastTime = currentTime
    end
    local info = prefix .. " " .. msg
    table.insert(logs, info)
    while #logs > Logger.maxLines do table.remove(logs, 1) end
    local f = fs.open(Logger.file, "w")
    for _, l in ipairs(logs) do f.writeLine(l) end
    f.close()
end
function Logger.updateBuffer(eventData)
    if eventData == "stargate_ping" or (type(eventData) == "table" and eventData[1] == "stargate_ping") then
        return
    end
    table.insert(Logger.eventBuffer, eventData)
    if #Logger.eventBuffer > Logger.maxBuffer then
        table.remove(Logger.eventBuffer, 1)
    end
end
local function safeRequire(path)
    local status, lib = pcall(require, path)
    if not status then
        Logger.log("Failed to load "..path..": "..tostring(lib), "CRIT")
        return false, nil
    end
    return true, lib
end
local function loadConfig()
    if fs.exists("options-gOS.conf") then
        local f = fs.open("options-gOS.conf", "r")
        config = textutils.unserialize(f.readAll())
        f.close()
    end
end
local ok_sg, Stargate   = safeRequire("lib/stargate")
local ok_menu, MainMenu = safeRequire("lib/main-menu")
local ok_render, render   = safeRequire("lib/gate-renderer")
term.reset = function()
    term.clear()
    term.setCursorPos(1, 1)
end
function initialize()
	Logger.log("==========Booting GateOS==========", "SYS", true)
	modem = peripheral.find("modem")
	if fs.exists("options-gOS.conf") then
		local f = fs.open("options-gOS.conf", "r")
		local loadedConfig = textutils.unserialize(f.readAll())
		f.close()
		if loadedConfig and loadedConfig.monitorID then
			config.monitorID = loadedConfig.monitorID
			monitorID = tonumber(config.monitorID)
			Logger.log("Bound to Remote ID: " .. monitorID, "SYS")
		end
	end
	local modemName = peripheral.find("modem", function(name, object)
		return object.isWireless()
	end)
	if modemName then
		local side = peripheral.getName(modemName)
		rednet.open(side)
		if rednet.isOpen(side) then
			Logger.log("Modem active on " .. side, "SYS")
		else
			Logger.log("Failed to open Rednet on " .. side, "CRIT")
		end
	else
		Logger.log("No Wireless Modem hardware detected!", "CRIT")
	end
	local ok, book = pcall(require, "gates")
	local addressBook = ok and book or {}
	local mon = peripheral.find("monitor")
	if mon then
		mon.setTextScale(1)
		Logger.log("Physical monitor detected", "SYS")
	else
		Logger.log("No physical monitor found - Remote only mode", "WARN")
	end
	local w, h = term.getSize()
	local buffer = {}
	local function clearBuffer()
		for y = 1, h do
			buffer[y] = {
				text = string.rep(" ", w),
				fg = string.rep("0", w),
				bg = string.rep("f", w)
			}
		end
	end
	clearBuffer()
	local cursorX, cursorY = 1, 1
	local curFG, curBG = "0", "f"
	display = {
		getSize = function() return w, h end,
		setCursorPos = function(x, y) cursorX, cursorY = x, y end,
		getCursorPos = function() return cursorX, cursorY end,
		setTextColor = function(c) curFG = colors.toBlit(c) end,
		setBackgroundColor = function(c) curBG = colors.toBlit(c) end,
		setTextScale = function(s) 
			if mon then mon.setTextScale(s) end 
		end,
		clear = function() clearBuffer() end,
		blit = function(t, f, b)
			if cursorY >= 1 and cursorY <= h then
				local row = buffer[cursorY]
				row.text = row.text:sub(1, cursorX-1) .. t .. row.text:sub(cursorX + #t)
				row.fg = row.fg:sub(1, cursorX-1) .. f .. row.fg:sub(cursorX + #f)
				row.bg = row.bg:sub(1, cursorX-1) .. b .. row.bg:sub(cursorX + #b)
				cursorX = cursorX + #t
			end
		end,
		write = function(t)
			display.blit(t, string.rep(curFG, #t), string.rep(curBG, #t))
		end,
		render = function()
			for y = 1, h do
				term.setCursorPos(1, y)
				term.blit(buffer[y].text, buffer[y].fg, buffer[y].bg)
			end
			if mon then
				for y = 1, h do
					mon.setCursorPos(1, y)
					mon.blit(buffer[y].text, buffer[y].fg, buffer[y].bg)
				end
			end
			return buffer
		end
	}
	Logger.log("Display initialized", "SYS", true)
	if ok_render then
		render.setTarget(display)
	end

	if not ok_sg then
		Logger.log("Library 'lib/stargate' is missing!", "CRIT")
		return false, {}
	end	
	stargate = Stargate.connect()
	if stargate then
		Logger.log("Stargate initialized", "SYS", true)
		stargate.disengage()
	end
	return stargate ~= nil, addressBook
end
function runSandboxed(addressBook)
    local env = setmetatable({
        Logger = Logger,
        display = display,
        stargate = stargate,
        viewLogs = viewLogs,
    }, { __index = _G })
    setfenv(MainMenu, env)
    return MainMenu(stargate, addressBook, display)
end
function viewLogs()
	local w, h = display.getSize()
	local scrollOffset = 0
	local wrappedLines = {}
	if not fs.exists(Logger.file) then
		display.clear()
		display.setCursorPos(1, 1)
		display.write("No logs found.")
		display.render()
		os.pullEvent("key")
		return
	end
	local function refreshWrappedLines()
		wrappedLines = {}
		local f = fs.open(Logger.file, "r")
		local activeColor = colors.white
		local line = f.readLine()
		while line do
			if not line:find("^/\\|") then
				if line:find("CRIT:") or line:find("ERR:") then 
					activeColor = colors.red
				elseif line:find("SYS:") or line:find("HARDWARE:") then 
					activeColor = colors.yellow
				else 
					activeColor = colors.white 
				end
			end
			local tempLine = line
			while #tempLine > 0 do
				table.insert(wrappedLines, { text = tempLine:sub(1, w), color = activeColor })
				tempLine = tempLine:sub(w + 1)
			end
			line = f.readLine()
		end
		f.close()
	end
	local function draw()
		display.setBackgroundColor(colors.black)
		display.clear()
		local maxVisible = h - 1
		for i = 1, maxVisible do
			local lineIdx = #wrappedLines - (maxVisible - i) - scrollOffset
			if wrappedLines[lineIdx] then
				display.setCursorPos(1, i)
				display.setTextColor(wrappedLines[lineIdx].color)
				display.write(wrappedLines[lineIdx].text)
			end
		end
		display.setCursorPos(1, h)
		display.setBackgroundColor(colors.gray)
		display.setTextColor(colors.black)
		display.write(" SCROLL: Mouse | EXIT: Key " .. string.rep(" ", w - 27))
		display.render()
	end
	refreshWrappedLines()
	scrollOffset = 0
	while true do
		draw()
		local event, dir, x, y = os.pullEvent()
		if event == "mouse_scroll" then
			scrollOffset = math.max(0, math.min(scrollOffset - dir, #wrappedLines - (h - 1)))
		elseif event == "key" or event == "mouse_click" or event == "monitor_touch" then
			break
		end
	end
	display.setBackgroundColor(colors.black)
	display.clear()
	display.render()
end
function Logger.getLastLog()
    if not fs.exists(Logger.file) then 
        return "No logs found", colors.gray 
    end
    local f = fs.open(Logger.file, "r")
    local lines = {}
    local line = f.readLine()
    while line do 
        table.insert(lines, line) 
        line = f.readLine() 
    end
    f.close()    
    
    if #lines == 0 then 
        return "Empty log", colors.gray 
    end
    local last = lines[#lines]
    local col = colors.white
    if last:find("CRIT") or last:find("ERR") then 
        col = colors.red
    elseif last:find("SYS") or last:find("HARDWARE") then 
        col = colors.yellow 
    end
    local cleanMsg = last:match(":?%s+(.+)$") or last
    return tostring(cleanMsg):sub(1, 30), col
end
function inputListener()
	while true do
		local id, msg, prot = rednet.receive("gateos_input")
		if type(msg) == "table" then
			if msg.type == "HANDSHAKE" and msg.uid == config.monitorID then
				_G.clientPCID = id
				rednet.send(id, {type = "CONFIRM", uid = config.monitorID}, "gateos_mirror")
				Logger.log("Client Linked: " .. id, "SYS")
			elseif msg.type == "remote_touch" and msg.uid == config.monitorID then
				os.queueEvent("mouse_click", 1, msg.x, msg.y)
			end
		end
	end
end
function framePusher()
    while true do
        if _G.clientPCID and display then
            local currentFrame = display.render()
            local packet = {
                type = "FRAME_UPDATE",
                uid = config.monitorID,
                data = currentFrame
            }
            rednet.send(_G.clientPCID, packet, "gateos_mirror")
        end
        sleep(0.05)
    end
end
function main()
    local success, addressBook = initialize()
	loadConfig()
    if not success then 
        print("Error: Stargate hardware or library missing.")
        Logger.log("Error: Stargate hardware or library missing.", "CRIT")
        viewLogs()
        return 
    end
    if not ok_menu then
        print("Error: 'lib/main-menu' not found. Cannot start UI.")
        Logger.log("Menu library missing - cannot render UI", "CRIT")
        viewLogs()
        return
    end
    term.clear()
	local ok, err = pcall(function()
		parallel.waitForAny(
			function() runSandboxed(addressBook) end,
			function() inputListener() end,
		function() framePusher() end
		)
	end)
    if not ok then
		if err ~= "Terminated" then
			Logger.log("Runtime Error: " .. tostring(err), "CRIT", true)
			print("Error: " .. tostring(err))
		end
	end
    if stargate then 
        pcall(stargate.disengage) 
    end
    display.setBackgroundColor(colors.black)
    term.reset()
    display.setTextColor(colors.cyan)
    display.setBackgroundColor(colors.gray)
    print("==================Exiting=GateOS===================")
    display.setTextColor(colors.white)
    display.setBackgroundColor(colors.black)
end
main()
