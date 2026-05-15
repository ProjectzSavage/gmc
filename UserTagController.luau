-- UserTagController - v2026-04-18
-- Hides user tags (name/streak) during game, shows after game

local Players = game:GetService("Players")

local playerInGame = {}

local function setTagVisibility(player, visible)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end

	-- Find and toggle UserTag gui (adjust name as needed)
	local userTag = playerGui:FindFirstChild("UserTag") or playerGui:FindFirstChild("NameTag")
	if userTag and userTag:IsA("ScreenGui") then
		userTag.Enabled = visible
	end
end

Players.PlayerAdded:Connect(function(player)
	playerInGame[player.UserId] = false
end)

Players.PlayerRemoving:Connect(function(player)
	playerInGame[player.UserId] = nil
end)

-- Function to call when game starts
local function onGameStart(player)
	playerInGame[player.UserId] = true
	setTagVisibility(player, false) -- Hide tags
end

-- Function to call when game ends
local function onGameEnd(player)
	playerInGame[player.UserId] = false
	setTagVisibility(player, true) -- Show tags
end

-- Export functions for other scripts to use
_G.UserTagController = {
	onGameStart = onGameStart,
	onGameEnd = onGameEnd,
}

print("[UserTagController] Ready")
