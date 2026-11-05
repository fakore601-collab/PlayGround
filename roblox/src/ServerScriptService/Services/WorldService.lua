--!strict
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Shared.Config)
local WorldService = {}
local resourceFolder: Folder
local buildingFolder: Folder
local groundFolder: Folder

local BUILDING_SIZE = Vector2.new(12, 10)
local ISLAND_HALF_WIDTH = 330
local ISLAND_HALF_DEPTH = 235

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Color, p.Material = name, size, position, color, material
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

local function makeResource(kind: string, position: Vector3, index: number)
	local model = Instance.new("Model")
	model.Name = kind .. string.format("_%02d", index)
	model:SetAttribute("ResourceType", kind)
	model:SetAttribute("Health", Config.Resources[kind].Health)
	model:SetAttribute("MaxHealth", Config.Resources[kind].Health)
	model:SetAttribute("ResourceIndex", index)
	local root: Part
	if kind == "Tree" or kind == "Palm" then
		root = part(model, "Trunk", Vector3.new(2.4, 17, 2.4), position + Vector3.new(0, 8.5, 0), Color3.fromRGB(112, 82, 52), Enum.Material.Wood)
		root.Shape = Enum.PartType.Cylinder
		if kind == "Palm" then
			local crown = part(model, "PalmCrown", Vector3.new(13, 3, 13), position + Vector3.new(0, 18, 0), Color3.fromRGB(68, 139, 75), Enum.Material.Grass, Enum.PartType.Ball)
			crown.CanCollide = false
		else
			local crown = part(model, "Canopy", Vector3.new(13, 12, 13), position + Vector3.new(0, 17, 0), Color3.fromRGB(55, 119, 62), Enum.Material.Grass, Enum.PartType.Ball)
			crown.CanCollide = false
		end
	elseif kind == "Rock" then
		root = part(model, "Rock", Vector3.new(8, 6, 7), position + Vector3.new(0, 3, 0), Color3.fromRGB(123, 132, 117), Enum.Material.Rock, Enum.PartType.Ball)
	elseif kind == "Bush" then
		root = part(model, "BerryBush", Vector3.new(7, 5, 7), position + Vector3.new(0, 2.5, 0), Color3.fromRGB(68, 140, 70), Enum.Material.Grass, Enum.PartType.Ball)
		local berries = part(model, "Berries", Vector3.new(1.2, 1.2, 1.2), position + Vector3.new(1, 4, -2), Color3.fromRGB(177, 82, 128), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		berries.CanCollide = false
	else
		root = part(model, "Spring", Vector3.new(9, 0.6, 9), position + Vector3.new(0, 0.4, 0), Color3.fromRGB(89, 190, 188), Enum.Material.Glass, Enum.PartType.Cylinder)
		root.Transparency = 0.2
	end
	root.Name = "ResourceRoot"
	root:SetAttribute("IsResourceRoot", true)
	root.CanCollide = kind == "Rock"
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Gather"
	prompt.ObjectText = kind
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	model.PrimaryPart = root
	-- Parts are created directly at their final world positions; PivotTo would offset the whole model.
	model.Parent = resourceFolder
	CollectionService:AddTag(model, "SurvivalResource")
end

local function islandPosition(rng: Random): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = math.sqrt(rng:NextNumber(0.06, 0.88)) * 300
	return Vector3.new(math.cos(angle) * radius, 7, math.sin(angle) * radius * 0.72)
end

local function groundAt(x: number, z: number, character: Model?): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: {Instance} = { resourceFolder, buildingFolder }
	if character then table.insert(excluded, character) end
	params.FilterDescendantsInstances = excluded
	params.IgnoreWater = false
	local hit = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -280, 0), params)
	if not hit or hit.Material == Enum.Material.Water then return nil end
	local instance = hit.Instance
	if instance == Workspace.Terrain or instance.Name == "IslandSandShelf" or instance.Name == "IslandHeart" or instance.Name == "BeachSpawn" then return hit end
	return nil
end

local function insideIsland(x: number, z: number): boolean
	local nx, nz = x / (ISLAND_HALF_WIDTH - 8), z / (ISLAND_HALF_DEPTH - 8)
	return nx * nx + nz * nz <= 1
end

function WorldService.GetIslandGroundHeight(x: number, z: number, character: Model?): number?
	local hit = groundAt(x, z, character)
	return if hit then hit.Position.Y else nil
end

function WorldService.CanPlaceBuilding(position: Vector3, character: Model?): (boolean, number?)
	local halfX, halfZ = BUILDING_SIZE.X / 2, BUILDING_SIZE.Y / 2
	local samples = {
		Vector2.new(0, 0), Vector2.new(-halfX, -halfZ), Vector2.new(-halfX, halfZ),
		Vector2.new(halfX, -halfZ), Vector2.new(halfX, halfZ), Vector2.new(0, -halfZ),
		Vector2.new(0, halfZ), Vector2.new(-halfX, 0), Vector2.new(halfX, 0),
	}
	local groundHeight: number? = nil
	local minHeight, maxHeight = math.huge, -math.huge
	for _, offset in ipairs(samples) do
		local x, z = position.X + offset.X, position.Z + offset.Y
		if not insideIsland(x, z) then return false, nil end
		local hit = groundAt(x, z, character)
		if not hit then return false, nil end
		groundHeight = groundHeight or hit.Position.Y
		minHeight = math.min(minHeight, hit.Position.Y)
		maxHeight = math.max(maxHeight, hit.Position.Y)
	end
	if maxHeight - minHeight > 5 then return false, nil end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: {Instance} = { groundFolder }
	if character then table.insert(excluded, character) end
	overlapParams.FilterDescendantsInstances = excluded
	local centerY = (groundHeight :: number) + 6
	local overlaps = Workspace:GetPartBoundsInBox(CFrame.new(position.X, centerY, position.Z), Vector3.new(BUILDING_SIZE.X, 12, BUILDING_SIZE.Y), overlapParams)
	if #overlaps > 0 then return false, nil end
	return true, groundHeight
end

function WorldService.CreateBuilding(buildingId: string, ownerName: string, x: number, z: number, groundHeight: number): Model
	local model = Instance.new("Model")
	model.Name = ownerName .. "_" .. buildingId
	model:SetAttribute("BuildingId", buildingId)
	local floor = Instance.new("Part")
	floor.Name, floor.Anchored, floor.Size = "Floor", true, Vector3.new(BUILDING_SIZE.X, 0.6, BUILDING_SIZE.Y)
	floor.Material, floor.Color = Enum.Material.WoodPlanks, Color3.fromRGB(142, 111, 73)
	floor.CFrame = CFrame.new(x, groundHeight + 0.3, z)
	floor.Parent = model
	if buildingId == "LeanTo" then
		for _, offset in ipairs({ -1, 1 }) do
			local beam = Instance.new("WedgePart")
			beam.Name, beam.Anchored, beam.Size = "PalmRoof", true, Vector3.new(7, 9, 12)
			beam.Material, beam.Color = Enum.Material.Wood, Color3.fromRGB(112, 137, 77)
			beam.CFrame = floor.CFrame * CFrame.new(offset * 2.8, 4.3, 0) * CFrame.Angles(0, 0, math.rad(offset * 24))
			beam.Parent = model
		end
	else
		local fire = Instance.new("Part")
		fire.Name, fire.Shape, fire.Size = "Campfire", Enum.PartType.Ball, Vector3.new(2.5, 2.5, 2.5)
		fire.Anchored, fire.Material, fire.Color = true, Enum.Material.Neon, Color3.fromRGB(255, 143, 59)
		fire.Position = Vector3.new(x, groundHeight + 2, z)
		fire.Parent = model
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 159, 83), 18, 1.5
		light.Parent = fire
	end
	model.Parent = buildingFolder
	return model
end

function WorldService.Initialize()
	groundFolder = Instance.new("Folder")
	groundFolder.Name = "IslandGround"
	groundFolder.Parent = Workspace
	local terrain = Workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -18, 0), Vector3.new(2048, 32, 2048), Enum.Material.Water)
	local sandBase = part(groundFolder, "IslandSandShelf", Vector3.new(18, 660, 470), Vector3.new(0, -7, 0), Color3.fromRGB(224, 204, 148), Enum.Material.Sand, Enum.PartType.Cylinder)
	sandBase.CFrame = CFrame.new(0, -7, 0) * CFrame.Angles(0, 0, math.rad(90))
	sandBase.CanCollide = true
	local grassBase = part(groundFolder, "IslandHeart", Vector3.new(14, 610, 420), Vector3.new(0, 0, 0), Color3.fromRGB(92, 130, 73), Enum.Material.Grass, Enum.PartType.Cylinder)
	grassBase.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
	grassBase.CanCollide = true
	terrain:FillBall(Vector3.new(35, 28, -55), 86, Enum.Material.Ground)
	terrain:FillBall(Vector3.new(35, 49, -55), 65, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(-105, 23, 20), 56, Enum.Material.Ground)
	terrain:FillBall(Vector3.new(-105, 40, 20), 39, Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(8, 2, 148), Vector3.new(16, 5, 130), Enum.Material.Water)
	resourceFolder = Instance.new("Folder")
	resourceFolder.Name = "IslandResources"
	resourceFolder.Parent = Workspace
	buildingFolder = Instance.new("Folder")
	buildingFolder.Name = "IslandBuildings"
	buildingFolder.Parent = Workspace
	local rng = Random.new(72024)
	local kinds = { Tree = 70, Palm = 24, Rock = 24, Bush = 28, Spring = 5 }
	local index = 0
	for kind, amount in pairs(kinds) do
		for _ = 1, amount do
			index += 1
			local pos = islandPosition(rng)
			if kind == "Spring" then pos += Vector3.new(0, 0, -20) end
			makeResource(kind, pos, index)
		end
	end
	local spawnPosition = Vector3.new(0, 0, 0)
	local spawnGround = WorldService.GetIslandGroundHeight(spawnPosition.X, spawnPosition.Z, nil) or 7
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size, spawn.Position = "BeachSpawn", Vector3.new(18, 1, 18), Vector3.new(spawnPosition.X, spawnGround + 0.5, spawnPosition.Z)
	spawn.Anchored, spawn.Neutral, spawn.Material = true, true, Enum.Material.Sand
	spawn.Color = Color3.fromRGB(224, 204, 148)
	spawn.Parent = groundFolder
	Lighting.ClockTime = 8
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(116, 135, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(153, 170, 156)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.45
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density, atmosphere.Offset = 0.25, 0.12
	atmosphere.Color, atmosphere.Decay = Color3.fromRGB(197, 230, 219), Color3.fromRGB(95, 151, 156)
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.18, 24, 1.2
	bloom.Parent = Lighting
end

function WorldService.GetResourceFolder(): Folder
	return resourceFolder
end

function WorldService.RespawnResource(model: Model)
	if not model.Parent then return end
	local kind = model:GetAttribute("ResourceType")
	if type(kind) ~= "string" or not Config.Resources[kind] then return end
	model:SetAttribute("Health", Config.Resources[kind].Health)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then descendant.Transparency = 0; descendant.CanQuery = true end
	end
end

function WorldService.SetResourceDepleted(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then descendant.Transparency = 0.72; descendant.CanQuery = false end
	end
end

return WorldService
