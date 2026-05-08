local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local STREAK_VALUE_NAME = "Winstreak"
local localPlayer = Players.LocalPlayer
local Events = RS:WaitForChild("Events")
local SetHeadTagsVisible = Events:WaitForChild("SetHeadTagsVisible")
local hiddenNames = {}

local function isNameHidden(name)
	return hiddenNames[name] == true
end

local function applyVisibilityForPlayer(player)
	if not player then return end
	local hidden = isNameHidden(player.Name)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local worldTag = head and head:FindFirstChild("PlayerHeadTag")
	if worldTag and worldTag:IsA("BillboardGui") then
		worldTag.Enabled = not hidden
	end

	if player == localPlayer then
		local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
		local localTag = pg and pg:FindFirstChild("PlayerHeadTagLocal")
		if localTag and localTag:IsA("BillboardGui") then
			localTag.Enabled = not hidden
		end
	end
end

local function tierColor(n)
	if n >= 20 then return Color3.fromRGB(255, 70, 70) end
	if n >= 10 then return Color3.fromRGB(255, 120, 40) end
	if n >= 5 then return Color3.fromRGB(255, 210, 50) end
	if n >= 1 then return Color3.fromRGB(255, 180, 70) end
	return Color3.fromRGB(165, 190, 255)
end

local function makeHeadTag(player)
	local char = player.Character or player.CharacterAdded:Wait()
	local head = char:WaitForChild("Head", 10)
	if not head then return end

	local old = head:FindFirstChild("PlayerHeadTag")
	if old then old:Destroy() end

	local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
	if player == localPlayer and pg then
		local oldLocal = pg:FindFirstChild("PlayerHeadTagLocal")
		if oldLocal then oldLocal:Destroy() end
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "PlayerHeadTag"
	-- Scale-based size per request.
	bb.Size = UDim2.fromScale(5.2, 5.1)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 300
	bb.Parent = head
	bb.Enabled = not isNameHidden(player.Name)

	local container = Instance.new("Frame")
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = bb

	local streakLbl = Instance.new("TextLabel")
	streakLbl.Name = "StreakLbl"
	streakLbl.Size = UDim2.new(1, 0, 0.2, 0)
	streakLbl.Position = UDim2.new(0, 0, 0.45, 0)
	streakLbl.BackgroundTransparency = 1
	streakLbl.Text = ""
	streakLbl.Font = Enum.Font.GothamBlack
	streakLbl.TextScaled = true
	streakLbl.TextStrokeTransparency = 0.18
	streakLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	streakLbl.Parent = container

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "NameLbl"
	nameLbl.Size = UDim2.new(1, 0, 0.52, 0)
	nameLbl.Position = UDim2.new(0, 0, 0.48, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = player.DisplayName ~= "" and player.DisplayName or player.Name
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextScaled = true
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextStrokeTransparency = 0.15
	nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLbl.Parent = container

	local localStreakLbl = nil
	if player == localPlayer and pg then
		-- Local copy so you can see your own tag from your camera as well.
		local localBb = bb:Clone()
		localBb.Name = "PlayerHeadTagLocal"
		localBb.Parent = pg
		localBb.Adornee = head
		localBb.Enabled = not isNameHidden(player.Name)
		localStreakLbl = localBb:FindFirstChild("StreakLbl", true)
	end

	local function setStreak(label, n)
		if not label then return end
		if n <= 0 then
			label.Text = ""
			return
		end
		local col = tierColor(n)
		label.Text = "?? " .. tostring(n)
		label.TextColor3 = col
	end

	local function updateStreak(v)
		local n = tonumber(v) or 0
		setStreak(streakLbl, n)
		setStreak(localStreakLbl, n)
	end

	local stats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 15)
	local streakValue = stats and stats:FindFirstChild(STREAK_VALUE_NAME)
	if streakValue and streakValue:IsA("IntValue") then
		updateStreak(streakValue.Value)
		streakValue.Changed:Connect(updateStreak)
	else
		updateStreak(0)
	end
end

local function hookPlayer(player)
	task.spawn(function()
		makeHeadTag(player)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		makeHeadTag(player)
	end)
end

Players.PlayerAdded:Connect(hookPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	hookPlayer(p)
end

SetHeadTagsVisible.OnClientEvent:Connect(function(names, visible)
	if type(names) ~= "table" then return end
	for _, n in ipairs(names) do
		if type(n) == "string" and n ~= "" then
			if visible then
				hiddenNames[n] = nil
			else
				hiddenNames[n] = true
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		applyVisibilityForPlayer(p)
	end
end)

print("[HeadTagsHandler] Ready")
