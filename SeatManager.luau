-- SeatManager v2.1 (multi-table, hardened for live)
local DEBUG = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local function dprint(...)
	if DEBUG then
		print("[SeatManager]", ...)
	end
end

local function dwarn(...)
	warn("[SeatManager]", ...)
end

local events = ReplicatedStorage:FindFirstChild("Events")
if not events then
	events = Instance.new("Folder")
	events.Name = "Events"
	events.Parent = ReplicatedStorage
end

local function ensureEvent(name)
	local ev = events:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then return ev end
	if ev then ev:Destroy() end
	ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = events
	return ev
end

local function ensureFunction(name)
	local fn = events:FindFirstChild(name)
	if fn and fn:IsA("RemoteFunction") then return fn end
	if fn then fn:Destroy() end
	fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = events
	return fn
end

for _, name in ipairs({
	"PlayerSat", "PlayerStood",
	"RequestSit", "RequestStand",
	"TableCountdown", "TableStatus",
	"SetHeadTagsVisible",
	"ShowLetterPick", "LetterChosen",
	"ShowCountryPick", "CountryChosen",
	"ShowLetterGuess", "SubmitLetterGuess", "LetterGuessResult",
	"ShowCountryGuess", "SubmitCountryGuess", "CountryGuessResult",
	"ShowWait", "ShowBillboard", "TimerTick", "GameOver", "ResetAll",
}) do
	ensureEvent(name)
end

local GetMySeatState = ensureFunction("GetMySeatState")
local PlayerSat = events:WaitForChild("PlayerSat")
local PlayerStood = events:WaitForChild("PlayerStood")
local RequestSit = events:WaitForChild("RequestSit")
local RequestStand = events:WaitForChild("RequestStand")

local tablesFolder = workspace:WaitForChild("Tables")

local ACTION_COOLDOWN = 0.18
local READY_WAIT_SECONDS = 8

local joinAt = {}
local lastActionAt = {}

local tables = {}
local playerToSeat = {}

local function canAct(player)
	local now = os.clock()
	local prev = lastActionAt[player.UserId] or 0
	if now - prev < ACTION_COOLDOWN then
		dprint("Action cooldown block:", player.Name, string.format("%.2f", now - prev))
		return false
	end
	lastActionAt[player.UserId] = now
	return true
end

local function isClientReadyOrGrace(player)
	if not _G.IsClientReady then
		return true
	end

	local deadline = os.clock() + READY_WAIT_SECONDS
	while os.clock() < deadline do
		if _G.IsClientReady(player) then
			return true
		end
		task.wait(0.15)
	end

	-- Fail-open for live stability.
	warn("[SeatManager] Ready timeout fallback allow:", player.Name)
	return true
end

local function restoreMovement(h, hrp)
	if h then
		h.AutoRotate = true
		h.PlatformStand = false
		h:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		h:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		h:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		h.WalkSpeed = 21
		h.JumpPower = 50
		h.JumpHeight = 7.2
		h.Sit = false
	end
	if hrp then
		hrp.Anchored = false
	end
end

local function lockSeated(h, hrp, seatPart)
	if not h or not hrp then return end
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = seatPart.CFrame * CFrame.new(0, seatPart.Size.Y / 2 + 2.05, 0)
	hrp.Anchored = true
	h.AutoRotate = false
	h.PlatformStand = false
	h.WalkSpeed = 0
	h.Sit = true
	h:ChangeState(Enum.HumanoidStateType.Seated)
end

local function getSeatRecord(player)
	return playerToSeat[player.UserId]
end

local function applyPromptState(tableState)
	if not tableState or not tableState.sitPrompt then return end
	tableState.sitPrompt.Enabled = (tableState.promptsEnabled == true) and (tableState.locked ~= true)
end

local function standPlayer(player, force)
	local rec = getSeatRecord(player)
	if not rec then return false end

	local tableState = tables[rec.tableId]
	if not tableState then
		playerToSeat[player.UserId] = nil
		return false
	end

	if tableState.locked and not force then
		local session = _G.GetSessionByPlayer and _G.GetSessionByPlayer(player) or nil
		if session and session.started then
			dprint("Stand blocked (live round):", player.Name, rec.tableId, rec.slot)
			return false
		end
		tableState.locked = false
	end

	local seatState = tableState.seats[rec.slot]
	if not seatState or seatState.player ~= player then
		playerToSeat[player.UserId] = nil
		return false
	end

	local char = player.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")

	restoreMovement(h, hrp)
	if hrp then
		hrp.CFrame = seatState.part.CFrame * CFrame.new(0, 4, 5)
	end

	if seatState.deadConn then
		seatState.deadConn:Disconnect()
		seatState.deadConn = nil
	end

	seatState.player = nil
	playerToSeat[player.UserId] = nil

	PlayerStood:FireAllClients(rec.slot, player.Name, rec.tableId)

	if _G.OnPlayerStood then
		_G.OnPlayerStood(player, rec.tableId, rec.slot)
	end

	-- If table is not full anymore, unlock and restore prompt.
	local a = tableState.seats.A.player
	local b = tableState.seats.B.player
	if not a or not b then
		tableState.locked = false
		tableState.promptsEnabled = true
		applyPromptState(tableState)
	end

	dprint("Player stood:", player.Name, rec.tableId, rec.slot, "force:", force)
	return true
end

GetMySeatState.OnServerInvoke = function(player)
	local rec = getSeatRecord(player)
	if not rec then
		return { seated = false }
	end

	local tableState = tables[rec.tableId]
	if not tableState then
		return { seated = false }
	end

	return {
		seated = true,
		tableId = rec.tableId,
		slot = rec.slot,
		seatAName = tableState.seats.A.player and tableState.seats.A.player.Name or nil,
		seatBName = tableState.seats.B.player and tableState.seats.B.player.Name or nil,
	}
end

local function trySeatPlayerAtTable(player, tableId, preferredSlot)
	if getSeatRecord(player) then
		dprint("Seat blocked: already seated:", player.Name)
		return false
	end

	local function isClientReadyOrGrace(player)
		if _G.IsClientReady and _G.IsClientReady(player) then
			return true
		end
		-- one short grace tick only
		task.wait(0.05)
		return true
	end

	local tableState = tables[tableId]
	if not tableState then
		dprint("Seat blocked: invalid table:", tostring(tableId))
		return false
	end

	if not tableState.promptsEnabled then
		dprint("Seat blocked: prompts disabled:", tableId)
		return false
	end

	local char = player.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not h or not hrp then
		dprint("Seat blocked: missing humanoid/root:", player.Name)
		return false
	end

	local slotOrder = preferredSlot and { preferredSlot, preferredSlot == "A" and "B" or "A" } or { "A", "B" }
	local chosenSlot
	for _, slot in ipairs(slotOrder) do
		if tableState.seats[slot] and not tableState.seats[slot].player then
			chosenSlot = slot
			break
		end
	end
	if not chosenSlot then
		dprint("Seat blocked: no free slot:", tableId)
		return false
	end

	local seatState = tableState.seats[chosenSlot]
	lockSeated(h, hrp, seatState.part)

	seatState.player = player
	playerToSeat[player.UserId] = {
		tableId = tableId,
		slot = chosenSlot,
	}

	if seatState.deadConn then
		seatState.deadConn:Disconnect()
	end
	seatState.deadConn = h.Died:Connect(function()
		if seatState.player == player then
			standPlayer(player, true)
		end
	end)

	PlayerSat:FireAllClients(chosenSlot, player.Name, tableId)
	dprint("Player sat:", player.Name, tableId, chosenSlot)

	local playerA = tableState.seats.A.player
	local playerB = tableState.seats.B.player
	if playerA and playerB then
		tableState.token += 1
		local token = tableState.token
		task.delay(0.2, function()
			local a2 = tableState.seats.A.player
			local b2 = tableState.seats.B.player
			if tableState.token ~= token then return end
			if not (a2 and b2) then return end

			if _G.OnBothSeated then
				_G.OnBothSeated(tableId, a2, b2)
				dprint("OnBothSeated fired:", tableId, a2.Name, b2.Name)
			else
				dwarn("_G.OnBothSeated missing for table:", tableId)
			end
		end)
	end

	return true
end

local function closestAvailableTable(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local bestId
	local bestDist = math.huge

	for tableId, tableState in pairs(tables) do
		if tableState.promptsEnabled and (not tableState.seats.A.player or not tableState.seats.B.player) then
			local dist = (tableState.tableTop.Position - hrp.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestId = tableId
			end
		end
	end

	return bestId
end

local function addTable(model)
	local seatA = model:FindFirstChild("SeatA")
	local seatB = model:FindFirstChild("SeatB")
	local tableTop = model:FindFirstChild("TableTop")
	if not (seatA and seatB and tableTop) then
		dwarn("Missing SeatA/SeatB/TableTop on", model:GetFullName())
		return
	end

	seatA.Anchored = true
	seatB.Anchored = true

	local tableId = model.Name
	local tableState = {
		id = tableId,
		model = model,
		tableTop = tableTop,
		token = 0,
		promptsEnabled = true,
		locked = false,
		sitPrompt = nil,
		seats = {
			A = { part = seatA, player = nil, deadConn = nil },
			B = { part = seatB, player = nil, deadConn = nil },
		},
	}
	tables[tableId] = tableState

	for _, child in ipairs(tableTop:GetChildren()) do
		if child:IsA("ProximityPrompt") and child.Name == "SitPrompt" then
			child:Destroy()
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SitPrompt"
	prompt.ActionText = "Sit"
	prompt.ObjectText = "Guess My Country"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = tableTop
	tableState.sitPrompt = prompt
	applyPromptState(tableState)

	prompt.Triggered:Connect(function(player)
		dprint("Prompt triggered:", player.Name, tableId)
		if not canAct(player) then return end
		if getSeatRecord(player) then return end
		trySeatPlayerAtTable(player, tableId)
	end)
end

for _, child in ipairs(tablesFolder:GetChildren()) do
	if child:IsA("Model") then
		addTable(child)
	end
end

tablesFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		addTable(child)
	end
end)

RequestSit.OnServerEvent:Connect(function(player, tableId, slot)
	dprint("RequestSit:", player.Name, "table:", tostring(tableId), "slot:", tostring(slot))
	if not canAct(player) then return end
	if getSeatRecord(player) then return end

	local targetTable = tableId
	if not targetTable or not tables[targetTable] then
		targetTable = closestAvailableTable(player)
	end
	if not targetTable then
		dprint("RequestSit blocked: no target table for", player.Name)
		return
	end

	trySeatPlayerAtTable(player, targetTable, slot)
end)

RequestStand.OnServerEvent:Connect(function(player)
	if not canAct(player) then return end
	standPlayer(player, false)
end)

Players.PlayerAdded:Connect(function(player)
	joinAt[player.UserId] = os.clock()
end)

Players.PlayerRemoving:Connect(function(player)
	joinAt[player.UserId] = nil
	lastActionAt[player.UserId] = nil
	standPlayer(player, true)
end)

RunService.Heartbeat:Connect(function()
	for _, tableState in pairs(tables) do
		for _, seatState in pairs(tableState.seats) do
			local p = seatState.player
			if p then
				local char = p.Character
				local h = char and char:FindFirstChildOfClass("Humanoid")
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				lockSeated(h, hrp, seatState.part)
			end
		end
	end
end)

-- Watchdog: if table empty, force prompt usable.
task.spawn(function()
	while true do
		task.wait(2)
		for _, tableState in pairs(tables) do
			local a = tableState.seats.A.player
			local b = tableState.seats.B.player
			if not a and not b then
				tableState.locked = false
				tableState.promptsEnabled = true
				applyPromptState(tableState)
			end
		end
	end
end)

_G.SeatManager = {
	getAllTables = function()
		return tables
	end,

	getTableSeats = function(tableId)
		local tableState = tables[tableId]
		return tableState and tableState.seats or nil
	end,

	getSeatRecord = function(player)
		return getSeatRecord(player)
	end,

	standPlayer = function(player, force)
		return standPlayer(player, force == true)
	end,

	standSlot = function(tableId, slot, force)
		local tableState = tables[tableId]
		if not tableState then return false end
		local seatState = tableState.seats[slot]
		if not seatState or not seatState.player then return false end
		return standPlayer(seatState.player, force == true)
	end,

	setTableLocked = function(tableId, locked)
		local tableState = tables[tableId]
		if not tableState then return end
		tableState.locked = (locked == true)
		applyPromptState(tableState)
	end,

	setTablePromptEnabled = function(tableId, enabled)
		local tableState = tables[tableId]
		if not tableState then return end
		tableState.promptsEnabled = (enabled == true)
		applyPromptState(tableState)
	end,

	setAllPromptsEnabled = function(enabled)
		local value = (enabled == true)
		for _, tableState in pairs(tables) do
			tableState.promptsEnabled = value
			applyPromptState(tableState)
		end
	end,
}

dprint("SeatManager v2.1 ready. tables=", #tablesFolder:GetChildren())
