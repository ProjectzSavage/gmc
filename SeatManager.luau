-- Multi-table SeatManager for Workspace.Tables
-- Debug build: leave DEBUG = true until seat issue is confirmed fixed.
local DEBUG = false

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
	local event = events:FindFirstChild(name)
	if event and event:IsA("RemoteEvent") then return event end
	if event then event:Destroy() end
	event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = events
	return event
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
local CLIENT_READY_GRACE_SECONDS = 8

local lastActionAt = {}
local joinAt = {}

local tables = {}
local playerToSeat = {}

local function canAct(player)
	local now = os.clock()
	local previous = lastActionAt[player.UserId] or 0
	if now - previous < ACTION_COOLDOWN then
		dprint("Action cooldown block:", player.Name, string.format("%.2f", now - previous))
		return false
	end
	lastActionAt[player.UserId] = now
	return true
end

local function isClientReadyOrGrace(player)
	if _G.IsClientReady then
		local okReady = _G.IsClientReady(player)
		if okReady then
			return true
		end
	end

	local t0 = joinAt[player.UserId] or 0
	local age = os.clock() - t0
	local allowByGrace = age >= CLIENT_READY_GRACE_SECONDS
	if not allowByGrace then
		dprint("Client not ready yet:", player.Name, "age", string.format("%.2f", age))
	end
	return allowByGrace
end

local function restoreMovement(humanoid, rootPart)
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		humanoid.WalkSpeed = 21
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
		humanoid.Sit = false
	end
	if rootPart then
		rootPart.Anchored = false
	end
end

local function lockSeated(humanoid, rootPart, seatPart)
	if not humanoid or not rootPart then return end
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	rootPart.CFrame = seatPart.CFrame * CFrame.new(0, seatPart.Size.Y / 2 + 2.05, 0)
	rootPart.Anchored = true
	humanoid.AutoRotate = false
	humanoid.PlatformStand = false
	humanoid.WalkSpeed = 0
	humanoid.Sit = true
	humanoid:ChangeState(Enum.HumanoidStateType.Seated)
end

local function getSeatRecord(player)
	return playerToSeat[player.UserId]
end

local function standPlayer(player, force)
	local record = getSeatRecord(player)
	if not record then return false end

	local tableState = tables[record.tableId]
	if not tableState then
		playerToSeat[player.UserId] = nil
		return false
	end

	if tableState.locked and not force then
		local session = _G.GetSessionByPlayer and _G.GetSessionByPlayer(player) or nil
		if session and session.started then
			dprint("Stand blocked (live round):", player.Name, record.tableId, record.slot)
			return false
		end
		tableState.locked = false
	end

	local seatState = tableState.seats[record.slot]
	if not seatState or seatState.player ~= player then
		playerToSeat[player.UserId] = nil
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	restoreMovement(humanoid, rootPart)
	if rootPart then
		rootPart.CFrame = seatState.part.CFrame * CFrame.new(0, 4, 5)
	end

	if seatState.deadConn then
		seatState.deadConn:Disconnect()
		seatState.deadConn = nil
	end

	seatState.player = nil
	playerToSeat[player.UserId] = nil

	PlayerStood:FireAllClients(record.slot, player.Name, record.tableId)

	if _G.OnPlayerStood then
		_G.OnPlayerStood(player, record.tableId, record.slot)
	end

	dprint("Player stood:", player.Name, record.tableId, record.slot, "force:", force)
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

	if not isClientReadyOrGrace(player) then
		dprint("Seat blocked: client not ready/grace:", player.Name)
		return false
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

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
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
	lockSeated(humanoid, rootPart, seatState.part)

	seatState.player = player
	playerToSeat[player.UserId] = {
		tableId = tableId,
		slot = chosenSlot,
	}

	if seatState.deadConn then
		seatState.deadConn:Disconnect()
	end
	seatState.deadConn = humanoid.Died:Connect(function()
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
			local againA = tableState.seats.A.player
			local againB = tableState.seats.B.player
			if tableState.token ~= token then return end
			if not (againA and againB) then return end

			if _G.OnBothSeated then
				_G.OnBothSeated(tableId, againA, againB)
				dprint("OnBothSeated fired:", tableId, againA.Name, againB.Name)
			else
				dwarn("_G.OnBothSeated missing for table:", tableId)
			end
		end)
	end

	return true
end

local function closestAvailableTable(player)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	local bestTableId
	local bestDistance = math.huge

	for tableId, tableState in pairs(tables) do
		if tableState.promptsEnabled and (not tableState.seats.A.player or not tableState.seats.B.player) then
			local distance = (tableState.tableTop.Position - rootPart.Position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestTableId = tableId
			end
		end
	end

	return bestTableId
end

local function applyPromptState(tableState)
	if not tableState or not tableState.sitPrompt then return end
	tableState.sitPrompt.Enabled = (tableState.promptsEnabled == true) and (tableState.locked ~= true)
end

local function addTable(tableModel)
	local seatA = tableModel:FindFirstChild("SeatA")
	local seatB = tableModel:FindFirstChild("SeatB")
	local tableTop = tableModel:FindFirstChild("TableTop")
	if not (seatA and seatB and tableTop) then
		dwarn("Missing SeatA/SeatB/TableTop on", tableModel:GetFullName())
		return
	end

	seatA.Anchored = true
	seatB.Anchored = true

	local tableId = tableModel.Name
	local tableState = {
		id = tableId,
		model = tableModel,
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

RequestSit.OnServerEvent:Connect(function(player, tableId, slot)
	dprint("RequestSit:", player.Name, "table:", tostring(tableId), "slot:", tostring(slot))

	if not isClientReadyOrGrace(player) then
		dprint("RequestSit blocked (ready/grace):", player.Name)
		return
	end
	if not canAct(player) then return end
	if getSeatRecord(player) then return end

	local targetTable = tableId
	if not targetTable or not tables[targetTable] then
		targetTable = closestAvailableTable(player)
	end
	if not targetTable then
		dprint("RequestSit blocked: no targetTable for", player.Name)
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
				local character = p.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				lockSeated(humanoid, rootPart, seatState.part)
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

dprint("Multi-table ready:", #tablesFolder:GetChildren())
