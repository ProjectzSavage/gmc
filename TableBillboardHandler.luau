-- ============================================================
-- LocalScript: StarterGui/TableBillboardHandler (MULTI-TABLE)
-- Supports:
-- - count text (0/2, 2/2 ✅)
-- - countdown tween
-- - GO then hide billboard
-- - reset on stand
-- - tableId-aware events
-- ============================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Events = RS:WaitForChild("Events")

local PlayerSat = Events:WaitForChild("PlayerSat")
local PlayerStood = Events:WaitForChild("PlayerStood")
local TableCountdown = Events:WaitForChild("TableCountdown")
local TableStatus = Events:WaitForChild("TableStatus")

local TablesFolder = workspace:WaitForChild("Tables")

local tableState = {}

local function findLabel(root, name)
	local obj = root:FindFirstChild(name, true)
	if obj and obj:IsA("TextLabel") then
		return obj
	end
	return nil
end

local function getClosestTableId()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		local first = TablesFolder:FindFirstChildWhichIsA("Model")
		return first and first.Name or nil
	end

	local bestId = nil
	local bestDist = math.huge
	for _, model in ipairs(TablesFolder:GetChildren()) do
		if model:IsA("Model") then
			local top = model:FindFirstChild("TableTop")
			if top and top:IsA("BasePart") then
				local d = (top.Position - hrp.Position).Magnitude
				if d < bestDist then
					bestDist = d
					bestId = model.Name
				end
			end
		end
	end
	return bestId
end

local function setupTable(model)
	local top = model:FindFirstChild("TableTop")
	if not top then return end

	local bb = top:FindFirstChild("TableBillboard") or top:FindFirstChildWhichIsA("BillboardGui")
	if not bb then return end

	local bg = bb:FindFirstChild("BG") or bb
	local countLbl = findLabel(bg, "CountLbl")
	local winLbl = findLabel(bg, "WinLbl")
	local countdownLbl = findLabel(bg, "CountdownLbl")
	local statusLbl = findLabel(bg, "StatusLbl") or countdownLbl

	tableState[model.Name] = {
		bb = bb,
		bg = bg,
		CountLbl = countLbl,
		WinLbl = winLbl,
		CountdownLbl = countdownLbl,
		StatusLbl = statusLbl,
		playerCount = 0,
		countdownToken = 0,
	}
end

local function updateCount(tid)
	local st = tableState[tid]
	if not st or not st.CountLbl then return end

	if st.playerCount >= 2 then
		st.CountLbl.Text = "2/2 Players ✅"
	else
		st.CountLbl.Text = tostring(st.playerCount) .. "/2 Players"
	end
end

local function resetBillboard(tid)
	local st = tableState[tid]
	if not st then return end

	st.countdownToken += 1
	st.playerCount = 0

	if st.bb then st.bb.Enabled = true end
	if st.CountLbl then st.CountLbl.Visible = true end
	if st.WinLbl then st.WinLbl.Visible = true end
	if st.CountdownLbl then st.CountdownLbl.Visible = false end
	if st.StatusLbl and st.StatusLbl ~= st.CountdownLbl then st.StatusLbl.Visible = false end

	updateCount(tid)
end

local function showDefaultWithoutReset(tid)
	local st = tableState[tid]
	if not st then return end

	if st.bb then st.bb.Enabled = true end
	if st.CountLbl then st.CountLbl.Visible = true end
	if st.WinLbl then st.WinLbl.Visible = true end
	if st.CountdownLbl then st.CountdownLbl.Visible = false end
	if st.StatusLbl and st.StatusLbl ~= st.CountdownLbl then st.StatusLbl.Visible = false end

	updateCount(tid)
end

local function playCountdownStep(tid, text)
	local st = tableState[tid]
	if not st or not st.CountdownLbl then return end

	st.CountdownLbl.Text = text
	st.CountdownLbl.TextTransparency = 0

	TweenService:Create(
		st.CountdownLbl,
		TweenInfo.new(0.85, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ TextTransparency = 0.4 }
	):Play()
end

local function showCountdown(tid, numberText)
	local st = tableState[tid]
	if not st then return end

	if st.bb then st.bb.Enabled = true end
	if st.CountLbl then st.CountLbl.Visible = false end
	if st.WinLbl then st.WinLbl.Visible = false end
	if st.StatusLbl and st.StatusLbl ~= st.CountdownLbl then st.StatusLbl.Visible = false end
	if st.CountdownLbl then
		st.CountdownLbl.Visible = true
		playCountdownStep(tid, numberText)
	end
end

local function showGoAndHide(tid)
	local st = tableState[tid]
	if not st then return end
	local token = st.countdownToken + 1
	st.countdownToken = token

	if st.bb then st.bb.Enabled = true end
	if st.CountdownLbl then
		st.CountdownLbl.Visible = true
		playCountdownStep(tid, "🌍 GO!")
	end

	task.delay(0.75, function()
		local current = tableState[tid]
		if not current or current.countdownToken ~= token then return end
		if current.bb then current.bb.Enabled = false end
		if current.CountdownLbl then current.CountdownLbl.Visible = false end
	end)
end

for _, model in ipairs(TablesFolder:GetChildren()) do
	if model:IsA("Model") then
		setupTable(model)
	end
end

for tid, _ in pairs(tableState) do
	resetBillboard(tid)
end

PlayerSat.OnClientEvent:Connect(function(_slot, _name, tableId)
	local tid = tableId or getClosestTableId()
	if not tid then return end
	local st = tableState[tid]
	if not st then return end

	st.playerCount = math.min(st.playerCount + 1, 2)
	updateCount(tid)
end)

PlayerStood.OnClientEvent:Connect(function(_slot, _name, tableId)
	local tid = tableId or getClosestTableId()
	if not tid then return end
	resetBillboard(tid)
end)

-- Preferred countdown path from server.
TableCountdown.OnClientEvent:Connect(function(tableId, t)
	local st = tableState[tableId]
	if not st then return end

	if t and t > 0 then
		showCountdown(tableId, tostring(t))
	else
		showGoAndHide(tableId)
	end
end)

TableStatus.OnClientEvent:Connect(function(tableId, text)
	local st = tableState[tableId]
	if not st then return end

	local msg = tostring(text or "")
	if msg == "" then
		showDefaultWithoutReset(tableId)
		return
	end

	if st.bb then st.bb.Enabled = true end
	if st.CountLbl then st.CountLbl.Visible = false end
	if st.WinLbl then st.WinLbl.Visible = false end
	if st.CountdownLbl then st.CountdownLbl.Visible = false end
	if st.StatusLbl then
		st.StatusLbl.Visible = true
		st.StatusLbl.Text = msg
	end
end)

print("[TableBillboard] Multi-table Ready")
