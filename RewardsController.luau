-- local SOCIAL_DEVS = {(full rewrite, stable subtitle + robux spent text)
print("[RewardsController] Starting...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local gameGui = gui:WaitForChild("GameGui")

local openBtn = gameGui:WaitForChild("OpenRewardsBtn")
local root = gameGui:WaitForChild("RewardsF")
local closeBtn = root:WaitForChild("CloseBtn")

local leftTabs = root:WaitForChild("LeftTabs")
local content = root:WaitForChild("Content")
local titleLbl = content:WaitForChild("CategoryTitle")
local subLbl = content:WaitForChild("CategorySubtitle")
local rowsScroll = content:WaitForChild("RowsScroll")
local rowTemplate = rowsScroll:WaitForChild("RowTemplate")

local Events = RS:WaitForChild("Events")
local RewardSync = Events:WaitForChild("RewardSync")
local RewardClaim = Events:WaitForChild("RewardClaim")
local RewardRequestSync = Events:WaitForChild("RewardRequestSync")
local hasAutoOpenedDaily = false
local hasAutoOpenedPlaytime = false
local autoOpenMode = nil
local TAB_TO_CAT = {
	PlaytimeBtn = "playtime",
	DailyBtn = "daily",
	GroupBtn = "group",
	SocialBtn = "social",
	VipDailyBtn = "vipdaily",
	RobuxSpentBtn = "robuxspent",
}

local CAT_TITLE = {
	playtime = "Playtime Rewards",
	daily = "Daily Rewards",
	group = "Group Rewards",
	social = "Social Rewards",
	vipdaily = "VIP Daily Rewards",
	robuxspent = "Robux Spent Rewards",
}

local SOCIAL_DEVS = {
	{ username = "TheCoolBaconHairIsMe", userId = 3107183806 },
	{ username = "YurisMatrix", userId = 3721585498 },
}

local REWARD_IMAGES = {
	["cash_200"] = "rbxassetid://73475281808267",
	["cash_250"] = "rbxassetid://95709817514797",
	["cash_300"] = "rbxassetid://72562550267593",
	["cash_350"] = "rbxassetid://136984600835859",
	["cash_400"] = "rbxassetid://111851628253582",
	["cash_450"] = "rbxassetid://127353088289605",
	["cash_500"] = "rbxassetid://121749597294959",
	["cash_600"] = "rbxassetid://88543138919395",
	["cash_650"] = "rbxassetid://133672122839712",
	["cash_800"] = "rbxassetid://125003786053473",
	["cash_1000"] = "rbxassetid://105125784128656",
	["cash_2000"] = "rbxassetid://108333874006118",
	["cash_4000"] = "rbxassetid://118689386769573",
	["cash_8000"] = "rbxassetid://109102845128329",
	["cash_15000"] = "rbxassetid://132457307373540",
	["cash_30000"] = "rbxassetid://136730063156531",
	["magnifier_1"] = "rbxassetid://118444404126569",
	["magnifier_2"] = "rbxassetid://71274466836275",
	["hook_1"] = "rbxassetid://134060934663289",
	["hook_2"] = "rbxassetid://98436490057054",
	["mystery_1"] = "rbxassetid://133477499555789",
	["mystery_2"] = "rbxassetid://97784274802455",
	["time_5min"] = "rbxassetid://134246698110119",
	["time_15min"] = "rbxassetid://74897415127747",
}

local REWARD_PATTERNS = {
	{ pattern = "+%$200", image = "cash_200" },
	{ pattern = "+%$250", image = "cash_250" },
	{ pattern = "+%$300", image = "cash_300" },
	{ pattern = "+%$350", image = "cash_350" },
	{ pattern = "+%$400", image = "cash_400" },
	{ pattern = "+%$450", image = "cash_450" },
	{ pattern = "+%$500", image = "cash_500" },
	{ pattern = "+%$600", image = "cash_600" },
	{ pattern = "+%$650", image = "cash_650" },
	{ pattern = "+%$800", image = "cash_800" },
	{ pattern = "+%$1000", image = "cash_1000" },
	{ pattern = "+%$2000", image = "cash_2000" },
	{ pattern = "+%$4000", image = "cash_4000" },
	{ pattern = "+%$8000", image = "cash_8000" },
	{ pattern = "+%$15000", image = "cash_15000" },
	{ pattern = "+%$30000", image = "cash_30000" },
	{ pattern = "+1 Magnifier", image = "magnifier_1" },
	{ pattern = "+2 Magnifier", image = "magnifier_2" },
	{ pattern = "+1 Hook", image = "hook_1" },
	{ pattern = "+2 Hook", image = "hook_2" },
	{ pattern = "+1 Mystery", image = "mystery_1" },
	{ pattern = "+2 Mystery", image = "mystery_2" },
	{ pattern = "x2 5min", image = "time_5min" },
	{ pattern = "x2 15min", image = "time_15min" },
}

local IMAGE_CONFIG = {
	DISPLAY_SIZE = 64,
	IMAGE_SPACING = 8,
	ARROW_WIDTH = 28,
	ARROW_GAP = 6,
}

local payload = nil
local activeCat = "playtime"
local pendingAutoTour = false
local autoTourStarted = false
local playtimeSeconds = 0
local dailyCountdown = 0
local lastTick = tick()
local updateConn = nil
local rowPageState = {}
local function hardHideRewards()
	root.Visible = false
	root.Active = false
	root.Selectable = false
	rowsScroll.ScrollingEnabled = false

	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.Active = false
			d.Selectable = false
		end
	end
end

local function hardShowRewards()
	root.Visible = true
	root.Active = true
	root.Selectable = true
	rowsScroll.ScrollingEnabled = true

	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.Active = true
		end
	end
end
local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function requestSync()
	if RewardRequestSync:IsA("RemoteFunction") then
		pcall(function()
			RewardRequestSync:InvokeServer()
		end)
	elseif RewardRequestSync:IsA("RemoteEvent") then
		RewardRequestSync:FireServer()
	end
end

local function clearRows()
	for _, c in ipairs(rowsScroll:GetChildren()) do
		if c:IsA("Frame") and c ~= rowTemplate then
			c:Destroy()
		end
	end
end

local function styleClaim(btn, row)
	if row.claimed then
		btn.Text = "CLAIMED"
		btn.BackgroundColor3 = Color3.fromRGB(60, 220, 60)
		btn.Active = false
	elseif row.ready then
		btn.Text = "CLAIM"
		btn.BackgroundColor3 = Color3.fromRGB(60, 220, 60)
		btn.Active = true
	else
		btn.Text = "NOT READY"
		btn.BackgroundColor3 = Color3.fromRGB(140, 140, 140)
		btn.Active = false
	end
	btn.AutoButtonColor = false
	btn.ZIndex = 20
end

local function parseRewardImages(rewardsText)
	local images = {}
	local txt = tostring(rewardsText or "")
	for _, p in ipairs(REWARD_PATTERNS) do
		if txt:find(p.pattern) then
			table.insert(images, p.image)
		end
	end
	return images
end

local function loadProfileImage(imageLabel, userId)
	if userId == 0 then
		imageLabel.Image = "rbxassetid://0"
		return
	end
	local ok, imageUrl = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	end)
	imageLabel.Image = ok and imageUrl or "rbxassetid://0"
end

local function ensurePagerButton(container, name, text, xScale, xOffset)
	local btn = container:FindFirstChild(name)
	if not btn then
		btn = Instance.new("TextButton")
		btn.Name = name
		btn.Parent = container
	end
	btn.BackgroundColor3 = Color3.fromRGB(30, 45, 70)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Text = text
	btn.TextScaled = true
	btn.AutoButtonColor = true
	btn.BorderSizePixel = 0
	btn.AnchorPoint = Vector2.new(0, 0.5)
	btn.Size = UDim2.new(0, IMAGE_CONFIG.ARROW_WIDTH, 0, IMAGE_CONFIG.ARROW_WIDTH)
	btn.Position = UDim2.new(xScale, xOffset, 0.5, 0)
	btn.ZIndex = 7

	local corner = btn:FindFirstChildOfClass("UICorner")
	if not corner then
		corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = btn
	end
	return btn
end

local function buildRewardPager(container, template, rowKey, rewardImageKeys)
	container.ClipsDescendants = true
	container.ZIndex = 2

	local leftBtn = ensurePagerButton(container, "PrevBtn", "<", 0, 0)
	local rightBtn = ensurePagerButton(container, "NextBtn", ">", 1, -IMAGE_CONFIG.ARROW_WIDTH)

	local pageLbl = container:FindFirstChild("PageLbl")
	if not pageLbl then
		pageLbl = Instance.new("TextLabel")
		pageLbl.Name = "PageLbl"
		pageLbl.BackgroundTransparency = 1
		pageLbl.TextColor3 = Color3.fromRGB(220, 230, 255)
		pageLbl.TextScaled = true
		pageLbl.Parent = container
	end
	pageLbl.Size = UDim2.new(0, 54, 0, 16)
	pageLbl.Position = UDim2.new(0.5, -27, 1, -16)
	pageLbl.ZIndex = 7

	local function clearGeneratedIcons()
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("ImageLabel") and child ~= template and child:GetAttribute("RewardClone") then
				child:Destroy()
			end
		end
	end

	local function renderPage()
		clearGeneratedIcons()

		local count = #rewardImageKeys
		if count == 0 then
			leftBtn.Visible = false
			rightBtn.Visible = false
			pageLbl.Visible = false
			return
		end

		local rowState = rowPageState[rowKey] or { page = 1 }
		rowPageState[rowKey] = rowState

		local availableWidth = container.AbsoluteSize.X - ((IMAGE_CONFIG.ARROW_WIDTH * 2) + (IMAGE_CONFIG.ARROW_GAP * 4))
		if availableWidth <= 0 then
			availableWidth = 200
		end

		local iconSize = IMAGE_CONFIG.DISPLAY_SIZE
		local spacing = IMAGE_CONFIG.IMAGE_SPACING
		local iconsPerPage = math.max(1, math.floor((availableWidth + spacing) / (iconSize + spacing)))
		local totalPages = math.max(1, math.ceil(count / iconsPerPage))

		rowState.page = math.clamp(rowState.page, 1, totalPages)

		local startIndex = (rowState.page - 1) * iconsPerPage + 1
		local endIndex = math.min(count, startIndex + iconsPerPage - 1)
		local visibleCount = endIndex - startIndex + 1

		local contentWidth = visibleCount * iconSize + (visibleCount - 1) * spacing
		local contentStart = (container.AbsoluteSize.X - contentWidth) / 2

		for i = startIndex, endIndex do
			local localIndex = i - startIndex + 1
			local iconKey = rewardImageKeys[i]
			local img = template:Clone()
			img.Visible = true
			img.Image = REWARD_IMAGES[iconKey] or iconKey
			img.Size = UDim2.new(0, iconSize, 0, iconSize)
			img.Position = UDim2.new(0, contentStart + (localIndex - 1) * (iconSize + spacing), 0.5, -iconSize / 2)
			img.ZIndex = 3
			img.Active = false
			img.Selectable = false
			img:SetAttribute("RewardClone", true)
			img.Parent = container
		end

		leftBtn.Visible = totalPages > 1
		rightBtn.Visible = totalPages > 1
		pageLbl.Visible = totalPages > 1
		pageLbl.Text = string.format("%d/%d", rowState.page, totalPages)

		leftBtn.Active = rowState.page > 1
		rightBtn.Active = rowState.page < totalPages
		leftBtn.TextTransparency = leftBtn.Active and 0 or 0.5
		rightBtn.TextTransparency = rightBtn.Active and 0 or 0.5
	end

	leftBtn.MouseButton1Click:Connect(function()
		local st = rowPageState[rowKey] or { page = 1 }
		st.page -= 1
		rowPageState[rowKey] = st
		renderPage()
	end)

	rightBtn.MouseButton1Click:Connect(function()
		local st = rowPageState[rowKey] or { page = 1 }
		st.page += 1
		rowPageState[rowKey] = st
		renderPage()
	end)

	renderPage()
end

local function setupRowContent(clone, categoryId, rowIndex, rowData)
	local leftLbl = clone:FindFirstChild("LeftLbl")
	local container = clone:FindFirstChild("RewardsContainer")
	if not container then return end

	local template = container:FindFirstChild("ImageTemplate")
	if not template or not template:IsA("ImageLabel") then return end
	template.Visible = false
	template.ZIndex = 3

	if leftLbl and leftLbl:IsA("TextLabel") then
		if categoryId == "playtime" then
			leftLbl.Text = rowData.left or ""
		elseif categoryId == "daily" then
			leftLbl.Text = "Day " .. tostring(rowIndex)
		elseif categoryId == "group" then
			leftLbl.Text = "Group"
		elseif categoryId == "vipdaily" then
			leftLbl.Text = "VIP"
		elseif categoryId == "robuxspent" then
			leftLbl.Text = rowData.left or ""
		elseif categoryId == "social" then
			leftLbl.Text = ""
		end
	end

	if categoryId == "social" and SOCIAL_DEVS[rowIndex] and leftLbl then
		local img = leftLbl:FindFirstChild("ProfileImage")
		if not img then
			img = Instance.new("ImageLabel")
			img.Name = "ProfileImage"
			img.Size = UDim2.new(0, 80, 0, 80)
			img.Position = UDim2.new(0.5, 0, 0.5, 0)
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.BackgroundTransparency = 1
			img.Parent = leftLbl
		end
		loadProfileImage(img, SOCIAL_DEVS[rowIndex].userId)
	end

	local rewardImageKeys = parseRewardImages(rowData.rewards or "")
	local rowKey = tostring(categoryId) .. ":" .. tostring(rowData.id or rowIndex)
	buildRewardPager(container, template, rowKey, rewardImageKeys)
end

local function refreshCategorySubtitle()
	if not payload or not activeCat then
		subLbl.Text = ""
		return
	end

	if activeCat == "robuxspent" then
		local spent = tonumber(payload.robuxSpentTotal) or 0
		subLbl.Text = string.format("Total Robux spent: R$%d", spent)
		return
	end

	if activeCat == "playtime" then
		subLbl.Text = "You played for " .. formatTime(playtimeSeconds)
		return
	end

	if activeCat == "daily" then
		if dailyCountdown > 0 then
			subLbl.Text = "Ready to claim in " .. formatTime(dailyCountdown)
		else
			subLbl.Text = "Daily reward ready"
		end
		return
	end

	if activeCat == "social" then
		subLbl.Text = "Follow these developers on Roblox!"
	elseif activeCat == "group" then
		subLbl.Text = "Like the game + Join the group"
	elseif activeCat == "vipdaily" then
		subLbl.Text = "Become VIP to claim"
	else
		subLbl.Text = ""
	end
end

local function stopLiveUpdater()
	if updateConn then
		updateConn:Disconnect()
		updateConn = nil
	end
end

local function startLiveUpdater()
	stopLiveUpdater()
	lastTick = tick()

	updateConn = RunService.Heartbeat:Connect(function()
		if not payload or not activeCat then return end

		local now = tick()
		local dt = now - lastTick
		lastTick = now

		if activeCat == "playtime" then
			playtimeSeconds += dt
			refreshCategorySubtitle()
		elseif activeCat == "daily" then
			dailyCountdown = math.max(0, dailyCountdown - dt)
			refreshCategorySubtitle()
		end
	end)
end

local function renderRows()
	clearRows()
	rowPageState = {}

	local rows = payload and payload.categories and payload.categories[activeCat] or {}

	local y = 6
	local rowH = rowTemplate.Size.Y.Offset > 0 and rowTemplate.Size.Y.Offset or 100
	local gap = 10

	for idx, row in ipairs(rows) do
		local clone = rowTemplate:Clone()
		clone.Visible = true
		clone.Name = "Row_" .. tostring(row.id or idx)
		clone.Position = UDim2.new(rowTemplate.Position.X.Scale, rowTemplate.Position.X.Offset, 0, y)
		clone.Size = UDim2.new(rowTemplate.Size.X.Scale, rowTemplate.Size.X.Offset, 0, rowH)
		clone.Parent = rowsScroll

		setupRowContent(clone, activeCat, idx, row)

		local claimBtn = clone:FindFirstChild("ClaimBtn")
		if claimBtn and claimBtn:IsA("TextButton") then
			styleClaim(claimBtn, row)
			claimBtn.MouseButton1Click:Connect(function()
				if row.ready and not row.claimed then
					RewardClaim:FireServer(activeCat, row.id)
				end
			end)
		end

		y += rowH + gap
	end

	rowsScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	rowsScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(y + 8, rowsScroll.AbsoluteSize.Y + 1))
end

local function render()
	titleLbl.Text = CAT_TITLE[activeCat] or "Rewards"

	if not payload then
		stopLiveUpdater()
		subLbl.Text = "Waiting for server sync..."
		clearRows()
		return
	end

	if activeCat == "playtime" then
		playtimeSeconds = tonumber(payload.totalPlaytime) or 0
		startLiveUpdater()
	elseif activeCat == "daily" then
		dailyCountdown = tonumber(payload.dailyCountdown) or 0
		startLiveUpdater()
	else
		stopLiveUpdater()
	end

	refreshCategorySubtitle()
	renderRows()
end

local function selectCategory(cat)
	activeCat = cat
	render()
end
local function openRewardsTo(cat)
	hardShowRewards()
	selectCategory(cat)
	requestSync()
end

local function startJoinRewardTour()
	if autoTourStarted then return end
	if not payload then
		pendingAutoTour = true
		requestSync()
		return
	end

	autoTourStarted = true
	hasAutoOpenedDaily = true
	autoOpenMode = "daily"
	openRewardsTo("daily")
end
for btnName, cat in pairs(TAB_TO_CAT) do
	local btn = leftTabs:FindFirstChild(btnName)
	if btn and btn:IsA("TextButton") then
		btn.MouseButton1Click:Connect(function()
			selectCategory(cat)
		end)
	end
end

local function onOpen()
	autoOpenMode = nil
	hardShowRewards()
	requestSync()
	render()
end
local function onClose()
	stopLiveUpdater()

	-- force it non-interactive immediately, even if animator only fades it
	hardHideRewards()

	if autoOpenMode == "daily" and not hasAutoOpenedPlaytime then
		hasAutoOpenedPlaytime = true
		autoOpenMode = "playtime"

		task.delay(0.6, function()
			openRewardsTo("playtime")
		end)
	else
		autoOpenMode = nil
	end
end
task.spawn(function()
	local rf = game:GetService("ReplicatedFirst")
	local finished = rf:FindFirstChild("LoadingFinished")

	if finished and finished:IsA("BindableEvent") then
		finished.Event:Wait()
	else
		task.wait(5)
	end

	task.wait(8)
	startJoinRewardTour()
end)

local t = 0
while not _G.UIWindowAnimator and t < 5 do
	task.wait(0.1)
	t += 0.1
end

openBtn.MouseButton1Click:Connect(function()
	if root.Visible then
		onClose()
	else
		onOpen()
	end
end)

closeBtn.MouseButton1Click:Connect(onClose)

RewardSync.OnClientEvent:Connect(function(newPayload)
	if type(newPayload) ~= "table" then return end

	payload = newPayload
	render()

	if pendingAutoTour and not autoTourStarted then
		pendingAutoTour = false
		task.defer(startJoinRewardTour)
	end
end)
local TweenService = game:GetService("TweenService")

local questF = gameGui:WaitForChild("DailyQuestsF")
local toggleBtn = questF:WaitForChild("ToggleBtn")

local openPos = UDim2.new(0.76, 0, 0.025, 0)
local closedPos = UDim2.new(0.98, 0, 0.025, 0)

local isOpen = true
questF.Position = openPos

local function setQuestOpen(open)
	isOpen = open

	local target = open and openPos or closedPos
	toggleBtn.Text = open and ">" or "<"

	TweenService:Create(
		questF,
		TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = target }
	):Play()
end

toggleBtn.MouseButton1Click:Connect(function()
	setQuestOpen(not isOpen)
end)
hardHideRewards()
requestSync()
render()
print("[RewardsController] Ready")
