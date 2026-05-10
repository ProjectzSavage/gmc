-- StarterGui/TableBillboardHandler (MULTI-TABLE, robust + snapshot init)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local done = ReplicatedFirst:FindFirstChild("LoadingFinished")
if done and done:IsA("BindableEvent") then
	done.Event:Wait()
end

local player = Players.LocalPlayer
local Events = RS:WaitForChild("Events")

local PlayerSat = Events:WaitForChild("PlayerSat")
local PlayerStood = Events:WaitForChild("PlayerStood")
local TableCountdown = Events:WaitForChild("TableCountdown")
local TableStatus = Events:WaitForChild("TableStatus")

local TablesFolder = workspace:WaitForChild("Tables")
local tableState = {}

local function hasText(obj)
	if not obj then return false end
	local ok = pcall(function() local _ = obj.Text end)
	return ok
end

local function findTextObject(root, name)
	local obj = root:FindFirstChild(name, true)
	if obj and hasText(obj) then return obj end
	return nil
end

local function setText(obj, text)
	if not obj then return end
	pcall(function() obj.Text = text end)
end

local function setVisible(obj, value)
	if not obj then return end
	pcall(function() obj.Visible = value end)
end

local function getClosestTableId()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		local first = TablesFolder:FindFirstChildWhichIsA("Model")
		return first and first.Name or nil
	end

	local bestId, bestDist = nil, math.huge
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
	local countObj = findTextObject(bg, "CountLbl")
	local winObj = findTextObject(bg, "WinLbl")
	local countdownObj = findTextObject(bg, "CountdownLbl")
	local statusObj = findTextObject(bg, "StatusLbl") or countdownObj

	tableState[model.Name] = {
		bb = bb,
		CountLbl = countObj,
		WinLbl = winObj,
		CountdownLbl = countdownObj,
		StatusLbl = statusObj,
		occupied = { A = false, B = false },
		countdownToken = 0,
	}
end

local function getCount(st)
	local c = 0
	if st.occupied.A then c += 1 end
	if st.occupied.B then c += 1 end
	return c
end

local function updateCount(tableId)
	local st = tableState[tableId]
	if not st then return end
	local count = getCount(st)

	if count >= 2 then
		setText(st.CountLbl, "2/2 Players ✅")
	else
		setText(st.CountLbl, tostring(count) .. "/2 Players")
	end
end

local function showDefault(tableId)
	local st = tableState[tableId]
	if not st then return end

	if st.bb then st.bb.Enabled = true end
	setVisible(st.CountLbl, true)
	setVisible(st.WinLbl, true)
	setVisible(st.CountdownLbl, false)
	if st.StatusLbl and st.StatusLbl ~= st.CountdownLbl then
		setVisible(st.StatusLbl, false)
	end
	updateCount(tableId)
end

local function resetTable(tableId)
	local st = tableState[tableId]
	if not st then return end
	st.countdownToken += 1
	st.occupied.A = false
	st.occupied.B = false
	showDefault(tableId)
end

local function playCountdownStep(st, text)
	if not st or not st.CountdownLbl then return end
	setText(st.CountdownLbl, text)
	pcall(function() st.CountdownLbl.TextTransparency = 0 end)

	TweenService:Create(
		st.CountdownLbl,
		TweenInfo.new(0.85, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ TextTransparency = 0.4 }
	):Play()
end

local function showCountdown(tableId, text)
	local st = tableState[tableId]
	if not st then return end
	if st.bb then st.bb.Enabled = true end
	setVisible(st.CountLbl, false)
	setVisible(st.WinLbl, false)
	if st.StatusLbl and st.StatusLbl ~= st.CountdownLbl then setVisible(st.StatusLbl, false) end
	setVisible(st.CountdownLbl, true)
	playCountdownStep(st, text)
end

local function showGoAndHide(tableId)
	local st = tableState[tableId]
	if not st then return end

	local token = st.countdownToken + 1
	st.countdownToken = token

	if st.bb then st.bb.Enabled = true end
	setVisible(st.CountdownLbl, true)
	playCountdownStep(st, "🌍 GO!")

	task.delay(0.75, function()
		local current = tableState[tableId]
		if not current or current.countdownToken ~= token then return end
		if current.bb then current.bb.Enabled = false end
		setVisible(current.CountdownLbl, false)
	end)
end

for _, model in ipairs(TablesFolder:GetChildren()) do
	if model:IsA("Model") then
		setupTable(model)
	end
end

for id in pairs(tableState) do
	resetTable(id)
end

-- Snapshot init for late join
local getSnapshot = Events:FindFirstChild("GetSeatSnapshot")
if getSnapshot and getSnapshot:IsA("RemoteFunction") then
	local ok, snap = pcall(function()
		return getSnapshot:InvokeServer()
	end)
	if ok and type(snap) == "table" then
		for tableId, count in pairs(snap.tables or {}) do
			local st = tableState[tableId]
			local n = tonumber(count) or 0
			if st then
				st.occupied.A = (n >= 1)
				st.occupied.B = (n >= 2)
				updateCount(tableId)
			end
		end
	end
end

PlayerSat.OnClientEvent:Connect(function(slot, _name, tableId)
	local tid = tableId or getClosestTableId()
	local st = tid and tableState[tid] or nil
	if not st then return end

	if slot == "A" or slot == "B" then
		st.occupied[slot] = true
	else
		local count = getCount(st)
		if count == 0 then st.occupied.A = true else st.occupied.B = true end
	end

	updateCount(tid)
end)

PlayerStood.OnClientEvent:Connect(function(slot, _name, tableId)
	local tid = tableId or getClosestTableId()
	local st = tid and tableState[tid] or nil
	if not st then return end

	if slot == "A" or slot == "B" then
		st.occupied[slot] = false
	else
		st.occupied.A = false
		st.occupied.B = false
	end

	showDefault(tid)
end)

TableCountdown.OnClientEvent:Connect(function(tableId, t)
	local st = tableState[tableId]
	if not st then return end

	local n = tonumber(t)
	if n and n > 0 then
		showCountdown(tableId, tostring(n))
	else
		showGoAndHide(tableId)
	end
end)

TableStatus.OnClientEvent:Connect(function(tableId, text)
	local st = tableState[tableId]
	if not st then return end

	local msg = tostring(text or "")
	if msg == "" then
		showDefault(tableId)
		return
	end

	if st.bb then st.bb.Enabled = true end
	setVisible(st.CountLbl, false)
	setVisible(st.WinLbl, false)
	setVisible(st.CountdownLbl, false)
	setVisible(st.StatusLbl, true)
	setText(st.StatusLbl, msg)
end)

print("[TableBillboardHandler] Ready")
