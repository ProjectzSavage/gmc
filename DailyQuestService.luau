-- DailyQuestService
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Events = RS:WaitForChild("Events")

local DailyQuestSync = Events:FindFirstChild("DailyQuestSync") or Instance.new("RemoteEvent", Events)
DailyQuestSync.Name = "DailyQuestSync"
local DailyQuestClaim = Events:FindFirstChild("DailyQuestClaim") or Instance.new("RemoteEvent", Events)
DailyQuestClaim.Name = "DailyQuestClaim"
local NotifyPlayer = Events:WaitForChild("NotifyPlayer")

local CYCLE_SECONDS = 7 * 60 * 60
local states = {}

local QUESTS = {
	{ id = "win_1", title = "Win a game", required = 1, reward = 700, 
		getProgress = function(stats, state) return state.sessionWins or 0 end },
	{ id = "streak_3", title = "Win 3 games in a row", required = 3, reward = 500, 
		getProgress = function(stats) 
			local ws = stats and stats:FindFirstChild("Winstreak")
			return ws and ws.Value or 0 
		end },
}

local function currentCycleStart()
	local now = os.time()
	return now - (now % CYCLE_SECONDS)
end

local function ensureState(player)
	if states[player.UserId] then return states[player.UserId] end
	local stats = player:FindFirstChild("leaderstats")
	local wins = stats and stats:FindFirstChild("Wins")

	states[player.UserId] = {
		cycleStart = currentCycleStart(),
		lastWins = wins and wins.Value or 0,
		sessionWins = 0,
		claimed = {}, -- Dynamic
	}
	return states[player.UserId]
end

local function rolloverIfNeeded(player, st)
	local c = currentCycleStart()
	if st.cycleStart == c then return end

	local stats = player:FindFirstChild("leaderstats")
	local wins = stats and stats:FindFirstChild("Wins")
	st.cycleStart = c
	st.lastWins = wins and wins.Value or 0
	st.sessionWins = 0
	st.claimed = {} 
end

local function buildPayload(player)
	local st = ensureState(player)
	rolloverIfNeeded(player, st)
	local stats = player:FindFirstChild("leaderstats")
	local quests = {}

	for _, q in ipairs(QUESTS) do
		local progress = math.clamp(q.getProgress(stats, st), 0, q.required)
		local isClaimed = st.claimed[q.id] == true
		table.insert(quests, {
			id = q.id,
			title = q.title,
			progress = progress,
			required = q.required,
			reward = q.reward,
			claimable = (progress >= q.required) and not isClaimed,
			claimed = isClaimed,
		})
	end
	return { cycleEndsAt = st.cycleStart + CYCLE_SECONDS, quests = quests }
end

local function syncPlayer(player)
	DailyQuestSync:FireClient(player, buildPayload(player))
end

DailyQuestClaim.OnServerEvent:Connect(function(player, questId)
	local st = ensureState(player)
	rolloverIfNeeded(player, st)

	-- Find the quest in the config
	local questConfig
	for _, q in ipairs(QUESTS) do if q.id == questId then questConfig = q break end end
	if not questConfig or st.claimed[questId] then return end

	-- Re-check progress server-side for security
	local stats = player:FindFirstChild("leaderstats")
	local progress = questConfig.getProgress(stats, st)

	if progress >= questConfig.required then
		st.claimed[questId] = true
		local cash = stats and stats:FindFirstChild("Cash")
		if cash then cash.Value += questConfig.reward end

		NotifyPlayer:FireClient(player, {
			title = "Quest Complete!",
			message = questConfig.title .. " — +$" .. questConfig.reward,
			kind = "success"
		})
		syncPlayer(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	local stats = player:WaitForChild("leaderstats", 20)
	local st = ensureState(player)

	local wins = stats and stats:WaitForChild("Wins", 10)
	if wins then
		wins.Changed:Connect(function(val)
			if val > st.lastWins then
				st.sessionWins += (val - st.lastWins)
			end
			st.lastWins = val
			syncPlayer(player)
		end)
	end

	syncPlayer(player)
end)

-- Background Refresh
task.spawn(function()
	while true do
		for _, p in ipairs(Players:GetPlayers()) do syncPlayer(p) end
		task.wait(30)
	end
end)