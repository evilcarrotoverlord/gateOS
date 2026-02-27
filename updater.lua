local VERSION_URL = "https://api.github.com/repos/evilcarrotoverlord/gateOS/releases"
local term = term
local w, h = term.getSize()
local function resetTerm()
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clear()
	term.setCursorPos(1, 1)
end
local function getExistingVersion()
	local path = "lib/main-menu.lua"
	if fs.exists(path) then
		local f = fs.open(path, "r")
		local content = f.readAll()
		f.close()
		local ver = content:match('_G%.OS_VERSION%s*=%s*"%s*([^"]-)%s*"')
		return ver or "???"
	end
	return "???"
end
local function drawBackground(ver)
	term.setBackgroundColor(colors.blue)
	term.clear()
	term.setCursorPos(1, 1)
	term.setTextColor(colors.white)
	term.write("GateOS Remote Bootloader - Current: " .. ver)
	term.setCursorPos(1, 2)
	term.write(string.rep("=", w))
	term.setCursorPos(1, h)
	term.setBackgroundColor(colors.lightGray)
	term.setTextColor(colors.black)
	term.clearLine()
	term.write(" Select version and click RUN  |  F3 to Quit")
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
	term.setCursorPos(x, y)
	term.write(string.rep("-", width))
	term.setCursorPos(x, y + height - 1)
	term.write(string.rep("-", width))
	if title then
		term.setCursorPos(x + (width / 2) - (#title / 2) - 1, y)
		term.write(" " .. title .. " ")
	end
end
local function fetchReleases(currentVer)
	local list = {}
	local response = http.get(VERSION_URL)
	if response then
		local data = textutils.unserialiseJSON(response.readAll())
		response.close()
		if data then
			for i, rel in ipairs(data) do
				local downloadUrl = nil
				for _, asset in ipairs(rel.assets or {}) do
					if asset.name == "installer.lua" then
						downloadUrl = asset.browser_download_url
						break
					end
				end
				table.insert(list, {
					tag = rel.tag_name,
					url = downloadUrl,
					isLatest = (i == 1),
					isCurrent = (rel.tag_name == currentVer)
				})
			end
		end
	end
	return list
end
local function main()
	local currentVer = getExistingVersion()
	drawBackground(currentVer)
	drawWindow(10, 8, 32, 5, "Network")
	term.setCursorPos(12, 10)
	term.write("Querying GitHub...")	
	local releases = fetchReleases(currentVer)
	local selectedIdx = 1
	local scrollOffset = 0
	local visibleRows = 5
	local winX, winY, winW, winH = 4, 4, 44, 14
	while true do
		drawBackground(currentVer)
		drawWindow(winX, winY, winW, winH, "Select Version")		
		for i = 1, visibleRows do
			local idx = i + scrollOffset
			if releases[idx] then
				local rel = releases[idx]
				local drawY = winY + (i * 2) - 1
				term.setCursorPos(winX + 2, drawY)
				if idx == selectedIdx then
					term.setBackgroundColor(colors.blue)
					term.setTextColor(colors.white)
				else
					term.setBackgroundColor(colors.gray)
					term.setTextColor(colors.lightGray)
				end
				local label = string.format(" %-38s", (rel.tag .. (rel.isLatest and " (NEW)" or "") .. (rel.isCurrent and " (LIVE)" or "")):sub(1, 38))
				term.write(label)
			end
		end
		local btnY = winY + winH - 2
		term.setCursorPos(winX + 6, btnY)
		term.setBackgroundColor(colors.cyan)
		term.setTextColor(colors.black)
		term.write("  [ RUN ]  ")
		term.setCursorPos(winX + 26, btnY)
		term.setBackgroundColor(colors.red)
		term.setTextColor(colors.white)
		term.write("  [ QUIT ]  ")
		local event, p1, p2, p3 = os.pullEvent()
		if event == "key" then
			if p1 == keys.up and selectedIdx > 1 then
				selectedIdx = selectedIdx - 1
			elseif p1 == keys.down and selectedIdx < #releases then
				selectedIdx = selectedIdx + 1
			elseif p1 == keys.enter then
				break
			elseif p1 == keys.f3 then
				resetTerm()
				return
			end
		elseif event == "mouse_click" or event == "monitor_touch" then
			local mx, my = p2, p3
			if my == btnY then
				if mx >= winX + 6 and mx <= winX + 16 then break
				elseif mx >= winX + 26 and mx <= winX + 36 then
					resetTerm()
					return
				end
			end
			for i = 1, visibleRows do
				local idx = i + scrollOffset
				local drawY = winY + (i * 2) - 1
				if my == drawY and mx >= winX + 2 and mx <= winX + winW - 2 then
					selectedIdx = idx
				end
			end
		elseif event == "mouse_scroll" then
			scrollOffset = math.max(0, math.min(scrollOffset + p1, #releases - visibleRows))
		end

		if selectedIdx <= scrollOffset then
			scrollOffset = selectedIdx - 1
		elseif selectedIdx > scrollOffset + visibleRows then
			scrollOffset = selectedIdx - visibleRows
		end
	end
	local target = releases[selectedIdx]
	if not target.url then
		resetTerm()
		print("Dummy entry selected. No remote code to run.")
		return
	end
	drawBackground(currentVer)
	drawWindow(8, 8, 36, 6, "MEMORY LOAD")
	term.setCursorPos(10, 10)
	term.write("Running: " .. target.tag)
	local res = http.get(target.url)
	if res then
		local code = res.readAll()
		res.close()
		resetTerm()
		local func, err = load(code, "installer", "t", _ENV)
		if func then
			local ok, runErr = pcall(func)
			if not ok then print("Runtime Error: " .. tostring(runErr)) end
		else
			print("Load Error: " .. tostring(err))
		end
	else
		resetTerm()
		print("Failed to reach GitHub.")
	end
end
main()