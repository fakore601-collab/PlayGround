--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local services = ServerScriptService:WaitForChild("Services")
local WorldService = require(services:WaitForChild("WorldService"))
local GameService = require(services:WaitForChild("GameService"))

local remotes = ReplicatedStorage:FindFirstChild("SurvivalIslandRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "SurvivalIslandRemotes"
	remotes.Parent = ReplicatedStorage
end
for _, name in ipairs({ "Action", "State" }) do
	if not remotes:FindFirstChild(name) then
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = remotes
	end
end

WorldService.Initialize()
GameService.Initialize(remotes :: Folder)
print("[SurvivalIsland] Server systems initialized")
