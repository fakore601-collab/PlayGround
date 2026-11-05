--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local store = DataStoreService:GetDataStore(Config.DataStoreName)
local profiles: {[Player]: any} = {}
local saving: {[Player]: boolean} = {}

local function clone(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = clone(child) end
	return result
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function sanitize(raw: any): any
	local profile = clone(Config.DefaultProfile)
	if type(raw) ~= "table" then return profile end
	for _, key in ipairs({ "Health", "Hunger", "Thirst" }) do
		if isFiniteNumber(raw[key]) then profile[key] = math.clamp(raw[key], 0, 100) end
	end
	for _, key in ipairs({ "Shells", "XP" }) do
		if isFiniteNumber(raw[key]) then profile[key] = math.clamp(math.floor(raw[key]), 0, 1000000) end
	end
	if isFiniteNumber(raw.Level) then profile.Level = math.clamp(math.floor(raw.Level), 1, 1000000) end
	if type(raw.Inventory) == "table" then
		local items = {}
		for item in pairs(profile.Inventory) do table.insert(items, item) end
		table.sort(items)
		local remaining = Config.MaxInventory
		for _, item in ipairs(items) do
			local amount = raw.Inventory[item]
			if isFiniteNumber(amount) then
				local accepted = math.clamp(math.floor(amount), 0, remaining)
				profile.Inventory[item] = accepted
				remaining -= accepted
			end
		end
	end
	if type(raw.Crafted) == "table" then
		for id in pairs(Config.Recipes) do
			if type(raw.Crafted[id]) == "boolean" then profile.Crafted[id] = raw.Crafted[id] end
		end
	end
	if type(raw.Missions) == "table" then
		for id in pairs(Config.Missions) do
			if type(raw.Missions[id]) == "boolean" then profile.Missions[id] = raw.Missions[id] end
		end
	end
	if type(raw.Buildings) == "table" then
		for id, value in pairs(raw.Buildings) do
			if type(id) == "string" and Config.Buildings[id] then
				if value == true then
					-- Migrate early prototype saves by restoring legacy bases at the island center.
					profile.Buildings[id] = { X = 0, Z = 0 }
				elseif type(value) == "table" and isFiniteNumber(value.X) and isFiniteNumber(value.Z) then
					profile.Buildings[id] = {
						X = math.clamp(value.X, -Config.IslandRadius, Config.IslandRadius),
						Z = math.clamp(value.Z, -Config.IslandRadius, Config.IslandRadius),
					}
				end
			end
		end
	end
	if type(raw.Gathered) == "table" then
		for item in pairs(profile.Gathered) do
			local amount = raw.Gathered[item]
			if isFiniteNumber(amount) then profile.Gathered[item] = math.clamp(math.floor(amount), 0, 1000000) end
		end
	end
	return profile
end

function DataService.Load(player: Player): any?
	-- Never leave an earlier session's profile available if a retry fails.
	profiles[player] = nil
	local success, result = pcall(function()
		return store:GetAsync("player_" .. player.UserId)
	end)
	if not success then
		warn("[SurvivalIsland] Data load failed for", player.UserId, result)
		return nil
	end
	if player.Parent ~= Players then return nil end
	local profile = sanitize(result)
	profiles[player] = profile
	return profile
end

function DataService.Get(player: Player): any?
	return profiles[player]
end

function DataService.Save(player: Player): boolean
	while saving[player] do task.wait() end
	local profile = profiles[player]
	if not profile then return false end
	saving[player] = true
	local snapshot = clone(profile)
	local success, message = pcall(function()
		store:UpdateAsync("player_" .. player.UserId, function()
			return snapshot
		end)
	end)
	saving[player] = nil
	if not success then warn("[SurvivalIsland] Data save failed for", player.UserId, message) end
	return success
end

function DataService.Remove(player: Player)
	profiles[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	DataService.Save(player)
	DataService.Remove(player)
end)

game:BindToClose(function()
	local pending = 0
	for _, player in ipairs(Players:GetPlayers()) do
		pending += 1
		task.spawn(function()
			DataService.Save(player)
			pending -= 1
		end)
	end
	while pending > 0 do task.wait() end
end)

return DataService
