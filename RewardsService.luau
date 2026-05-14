-- RewardsService - FIXED: checkDailyReset preserves pt_* claims, request sync added
print("[Rewards] Server script starting...")

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")

local Events = RS:WaitForChild("Events")
local RewardDataStore = DataStoreService:GetDataStore("RewardsData_V1")
print("[Rewards] DataStore loaded")
local ChairStore = DataStoreService:GetDataStore("GMC_Chairs_V1")
local MYSTERY_CHAIR_POOL = {
	"Cardboard","Rusty","Metal","Sand","Joker",
	"Rock","Grass","Ice","Candy",
	"Shiny","Snow","Brick","Water","Magma","Mirror",
}
local function ensureEvent(name)
	local e = Events:FindFirstChild(name)
	if e then return e end
	e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = Events
	return e
end

local RewardSync        = ensureEvent("RewardSync")
local RewardClaim       = ensureEvent("RewardClaim")
local NotifyPlayer      = ensureEvent("NotifyPlayer")
local AddRobuxSpent     = ensureEvent("AddRobuxSpent")
local UsePowerup        = ensureEvent("UsePowerup")
local RewardRequestSync = ensureEvent("RewardRequestSync")
print("[Rewards] Events created")

local DAILY_SECONDS = 24 * 60 * 60

local playerData = {}

local function loadData(player)
	local success, data = pcall(function()
		return RewardDataStore:GetAsync("player_" .. player.UserId)
	end)
	if success and data then
		print("[Rewards] Loaded data for", player.Name)
		-- Ensure all keys exist (handles old saves missing new fields)
		data.claimed         = data.claimed or {}
		data.lastDailyClaim  = data.lastDailyClaim or 0
		data.dailyDay        = data.dailyDay or 1
		data.robuxSpent      = data.robuxSpent or 0
		data.lastClaimDate   = data.lastClaimDate or os.date("%Y-%m-%d")
		data.totalPlaytime   = data.totalPlaytime or 0
		data.powerups        = data.powerups or {}
		data.powerups.magnifier    = data.powerups.magnifier or 0
		data.powerups.hook         = data.powerups.hook or 0
		data.powerups.mystery      = data.powerups.mystery or 0
		data.powerups.boost2x      = data.powerups.boost2x or 0
		data.powerups.boost2xExpiry = data.powerups.boost2xExpiry or 0
		return data
	end
	print("[Rewards] No data for", player.Name, "- creating new")
	return {
		claimed = {},
		lastDailyClaim = 0,
		dailyDay = 1,
		robuxSpent = 0,
		lastClaimDate = os.date("%Y-%m-%d"),
		totalPlaytime = 0,
		powerups = {
			magnifier = 0,
			hook = 0,
			mystery = 0,
			boost2x = 0,
			boost2xExpiry = 0,
		},
	}
end
local function giveRandomChair(player, count)
	count = math.max(1, tonumber(count) or 1)

	local key = "c_" .. player.UserId
	local data = nil
	local okLoad, loaded = pcall(function()
		return ChairStore:GetAsync(key)
	end)

	if okLoad and type(loaded) == "table" then
		data = loaded
	else
		data = { owned = {"Default"}, equipped = "Default" }
	end

	data.owned = data.owned or {"Default"}
	data.equipped = data.equipped or "Default"

	local ownedSet = {}
	for _, c in ipairs(data.owned) do
		ownedSet[c] = true
	end

	local granted = {}
	for _ = 1, count do
		local candidates = {}
		for _, chairName in ipairs(MYSTERY_CHAIR_POOL) do
			if not ownedSet[chairName] then
				table.insert(candidates, chairName)
			end
		end

		if #candidates == 0 then break end
		local pick = candidates[math.random(1, #candidates)]
		ownedSet[pick] = true
		table.insert(data.owned, pick)
		table.insert(granted, pick)
	end

	pcall(function()
		ChairStore:SetAsync(key, data)
	end)

	if #granted > 0 then
		NotifyPlayer:FireClient(player, {
			title = "Mystery Reward",
			message = "You got: " .. table.concat(granted, ", "),
			kind = "success",
			duration = 4,
		})
	end
end
local function saveData(player)
	local data = playerData[player.UserId]
	if not data then return end
	local success, err = pcall(function()
		RewardDataStore:SetAsync("player_" .. player.UserId, data)
	end)
	if success then
		print("[Rewards] Saved data for", player.Name)
	else
		warn("[Rewards] Failed to save for", player.Name, err)
	end
end

local function ensureData(player)
	if not playerData[player.UserId] then
		playerData[player.UserId] = loadData(player)
	end
	return playerData[player.UserId]
end

local PLAYTIME = {
	{ id = "pt_5",  rewards = "+$250", requiredMin = 5 },
	{ id = "pt_10", rewards = "+$250, x2 5min", requiredMin = 10 },
	{ id = "pt_15", rewards = "+$300, +1 Magnifier", requiredMin = 15 },
	{ id = "pt_20", rewards = "+$300, +1 Magnifier, +1 Hook", requiredMin = 20 },
	{ id = "pt_30", rewards = "+$300, +1 Magnifier, +2 Hook, x2 15min", requiredMin = 30 },
	{ id = "pt_45", rewards = "+$500, +2 Magnifier, +2 Hook", requiredMin = 45 },
	{ id = "pt_60", rewards = "+$600, +1 Mystery", requiredMin = 60 },
}

local DAILY = {
	{ id = "d1", rewards = "+$300" },
	{ id = "d2", rewards = "+$400, +1 Magnifier, +1 Hook, +1 Mystery" },
	{ id = "d3", rewards = "+$350, +1 Hook" },
	{ id = "d4", rewards = "+$450, x2 5min" },
	{ id = "d5", rewards = "+$600" },
	{ id = "d6", rewards = "+$650, +2 Hook, x2 15min" },
	{ id = "d7", rewards = "+$800, +1 Magnifier, +1 Hook, +1 Mystery" },
}

local ROBUX_SPENT = {
	{ id = "rb_100",   rewards = "+$500, +1 Magnifier", required = 100 },
	{ id = "rb_250",   rewards = "+$1000, +1 Magnifier, +1 Hook", required = 250 },
	{ id = "rb_500",   rewards = "+$2000, +1 Magnifier, +2 Hook", required = 500 },
	{ id = "rb_1000",  rewards = "+$4000, +2 Magnifier, +2 Hook", required = 1000 },
	{ id = "rb_2500",  rewards = "+$8000, +1 Mystery", required = 2500 },
	{ id = "rb_5000",  rewards = "+$15000, +2 Mystery", required = 5000 },
	{ id = "rb_10000", rewards = "+$30000, +2 Magnifier, +2 Hook, +2 Mystery", required = 10000 },
}

local function addCash(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		cash.Value += amount
		print("[Rewards] Added", amount, "cash to", player.Name)
	end
end

local function isClaimed(data, id)
	return data.claimed[id] == true
end

local function markClaimed(player, id, rewards)
	local data = ensureData(player)
	data.claimed[id] = true

	if rewards:find("Magnifier") then
		local count = tonumber(rewards:match("+(%d+) Magnifier")) or 1
		data.powerups.magnifier = (data.powerups.magnifier or 0) + count
	end
	if rewards:find("Hook") then
		local count = tonumber(rewards:match("+(%d+) Hook")) or 1
		data.powerups.hook = (data.powerups.hook or 0) + count
	end
	if rewards:find("Mystery") then
		local count = tonumber(rewards:match("%+(%d+) Mystery")) or 1
		giveRandomChair(player, count)
	end
	if rewards:find("x2") then
		local minutes = tonumber(rewards:match("x2 (%d+)min")) or 5
		local expiry = os.time() + (minutes * 60)
		if expiry > (data.powerups.boost2xExpiry or 0) then
			data.powerups.boost2xExpiry = expiry
			data.powerups.boost2x = 1
		end
	end

	local cashAmount = tonumber(rewards:match("%+%$(%d+)"))
	if cashAmount then
		addCash(player, cashAmount)
	end

	saveData(player)
end

local function getDailyCountdown(data)
	if (data.lastDailyClaim or 0) <= 0 then return 0 end
	return math.max(0, DAILY_SECONDS - (os.time() - data.lastDailyClaim))
end

-- FIX: daily reset only clears non-playtime claims.
-- Previously this wiped ALL claims including pt_* which made playtime rewards
-- unclaim-able the next day even if the player had reached the time threshold.
local function checkDailyReset(player, data)
	local today = os.date("%Y-%m-%d")
	if data.lastClaimDate ~= today then
		-- Clear daily/group/social/vip/robux claims but KEEP pt_* claims
		for id in pairs(data.claimed) do
			if string.sub(id, 1, 3) ~= "pt_" then
				data.claimed[id] = nil
			end
		end
		data.lastClaimDate  = today
		data.lastDailyClaim = os.time()
		data.dailyDay       = 1
		saveData(player)
		print("[Rewards] Daily reset for", player.Name, "(pt_* claims preserved)")
	end
end

local function getBoostTimeRemaining(data)
	if not data.powerups then return 0 end
	return math.max(0, (data.powerups.boost2xExpiry or 0) - os.time())
end

local function buildPayload(player, data)
	local totalPlaytime = data.totalPlaytime or 0
	local playMin       = math.floor(totalPlaytime / 60)
	local dailyLeft     = getDailyCountdown(data)
	local robuxSpent    = data.robuxSpent or 0
	local boostTimeLeft = getBoostTimeRemaining(data)

	local categories = {
		playtime = {}, daily = {}, group = {},
		social = {}, vipdaily = {}, robuxspent = {},
	}

	for _, row in ipairs(PLAYTIME) do
		table.insert(categories.playtime, {
			id      = row.id,
			rewards = row.rewards,
			left    = row.requiredMin .. "m",
			claimed = isClaimed(data, row.id),
			ready   = playMin >= row.requiredMin and not isClaimed(data, row.id),
		})
	end

	for idx, row in ipairs(DAILY) do
		table.insert(categories.daily, {
			id      = row.id,
			rewards = row.rewards,
			claimed = isClaimed(data, row.id),
			ready   = data.dailyDay == idx and dailyLeft <= 0,
		})
	end

	local groupReady = false
	local ok, inGroup = pcall(function() return player:IsInGroup(0) end) -- replace 0 with your group ID
	if ok and inGroup then groupReady = true end
	table.insert(categories.group, {
		id = "group_main", rewards = "+$200, +1 Magnifier, +1 Hook",
		claimed = isClaimed(data, "group_main"), ready = groupReady,
	})

	table.insert(categories.social, {
		id = "social_main", rewards = "+$500, +1 Hook, +1 Mystery, x2 5min",
		claimed = isClaimed(data, "social_main"), ready = true,
	})

	local perks  = player:FindFirstChild("ShopPerks")
	local vip    = perks and perks:FindFirstChild("VIPPack")
	local vipReady = vip and vip:IsA("BoolValue") and vip.Value == true
	table.insert(categories.vipdaily, {
		id = "vip_daily_main", rewards = "+$300, +1 Magnifier, +2 Hook",
		claimed = isClaimed(data, "vip_daily_main"), ready = vipReady,
	})

	for _, row in ipairs(ROBUX_SPENT) do
		table.insert(categories.robuxspent, {
			id = row.id, rewards = row.rewards, left = row.required,
			claimed = isClaimed(data, row.id), ready = robuxSpent >= row.required,
		})
	end

	return {
		totalPlaytime  = totalPlaytime,
		dailyCountdown = dailyLeft,
		categories     = categories,
		robuxSpentTotal = robuxSpent,
		boostTimeLeft  = boostTimeLeft,
		powerups       = data.powerups or {},
	}
end

local function syncPlayer(player)
	local data = ensureData(player)
	checkDailyReset(player, data)
	print("[Rewards] Syncing", player.Name)
	RewardSync:FireClient(player, buildPayload(player, data))
end

-- Claim handler
RewardClaim.OnServerEvent:Connect(function(player, categoryId, rowId)
	print("[Rewards] Claim:", player.Name, categoryId, rowId)
	local data = ensureData(player)
	local payload = buildPayload(player, data)
	local rows = payload.categories[categoryId]
	if type(rows) ~= "table" then
		warn("[Rewards] Invalid category:", categoryId)
		syncPlayer(player); return
	end
	local row
	for _, r in ipairs(rows) do
		if r.id == rowId then row = r; break end
	end
	if not row or row.claimed or not row.ready then
		warn("[Rewards] Not claimable:", rowId)
		syncPlayer(player); return
	end

	markClaimed(player, row.id, row.rewards)

	if categoryId == "daily" then
		data.lastDailyClaim = os.time()
		data.dailyDay = (data.dailyDay or 1) % 7 + 1
		saveData(player)
	end

	NotifyPlayer:FireClient(player, {
		title    = "Reward Claimed!",
		message  = row.rewards,
		kind     = "success",
		duration = 3,
	})
	syncPlayer(player)
end)
_G.RewardsAddRobuxSpent = function(player, amount)
	if not player then return end
	amount = tonumber(amount) or 0
	if amount <= 0 then return end
	AddRobuxSpent.OnServerEvent:Connect(function(player, amount)
		if _G.RewardsAddRobuxSpent then
			_G.RewardsAddRobuxSpent(player, amount)
		end
	end)
	local data = ensureData(player)
	data.robuxSpent = (data.robuxSpent or 0) + amount
	saveData(player)
	RewardSync:FireClient(player, buildPayload(player, data))
end
-- Robux spent
AddRobuxSpent.OnServerEvent:Connect(function(player, amount)
	if type(amount) ~= "number" or amount <= 0 then return end
	local data = ensureData(player)
	data.robuxSpent = (data.robuxSpent or 0) + amount
	saveData(player)
	print("[Rewards]", player.Name, "spent", amount, "robux. Total:", data.robuxSpent)
	NotifyPlayer:FireClient(player, {
		title    = "Thank You For Your Purchase!",
		message  = "+" .. amount .. " Robux added to your total",
		kind     = "robux",
		duration = 4,
	})
	syncPlayer(player)
end)

-- Powerup use
UsePowerup.OnServerEvent:Connect(function(player, powerupType)
	local data = ensureData(player)
	if not data.powerups then return end
	local key = ({ magnifier = "magnifier", hook = "hook", mystery = "mystery" })[powerupType]
	if not key then return end
	if (data.powerups[key] or 0) <= 0 then
		warn("[Rewards] No", powerupType, "for", player.Name); return
	end
	data.powerups[key] -= 1
	saveData(player)
	NotifyPlayer:FireClient(player, {
		title = "Powerup Used!", message = "You used 1 " .. powerupType,
		kind = "info", duration = 2,
	})
	syncPlayer(player)
end)

-- Manual sync request from client (e.g. on panel open)
RewardRequestSync.OnServerEvent:Connect(function(player)
	print("[Rewards] Manual sync requested by", player.Name)
	syncPlayer(player)
end)

-- Player join
Players.PlayerAdded:Connect(function(player)
	print("[Rewards] Player joined:", player.Name)
	local data = ensureData(player)

	-- Playtime is session-based: reset to 0 each join so pt_* rewards
	-- require the player to actually play this session.
	-- pt_* claims are also cleared so they can earn them again this session.
	data.totalPlaytime = 0
	if type(data.claimed) ~= "table" then data.claimed = {} end
	for id in pairs(data.claimed) do
		if string.sub(id, 1, 3) == "pt_" then
			data.claimed[id] = nil
		end
	end
	saveData(player)

	-- Playtime ticker
	task.spawn(function()
		while player.Parent do
			task.wait(1)
			if not playerData[player.UserId] then break end
			data.totalPlaytime = (data.totalPlaytime or 0) + 1
			if data.totalPlaytime % 60 == 0 then
				saveData(player)
				print("[Rewards] Playtime saved:", player.Name, data.totalPlaytime .. "s")
			end
		end
	end)

	-- Initial sync after short delay so leaderstats are ready
	task.delay(1.5, function()
		if player.Parent then syncPlayer(player) end
	end)
end)

-- Player leave
Players.PlayerRemoving:Connect(function(player)
	print("[Rewards] Player leaving:", player.Name)
	saveData(player)
	playerData[player.UserId] = nil
end)

-- Auto-save every 5 minutes
task.spawn(function()
	while true do
		task.wait(300)
		for _, p in ipairs(Players:GetPlayers()) do
			saveData(p)
		end
	end
end)

-- Global API for other server scripts
local POWERUP_TO_INV = {
	hint           = "magnifier",
	reveal_country = "hook",
	reveal_letter  = "mystery",
}

_G.RewardsUsePowerup = function(player, powerupType)
	local data = ensureData(player)
	if not data or not data.powerups then return false end
	local key = POWERUP_TO_INV[powerupType]
	if not key or (data.powerups[key] or 0) <= 0 then return false end
	data.powerups[key] -= 1
	saveData(player)
	syncPlayer(player)
	return true
end

_G.RewardsPlayerData = function(player) return ensureData(player) end
_G.RewardsSaveData   = function(player) saveData(player) end
_G.RewardsSyncPlayer = function(player) syncPlayer(player) end

print("[RewardsService] Ready")
