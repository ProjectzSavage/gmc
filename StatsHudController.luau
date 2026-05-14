-- Expected hierarchy inside StarterGui/GameGui:
-- StatsFrame (Frame)
--   CashLbl (TextLabel)
--   WinsLbl (TextLabel)
-- Optional:
--   StreakLbl (TextLabel)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local NumberFormat = require(RS:WaitForChild("NumberFormat"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gameGui = playerGui:WaitForChild("GameGui")
local statsFrame = gameGui:WaitForChild("StatsFrame")

local CashLbl = statsFrame:WaitForChild("CashLbl")
local WinsLbl = statsFrame:WaitForChild("WinsLbl")
local StreakLbl = statsFrame:FindFirstChild("StreakLbl")

local leaderstats = player:WaitForChild("leaderstats")
local Cash = leaderstats:WaitForChild("Cash")
local Wins = leaderstats:WaitForChild("Wins")
local Winstreak = leaderstats:WaitForChild("Winstreak")

local function updateAll()
	CashLbl.Text = "$" .. NumberFormat.compact(Cash.Value)
	WinsLbl.Text = NumberFormat.compact(Wins.Value)
	if StreakLbl then
		StreakLbl.Text = "🔥" .. NumberFormat.compact(Winstreak.Value)
	end
end

Cash:GetPropertyChangedSignal("Value"):Connect(updateAll)
Wins:GetPropertyChangedSignal("Value"):Connect(updateAll)
Winstreak:GetPropertyChangedSignal("Value"):Connect(updateAll)

updateAll()
print("[StatsHudController] Ready")
