-- ClientHandler v3 (safe camera wrappers + mobile fallback)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
player.CharacterAdded:Wait()

while not _G.Frames do
	task.wait(0.1)
end
local F = _G.Frames

local Events = RS:WaitForChild("Events", 15)
if not Events then
	warn("[ClientHandler] Events folder missing")
	return
end

local function getRemote(name, required)
	local obj = Events:FindFirstChild(name) or Events:WaitForChild(name, 10)
	if not obj and required then
		warn("[ClientHandler] Missing remote:", name)
	end
	return obj
end

local E = {
	PlayerSat = getRemote("PlayerSat", true),
	PlayerStood = getRemote("PlayerStood", true),

	ShowLetterPick = getRemote("ShowLetterPick", true),
	LetterChosen = getRemote("LetterChosen", true),

	ShowCountryPick = getRemote("ShowCountryPick", true),
	CountryChosen = getRemote("CountryChosen", true),

	ShowLetterGuess = getRemote("ShowLetterGuess", true),
	SubmitLetterGuess = getRemote("SubmitLetterGuess", true),
	LetterGuessResult = getRemote("LetterGuessResult", true),

	ShowCountryGuess = getRemote("ShowCountryGuess", true),
	SubmitCountryGuess = getRemote("SubmitCountryGuess", true),
	CountryGuessResult = getRemote("CountryGuessResult", true),

	ShowWait = getRemote("ShowWait", true),
	ShowBillboard = getRemote("ShowBillboard", true),
	TimerTick = getRemote("TimerTick", true),

	GameOver = getRemote("GameOver", true),
	ResetAll = getRemote("ResetAll", true),

	RequestStand = getRemote("RequestStand", true),
	TableCountdown = getRemote("TableCountdown", true),

	BotTableCountdown = getRemote("BotTableCountdown", false),
	RoundOver = getRemote("RoundOver", false),
}

local getSeatSnapshotRF = Events:FindFirstChild("GetSeatSnapshot")

local CountryData = { ByLetter = {} }
do
	local ok, mod = pcall(function()
		return require(RS:WaitForChild("CountryData"))
	end)
	if ok and type(mod) == "table" then
		CountryData = mod
		CountryData.ByLetter = CountryData.ByLetter or {}
	else
		warn("[CH] CountryData failed:", mod)
	end
end

-- State
local myElimMin = 0
local myElimMax = 27
local myWrong = {}

local iAmSeated = false
local mySlot = nil
local myTableId = nil
local myTableSeatNames = { A = nil, B = nil }
local myTablePlayerCount = 0

local countdownDone = false
local pendingShowLetterPick = false

local seatedAt = 0
local lastStandRequestAt = 0

-- Jump lock
local roundJumpLocked = false
local JUMP_LOCK_ACTION = "RoundJumpLock"
local jumpBound = false

local function setJumpLock(locked)
	roundJumpLocked = (locked == true)

	if roundJumpLocked then
		if not jumpBound then
			CAS:BindActionAtPriority(
				JUMP_LOCK_ACTION,
				function(_, state)
					if state == Enum.UserInputState.Begin then
						return Enum.ContextActionResult.Sink
					end
					return Enum.ContextActionResult.Pass
				end,
				false,
				3000,
				Enum.PlayerActions.CharacterJump
			)
			jumpBound = true
		end
	else
		if jumpBound then
			CAS:UnbindAction(JUMP_LOCK_ACTION)
			jumpBound = false
		end
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
	hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
	hum.JumpPower = 50
	hum.JumpHeight = 7.2
end

-- Camera helpers
local function callExternalCamera(name, ...)
	local fn = _G[name]
	if type(fn) ~= "function" then
		return false
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[CH] Camera function failed:", name, err)
		return false
	end
	return true
end

local function getTableModel()
	if not myTableId then return nil end
	local tablesFolder = workspace:FindFirstChild("Tables")
	if not tablesFolder then return nil end
	return tablesFolder:FindFirstChild(tostring(myTableId))
end

local function tweenCameraTo(cf, duration)
	local cam = workspace.CurrentCamera
	if not cam then return end
	cam.CameraType = Enum.CameraType.Scriptable
	local tween = TweenService:Create(
		cam,
		TweenInfo.new(duration or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = cf }
	)
	tween:Play()
end

local function fallbackGoWideShot(duration)
	local model = getTableModel()
	local top = model and model:FindFirstChild("TableTop")
	if not top then return end
	local lookAtPos = top.Position + Vector3.new(0, 1.8, 0)
	local camPos = top.Position + Vector3.new(0, 8, 12)
	tweenCameraTo(CFrame.lookAt(camPos, lookAtPos), duration or 0.7)
end

local function fallbackZoomIntoFace(slot, duration)
	local model = getTableModel()
	local seat = model and model:FindFirstChild("Seat" .. tostring(slot or mySlot or "A"))
	if not seat then
		fallbackGoWideShot(duration)
		return
	end
	local faceTarget = seat.Position + seat.CFrame.LookVector * 2 + Vector3.new(0, 2.2, 0)
	local camPos = faceTarget + seat.CFrame.LookVector * 3.2 + Vector3.new(0, 0.4, 0)
	tweenCameraTo(CFrame.lookAt(camPos, faceTarget), duration or 0.7)
end

local function fallbackReleaseCamera()
	local cam = workspace.CurrentCamera
	if not cam then return end
	cam.CameraType = Enum.CameraType.Custom
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
end

local function CamGoWideShot(duration)
	if not callExternalCamera("GoWideShot", duration) then
		fallbackGoWideShot(duration)
	end
end

local function CamZoomIntoFace(slot, duration)
	if not callExternalCamera("ZoomIntoMyFace", slot, duration) then
		fallbackZoomIntoFace(slot, duration)
	end
end

local function CamZoomGuessTurn(slot, duration)
	if not callExternalCamera("ZoomGuessTurn", slot, duration) then
		CamZoomIntoFace(slot, duration)
	end
end

local function CamObservePlayerFace(slot, duration, overlayText)
	if not callExternalCamera("ObservePlayerFace", slot, duration, overlayText) then
		fallbackZoomIntoFace(slot, duration)
	end
end

local function CamRelease(duration)
	if not callExternalCamera("ReleaseCamera", duration) then
		fallbackReleaseCamera()
	end
end

-- Utility
local LETTER_UI = {
	CellSize = 72,
	CellPadding = 6,
	MaxCells = 8,
	Radius = 10,
	StrokeThickness = 2,
	StrokeColor = Color3.fromRGB(120, 165, 255),
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	TextStrokeTransparency = 0.18,
	TextStrokeColor = Color3.fromRGB(6, 10, 24),
	BaseColor = Color3.fromRGB(255, 255, 255),
	HoverColor = Color3.fromRGB(60, 120, 255),
	DisabledColor = Color3.fromRGB(38, 38, 48),
	DisabledTextColor = Color3.fromRGB(65, 65, 75),
}

local COUNTRY_UI = {
	RowHeight = 52,
	RowGap = 6,
	RowInset = 6,
	Radius = 8,
	StrokeThickness = 2,
	StrokeColor = Color3.fromRGB(95, 135, 220),
	TextSize = 15,
	Font = Enum.Font.Gotham,
	TextStrokeTransparency = 0.2,
	TextStrokeColor = Color3.fromRGB(4, 8, 20),
	BaseColor = Color3.fromRGB(2, 187, 190),
	HoverColor = Color3.fromRGB(40, 90, 180),
	TextColor = Color3.fromRGB(230, 235, 255),
}

local function setVisible(o, v)
	if o then o.Visible = v end
end

local function setText(lbl, txt)
	if lbl and lbl:IsA("TextLabel") then
		lbl.Text = txt
	end
end

local function hideAll()
	setVisible(F.LPickF, false)
	setVisible(F.CPickF, false)
	setVisible(F.LGuessF, false)
	setVisible(F.CGuessF, false)
	setVisible(F.WaitF, false)
	setVisible(F.ResultF, false)
	setVisible(F.GameOverF, false)
end

local function clear(container)
	if not container then return end
	for _, c in ipairs(container:GetChildren()) do
		if not c:IsA("UIGridLayout")
			and not c:IsA("UIListLayout")
			and not c:IsA("UICorner")
			and not c:IsA("UIStroke") then
			c:Destroy()
		end
	end
end

local function disableAll(container)
	if not container then return end
	for _, b in ipairs(container:GetChildren()) do
		if b:IsA("TextButton") then
			b.Active = false
		end
	end
end

local function mkCorner(radius, parent)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function isWrong(name)
	for _, w in ipairs(myWrong) do
		if string.lower(w) == string.lower(name) then
			return true
		end
	end
	return false
end

local function colorFromName(c)
	local map = {
		green = Color3.fromRGB(80, 255, 100),
		red = Color3.fromRGB(255, 60, 60),
		yellow = Color3.fromRGB(255, 210, 0),
		white = Color3.fromRGB(255, 255, 255),
	}
	return map[c] or map.white
end

local function getOtherSlot()
	if mySlot == "A" then return "B" end
	if mySlot == "B" then return "A" end
	return nil
end

local function getSlotByName(name)
	if myTableSeatNames.A == name then return "A" end
	if myTableSeatNames.B == name then return "B" end
	return nil
end

local function setGuessingOverlay(t)
	if F.BlurOverlay then
		F.BlurOverlay.Visible = true
	end
	if F.GuessingLbl then
		F.GuessingLbl.Text = t or ""
		F.GuessingLbl.TextTransparency = t and 0 or 1
	end
end

local function hideGuessingOverlay()
	if F.GuessingLbl then
		F.GuessingLbl.Text = ""
		F.GuessingLbl.TextTransparency = 1
	end
end

local function recalcMyTableCount()
	local c = 0
	if myTableSeatNames.A then c += 1 end
	if myTableSeatNames.B then c += 1 end
	myTablePlayerCount = c

	if myTablePlayerCount < 2 then
		setJumpLock(false)
	end
end

local function forceUnlockRoundState()
	countdownDone = false
	pendingShowLetterPick = false
	setJumpLock(false)
	CamRelease()
end

local function hardUnlockMovementAndCamera()
	setJumpLock(false)
	hideGuessingOverlay()
	CamRelease()

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		hum.JumpPower = 50
		hum.JumpHeight = 7.2
	end
end

local function parseTableId(raw)
	local s = tostring(raw or "")
	if s == "" then return nil end
	if string.sub(s, 1, 4) == "BOT:" then
		return string.sub(s, 5)
	end
	return s
end

local function syncMyTableCountFromSnapshot()
	if not myTableId then return end
	if not getSeatSnapshotRF or not getSeatSnapshotRF:IsA("RemoteFunction") then return end

	local ok, snap = pcall(function()
		return getSeatSnapshotRF:InvokeServer()
	end)
	if not ok or type(snap) ~= "table" then return end

	local count
	if tostring(myTableId):sub(1, 4) == "BOT:" then
		local id = tostring(myTableId):sub(5)
		count = snap.botTables and snap.botTables[id]
	else
		count = snap.tables and snap.tables[myTableId]
	end

	myTablePlayerCount = tonumber(count) or myTablePlayerCount
	setText(F.HUDStatus, tostring(myTablePlayerCount) .. " / 2 seated")
end

-- Stand by jump
local function tryStandFromJump()
	if not iAmSeated then return end
	if myTablePlayerCount >= 2 and countdownDone then return end
	if roundJumpLocked then return end

	if os.clock() - seatedAt < 0.45 then return end
	local now = os.clock()
	if now - lastStandRequestAt < 0.25 then return end
	lastStandRequestAt = now

	if E.RequestStand then
		E.RequestStand:FireServer()
	end
end

UIS.InputBegan:Connect(function(input, gameProcessed)
	if not iAmSeated then return end

	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
		tryStandFromJump()
		return
	end

	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonA then
		tryStandFromJump()
	end
end)

UIS.JumpRequest:Connect(function()
	tryStandFromJump()
end)

-- UI builders
local function ensureLetterGridLayout(grid)
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	if not layout then
		layout = Instance.new("UIGridLayout")
		layout.Parent = grid
	end

	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local mobile = vp.X <= 900

	layout.CellSize = UDim2.fromOffset(mobile and 50 or LETTER_UI.CellSize, mobile and 50 or LETTER_UI.CellSize)
	layout.CellPadding = UDim2.fromOffset(LETTER_UI.CellPadding, LETTER_UI.CellPadding)
	layout.FillDirectionMaxCells = mobile and 5 or LETTER_UI.MaxCells
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	grid.BackgroundTransparency = 1
	grid.ClipsDescendants = true
end

local function mergeCountryLists(localList, serverList)
	local merged = {}
	local seen = {}

	local function addAll(list)
		if type(list) ~= "table" then return end
		for _, c in ipairs(list) do
			local key = c and c.name and string.lower(c.name)
			if key and not seen[key] then
				seen[key] = true
				table.insert(merged, c)
			end
		end
	end

	addAll(localList)
	addAll(serverList)
	return merged
end

local function debugCountryList(tag, letter, serverList, localList, finalList)
	local s = type(serverList) == "table" and serverList or {}
	local l = type(localList) == "table" and localList or {}
	local f = type(finalList) == "table" and finalList or {}
	print(string.format("[CH][%s] letter=%s server=%d local=%d final=%d", tag, tostring(letter), #s, #l, #f))
end

local function buildLetterGrid(grid, onPick)
	ensureLetterGridLayout(grid)
	clear(grid)

	for i = 1, 26 do
		local letter = string.char(64 + i)
		local list = CountryData.ByLetter[letter]
		local hasData = type(list) == "table" and #list > 0

		local btn = Instance.new("TextButton")
		btn.Name = "L_" .. letter
		btn.Size = UDim2.fromOffset(LETTER_UI.CellSize, LETTER_UI.CellSize)
		btn.BackgroundColor3 = hasData and LETTER_UI.BaseColor or LETTER_UI.DisabledColor
		btn.TextColor3 = hasData and Color3.fromRGB(255, 255, 255) or LETTER_UI.DisabledTextColor
		btn.Font = LETTER_UI.Font
		btn.TextSize = LETTER_UI.TextSize
		btn.TextStrokeTransparency = LETTER_UI.TextStrokeTransparency
		btn.TextStrokeColor3 = LETTER_UI.TextStrokeColor
		btn.Text = letter
		btn.AutoButtonColor = false
		btn.Active = hasData
		btn.Parent = grid
		mkCorner(LETTER_UI.Radius, btn)

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = LETTER_UI.StrokeThickness
		stroke.Color = hasData and LETTER_UI.StrokeColor or Color3.fromRGB(55, 60, 75)
		stroke.Parent = btn

		if hasData then
			local base = LETTER_UI.BaseColor
			btn.MouseEnter:Connect(function()
				if btn.Active then
					btn.BackgroundColor3 = LETTER_UI.HoverColor
				end
			end)
			btn.MouseLeave:Connect(function()
				if btn.Active then
					btn.BackgroundColor3 = base
				end
			end)
			btn.MouseButton1Click:Connect(function()
				if not btn.Active then return end
				disableAll(grid)
				onPick(letter)
			end)
		end
	end
end

local function applyElim(grid, eMin, eMax)
	local minN = tonumber(eMin) or 0
	local maxN = tonumber(eMax) or 27

	for i = 1, 26 do
		local b = grid:FindFirstChild("L_" .. string.char(64 + i))
		if b and (i <= minN or i >= maxN) then
			b.BackgroundColor3 = Color3.fromRGB(42, 42, 52)
			b.TextColor3 = Color3.fromRGB(62, 62, 72)
			b.TextStrokeTransparency = 1
			b.Active = false
			local st = b:FindFirstChildOfClass("UIStroke")
			if st then st.Enabled = false end
		end
	end
end

local function buildCountryList(scroll, countries, onPick, debugTag)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
	clear(scroll)

	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local mobile = vp.X <= 900
	local rowH = mobile and 40 or COUNTRY_UI.RowHeight
	local gap = mobile and 5 or COUNTRY_UI.RowGap

	scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = mobile and 8 or 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ClipsDescendants = true
	scroll.Active = true
	scroll.ScrollingEnabled = true

	local y = COUNTRY_UI.RowInset

	for _, c in ipairs(countries) do
		local btn = Instance.new("TextButton")
		btn.Name = "C_" .. tostring(c.name)
		btn.Size = UDim2.new(1, -(COUNTRY_UI.RowInset * 2), 0, rowH)
		btn.Position = UDim2.new(0, COUNTRY_UI.RowInset, 0, y)
		btn.BackgroundColor3 = COUNTRY_UI.BaseColor
		btn.TextColor3 = COUNTRY_UI.TextColor
		btn.Font = COUNTRY_UI.Font
		btn.TextSize = mobile and 13 or COUNTRY_UI.TextSize
		btn.TextStrokeTransparency = COUNTRY_UI.TextStrokeTransparency
		btn.TextStrokeColor3 = COUNTRY_UI.TextStrokeColor
		btn.Text = "  " .. tostring(c.name) .. "   |   " .. tostring(c.continent)
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.TextWrapped = false
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn.AutoButtonColor = false
		btn.Active = true
		btn.Parent = scroll
		mkCorner(COUNTRY_UI.Radius, btn)

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = COUNTRY_UI.StrokeThickness
		stroke.Color = COUNTRY_UI.StrokeColor
		stroke.Parent = btn

		btn.MouseEnter:Connect(function()
			if btn.Active then
				btn.BackgroundColor3 = COUNTRY_UI.HoverColor
			end
		end)
		btn.MouseLeave:Connect(function()
			if btn.Active then
				btn.BackgroundColor3 = COUNTRY_UI.BaseColor
			end
		end)
		btn.MouseButton1Click:Connect(function()
			if not btn.Active then return end
			onPick(c.name)
		end)

		y += rowH + gap
	end

	print("[CH][" .. debugTag .. "] options count =", #countries)
	scroll.CanvasSize = UDim2.new(0, 0, 0, y + 6)
end

local function openLetterPick()
	hideAll()
	hideGuessingOverlay()
	F.LPickF.Visible = true

	if mySlot then
		CamZoomIntoFace(mySlot, 0.9)
	end

	buildLetterGrid(F.LPickGrid, function(letter)
		if E.LetterChosen then
			E.LetterChosen:FireServer(letter)
		end
		hideAll()
		F.WaitF.Visible = true
		F.WaitLbl.Text = "Chosen letter: " .. letter
	end)
end

-- Event handlers
if E.PlayerSat then
	E.PlayerSat.OnClientEvent:Connect(function(slot, name, rawTableId)
		local tableId = parseTableId(rawTableId)

		if name == player.Name then
			seatedAt = os.clock()
			lastStandRequestAt = 0
			iAmSeated = true
			setJumpLock(false)

			mySlot = slot
			myTableId = tableId
			myTableSeatNames = { A = nil, B = nil }

			countdownDone = false
			pendingShowLetterPick = false

			task.defer(syncMyTableCountFromSnapshot)
		end

		if myTableId and tableId ~= myTableId then return end

		if slot == "A" or slot == "B" then
			myTableSeatNames[slot] = name
		end

		recalcMyTableCount()
		setText(F.HUDSeat1, "A: " .. tostring(myTableSeatNames.A or "Empty"))
		setText(F.HUDSeat2, "B: " .. tostring(myTableSeatNames.B or "Empty"))
		setText(F.HUDStatus, tostring(myTablePlayerCount) .. " / 2 seated")

		if name == player.Name then
			CamGoWideShot(1.0)
		end
	end)
end

if E.PlayerStood then
	E.PlayerStood.OnClientEvent:Connect(function(slot, name, rawTableId)
		local tableId = parseTableId(rawTableId)

		if myTableId and tableId ~= myTableId then return end

		if slot == "A" or slot == "B" then
			myTableSeatNames[slot] = nil
		end

		recalcMyTableCount()

		if iAmSeated and myTablePlayerCount < 2 then
			forceUnlockRoundState()
			setText(F.HUDStatus, tostring(myTablePlayerCount) .. " / 2 seated")
		end

		if name == player.Name then
			iAmSeated = false
			mySlot = nil
			myTableId = nil
			myTableSeatNames = { A = nil, B = nil }
			myTablePlayerCount = 0

			countdownDone = false
			pendingShowLetterPick = false

			myElimMin = 0
			myElimMax = 27
			myWrong = {}

			setJumpLock(false)
			hideGuessingOverlay()
			hideAll()
			setText(F.HUDStatus, "Walk up and press E to sit")
			CamRelease()
		end
	end)
end

if E.TableCountdown then
	E.TableCountdown.OnClientEvent:Connect(function(a, b)
		local tableId, t
		if b == nil then
			tableId = myTableId
			t = a
		else
			tableId = tostring(a)
			t = b
		end

		if myTableId and tableId and tableId ~= myTableId then return end

		local n = tonumber(t)
		if n and n > 0 then
			countdownDone = false
			setJumpLock(myTablePlayerCount >= 2)
			hideAll()
			return
		end

		if iAmSeated then
			countdownDone = true
			setJumpLock(true)
			if pendingShowLetterPick then
				pendingShowLetterPick = false
				openLetterPick()
			end
		else
			forceUnlockRoundState()
		end
	end)
end

if E.BotTableCountdown then
	E.BotTableCountdown.OnClientEvent:Connect(function(rawTableId, t)
		local tableId = parseTableId(rawTableId)
		if myTableId and tableId ~= myTableId then return end

		local n = tonumber(t)
		if n and n > 0 then
			countdownDone = false
			setJumpLock(true)
			hideAll()
			return
		end

		if iAmSeated then
			countdownDone = true
			setJumpLock(true)
			if pendingShowLetterPick then
				pendingShowLetterPick = false
				openLetterPick()
			end
		else
			forceUnlockRoundState()
		end
	end)
end

if E.ShowBillboard then
	E.ShowBillboard.OnClientEvent:Connect(function(targetName, text, colorName)
		if not iAmSeated then return end

		local tp = Players:FindFirstChild(targetName)
		if tp and _G.ShowHeadBB then
			_G.ShowHeadBB(tp, text, colorFromName(colorName))
		end

		if tostring(text) == "Guessing" then return end
		hideGuessingOverlay()
		CamGoWideShot(0.45)
	end)
end

if E.ShowWait then
	E.ShowWait.OnClientEvent:Connect(function(msg, focusName, focusSlot, countryHint)
		if not iAmSeated then return end

		hideAll()
		F.WaitF.Visible = true

		local displayText = msg or "Opponent's turn..."
		if countryHint and countryHint ~= "?" then
			displayText = displayText .. "\n\nYour country: " .. tostring(countryHint)
		end
		F.WaitLbl.Text = displayText

		local guessedName = focusName
		if not guessedName or guessedName == "" then
			guessedName = tostring(msg or ""):match("^(.-) is guessing")
		end

		local targetSlot = focusSlot or getSlotByName(guessedName) or getOtherSlot()
		if guessedName == player.Name then
			targetSlot = nil
		end

		local overlayText = ((guessedName and guessedName ~= "") and (guessedName .. " is guessing")) or "Opponent is guessing"

		if targetSlot then
			setGuessingOverlay(overlayText)
			CamObservePlayerFace(targetSlot, 0.7, overlayText)
		else
			hideGuessingOverlay()
			CamGoWideShot(0.6)
		end
	end)
end

if E.ShowLetterPick then
	E.ShowLetterPick.OnClientEvent:Connect(function()
		if not iAmSeated then return end

		if not countdownDone then
			pendingShowLetterPick = true
			return
		end

		openLetterPick()
	end)
end

if E.ShowCountryPick then
	E.ShowCountryPick.OnClientEvent:Connect(function(arg1, arg2)
		if not iAmSeated then return end

		hideAll()
		hideGuessingOverlay()
		F.CPickF.Visible = true

		local letter, serverList
		if type(arg1) == "table" then
			letter = arg1.letter or arg1.Letter
			serverList = arg1.countries or arg1.Countries or arg1.list or arg1.List
		else
			letter = arg1
			serverList = arg2
		end

		letter = string.upper(tostring(letter or ""))
		if #letter > 1 then
			letter = string.sub(letter, 1, 1)
		end

		local localList = CountryData.ByLetter[letter] or {}
		local countries = mergeCountryLists(localList, serverList)
		debugCountryList("CountryPick", letter, serverList, localList, countries)

		if #countries == 0 then
			F.WaitF.Visible = true
			F.WaitLbl.Text = "No countries found for letter " .. tostring(letter) .. "."
			return
		end

		buildCountryList(F.CPickScroll, countries, function(countryName)
			disableAll(F.CPickScroll)
			if E.CountryChosen then
				E.CountryChosen:FireServer(countryName)
			end
			hideAll()
			F.WaitF.Visible = true
			F.WaitLbl.Text = "Secret country chosen"
			CamGoWideShot(0.8)
		end, "CountryPick")
	end)
end

if E.ShowLetterGuess then
	E.ShowLetterGuess.OnClientEvent:Connect(function(data)
		if not iAmSeated then return end

		hideAll()
		hideGuessingOverlay()

		myElimMin = tonumber(data.eliminatedMin) or 0
		myElimMax = tonumber(data.eliminatedMax) or 27

		F.LGuessF.Visible = true
		F.LGuessTitle.Text = "Guess " .. tostring(data.opponentName or "?") .. "'s letter"
		F.LGuessFeedback.Text = "One guess per turn"
		F.LGuessFeedback.TextColor3 = Color3.fromRGB(200, 200, 220)
		F.LGuessTimer.Text = tostring(tonumber(data.timeLeft) or 60) .. "s"
		F.LGuessTimer.TextColor3 = Color3.fromRGB(255, 215, 0)

		if mySlot then
			CamZoomGuessTurn(mySlot, 0.8)
		end

		buildLetterGrid(F.LGuessGrid, function(letter)
			if E.SubmitLetterGuess then
				E.SubmitLetterGuess:FireServer(letter)
			end
			hideAll()
			F.WaitF.Visible = true
			F.WaitLbl.Text = "Waiting for response..."
			CamGoWideShot(0.5)
		end)

		applyElim(F.LGuessGrid, myElimMin, myElimMax)
	end)
end

if E.LetterGuessResult then
	E.LetterGuessResult.OnClientEvent:Connect(function(data)
		if not iAmSeated then return end

		local result = string.lower(tostring(data.result or ""))
		if result == "higher" then
			myElimMin = tonumber(data.eliminatedMin) or myElimMin
		elseif result == "lower" then
			myElimMax = tonumber(data.eliminatedMax) or myElimMax
		end

		hideGuessingOverlay()
		CamGoWideShot(0.45)

		F.WaitF.Visible = true
		F.WaitLbl.Text = tostring(data.message or "Response received")
	end)
end

if E.ShowCountryGuess then
	E.ShowCountryGuess.OnClientEvent:Connect(function(data)
		if not iAmSeated then return end

		hideAll()
		hideGuessingOverlay()

		if data.waiting then
			F.WaitF.Visible = true
			local waitMsg = data.message or "Opponent is guessing your country..."
			if data.countryHint and data.countryHint ~= "?" then
				waitMsg = waitMsg .. "\n\nYour country: " .. tostring(data.countryHint)
			end
			F.WaitLbl.Text = waitMsg

			local otherSlot = getOtherSlot()
			local otherName = data.opponentName or myTableSeatNames[otherSlot]
			local overlayText = ((otherName and otherName ~= "") and (otherName .. " is guessing")) or "Opponent is guessing"

			if otherSlot then
				setGuessingOverlay(overlayText)
				CamObservePlayerFace(otherSlot, 0.7, overlayText)
			else
				CamGoWideShot(0.6)
			end
			return
		end

		if data.wrongList then
			myWrong = data.wrongList
		end

		F.CGuessF.Visible = true
		F.CGuessTitle.Text = "Guess " .. tostring(data.opponentName or "?") .. "'s country"
		F.CGuessInfo.Text = "One guess per turn"
		F.CGuessInfo.TextColor3 = Color3.fromRGB(200, 200, 220)
		F.CGuessTimer.Text = tostring(data.timeLeft or 60) .. "s"
		F.CGuessTimer.TextColor3 = Color3.fromRGB(255, 215, 0)

		if mySlot then
			CamZoomGuessTurn(mySlot, 0.8)
		end

		local letter = string.upper(tostring(data.letter or ""))
		local localList = CountryData.ByLetter[letter] or {}
		local countries = mergeCountryLists(localList, data.countries)
		debugCountryList("CountryGuess", letter, data.countries, localList, countries)

		buildCountryList(F.CGuessScroll, countries, function(countryName)
			disableAll(F.CGuessScroll)
			if E.SubmitCountryGuess then
				E.SubmitCountryGuess:FireServer(countryName)
			end
			hideAll()
			F.WaitF.Visible = true
			F.WaitLbl.Text = "Waiting for response..."
			CamGoWideShot(0.5)
		end, "CountryGuess")

		for _, child in ipairs(F.CGuessScroll:GetChildren()) do
			if child:IsA("TextButton") then
				local cn = string.gsub(child.Name, "^C_", "")
				if isWrong(cn) then
					child.BackgroundColor3 = Color3.fromRGB(100, 25, 25)
					child.TextColor3 = Color3.fromRGB(180, 70, 70)
					child.Active = false
				end
			end
		end
	end)
end

if E.CountryGuessResult then
	E.CountryGuessResult.OnClientEvent:Connect(function(data)
		if not iAmSeated then return end

		if data.result == "no" and data.wrongName and data.wrongName ~= "" then
			table.insert(myWrong, data.wrongName)
		end

		hideGuessingOverlay()
		CamGoWideShot(0.45)

		F.WaitF.Visible = true
		F.WaitLbl.Text = tostring(data.message or "Response received")
	end)
end

if E.TimerTick then
	E.TimerTick.OnClientEvent:Connect(function(t)
		if not (iAmSeated and mySlot and myTablePlayerCount >= 2) then return end

		local col = (t <= 10 and Color3.fromRGB(255, 60, 60))
			or (t <= 30 and Color3.fromRGB(255, 180, 50))
			or Color3.fromRGB(255, 215, 0)

		local text = tostring(t) .. "s"

		if F.LGuessF.Visible then
			F.LGuessTimer.Text = text
			F.LGuessTimer.TextColor3 = col
		end
		if F.CGuessF.Visible then
			F.CGuessTimer.Text = text
			F.CGuessTimer.TextColor3 = col
		end
	end)
end

if E.RoundOver then
	E.RoundOver.OnClientEvent:Connect(function()
		-- Intentionally unused in current flow.
	end)
end

if E.GameOver then
	E.GameOver.OnClientEvent:Connect(function(data)
		hideAll()
		hardUnlockMovementAndCamera()
		forceUnlockRoundState()

		local winner = (data and data.winner) or "Unknown"

		if iAmSeated then
			if F.GameOverF and F.GameOverLbl then
				F.GameOverF.Visible = true
				F.GameOverLbl.Text = "Winner: " .. winner
			else
				F.WaitF.Visible = true
				F.WaitLbl.Text = "Winner: " .. winner
			end
		end
	end)
end

if E.ResetAll then
	E.ResetAll.OnClientEvent:Connect(function()
		myElimMin = 0
		myElimMax = 27
		myWrong = {}

		iAmSeated = false
		mySlot = nil
		myTableId = nil
		myTableSeatNames = { A = nil, B = nil }
		myTablePlayerCount = 0

		countdownDone = false
		pendingShowLetterPick = false

		hardUnlockMovementAndCamera()
		forceUnlockRoundState()
	end)
end

local function hookHumanoidUnlock(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end

	hum.Seated:Connect(function(isSeatedNow)
		if not isSeatedNow and myTablePlayerCount < 2 then
			setJumpLock(false)
		end
	end)

	hum:GetPropertyChangedSignal("Jump"):Connect(function()
		if hum.Jump and iAmSeated and not roundJumpLocked then
			tryStandFromJump()
		end
	end)

	hum.Died:Connect(function()
		setJumpLock(false)
	end)
end

if player.Character then
	hookHumanoidUnlock(player.Character)
end

player.CharacterAdded:Connect(function(char)
	task.wait(0.2)
	setJumpLock(false)
	hookHumanoidUnlock(char)
end)

player.CharacterAdded:Connect(function()
	task.wait(0.15)
	hideGuessingOverlay()
	hideAll()
	if F.GameOverF then
		F.GameOverF.Visible = false
	end
	CamRelease(0.2)
end)

print("[ClientHandler] Ready - " .. player.Name)
