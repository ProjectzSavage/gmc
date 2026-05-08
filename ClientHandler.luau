-- ClientHandler - Original + fixes
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
player.CharacterAdded:Wait()

local waited = 0
while not _G.Frames and waited < 10 do
	task.wait(0.1)
	waited += 0.1
end
if not _G.Frames then
	warn("[CH] GuiBuilder not ready")
	return
end

local F = _G.Frames

local Events = RS:WaitForChild("Events", 15)
local E = {}
for _, n in ipairs({
	"PlayerSat", "PlayerStood",
	"ShowLetterPick", "LetterChosen",
	"ShowCountryPick", "CountryChosen",
	"ShowLetterGuess", "SubmitLetterGuess", "LetterGuessResult",
	"ShowCountryGuess", "SubmitCountryGuess", "CountryGuessResult",
	"ShowWait", "ShowBillboard", "TimerTick",
	"RoundOver", "GameOver", "ResetAll",
	"RequestSit", "RequestStand", "TableCountdown",
	"BotTableCountdown", -- add this
	}) do
	E[n] = Events:WaitForChild(n, 10)
end

local CountryData = { ByLetter = {} }
do
	local ok, mod = pcall(function()
		return require(RS:WaitForChild("CountryData"))
	end)
	if ok and type(mod) == "table" then
		CountryData = mod
		CountryData.ByLetter = CountryData.ByLetter or {}
	else
		warn("[CH] CountryData failed to load:", mod)
	end
end

local myElimMin = 0
local myElimMax = 27
local myWrong = {}
local playerCount = 0
local iAmSeated = false
local mySlot = nil
local countdownDone = false
local pendingShowLetterPick = false
local seatNames = { A = nil, B = nil }
local jumpLocked = false

local LETTER_UI = {
	CellSize = 72, CellPadding = 6, MaxCells = 8, Radius = 10,
	StrokeThickness = 2, StrokeColor = Color3.fromRGB(120,165,255),
	TextSize = 20, Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.18,
	TextStrokeColor = Color3.fromRGB(6,10,24),
	BaseColor = Color3.fromRGB(255,255,255), HoverColor = Color3.fromRGB(60,120,255),
	DisabledColor = Color3.fromRGB(38,38,48), DisabledTextColor = Color3.fromRGB(65,65,75),
}

local COUNTRY_UI = {
	RowHeight = 52, RowGap = 6, RowInset = 6, Radius = 8,
	StrokeThickness = 2, StrokeColor = Color3.fromRGB(95,135,220),
	TextSize = 15, Font = Enum.Font.Gotham, TextStrokeTransparency = 0.2,
	TextStrokeColor = Color3.fromRGB(4,8,20),
	BaseColor = Color3.fromRGB(2,187,190), HoverColor = Color3.fromRGB(40,90,180),
	TextColor = Color3.fromRGB(230,235,255),
	WrongColor = Color3.fromRGB(100,25,25), WrongTextColor = Color3.fromRGB(180,70,70),
}

local function setVisible(o, v) if o then o.Visible = v end end
local function setText(l, v) if l and l:IsA("TextLabel") then l.Text = v end end
local function hideAll()
	setVisible(F.LPickF,false); setVisible(F.CPickF,false); setVisible(F.LGuessF,false)
	setVisible(F.CGuessF,false); setVisible(F.WaitF,false); setVisible(F.ResultF,false)
	setVisible(F.GameOverF,false)
end
local function clear(p)
	if not p then return end
	for _, c in ipairs(p:GetChildren()) do
		if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") and not c:IsA("UICorner") and not c:IsA("UIStroke") then c:Destroy() end
	end
end
local function disableAll(p) if not p then return end for _, b in ipairs(p:GetChildren()) do if b:IsA("TextButton") then b.Active = false end end end
local function mkCorner(r, p) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p end
local function isWrong(n) for _, w in ipairs(myWrong) do if string.lower(w) == string.lower(n) then return true end end; return false end
local function colorFromName(c) local m = {green=Color3.fromRGB(80,255,100),red=Color3.fromRGB(255,60,60),yellow=Color3.fromRGB(255,210,0),white=Color3.fromRGB(255,255,255)}; return m[c] or m.white end
local function getOtherSlot() return mySlot == "A" and "B" or mySlot == "B" and "A" or nil end
local function getSlotByName(n) return (seatNames.A == n and "A") or (seatNames.B == n and "B") end
local function setGuessingOverlay(t) if F.BlurOverlay then F.BlurOverlay.Visible = true end; if F.GuessingLbl then F.GuessingLbl.Text = t or ""; F.GuessingLbl.TextTransparency = t and 0 or 1 end end
local function hideGuessingOverlay() if F.GuessingLbl then F.GuessingLbl.Text = ""; F.GuessingLbl.TextTransparency = 1 end end

local function ensureLetterGridLayout(grid)
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	if not layout then layout = Instance.new("UIGridLayout"); layout.Parent = grid end
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
	local mobile = vp.X <= 900
	layout.CellSize = UDim2.fromOffset(mobile and 50 or LETTER_UI.CellSize, mobile and 50 or LETTER_UI.CellSize)
	layout.CellPadding = UDim2.fromOffset(LETTER_UI.CellPadding, LETTER_UI.CellPadding)
	layout.FillDirectionMaxCells = mobile and 5 or LETTER_UI.MaxCells
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	grid.BackgroundTransparency = 1
	grid.ClipsDescendants = true
end

local function mergeCountryLists(localList, serverList)
	local merged, seen = {}, {}
	local function addAll(list) if type(list)~="table" then return end for _, c in ipairs(list) do local key = c and c.name and string.lower(c.name) if key and not seen[key] then seen[key]=true; table.insert(merged,c) end end end
	addAll(localList); addAll(serverList); return merged
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
		local base = hasData and LETTER_UI.BaseColor or LETTER_UI.DisabledColor
		local hover = LETTER_UI.HoverColor
		local btn = Instance.new("TextButton")
		btn.Name = "L_"..letter
		btn.Size = UDim2.fromOffset(LETTER_UI.CellSize, LETTER_UI.CellSize)
		btn.BackgroundColor3 = base
		btn.TextColor3 = hasData and Color3.fromRGB(255,255,255) or LETTER_UI.DisabledTextColor
		btn.Font = LETTER_UI.Font; btn.TextSize = LETTER_UI.TextSize
		btn.TextStrokeTransparency = LETTER_UI.TextStrokeTransparency
		btn.TextStrokeColor3 = LETTER_UI.TextStrokeColor
		btn.Text = letter; btn.AutoButtonColor = false; btn.Active = hasData; btn.Parent = grid
		mkCorner(LETTER_UI.Radius, btn)
		local stroke = Instance.new("UIStroke"); stroke.Thickness = LETTER_UI.StrokeThickness; stroke.Color = hasData and LETTER_UI.StrokeColor or Color3.fromRGB(55,60,75); stroke.Parent = btn
		if hasData then
			btn.MouseEnter:Connect(function() if btn.Active then btn.BackgroundColor3 = hover end end)
			btn.MouseLeave:Connect(function() if btn.Active then btn.BackgroundColor3 = base end end)
			btn.MouseButton1Click:Connect(function() if not btn.Active then return end; disableAll(grid); onPick(letter) end)
		end
	end
end

local function applyElim(grid, eMin, eMax)
	eMin = tonumber(eMin) or 0
	eMax = tonumber(eMax) or 27

	for i = 1, 26 do
		local b = grid:FindFirstChild("L_" .. string.char(64 + i))
		if b and (i <= eMin or i >= eMax) then
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
	for _, child in ipairs(scroll:GetChildren()) do if child:IsA("UIListLayout") or child:IsA("UIGridLayout") then child:Destroy() end end
	clear(scroll)
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
	local mobile = vp.X <= 900
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = mobile and 8 or 6
	scroll.CanvasSize = UDim2.new(0,0,0,0)
	scroll.ClipsDescendants = true
	scroll.Active = true; scroll.ScrollingEnabled = true
	local y = COUNTRY_UI.RowInset
	local rowH = mobile and 40 or COUNTRY_UI.RowHeight
	local gap = mobile and 5 or COUNTRY_UI.RowGap
	for _, c in ipairs(countries) do
		local btn = Instance.new("TextButton")
		btn.Name = "C_"..tostring(c.name)
		btn.Size = UDim2.new(1, -(COUNTRY_UI.RowInset*2), 0, rowH)
		btn.Position = UDim2.new(0, COUNTRY_UI.RowInset, 0, y)
		btn.BackgroundColor3 = COUNTRY_UI.BaseColor
		btn.TextColor3 = COUNTRY_UI.TextColor
		btn.Font = COUNTRY_UI.Font
		btn.TextSize = mobile and 13 or COUNTRY_UI.TextSize
		btn.TextStrokeTransparency = COUNTRY_UI.TextStrokeTransparency
		btn.TextStrokeColor3 = COUNTRY_UI.TextStrokeColor
		btn.Text = "  "..tostring(c.name).."   |   "..tostring(c.continent)
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.TextWrapped = false; btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn.AutoButtonColor = false; btn.Active = true; btn.Parent = scroll
		mkCorner(COUNTRY_UI.Radius, btn)
		local stroke = Instance.new("UIStroke"); stroke.Thickness = COUNTRY_UI.StrokeThickness; stroke.Color = COUNTRY_UI.StrokeColor; stroke.Parent = btn
		btn.MouseEnter:Connect(function() if btn.Active then btn.BackgroundColor3 = COUNTRY_UI.HoverColor end end)
		btn.MouseLeave:Connect(function() if btn.Active then btn.BackgroundColor3 = COUNTRY_UI.BaseColor end end)
		btn.MouseButton1Click:Connect(function() if not btn.Active then return end; onPick(c.name) end)
		y += rowH + gap
	end
	print("[CH]["..debugTag.."] options count =", #countries)
	scroll.CanvasSize = UDim2.new(0, 0, 0, y + 6)
end

local function openLetterPick()
	hideAll(); hideGuessingOverlay()
	F.LPickF.Visible = true
	if mySlot and _G.ZoomIntoMyFace then _G.ZoomIntoMyFace(mySlot, 0.9) end
	buildLetterGrid(F.LPickGrid, function(letter)
		E.LetterChosen:FireServer(letter)
		hideAll(); F.WaitF.Visible = true
		F.WaitLbl.Text = "Chosen letter: "..letter
	end)
end

local function getClosestTableModel()
	local folder = workspace:WaitForChild("Tables")
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return folder:FindFirstChildWhichIsA("Model")
	end

	local best, bestDist = nil, math.huge
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") then
			local top = model:FindFirstChild("TableTop")
			if top and top:IsA("BasePart") then
				local d = (top.Position - hrp.Position).Magnitude
				if d < bestDist then
					bestDist = d
					best = model
				end
			end
		end
	end
	return best
end

UIS.JumpRequest:Connect(function()
	if iAmSeated and not jumpLocked then E.RequestStand:FireServer() end
end)

Players.PlayerRemoving:Connect(function(p)
	if seatNames.A == p.Name or seatNames.B == p.Name then
		jumpLocked = false
		if iAmSeated then E.RequestStand:FireServer() end
	end
end)

-- ALL event handlers now guard: `if not iAmSeated then return end`

E.ShowBillboard.OnClientEvent:Connect(function(targetName, text, colorName)
	if not iAmSeated then return end
	local tp = Players:FindFirstChild(targetName)
	if tp and _G.ShowHeadBB then _G.ShowHeadBB(tp, text, colorFromName(colorName)) end
	if tostring(text) == "Guessing" then return end
	hideGuessingOverlay()
	if _G.GoWideShot then _G.GoWideShot(0.45) end
end)

E.TableCountdown.OnClientEvent:Connect(function(t)
	if t and t > 0 then countdownDone = false; hideAll(); return end
	countdownDone = true
	if pendingShowLetterPick then pendingShowLetterPick = false; openLetterPick() end
end)
E.BotTableCountdown.OnClientEvent:Connect(function(_tableId, t)
	if t and t > 0 then
		countdownDone = false
		hideAll()
		return
	end
	countdownDone = true
	if pendingShowLetterPick then
		pendingShowLetterPick = false
		openLetterPick()
	end
end)
E.PlayerSat.OnClientEvent:Connect(function(slot, name)
	playerCount = math.min(playerCount + 1, 2)
	seatNames[slot] = name
	if slot == "A" then setText(F.HUDSeat1, "A: "..name) else setText(F.HUDSeat2, "B: "..name) end
	setText(F.HUDStatus, playerCount.." / 2 seated")
	if name == player.Name then
		iAmSeated = true; mySlot = slot
		if _G.GoWideShot then _G.GoWideShot(1.0) end
	end
	if playerCount >= 2 then jumpLocked = true end
end)

E.PlayerStood.OnClientEvent:Connect(function(slot, name)
	playerCount = math.max(playerCount - 1, 0)
	seatNames[slot] = nil
	countdownDone = false; pendingShowLetterPick = false
	myElimMin = 0; myElimMax = 27; myWrong = {}; jumpLocked = false
	if slot == "A" then setText(F.HUDSeat1, "A: Empty") else setText(F.HUDSeat2, "B: Empty") end
	setText(F.HUDStatus, "Walk up and press E to sit")
	if name == player.Name then
		iAmSeated = false; mySlot = nil; hideGuessingOverlay(); hideAll()
		if _G.ReleaseCamera then _G.ReleaseCamera() end
	end
end)

E.ShowWait.OnClientEvent:Connect(function(msg, focusName, focusSlot, countryHint)
	if not iAmSeated then return end
	hideAll(); F.WaitF.Visible = true
	local displayText = msg or "Opponent's turn..."
	if countryHint and countryHint ~= "?" then
		displayText = displayText.."\n\nYour country: "..tostring(countryHint)
	end
	F.WaitLbl.Text = displayText
	local guessedName = focusName
	if not guessedName or guessedName == "" then guessedName = tostring(msg or ""):match("^(.-) is guessing") end
	local targetSlot = focusSlot or getSlotByName(guessedName) or getOtherSlot()
	if guessedName == player.Name then targetSlot = nil end
	local overlayText = ((guessedName and guessedName ~= "") and (guessedName.." is guessing")) or "Opponent is guessing"
	if targetSlot and _G.ObservePlayerFace then
		setGuessingOverlay(overlayText); _G.ObservePlayerFace(targetSlot, 0.7, overlayText)
	else
		hideGuessingOverlay(); if _G.GoWideShot then _G.GoWideShot(0.6) end
	end
end)

E.ShowLetterPick.OnClientEvent:Connect(function()
	if not iAmSeated then return end

	-- If in bot mode, do not hard-block on countdown flag.
	local inBotMode = _G.ActiveBotTableId ~= nil
	if not inBotMode and not countdownDone then
		pendingShowLetterPick = true
		return
	end

	openLetterPick()
end)

E.ShowCountryPick.OnClientEvent:Connect(function(arg1, arg2)
	if not iAmSeated then return end

	hideAll()
	hideGuessingOverlay()
	F.CPickF.Visible = true

	-- Supports both server styles:
	-- 1) FireClient(player, letter, list)
	-- 2) FireClient(player, { letter = "...", countries = {...} })
	local letter
	local serverList

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
		E.CountryChosen:FireServer(countryName)
		hideAll()
		F.WaitF.Visible = true
		F.WaitLbl.Text = "Secret country chosen"
		if _G.GoWideShot then _G.GoWideShot(0.8) end
	end, "CountryPick")
end)

E.ShowLetterGuess.OnClientEvent:Connect(function(data)
	if not iAmSeated then return end
	hideAll(); hideGuessingOverlay()
	myElimMin = tonumber(data.eliminatedMin) or 0
	myElimMax = tonumber(data.eliminatedMax) or 27
	F.LGuessF.Visible = true
	F.LGuessTitle.Text = "Guess "..tostring(data.opponentName or "?").."'s letter"
	F.LGuessFeedback.Text = "One guess per turn"; F.LGuessFeedback.TextColor3 = Color3.fromRGB(200,200,220)
	F.LGuessTimer.Text = tostring(data.timeLeft or 60).."s"; F.LGuessTimer.TextColor3 = Color3.fromRGB(255,215,0)
	if mySlot and _G.ZoomGuessTurn then _G.ZoomGuessTurn(mySlot, 0.8)
	elseif mySlot and _G.ZoomIntoMyFace then _G.ZoomIntoMyFace(mySlot, 0.8) end
	buildLetterGrid(F.LGuessGrid, function(letter)
		E.SubmitLetterGuess:FireServer(letter); hideAll(); F.WaitF.Visible = true; F.WaitLbl.Text = "Waiting for response..."
		if _G.GoWideShot then _G.GoWideShot(0.5) end
	end)
	applyElim(F.LGuessGrid, myElimMin, myElimMax)
end)

E.LetterGuessResult.OnClientEvent:Connect(function(data)
	if not iAmSeated then return end
	if data.result == "higher" then
		myElimMin = tonumber(data.eliminatedMin) or myElimMin
	elseif data.result == "lower" then
		myElimMax = tonumber(data.eliminatedMax) or myElimMax
	end
	hideGuessingOverlay()
	if _G.GoWideShot then _G.GoWideShot(0.45) end
	F.WaitF.Visible = true; F.WaitLbl.Text = tostring(data.message or "Response received")
end)

E.ShowCountryGuess.OnClientEvent:Connect(function(data)
	if not iAmSeated then return end
	hideAll(); hideGuessingOverlay()
	if data.waiting then
		F.WaitF.Visible = true
		local waitMsg = data.message or "Opponent is guessing your country..."
		if data.countryHint and data.countryHint ~= "?" then waitMsg = waitMsg.."\n\nYour country: "..tostring(data.countryHint) end
		F.WaitLbl.Text = waitMsg
		local otherSlot = getOtherSlot()
		local otherName = data.opponentName or seatNames[otherSlot]
		local overlayText = ((otherName and otherName ~= "") and (otherName.." is guessing")) or "Opponent is guessing"
		if otherSlot and _G.ObservePlayerFace then
			setGuessingOverlay(overlayText); _G.ObservePlayerFace(otherSlot, 0.7, overlayText)
		elseif _G.GoWideShot then _G.GoWideShot(0.6) end
		return
	end
	if data.wrongList then myWrong = data.wrongList end
	F.CGuessF.Visible = true
	F.CGuessTitle.Text = "Guess "..tostring(data.opponentName or "?").."'s country"
	F.CGuessInfo.Text = "One guess per turn"; F.CGuessInfo.TextColor3 = Color3.fromRGB(200,200,220)
	F.CGuessTimer.Text = tostring(data.timeLeft or 60).."s"; F.CGuessTimer.TextColor3 = Color3.fromRGB(255,215,0)
	if mySlot and _G.ZoomGuessTurn then _G.ZoomGuessTurn(mySlot, 0.8)
	elseif mySlot and _G.ZoomIntoMyFace then _G.ZoomIntoMyFace(mySlot, 0.8) end
	local letter = string.upper(tostring(data.letter or ""))
	local localList = CountryData.ByLetter[letter] or {}
	local countries = mergeCountryLists(localList, data.countries)
	debugCountryList("CountryGuess", letter, data.countries, localList, countries)
	buildCountryList(F.CGuessScroll, countries, function(countryName)
		disableAll(F.CGuessScroll); E.SubmitCountryGuess:FireServer(countryName)
		hideAll(); F.WaitF.Visible = true; F.WaitLbl.Text = "Waiting for response..."
		if _G.GoWideShot then _G.GoWideShot(0.5) end
	end, "CountryGuess")
	for _, child in ipairs(F.CGuessScroll:GetChildren()) do
		if child:IsA("TextButton") then
			local cn = string.gsub(child.Name, "^C_", "")
			if isWrong(cn) then child.BackgroundColor3 = Color3.fromRGB(100,25,25); child.TextColor3 = Color3.fromRGB(180,70,70); child.Active = false end
		end
	end
end)

E.CountryGuessResult.OnClientEvent:Connect(function(data)
	if not iAmSeated then return end
	if data.result == "no" and data.wrongName and data.wrongName ~= "" then table.insert(myWrong, data.wrongName) end
	hideGuessingOverlay()
	if _G.GoWideShot then _G.GoWideShot(0.45) end
	F.WaitF.Visible = true; F.WaitLbl.Text = tostring(data.message or "Response received")
end)

E.TimerTick.OnClientEvent:Connect(function(t)
	if not (iAmSeated and mySlot and playerCount >= 2) then return end
	local col = t <= 10 and Color3.fromRGB(255,60,60) or t <= 30 and Color3.fromRGB(255,180,50) or Color3.fromRGB(255,215,0)
	local text = t.."s"
	if F.LGuessF.Visible then F.LGuessTimer.Text = text; F.LGuessTimer.TextColor3 = col end
	if F.CGuessF.Visible then F.CGuessTimer.Text = text; F.CGuessTimer.TextColor3 = col end
end)

E.RoundOver.OnClientEvent:Connect(function() end)

E.GameOver.OnClientEvent:Connect(function(data)
	if not iAmSeated then return end
	hideAll(); jumpLocked = false
	local winner = (data and data.winner) or "Unknown"
	if F.GameOverF and F.GameOverLbl then F.GameOverF.Visible = true; F.GameOverLbl.Text = "Winner: "..winner
	else F.WaitF.Visible = true; F.WaitLbl.Text = "Winner: "..winner end
	if _G.ReleaseCamera then _G.ReleaseCamera() end
end)

E.ResetAll.OnClientEvent:Connect(function()
	myElimMin=0; myElimMax=27; myWrong={}; playerCount=0
	seatNames.A=nil; seatNames.B=nil; iAmSeated=false; mySlot=nil
	countdownDone=false; pendingShowLetterPick=false; jumpLocked=false
	hideGuessingOverlay(); hideAll()
	setText(F.HUDSeat1, "A: Empty"); setText(F.HUDSeat2, "B: Empty")
	setText(F.HUDStatus, "Walk up and press E to sit")
	if _G.ReleaseCamera then _G.ReleaseCamera() end
end)

player.CharacterAdded:Connect(function()
	task.wait(0.15); hideGuessingOverlay(); hideAll()
	if F.GameOverF then F.GameOverF.Visible = false end
	if _G.ReleaseCamera then _G.ReleaseCamera(0.2) end
end)

print("[ClientHandler] Ready - "..player.Name)
