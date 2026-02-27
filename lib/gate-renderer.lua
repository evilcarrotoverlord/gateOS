local glyph_data = require("lib/glyph")
local GateRenderer = {}
local lastIrisState = "OPENED"
local wasIrisClosed = false
local wasGateOpen = false
local colors_map = {MilkyWay = colors.orange, Pegasus = colors.cyan, Universe = colors.white,Tollan = colors.lightBlue, Movie = colors.orange, Iris = colors.lightGray, IRIS_TITANIUM = colors.lightGray, IRIS_TRINIUM = colors.lightGray, SHIELD = colors.white}

local uniRLE = "0:6_1_3_1_11_7_9_2_5_2_7_2_7_2_4_3_9_3_3_1_11_1_3_1_13_1_2_1_13_1_1_2_13_4_13_4_13_2_2_1_11_1_4_2_9_2_5_2_7_2_6_3_5_3_9_5_13_3_7"
local pg1RLE = "0:23_2_1_2_11_1_5_1_9_1_7_1_7_1_9_1_5_1_11_1_3_1_13_1_36_1_13_1_2_1_13_1_3_1_11_1_5_1_9_1_7_1_7_1_9_1_5_1_12_3_24"
local pg2RLE = "0:6_1_3_1_10_2_5_2_8_1_7_1_22_2_11_2_2_1_13_1_1_1_15_1_34_1_15_2_15_1_1_1_13_1_21_1_9_1_6_2_7_2_7_1_7_1_11_3_7"
local mlkRLE = "0:6_1_3_1_10_4_1_4_8_2_5_2_8_1_7_1_5_3_9_3_2_2_11_2_1_2_13_2_34_2_13_4_13_2_1_2_11_2_4_1_9_1_6_2_7_2_6_3_5_3_7_1_2_3_2_1_10_5_6"
local tolRLE = "0:6_2_1_2_10_9_8_2_5_2_6_3_7_3_3_3_9_3_2_2_11_2_2_1_13_1_1_2_13_4_13_4_13_4_13_2_1_2_11_2_3_2_9_2_4_3_7_3_5_3_5_3_7_1_1_5_1_1_11_3_7"
local resetRLE = "1:6_5_10_9_7_11_5_13_3_15_2_15_1_85_1_15_2_15_3_13_5_11_7_9_11_3_7"
local chevron1 = { { x = 4,  y = -6, rle = "0:1_1_2_2"   }, { x = 7,  y = -1, rle = "1:2_1_2_1"   }, { x = 5,  y = 4,  rle = "0:1_2_1_1_1" }, { x = -7, y = 4,  rle = "1:2_2_1_1"   },
    { x = -9, y = -1, rle = "0:1_2_1_2"   }, { x = -6, y = -6, rle = "0:1_1_1_2_1" }, { x = 2,  y = 7,  rle = "1:2_1_1_2"   }, { x = -4, y = 7,  rle = "0:1_2_2_1"   }, { x = -1, y = -8, rle = "1:3_1_1_1"   } }
local chevron2 = { { x = 5,  y = -6, rle = "1:1"   }, { x = 8,  y = -2, rle = "1:1"   }, { x = 7,  y = 4,  rle = "1:1"  }, { x = -7, y = 4,  rle = "1:1" },
    { x = -8, y = -2, rle = "1:1"    }, { x = -5, y = -6, rle = "1:1" }, { x = 3,  y = 7,  rle = "1:1"   }, { x = -3, y = 7,  rle = "1:1"   }, { x = 0, y = -8, rle = "1:1"    } }
local chevron3 = { { x = 4,  y = -7, rle = "1:1_3_1_3_1"   }, { x = 7,  y = -3, rle = "1:1_3_1_2_1"   }, { x = 6,  y = 3,  rle = "0:1_1_2_1_1_1" }, { x = -7, y = 3,  rle = "1:1_2_1_3_1"   },
    { x = -8, y = -3, rle = "0:1_1_1_1_2_1"   }, { x = -6, y = -7, rle = "0:2_1_1_1_1_1" }, { x = 2,  y = 6,  rle = "0:4_3"   }, { x = -4, y = 7,  rle = "1:2_3_1"   }, { x = -1, y = -8, rle = "1:3"   } }
local w, h, vH
local target = term
local setCursor, setBG, setFG, write
local Buffer = {}
function GateRenderer.setTarget(newTarget)
    target = newTarget
    w, h = target.getSize()
    vH = math.floor(h * 1.5)
    setCursor = target.setCursorPos
    setBG = target.setBackgroundColor
    setFG = target.setTextColor
    write = target.write
    GateRenderer.init()
end
function GateRenderer.getBufferCell(x, y)
    if Buffer[y] and Buffer[y][x] then
        return Buffer[y][x]
    end
    return nil
end
function GateRenderer.init()
    if not w or not h then GateRenderer.setTarget(term) end
    Buffer = {} 
    for y = 1, h do
        Buffer[y] = {}
        for x = 1, w do
            Buffer[y][x] = {colors.black, colors.black, " "}
        end
    end
end
function GateRenderer.set(x, y, col)
    if x < 1 or x > w or y < 1 or y > vH then return end
    if not Buffer[1] then GateRenderer.init() end
    local group = math.floor((y - 1) / 3)
    local subY = (y - 1) % 3
    
    if subY == 0 then
        local row = group * 2 + 1
        if Buffer[row] then
            Buffer[row][x][1] = col
            Buffer[row][x][3] = "\143"
        end
    elseif subY == 1 then
        local rowA, rowB = group * 2 + 1, group * 2 + 2
        if Buffer[rowA] then Buffer[rowA][x][2] = col end
        if Buffer[rowB] then
            Buffer[rowB][x][1] = col
            Buffer[rowB][x][3] = "\131"
        end
    elseif subY == 2 then
        local row = group * 2 + 2
        if Buffer[row] then Buffer[row][x][2] = col end
    end
end
function GateRenderer.drawRLE(sizex, sizey, rle_string, startX, startY, color)
    local first, counts = rle_string:match("^(%d):(.+)$")
    if not first then return end
    
    local bit = tonumber(first)
    local x, y = 0, 0
    for count in counts:gmatch("(%d+)") do
        for i = 1, tonumber(count) do
            if bit == 1 then
                GateRenderer.set(startX + x, startY + y, color)
            end
            x = x + 1
            if x >= sizex then 
                x = 0
                y = y + 1 
            end
        end
        bit = 1 - bit
    end
end
function GateRenderer.saveRLE(data_table)
    local firstBit = data_table[1] or 0
    local result = { tostring(firstBit) }
    local current = firstBit
    local count = 0
    for _, val in ipairs(data_table) do
        if val == current then
            count = count + 1
        else
            table.insert(result, count)
            current = val
            count = 1
        end
    end
    table.insert(result, count)
    return result[1] .. ":" .. table.concat({select(2, unpack(result))}, "_")
end
function GateRenderer.drawCircle(centerX, centerY, radius, col)
    local r2 = (radius + 0.25) * (radius + 0.25)
    for dy = -radius, radius do
        local dx = math.floor(math.sqrt(r2 - dy * dy))
        local startX = centerX - dx
        local endX = centerX + dx
        for x = startX, endX do
            GateRenderer.set(x, centerY + dy, col)
        end
    end
end
function GateRenderer.render()
    for y = 1, h do
        for x = 1, w do
            local cell = Buffer[y][x]
            if cell[3] ~= " " or cell[2] ~= colors.black then
                setCursor(x, y)
                setFG(cell[1])
                setBG(cell[2])
                write(cell[3])
            end
        end
    end
end
local function drawPowerBar(x, y, height, percentage)
    local fill = math.floor(height * 3 * percentage)
    for i = 0, (height * 3) - 1 do
        local color = colors.gray
        if i < fill then
            color = (percentage < 0.2) and colors.red or colors.green
        end
        GateRenderer.set(x, (y * 3) - i, color) 
    end
end
function GateRenderer.clear(col)
    local c = col or colors.black
    for y = 1, h do
        for x = 1, w do Buffer[y][x] = {c, c, " "} end
    end
end
local function drawGlyph(gateType, glyphID, centerX, centerY, activeColor)
	if glyphID == nil then return end
    local universe = glyph_data[gateType] or glyph_data[gateType:lower()]
    if not universe then return end
    local entry = universe[tostring(glyphID)] or universe[tonumber(glyphID)]
    if not entry then return end
    local rle_string = entry[2]
    local startX = centerX - 4
    local startY = centerY - 4
    GateRenderer.drawRLE(9, 9, rle_string, startX, startY, activeColor)
end
GateRenderer.drawGlyph = drawGlyph
local function drawGateFrame(gateType, lockedChevrons, activeColor, centerX, centerY)
    local startX, startY = centerX - 8, centerY - 8
	if gateType == "MilkyWay" or gateType == "Movie" then
        GateRenderer.drawRLE(17, 17, mlkRLE, startX, startY, colors.gray)
    elseif gateType == "Pegasus" then
        GateRenderer.drawRLE(17, 17, pg1RLE, startX, startY, colors.blue)
        GateRenderer.drawRLE(17, 17, pg2RLE, startX, startY, colors.gray)
    elseif gateType == "Universe" then
        GateRenderer.drawRLE(17, 17, uniRLE, startX, startY, colors.gray)
    elseif gateType == "Tollan" then
        GateRenderer.drawRLE(17, 17, tolRLE, startX, startY, colors.gray)
    else
        GateRenderer.drawRLE(17, 18, resetRLE, startX, startY, colors.black)
    end
    GateRenderer.drawRLE(17, 18, resetRLE, startX, startY, colors.black)
	local selectedChevrons
    if gateType == "MilkyWay" or gateType == "Movie" or gateType == "Pegasus" then
        selectedChevrons = chevron1
    elseif gateType == "Tollan" then
        selectedChevrons = chevron2
    elseif gateType == "Universe" then
        selectedChevrons = chevron3
    end
    if selectedChevrons then
        local lockedStr = tostring(lockedChevrons or "")
        for i, chev in ipairs(selectedChevrons) do
            local isLocked = lockedStr:find(tostring(i)) ~= nil
            local color = isLocked and activeColor or colors.lightGray
            GateRenderer.drawRLE(3, 3, chev.rle, centerX + chev.x, centerY + chev.y, color)
        end
    end
    term.setBackgroundColor(colors.black)
end
function GateRenderer.draw(lockedChevrons, gateType, centerX, centerY, gateOpen, irisState, irisMaterial, glyphID)
    local activeColor = colors_map[gateType] or colors.orange
    local horizonColor = colors.lightBlue
    local irisColor = colors_map[irisMaterial] or colors.lightGray
    local isAnimating = false
	if irisState == "CLOSING" and lastIrisState ~= "CLOSED" then
        isAnimating = true
        for r = 7, 0, -1 do
            GateRenderer.clear(colors.black)
            GateRenderer.drawCircle(centerX, centerY, 7, irisColor, true)
            local holeColor = gateOpen and horizonColor or colors.black
            if r > 0 then
                GateRenderer.drawCircle(centerX, centerY, r, holeColor, true)
            end            
            drawGlyph(gateType, glyphID, centerX, centerY, activeColor) 
            drawGateFrame(gateType, lockedChevrons, activeColor, centerX, centerY)            
            sleep(0.3)
            GateRenderer.render()
        end
        lastIrisState = "CLOSED" 
    elseif irisState == "OPENING" and lastIrisState ~= "OPENED" then
        isAnimating = true
        local revealColor = gateOpen and horizonColor or colors.black
        for r = 0, 7 do
            GateRenderer.clear(colors.black)
            GateRenderer.drawCircle(centerX, centerY, 7, irisColor, true)
            GateRenderer.drawCircle(centerX, centerY, r, revealColor, true)
            drawGlyph(gateType, glyphID, centerX, centerY, activeColor) 
            drawGateFrame(gateType, lockedChevrons, activeColor, centerX, centerY)            
            sleep(0.3)
            GateRenderer.render()
        end
        lastIrisState = "OPENED"
    end
    if not isAnimating and lastIrisState == "OPENED" then
        if gateOpen and not wasGateOpen then
            isAnimating = true
            for r = 7, 1, -1 do
                GateRenderer.drawCircle(centerX, centerY, 7, horizonColor, true)
                GateRenderer.drawCircle(centerX, centerY, r, colors.black, true)
                drawGlyph(gateType, glyphID, centerX, centerY, activeColor)
                drawGateFrame(gateType, lockedChevrons, activeColor, centerX, centerY)
                sleep(0.1)
				GateRenderer.render()
            end
            GateRenderer.drawCircle(centerX, centerY, 7, horizonColor, true)
            GateRenderer.set(centerX, centerY, colors.black, true) 
            drawGateFrame(gateType, lockedChevrons, activeColor, centerX, centerY)
            wasGateOpen = true
        elseif not gateOpen and wasGateOpen then
            isAnimating = true
            GateRenderer.drawCircle(centerX, centerY, 7, horizonColor, true)
            GateRenderer.set(centerX, centerY, colors.black, true)
            sleep(0.1)
            for r = 1, 7 do
                GateRenderer.drawCircle(centerX, centerY, 7, horizonColor, true)
                GateRenderer.drawCircle(centerX, centerY, r, colors.black, true)
                drawGlyph(gateType, glyphID, centerX, centerY, activeColor)
                drawGateFrame(gateType, lockedChevrons, activeColor, centerX, centerY)
                sleep(0.05)
				GateRenderer.render()
            end
            wasGateOpen = false
        end
    end
	if not isAnimating then
        GateRenderer.clear(colors.black)
        local bgColor = colors.black
        if irisState == "CLOSED" or irisState == "CLOSING" then
            bgColor = irisColor
        elseif gateOpen then
            bgColor = horizonColor
        end
        GateRenderer.drawCircle(centerX, centerY, 7, bgColor, true)
        drawGlyph(gateType, glyphID, centerX, centerY, activeColor)
        drawGateFrame(gateType, lockedChevrons, activeColor, centerX, centerY)
        GateRenderer.render()
    end
    if irisState == "OPENED" or irisState == "CLOSED" then
        lastIrisState = irisState
    end
	GateRenderer.render()
    wasGateOpen = gateOpen
end
return GateRenderer
