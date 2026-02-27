local Stargate = {}
local pointsOfOrigin = {
    MilkyWay = "Point of Origin", 
    Pegasus = 14, 
    Universe = 17, 
    Tollan = "Point of Origin", 
    Movie = "Point of Origin"
}
function Stargate.connect(config)
    local gate = {}
    local _stargate = peripheral.find("stargate")
    local gateDelays = {MilkyWay = 2.0, Pegasus = 0.1, Universe = 0.5, Tollan = 0.1, Movie = 2.0 }
    if not _stargate then
        if _G.Logger then _G.Logger.log("Failed to find stargate peripheral", "HARDWARE", true) end
        return false 
    end
    function gate.applyDialDelay()
		local gType = gate.getGateType()
		local delay = gateDelays[gType] or 2.0
		os.sleep(delay)
	end
    local localType = _stargate.getGateType()
	local function formatEnergy(value)
		if value >= 1000000 then
			return string.format("%.2f MRF", value / 1000000)
		elseif value >= 1000 then
			return string.format("%.2f kRF", value / 1000)
		else
			return string.format("%d FE", math.floor(value))
		end
	end
	function gate.canAffordDial(address)
		local success, response, energyMap = _stargate.getEnergyRequiredToDial(address)		
		if not success then
			if response == "address_malformed" then
				return false, "Invalid Address Format"
			elseif response == "stargate_busy" then
				return false, "Stargate is Busy"
			else
				return false, "Dial Check Failed: " .. tostring(response)
			end
		end
		if response == "energy_map" and energyMap then
			local currentPower = gate.getEnergy()
			local buffer = energyMap.keepAlive * 5			
			if energyMap.canOpen and currentPower >= (energyMap.open + buffer) then
				return true
			else
				local needed = energyMap.open + buffer
				local diff = needed - currentPower
				return false, string.format("Insufficient Energy: Need %s more", formatEnergy(diff))
			end
		end
		return false, "Unknown Dialing Error"
	end
	local function getGateTypeLabel()
        if localType == "Pegasus" then return "Pegasus"
        elseif localType == "Universe" then return "Universe"
        else return "MilkyWay" end
    end    
	function gate.getEnergyRequiredToDial(address) 
		return _stargate.getEnergyRequiredToDial(address) 
	end
    function gate.engage() return _stargate.engageGate end
    function gate.sendIrisCode(code) return _stargate.sendIrisCode(code) end
    local detectedType = getGateTypeLabel()
    gate.config = config or { idc = "0000", irisMode = 1, autoIris = false }
    gate.currentAddress = {}
    gate.isDialing = false
    gate.dialQueue = {}
    gate.currentDialIndex = 1
    gate.renderCallback = nil
    function gate.getGateType() return localType end
    function gate.getStatus() return _stargate.getGateStatus() end
    function gate.getEnergy()
		if _stargate.getEnergyStored then
			return _stargate.getEnergyStored() or 0
		end
		return 0
	end
	function gate.getMaxEnergy()
		if _stargate.getMaxEnergyStored then
			return _stargate.getMaxEnergyStored() or 1
		end
		return 1
	end
    function gate.getStatusString()
        local state = _stargate.getIrisState()
        return (type(state) == "table" and state[1] or state):upper()
    end
	function gate.getLockedString()
		local dialed = _stargate.getDialedAddress()
		if not dialed or #dialed == 0 then 
			return "" 
		end		
		local str = ""
		for i = 1, #dialed do
			str = str .. i
		end
		return str
	end
    function gate.glyphID()
        if gate.isDialing and gate.dialQueue[gate.currentDialIndex] then
            return gate.dialQueue[gate.currentDialIndex]
        end
        return nil
    end
    function gate.irisToggle()
        gate.config.irisMode = (gate.config.irisMode % 3) + 1
        local irisStatus = gate.getStatusString()
        
        if gate.config.irisMode == 1 and irisStatus == "CLOSED" then
            _stargate.toggleIris() 
        elseif gate.config.irisMode == 3 and irisStatus == "OPENED" then
            _stargate.toggleIris() 
        end
        
        if _G.Logger then _G.Logger.log("Iris Mode changed to: " .. gate.config.irisMode, "SYS") end
        return gate.config.irisMode
    end
    function gate.getDialedAddress() return _stargate.getDialedAddress() end
    function gate.getIrisState() return _stargate.getIrisState() end
    function gate.toggleIris() _stargate.toggleIris() end
    function gate.getIrisType() return _stargate.getIrisType() end
    function gate.disengage()
        if _G.Logger then _G.Logger.log("Disengaging gate", "SYS") end
        _stargate.disengageGate()
        _stargate.abortDialing()
        if gate.config.irisMode == 2 then 
            local irisStatus = gate.getStatusString()
            if irisStatus:find("CLOSE") then
                _stargate.toggleIris()
            end
        end
        gate.isDialing = false
        gate.currentAddress = {}
        gate.dialQueue = {}
        gate.currentDialIndex = 1
    end
	function gate.getDialedAddress() 
		local address = _stargate.getDialedAddress()
		Logger.log("dialed address: " .. tostring(address), "SYS")
		return address
	end
	function gate.onDialAddress(entry, renderCallback)
		local displayName = entry.name or "Unknown Gate"
		local currentGateType = gate.getGateType()
		local targetStr = table.concat(gate.dialQueue or {}, "-")
		Logger.log("Dialing " .. targetStr .. ": [" .. displayName .. "]", "SYS")
		local destType = entry.gateType
		local addressToUse = entry.addresses[detectedType]		
		if not addressToUse then 
			if _G.Logger then _G.Logger.log("Dial Fail: No address for " .. detectedType, "ERR") end
			return false 
		end
        local totalLength = 7
        if detectedType == "Universe" or destType == "Universe" then totalLength = 9
        elseif (detectedType == "MilkyWay" and destType == "Pegasus") or (detectedType == "Pegasus" and destType == "MilkyWay") then totalLength = 8
        elseif entry.isIntergalactic then totalLength = 8 end
        local symbolsNeededFromBook = totalLength - 1
        local finalAddress = {}
        for i = 1, symbolsNeededFromBook do finalAddress[i] = addressToUse[i] end
		
        local success, data = gate.resolveAddress(finalAddress)
		if not success then
			if _G.Logger then _G.Logger.log("Invalid Address: " .. (data.error or "Unknown"), "") end
			return false, "INVALID_ADDRESS"
		end
		gate.dialQueue = data.address
		table.insert(gate.dialQueue, pointsOfOrigin[detectedType] or "Point of Origin")
		local canDial, errReason = gate.canAffordDial(finalAddress)
		if not canDial then
			if _G.Logger then _G.Logger.log("Power Error: " .. errReason, "") end
			return false, errReason
		end
		gate.isDialing = true
		gate.currentDialIndex = 1
		gate.renderCallback = renderCallback
		local status, err = pcall(function() _stargate.engageSymbol(gate.dialQueue[1]) end)		
		if status then
			if gate.renderCallback then
				gate.renderCallback(1, gate.dialQueue, false)
			end
		else
			if _G.Logger then _G.Logger.log("Engage Error: " .. tostring(err), "ERR") end
			gate.isDialing = false
			return false
		end
        return true
    end
	function gate.onChevronLit(chevronIndex)
		if not gate.isDialing then return end
		if gate.currentDialIndex < #gate.dialQueue then
			gate.applyDialDelay()
			gate.currentDialIndex = gate.currentDialIndex + 1
			_stargate.engageSymbol(gate.dialQueue[gate.currentDialIndex])
		else
			gate.applyDialDelay()
			_stargate.engageGate()
		end
	end
    function gate.handleEvents(event, p1, p2, p3)
        if event == "stargate_wormhole_open_unstable" then
            if gate.renderCallback then gate.renderCallback("gateopen", nil, true) end
            if gate.isDialing then
                gate.isDialing = false
                if gate.config.idc and gate.config.idc ~= "" then
                    gate.idcTimer = os.startTimer(3)
                    if _G.Logger then _G.Logger.log("Wormhole Open. Sending IDC in 3s...", "SEC") end
                end
            end
        end
        if event == "timer" and p1 == gate.idcTimer then
            if _stargate.sendIrisCode then 
                _stargate.sendIrisCode(gate.config.idc) 
                if _G.Logger then _G.Logger.log("IDC Sent: " .. gate.config.idc, "SEC") end
            end
            gate.idcTimer = nil
        end

        if event == "stargate_disconnected" then 
            gate.disengage() 
            gate.idcTimer = nil
        end
    end
    function gate.resolveAddress(remoteAddress)
        if not remoteAddress then return false, { error = "ADDRESS_MISSING" } end
        local status, numGlyphs = _stargate.getSymbolsNeeded(remoteAddress)
        if status == "address_malformed" then return false, { error = "ADDRESS_INVALID" } end
        local targetAddress = { table.unpack(remoteAddress, 1, tonumber(numGlyphs)) }
        return true, { address = targetAddress }
    end
    return gate
end
return Stargate