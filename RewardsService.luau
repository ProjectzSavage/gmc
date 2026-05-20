-- RewardsService
print("[Rewards] Server script starting...")

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Events = ReplicatedStorage:WaitForChild("Events")
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

print("[Rewards] DataStore + events ready")

local SOCIAL_TARGETS = {
	{
		id = 3107183806,
		title = "Follow Owner",
		rewards = "+$500, +1 Magnifier",
	},
	{
		id = 3721585498,
		title = "Follow Co-Owner",
		rewards = "+$500, +1 Hook",
	},
}

local MYSTERY_CHAIR_POOL = {
	"Cardboard","Rusty","Metal","Sand","Joker",
	"Rock","Grass","Ice","Candy",
	"Shiny","Snow","Brick","Water","Magma","Mirror",
}

local DAILY_SECONDS = 24 * 60 * 60
local FOLLOW_CACHE_TTL = 300

local playerData = {}
local followCache = {}

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

local function loadData(player)
	local ok, data = pcall(function()
		return RewardDataStore:GetAsync("player_" .. player.UserId)
	end)

	if ok and type(data) == "table" then
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
		print("[Rewards] Loaded data for", player.Name)
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

local function saveData(player)
	local data = playerData[player.UserId]
	if not data then return end
	local ok, err = pcall(function()
		RewardDataStore:SetAsync("player_" .. player.UserId, data)
	end)
	if not ok then
		warn("[Rewards] Save failed for", player.Name, err)
	end
end

local function ensureData(player)
	if not playerData[player.UserId] then
		playerData[player.UserId] = loadData(player)
	end
	return playerData[player.UserId]
end

local function hasBoolIn(container, names)
	if not container then return false end
	for _, n in ipairs(names) do
		local v = container:FindFirstChild(n)
		if v then
			if v:IsA("BoolValue") and v.Value == true then
				return true
			end
			if v:IsA("IntValue") and v.Value > 0 then
				return true
			end
		end
	end
	return false
end

local function hasPermanentCash2x(player)
	local perks = player:FindFirstChild("ShopPerks")
	local gamepasses = player:FindFirstChild("Gamepasses")
	return hasBoolIn(perks, { "DoubleCash", "TwoXCash", "Cash2x", "X2Cash" })
		or hasBoolIn(gamepasses, { "DoubleCash", "TwoXCash", "Cash2x", "X2Cash" })
end

local function hasPermanentStreak2x(player)
	local perks = player:FindFirstChild("ShopPerks")
	local gamepasses = player:FindFirstChild("Gamepasses")
	return hasBoolIn(perks, { "DoubleWinstreak", "DoubleStreak", "TwoXStreak", "Streak2x", "X2Streak" })
		or hasBoolIn(gamepasses, { "DoubleWinstreak", "DoubleStreak", "TwoXStreak", "Streak2x", "X2Streak" })
end

local function hasActive2x(player)
	local data = ensureData(player)
	local expiry = data.powerups and data.powerups.boost2xExpiry or 0
	return expiry > os.time()
end

local function cashMultiplier(player)
	if hasPermanentCash2x(player) or hasActive2x(player) then
		return 2
	end
	return 1
end

local function streakMultiplier(player)
	if hasPermanentStreak2x(player) or hasActive2x(player) then
		return 2
	end
	return 1
end

local function getBoostTimeRemaining(data)
	if not data.powerups then return 0 end
	return math.max(0, (data.powerups.boost2xExpiry or 0) - os.time())
end

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

local function giveMysteryReward(player, count)
	count = math.max(1, tonumber(count) or 1)
	local data = ensureData(player)

	if _G.ChairGrantMystery then
		local pool = {
			"Cardboard","Rusty","Metal","Sand","Joker",
			"Rock","Grass","Ice","Candy",
			"Shiny","Snow","Brick","Water","Magma","Mirror","Deer",
		}
		_G.ChairGrantMystery(player, count, pool)
		return
	end

	-- fallback direct datastore grant
	local key = "c_" .. player.UserId
	local chairData = nil
	local okLoad, loaded = pcall(function()
		return ChairStore:GetAsync(key)
	end)
	if okLoad and type(loaded) == "table" then
		chairData = loaded
	else
		chairData = { owned = {"Default"}, equipped = "Default" }
	end

	chairData.owned = chairData.owned or {"Default"}
	local ownedSet = {}
	for _, c in ipairs(chairData.owned) do
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
		table.insert(chairData.owned, pick)
		table.insert(granted, pick)
	end

	pcall(function()
		ChairStore:SetAsync(key, chairData)
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
		data.powerups.magnifier = (data.powerups.magnifier or 0) + count
	end

	if rewards:find("Hook") then
		local count = tonumber(rewards:match("%+(%d+) Hook")) or 1
		data.powerups.hook = (data.powerups.hook or 0) + count
	end

	if rewards:find("Mystery") then
		local count = tonumber(rewards:match("%+(%d+) Mystery")) or 1
		giveMysteryReward(player, count)
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
	if (data.lastDailyClaim or 0) <= 0 then
		return 0
	end
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
		data.lastDailyClaim = 0 -- new daily is ready immediately
		data.dailyDay = data.dailyDay or 1

		saveData(player)
		print("[Rewards] Daily reset for", player.Name, "(daily ready, pt_* preserved)")
	end
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
			warn("[Rewards] follow check failed:", body)
			break
		end

		local decoded
		local okDecode, errDecode = pcall(function()
			decoded = HttpService:JSONDecode(body)
		end)
		if not okDecode then
			warn("[Rewards] follow decode failed:", errDecode)
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

local function buildPayload(player, data)
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
		table.insert(categories.playtime, {
			id = row.id,
			left = row.requiredMin .. "m",
			rewards = row.rewards,
			claimed = isClaimed(data, row.id),
			ready = playMin >= row.requiredMin and not isClaimed(data, row.id),
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
		table.insert(categories.daily, {
			id = row.id,
			rewards = row.rewards,
			claimed = isClaimed(data, row.id),
			ready = data.dailyDay == idx and dailyLeft <= 0,
		})
	end

	local groupReady = false
	local ok, inGroup = pcall(function()
		return player:IsInGroup(35973544)
	end)
	if ok and inGroup then
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
		table.insert(categories.robuxspent, {
			id = row.id,
			rewards = row.rewards,
			left = row.required,
			claimed = isClaimed(data, row.id),
			ready = robuxSpent >= row.required and not isClaimed(data, row.id),
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
	checkDailyReset(player, data)
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

AddRobuxSpent.OnServerEvent:Connect(function(player, amount)
	if type(amount) ~= "number" or amount <= 0 then return end
	local data = ensureData(player)
	data.robuxSpent = (data.robuxSpent or 0) + amount
	saveData(player)

	NotifyPlayer:FireClient(player, {
		title = "Thank You For Your Purchase!",
		message = "+" .. amount .. " Robux added to your total",
		kind = "robux",
		duration = 4,
	})

	syncPlayer(player)
end)

RewardRequestSync.OnServerEvent:Connect(function(player)
	syncPlayer(player)
end)

UsePowerup.OnServerEvent:Connect(function(player, powerupType)
	local data = ensureData(player)
	if not data.powerups then return end

	local key = ({ magnifier = "magnifier", hook = "hook", mystery = "mystery" })[powerupType]
	if not key then return end
	if (data.powerups[key] or 0) <= 0 then return end

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

Players.PlayerAdded:Connect(function(player)
	local data = ensureData(player)

	-- playtime is session-based
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
			if not playerData[player.UserId] then break end
			data.totalPlaytime = (data.totalPlaytime or 0) + 1
			if data.totalPlaytime % 60 == 0 then
				saveData(player)
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

_G.GrantPowerup = function(player, powerupType, amount, durationMinutes)
	if not player then return false end
	local data = ensureData(player)
	if not data then return false end

	data.powerups = data.powerups or {}
	data.powerups.magnifier = data.powerups.magnifier or 0
	data.powerups.hook = data.powerups.hook or 0
	data.powerups.mystery = data.powerups.mystery or 0
	data.powerups.boost2x = data.powerups.boost2x or 0
	data.powerups.boost2xExpiry = data.powerups.boost2xExpiry or 0

	amount = math.max(1, tonumber(amount) or 1)

	if powerupType == "hint" or powerupType == "magnifier" then
		data.powerups.magnifier += amount
	elseif powerupType == "hook" then
		data.powerups.hook += amount
	elseif powerupType == "mystery" then
		data.powerups.mystery += amount
	elseif powerupType == "boost2x" then
		local mins = tonumber(durationMinutes) or 5
		local expiry = os.time() + (mins * 60)
		if expiry > data.powerups.boost2xExpiry then
			data.powerups.boost2xExpiry = expiry
		end
		data.powerups.boost2x = 1
	else
		return false
	end

	saveData(player)
	syncPlayer(player)
	return true
end

_G.RewardsCashMultiplier = function(player)
	return cashMultiplier(player)
end

_G.RewardsStreakMultiplier = function(player)
	return streakMultiplier(player)
end

_G.RewardsBoostTimeLeft = function(player)
	local data = ensureData(player)
	return getBoostTimeRemaining(data)
end

local POWERUP_TO_INV = {
	hint = "magnifier",
	reveal_country = "hook",
	reveal_letter = "mystery",
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

_G.RewardsAddRobuxSpent = function(player, amount)
	if not player then return end
	amount = tonumber(amount) or 0
	if amount <= 0 then return end
	local data = ensureData(player)
	data.robuxSpent = (data.robuxSpent or 0) + amount
	saveData(player)
	syncPlayer(player)
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
