--[[
	Tag List App Module

	Lists every CollectionService tag in the game with the number of objects that have it.
	Selecting a tag filters the Explorer to that tag; selecting it again clears the filter.
]]

-- Common Locals
local Main,Lib,Apps,Settings -- Main Containers
local Explorer -- Major Apps
local env,service,createSimple -- Main Locals

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings

	env = data.env
	service = data.service
	createSimple = data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
end

local function main()
	local TagList = {}
	local counts,dirty = {},{} -- tag -> objects in the DataModel with that tag
	local selectedTag,filterText = nil,""
	local watcher,updatePending
	local window,listFrame,statusLabel,rowContext
	local rows = {}

	TagList.Counts = counts

	local function collection()
		return service.CollectionService
	end

	local function countTag(tag)
		local ok,objects = pcall(collection().GetTagged,collection(),tag)
		return ok and type(objects) == "table" and #objects or 0
	end

	local function lowerSort(a,b)
		local la,lb = string.lower(a.Tag),string.lower(b.Tag)
		if la ~= lb then return la < lb end
		return a.Tag < b.Tag
	end

	-- Tags shown in the list: every tag in use, plus the active filter tag even when unused.
	TagList.GetEntries = function()
		local query = string.lower(filterText)
		local entries = {}
		local function include(tag,count)
			if query == "" or string.find(string.lower(tag),query,1,true) then
				entries[#entries+1] = {Tag = tag, Count = count}
			end
		end
		for tag,count in pairs(counts) do
			if count > 0 or tag == selectedTag then include(tag,count) end
		end
		if selectedTag and counts[selectedTag] == nil then include(selectedTag,0) end
		table.sort(entries,lowerSort)
		return entries
	end

	TagList.GetSelectedTag = function()
		return selectedTag
	end

	TagList.SetFilter = function(text)
		filterText = text or ""
		TagList.Render()
	end

	-- Recounts every tag. Also picks up objects outside the reach of tag signals.
	TagList.Refresh = function()
		table.clear(counts)
		table.clear(dirty)
		local ok,tags = pcall(collection().GetAllTags,collection())
		if ok and type(tags) == "table" then
			for _,tag in ipairs(tags) do counts[tag] = countTag(tag) end
		end
		TagList.Render()
	end

	-- Coalesce tag event bursts into one recount of the changed tags.
	local function queueUpdate(tag)
		if tag then dirty[tag] = true end
		if updatePending then return end
		updatePending = true
		task.defer(function()
			updatePending = false
			if not watcher then table.clear(dirty) return end
			for changed in pairs(dirty) do counts[changed] = countTag(changed) end
			table.clear(dirty)
			TagList.Render()
		end)
	end

	-- Only follow tag changes while the panel is open.
	TagList.SetActive = function(active)
		if active then
			if watcher then return end
			watcher = Apps.Tags.Watch(function(_,tag) queueUpdate(tag) end)
			TagList.Refresh()
		elseif watcher then
			watcher:Disconnect()
			watcher = nil
		end
	end

	TagList.IsActive = function()
		return watcher ~= nil
	end

	-- Filters the Explorer to the tag, or clears the filter when the tag is already selected.
	TagList.SelectTag = function(tag)
		if tag == nil or tag == selectedTag then
			Explorer.ClearSearch()
			return
		end
		Explorer.SearchTag(tag)
		if Explorer.Window and Explorer.Window.Closed then Explorer.Window:Show() end
	end

	local function onSearchChanged(query)
		selectedTag = Explorer.GetSearchTag(query)
		TagList.Render()
	end

	-- Keeps the selected row in sync with the Explorer search, however it was changed.
	TagList.AttachExplorer = function()
		if TagList.ExplorerConnection then return end
		TagList.ExplorerConnection = Explorer.OnSearchChanged(onSearchChanged)
		selectedTag = Explorer.GetSearchTag()
	end

	local function paintRow(row)
		local selected = row.Tag ~= nil and row.Tag == selectedTag
		row.Gui.BackgroundColor3 = selected and Settings.Theme.ListSelection or Settings.Theme.Button
		row.Gui.BackgroundTransparency = (selected or row.Hovered) and 0 or 1
	end

	local function showRowContext(row)
		local tag = row.Tag
		if not tag then return end
		if not rowContext then
			rowContext = Lib.ContextMenu.new()
			rowContext.Iconless = true
			rowContext.Width = 160
		end
		rowContext:Clear()
		if tag == selectedTag then
			rowContext:Add({Name = "Clear Explorer filter", OnClick = function() TagList.SelectTag(nil) end})
		else
			rowContext:Add({Name = "Show in Explorer", OnClick = function() TagList.SelectTag(tag) end})
		end
		if env.setclipboard then
			rowContext:Add({Name = "Copy tag name", OnClick = function() env.setclipboard(tag) end})
		end
		rowContext:Show()
	end

	local function newRow(index)
		local row = {}
		local button = createSimple("TextButton",{
			AutoButtonColor = false, BorderSizePixel = 0, BackgroundTransparency = 1,
			BackgroundColor3 = Settings.Theme.Button, Size = UDim2.new(1,0,0,20),
			Text = "", Name = "Row",
		})
		row.Gui = button
		row.NameLabel = createSimple("TextLabel",{
			BackgroundTransparency = 1, Position = UDim2.new(0,6,0,0), Size = UDim2.new(1,-74,1,0),
			Font = Enum.Font.SourceSans, TextSize = 14, TextColor3 = Settings.Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			Name = "TagName", Parent = button,
		})
		row.CountLabel = createSimple("TextLabel",{
			BackgroundTransparency = 1, Position = UDim2.new(1,-66,0,0), Size = UDim2.new(0,60,1,0),
			Font = Enum.Font.SourceSans, TextSize = 14, TextColor3 = Settings.Theme.Text, TextTransparency = 0.35,
			TextXAlignment = Enum.TextXAlignment.Right, Name = "Count", Parent = button,
		})
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				row.Hovered = true
				paintRow(row)
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				row.Hovered = false
				paintRow(row)
			end
		end)
		button.MouseButton1Click:Connect(function()
			if row.Tag then TagList.SelectTag(row.Tag) end
		end)
		button.MouseButton2Click:Connect(function() showRowContext(row) end)
		button.Parent = listFrame
		rows[index] = row
		return row
	end

	TagList.Render = function()
		if not listFrame then return end
		local entries = TagList.GetEntries()
		for i,entry in ipairs(entries) do
			local row = rows[i] or newRow(i)
			row.Tag = entry.Tag
			row.NameLabel.Text = entry.Tag
			row.CountLabel.Text = tostring(entry.Count)
			row.Gui.LayoutOrder = i
			row.Gui.Visible = true
			paintRow(row)
		end
		for i = #entries+1,#rows do
			rows[i].Tag = nil
			rows[i].Hovered = false
			rows[i].Gui.Visible = false
		end

		local tagCount = 0
		for _,count in pairs(counts) do if count > 0 then tagCount += 1 end end
		if selectedTag then
			statusLabel.Text = "Explorer filtered by \""..selectedTag.."\". Click it again to clear."
		elseif tagCount == 0 then
			statusLabel.Text = "No tagged objects in this game"
		elseif #entries == 0 then
			statusLabel.Text = "No tags match the filter"
		else
			statusLabel.Text = tagCount..(tagCount == 1 and " tag" or " tags").." · click one to filter the Explorer"
		end
	end

	TagList.Init = function()
		window = Lib.Window.new()
		window:SetTitle("Tag List")
		window:Resize(260,320)
		TagList.Window = window

		local filterBox = Lib.ViewportTextBox.new()
		filterBox.Position = UDim2.new(0,4,0,4)
		filterBox.Size = UDim2.new(1,-74,0,20)
		filterBox.TextBox.PlaceholderText = "Filter tags"
		filterBox.TextBox.PlaceholderColor3 = Settings.Theme.PlaceholderText
		filterBox.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
			TagList.SetFilter(filterBox:GetText())
		end)
		window:Add(filterBox,"FilterBox")

		local refreshButton = Lib.Button.new()
		refreshButton.Text = "Refresh"
		refreshButton.Position = UDim2.new(1,-66,0,4)
		refreshButton.Size = UDim2.new(0,62,0,20)
		refreshButton.OnClick:Connect(TagList.Refresh)
		window:Add(refreshButton,"RefreshButton")

		local header = createSimple("Frame",{
			BackgroundColor3 = Settings.Theme.Main2, BorderSizePixel = 0,
			Position = UDim2.new(0,0,0,28), Size = UDim2.new(1,0,0,18), Name = "Header",
		})
		createSimple("TextLabel",{
			BackgroundTransparency = 1, Position = UDim2.new(0,6,0,0), Size = UDim2.new(1,-74,1,0),
			Font = Enum.Font.SourceSansBold, TextSize = 14, TextColor3 = Settings.Theme.Text, TextTransparency = 0.3,
			TextXAlignment = Enum.TextXAlignment.Left, Text = "Tag", Parent = header,
		})
		createSimple("TextLabel",{
			BackgroundTransparency = 1, Position = UDim2.new(1,-66,0,0), Size = UDim2.new(0,60,1,0),
			Font = Enum.Font.SourceSansBold, TextSize = 14, TextColor3 = Settings.Theme.Text, TextTransparency = 0.3,
			TextXAlignment = Enum.TextXAlignment.Right, Text = "Objects", Parent = header,
		})
		window:Add(header,"Header")

		listFrame = createSimple("ScrollingFrame",{
			BackgroundTransparency = 1, BorderSizePixel = 0,
			Position = UDim2.new(0,0,0,48), Size = UDim2.new(1,0,1,-70),
			CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6, ScrollBarImageColor3 = Settings.Theme.Outline2,
			BottomImage = "", TopImage = "", ScrollingDirection = Enum.ScrollingDirection.Y,
			Name = "TagRows",
		})
		createSimple("UIListLayout",{SortOrder = Enum.SortOrder.LayoutOrder, Parent = listFrame})
		window:Add(listFrame,"List")

		statusLabel = Lib.Label.new()
		statusLabel.Position = UDim2.new(0,6,1,-20)
		statusLabel.Size = UDim2.new(1,-12,0,20)
		statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
		statusLabel.TextTransparency = 0.35
		statusLabel.Text = ""
		window:Add(statusLabel,"Status")

		TagList.AttachExplorer()

		window.OnActivate:Connect(function() TagList.SetActive(true) end)
		window.OnDeactivate:Connect(function() TagList.SetActive(false) end)
		TagList.Render()
	end

	return TagList
end

return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
