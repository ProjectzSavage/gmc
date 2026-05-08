-- Multi-table GameManager (independent 1v1 sessions per table)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local events = ReplicatedStorage:WaitForChild("Events")
local CountryData = require(ReplicatedStorage:WaitForChild("CountryData"))

local function event(name)
	return events:WaitForChild(name)
end

local E = {
	ShowLetterPick = event("ShowLetterPick"),
	LetterChosen = event("LetterChosen"),
	ShowCountryPick = event("ShowCountryPick"),
	CountryChosen = event("CountryChosen"),
	ShowLetterGuess = event("ShowLetterGuess"),
	SubmitLetterGuess = event("SubmitLetterGuess"),
	LetterGuessResult = event("LetterGuessResult"),
	ShowCountryGuess = event("ShowCountryGuess"),
	SubmitCountryGuess = event("SubmitCountryGuess"),
	CountryGuessResult = event("CountryGuessResult"),
	ShowWait = event("ShowWait"),
	ShowBillboard = event("ShowBillboard"),
	TimerTick = event("TimerTick"),
	GameOver = event("GameOver"),
	ResetAll = event("ResetAll"),
	TableCountdown = event("TableCountdown"),
	TableStatus = event("TableStatus"),
}

local CFG = {
	COUNTDOWN_START = 3,
	TURN_TIME = 60,
	TURN_SWITCH_DELAY = 1.2,
}

local sessions = {}
local playerToTable = {}

local function countryListForLetter(letter)
	local list = CountryData.ByLetter[string.upper(letter or "")]
	if type(list) == "table" then
		return list
	end
	return {}
end

local function countryExistsForLetter(letter, countryName)
	local list = countryListForLetter(letter)
	local target = string.lower(tostring(countryName or ""))
	for _, entry in ipairs(list) do
		if string.lower(entry.name) == target then
			return true
		end
	end
	return false
end

local function getOtherPlayer(session, player)
	if player == session.playerA then return session.playerB end
	if player == session.playerB then return session.playerA end
	return nil
end

local function getSecret(session, player)
	return session.secret[player.UserId]
end

local function fireBoth(session, remote, payload)
	if session.playerA then remote:FireClient(session.playerA, payload) end
	if session.playerB then remote:FireClient(session.playerB, payload) end
end

local function setTableStatus(tableId, text)
	E.TableStatus:FireAllClients(tableId, text)
end

local function setTableCountdown(tableId, value)
	E.TableCountdown:FireAllClients(tableId, value)
end

local function clearSession(tableId)
	local session = sessions[tableId]
	if not session then return end

	sessions[tableId] = nil
	if session.playerA then playerToTable[session.playerA.UserId] = nil end
	if session.playerB then playerToTable[session.playerB.UserId] = nil end

	if _G.SeatManager and _G.SeatManager.setTablePromptEnabled then
		_G.SeatManager.setTablePromptEnabled(tableId, true)
	end

	setTableStatus(tableId, "")
	setTableCountdown(tableId, 0)
end

local function endSessionWithWinner(tableId, winner, reason)
	local session = sessions[tableId]
	if not session or not session.active then return end
	if session.ending then return end
	session.ending = true
	session.active = false
	session.token += 1

	local loser = getOtherPlayer(session, winner)
	fireBoth(session, E.GameOver, {
		winner = winner and winner.Name or "Unknown",
		reason = reason or "",
		rewardCash = 200,
	})

	task.delay(1.25, function()
		if _G.SeatManager and _G.SeatManager.standPlayer then
			if winner then _G.SeatManager.standPlayer(winner) end
			if loser then _G.SeatManager.standPlayer(loser) end
		end
		clearSession(tableId)
	end)
end

local function switchTurn(session)
	local current = session.turnPlayer
	session.turnPlayer = getOtherPlayer(session, current)
	session.mode = "letter"
end

local function openTurn(session)
	if not session.active then return end
	local turnPlayer = session.turnPlayer
	local other = getOtherPlayer(session, turnPlayer)
	if not turnPlayer or not other then return end

	local mySecret = getSecret(session, turnPlayer)
	local oppSecret = getSecret(session, other)
	if not mySecret or not oppSecret then return end

	session.phase = "turn"
	session.token += 1
	local token = session.token

	E.ShowWait:FireClient(other, { text = turnPlayer.Name .. " is guessing..." })
	E.ShowBillboard:FireClient(other, { text = turnPlayer.Name .. " turn" })

	if session.mode == "letter" then
		E.ShowLetterGuess:FireClient(turnPlayer, {
			eliminatedMin = mySecret.elimMin,
			eliminatedMax = mySecret.elimMax,
			turnTime = CFG.TURN_TIME,
		})
	else
		local wrong = {}
		for countryName, state in pairs(mySecret.wrongCountries) do
			if state then table.insert(wrong, countryName) end
		end
		table.sort(wrong)
		E.ShowCountryGuess:FireClient(turnPlayer, {
			letter = oppSecret.letter,
			wrongCountries = wrong,
			turnTime = CFG.TURN_TIME,
		})
	end

	task.spawn(function()
		for t = CFG.TURN_TIME, 1, -1 do
			if not session.active or session.token ~= token then return end
			E.TimerTick:FireClient(turnPlayer, t)
			task.wait(1)
		end

		if not session.active or session.token ~= token then return end

		if session.mode == "letter" then
			E.LetterGuessResult:FireClient(turnPlayer, {
				result = "timeout",
				message = "TIMEOUT",
				eliminatedMin = mySecret.elimMin,
				eliminatedMax = mySecret.elimMax,
			})
		else
			E.CountryGuessResult:FireClient(turnPlayer, {
				result = "timeout",
				message = "TIMEOUT",
			})
		end

		switchTurn(session)
		task.delay(CFG.TURN_SWITCH_DELAY, function()
			if session.active then
				openTurn(session)
			end
		end)
	end)
end

local function startGame(tableId)
	local session = sessions[tableId]
	if not session or not session.active then return end

	local a = session.secret[session.playerA.UserId]
	local b = session.secret[session.playerB.UserId]
	if not (a and b and a.country and b.country) then return end

	session.turnPlayer = math.random(1, 2) == 1 and session.playerA or session.playerB
	session.mode = "letter"
	session.phase = "turn"

	setTableStatus(tableId, "In match")
	openTurn(session)
end

local function beginCountryPick(tableId)
	local session = sessions[tableId]
	if not session or not session.active then return end

	session.phase = "country-pick"

	for _, player in ipairs({ session.playerA, session.playerB }) do
		local secret = getSecret(session, player)
		E.ShowCountryPick:FireClient(player, {
			letter = secret.letter,
			countries = countryListForLetter(secret.letter),
		})
	end
end

local function beginLetterPick(tableId)
	local session = sessions[tableId]
	if not session or not session.active then return end
	session.phase = "letter-pick"

	E.ShowLetterPick:FireClient(session.playerA)
	E.ShowLetterPick:FireClient(session.playerB)
end

local function createSession(tableId, playerA, playerB)
	if sessions[tableId] then return end

	local session = {
		tableId = tableId,
		playerA = playerA,
		playerB = playerB,
		active = true,
		ending = false,
		token = 0,
		phase = "countdown",
		turnPlayer = nil,
		mode = "letter",
		secret = {
			[playerA.UserId] = { letter = nil, country = nil, elimMin = 0, elimMax = 27, wrongCountries = {} },
			[playerB.UserId] = { letter = nil, country = nil, elimMin = 0, elimMax = 27, wrongCountries = {} },
		},
	}

	sessions[tableId] = session
	playerToTable[playerA.UserId] = tableId
	playerToTable[playerB.UserId] = tableId

	if _G.SeatManager and _G.SeatManager.setTablePromptEnabled then
		_G.SeatManager.setTablePromptEnabled(tableId, false)
	end

	setTableStatus(tableId, "Both players are ready")

	task.spawn(function()
		for t = CFG.COUNTDOWN_START, 1, -1 do
			if not session.active then return end
			setTableCountdown(tableId, t)
			task.wait(1)
		end
		setTableCountdown(tableId, 0)
		beginLetterPick(tableId)
	end)
end

_G.OnBothSeated = function(tableId, playerA, playerB)
	createSession(tableId, playerA, playerB)
end

_G.OnPlayerStood = function(player, tableId)
	local session = sessions[tableId]
	if not session or not session.active then return end

	local other = getOtherPlayer(session, player)
	if other then
		endSessionWithWinner(tableId, other, "opponent_left")
	else
		clearSession(tableId)
	end
end

E.LetterChosen.OnServerEvent:Connect(function(player, letter)
	local tableId = playerToTable[player.UserId]
	if not tableId then return end
	local session = sessions[tableId]
	if not session or not session.active or session.phase ~= "letter-pick" then return end

	local secret = getSecret(session, player)
	if not secret then return end

	local list = countryListForLetter(letter)
	if #list == 0 then return end

	secret.letter = string.upper(letter)

	local aDone = getSecret(session, session.playerA).letter ~= nil
	local bDone = getSecret(session, session.playerB).letter ~= nil
	if aDone and bDone then
		beginCountryPick(tableId)
	end
end)

E.CountryChosen.OnServerEvent:Connect(function(player, countryName)
	local tableId = playerToTable[player.UserId]
	if not tableId then return end
	local session = sessions[tableId]
	if not session or not session.active or session.phase ~= "country-pick" then return end

	local secret = getSecret(session, player)
	if not secret or not secret.letter then return end

	if not countryExistsForLetter(secret.letter, countryName) then return end
	secret.country = countryName

	local aDone = getSecret(session, session.playerA).country ~= nil
	local bDone = getSecret(session, session.playerB).country ~= nil
	if aDone and bDone then
		startGame(tableId)
	end
end)

E.SubmitLetterGuess.OnServerEvent:Connect(function(player, guessLetter)
	local tableId = playerToTable[player.UserId]
	if not tableId then return end
	local session = sessions[tableId]
	if not session or not session.active then return end
	if session.phase ~= "turn" or session.mode ~= "letter" then return end
	if session.turnPlayer ~= player then return end

	local other = getOtherPlayer(session, player)
	local mySecret = getSecret(session, player)
	local oppSecret = getSecret(session, other)
	if not (mySecret and oppSecret and oppSecret.letter) then return end

	session.token += 1

	local guessed = string.byte(string.upper(guessLetter)) - 64
	local actual = string.byte(oppSecret.letter) - 64

	if guessed == actual then
		E.LetterGuessResult:FireClient(player, {
			result = "correct",
			message = "YES",
			eliminatedMin = mySecret.elimMin,
			eliminatedMax = mySecret.elimMax,
		})
		session.mode = "country"
		task.delay(0.8, function()
			if session.active then
				openTurn(session)
			end
		end)
		return
	end

	local message
	if guessed < actual then
		mySecret.elimMin = math.max(mySecret.elimMin, guessed)
		message = "HIGHER"
	else
		mySecret.elimMax = math.min(mySecret.elimMax, guessed)
		message = "LOWER"
	end

	E.LetterGuessResult:FireClient(player, {
		result = "wrong",
		message = message,
		eliminatedMin = mySecret.elimMin,
		eliminatedMax = mySecret.elimMax,
	})

	switchTurn(session)
	task.delay(CFG.TURN_SWITCH_DELAY, function()
		if session.active then
			openTurn(session)
		end
	end)
end)

E.SubmitCountryGuess.OnServerEvent:Connect(function(player, guessCountry)
	local tableId = playerToTable[player.UserId]
	if not tableId then return end
	local session = sessions[tableId]
	if not session or not session.active then return end
	if session.phase ~= "turn" or session.mode ~= "country" then return end
	if session.turnPlayer ~= player then return end

	local other = getOtherPlayer(session, player)
	local mySecret = getSecret(session, player)
	local oppSecret = getSecret(session, other)
	if not (mySecret and oppSecret and oppSecret.country) then return end

	session.token += 1
	if string.lower(guessCountry) == string.lower(oppSecret.country) then
		E.CountryGuessResult:FireClient(player, {
			result = "correct",
			message = "YES",
		})
		endSessionWithWinner(tableId, player, "country_guessed")
		return
	end

	mySecret.wrongCountries[guessCountry] = true

	local wrongList = {}
	for name, used in pairs(mySecret.wrongCountries) do
		if used then table.insert(wrongList, name) end
	end
	table.sort(wrongList)

	E.CountryGuessResult:FireClient(player, {
		result = "wrong",
		message = "NO",
		wrongCountries = wrongList,
	})

	switchTurn(session)
	task.delay(CFG.TURN_SWITCH_DELAY, function()
		if session.active then
			openTurn(session)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local tableId = playerToTable[player.UserId]
	if not tableId then return end
	local session = sessions[tableId]
	if not session then
		playerToTable[player.UserId] = nil
		return
	end

	local other = getOtherPlayer(session, player)
	if other then
		endSessionWithWinner(tableId, other, "opponent_left")
	else
		clearSession(tableId)
	end
end)

print("[GameManager] Multi-table mode ready")
