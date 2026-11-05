--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.DataService)
local World = require(script.Parent.WorldService)
local GameService = {}
local lastAction: {[Player]: number} = {}
local stateEvent: RemoteEvent

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function inventoryUsed(profile: any): number
	local total = 0
	for _, amount in pairs(profile.Inventory) do total += amount end
	return total
end

local function sendState(player: Player, message: string?)
	if player:GetAttribute("IslandDataLoaded") ~= true then return end
	local profile = Data.Get(player)
	if not profile or not stateEvent then return end
	stateEvent:FireClient(player, {
		Inventory = profile.Inventory, Health = profile.Health, Hunger = profile.Hunger,
		Thirst = profile.Thirst, Shells = profile.Shells, Level = profile.Level,
		XP = profile.XP, Crafted = profile.Crafted, Buildings = profile.Buildings,
		Missions = profile.Missions, Gathered = profile.Gathered, Message = message,
	})
end

local function message(player: Player, text: string)
	sendState(player, text)
end

local function addXP(profile: any, amount: number)
	profile.XP += amount
	while profile.XP >= 100 do
		profile.XP -= 100
		profile.Level += 1
	end
end

local function canAfford(profile: any, cost: {[string]: number}): boolean
	for item, amount in pairs(cost) do
		if (profile.Inventory[item] or 0) < amount then return false end
	end
	return true
end

local function pay(profile: any, cost: {[string]: number})
	for item, amount in pairs(cost) do profile.Inventory[item] -= amount end
end

local function tryGather(player: Player, target: any)
	if typeof(target) ~= "Instance" or not target:IsA("Model") or not CollectionService:HasTag(target, "SurvivalResource") then return end
	if not target:IsDescendantOf(World.GetResourceFolder()) or target:GetAttribute("Health") == nil or target:GetAttribute("Health") <= 0 then return end
	local root = rootOf(player)
	local resourceRoot = target.PrimaryPart
	if not root or not resourceRoot or (root.Position - resourceRoot.Position).Magnitude > 20 then return end
	local profile = Data.Get(player)
	local kind = target:GetAttribute("ResourceType")
	local definition = if type(kind) == "string" then Config.Resources[kind] else nil
	if not profile or not definition then return end
	local amount = definition.Amount
	if definition.Item == "Wood" and profile.Crafted.StoneAxe then amount *= 2 end
	local freeSlots = Config.MaxInventory - inventoryUsed(profile)
	if freeSlots <= 0 then message(player, "Your pack is full. Make room before gathering more."); return end
	local gained = math.min(amount, freeSlots)
	profile.Inventory[definition.Item] = (profile.Inventory[definition.Item] or 0) + gained
	profile.Gathered[definition.Item] = (profile.Gathered[definition.Item] or 0) + gained
	local bonus = definition.Bonus
	local bonusGained = 0
	if bonus and freeSlots > gained then
		bonusGained = math.min(bonus.Amount, freeSlots - gained)
		profile.Inventory[bonus.Item] = (profile.Inventory[bonus.Item] or 0) + bonusGained
		profile.Gathered[bonus.Item] = (profile.Gathered[bonus.Item] or 0) + bonusGained
	end
	local damage = if profile.Crafted.StoneAxe and kind == "Tree" then 2 else 1
	local remaining = math.max(0, target:GetAttribute("Health") - damage)
	target:SetAttribute("Health", remaining)
	addXP(profile, 5)
	if definition.Item == "Berries" then profile.Hunger = math.min(100, profile.Hunger + 12) end
	if definition.Item == "Coconut" then profile.Hunger = math.min(100, profile.Hunger + 5); profile.Thirst = math.min(100, profile.Thirst + 18) end
	if definition.Item == "Water" then profile.Thirst = math.min(100, profile.Thirst + 10) end
	if remaining <= 0 then
		World.SetResourceDepleted(target)
		task.delay(Config.ResourceRespawnSeconds, function()
			if target.Parent then World.RespawnResource(target) end
		end)
	end
	local result = string.format("+%d %s", gained, definition.Item)
	if bonusGained > 0 and bonus then result ..= string.format(" · +%d %s", bonusGained, bonus.Item) end
	message(player, result)
end

local function craft(player: Player, recipeId: any)
	if type(recipeId) ~= "string" or #recipeId > 30 then return end
	local profile, recipe = Data.Get(player), Config.Recipes[recipeId]
	if not profile or not recipe then return end
	if profile.Crafted[recipeId] then message(player, "You already made that tool."); return end
	if not canAfford(profile, recipe.Cost) then message(player, "You don't have the ingredients for that yet."); return end
	pay(profile, recipe.Cost)
	profile.Crafted[recipeId] = true
	addXP(profile, 15)
	message(player, recipeId .. " crafted and recorded.")
end

local function build(player: Player, buildingId: any)
	if type(buildingId) ~= "string" or #buildingId > 30 then return end
	local profile, definition = Data.Get(player), Config.Buildings[buildingId]
	local root = rootOf(player)
	if not profile or not definition or not root then return end
	if profile.Buildings[buildingId] then message(player, "You have already built that."); return end
	local valid, groundHeight = World.CanPlaceBuilding(root.Position, player.Character)
	if not valid or not groundHeight then message(player, "Find a clear, level patch of island ground to build on."); return end
	if not canAfford(profile, definition.Cost) then message(player, "Gather more materials before you build."); return end
	World.CreateBuilding(buildingId, player.Name, root.Position.X, root.Position.Z, groundHeight)
	pay(profile, definition.Cost)
	profile.Buildings[buildingId] = { X = root.Position.X, Z = root.Position.Z }
	profile.Health = math.min(100, profile.Health + definition.Health)
	addXP(profile, 20)
	message(player, buildingId .. " built! Your new base is right here.")
end

local function consume(player: Player, item: string)
	local profile = Data.Get(player)
	if item ~= "Berries" and item ~= "Coconut" and item ~= "Water" then return end
	if not profile or (profile.Inventory[item] or 0) < 1 then message(player, "You don't have any " .. item .. "."); return end
	profile.Inventory[item] -= 1
	if item == "Berries" then profile.Hunger = math.min(100, profile.Hunger + 25)
	elseif item == "Coconut" then profile.Hunger = math.min(100, profile.Hunger + 12); profile.Thirst = math.min(100, profile.Thirst + 25)
	else profile.Thirst = math.min(100, profile.Thirst + 30) end
	message(player, item .. " used. You're feeling better.")
end

local function shop(player: Player, action: any)
	local profile = Data.Get(player)
	if not profile or type(action) ~= "string" then return end
	if action == "SellWood" then
		if (profile.Inventory.Wood or 0) < 3 then message(player, "You need 3 wood to trade."); return end
		profile.Inventory.Wood -= 3
		profile.Shells += 10
		message(player, "+10 shells. A good trade!")
	elseif action == "BuyBerries" or action == "BuyWater" then
		local item = if action == "BuyBerries" then "Berries" else "Water"
		local cost = if action == "BuyBerries" then 12 else 15
		local amount = if action == "BuyBerries" then 2 else 1
		if profile.Shells < cost then message(player, "You need more shells for that."); return end
		if inventoryUsed(profile) + amount > Config.MaxInventory then
			message(player, "Your pack is too full. Make room before buying.")
			return
		end
		profile.Shells -= cost
		profile.Inventory[item] = (profile.Inventory[item] or 0) + amount
		message(player, if item == "Berries" then "Bought a handful of berries." else "Bought fresh water.")
	else
		message(player, "That trade isn't available.")
	end
end

local function claimMission(player: Player, missionId: any)
	if type(missionId) ~= "string" or #missionId > 40 then return end
	local profile, mission = Data.Get(player), Config.Missions[missionId]
	if not profile or not mission or profile.Missions[missionId] then return end
	if (profile.Gathered[mission.Item] or 0) < mission.Goal then message(player, "Keep exploring to finish this mission."); return end
	profile.Missions[missionId] = true
	profile.Shells += mission.Reward
	addXP(profile, 25)
	message(player, "Mission complete! +" .. mission.Reward .. " shells.")
end

local function restoreBuildings(player: Player, profile: any)
	local ids = {}
	for id in pairs(profile.Buildings) do table.insert(ids, id) end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local saved = profile.Buildings[id]
		if type(saved) == "table" and type(saved.X) == "number" and type(saved.Z) == "number" then
			local position = Vector3.new(saved.X, 0, saved.Z)
			local valid, groundHeight = World.CanPlaceBuilding(position, nil)
			if valid and groundHeight then World.CreateBuilding(id, player.Name, saved.X, saved.Z, groundHeight) end
		end
	end
end

local function handleAction(player: Player, action: any, payload: any)
	if player:GetAttribute("IslandDataLoaded") ~= true or not Data.Get(player) then return end
	if type(action) ~= "string" or #action > 24 then return end
	local now = os.clock()
	if now - (lastAction[player] or 0) < Config.ActionCooldown then return end
	lastAction[player] = now
	if action == "Gather" then tryGather(player, payload)
	elseif action == "Craft" then craft(player, payload)
	elseif action == "Build" then build(player, payload)
	elseif action == "Eat" then consume(player, "Berries")
	elseif action == "Drink" then consume(player, "Water")
	elseif action == "UseCoconut" then consume(player, "Coconut")
	elseif action == "Shop" then shop(player, payload)
	elseif action == "ClaimMission" then claimMission(player, payload)
	elseif action == "RequestState" then sendState(player) end
end

local function loadPlayer(player: Player)
	player:SetAttribute("IslandDataLoaded", false)
	player:SetAttribute("IslandDataLoadFailed", false)
	local profile = Data.Load(player)
	if not profile or player.Parent ~= Players then
		player:SetAttribute("IslandDataLoadFailed", true)
		return
	end
	restoreBuildings(player, profile)
	player:SetAttribute("IslandDataLoaded", true)
	player:SetAttribute("IslandDataLoadFailed", false)
	local function onCharacterAdded(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		local currentProfile = Data.Get(player)
		if humanoid and currentProfile and player:GetAttribute("IslandDataLoaded") == true then
			humanoid.MaxHealth = 100
			humanoid.Health = currentProfile.Health
		end
		task.wait(0.5)
		sendState(player)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then task.spawn(onCharacterAdded, player.Character) else sendState(player) end
end

function GameService.Initialize(remoteFolder: Folder)
	stateEvent = remoteFolder:WaitForChild("State") :: RemoteEvent
	local actionEvent = remoteFolder:WaitForChild("Action") :: RemoteEvent
	actionEvent.OnServerEvent:Connect(handleAction)
	for _, resource in ipairs(CollectionService:GetTagged("SurvivalResource")) do
		local prompt = resource.PrimaryPart and resource.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then prompt.Triggered:Connect(function(player) handleAction(player, "Gather", resource) end) end
	end
	Players.PlayerAdded:Connect(function(player) task.spawn(loadPlayer, player) end)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(loadPlayer, player) end
	task.spawn(function()
		while true do
			task.wait(12)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = Data.Get(player)
				if profile and player:GetAttribute("IslandDataLoaded") == true then
					profile.Hunger = math.max(0, profile.Hunger - 0.55)
					profile.Thirst = math.max(0, profile.Thirst - 0.85)
					if profile.Hunger <= 0 or profile.Thirst <= 0 then
						profile.Health = math.max(5, profile.Health - 2)
					else profile.Health = math.min(100, profile.Health + 0.2) end
					local character = player.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid then humanoid.Health = profile.Health end
					sendState(player)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.DayLengthSeconds / 24)
			local lighting = game:GetService("Lighting")
			lighting.ClockTime = (lighting.ClockTime + 1) % 24
		end
	end)
	task.spawn(function()
		while true do task.wait(Config.SaveIntervalSeconds); for _, player in ipairs(Players:GetPlayers()) do Data.Save(player) end end
	end)
	Players.PlayerRemoving:Connect(function(player) lastAction[player] = nil end)
end

return GameService
