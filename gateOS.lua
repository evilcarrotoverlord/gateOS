local stargate, display
_G.Logger = { file = "Logger.log", maxLines = 64, lastTime = "", lastColor = colors.white, eventBuffer = {}, maxBuffer = 20}
_G.DEBUG_MODE = true
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
local ok_sg, Stargate   = safeRequire("lib/stargate")
local ok_menu, MainMenu = safeRequire("lib/main-menu")
local ok_render, render   = safeRequire("lib/gate-renderer")
term.reset = function()
    term.clear()
    term.setCursorPos(1, 1)
end
function initialize()
    Logger.log("==========Booting GateOS==========", "SYS", true)
    local ok, book = pcall(require, "gates")
    local addressBook = ok and book or {}
    local mon, nat = peripheral.find("monitor"), term.current()
    if mon then
        mon.setTextScale(1)
        display = {
            write = function(t) nat.write(t) mon.write(t) end,
            setCursorPos = function(x, y) nat.setCursorPos(x, y) mon.setCursorPos(x, y) end,
            clear = function() nat.clear() mon.clear() end,
            getSize = function() return nat.getSize() end,
            setBackgroundColor = function(c) nat.setBackgroundColor(c) mon.setBackgroundColor(c) end,
            setTextColor = function(c) nat.setTextColor(c) mon.setTextColor(c) end,
            blit = function(t, f, b) nat.blit(t, f, b) mon.blit(t, f, b) end,
        }
    else display = nat end
	Logger.log("display innitialized", "SYS", true)
	if ok_render then
        render.setTarget(display)
    else
        Logger.log("Gate-Renderer missing - Graphics may be degraded", "WARN")
    end
	if not ok_sg then
        Logger.log("Library 'lib/stargate' is missing!", "CRIT")
        return false, {}
    end	
    stargate = Stargate.connect()
	if stargate then
        Logger.log("stargate initialized", "SYS", true)
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
	display.setBackgroundColor(colors.black)
	display.clear()    
	if not fs.exists(Logger.file) then
		display.setCursorPos(1, 1)
		display.write("No logs found.")
		os.pullEvent() 
		return
	end
	local f = fs.open(Logger.file, "r")
	local rawLines = {}
	local line = f.readLine()
	while line do 
		table.insert(rawLines, line) 
		line = f.readLine() 
	end
	f.close()
	local w, h = display.getSize()
	local wrappedLines = {}
	local activeColor = colors.white
	for _, l in ipairs(rawLines) do
		if not l:find("^/\\|") then
			if l:find("CRIT:") or l:find("ERR:") then 
				activeColor = colors.red
			elseif l:find("SYS:") or l:find("HARDWARE:") then 
				activeColor = colors.yellow
			else 
				activeColor = colors.white 
			end
		end
		local tempLine = l
		while #tempLine > 0 do
			table.insert(wrappedLines, { text = tempLine:sub(1, w), color = activeColor })
			tempLine = tempLine:sub(w + 1)
		end
	end
	local startLine = math.max(1, #wrappedLines - (h - 2))
	for i = startLine, #wrappedLines do
		local y = i - startLine + 1
		local data = wrappedLines[i]
		display.setCursorPos(1, y)
		display.setTextColor(data.color)
		display.write(data.text)
	end
	display.setCursorPos(1, h)
	display.setBackgroundColor(colors.gray)
	display.setTextColor(colors.black)
	display.write(" INTERACT TO RETURN " .. string.rep(" ", w - 19))
	repeat
		local event = os.pullEvent()
	until event == "key" or event == "mouse_click" or event == "monitor_touch"
	display.setBackgroundColor(colors.black)
	display.clear()    
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
function main()
    local success, addressBook = initialize()
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
    local status, err = pcall(runSandboxed, addressBook)
    if not status then
        if err == "Terminated" then
            Logger.log("User terminated program", "SYS")
        else
            Logger.log("Runtime Error: " .. tostring(err), "CRIT", true)
            term.reset()
            viewLogs()
            display.setTextColor(colors.white)
            display.setBackgroundColor(colors.black)
            print("Program Error: " .. tostring(err))
            os.pullEvent("key")
        end
    end
    if stargate then 
        pcall(stargate.disengage) 
    end
    term.reset()
    display.setTextColor(colors.cyan)
    display.setBackgroundColor(colors.gray)
    print("==================Exiting=GateOS===================")
    display.setTextColor(colors.white)
    display.setBackgroundColor(colors.black)
end
main()
