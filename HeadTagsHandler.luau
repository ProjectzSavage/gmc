local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local STREAK_VALUE_NAME = "Winstreak"
local localPlayer = Players.LocalPlayer
local Events = RS:WaitForChild("Events")
local SetHeadTagsVisible = Events:WaitForChild("SetHeadTagsVisible")
local hiddenNames = {}

-- BADGE ICONS (72x72 recommended)
local ICON_PREMIUM  = "rbxassetid://101904671739135" -- TODO
local ICON_VERIFIED = "rbxassetid://102865349901178" -- TODO
local ICON_HAMMER   = "rbxassetid://134307675251410" -- TODO

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

local function ensureIcon(iconRow, name, imageId, order)
	local icon = iconRow:FindFirstChild(name)
	if not icon then
		icon = Instance.new("ImageLabel")
		icon.Name = name
		icon.Size = UDim2.fromScale(0.45, 0.5)
		icon.BackgroundTransparency = 1
		icon.LayoutOrder = order
		icon.Parent = iconRow
	end
	icon.Image = imageId
	icon.Visible = true
	return icon
end

local function clearIcons(iconRow)
	for _, c in ipairs(iconRow:GetChildren()) do
		if c:IsA("ImageLabel") then
			c:Destroy()
		end
	end
end

local function createTagGui(parent, name, adornee)
	local bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.Size = UDim2.fromScale(5.2, 5.1)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 300
	bb.Parent = parent
	if adornee then
		bb.Adornee = adornee
	end

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
	streakLbl.Font = Enum.Font.FredokaOne
	streakLbl.TextScaled = true
	streakLbl.TextStrokeTransparency = 0.18
	streakLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	streakLbl.Parent = container

	local iconRow = Instance.new("Frame")
	iconRow.Name = "IconRow"
	iconRow.Size = UDim2.new(0.24, 0, 0.18, 0)
	iconRow.Position = UDim2.new(-0.05, 0, 0.63, 0)
	iconRow.BackgroundTransparency = 1
	iconRow.Parent = container

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 3)
	list.Parent = iconRow

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "NameLbl"
	nameLbl.Size = UDim2.new(0.76, 0, 0.22, 0)
	nameLbl.Position = UDim2.new(0.22, 0, 0.61, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = ""
	nameLbl.Font = Enum.Font.FredokaOne
	nameLbl.TextScaled = true
	nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextStrokeTransparency = 0.15
	nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Parent = container

	local subLbl = Instance.new("TextLabel")
	subLbl.Name = "SubLbl"
	subLbl.Size = UDim2.new(0.96, 0, 0.10, 0)
	subLbl.Position = UDim2.new(0.46, 0, 0.77, 0)
	subLbl.BackgroundTransparency = 1
	subLbl.Text = ""
	subLbl.Font = Enum.Font.FredokaOne
	subLbl.TextScaled = true
	subLbl.TextColor3 = Color3.fromRGB(255, 210, 70)
	subLbl.TextStrokeTransparency = 0.25
	subLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	subLbl.TextXAlignment = Enum.TextXAlignment.Left
	subLbl.Parent = container

	return bb, streakLbl, nameLbl, subLbl, iconRow
end

local function updateRoleAndBadges(player, nameLbl, subLbl, iconRow)
	nameLbl.Text = (player.DisplayName ~= "" and player.DisplayName) or player.Name

	local isVip = player:GetAttribute("HasVIP") == true
	local inGroup = player:GetAttribute("InGroupTag") == true
	local hasPremium = player:GetAttribute("HasPremiumTag") == true
	local isVerified = player:GetAttribute("IsVerifiedTag") == true
	local isHammer = player:GetAttribute("IsHammerTag") == true

	if isVip then
		subLbl.Text = "VIP"
		subLbl.TextColor3 = Color3.fromRGB(255, 210, 70)
	elseif inGroup then
		subLbl.Text = "GROUP"
		subLbl.TextColor3 = Color3.fromRGB(130, 220, 255)
	else
		subLbl.Text = ""
	end

	clearIcons(iconRow)
	local order = 1
	if hasPremium and ICON_PREMIUM ~= "rbxassetid://0" then
		ensureIcon(iconRow, "PremiumIcon", ICON_PREMIUM, order)
		order += 1
	end
	if isVerified and ICON_VERIFIED ~= "rbxassetid://0" then
		ensureIcon(iconRow, "VerifiedIcon", ICON_VERIFIED, order)
		order += 1
	end
	if isHammer and ICON_HAMMER ~= "rbxassetid://0" then
		ensureIcon(iconRow, "HammerIcon", ICON_HAMMER, order)
		order += 1
	end
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

	local worldBb, streakLbl, nameLbl, subLbl, iconRow = createTagGui(head, "PlayerHeadTag", nil)
	worldBb.Enabled = not isNameHidden(player.Name)

	local localStreakLbl, localNameLbl, localSubLbl, localIconRow
	if player == localPlayer and pg then
		local localBb, ls, ln, lsub, li = createTagGui(pg, "PlayerHeadTagLocal", head)
		localBb.Enabled = not isNameHidden(player.Name)
		localStreakLbl = ls
		localNameLbl = ln
		localSubLbl = lsub
		localIconRow = li
	end

	local function setStreak(label, n)
		if not label then return end
		if n <= 0 then
			label.Text = ""
			return
		end
		label.Text = "🔥 " .. tostring(n)
		label.TextColor3 = tierColor(n)
	end

	local function updateStreak(v)
		local n = tonumber(v) or 0
		setStreak(streakLbl, n)
		setStreak(localStreakLbl, n)
	end

	local function updateRoleVisuals()
		updateRoleAndBadges(player, nameLbl, subLbl, iconRow)
		if localNameLbl and localSubLbl and localIconRow then
			updateRoleAndBadges(player, localNameLbl, localSubLbl, localIconRow)
		end
	end

	local stats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 15)
	local streakValue = stats and stats:FindFirstChild(STREAK_VALUE_NAME)
	if streakValue and streakValue:IsA("IntValue") then
		updateStreak(streakValue.Value)
		streakValue.Changed:Connect(updateStreak)
	else
		updateStreak(0)
	end

	-- React to server-pushed identity attributes
	for _, attr in ipairs({
		"HasVIP", "InGroupTag", "HasPremiumTag", "IsVerifiedTag", "IsHammerTag"
		}) do
		player:GetAttributeChangedSignal(attr):Connect(updateRoleVisuals)
	end

	updateRoleVisuals()
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
