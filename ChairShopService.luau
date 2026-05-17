local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local DS = DataStoreService:GetDataStore("GMC_Chairs_V1")

local GROUP_ID = 35973544
local PASS_TO_CHAIRS = {
	[1840862526] = { "Rainbow", "Bloodmoon" },
	[1840721728] = { "Hacker" },
	[1839924043] = { "Portal" },
	[1839628382] = { "VIP" },
	-- [ANOTHER_PASS_ID] = { "AnotherChair" },
}
local DEV_TEST_USERS = {
	[3721585498] = true, -- replace with your own UserId
}
local REFRESH_INTERVAL = 21600
local SHOP_HEIGHT_OFFSET = 0.15
local SAVE_DEBOUNCE = 10
local LOAD_RETRIES = 4

local Events = RS:WaitForChild("Events")
local function ensureEvent(name, class)
	local e = Events:FindFirstChild(name)
	if not e then
		e = Instance.new(class)
		e.Name = name
		e.Parent = Events
	end
	return e
end

local EquipChair = ensureEvent("EquipChair", "RemoteEvent")
local ChairSync = ensureEvent("ChairSync", "RemoteEvent")
local NotifyPlayer = ensureEvent("NotifyPlayer", "RemoteEvent")
local RequestSync = ensureEvent("RequestSync", "RemoteFunction")

local CHAIR_POOL = {
	Common = {"Cardboard","Rusty","Metal","Sand"},
	Uncommon = {"Rock","Grass","Ice","Candy"},
	Rare = {"Shiny","Snow","Brick","Water","Magma","Mirror"},
	Legendary = {"Lava","Zap","Radioactive","Angel","Demon"},
	Secret = {"Pure","Void", "Joker"},
}

local CHAIR_PRICES = {
	Cardboard=200, Metal=400, Rusty=600, Sand=800, Joker=900000, Grass=1000, Rock=1400,
	Brick=1800, Candy=2400, Ice=3000, Snow=4000, Shiny=5000, Mirror=6500, Magma=8000,
	Water=7000, Zap=12000, Radioactive=16000, Lava=20000, Demon=24000, Angel=30000,
	Pure=50000, Void=50000,
}
_G.CHAIR_PRICES = CHAIR_PRICES
local ShopChairs = RS:WaitForChild("Chairs"):WaitForChild("ShopChairs")
local Podium = workspace:WaitForChild("ChairPodium")
local Pads = {
	Common = Podium:WaitForChild("CommonPad"),
	Uncommon1 = Podium:WaitForChild("UncommonPad1"),
	Uncommon2 = Podium:WaitForChild("UncommonPad2"),
	Rare1 = Podium:WaitForChild("RarePad1"),
	Rare2 = Podium:WaitForChild("RarePad2"),
	LegSec = Podium:WaitForChild("LegSecPad"),
}
local CountdownLbl = Podium:WaitForChild("CountdownPart"):WaitForChild("CountdownLabel"):WaitForChild("Text"):WaitForChild("ChairLbl")

local playerData = {}
local loadedOk = {}
local saveQueued = {}

local function normalizeData(d)
	if type(d) ~= "table" then
		d = { owned = {"Default"}, equipped = "Default" }
	end
	d.owned = (type(d.owned) == "table") and d.owned or {"Default"}
	d.equipped = (type(d.equipped) == "string" and d.equipped ~= "") and d.equipped or "Default"
	if not table.find(d.owned, "Default") then
		table.insert(d.owned, "Default")
	end
	return d
end

local function hasChair(data, chairName)
	if not data or type(data.owned) ~= "table" then return false end
	return table.find(data.owned, chairName) ~= nil
end

local function safeLoad(userId)
	local key = "c_" .. userId
	for i = 1, LOAD_RETRIES do
		local ok, data = pcall(function()
			return DS:GetAsync(key)
		end)
		if ok then
			return normalizeData(data), true
		end
		task.wait(i * 1.5)
	end
	return normalizeData(nil), false
end

local function saveNow(userId)
	if not loadedOk[userId] then return end
	local data = playerData[userId]
	if not data then return end

	local key = "c_" .. userId
	local snapshot = normalizeData({
		owned = table.clone(data.owned),
		equipped = data.equipped,
	})

	for i = 1, 3 do
		local ok = pcall(function()
			DS:SetAsync(key, snapshot)
		end)
		if ok then return end
		task.wait(i)
	end
end

local function queueSave(userId)
	if not loadedOk[userId] then return end
	if saveQueued[userId] then return end
	saveQueued[userId] = true
	task.delay(SAVE_DEBOUNCE, function()
		saveQueued[userId] = nil
		saveNow(userId)
	end)
end

local function syncPlayer(player)
	local data = playerData[player.UserId]
	if data then ChairSync:FireClient(player, data) end
end

local function grantChair(player, chairName, notifyText)
	local data = playerData[player.UserId]
	if not data then return false end
	if hasChair(data, chairName) then return false end

	table.insert(data.owned, chairName)
	queueSave(player.UserId)
	syncPlayer(player)

	if notifyText then
		NotifyPlayer:FireClient(player, {
			title = "Chair Unlocked",
			message = notifyText,
			kind = "success",
			duration = 3,
		})
	end
	return true
end

local function grantPassChairs(player)
	local data = playerData[player.UserId]
	if not data then return end

	local changed = false

	for passId, chairList in pairs(PASS_TO_CHAIRS) do
		local owns = false

		if DEV_TEST_USERS[player.UserId] then
			owns = true
		else
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			owns = ok and result
		end

		if owns then
			for _, chairName in ipairs(chairList) do
				if not hasChair(data, chairName) then
					table.insert(data.owned, chairName)
					changed = true
				end
			end
		end
	end

	if changed then
		queueSave(player.UserId)
		syncPlayer(player)
		NotifyPlayer:FireClient(player, {
			title = "Gamepass Chairs",
			message = "Pass chairs unlocked.",
			kind = "success",
			duration = 3,
		})
	end
end

-- Ensure this connection exists so newly purchased gamepasses apply quickly
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if wasPurchased then
		task.delay(1, function()
			grantPassChairs(player)
		end)
	end
end)

local function grantGroupChair(player)
	local data = playerData[player.UserId]
	if not data then return end

	local ok, inGroup = pcall(function()
		return GROUP_ID > 0 and player:IsInGroup(GROUP_ID)
	end)
	if not ok or not inGroup then return end

	if not hasChair(data, "Deer") then
		table.insert(data.owned, "Deer")
		queueSave(player.UserId)
		syncPlayer(player)
		NotifyPlayer:FireClient(player, {
			title = "Group Reward",
			message = "Deer unlocked",
			kind = "success",
			duration = 3,
		})
	end
end

_G.GetEquippedChair = function(p)
	if not p or not playerData[p.UserId] then return "Default" end
	return playerData[p.UserId].equipped or "Default"
end

_G.PlayerOwnsChair = function(player, chairName)
	local data = player and playerData[player.UserId]
	return hasChair(data, chairName)
end

_G.ChairGrantToPlayer = function(player, chairName, notifyText)
	if not player or not chairName then return false end
	return grantChair(player, chairName, notifyText)
end

_G.ChairGrantMystery = function(player, count, pool)
	local data = player and playerData[player.UserId]
	if not data then return {} end

	count = math.max(1, tonumber(count) or 1)
	local granted = {}

	for _ = 1, count do
		local candidates = {}
		for _, chairName in ipairs(pool) do
			if not hasChair(data, chairName) then
				table.insert(candidates, chairName)
			end
		end
		if #candidates == 0 then break end

		local pick = candidates[math.random(1, #candidates)]
		if grantChair(player, pick, nil) then
			table.insert(granted, pick)
		end
	end

	if #granted > 0 then
		NotifyPlayer:FireClient(player, {
			title = "Mystery Reward",
			message = "You got: " .. table.concat(granted, ", "),
			kind = "success",
			duration = 4,
		})
	end

	return granted
end

local function placeOnPad(pad, name)
	for _, c in ipairs(pad:GetChildren()) do
		if c:IsA("Model") or c:IsA("ProximityPrompt") then c:Destroy() end
	end

	local m = ShopChairs:FindFirstChild(name)
	if not m then return end

	local clone = m:Clone()
	clone.Name = "ShopChair"
	clone.Parent = pad

	local _, size = clone:GetBoundingBox()
	clone:PivotTo(pad.CFrame * CFrame.new(0, (size.Y / 2) + SHOP_HEIGHT_OFFSET, 0))

	local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
	if primary then
		primary.Anchored = true
		local startCF = clone:GetPivot()
		task.spawn(function()
			local angle = 0
			while clone and clone.Parent do
				angle += 0.02
				clone:PivotTo(startCF * CFrame.Angles(0, angle, 0) * CFrame.new(0, math.sin(tick() * 2) * 0.25, 0))
				RunService.Heartbeat:Wait()
			end
		end)
	end

	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Buy " .. name
	pr.ObjectText = "$" .. tostring(CHAIR_PRICES[name] or 1000)
	pr.Parent = pad

	pr.Triggered:Connect(function(player)
		local data = playerData[player.UserId]
		if not data or hasChair(data, name) then return end

		local ls = player:FindFirstChild("leaderstats")
		local cash = ls and ls:FindFirstChild("Cash")
		if not cash then return end

		local cost = CHAIR_PRICES[name] or 1000
		if cash.Value >= cost then
			cash.Value -= cost
			table.insert(data.owned, name)
			queueSave(player.UserId)
			syncPlayer(player)
			NotifyPlayer:FireClient(player, { title = "Purchased", message = name, kind = "success", duration = 2.5 })
		else
			NotifyPlayer:FireClient(player, { title = "Not enough cash", message = "$" .. tostring(cost), kind = "warn", duration = 2.0 })
		end
	end)
end

local function refreshAll()
	local rng = Random.new()
	local isSecret = rng:NextNumber(0, 100) < 4
	local picks = {
		Common = CHAIR_POOL.Common[rng:NextInteger(1, #CHAIR_POOL.Common)],
		Uncommon1 = CHAIR_POOL.Uncommon[rng:NextInteger(1, #CHAIR_POOL.Uncommon)],
		Uncommon2 = CHAIR_POOL.Uncommon[rng:NextInteger(1, #CHAIR_POOL.Uncommon)],
		Rare1 = CHAIR_POOL.Rare[rng:NextInteger(1, #CHAIR_POOL.Rare)],
		Rare2 = CHAIR_POOL.Rare[rng:NextInteger(1, #CHAIR_POOL.Rare)],
		LegSec = isSecret and CHAIR_POOL.Secret[rng:NextInteger(1, #CHAIR_POOL.Secret)] or CHAIR_POOL.Legendary[rng:NextInteger(1, #CHAIR_POOL.Legendary)],
	}
	for key, pad in pairs(Pads) do
		placeOnPad(pad, picks[key])
	end
end

Players.PlayerAdded:Connect(function(p)
	local data, ok = safeLoad(p.UserId)
	playerData[p.UserId] = data
	loadedOk[p.UserId] = ok

	if not ok then
		NotifyPlayer:FireClient(p, {
			title = "Inventory Sync",
			message = "Data is busy, retrying...",
			kind = "warn",
			duration = 4,
		})

		task.spawn(function()
			for _ = 1, 5 do
				task.wait(4)
				local retryData, retryOk = safeLoad(p.UserId)
				if retryOk then
					playerData[p.UserId] = retryData
					loadedOk[p.UserId] = true
					grantPassChairs(p)
					grantGroupChair(p)
					syncPlayer(p)
					return
				end
			end
		end)
	else
		grantPassChairs(p)
		grantGroupChair(p)
		syncPlayer(p)
	end
end)

Players.PlayerRemoving:Connect(function(p)
	saveQueued[p.UserId] = nil
	saveNow(p.UserId)
	playerData[p.UserId] = nil
	loadedOk[p.UserId] = nil
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		saveNow(p.UserId)
	end
end)

EquipChair.OnServerEvent:Connect(function(p, name)
	local data = playerData[p.UserId]
	if not data then return end
	if not hasChair(data, name) then return end

	data.equipped = name
	queueSave(p.UserId)
	syncPlayer(p)
	NotifyPlayer:FireClient(p, { title = "Equipped", message = name, kind = "info", duration = 2.0 })
end)

RequestSync.OnServerInvoke = function(p)
	if not playerData[p.UserId] then
		playerData[p.UserId] = normalizeData(nil)
	end

	if loadedOk[p.UserId] then
		grantPassChairs(p)
		grantGroupChair(p)
	end

	return playerData[p.UserId]
end

task.spawn(function()
	while true do
		local diff = REFRESH_INTERVAL - (os.time() % REFRESH_INTERVAL)
		CountdownLbl.Text = string.format("%02d:%02d", math.floor(diff / 60), diff % 60)
		if diff <= 1 then
			task.wait(1.1)
			refreshAll()
		end
		task.wait(1)
	end
end)

refreshAll()
print("[ChairShopService] Ready")
