-- GameManager - v2026-04-18 Update 7 FIXED
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Events = RS:WaitForChild("Events")
local CountryData = require(RS:WaitForChild("CountryData"))
local SetHeadTagsVisible = Events:WaitForChild("SetHeadTagsVisible")

local function ensureEvent(name)
	local e = Events:FindFirstChild(name)
	if e then return e end
	e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = Events
	return e
end

local TableCountdown = ensureEvent("TableCountdown")
local TableStatus = ensureEvent("TableStatus")

local E = {
	ShowLetterPick = Events:WaitForChild("ShowLetterPick"),
	LetterChosen = Events:WaitForChild("LetterChosen"),
	ShowCountryPick = Events:WaitForChild("ShowCountryPick"),
	CountryChosen = Events:WaitForChild("CountryChosen"),
	ShowLetterGuess = Events:WaitForChild("ShowLetterGuess"),
	SubmitLetterGuess = Events:WaitForChild("SubmitLetterGuess"),
	LetterGuessResult = Events:WaitForChild("LetterGuessResult"),
	ShowCountryGuess = Events:WaitForChild("ShowCountryGuess"),
	SubmitCountryGuess = Events:WaitForChild("SubmitCountryGuess"),
	CountryGuessResult = Events:WaitForChild("CountryGuessResult"),
	ShowWait = Events:WaitForChild("ShowWait"),
	ShowBillboard = Events:WaitForChild("ShowBillboard"),
	TimerTick = Events:WaitForChild("TimerTick"),
	GameOver = Events:WaitForChild("GameOver"),
	ResetAll = Events:WaitForChild("ResetAll"),
}

local CFG = {
	COUNTDOWN_START = 3,
	POST_COUNTDOWN_DELAY = 0,
	START_AFTER_PICK_DELAY = 0.7,
	TURN_TIME = 60,
	ASK_TO_RESPONSE_DELAY = 1.35,
	RESPONSE_DISPLAY_TIME = 2.0,
	TURN_SWITCH_BUFFER = 0.75,
}

local REWARDS = {
	WinCash = 200,
	WinIncrease = 1,
	WinstreakIncrease = 1,
}

local TEXT = {
	AskLetter = "Is your letter %s?",
	AskCountry = "Is your country %s?",
	Guessing = "Guessing",
	BothReady = "Both players are ready",
	Higher = "HIGHER",
	Lower = "LOWER",
	Yes = "YES",
	No = "NO",
	Timeout = "TIME UP",
}

local session = nil

local function countryListForLetter(letter)
	local list = CountryData.ByLetter[string.upper(letter or "")]
	if type(list) == "table" then return list end
	return {}
end

local function listNames(list)
	local out = {}
	for i, c in ipairs(list) do
		if i > 20 then break end
		table.insert(out, c.name or "?")
	end
	return table.concat(out, ", ")
end

local function getOtherPlayer(s, p)
	if p == s.playerA then return s.playerB end
	if p == s.playerB then return s.playerA end
	return nil
end

local function getPlayerById(s, userId)
	if s.playerA and s.playerA.UserId == userId then return s.playerA end
	if s.playerB and s.playerB.UserId == userId then return s.playerB end
	return nil
end

local function isParticipant(s, p)
	return p and (p == s.playerA or p == s.playerB)
end

local function bumpToken(s)
	s.token += 1
	return s.token
end

local function resetSession()
	if session and session.active then
		session.active = false
		bumpToken(session)
		E.ResetAll:FireAllClients()
	end
	-- Restore head tags and prompts
	if session and session.playerA and session.playerB then
		SetHeadTagsVisible:FireAllClients({session.playerA.Name, session.playerB.Name}, true)
	end
	if _G.SeatManager and _G.SeatManager.setPromptsEnabled then
		_G.SeatManager.setPromptsEnabled(true)
	end
	session = nil
	_G.CurrentGameSession = nil
end

-- FIX: was checking `cash:IsA` instead of `wins:IsA`
local function awardWinner(player)
	if not player then return end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end

	local cash = stats:FindFirstChild("Cash")
	local wins = stats:FindFirstChild("Wins")
	local winstreak = stats:FindFirstChild("Winstreak")

	if cash and cash:IsA("IntValue") then
		cash.Value += REWARDS.WinCash
	end
	if wins and wins:IsA("IntValue") then
		wins.Value += REWARDS.WinIncrease
	end
	if winstreak and winstreak:IsA("IntValue") then
		winstreak.Value += REWARDS.WinstreakIncrease
	end
end

local function resetPlayerStreak(player)
	if not player then return end
	local stats = player:FindFirstChild("leaderstats")
	local winstreak = stats and stats:FindFirstChild("Winstreak")
	if winstreak and winstreak:IsA("IntValue") then winstreak.Value = 0 end
end

local function eliminateLoserOnly(s, winnerPlayer)
	local loser = getOtherPlayer(s, winnerPlayer)
	if not loser then return end
	local char = loser.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then hum.Health = 0 end
end

local function standWinnerOnly(s, winnerPlayer)
	if not _G.SeatManager or not _G.SeatManager.getSeats or not _G.SeatManager.standSlot then return end
	if typeof(winnerPlayer) ~= "Instance" then return end
	local seats = _G.SeatManager.getSeats()
	for slot, data in pairs(seats) do
		if data.player == winnerPlayer then
			_G.SeatManager.standSlot(slot)
			break
		end
	end
end

local function endWithWinner(s, winnerPlayer)
	if not s or not s.active then return end
	if s.ending then return end
	s.ending = true
	local winnerName = typeof(winnerPlayer) == "Instance" and winnerPlayer.Name or tostring(winnerPlayer or "Unknown")

	if typeof(winnerPlayer) == "Instance" then
		awardWinner(winnerPlayer)
		local loser = getOtherPlayer(s, winnerPlayer)
		resetPlayerStreak(loser)
	end

	s.active = false
	bumpToken(s)
	-- Only fire to participants
	if s.playerA then E.GameOver:FireClient(s.playerA, { winner = winnerName, rewardCash = REWARDS.WinCash }) end
	if s.playerB then E.GameOver:FireClient(s.playerB, { winner = winnerName, rewardCash = REWARDS.WinCash }) end

	task.delay(0.25, function() standWinnerOnly(s, winnerPlayer) end)
	task.delay(1.2, function()
		if s.active then return end
		eliminateLoserOnly(s, winnerPlayer)
	end)
	task.delay(1.5, function() resetSession() end)
end

local switchToOtherTurn

local function startTurnTimer(s, token, turnPlayer)
	task.spawn(function()
		for t = CFG.TURN_TIME, 1, -1 do
			if not s.active or s.token ~= token or s.turnUserId ~= turnPlayer.UserId then return end
			E.TimerTick:FireClient(turnPlayer, t)
			task.wait(1)
		end

		if not s.active or s.token ~= token or s.turnUserId ~= turnPlayer.UserId then return end

		local resolveToken = bumpToken(s)
		s.phase = "resolving"

		if s.mode == "letter" then
			E.LetterGuessResult:FireClient(turnPlayer, {
				result = "timeout",
				message = "TIMEOUT",
				eliminatedMin = s.secret[turnPlayer.UserId].elimMin,
				eliminatedMax = s.secret[turnPlayer.UserId].elimMax,
			})
		else
			E.CountryGuessResult:FireClient(turnPlayer, {
				result = "timeout",
				message = "TIMEOUT",
			})
		end

		task.delay(CFG.RESPONSE_DISPLAY_TIME + CFG.TURN_SWITCH_BUFFER, function()
			if not s.active or s.token ~= resolveToken then return end
			switchToOtherTurn(s, turnPlayer, "after timeout")
		end)
	end)
end

local function newWrongList(map)
	local out = {}
	for name, v in pairs(map) do
		if v then table.insert(out, name) end
	end
	table.sort(out)
	return out
end

switchToOtherTurn = function(s, currentPlayer, reason)
	if not s or not s.active then return end
	local other = getOtherPlayer(s, currentPlayer)
	if not other then return end
	s.turnUserId = other.UserId
	s.mode = nil
	print("[GM][NextTurn] " .. tostring(reason or "switch") .. " -> " .. other.Name)
	s.openTurnUI()
end

local function openTurnUIFactory(s)
	return function()
		if not s.active then return end

		local turnPlayer = getPlayerById(s, s.turnUserId)
		if not turnPlayer then return end
		local other = getOtherPlayer(s, turnPlayer)
		if not other then return end

		local mySecret = s.secret[turnPlayer.UserId]
		local oppSecret = s.secret[other.UserId]
		if not mySecret or not oppSecret then return end

		local token = bumpToken(s)
		-- Only fire billboard to participants
		if s.playerA then E.ShowBillboard:FireClient(s.playerA, turnPlayer.Name, TEXT.Guessing, "white") end
		if s.playerB then E.ShowBillboard:FireClient(s.playerB, turnPlayer.Name, TEXT.Guessing, "white") end

		if mySecret.foundLetter then
			s.phase = "guessCountry"
			s.mode = "country"

			local letter = string.upper(tostring(oppSecret.letter or ""))
			local list = countryListForLetter(letter)
			print("[GM][ShowCountryGuess] opponent=" .. other.Name .. " letter=" .. letter .. " count=" .. #list)
			print("[GM][ShowCountryGuess] names=" .. listNames(list))

			E.ShowCountryGuess:FireClient(turnPlayer, {
				opponentName = other.Name,
				letter = letter,
				countries = list,
				timeLeft = CFG.TURN_TIME,
				wrongList = newWrongList(mySecret.wrongCountries),
			})
			-- Country hint for waiting player
			local oppCountry2 = s.secret[other.UserId] and s.secret[other.UserId].country or "?"
			E.ShowCountryGuess:FireClient(other, {
				waiting = true,
				opponentName = turnPlayer.Name,
				message = turnPlayer.Name .. " is guessing your country...",
				countryHint = oppCountry2,
			})
		else
			s.phase = "guessLetter"
			s.mode = "letter"
			E.ShowLetterGuess:FireClient(turnPlayer, {
				opponentName = other.Name,
				timeLeft = CFG.TURN_TIME,
				eliminatedMin = mySecret.elimMin,
				eliminatedMax = mySecret.elimMax,
			})
			-- Country hint for waiting player
			local oppCountry = s.secret[other.UserId] and s.secret[other.UserId].country or "?"
			local focusSlot = (turnPlayer == s.playerA) and "A" or "B"
			E.ShowWait:FireClient(other,
				turnPlayer.Name .. " is guessing your letter...",
				turnPlayer.Name, focusSlot, oppCountry)
		end

		startTurnTimer(s, token, turnPlayer)
	end
end

local function runCountdownAndStart(s)
	for t = CFG.COUNTDOWN_START, 1, -1 do
		if not s.active then return end
		TableCountdown:FireClient(s.playerA, t)
		TableCountdown:FireClient(s.playerB, t)
		task.wait(1)
	end

	if not s.active then return end
	TableCountdown:FireClient(s.playerA, 0)
	TableCountdown:FireClient(s.playerB, 0)
	task.wait(CFG.POST_COUNTDOWN_DELAY)
	if not s.active then return end

	s.phase = "picking"
	E.ShowLetterPick:FireClient(s.playerA)
	E.ShowLetterPick:FireClient(s.playerB)
end

_G.OnBothSeated = function(playerA, playerB)
	resetSession()

	session = {
		active = true,
		playerA = playerA,
		playerB = playerB,
		turnUserId = playerA.UserId,
		phase = "picking",
		mode = nil,
		token = 0,
		letterPicked = {},
		countryPicked = {},
		secret = {
			[playerA.UserId] = { letter = nil, country = nil, foundLetter = false, elimMin = 0, elimMax = 27, wrongCountries = {} },
			[playerB.UserId] = { letter = nil, country = nil, foundLetter = false, elimMin = 0, elimMax = 27, wrongCountries = {} },
		},
	}

	_G.CurrentGameSession = session

	-- Hide tags + disable prompts
	SetHeadTagsVisible:FireAllClients({playerA.Name, playerB.Name}, false)
	if _G.SeatManager and _G.SeatManager.setPromptsEnabled then
		_G.SeatManager.setPromptsEnabled(false)
	end

	session.openTurnUI = openTurnUIFactory(session)
	task.spawn(runCountdownAndStart, session)
end

_G.OnPlayerStood = function(player)
	if session and isParticipant(session, player) then
		if session.ending then return end
		if session.phase ~= "picking" then
			local other = getOtherPlayer(session, player)
			if other then
				endWithWinner(session, other)
				return
			end
		end
		resetSession()
	end
end

Players.PlayerRemoving:Connect(function(player)
	if session and isParticipant(session, player) then
		if session.ending then return end
		if session.phase ~= "picking" then
			local other = getOtherPlayer(session, player)
			if other then endWithWinner(session, other); return end
		end
		resetSession()
	end
end)

E.LetterChosen.OnServerEvent:Connect(function(player, letter)
	local s = session
	if not s or not s.active or s.phase ~= "picking" then return end
	if not isParticipant(s, player) then return end
	if s.letterPicked[player.UserId] then return end

	letter = string.upper(tostring(letter or ""))
	if #letter ~= 1 then return end

	local list = countryListForLetter(letter)
	if #list == 0 then return end

	s.secret[player.UserId].letter = letter
	s.letterPicked[player.UserId] = true
	E.ShowCountryPick:FireClient(player, letter, list)
end)

E.CountryChosen.OnServerEvent:Connect(function(player, countryName)
	local s = session
	if not s or not s.active or s.phase ~= "picking" then return end
	if not isParticipant(s, player) then return end
	if not s.letterPicked[player.UserId] or s.countryPicked[player.UserId] then return end

	local letter = s.secret[player.UserId].letter
	if not letter then return end

	local chosen = nil
	for _, c in ipairs(countryListForLetter(letter)) do
		if string.lower(c.name) == string.lower(tostring(countryName)) then
			chosen = c.name
			break
		end
	end
	if not chosen then return end

	s.secret[player.UserId].country = chosen
	s.countryPicked[player.UserId] = true

	if s.countryPicked[s.playerA.UserId] and s.countryPicked[s.playerB.UserId] then
		TableStatus:FireAllClients(TEXT.BothReady)
		local GuessPhaseStart = ensureEvent("GuessPhaseStart")
		GuessPhaseStart:FireClient(s.playerA)
		GuessPhaseStart:FireClient(s.playerB)
		task.delay(CFG.START_AFTER_PICK_DELAY, function()
			if not s.active or s.phase ~= "picking" then return end
			TableStatus:FireAllClients("")
			s.openTurnUI()
		end)
	end
end)

E.SubmitLetterGuess.OnServerEvent:Connect(function(player, letter)
	local s = session
	if not s or not s.active or s.phase ~= "guessLetter" then return end
	if s.turnUserId ~= player.UserId then return end

	local other = getOtherPlayer(s, player)
	if not other then return end

	local mySecret = s.secret[player.UserId]
	local oppSecret = s.secret[other.UserId]
	if not mySecret or not oppSecret or not oppSecret.letter then return end

	letter = string.upper(tostring(letter or ""))
	if #letter ~= 1 then return end

	local guessIdx = string.byte(letter) - 64
	local targetIdx = string.byte(oppSecret.letter) - 64
	if guessIdx < 1 or guessIdx > 26 then return end

	local token = bumpToken(s)
	s.phase = "resolving"

	E.ShowBillboard:FireAllClients(player.Name, string.format(TEXT.AskLetter, letter), "white")

	task.delay(CFG.ASK_TO_RESPONSE_DELAY, function()
		if not s.active or s.token ~= token then return end

		local result, msg, colorName
		if guessIdx == targetIdx then
			result = "yes"
			msg = TEXT.Yes
			colorName = "green"
			mySecret.foundLetter = true
		elseif guessIdx < targetIdx then
			result = "higher"
			msg = TEXT.Higher
			colorName = "yellow"
			mySecret.elimMin = math.max(mySecret.elimMin, guessIdx)
		else
			result = "lower"
			msg = TEXT.Lower
			colorName = "yellow"
			mySecret.elimMax = math.min(mySecret.elimMax, guessIdx)
		end

		print("[GM][LetterResult] guess=" .. letter .. " target=" .. oppSecret.letter .. " result=" .. msg)
		E.ShowBillboard:FireAllClients(other.Name, msg, colorName)
		E.LetterGuessResult:FireClient(player, {
			result = result,
			letter = letter,
			message = msg,
			eliminatedMin = mySecret.elimMin,
			eliminatedMax = mySecret.elimMax,
		})

		task.delay(CFG.RESPONSE_DISPLAY_TIME + CFG.TURN_SWITCH_BUFFER, function()
			if not s.active or s.token ~= token then return end
			switchToOtherTurn(s, player, "after letter guess")
		end)
	end)
end)

E.SubmitCountryGuess.OnServerEvent:Connect(function(player, countryName)
	local s = session
	if not s or not s.active or s.phase ~= "guessCountry" then return end
	if s.turnUserId ~= player.UserId then return end

	local other = getOtherPlayer(s, player)
	if not other then return end

	local mySecret = s.secret[player.UserId]
	local oppSecret = s.secret[other.UserId]
	if not mySecret or not oppSecret or not oppSecret.country then return end

	local guess = tostring(countryName or "")
	local correct = string.lower(guess) == string.lower(oppSecret.country)
	local token = bumpToken(s)
	s.phase = "resolving"

	E.ShowBillboard:FireAllClients(player.Name, string.format(TEXT.AskCountry, guess), "white")

	task.delay(CFG.ASK_TO_RESPONSE_DELAY, function()
		if not s.active or s.token ~= token then return end

		if correct then
			print("[GM][CountryResult] guess=" .. guess .. " target=" .. oppSecret.country .. " result=" .. TEXT.Yes)
			E.ShowBillboard:FireAllClients(other.Name, TEXT.Yes, "green")
			E.CountryGuessResult:FireClient(player, { result = "yes", message = TEXT.Yes })
			task.delay(CFG.RESPONSE_DISPLAY_TIME, function()
				if not s.active or s.token ~= token then return end
				endWithWinner(s, player)
			end)
			return
		end

		print("[GM][CountryResult] guess=" .. guess .. " target=" .. oppSecret.country .. " result=" .. TEXT.No)
		mySecret.wrongCountries[guess] = true
		E.ShowBillboard:FireAllClients(other.Name, TEXT.No, "red")
		E.CountryGuessResult:FireClient(player, {
			result = "no",
			message = TEXT.No,
			wrongName = guess,
		})
		task.delay(CFG.RESPONSE_DISPLAY_TIME + CFG.TURN_SWITCH_BUFFER, function()
			if not s.active or s.token ~= token then return end
			switchToOtherTurn(s, player, "after country guess")
		end)
	end)
end)

print("[GameManager] Ready")