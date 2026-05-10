-- RewardsController - timer reset bug fixed, playtime claim bug fixed
print("[Rewards] Script starting...")

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")

local player  = Players.LocalPlayer
local gui     = player:WaitForChild("PlayerGui")
local gameGui = gui:WaitForChild("GameGui")

local openBtn  = gameGui:WaitForChild("OpenRewardsBtn")
local root     = gameGui:WaitForChild("RewardsF")
local closeBtn = root:WaitForChild("CloseBtn")

local leftTabs  = root:WaitForChild("LeftTabs")
local content   = root:WaitForChild("Content")
local titleLbl  = content:WaitForChild("CategoryTitle")
local subLbl    = content:WaitForChild("CategorySubtitle")
local rowsScroll= content:WaitForChild("RowsScroll")
local rowTemplate = rowsScroll:WaitForChild("RowTemplate")
print("[Rewards] Found containers and template")

local powerupContainer = content:FindFirstChild("PowerupContainer")
if not powerupContainer then
	powerupContainer = Instance.new("Frame")
	powerupContainer.Name = "PowerupContainer"
	powerupContainer.Size = UDim2.new(1, 0, 0, 40)
	powerupContainer.Position = UDim2.new(0, 0, 1, -50)
	powerupContainer.BackgroundTransparency = 1
	powerupContainer.Parent = content
end

if not rowTemplate then warn("[Rewards] ERROR: RowTemplate not found!"); return end
local rewardsContainer = rowTemplate:FindFirstChild("RewardsContainer")
if not rewardsContainer then warn("[Rewards] ERROR: RewardsContainer NOT FOUND in RowTemplate!"); return end
local imageTemplate = rewardsContainer:FindFirstChild("ImageTemplate")
if not imageTemplate then warn("[Rewards] ERROR: ImageTemplate NOT FOUND in RewardsContainer!"); return end
print("[Rewards] Template structure OK")

local Events            = RS:WaitForChild("Events")
local RewardSync        = Events:WaitForChild("RewardSync")
local RewardClaim       = Events:WaitForChild("RewardClaim")
local UsePowerup        = Events:WaitForChild("UsePowerup")
local RewardRequestSync = Events:WaitForChild("RewardRequestSync")
print("[Rewards] Found events")

local TAB_TO_CAT = {
	PlaytimeBtn   = "playtime",
	DailyBtn      = "daily",
	GroupBtn      = "group",
	SocialBtn     = "social",
	VipDailyBtn   = "vipdaily",
	RobuxSpentBtn = "robuxspent",
}
local CAT_TITLE = {
	playtime   = "Playtime Rewards",
	daily      = "Daily Rewards",
	group      = "Group Rewards",
	social     = "Social Rewards",
	vipdaily   = "VIP Daily Rewards",
	robuxspent = "Robux Spent Rewards",
}
local SOCIAL_DEVS = {
	{ username = "bymyego",   userId = 0 },
	{ username = "secondDev", userId = 0 },
}
local REWARD_IMAGES = {
	["cash_200"]    = "rbxassetid://73475281808267",
	["cash_250"]    = "rbxassetid://95709817514797",
	["cash_300"]    = "rbxassetid://72562550267593",
	["cash_350"]    = "rbxassetid://136984600835859",
	["cash_400"]    = "rbxassetid://111851628253582",
	["cash_450"]    = "rbxassetid://127353088289605",
	["cash_500"]    = "rbxassetid://121749597294959",
	["cash_600"]    = "rbxassetid://88543138919395",
	["cash_650"]    = "rbxassetid://133672122839712",
	["cash_800"]    = "rbxassetid://125003786053473",
	["cash_1000"]   = "rbxassetid://105125784128656",
	["cash_2000"]   = "rbxassetid://108333874006118",
	["cash_4000"]   = "rbxassetid://118689386769573",
	["cash_8000"]   = "rbxassetid://109102845128329",
	["cash_15000"]  = "rbxassetid://132457307373540",
	["cash_30000"]  = "rbxassetid://136730063156531",
	["magnifier_1"] = "rbxassetid://118444404126569",
	["magnifier_2"] = "rbxassetid://71274466836275",
	["hook_1"]      = "rbxassetid://134060934663289",
	["hook_2"]      = "rbxassetid://98436490057054",
	["mystery_1"]   = "rbxassetid://133477499555789",
	["mystery_2"]   = "rbxassetid://97784274802455",
	["time_5min"]   = "rbxassetid://134246698110119",
	["time_15min"]  = "rbxassetid://74897415127747",
}
local REWARD_PATTERNS = {
	{ pattern = "+%$200",       image = "cash_200" },
	{ pattern = "+%$250",       image = "cash_250" },
	{ pattern = "+%$300",       image = "cash_300" },
	{ pattern = "+%$350",       image = "cash_350" },
	{ pattern = "+%$400",       image = "cash_400" },
	{ pattern = "+%$450",       image = "cash_450" },
	{ pattern = "+%$500",       image = "cash_500" },
	{ pattern = "+%$600",       image = "cash_600" },
	{ pattern = "+%$650",       image = "cash_650" },
	{ pattern = "+%$800",       image = "cash_800" },
	{ pattern = "+%$1000",      image = "cash_1000" },
	{ pattern = "+%$2000",      image = "cash_2000" },
	{ pattern = "+%$4000",      image = "cash_4000" },
	{ pattern = "+%$8000",      image = "cash_8000" },
	{ pattern = "+%$15000",     image = "cash_15000" },
	{ pattern = "+%$30000",     image = "cash_30000" },
	{ pattern = "+1 Magnifier", image = "magnifier_1" },
	{ pattern = "+2 Magnifier", image = "magnifier_2" },
	{ pattern = "+1 Hook",      image = "hook_1" },
	{ pattern = "+2 Hook",      image = "hook_2" },
	{ pattern = "+1 Mystery",   image = "mystery_1" },
	{ pattern = "+2 Mystery",   image = "mystery_2" },
	{ pattern = "x2 5min",      image = "time_5min" },
	{ pattern = "x2 15min",     image = "time_15min" },
}
local IMAGE_CONFIG = { DISPLAY_SIZE = 68, IMAGE_SPACING = 8 }

local payload         = nil
local activeCat       = nil
local robuxSpentTotal = 0
local playtimeSeconds = 0
local dailyCountdown  = 0
local lastUpdateTime  = tick()
local updateConnection= nil
local lastPayloadId   = nil
local lastRenderedCat = nil

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end
local function formatCash(amount)
	if amount >= 1000000 then return string.format("%.1fM", amount / 1000000)
	elseif amount >= 1000 then return string.format("%.1fK", amount / 1000)
	else return tostring(amount) end
end
local function clearRows()
	for _, c in ipairs(rowsScroll:GetChildren()) do
		if c:IsA("Frame") and c ~= rowTemplate then c:Destroy() end
	end
end
local function styleClaim(btn, row)
	if row.claimed then
		btn.Text = "CLAIMED"; btn.BackgroundColor3 = Color3.fromRGB(60,220,60); btn.Active = false
	elseif row.ready then
		btn.Text = "CLAIM";   btn.BackgroundColor3 = Color3.fromRGB(60,220,60); btn.Active = true
	else
		btn.Text = "NOT READY"; btn.BackgroundColor3 = Color3.fromRGB(140,140,140); btn.Active = false
	end
	btn.AutoButtonColor = false
end
local function loadProfileImage(imageLabel, userId)
	if userId == 0 then imageLabel.Image = "rbxassetid://0"; return end
	local ok, url = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	end)
	imageLabel.Image = ok and url or "rbxassetid://0"
end
local function parseRewardImages(rewardsText)
	local images = {}
	for _, p in ipairs(REWARD_PATTERNS) do
		if rewardsText:find(p.pattern) then table.insert(images, p.image) end
	end
	return images
end
local function createRewardImage(iconId, index, totalImages)
	if not iconId then return nil end
	if not imageTemplate or not imageTemplate:IsA("ImageLabel") then return nil end
	local img     = imageTemplate:Clone()
	img.Visible   = true
	local size    = IMAGE_CONFIG.DISPLAY_SIZE
	local spacing = IMAGE_CONFIG.IMAGE_SPACING
	local totalW  = size * totalImages + spacing * (totalImages - 1)
	local startX  = -totalW / 2
	local offsetX = startX + (index - 1) * (size + spacing)
	img.Size        = UDim2.new(0, size, 0, size)
	img.Position    = UDim2.new(0.5, offsetX, 0.5, -size / 2)
	img.AnchorPoint = Vector2.new(0, 0)
	img.Image       = REWARD_IMAGES[iconId] or iconId
	return img
end
local function setupRowContent(clone, categoryId, rowIndex, rowData)
	local leftLbl   = clone:FindFirstChild("LeftLbl")
	local container = clone:FindFirstChild("RewardsContainer")
	if not container then warn("[Rewards] RewardsContainer not found in clone!"); return end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ImageLabel") and child.Name ~= "ImageTemplate" then child:Destroy() end
	end
	if leftLbl and leftLbl:IsA("TextLabel") then
		if categoryId == "playtime" then leftLbl.Text = rowData.left or ""
		elseif categoryId == "daily" then leftLbl.Text = "Day " .. rowIndex
		elseif categoryId == "group" then leftLbl.Text = "Group"
		elseif categoryId == "vipdaily" then leftLbl.Text = "VIP"
		elseif categoryId == "robuxspent" then leftLbl.Text = rowData.left or ""
		elseif categoryId == "social" then leftLbl.Text = "" end
	end
	if categoryId == "social" and SOCIAL_DEVS[rowIndex] then
		if leftLbl then
			leftLbl.Text = ""
			local img = leftLbl:FindFirstChild("ProfileImage")
			if not img then
				img = Instance.new("ImageLabel"); img.Name = "ProfileImage"
				img.Size = UDim2.new(0,80,0,80); img.Position = UDim2.new(0.5,0,0.5,0)
				img.AnchorPoint = Vector2.new(0.5,0.5); img.BackgroundTransparency = 1
				img.Parent = leftLbl
			end
			loadProfileImage(img, SOCIAL_DEVS[rowIndex].userId)
		end
	end
	local images = parseRewardImages(rowData.rewards or "")
	for idx, iconId in ipairs(images) do
		local img = createRewardImage(iconId, idx, #images)
		if img then img.Parent = container end
	end
end
local function updatePowerupDisplay(powerups, boostTime)
	if not powerupContainer then return end
	local magBtn = powerupContainer:FindFirstChild("MagnifierBtn")
	if magBtn then
		local count = powerups.magnifier or 0; magBtn.Visible = count > 0
		local lbl = magBtn:FindFirstChild("UsesLbl")
		if lbl then lbl.Text = count .. " Use" .. (count ~= 1 and "s" or "") end
	end
	local hookBtn = powerupContainer:FindFirstChild("HookBtn")
	if hookBtn then
		local count = powerups.hook or 0; hookBtn.Visible = count > 0
		local lbl = hookBtn:FindFirstChild("UsesLbl")
		if lbl then lbl.Text = count .. " Use" .. (count ~= 1 and "s" or "") end
	end
	local boostBtn = powerupContainer:FindFirstChild("BoostBtn")
	if boostBtn then
		boostBtn.Visible = (boostTime or 0) > 0
		local lbl = boostBtn:FindFirstChild("TimeLbl")
		if lbl then lbl.Text = formatTime(boostTime or 0) end
	end
end
local function startLiveCountdown()
	if updateConnection then updateConnection:Disconnect() end
	lastUpdateTime = tick()
	updateConnection = RunService.Heartbeat:Connect(function()
		local now = tick(); local dt = now - lastUpdateTime; lastUpdateTime = now
		if not payload or not activeCat then return end
		if activeCat == "playtime" then
			playtimeSeconds += dt; subLbl.Text = "You played for " .. formatTime(playtimeSeconds)
		elseif activeCat == "daily" then
			dailyCountdown = math.max(0, dailyCountdown - dt)
			subLbl.Text = "Ready to claim in " .. formatTime(dailyCountdown)
		end
	end)
end
local function stopLiveCountdown()
	if updateConnection then updateConnection:Disconnect(); updateConnection = nil end
end

local function drawRows()
	clearRows()
	local rows = payload and payload.categories and payload.categories[activeCat] or {}
	if payload and payload.powerups then
		updatePowerupDisplay(payload.powerups, payload.boostTimeLeft or 0)
	end
	local y    = 6
	local rowH = rowTemplate.Size.Y.Offset > 0 and rowTemplate.Size.Y.Offset or 100
	local gap  = 10
	for idx, row in ipairs(rows) do
		local clone = rowTemplate:Clone()
		clone.Visible  = true
		clone.Name     = "Row_" .. tostring(row.id)
		clone.Position = UDim2.new(rowTemplate.Position.X.Scale, rowTemplate.Position.X.Offset, 0, y)
		clone.Size     = UDim2.new(rowTemplate.Size.X.Scale, rowTemplate.Size.X.Offset, 0, rowH)
		clone.Parent   = rowsScroll
		setupRowContent(clone, activeCat, idx, row)
		local claimBtn = clone:FindFirstChild("ClaimBtn")
		if claimBtn and claimBtn:IsA("TextButton") then
			styleClaim(claimBtn, row)
			claimBtn.MouseButton1Click:Connect(function()
				if row.ready and not row.claimed then RewardClaim:FireServer(activeCat, row.id) end
			end)
		end
		y += rowH + gap
	end
	rowsScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	rowsScroll.CanvasSize = UDim2.new(0,0,0, math.max(y+8, rowsScroll.AbsoluteSize.Y+1))
end

local function render()
	if not activeCat then return end
	titleLbl.Text = CAT_TITLE[activeCat] or "Rewards"
	if not payload then subLbl.Text = "Waiting for server sync..."; clearRows(); return end
	if lastRenderedCat ~= activeCat then
		lastRenderedCat = activeCat
		if activeCat == "playtime" then
			playtimeSeconds = tonumber(payload.totalPlaytime) or 0
			lastUpdateTime  = tick()
			subLbl.Text     = "You played for " .. formatTime(playtimeSeconds)
			startLiveCountdown()
		elseif activeCat == "daily" then
			dailyCountdown = tonumber(payload.dailyCountdown) or 0
			lastUpdateTime = tick()
			subLbl.Text    = "Ready to claim in " .. formatTime(dailyCountdown)
			startLiveCountdown()
		else
			stopLiveCountdown()
			if activeCat == "social" then subLbl.Text = "Follow these developers on Roblox!"
			elseif activeCat == "group" then subLbl.Text = "Like the game + Join the group"
			elseif activeCat == "vipdaily" then subLbl.Text = "Become VIP to claim"
			elseif activeCat == "robuxspent" then
				robuxSpentTotal = tonumber(payload.robuxSpentTotal) or 0
				subLbl.Text = "Total spent: " .. formatCash(robuxSpentTotal) .. " Robux"
			end
		end
	end
	drawRows()
end

for btnName, cat in pairs(TAB_TO_CAT) do
	local btn = leftTabs:FindFirstChild(btnName)
	if btn and btn:IsA("TextButton") then
		btn.MouseButton1Click:Connect(function()
			if activeCat ~= cat then lastRenderedCat = nil end
			activeCat = cat
			render()
		end)
	else
		warn("[Rewards] Button not found:", btnName)
	end
end

root.Visible = false

local t = 0
while not _G.UIWindowAnimator and t < 5 do task.wait(0.1); t += 0.1 end

if _G.UIWindowAnimator then
	-- Pass onOpen as 5th arg — animator fires it, no duplicate connection needed
	_G.UIWindowAnimator.register("rewards", root, openBtn, closeBtn, function()
		RewardRequestSync:FireServer()
	end)
else
	openBtn.MouseButton1Click:Connect(function() root.Visible = not root.Visible end)
	closeBtn.MouseButton1Click:Connect(function() root.Visible = false end)
end

RewardSync.OnClientEvent:Connect(function(newPayload)
	if type(newPayload) ~= "table" then warn("[Rewards] Invalid payload"); return end
	local serverPlaytime = tonumber(newPayload.totalPlaytime) or 0
	local serverDaily    = tonumber(newPayload.dailyCountdown) or 0
	if serverPlaytime > playtimeSeconds then
		playtimeSeconds = serverPlaytime; lastUpdateTime = tick()
	end
	dailyCountdown = serverDaily
	payload = newPayload
	if activeCat then drawRows() end
end)

root.Visible = false
print("[RewardsController] Ready")
