-- DailyQuestService (persistent + friend quests)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Events = RS:WaitForChild("Events")

local DailyQuestSync = Events:FindFirstChild("DailyQuestSync") or Instance.new("RemoteEvent")
DailyQuestSync.Name = "DailyQuestSync"
DailyQuestSync.Parent = Events

local DailyQuestClaim = Events:FindFirstChild("DailyQuestClaim") or Instance.new("RemoteEvent")
DailyQuestClaim.Name = "DailyQuestClaim"
DailyQuestClaim.Parent = Events

local NotifyPlayer = Events:WaitForChild("NotifyPlayer")

local STORE = DataStoreService:GetDataStore("DailyQuestData_V2")
local CYCLE_SECONDS = 7 * 60 * 60 -- 7h cycle  (keep your original value)

local states = {}

local QUESTS = {
	{
		id = "win_1",
		title = "Win a game",
		required = 1,
		reward = 700,
		getProgress = function(stats, st)
			local wins = stats and stats:FindFirstChild("Wins")
			local currentWins = (wins and wins.Value) or 0
			return math.max(0, currentWins - (st.winsAtCycleStart or 0))
		end,
	},
	{
		id = "streak_3",
		title = "Win 3 games in a row",
		required = 3,
		reward = 500,
		getProgress = function(stats)
			local ws = stats and stats:FindFirstChild("Winstreak")
			return (ws and ws.Value) or 0
		end,
	},
	{
		id = "play_friend",
		title = "Play with a friend",
		required = 1,
		reward = 400,
		getProgress = function(_stats, st)
			return st.playedWithFriend and 1 or 0
		end,
	},
	{
		id = "win_friend",
		title = "Win a friend",
		required = 1,
		reward = 600,
		getProgress = function(_stats, st)
			return st.wonWithFriend and 1 or 0
		end,
	},
}

local function currentCycleStart()
	local now = os.time()
	return now - (now % CYCLE_SECONDS)
end

local function saveState(player)
	local st = states[player.UserId]
	if not st then return end

	local payload = {
		cycleStart = st.cycleStart,
		claimed = st.claimed,
		winsAtCycleStart = st.winsAtCycleStart or 0,
		playedWithFriend = st.playedWithFriend == true,
		wonWithFriend = st.wonWithFriend == true,
	}

	pcall(function()
		STORE:SetAsync("dq_" .. player.UserId, payload)
	end)
end

local function loadState(player)
	local stats = player:FindFirstChild("leaderstats")
	local wins = stats and stats:FindFirstChild("Wins")
	local currentWins = (wins and wins.Value) or 0

	local st = {
		cycleStart = currentCycleStart(),
		claimed = {},
		winsAtCycleStart = currentWins,
		playedWithFriend = false,
		wonWithFriend = false,
	}

	local ok, data = pcall(function()
		return STORE:GetAsync("dq_" .. player.UserId)
	end)

	if ok and type(data) == "table" then
		st.cycleStart = tonumber(data.cycleStart) or st.cycleStart
		st.claimed = (type(data.claimed) == "table") and data.claimed or {}
		st.winsAtCycleStart = tonumber(data.winsAtCycleStart) or currentWins
		st.playedWithFriend = data.playedWithFriend == true
		st.wonWithFriend = data.wonWithFriend == true
	end

	return st
end

local function rolloverIfNeeded(player, st)
	local c = currentCycleStart()
	if st.cycleStart == c then return false end

	local stats = player:FindFirstChild("leaderstats")
	local wins = stats and stats:FindFirstChild("Wins")
	local currentWins = (wins and wins.Value) or 0

	st.cycleStart = c
	st.claimed = {}
	st.winsAtCycleStart = currentWins
	st.playedWithFriend = false
	st.wonWithFriend = false
	return true
end

local function buildPayload(player)
	local st = states[player.UserId]
	if not st then return nil end

	local changed = rolloverIfNeeded(player, st)
	if changed then
		saveState(player)
	end

	local stats = player:FindFirstChild("leaderstats")
	local quests = {}

	for _, q in ipairs(QUESTS) do
		local progress = math.clamp(tonumber(q.getProgress(stats, st)) or 0, 0, q.required)
		local claimed = st.claimed[q.id] == true

		table.insert(quests, {
			id = q.id,
			title = q.title,
			progress = progress,
			required = q.required,
			reward = q.reward,
			claimable = (progress >= q.required) and not claimed,
			claimed = claimed,
		})
	end

	return {
		cycleEndsAt = st.cycleStart + CYCLE_SECONDS,
		quests = quests,
	}
end

local function syncPlayer(player)
	local payload = buildPayload(player)
	if payload then
		DailyQuestSync:FireClient(player, payload)
	end
end

local function markPlayedWithFriend(player)
	if not player then return end
	local st = states[player.UserId]
	if not st then return end
	if rolloverIfNeeded(player, st) then
		-- rollover already handled; continue
	end
	if not st.playedWithFriend then
		st.playedWithFriend = true
		saveState(player)
		syncPlayer(player)
	end
end

local function markWonWithFriend(player)
	if not player then return end
	local st = states[player.UserId]
	if not st then return end
	if rolloverIfNeeded(player, st) then
		-- rollover already handled; continue
	end
	if not st.wonWithFriend then
		st.wonWithFriend = true
		saveState(player)
		syncPlayer(player)
	end
end

DailyQuestClaim.OnServerEvent:Connect(function(player, questId)
	local st = states[player.UserId]
	if not st then return end
	rolloverIfNeeded(player, st)

	local qcfg = nil
	for _, q in ipairs(QUESTS) do
		if q.id == questId then
			qcfg = q
			break
		end
	end
	if not qcfg then return end
	if st.claimed[questId] then return end

	local stats = player:FindFirstChild("leaderstats")
	local progress = tonumber(qcfg.getProgress(stats, st)) or 0
	if progress < qcfg.required then return end

	st.claimed[questId] = true

	local cash = stats and stats:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		cash.Value += qcfg.reward
	end

	saveState(player)
	syncPlayer(player)

	NotifyPlayer:FireClient(player, {
		title = "Quest Complete!",
		message = qcfg.title .. " +$" .. tostring(qcfg.reward),
		kind = "success",
		duration = 3,
	})
end)

Players.PlayerAdded:Connect(function(player)
	player:WaitForChild("leaderstats", 20)
	states[player.UserId] = loadState(player)

	local stats = player:FindFirstChild("leaderstats")
	local wins = stats and stats:FindFirstChild("Wins")
	local ws = stats and stats:FindFirstChild("Winstreak")

	if wins then
		wins.Changed:Connect(function()
			syncPlayer(player)
			saveState(player)
		end)
	end

	if ws then
		ws.Changed:Connect(function()
			-- Needed so streak quest instantly reflects 0/3 after a loss.
			syncPlayer(player)
			saveState(player)
		end)
	end

	syncPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	saveState(player)
	states[player.UserId] = nil
end)

-- Hooks called from GameManager
_G.DailyQuestMarkPlayedWithFriend = function(playerA, playerB)
	markPlayedWithFriend(playerA)
	markPlayedWithFriend(playerB)
end

_G.DailyQuestMarkWinWithFriend = function(winner, _loser)
	markWonWithFriend(winner)
end

task.spawn(function()
	while true do
		for _, p in ipairs(Players:GetPlayers()) do
			syncPlayer(p)
		end
		task.wait(30)
	end
end)

print("[DailyQuestService] Ready")
