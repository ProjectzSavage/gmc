-- DailyQuestController
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gameGui = player:WaitForChild("PlayerGui"):WaitForChild("GameGui")
local panel = gameGui:WaitForChild("DailyQuestsF")

local titleLbl = panel:WaitForChild("TitleLbl")
local row1 = panel:WaitForChild("Quest1")
local row2 = panel:WaitForChild("Quest2")

local Events = RS:WaitForChild("Events")
local DailyQuestSync = Events:WaitForChild("DailyQuestSync")
local DailyQuestClaim = Events:WaitForChild("DailyQuestClaim")

local cycleEndsAt = os.time()
local rows = { row1, row2 }

local function formatTime(sec)
	sec = math.max(0, sec)
	return string.format("%02d:%02d:%02d", math.floor(sec/3600), math.floor((sec%3600)/60), sec%60)
end

local function updateRow(row, q)
	row.DescLbl.Text = q.title
	row.ProgressLbl.Text = q.progress .. "/" .. q.required
	row.RewardLbl.Text = "+$" .. q.reward

	local btn = row.ClaimBtn
	btn.Active = q.claimable

	if q.claimed then
		btn.Text = "CLAIMED"
		btn.BackgroundColor3 = Color3.fromRGB(40, 190, 70)
	elseif q.claimable then
		btn.Text = "CLAIM"
		btn.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
	else
		btn.Text = "LOCKED"
		btn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
	end

	-- One-time wiring
	if not row:GetAttribute("Wired") then
		btn.MouseButton1Click:Connect(function()
			if btn.Text == "CLAIM" then
				DailyQuestClaim:FireServer(q.id)
				btn.Text = "..."
			end
		end)
		row:SetAttribute("Wired", true)
	end
end

DailyQuestSync.OnClientEvent:Connect(function(payload)
	cycleEndsAt = payload.cycleEndsAt
	for i, q in ipairs(payload.quests) do
		if rows[i] then updateRow(rows[i], q) end
	end
end)

task.spawn(function()
	while true do
		local left = cycleEndsAt - os.time()
		titleLbl.Text = "Daily Quests (" .. formatTime(left) .. ")"
		task.wait(1)
	end
end)