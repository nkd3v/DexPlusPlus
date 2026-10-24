-- Shared CollectionService helpers. Keep tag subscriptions scoped to their consumer.
local collection

local function main()
	local Tags = {}

	Tags.Get = function(obj)
		local tags = collection:GetTags(obj)
		table.sort(tags)
		return tags
	end

	Tags.Has = function(obj, tag)
		return collection:HasTag(obj, tag)
	end

	Tags.Set = function(objects, tag, enabled)
		if tag == "" then return false, "Enter a tag name" end
		local failures = 0
		for _, obj in ipairs(objects) do
			local ok = pcall(function()
				if enabled then
					collection:AddTag(obj, tag)
				else
					collection:RemoveTag(obj, tag)
				end
			end)
			if not ok then failures += 1 end
		end
		return failures == 0, failures > 0 and ("Could not update "..failures.." object(s)") or nil
	end

	-- A nil tag list watches all tags, including names introduced after subscribing.
	Tags.Watch = function(callback, names)
		local connections, watched = {}, {}
		local disconnected = false
		local function watch(tag)
			if watched[tag] or disconnected then return end
			local added = collection:GetInstanceAddedSignal(tag):Connect(function(obj)
				if not disconnected then callback(obj, tag) end
			end)
			local removed = collection:GetInstanceRemovedSignal(tag):Connect(function(obj)
				if not disconnected then callback(obj, tag) end
			end)
			watched[tag] = {added,removed}
		end
		if not names then
			connections[#connections + 1] = collection.TagAdded:Connect(function(tag)
				watch(tag)
				-- The first object's added signal may have fired before watch().
				if not disconnected then callback(nil, tag) end
			end)
			connections[#connections + 1] = collection.TagRemoved:Connect(function(tag)
				local pair = watched[tag]
				if pair then
					for _, connection in ipairs(pair) do connection:Disconnect() end
					watched[tag] = nil
				end
			end)
		end
		for _, tag in ipairs(names or collection:GetAllTags()) do watch(tag) end
		return {Disconnect = function()
			disconnected = true
			for _, connection in ipairs(connections) do connection:Disconnect() end
			for _, pair in pairs(watched) do
				for _, connection in ipairs(pair) do connection:Disconnect() end
			end
			table.clear(connections)
			table.clear(watched)
		end}
	end

	return Tags
end

return {
	InitDeps = function(data) collection = data.service.CollectionService end,
	InitAfterMain = function() end,
	Main = main,
}
