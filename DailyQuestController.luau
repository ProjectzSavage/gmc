-- DailyQuestController (robust, supports variable row count)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gameGui = player:WaitForChild("PlayerGui"):WaitForChild("GameGui")
local panel = gameGui:WaitForChild("DailyQuestsF")

local titleLbl = panel:WaitForChild("TitleLbl")

local Events = RS:WaitForChild("Events")
local DailyQuestSync = Events:WaitForChild("DailyQuestSync")
local DailyQuestClaim = Events:WaitForChild("DailyQuestClaim")

local cycleEndsAt = os.time()

-- Collect available quest rows safely (Quest1..Quest6)
local rows = {}
for i = 1, 6 do
	local row = panel:FindFirstChild("Quest" .. i)
	if row and row:IsA("Frame") then
		table.insert(rows, row)
	end
end

if #rows == 0 then
	warn("[DailyQuestController] No quest rows found (Quest1, Quest2, ...)")
	return
end

local function formatTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60)
end

local function updateRow(row, q)
	local desc = row:FindFirstChild("DescLbl")
	local prog = row:FindFirstChild("ProgressLbl")
	local reward = row:FindFirstChild("RewardLbl")
	local btn = row:FindFirstChild("ClaimBtn")

	if desc and desc:IsA("TextLabel") then
		desc.Text = tostring(q.title or "Quest")
	end
	if prog and prog:IsA("TextLabel") then
		prog.Text = tostring(q.progress or 0) .. "/" .. tostring(q.required or 1)
	end
	if reward and reward:IsA("TextLabel") then
		reward.Text = "+$" .. tostring(q.reward or 0)
	end

	if not (btn and btn:IsA("TextButton")) then return end

	btn.Active = q.claimable == true
	row:SetAttribute("QuestId", q.id)

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

	-- Wire once; read QuestId dynamically so updates stay correct.
	if not row:GetAttribute("Wired") then
		btn.MouseButton1Click:Connect(function()
			if btn.Text ~= "CLAIM" then return end
			local questId = row:GetAttribute("QuestId")
			if type(questId) ~= "string" or questId == "" then return end
			btn.Text = "..."
			DailyQuestClaim:FireServer(questId)
		end)
		row:SetAttribute("Wired", true)
	end
end

DailyQuestSync.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	cycleEndsAt = tonumber(payload.cycleEndsAt) or os.time()

	local quests = payload.quests
	if type(quests) ~= "table" then return end

	for i, row in ipairs(rows) do
		local q = quests[i]
		row.Visible = q ~= nil
		if q then
			updateRow(row, q)
		end
	end
end)

task.spawn(function()
	while true do
		local left = (tonumber(cycleEndsAt) or os.time()) - os.time()
		titleLbl.Text = "Daily Quests (" .. formatTime(left) .. ")"
		task.wait(1)
	end
end)
