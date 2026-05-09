-- StarterPlayerScripts/ChairVisualizer
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()

local Events = RS:WaitForChild("Events")
local ChairSync = Events:WaitForChild("ChairSync")

local myChair = nil

local function spawnEquippedChair()
	-- Remove old
	if myChair then myChair:Destroy(); myChair = nil end

	-- We get equipped chair name from server via ChairSync, but we can also store it locally
	-- For simplicity, we listen to ChairSync
end

ChairSync.OnClientEvent:Connect(function(data)
	if data.equipped == "Default" then return end

	-- Check if character exists
	local c = player.Character
	if not c then return end

	local models = RS:WaitForChild("Chairs")
	local model = models:FindFirstChild(data.equipped)
	if not model then return end

	local clone = model:Clone()
	clone.Name = "EquippedChair"

	local root = c:FindFirstChild("HumanoidRootPart")
	if not root then return end

	clone:PivotTo(root.CFrame * CFrame.new(0, -1.5, 0)) -- Adjust offset as needed

	-- Attach to root so it follows player
	local att = Instance.new("Attachment")
	att.Name = "ChairAtt"
	att.Position = Vector3.new(0, -1.5, 0)
	att.Parent = root

	local alignPos = Instance.new("AlignPosition")
	alignPos.Attachment0 = att
	alignPos.Attachment1 = clone:FindFirstChildWhichIsA("Attachment") or Instance.new("Attachment", clone)
	alignPos.Parent = clone

	local alignOri = Instance.new("AlignOrientation")
	alignOri.Attachment0 = att
	alignOri.Attachment1 = clone:FindFirstChildWhichIsA("Attachment") or alignPos.Attachment1
	alignOri.Parent = clone

	clone.Parent = c
	myChair = clone
end)

-- Re-apply on respawn
player.CharacterAdded:Connect(function(c)
	char = c
	task.wait(0.5)

	-- ChairRequest may not exist in all builds; guard it.
	local chairRequest = Events:FindFirstChild("ChairRequest")
	if chairRequest and chairRequest:IsA("RemoteEvent") then
		chairRequest:FireServer()
	end
end)
