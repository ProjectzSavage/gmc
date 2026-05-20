-- RewardsService
print("[Rewards] Server script starting...")

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Events = RS:WaitForChild("Events")
local RewardDataStore = DataStoreService:GetDataStore("RewardsData_V1")
local ChairStore = DataStoreService:GetDataStore("GMC_Chairs_V1")

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

local DAILY_SECONDS = 24 * 60 * 60
local FOLLOW_CACHE_TTL = 300

local SOCIAL_TARGETS = {
	{
		id = 3107183806,
		reward = 500,
		title = "Follow Owner",
		rewards = "+$500, +1 Magnifier",
	},
	{
		id = 3721585498,
		reward = 500,
		title = "Follow Co-Owner",
		rewards = "+$500, +1 Hook",
	},
}

local MYSTERY_CHAIR_POOL = {
	"Cardboard", "Rusty", "Metal", "Sand", "Joker",
	"Rock", "Grass", "Ice", "Candy",
	"Shiny", "Snow", "Brick", "Water", "Magma", "Mirror",
}

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

local playerData = {}
local followCache = {}

local function normalizeData(data)
	if type(data) ~= "table" then
		data = {}
	end

	data.claimed = data.claimed or {}
	data.lastDailyClaim = data.lastDailyClaim or 0
	data.dailyDay = data.dailyDay or 1
	data.robuxSpent = data.robuxSpent or 0
	data.lastClaimDate = data.lastClaimDate or os.date("%Y-%m-%d")
	data.totalPlaytime = data.totalPlaytime or 0
	data.powerups = data.powerups or {}
	data.powerups.magnifier = data.powerups.magnifier or 0
	data.powerups.hook = data.powerups.hook or 0
	data.powerups.mystery = data.powerups.mystery or 0
	data.powerups.boost2x = data.powerups.boost2x or 0
	data.powerups.boost2xExpiry = data.powerups.boost2xExpiry or 0

	return data
end

local function loadData(player)
	local ok, data = pcall(function()
		return RewardDataStore:GetAsync("player_" .. player.UserId)
	end)

	if ok and type(data) == "table" then
		print("[Rewards] Loaded data for", player.Name)
		return normalizeData(data)
	end

	print("[Rewards] New data for", player.Name)
	return normalizeData(nil)
end

local function saveData(player)
	local data = playerData[player.UserId]
	if not data then return end

	local ok, err = pcall(function()
		RewardDataStore:SetAsync("player_" .. player.UserId, data)
	end)

	if not ok then
		warn("[Rewards] Failed to save for", player.Name, err)
	end
end

local function ensureData(player)
	if not playerData[player.UserId] then
		playerData[player.UserId] = loadData(player)
	end
	return playerData[player.UserId]
end

local function isFollowing(playerUserId, targetUserId)
	local key = tostring(playerUserId) .. ":" .. tostring(targetUserId)
	local cached = followCache[key]
	if cached and cached.expiresAt > os.time() then
		return cached.value
	end

	local cursor = nil
	for _ = 1, 20 do
		local url = string.format(
			"https://friends.roblox.com/v1/users/%d/followings?sortOrder=Asc&limit=100",
			playerUserId
		)

		if cursor then
			url ..= "&cursor=" .. HttpService:UrlEncode(cursor)
		end

		local ok, body = pcall(function()
			return HttpService:GetAsync(url)
		end)

		if not ok then
			warn("[Rewards] Follow check failed:", body)
			break
		end

		local decoded
		local okDecode = pcall(function()
			decoded = HttpService:JSONDecode(body)
		end)

		if not okDecode then
			warn("[Rewards] Follow decode failed")
			break
		end

		for _, row in ipairs(decoded.data or {}) do
			if tonumber(row.id) == targetUserId then
				followCache[key] = { value = true, expiresAt = os.time() + FOLLOW_CACHE_TTL }
				return true
			end
		end

		cursor = decoded.nextPageCursor
		if not cursor then break end
	end

	followCache[key] = { value = false, expiresAt = os.time() + FOLLOW_CACHE_TTL }
	return false
end

local function getDailyCountdown(data)
	if (data.lastDailyClaim or 0) <= 0 then return 0 end
	return math.max(0, DAILY_SECONDS - (os.time() - data.lastDailyClaim))
end

local function checkDailyReset(player, data)
	local today = os.date("%Y-%m-%d")
	if data.lastClaimDate ~= today then
		for id in pairs(data.claimed) do
			if string.sub(id, 1, 3) ~= "pt_" then
				data.claimed[id] = nil
			end
		end

		data.lastClaimDate = today
		data.lastDailyClaim = 0
		data.dailyDay = data.dailyDay or 1

		saveData(player)
	end
end

local function isClaimed(data, id)
	return data.claimed[id] == true
end

local function getBoostTimeRemaining(data)
	return math.max(0, ((data.powerups and data.powerups.boost2xExpiry) or 0) - os.time())
end

local function hasActive2x(player)
	local data = ensureData(player)
	return getBoostTimeRemaining(data) > 0
end

local function cashMultiplier(player)
	return hasActive2x(player) and 2 or 1
end

local function streakMultiplier(player)
	return hasActive2x(player) and 2 or 1
end

local function addCash(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		local finalAmount = amount * cashMultiplier(player)
		cash.Value += finalAmount
	end
end

local function grantMysteryChair(player, count)
	count = math.max(1, tonumber(count) or 1)

	local key = "c_" .. player.UserId
	local data

	local okLoad, loaded = pcall(function()
		return ChairStore:GetAsync(key)
	end)

	if okLoad and type(loaded) == "table" then
		data = loaded
	else
		data = { owned = { "Default" }, equipped = "Default" }
	end

	data.owned = data.owned or { "Default" }
	data.equipped = data.equipped or "Default"

	local owned = {}
	for _, chair in ipairs(data.owned) do
		owned[chair] = true
	end

	local granted = {}
	for _ = 1, count do
		local candidates = {}
		for _, chairName in ipairs(MYSTERY_CHAIR_POOL) do
			if not owned[chairName] then
				table.insert(candidates, chairName)
			end
		end

		if #candidates == 0 then break end

		local pick = candidates[math.random(1, #candidates)]
		owned[pick] = true
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

local function markClaimed(player, id, rewards)
	local data = ensureData(player)
	data.claimed[id] = true

	if rewards:find("Magnifier") then
		local count = tonumber(rewards:match("%+(%d+) Magnifier")) or 1
		data.powerups.magnifier += count
	end

	if rewards:find("Hook") then
		local count = tonumber(rewards:match("%+(%d+) Hook")) or 1
		data.powerups.hook += count
	end

	if rewards:find("Mystery") then
		local count = tonumber(rewards:match("%+(%d+) Mystery")) or 1
		grantMysteryChair(player, count)
	end

	if rewards:find("x2") then
		local minutes = tonumber(rewards:match("x2 (%d+)min")) or 5
		local expiry = os.time() + (minutes * 60)
		if expiry > (data.powerups.boost2xExpiry or 0) then
			data.powerups.boost2xExpiry = expiry
		end
		data.powerups.boost2x = 1
	end

	local cashAmount = tonumber(rewards:match("%+%$(%d+)"))
	if cashAmount then
		addCash(player, cashAmount)
	end

	saveData(player)
end

local function buildPayload(player, data)
	checkDailyReset(player, data)

	local totalPlaytime = data.totalPlaytime or 0
	local playMin = math.floor(totalPlaytime / 60)
	local dailyLeft = getDailyCountdown(data)
	local robuxSpent = data.robuxSpent or 0
	local boostTimeLeft = getBoostTimeRemaining(data)

	local categories = {
		playtime = {},
		daily = {},
		group = {},
		social = {},
		vipdaily = {},
		robuxspent = {},
	}

	for _, row in ipairs(PLAYTIME) do
		local claimed = isClaimed(data, row.id)
		table.insert(categories.playtime, {
			id = row.id,
			left = row.requiredMin .. "m",
			rewards = row.rewards,
			claimed = claimed,
			ready = playMin >= row.requiredMin and not claimed,
		})
	end

	for _, t in ipairs(SOCIAL_TARGETS) do
		local qid = "social_" .. tostring(t.id)
		local claimed = isClaimed(data, qid)
		local follows = isFollowing(player.UserId, t.id)

		table.insert(categories.social, {
			id = qid,
			left = t.title,
			rewards = t.rewards,
			claimed = claimed,
			ready = follows and not claimed,
			follows = follows,
		})
	end

	for idx, row in ipairs(DAILY) do
		local claimed = isClaimed(data, row.id)
		table.insert(categories.daily, {
			id = row.id,
			rewards = row.rewards,
			claimed = claimed,
			ready = data.dailyDay == idx and dailyLeft <= 0 and not claimed,
		})
	end

	local groupReady = false
	local okGroup, inGroup = pcall(function()
		return player:IsInGroup(35973544)
	end)
	if okGroup and inGroup then
		groupReady = true
	end

	table.insert(categories.group, {
		id = "group_main",
		rewards = "+$200, +1 Magnifier, +1 Hook",
		claimed = isClaimed(data, "group_main"),
		ready = groupReady and not isClaimed(data, "group_main"),
	})

	local perks = player:FindFirstChild("ShopPerks")
	local vip = perks and perks:FindFirstChild("VIPPack")
	local vipReady = vip and vip:IsA("BoolValue") and vip.Value == true

	table.insert(categories.vipdaily, {
		id = "vip_daily_main",
		rewards = "+$300, +1 Magnifier, +2 Hook",
		claimed = isClaimed(data, "vip_daily_main"),
		ready = vipReady and not isClaimed(data, "vip_daily_main"),
	})

	for _, row in ipairs(ROBUX_SPENT) do
		local claimed = isClaimed(data, row.id)
		table.insert(categories.robuxspent, {
			id = row.id,
			rewards = row.rewards,
			left = row.required,
			claimed = claimed,
			ready = robuxSpent >= row.required and not claimed,
		})
	end

	return {
		totalPlaytime = totalPlaytime,
		dailyCountdown = dailyLeft,
		categories = categories,
		robuxSpentTotal = robuxSpent,
		boostTimeLeft = boostTimeLeft,
		powerups = data.powerups or {},
	}
end

local function syncPlayer(player)
	local data = ensureData(player)
	RewardSync:FireClient(player, buildPayload(player, data))
end

RewardClaim.OnServerEvent:Connect(function(player, categoryId, rowId)
	local data = ensureData(player)

	if categoryId == "social" then
		local targetId = tonumber(string.match(rowId or "", "social_(%d+)"))
		if not targetId then return end

		if not isFollowing(player.UserId, targetId) then
			NotifyPlayer:FireClient(player, {
				title = "Not Eligible",
				message = "Follow this developer first, then try again.",
				kind = "warn",
				duration = 3,
			})
			syncPlayer(player)
			return
		end
	end

	local payload = buildPayload(player, data)
	local rows = payload.categories[categoryId]
	if type(rows) ~= "table" then
		syncPlayer(player)
		return
	end

	local row
	for _, r in ipairs(rows) do
		if r.id == rowId then
			row = r
			break
		end
	end

	if not row or row.claimed or not row.ready then
		syncPlayer(player)
		return
	end

	markClaimed(player, row.id, row.rewards)

	if categoryId == "daily" then
		data.lastDailyClaim = os.time()
		data.dailyDay = (data.dailyDay or 1) % 7 + 1
		saveData(player)
	end

	NotifyPlayer:FireClient(player, {
		title = "Reward Claimed!",
		message = row.rewards,
		kind = "success",
		duration = 3,
	})

	syncPlayer(player)
end)

_G.RewardsAddRobuxSpent = function(player, amount)
	if not player then return end
	amount = tonumber(amount) or 0
	if amount <= 0 then return end

	local data = ensureData(player)
	data.robuxSpent += amount
	saveData(player)
	syncPlayer(player)
end

AddRobuxSpent.OnServerEvent:Connect(function(player, amount)
	if type(amount) ~= "number" or amount <= 0 then return end

	local data = ensureData(player)
	data.robuxSpent += amount
	saveData(player)

	NotifyPlayer:FireClient(player, {
		title = "Thank You For Your Purchase!",
		message = "+" .. amount .. " Robux added to your total",
		kind = "robux",
		duration = 4,
	})

	syncPlayer(player)
end)

UsePowerup.OnServerEvent:Connect(function(player, powerupType)
	local data = ensureData(player)
	local map = {
		magnifier = "magnifier",
		hook = "hook",
		mystery = "mystery",
	}
	local key = map[powerupType]
	if not key then return end

	if (data.powerups[key] or 0) <= 0 then
		return
	end

	data.powerups[key] -= 1
	saveData(player)

	NotifyPlayer:FireClient(player, {
		title = "Powerup Used!",
		message = "You used 1 " .. powerupType,
		kind = "info",
		duration = 2,
	})

	syncPlayer(player)
end)

RewardRequestSync.OnServerEvent:Connect(function(player)
	syncPlayer(player)
end)

Players.PlayerAdded:Connect(function(player)
	local data = ensureData(player)

	data.totalPlaytime = 0
	data.claimed = data.claimed or {}

	for id in pairs(data.claimed) do
		if string.sub(id, 1, 3) == "pt_" then
			data.claimed[id] = nil
		end
	end

	saveData(player)

	task.spawn(function()
		while player.Parent do
			task.wait(1)
			local currentData = playerData[player.UserId]
			if not currentData then break end

			currentData.totalPlaytime += 1

			if currentData.totalPlaytime % 60 == 0 then
				saveData(player)
				syncPlayer(player)
			end
		end
	end)

	task.delay(1.5, function()
		if player.Parent then
			syncPlayer(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerData[player.UserId] = nil
end)

task.spawn(function()
	while true do
		task.wait(300)
		for _, p in ipairs(Players:GetPlayers()) do
			saveData(p)
		end
	end
end)

_G.RewardsCashMultiplier = function(player)
	return cashMultiplier(player)
end

_G.RewardsStreakMultiplier = function(player)
	return streakMultiplier(player)
end

_G.RewardsUsePowerup = function(player, powerupType)
	local data = ensureData(player)
	local map = {
		hint = "magnifier",
		reveal_country = "hook",
		reveal_letter = "mystery",
	}
	local key = map[powerupType]
	if not key or (data.powerups[key] or 0) <= 0 then
		return false
	end

	data.powerups[key] -= 1
	saveData(player)
	syncPlayer(player)
	return true
end

_G.RewardsPlayerData = function(player)
	return ensureData(player)
end

_G.RewardsSaveData = function(player)
	saveData(player)
end

_G.RewardsSyncPlayer = function(player)
	syncPlayer(player)
end

print("[RewardsService] Ready")
