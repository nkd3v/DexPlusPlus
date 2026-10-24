-- The runner loads the actual modules into a small, event-driven Roblox mock.
local count = 0
local function test(name, callback)
	callback()
	count += 1
	print("PASS "..name)
end

local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			local connection = {Connected = true}
			connection.Disconnect = function() connection.Connected = false end
			listeners[#listeners+1] = {connection,callback}
			return connection
		end,
		Fire = function(_, ...)
			for _,listener in ipairs(table.clone(listeners)) do
				if listener[1].Connected then listener[2](...) end
			end
		end,
		Count = function()
			local n = 0
			for _,listener in ipairs(listeners) do if listener[1].Connected then n += 1 end end
			return n
		end,
	}
end

local added,removed,tagged = {},{},{}
local collection = {TagAdded = signal(), TagRemoved = signal()}
function collection:GetInstanceAddedSignal(tag)
	added[tag] = added[tag] or signal()
	return added[tag]
end
function collection:GetInstanceRemovedSignal(tag)
	removed[tag] = removed[tag] or signal()
	return removed[tag]
end
function collection:GetAllTags()
	local result = {}
	for tag,objects in pairs(tagged) do if next(objects) then result[#result+1] = tag end end
	return result
end
function collection:GetTags(obj)
	local result = {}
	for tag,objects in pairs(tagged) do if objects[obj] then result[#result+1] = tag end end
	return result
end
function collection:HasTag(obj,tag)
	return tagged[tag] ~= nil and tagged[tag][obj] == true
end
function collection:AddTag(obj,tag)
	if obj.Locked then error("Object is locked") end
	if self:HasTag(obj,tag) then return end
	tagged[tag] = tagged[tag] or {}
	local isNew = next(tagged[tag]) == nil
	tagged[tag][obj] = true
	self:GetInstanceAddedSignal(tag):Fire(obj)
	if isNew then self.TagAdded:Fire(tag) end
end
function collection:RemoveTag(obj,tag)
	if obj.Locked then error("Object is locked") end
	if not self:HasTag(obj,tag) then return end
	tagged[tag][obj] = nil
	self:GetInstanceRemovedSignal(tag):Fire(obj)
	if not next(tagged[tag]) then self.TagRemoved:Fire(tag) end
end

local game = {
	DescendantAdded = signal(),
	IsA = function(obj,class) return class == "Instance" or obj.ClassName == class end,
	GetAttribute = function(obj,name) return obj.Attributes[name] end,
	SetAttribute = function(obj,name,value)
		if obj.RejectAttribute == name then error("Invalid attribute name") end
		obj.Attributes[name] = value
	end,
	GetAttributes = function(obj) return table.clone(obj.Attributes) end,
}
local function object(name,class)
	return setmetatable({Name = name, ClassName = class or "Folder", Attributes = {}}, {
		__tostring = function(self) return self.Name end,
	})
end
local deferred = {}
local function flush()
	while #deferred > 0 do
		local callbacks = deferred
		deferred = {}
		for _,callback in ipairs(callbacks) do callback() end
	end
end
local constructor = {new = function() return {} end}
local environment = setmetatable({
	game = game,
	Instance = {new = function(class) return object(class,class) end},
	Vector2 = constructor, Vector3 = constructor, UDim = constructor, UDim2 = constructor,
	BrickColor = constructor, Color3 = constructor, NumberSequence = constructor,
	ColorSequence = constructor, NumberRange = constructor, Rect = constructor,
	tick = function() return 0 end,
	task = {defer = function(callback) deferred[#deferred+1] = callback end},
}, {__index = getfenv()})
local apps = {}
local settings = {
	Explorer = {AutoUpdateSearch = true},
	Properties = {MaxConflictCheck = 50, MaxAttributes = 50, ShowAttributes = true},
	Theme = {Important = "error", Text = "text"},
}
local deps = {
	Main = {Elevated = true}, Apps = apps, Settings = settings, env = {},
	API = {CategoryOrder = {Attributes = 1}, Classes = {Instance = {Name = "Instance", Properties = {}}, Folder = {Name = "Folder", Properties = {}, Superclass = {Name = "Instance", Properties = {}}}, RemoteEvent = {Name = "RemoteEvent"},
		RemoteFunction = {Name = "RemoteFunction"}, UnreliableRemoteEvent = {Name = "UnreliableRemoteEvent"}}},
	RMD = {PropertyOrders = {}}, service = {CollectionService = collection, TextService = {}},
}
local function loadModule(name)
	local chunk = assert(loadstring(sources[name],name))
	setfenv(chunk,environment)
	local control = chunk()
	control.InitDeps(deps)
	apps[name] = control.Main()
	return control
end
loadModule("Tags")
local explorerControl = loadModule("Explorer")
local propertiesControl = loadModule("Properties")
explorerControl.InitAfterMain()
propertiesControl.InitAfterMain()
local Tags,Explorer,Properties = apps.Tags,apps.Explorer,apps.Properties
Explorer.SearchExpanded,Explorer.Expanded = {},{}
Explorer.GuiElems.SearchBar = {Text = ""}
Explorer.Selection = {List = {}}
Explorer.ForceUpdate = function() end
Properties.Update,Properties.Refresh = function() end,function() end

local red,blue = object("Red"),object("Blue")
local remote = object("Remote","RemoteFunction")
local root = {Obj = game}
local function node(obj,parent)
	local result = {Obj = obj, Parent = parent}
	environment.nodes[obj] = result
	parent[#parent+1] = result
	return result
end
environment.nodes[game] = root
local redNode,blueNode,remoteNode = node(red,root),node(blue,root),node(remote,root)
collection:AddTag(red,"Enemy")
collection:AddTag(blue,"enemy")

local function matches(query)
	table.clear(Explorer.SearchExpanded)
	local search = Explorer.BuildSearchFunc(query)
	assert(search,"Search did not compile: "..query)
	search(root)
	local result = {}
	for _,child in ipairs(root) do if Explorer.SearchExpanded[child] == 0 then result[child.Obj] = true end end
	return result
end

test("tag filters are exact, case-sensitive, and allow whitespace",function()
	assert(matches("/tag Enemy")[red])
	assert(not matches("/tag Enemy")[blue])
	assert(matches("/tag\t\tEnemy")[red])
	assert(not next(matches("/tag En")))
	assert(not next(matches("/tag")))
end)
test("quoted tag names round-trip punctuation and escape sequences",function()
	for _,tag in ipairs({'A && (B) || C', 'say "hello"', [[path\tag]], "two words", "line\nbreak", "control"..string.char(1)}) do
		collection:AddTag(red,tag)
		assert(matches("/tag "..string.format("%q",tag))[red],tag)
	end
end)
test("name search handles literal backslashes and escaped quotes",function()
	local tricky = object([[a\b"c]])
	local trickyNode = node(tricky,root)
	assert(matches([[a\b]])[tricky])
	assert(matches(string.format("%q",tricky.Name))[tricky])
	trickyNode.Del = true
	assert(not matches([[a\b]])[tricky])
end)
test("OR filters stay grouped when negated or combined with AND",function()
	assert(not next(matches("/remotes && Red")))
	local result = matches("!/remotes")
	assert(result[red] and result[blue] and not result[remote])
	assert(matches("!(/tag Enemy || /remotes)")[blue])
	assert(not matches("!(/tag Enemy || /remotes)")[red])
end)
test("invalid queries retain the previous results and clear restores the tree",function()
	assert(Explorer.DoSearch("/tag Enemy"))
	assert(Explorer.SearchExpanded[redNode] == 0)
	assert(not Explorer.DoSearch("/tag Enemy &&"))
	assert(Explorer.SearchExpanded[redNode] == 0)
	assert(Explorer.GuiElems.SearchBar.TextColor3 == "error")
	Explorer.ClearSearch()
	assert(not next(Explorer.SearchExpanded))
	assert(Explorer.GuiElems.SearchBar.TextColor3 == "text")
end)
test("tag search refreshes additions/removals and stops observing after clearing",function()
	assert(Explorer.DoSearch("/tag Live"))
	assert(Explorer.SearchExpanded[redNode] == nil)
	collection:AddTag(red,"Live")
	flush()
	assert(Explorer.SearchExpanded[redNode] == 0)
	collection:RemoveTag(red,"Live")
	flush()
	assert(Explorer.SearchExpanded[redNode] == nil)
	Explorer.ClearSearch()
	assert(added.Live:Count() == 0 and removed.Live:Count() == 0)
end)
test("all-tag subscriptions discover new names and disconnect cleanly",function()
	local events = 0
	local watcher = Tags.Watch(function() events += 1 end)
	collection:AddTag(red,"BrandNew")
	assert(events > 0)
	local before = events
	collection:AddTag(blue,"BrandNew")
	assert(events == before+1)
	watcher:Disconnect()
	collection:RemoveTag(red,"BrandNew")
	assert(events == before+1)
end)
test("fixed-tag subscriptions survive removal of the last tagged object",function()
	local events = 0
	local watcher = Tags.Watch(function() events += 1 end,{"Future"})
	collection:AddTag(red,"Future")
	collection:RemoveTag(red,"Future")
	collection:AddTag(blue,"Future")
	assert(events == 3)
	watcher:Disconnect()
end)
test("all-tag subscriptions release unused names and reconnect if reused",function()
	local events = 0
	local watcher = Tags.Watch(function() events += 1 end)
	collection:AddTag(red,"Transient")
	collection:RemoveTag(red,"Transient")
	assert(added.Transient:Count() == 0 and removed.Transient:Count() == 0)
	local before = events
	collection:AddTag(blue,"Transient")
	assert(events > before)
	watcher:Disconnect()
end)
test("basic tag search works without an elevated environment",function()
	deps.Main.Elevated = false
	local tag = [[a\b"c && d]]
	collection:AddTag(red,tag)
	assert(Explorer.DoSearch("/tag "..string.format("%q",tag)))
	assert(Explorer.SearchExpanded[redNode] == 0)
	assert(Explorer.SearchExpanded[blueNode] == nil)
	Explorer.ClearSearch()
	deps.Main.Elevated = true
end)
test("tag editing supports multiple objects and reports partial failures",function()
	local locked = object("Locked")
	locked.Locked = true
	local ok,message = Tags.Set({red,locked},"Partial",true)
	assert(not ok and message:find("1 object",1,true))
	assert(Tags.Has(red,"Partial"))
	assert(Tags.Set({red,blue},"Shared",true))
	assert(Tags.Has(red,"Shared") and Tags.Has(blue,"Shared"))
	assert(Tags.Set({red,blue},"Shared",false))
	assert(not Tags.Has(red,"Shared") and not Tags.Has(blue,"Shared"))
	assert(not Tags.Set({red},"",true))
end)
test("property tag checkboxes represent mixed selection and update all selected",function()
	Explorer.Selection.List = {redNode,blueNode}
	Properties.ClassLists = {Instance = {red,blue}}
	local prop = {IsTag = true,TagName = "Enemy",Name = "TAG_Enemy",Class = "Instance",ValueType = {Name = "bool"},Tags = {}}
	Properties.ComputeConflicts(prop)
	assert(Properties.GetPropVal(prop,red) == true)
	assert(Properties.GetPropVal(prop,blue) == false)
	local show = Properties.ShowExplorerProps
	Properties.ShowExplorerProps = function() end
	Properties.SetProp(prop,true)
	assert(Tags.Has(blue,"Enemy"))
	Properties.SetProp(prop,false)
	assert(not Tags.Has(red,"Enemy") and not Tags.Has(blue,"Enemy"))
	Properties.ShowExplorerProps = show
end)
test("selected tag watchers coalesce events and release old selections",function()
	local refreshes = 0
	local show = Properties.ShowExplorerProps
	Properties.ShowExplorerProps = function() refreshes += 1 end
	Explorer.Selection.List = {redNode}
	Properties.WatchTags()
	collection:AddTag(red,"Watched")
	collection:AddTag(red,"WatchedAgain")
	flush()
	assert(refreshes == 1)
	Explorer.Selection.List = {}
	Properties.WatchTags()
	collection:RemoveTag(red,"Watched")
	flush()
	assert(refreshes == 1)
	Properties.ShowExplorerProps = show
end)
test("object tag lists rebuild without reading pseudo-properties from instances",function()
	Explorer.Selection.List = {redNode,blueNode}
	Properties.ShowExplorerProps()
	Explorer.Selection.List = {}
	Properties.ShowExplorerProps()
	flush()
end)
test("editing a false attribute preserves false and same-name changes survive",function()
	Explorer.Selection.List = {redNode}
	red.Attributes.Old = false
	local old = {IsAttribute = true,AttributeName = "Old",Name = "ATTR_Old",Class = "Instance",ValueType = {Name = "bool"}}
	local new = table.clone(old)
	new.Name,new.AttributeName = "ATTR_New","New"
	Properties.SetProp(new,true,true,old)
	assert(red.Attributes.New == false and red.Attributes.Old == nil)
	Properties.SetProp(new,true,true,new)
	assert(red.Attributes.New == false)
	red.RejectAttribute = "Invalid"
	local invalid = table.clone(new)
	invalid.Name,invalid.AttributeName = "ATTR_Invalid","Invalid"
	Properties.SetProp(invalid,true,true,new)
	assert(red.Attributes.New == false, "A failed rename must preserve the original attribute")
	red.RejectAttribute = nil
end)
test("embedded module return values take priority over legacy global exports",function()
	local main = {Elevated = true, AppControls = {}, GetInitDeps = function() return deps end}
	local control = {InitDeps = function() end, Main = function() return "correct module" end}
	local env = setmetatable({
		Main = main, Apps = {}, EmbeddedModules = {Tags = function() return control end},
		gethsfuncs = true, _G = {moduleData = {}},
	}, {__index = getfenv()})
	local chunk = assert(loadstring(sources.Loader))
	setfenv(chunk,env)
	assert(chunk()("Tags") == "correct module")
end)
test("cloneref fallback returns the reference and scans the registry once",function()
	local scans,probes = 0,{}
	local refs = {__mode = "kvs",red}
	local env = setmetatable({
		game = game,
		getreg = function() scans += 1 return {refs} end,
		Instance = {new = function()
			local probe = {Destroy = function(self) self.Destroyed = true end}
			probes[#probes+1] = probe
			refs[#refs+1] = probe
			return probe
		end},
	}, {__index = getfenv()})
	local chunk = assert(loadstring(sources.Cloneref))
	setfenv(chunk,env)
	local clone = chunk()
	assert(clone(red) == red and clone(blue) == blue)
	assert(scans == 1 and #probes == 1 and probes[1].Destroyed)
	assert(refs[1] == nil)
end)
print(count.." regression tests passed.")
