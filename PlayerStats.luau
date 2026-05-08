local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE = DataStoreService:GetDataStore("GuessMyCountry_PlayerStats_V1")

local DEFAULTS = {
	Cash = 0,
	Wins = 0,
	Winstreak = 0,
}

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
	return DEFAULTS
end

local function savePlayer(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end

	local payload = {
		Cash = (stats:FindFirstChild("Cash") and stats.Cash.Value) or 0,
		Wins = (stats:FindFirstChild("Wins") and stats.Wins.Value) or 0,
		Winstreak = (stats:FindFirstChild("Winstreak") and stats.Winstreak.Value) or 0,
	}

	local ok, err = pcall(function()
		STORE:SetAsync("player_" .. player.UserId, payload)
	end)
	if not ok then
		warn("[PlayerStats] Save failed for", player.Name, err)
	end
end

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local data = loadData(player.UserId)
	ensureInt(leaderstats, "Cash", data.Cash)
	ensureInt(leaderstats, "Wins", data.Wins)
	ensureInt(leaderstats, "Winstreak", data.Winstreak)
end)

Players.PlayerRemoving:Connect(savePlayer)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end
end)

print("[PlayerStats] Ready")