-- SeatManager - Single Table + Jump at 1/2 OK
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = RS:FindFirstChild("Events")
if not Events then
	Events = Instance.new("Folder")
	Events.Name = "Events"
	Events.Parent = RS
end

local function ensureEvent(name)
	local e = Events:FindFirstChild(name)
	if e then return e end
	e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = Events
	return e
end

for _, name in ipairs({
	"PlayerSat", "PlayerStood",
	"ShowLetterPick", "LetterChosen",
	"ShowCountryPick", "CountryChosen",
	"ShowLetterGuess", "SubmitLetterGuess", "LetterGuessResult",
	"ShowCountryGuess", "SubmitCountryGuess", "CountryGuessResult",
	"ShowWait", "ShowBillboard", "TimerTick",
	"GameOver", "ResetAll",
	"RequestSit", "RequestStand",
	"TableCountdown", "TableStatus",
	"SetHeadTagsVisible",
	"DailyQuestSync", "DailyQuestClaim",
	"GuessPhaseStart", "GamePowerupEffect", "TestGamePowerup", "UseFreePowerup",
	}) do
	ensureEvent(name)
end

local PlayerSat = Events:WaitForChild("PlayerSat")
local PlayerStood = Events:WaitForChild("PlayerStood")

local Table = workspace:WaitForChild("Table")
local SeatA = Table:WaitForChild("SeatA")
local SeatB = Table:WaitForChild("SeatB")
local TableTop = Table:WaitForChild("TableTop")

SeatA.Anchored = true
SeatB.Anchored = true

local Seats = {
	A = { part = SeatA, player = nil, deadConn = nil },
	B = { part = SeatB, player = nil, deadConn = nil },
}

local ACTION_COOLDOWN = 0.18
local LAST_ACTION_AT = {}
local BOTH_SEATED_TOKEN = 0
local promptsEnabled = true

local standPlayer

local function canAct(player)
	local now = os.clock()
	local last = LAST_ACTION_AT[player.UserId] or 0
	if (now - last) < ACTION_COOLDOWN then return false end
	LAST_ACTION_AT[player.UserId] = now
	return true
end

local function restoreMovement(hum, hrp)
	if hum then
		hum.AutoRotate = true
		hum.PlatformStand = false
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		hum.WalkSpeed = 16
		hum.JumpPower = 50
		hum.JumpHeight = 7.2
		hum.Sit = false
	end
	if hrp then hrp.Anchored = false end
end

local function lockSeated(hum, hrp, seatPart)
	if not hum or not hrp then return end
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = seatPart.CFrame * CFrame.new(0, seatPart.Size.Y / 2 + 2.05, 0)
	hrp.Anchored = true
	hum.AutoRotate = false
	hum.PlatformStand = false
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.JumpHeight = 0
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	hum.Sit = true
	hum:ChangeState(Enum.HumanoidStateType.Seated)
end

local function sitPlayer(player, slot)
	local seat = Seats[slot]
	if not seat or seat.player then return false end
	for _, d in pairs(Seats) do
		if d.player == player then return false end
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return false end
	lockSeated(hum, hrp, seat.part)
	seat.player = player
	if seat.deadConn then seat.deadConn:Disconnect() end
	seat.deadConn = hum.Died:Connect(function()
		if seat.player == player then standPlayer(slot) end
	end)
	PlayerSat:FireAllClients(slot, player.Name)
	if Seats.A.player and Seats.B.player and _G.OnBothSeated then
		BOTH_SEATED_TOKEN += 1
		local token = BOTH_SEATED_TOKEN
		task.delay(0.2, function()
			if token ~= BOTH_SEATED_TOKEN then return end
			if Seats.A.player and Seats.B.player then
				_G.OnBothSeated(Seats.A.player, Seats.B.player)
			end
		end)
	end
	return true
end

standPlayer = function(slot)
	local seat = Seats[slot]
	if not seat or not seat.player then return end
	local player = seat.player
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	restoreMovement(hum, hrp)
	if hrp then hrp.CFrame = seat.part.CFrame * CFrame.new(0, 4, 5) end
	if seat.deadConn then seat.deadConn:Disconnect(); seat.deadConn = nil end
	seat.player = nil
	BOTH_SEATED_TOKEN += 1
	PlayerStood:FireAllClients(slot, player.Name)
	if _G.OnPlayerStood then _G.OnPlayerStood(player, slot) end
end

-- Single prompt on TableTop
for _, seat in ipairs({SeatA, SeatB}) do
	for _, c in ipairs(seat:GetChildren()) do
		if c:IsA("ProximityPrompt") then c:Destroy() end
	end
end
for _, c in ipairs(TableTop:GetChildren()) do
	if c:IsA("ProximityPrompt") and c.Name == "SitPrompt" then c:Destroy() end
end

local sitPrompt = Instance.new("ProximityPrompt")
sitPrompt.Name = "SitPrompt"
sitPrompt.ActionText = "Sit"
sitPrompt.ObjectText = "Guess My Country"
sitPrompt.KeyboardKeyCode = Enum.KeyCode.E
sitPrompt.HoldDuration = 0
sitPrompt.MaxActivationDistance = 12
sitPrompt.RequiresLineOfSight = false
sitPrompt.Parent = TableTop

sitPrompt.Triggered:Connect(function(triggerPlayer)
	if not promptsEnabled then return end
	if not canAct(triggerPlayer) then return end
	for _, d in pairs(Seats) do
		if d.player == triggerPlayer then return end
	end
	for _, slot in ipairs({"A", "B"}) do
		if not Seats[slot].player then
			sitPlayer(triggerPlayer, slot)
			return
		end
	end
end)

Events.RequestSit.OnServerEvent:Connect(function(player, slot)
	if not canAct(player) then return end
	for _, d in pairs(Seats) do
		if d.player == player then return end
	end
	if slot and Seats[slot] and not Seats[slot].player then
		sitPlayer(player, slot)
	else
		for _, s in ipairs({"A", "B"}) do
			if not Seats[s].player then sitPlayer(player, s); return end
		end
	end
end)

-- STAND: always allowed
Events.RequestStand.OnServerEvent:Connect(function(player)
	if not canAct(player) then return end
	for slot, d in pairs(Seats) do
		if d.player == player then standPlayer(slot); return end
	end
end)

_G.SeatManager = {
	getSeats = function() return Seats end,
	standSlot = standPlayer,
	setPromptsEnabled = function(enabled)
		promptsEnabled = enabled == true
		if sitPrompt then sitPrompt.Enabled = promptsEnabled end
	end,
}

Players.PlayerRemoving:Connect(function(player)
	LAST_ACTION_AT[player.UserId] = nil
	for slot, d in pairs(Seats) do
		if d.player == player then standPlayer(slot) end
	end
end)

RunService.Heartbeat:Connect(function()
	for _, d in pairs(Seats) do
		if d.player then
			local char = d.player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			lockSeated(hum, hrp, d.part)
		end
	end
end)

print("[SeatManager] Ready")