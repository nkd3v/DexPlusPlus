--[[
	Dex++
	Version 3.1.2
	
	Developed by Chillz
	
	Dex++ is a revival of Moon's Dex, made to fulfill Moon's Dex prophecy.
]]

local selection
local nodes = {}

cloneref = cloneref or (function()
	local instanceList
	local scanned = false
	return function(ref)
		if not getreg then return ref end
		if not scanned then
			scanned = true
			local probe = Instance.new("Part")
			local ok,registry = pcall(getreg)
			if ok and type(registry) == "table" then
				for _,value in pairs(registry) do
					if type(value) == "table" and rawget(value,"__mode") == "kvs" then
						for _,obj in pairs(value) do
							if obj == probe then instanceList = value break end
						end
					end
					if instanceList then break end
				end
			end
			probe:Destroy()
		end
		if instanceList then
			for key,obj in pairs(instanceList) do
				if obj == ref then instanceList[key] = nil break end
			end
		end
		return ref
	end
end)()

local oldgame = cloneref(game)
local game = cloneref(workspace.Parent)
