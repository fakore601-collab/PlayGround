--!strict
local Config = {}

Config.DataStoreName = "SurvivalIsland_PlayerData_v1"
Config.DayLengthSeconds = 720
Config.SaveIntervalSeconds = 60
Config.ActionCooldown = 0.45
Config.MaxInventory = 40
Config.IslandRadius = 430
Config.ResourceRespawnSeconds = 90

Config.Resources = {
	Tree = { Item = "Wood", Amount = 3, Health = 4, Respawn = true },
	Rock = { Item = "Stone", Amount = 2, Health = 3, Respawn = true },
	Bush = { Item = "Berries", Amount = 2, Bonus = { Item = "Fiber", Amount = 1 }, Health = 2, Respawn = true },
	Palm = { Item = "Coconut", Amount = 1, Health = 2, Respawn = true },
	Spring = { Item = "Water", Amount = 2, Health = 1, Respawn = true },
}

Config.Recipes = {
	StoneAxe = { Cost = { Wood = 5, Stone = 3 }, Kind = "Tool", Description = "Speeds up wood gathering." },
	WoodSpear = { Cost = { Wood = 4, Fiber = 2 }, Kind = "Tool", Description = "Crafted keepsake; combat is not implemented." },
	Campfire = { Cost = { Wood = 6, Stone = 3 }, Kind = "Placeable", Description = "Crafted item only; placement and cooking are not implemented." },
}

Config.Buildings = {
	LeanTo = { Cost = { Wood = 12, Fiber = 5 }, Health = 15 },
	BeachCamp = { Cost = { Wood = 8, Stone = 4 }, Health = 0 },
}

Config.Missions = {
	FirstGather = { Goal = 5, Item = "Wood", Reward = 25 },
	FreshWater = { Goal = 3, Item = "Water", Reward = 20 },
}

Config.DefaultProfile = {
	Inventory = { Wood = 0, Stone = 0, Berries = 0, Coconut = 0, Water = 0, Fiber = 0 },
	Health = 100,
	Hunger = 100,
	Thirst = 100,
	Shells = 0,
	XP = 0,
	Level = 1,
	Crafted = {},
	Buildings = {},
	Missions = {},
	Gathered = { Wood = 0, Stone = 0, Berries = 0, Coconut = 0, Water = 0, Fiber = 0 },
}

return Config
