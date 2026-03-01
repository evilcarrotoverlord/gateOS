local GUI = {}
local GateRenderer = require("lib/gate-renderer")
local glyph_data = dofile("lib/glyph.lua")
function GUI.new(display)
    local self = {}
    local clickZones = {}
    GateRenderer.setTarget(display)
    function self.reset()
        clickZones = {}
    end
    function self.clear()
        display.setBackgroundColor(colors.black)
        display.setTextColor(colors.white)
        display.clear()
        display.setCursorPos(1,1)
        self.reset()
    end
    function self.registerArea(x, y, w, h, onClick)
        table.insert(clickZones, {x=x, y=y, w=w, h=h, onClick=onClick})
    end
	function self.nameToId(gateType, name, glyphData)
			local category = glyphData[gateType:lower()] or glyphData[gateType]
			if not category then return nil end
			for id, data in pairs(category) do
				if data[1]:lower() == name:lower() then return id end
			end
			return nil
		end
    function self.handleEvent(event, p1, p2, p3)
        if event == "mouse_click" or event == "monitor_touch" then
            local x, y = p2, p3
            for _, zone in ipairs(clickZones) do
                if x >= zone.x and x <= (zone.x + zone.w - 1) and
                   y >= zone.y and y <= (zone.y + zone.h - 1) then
                    zone.onClick()
                    return true
                end
            end
        end
        return false
    end	
	function self.inputGlyphAddress(stargate, gateType, startX, startY)
		local typing = true
		local finalAddress = {}
		local forceMenuReturn = false
		startX = startX or 1
		startY = startY or 1
		local width, height = 38, 14
		local spacingX, spacingY = 9, 18
		local gridOffX, gridOffY = 1, 3
		local baseGlyphColor = colors.orange
		local lowerGateType = gateType:lower()
		if lowerGateType == "pegasus" then
			baseGlyphColor = colors.cyan
		elseif lowerGateType == "universe" then
			baseGlyphColor = colors.white
		end
		while typing do
			for i = 0, height - 1 do
				display.setCursorPos(startX, startY + i)
				display.setBackgroundColor(i >= 12 and colors.lightGray or colors.black)
				display.write(string.rep(" ", width))
			end
			self.reset()
			display.setCursorPos(48, 3)
			display.setBackgroundColor(colors.red)
			display.setTextColor(colors.white)
			display.write(" X ")
			self.registerArea(48, 3, 3, 1, function()
				typing = false
				finalAddress = nil
			end)
			GateRenderer.clear(colors.black)
			local addressNames = stargate.getDialedAddress() or {}
			local currentIDs = {}
			for i = 1, #addressNames do
				local id = self.nameToId(gateType, addressNames[i], glyph_data)
				if id then
					local numID = tonumber(id)
					if i == 9 then
						finalAddress = currentIDs
						typing = false
						forceMenuReturn = true
						break
					end
					currentIDs[i] = numID
					local row = math.floor((i - 1) / 4)
					local col = (i - 1) % 4
					local bgX = startX + (col * 9)
					local bgY = startY + (row * 16)
					local drawX = bgX + 4
					local drawY = bgY + 2
					
					local activeColor = (i >= 7) and colors.purple or baseGlyphColor
					GateRenderer.drawGlyphHD(gateType, numID, drawX, drawY, activeColor, colors.black)
				end
			end
			if not typing then break end
			GateRenderer.render()
			local formattedAddress = "|"
			for i = 1, 8 do
				local val = "__"
				if currentIDs[i] then
					val = string.format("%02d", currentIDs[i])
				end
				formattedAddress = formattedAddress .. val
				if i < 8 then
					formattedAddress = formattedAddress .. "-"
				end
			end
			formattedAddress = formattedAddress .. "|"
			display.setCursorPos(startX, startY + 12)
			display.setBackgroundColor(colors.lightGray)
			display.setTextColor(colors.black)			
			local centerX = math.floor((width - #formattedAddress) / 2) + 1
			display.setCursorPos(startX + centerX - 1, startY + 12)
			display.write(formattedAddress)
			display.setCursorPos(startX, startY + 13)
			display.setBackgroundColor(colors.red)
			display.setTextColor(colors.white)
			display.write(" [BACK] ")
			self.registerArea(startX, startY + 13, 8, 1, function()
				typing = false
				finalAddress = nil
			end)
			local count = #currentIDs
			local statusText = ""
			if count > 0 then
				if count < 6 then statusText = "INCOMPLETE"
				elseif count < 8 then statusText = "PARTIAL"
				else statusText = "FULL" end
			end
			display.setBackgroundColor(colors.lightGray)
			display.setTextColor(colors.gray)
			display.setCursorPos(startX + 9, startY + 13)
			display.write(statusText)
			local canSave = #currentIDs >= 6
			local saveLabel = " [SAVE & DIAL] "
			display.setCursorPos(startX + width - #saveLabel, startY + 13)
			display.setBackgroundColor(canSave and colors.green or colors.gray)
			display.setTextColor(colors.white)
			display.write(saveLabel)
			self.registerArea(startX + width - #saveLabel, startY + 13, #saveLabel, 1, function()
				if canSave then
					finalAddress = currentIDs
					typing = false
					forceMenuReturn = true
				end
			end)
			local ev, p1, p2, p3 = os.pullEvent()
			if not self.handleEvent(ev, p1, p2 or 0, p3 or 0) then
				if ev == "key" and (p1 == keys.backspace or p1 == keys.q) then
					typing = false
					finalAddress = nil
				end
			end
		end
		return finalAddress, forceMenuReturn
	end
	function self.inputKeyboard(title, prompt, startX, startY, limit)
		local input = ""
		local typing = true
		local btnW, btnH = 3, 2 
		startX, startY = startX or 1, startY or 1
		limit = limit or 13
		display.setBackgroundColor(colors.black)
		for i = 0, 13 do
			display.setCursorPos(startX, startY + i)
			display.write(string.rep(" ", 38))
		end
		local rows = {
			{"1","2","3","4","5","6","7","8","9","0","UN"},
			{"q","w","e","r","t","y","u","i","o","p"},
			{"a","s","d","f","g","h","j","k","l"},
			{"z","x","c","v","b","n","m","-"}
		}		
		while typing do
			self.reset()
			display.setBackgroundColor(colors.black)
			display.setTextColor(colors.yellow)
			for i = 0, 9 do
				display.setCursorPos(startX, startY + i)
				display.write(string.rep(" ", 35))
			end
			display.setCursorPos(48, 3)
			display.setBackgroundColor(colors.red)
			display.setTextColor(colors.white)
			display.write(" X ")
			self.registerArea(48, 3, 3, 1, function() 
				input = nil 
				typing = false 
			end)
			display.setBackgroundColor(colors.black)
			display.setCursorPos(startX, startY)
			display.write(title)
			display.setCursorPos(startX, startY + 1)
			display.write(prompt .. ":")
			display.setCursorPos(startX, startY + 2)
			display.setTextColor(colors.white)
			display.write("> " .. input .. "_" .. string.rep(" ", limit - #input))
			for rIdx, row in ipairs(rows) do
				local rowOffset = (rIdx - 1) * 1 
				for cIdx, char in ipairs(row) do
					local bX = startX + rowOffset + (cIdx - 1) * btnW
					local bY = (startY + 4) + (rIdx - 1) * btnH
					local isEven = (rIdx + cIdx) % 2 == 0
					local bg = isEven and colors.gray or colors.lightGray
					local label = char
					local currentBtnW = btnW
					if char == "UN" then 
						bg = colors.red 
						label = "<UNDO"
						currentBtnW = 5
					end
					display.setBackgroundColor(bg)
					display.setTextColor(colors.white)
					for ty = 0, btnH - 1 do
						display.setCursorPos(bX, bY + ty)
						display.write(string.rep(" ", currentBtnW))
					end
					display.setCursorPos(bX, bY + math.floor(btnH/2))
					display.write(label)
					self.registerArea(bX, bY, currentBtnW, btnH, function() 
						if char == "UN" then
							input = input:sub(1, -2)
						elseif #input < limit then 
							input = input .. char 
						end 
					end)
				end
			end
			local controlY = (startY + 4) + (#rows * btnH)
			local ctrlH = 2
			local controls = {                
				{label="[BACK]",     val="quit",  x=startX,      w=7,  c=colors.red},
				{label="[  SPACE  ]", val=" ",    x=startX + 8,  w=18, c=colors.blue},
				{label="[ACCEPT]",   val="done",  x=startX + 27, w=10, c=colors.green}
			}			
			for _, ctrl in ipairs(controls) do
				display.setBackgroundColor(ctrl.c)
				display.setTextColor(colors.white)
				for ty = 0, ctrlH - 1 do
					display.setCursorPos(ctrl.x, controlY + ty)
					display.write(string.rep(" ", ctrl.w))
				end
				display.setCursorPos(ctrl.x + (math.floor((ctrl.w - #ctrl.label)/2)), controlY + math.floor(ctrlH/2))
				display.write(ctrl.label)				
				self.registerArea(ctrl.x, controlY, ctrl.w, ctrlH, function()
					if ctrl.val == "done" then typing = false
					elseif ctrl.val == "quit" then input = nil typing = false
					elseif #input < limit then input = input .. ctrl.val end
				end)
			end
			local event, p1, p2, p3 = os.pullEvent()
			if not self.handleEvent(event, p1, p2 or 0, p3 or 0) then
				if event == "char" and #input < limit then 
					input = input .. p1
				elseif event == "key" then
					if p1 == keys.backspace then input = input:sub(1, -2)
					elseif p1 == keys.enter then typing = false end
				end
			end
		end		
		return input
	end
	function self.inputNumpad(title, prompt, initialValue, isDialerMode)
		local winX, winY = 11, 3
		local winW, winH = 40, 15
		local startX, startY = winX + 2, winY + 4
		local segments = {"", "", "", "", "", "", "", ""}
		local genericInput = tostring(initialValue or "")

		if isDialerMode and type(initialValue) == "table" then
			for i = 1, 8 do 
				if initialValue[i] then segments[i] = tostring(initialValue[i]) end
			end
		end

		local focus, typing, forceQuit = 1, true, false
		local btnW, btnH = 4, 2

		local function isDuplicate(val)
			for i, v in ipairs(segments) do
				if i ~= focus and tonumber(v) == val then return true end
			end
			return false
		end

		local function processDialerInput(digit)
			local current = segments[focus]
			local combined = current .. digit
			local val = tonumber(combined)

			if not val or val > 39 or isDuplicate(val) then 
				return 
			end

			segments[focus] = combined
			
			local isFinished = (#combined == 2 or val > 3)
			if isFinished and focus < 8 then 
				focus = focus + 1 
			end
		end

		while typing and death ~= true and not forceQuit do
			self.reset()
			display.setBackgroundColor(colors.gray)
			for y = winY, winY + winH do
				display.setCursorPos(winX, y)
				display.write(string.rep(" ", winW))
			end

			display.setBackgroundColor(colors.black)
			for y = winY + 1, winY + winH - 1 do
				display.setCursorPos(winX + 1, y)
				display.write(string.rep(" ", winW - 2))
			end

			display.setTextColor(colors.cyan)
			display.setBackgroundColor(colors.gray)
			display.setCursorPos(winX + 1, winY)
			display.write(" " .. title:upper() .. " ")
			
			display.setCursorPos(48, 3)
			display.setBackgroundColor(colors.red)
			display.setTextColor(colors.white)
			display.write(" X ")
			self.registerArea(48, 3, 3, 1, function() forceQuit = true end)

			display.setBackgroundColor(colors.black)
			display.setTextColor(colors.yellow)
			display.setCursorPos(startX, startY - 2)
			display.write(prompt .. ":")

			if isDialerMode then
				for i = 1, 8 do
					local segX = startX + ((i - 1) * 4)
					local bg = (i > 6) and colors.lightGray or colors.gray
					display.setBackgroundColor(bg)
					display.setTextColor(focus == i and colors.white or colors.black)
					display.setCursorPos(segX, startY)
					local val = segments[i] == "" and "__" or (segments[i] .. (#segments[i] == 1 and " " or ""))
					display.write(val)
					self.registerArea(segX, startY, 2, 1, function() focus = i end)
				end
			else
				display.setBackgroundColor(colors.gray)
				display.setTextColor(colors.white)
				display.setCursorPos(startX, startY)
				display.write(" " .. genericInput .. string.rep("_", 15 - #genericInput) .. " ")
			end

			local padStartY = startY + 2
			local buttons = {
				{"1", "1", 0, 0}, {"2", "2", 1, 0}, {"3", "3", 2, 0}, {"CLR", "clear", 3, 0},
				{"4", "4", 0, 1}, {"5", "5", 1, 1}, {"6", "6", 2, 1}, {"DEL", "back", 3, 1},
				{"7", "7", 0, 2}, {"8", "8", 1, 2}, {"9", "9", 2, 2}, {"NXT", "next", 3, 2},
				{"0", "0", 0, 3}, {"ACCEPT", "done", 1, 3}, {"BACK", "quit", 3, 3}
			}

			for _, btn in ipairs(buttons) do
				local label, val, gridX, gridY = btn[1], btn[2], btn[3], btn[4]
				local bX = startX + (gridX * (btnW + 1))
				local bY = padStartY + (gridY * btnH)
				local currentW = (val == "done") and (btnW * 2) + 1 or btnW
				
				local bg = ((gridX + gridY) % 2 == 0) and colors.gray or colors.lightGray
				if val == "done" then bg = colors.green end
				if val == "clear" or val == "back" or val == "quit" then bg = colors.red end
				
				display.setBackgroundColor(bg)
				display.setTextColor(colors.white)
				for ty = 0, btnH - 1 do 
					display.setCursorPos(bX, bY + ty) 
					display.write(string.rep(" ", currentW)) 
				end
				display.setCursorPos(bX + math.floor((currentW - #label)/2), bY + math.floor(btnH/2)) 
				display.write(label)

				self.registerArea(bX, bY, currentW, btnH, function()
					if val == "done" then 
						typing = false
					elseif val == "quit" then
						forceQuit = true
					elseif val == "clear" then
						segments = {"","","","","","","",""}
						genericInput = ""
						focus = 1
					elseif val == "back" then 
						if isDialerMode then
							if #segments[focus] > 0 then 
								segments[focus] = segments[focus]:sub(1, -2)
							elseif focus > 1 then 
								focus = focus - 1 
							end
						else
							genericInput = genericInput:sub(1, -2)
						end
					elseif val == "next" and isDialerMode then 
						if focus < 8 and segments[focus] ~= "" then focus = focus + 1 end
					elseif val:match("%d") then 
						if isDialerMode then processDialerInput(val)
						else genericInput = genericInput .. val end
					end
				end)
			end

			local event, p1, p2, p3 = os.pullEvent()
			if not self.handleEvent(event, p1, p2 or 0, p3 or 0) then
				if event == "char" and p1:match("%d") then 
					if isDialerMode then processDialerInput(p1) else genericInput = genericInput .. p1 end
				elseif event == "key" then
					if p1 == keys.backspace then
						if isDialerMode then
							if #segments[focus] > 0 then segments[focus] = segments[focus]:sub(1, -2)
							elseif focus > 1 then focus = focus - 1 end
						else genericInput = genericInput:sub(1, -2) end
					elseif p1 == keys.enter then 
						typing = false
					elseif p1 == keys.q then 
						forceQuit = true 
					end
				end
			end
		end

		if forceQuit then return initialValue end		
		if isDialerMode then
			local result = {}
			for _, s in ipairs(segments) do 
				if s ~= "" then table.insert(result, tonumber(s)) end 
			end
			return result
		else
			return tostring(genericInput or "")
		end
	end
	function self.openWindow(menuTree)
        local backgroundClickZones = clickZones
        clickZones = {}
        local menuStack = { menuTree }
        local windowOpen = true
		function self.closeWindow()
			windowOpen = false
		end
        while windowOpen do
            display.setBackgroundColor(colors.gray)
            for y = 3, 18 do
                display.setCursorPos(11, y)
                display.write(string.rep(" ", 40))
            end
            display.setBackgroundColor(colors.black)
            for y = 4, 17 do
                display.setCursorPos(12, y)
                display.write(string.rep(" ", 38))
            end
            local currentMenu = menuStack[#menuStack]
            display.setCursorPos(12, 3)
            display.setTextColor(colors.cyan)
            display.setBackgroundColor(colors.gray)
            local titleText = currentMenu.title
			if type(titleText) == "function" then
				titleText = titleText()
			end
			titleText = titleText or "MENU"
            if #menuStack > 1 then titleText = "< " .. titleText end
            display.write(" " .. titleText:upper() .. " ")
            display.setCursorPos(48, 3)
            display.setBackgroundColor(colors.red)
            display.setTextColor(colors.white)
            display.write(" X ")
            clickZones = {} 
            self.registerArea(48, 3, 3, 1, function()
            if #menuStack > 1 then table.remove(menuStack) else windowOpen = false end
			end)
			if currentMenu.customRender then
				currentMenu.customRender()
			else
				local startY = 4
				for i, item in ipairs(currentMenu.items or {}) do
					if startY > 17 then break end
					display.setCursorPos(13, startY)
					display.setBackgroundColor(colors.black)
					display.setTextColor(colors.white)					
					local labelText = type(item.label) == "function" and item.label() or item.label
					display.setCursorPos(13, startY)
					display.write("" .. tostring(labelText))
					
					self.registerArea(13, startY, 30, 1, function()
						if item.submenu then 
							table.insert(menuStack, item.submenu)
						elseif item.action then 
							if item.action() then windowOpen = false end 
						end
					end)
					startY = startY + 1
				end
			end
            local event, p1, p2, p3 = os.pullEvent()
            local handled = self.handleEvent(event, p1, p2 or 0, p3 or 0)
            if (event == "mouse_click" or event == "monitor_touch") and not handled then
            end
        end
        clickZones = backgroundClickZones
    end   
    return self
end
return GUI
