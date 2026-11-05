--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SurvivalIslandRemotes")
local actionEvent = remotes:WaitForChild("Action") :: RemoteEvent
local stateEvent = remotes:WaitForChild("State") :: RemoteEvent
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local COLORS = {
	background = Color3.fromRGB(13, 30, 34), panel = Color3.fromRGB(23, 48, 49), card = Color3.fromRGB(31, 62, 60),
	text = Color3.fromRGB(240, 240, 218), muted = Color3.fromRGB(166, 188, 167), accent = Color3.fromRGB(211, 226, 151),
	button = Color3.fromRGB(101, 138, 82), danger = Color3.fromRGB(188, 113, 86),
}
local inventoryNames = { "Wood", "Stone", "Berries", "Coconut", "Water", "Fiber" }
local itemIcons = { Wood = "🪵", Stone = "🪨", Berries = "🫐", Coconut = "🥥", Water = "💧", Fiber = "🌿" }
local currentState: any = nil
local activeTab = "Inventory"
local messageLabel: TextLabel
local content: ScrollingFrame
local screen: ScreenGui
local navButtons: {TextButton} = {}

local function create(className: string, props: {[string]: any}, parent: Instance): Instance
	local instance = Instance.new(className)
	for key, value in pairs(props) do (instance :: any)[key] = value end
	instance.Parent = parent
	return instance
end

local function corner(instance: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, instance)
end

local function label(parent: Instance, text: string, size: UDim2, position: UDim2, fontSize: number, color: Color3, bold: boolean?): TextLabel
	return create("TextLabel", {
		BackgroundTransparency = 1, Text = text, Size = size, Position = position,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham, TextSize = fontSize,
		TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
	}, parent) :: TextLabel
end

local function button(parent: Instance, text: string, callback: () -> (), width: UDim2?): TextButton
	local result = create("TextButton", {
		Size = width or UDim2.new(0, 112, 0, 38), BackgroundColor3 = COLORS.button, Text = text,
		TextColor3 = COLORS.text, Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = true,
	}, parent) :: TextButton
	corner(result, 9)
	result.Activated:Connect(callback)
	return result
end

local function send(action: string, payload: any?)
	if action ~= "RequestState" and not currentState then return end
	if player:GetAttribute("IslandDataLoaded") ~= true and action ~= "RequestState" then return end
	actionEvent:FireServer(action, payload)
end

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function row(parent: Instance, height: number): Frame
	local frame = create("Frame", {
		Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = COLORS.card, BorderSizePixel = 0,
	}, parent) :: Frame
	corner(frame, 12)
	return frame
end

local function addTitle(text: string, subtitle: string?)
	local heading = label(content, text, UDim2.new(1, -12, 0, 34), UDim2.new(0, 4, 0, 4), 22, COLORS.text, true)
	heading.LayoutOrder = 0
	if subtitle then
		local sub = label(content, subtitle, UDim2.new(1, -12, 0, 38), UDim2.new(0, 4, 0, 36), 13, COLORS.muted, false)
		sub.LayoutOrder = 1
	end
end

local function setMessage(text: string?)
	messageLabel.Text = text or "Gather from nearby resources using their prompts."
end

local function renderInventory()
	addTitle("Your supplies", "Gather nearby trees, rocks, bushes, palms, and springs.")
	for i, item in ipairs(inventoryNames) do
		local entry = row(content, 54)
		entry.LayoutOrder = i + 1
		label(entry, (itemIcons[item] or "•") .. "  " .. item, UDim2.new(0.62, -12, 1, 0), UDim2.new(0, 14, 0, 0), 16, COLORS.text, true)
		label(entry, tostring(currentState.Inventory[item] or 0), UDim2.new(0.28, 0, 1, 0), UDim2.new(0.68, 0, 0, 0), 17, COLORS.accent, true).TextXAlignment = Enum.TextXAlignment.Right
	end
	for _, item in ipairs({ "Berries", "Coconut", "Water" }) do
		local count = currentState.Inventory[item] or 0
		if count > 0 then
			local entry = row(content, 54)
			entry.LayoutOrder = #inventoryNames + (item == "Berries" and 1 or item == "Coconut" and 2 or 3)
			label(entry, "Use " .. item, UDim2.new(0.48, -12, 1, 0), UDim2.new(0, 14, 0, 0), 15, COLORS.text, true)
			local action = item == "Berries" and "Eat" or item == "Water" and "Drink" or "UseCoconut"
			button(entry, "USE  ·  " .. count, function() send(action) end, UDim2.new(0, 112, 0, 36)).Position = UDim2.new(1, -124, 0.5, -18)
		end
	end
end

local function renderRecipes(isBuilding: boolean)
	local definitions = if isBuilding then Config.Buildings else Config.Recipes
	addTitle(if isBuilding then "Build a base" else "Crafting", if isBuilding then "Shelter restores health. Your base appears where you are standing." else "The stone axe speeds up wood gathering. Spear combat and campfire placement/cooking are not implemented.")
	local order = 1
	for id, definition in pairs(definitions) do
		local crafted = if isBuilding then currentState.Buildings[id] else currentState.Crafted[id]
		local costs = {}
		for item, amount in pairs(definition.Cost) do table.insert(costs, tostring(amount) .. " " .. item) end
		table.sort(costs)
		local description: string? = nil
		if not isBuilding then description = Config.Recipes[id].Description end
		local entry = row(content, if description then 94 else 78)
		entry.LayoutOrder = order + 2
		order += 1
		label(entry, id, UDim2.new(0.53, -12, 0, 24), UDim2.new(0, 14, 0, 7), 15, COLORS.text, true)
		label(entry, table.concat(costs, "  ·  "), UDim2.new(0.55, -12, 0, 22), UDim2.new(0, 14, 0, 31), 11, COLORS.muted, false)
		if description then label(entry, description, UDim2.new(0.68, -12, 0, 34), UDim2.new(0, 14, 0, 53), 10, COLORS.muted, false) end
		local action = if isBuilding then "Build" else "Craft"
		local control = button(entry, if crafted then "DONE" else string.upper(action), function() send(action, id) end, UDim2.new(0, 96, 0, 38))
		control.Position = UDim2.new(1, -108, 0.5, -19)
		control.BackgroundColor3 = if crafted then COLORS.panel else COLORS.button
		control.Active = not crafted
	end
end

local function renderMissions()
	addTitle("Island missions", "Complete objectives and claim your shell rewards.")
	for i, mission in pairs(Config.Missions) do
		local gathered = currentState.Gathered[mission.Item] or 0
		local completed = currentState.Missions[i]
		local progress = math.min(gathered, mission.Goal)
		local entry = row(content, 78)
		entry.LayoutOrder = i == "FirstGather" and 3 or 4
		label(entry, i, UDim2.new(0.55, -12, 0, 24), UDim2.new(0, 14, 0, 9), 14, COLORS.text, true)
		label(entry, string.format("%s  %d / %d  ·  +%d shells", mission.Item, progress, mission.Goal, mission.Reward), UDim2.new(0.63, -12, 0, 28), UDim2.new(0, 14, 0, 39), 11, COLORS.muted, false)
		local control = button(entry, if completed then "CLAIMED" else "CLAIM", function() send("ClaimMission", i) end, UDim2.new(0, 96, 0, 38))
		control.Position = UDim2.new(1, -108, 0.5, -19)
		control.Active = not completed and gathered >= mission.Goal
		if completed or gathered < mission.Goal then control.BackgroundColor3 = COLORS.panel end
	end
end

local function renderShop()
	addTitle("Island trader", "Balance: " .. tostring(currentState.Shells) .. " shells. Trade spare wood for supplies.")
	local offers = {
		{ "SellWood", "Trade 3 Wood", "+10 shells" },
		{ "BuyBerries", "Buy berries", "12 shells · restores hunger" },
		{ "BuyWater", "Buy fresh water", "15 shells · restores thirst" },
	}
	for i, offer in ipairs(offers) do
		local entry = row(content, 66)
		entry.LayoutOrder = i + 2
		label(entry, offer[2], UDim2.new(0.55, -12, 1, 0), UDim2.new(0, 14, 0, 0), 14, COLORS.text, true)
		label(entry, offer[3], UDim2.new(0.32, 0, 1, 0), UDim2.new(0.59, 0, 0, 0), 11, COLORS.muted, false)
		local control = button(entry, "TRADE", function() send("Shop", offer[1]) end, UDim2.new(0, 82, 0, 36))
		control.Position = UDim2.new(1, -94, 0.5, -18)
	end
end

local function render()
	if not currentState then return end
	clearContent()
	if activeTab == "Inventory" then renderInventory()
	elseif activeTab == "Craft" then renderRecipes(false)
	elseif activeTab == "Build" then renderRecipes(true)
	elseif activeTab == "Missions" then renderMissions()
	else renderShop() end
	setMessage(currentState.Message)
end

screen = create("ScreenGui", {
	Name = "SurvivalIslandHUD", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 10,
}, player:WaitForChild("PlayerGui")) :: ScreenGui
local main = create("Frame", {
	Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.92, 0, 0.82, 0), BackgroundColor3 = COLORS.background, BorderSizePixel = 0,
}, screen) :: Frame
local function resizeMain()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewport = camera.ViewportSize
	local width = math.min(viewport.X * 0.94, 720)
	local height = math.min(viewport.Y * (if viewport.Y < 460 then 0.96 else 0.88), 560)
	main.Size = UDim2.fromOffset(width, height)

	local compact = viewport.Y < 460
	local header = main:FindFirstChild("Header") :: Frame?
	local vitals = main:FindFirstChild("Vitals") :: Frame?
	local nav = main:FindFirstChild("Nav") :: Frame?
	local content = main:FindFirstChild("Content") :: ScrollingFrame?
	local footer = main:FindFirstChild("Footer") :: Frame?
	local statusLabel = if header then header:FindFirstChild("Status") :: TextLabel? else nil
	if compact then
		if header then header.Position, header.Size = UDim2.new(0, 14, 0, 6), UDim2.new(1, -28, 0, 54) end
		if statusLabel then statusLabel.Position, statusLabel.Size, statusLabel.TextSize = UDim2.new(0, 4, 0, 27), UDim2.new(1, -8, 0, 25), 10 end
		if vitals then vitals.Position, vitals.Size = UDim2.new(0, 14, 0, 64), UDim2.new(1, -28, 0, 52) end
		if nav then nav.Position, nav.Size = UDim2.new(0, 14, 0, 124), UDim2.new(1, -28, 0, 36) end
		if content then content.Position, content.Size = UDim2.new(0, 14, 0, 166), UDim2.new(1, -28, 1, -212) end
		if footer then footer.Size, footer.Position = UDim2.new(1, -28, 0, 32), UDim2.new(0, 14, 1, -38) end
	else
		if header then header.Position, header.Size = UDim2.new(0, 14, 0, 12), UDim2.new(1, -28, 0, 76) end
		if statusLabel then statusLabel.Position, statusLabel.Size, statusLabel.TextSize = UDim2.new(0, 4, 0, 33), UDim2.new(1, -8, 0, 38), 12 end
		if vitals then vitals.Position, vitals.Size = UDim2.new(0, 14, 0, 90), UDim2.new(1, -28, 0, 72) end
		if nav then nav.Position, nav.Size = UDim2.new(0, 14, 0, 174), UDim2.new(1, -28, 0, 42) end
		if content then content.Position, content.Size = UDim2.new(0, 14, 0, 222), UDim2.new(1, -28, 1, -274) end
		if footer then footer.Size, footer.Position = UDim2.new(1, -28, 0, 38), UDim2.new(0, 14, 1, -46) end
	end
	for _, navButton in ipairs(navButtons) do
		navButton.TextSize = if viewport.X < 390 then 9 else 11
		navButton.Size = UDim2.new(0.2, -3, 0, if compact then 32 else 38)
	end
end
corner(main, 20)
create("UIStroke", { Color = Color3.fromRGB(75, 111, 87), Transparency = 0.25, Thickness = 1 }, main)

local header = create("Frame", { Name = "Header", Size = UDim2.new(1, -28, 0, 76), Position = UDim2.new(0, 14, 0, 12), BackgroundTransparency = 1 }, main)
label(header, "✳  SURVIVAL ISLAND", UDim2.new(0.62, 0, 0, 26), UDim2.new(0, 4, 0, 0), 19, COLORS.accent, true)
local status = label(header, "Loading survivor data…", UDim2.new(1, -8, 0, 38), UDim2.new(0, 4, 0, 33), 12, COLORS.muted, false)
status.Name = "Status"

local vitals = create("Frame", { Name = "Vitals", Size = UDim2.new(1, -28, 0, 72), Position = UDim2.new(0, 14, 0, 90), BackgroundColor3 = COLORS.panel, BorderSizePixel = 0 }, main)
corner(vitals, 12)
local vitalLabels = {}
for i, name in ipairs({ "Health", "Hunger", "Thirst" }) do
	local block = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1/3, -10, 1, -8), Position = UDim2.new((i-1)/3, 10, 0, 4) }, vitals)
	label(block, name, UDim2.new(1, 0, 0, 21), UDim2.new(), 11, COLORS.muted, true)
	local value = label(block, "100", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 24), 17, COLORS.text, true)
	vitalLabels[name] = value
end

local nav = create("Frame", { Name = "Nav", Size = UDim2.new(1, -28, 0, 42), Position = UDim2.new(0, 14, 0, 174), BackgroundTransparency = 1 }, main)
local navLayout = create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, nav)
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navButtons = {}
for i, tab in ipairs({ "Inventory", "Craft", "Build", "Missions", "Shop" }) do
	local navButton = button(nav, tab, function() activeTab = tab; render() end, UDim2.new(0, 112, 0, 38))
	navButton.LayoutOrder = i
	navButton.Size = UDim2.new(0.2, -3, 0, 38)
	navButton.TextSize = 11
	navButton.Active = false
	table.insert(navButtons, navButton)
end

content = create("ScrollingFrame", {
	Name = "Content", Position = UDim2.new(0, 14, 0, 222), Size = UDim2.new(1, -28, 1, -274),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = COLORS.accent,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, main) :: ScrollingFrame
create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
local footer = create("Frame", { Name = "Footer", Size = UDim2.new(1, -28, 0, 38), Position = UDim2.new(0, 14, 1, -46), BackgroundTransparency = 1 }, main)
messageLabel = label(footer, "Gather from nearby resources using their prompts.", UDim2.new(1, 0, 1, 0), UDim2.new(), 12, COLORS.accent, false)
resizeMain()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeMain) end

local function updateLoadNotice()
	if currentState then return end
	local failed = player:GetAttribute("IslandDataLoadFailed") == true
	status.Text = if failed then "DATA LOAD FAILED · Rejoin to try again" else "Loading survivor data…"
	messageLabel.Text = if failed then "Your progress wasn't changed. Please rejoin once data services are available." else "Survivor controls unlock after your profile loads."
	for _, navButton in ipairs(navButtons) do navButton.Active = false end
end

local function updateHUD(state: any)
	currentState = state
	for _, navButton in ipairs(navButtons) do navButton.Active = true end
	status.Text = string.format("LEVEL %d   ·   %d SHELLS   ·   PACK %d / %d", state.Level, state.Shells, (function()
		local total = 0
		for _, count in pairs(state.Inventory) do total += count end
		return total
	end)(), Config.MaxInventory)
	vitalLabels.Health.Text = "♥  " .. math.floor(state.Health)
	vitalLabels.Hunger.Text = "◉  " .. math.floor(state.Hunger)
	vitalLabels.Thirst.Text = "≈  " .. math.floor(state.Thirst)
	render()
end
stateEvent.OnClientEvent:Connect(updateHUD)
player:GetAttributeChangedSignal("IslandDataLoadFailed"):Connect(updateLoadNotice)
player:GetAttributeChangedSignal("IslandDataLoaded"):Connect(function()
	if not currentState then updateLoadNotice() end
	if player:GetAttribute("IslandDataLoaded") == true then send("RequestState") end
end)
updateLoadNotice()
send("RequestState")
