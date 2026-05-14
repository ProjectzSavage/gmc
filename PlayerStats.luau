local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE = DataStoreService:GetDataStore("GuessMyCountry_PlayerStats_V1")
local CASH_ORDERED = DataStoreService:GetOrderedDataStore("GuessMyCountry_LB_Cash_V1")
local WINS_ORDERED = DataStoreService:GetOrderedDataStore("GuessMyCountry_LB_Wins_V1")
local STREAK_ORDERED = DataStoreService:GetOrderedDataStore("GuessMyCountry_LB_Streak_V1")

local DEFAULTS = {
	Cash = 0,
	Wins = 0,
	Winstreak = 0,
}

local saveDebounce = {}
local orderedDebounce = {}

local function ensureInt(parent, name, value)
	local v = parent:FindFirstChild(name)
	if not v then
		v = Instance.new("IntValue")
		v.Name = name
		v.Parent = parent
	end
	v.Value = value
	return v
end

local function loadData(userId)
	local ok, data = pcall(function()
		return STORE:GetAsync("player_" .. userId)
	end)
	if ok and type(data) == "table" then
		return {
			Cash = tonumber(data.Cash) or DEFAULTS.Cash,
			Wins = tonumber(data.Wins) or DEFAULTS.Wins,
			Winstreak = tonumber(data.Winstreak) or DEFAULTS.Winstreak,
		}
	end
	return {
		Cash = DEFAULTS.Cash,
		Wins = DEFAULTS.Wins,
		Winstreak = DEFAULTS.Winstreak,
	}
end

local function getPayload(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return nil end
	return {
		Cash = (stats:FindFirstChild("Cash") and stats.Cash.Value) or 0,
		Wins = (stats:FindFirstChild("Wins") and stats.Wins.Value) or 0,
		Winstreak = (stats:FindFirstChild("Winstreak") and stats.Winstreak.Value) or 0,
	}
end

local function pushOrderedNow(userId, payload)
	local key = tostring(userId)
	pcall(function() CASH_ORDERED:SetAsync(key, payload.Cash) end)
	pcall(function() WINS_ORDERED:SetAsync(key, payload.Wins) end)
	pcall(function() STREAK_ORDERED:SetAsync(key, payload.Winstreak) end)
end

local function queueOrdered(player)
	if orderedDebounce[player.UserId] then return end
	orderedDebounce[player.UserId] = true
	task.delay(2, function()
		orderedDebounce[player.UserId] = nil
		if not player.Parent then return end
		local payload = getPayload(player)
		if payload then
			pushOrderedNow(player.UserId, payload)
		end
	end)
end

local function saveNow(player)
	local payload = getPayload(player)
	if not payload then return end

	local ok, err = pcall(function()
		STORE:SetAsync("player_" .. player.UserId, payload)
	end)
	if not ok then
		warn("[PlayerStats] Save failed for", player.Name, err)
	end
end

local function queueSave(player)
	if saveDebounce[player.UserId] then return end
	saveDebounce[player.UserId] = true
	task.delay(5, function()
		saveDebounce[player.UserId] = nil
		if player.Parent then
			saveNow(player)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local data = loadData(player.UserId)
	local cash = ensureInt(leaderstats, "Cash", data.Cash)
	local wins = ensureInt(leaderstats, "Wins", data.Wins)
	local streak = ensureInt(leaderstats, "Winstreak", data.Winstreak)

	local function onStatChanged()
		queueOrdered(player)
		queueSave(player)
	end

	cash:GetPropertyChangedSignal("Value"):Connect(onStatChanged)
	wins:GetPropertyChangedSignal("Value"):Connect(onStatChanged)
	streak:GetPropertyChangedSignal("Value"):Connect(onStatChanged)

	pushOrderedNow(player.UserId, data)
end)

Players.PlayerRemoving:Connect(function(player)
	saveDebounce[player.UserId] = nil
	orderedDebounce[player.UserId] = nil

	local payload = getPayload(player)
	if payload then
		pushOrderedNow(player.UserId, payload)
	end
	saveNow(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local payload = getPayload(player)
		if payload then
			pushOrderedNow(player.UserId, payload)
		end
		saveNow(player)
	end
end)

print("[PlayerStats] Ready")
