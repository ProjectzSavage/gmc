-- GameManager (multi-table, paced turns, head text, independent pick flow)
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
	SetHeadTagsVisible = event("SetHeadTagsVisible"), -- add this
}

local CFG = {
	COUNTDOWN_START = 3,
	TURN_TIME = 60,
	ASK_TO_RESPONSE_DELAY = 1.2,
	RESPONSE_DISPLAY_TIME = 1.7,
	TURN_SWITCH_BUFFER = 0.65,
	POST_PICK_TO_FIRST_TURN_DELAY = 2.0, -- add this
}

local sessions = {}
local playerToTable = {}
_G.GetSessionByPlayer = function(player)
	if not player then return nil end
	local tableId = playerToTable[player.UserId]
	if not tableId then return nil end
	local s = sessions[tableId]
	if s and s.active then return s end
	return nil
end

local function countryListForLetter(letter)
	local list = CountryData.ByLetter[string.upper(letter or "")]
	return (type(list) == "table") and list or {}
end

local function countryExistsForLetter(letter, countryName)
	local list = countryListForLetter(letter)
	local target = string.lower(tostring(countryName or ""))
	for _, c in ipairs(list) do
		if string.lower(c.name) == target then
			return true
		end
	end
	return false
end
local REWARDS = {
	WinCash = 200,
	WinIncrease = 1,
	WinstreakIncrease = 1,
	
}

local function awardWinner(player)
	if not player then return end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end

	local cash = stats:FindFirstChild("Cash")
	local wins = stats:FindFirstChild("Wins")
	local winstreak = stats:FindFirstChild("Winstreak")

	local cashMult = 1
	if _G.RewardsCashMultiplier then
		cashMult = _G.RewardsCashMultiplier(player)
	end

	local streakMult = 1
	if _G.RewardsStreakMultiplier then
		streakMult = _G.RewardsStreakMultiplier(player)
	end

	if cash and cash:IsA("IntValue") then
		cash.Value += math.floor(REWARDS.WinCash * cashMult)
	end
	if wins and wins:IsA("IntValue") then
		wins.Value += REWARDS.WinIncrease
	end
	if winstreak and winstreak:IsA("IntValue") then
		winstreak.Value += math.floor(REWARDS.WinstreakIncrease * streakMult)
	end
end

local function resetLoserStreak(player)
	if not player then return end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end
	local ws = stats:FindFirstChild("Winstreak")
	if ws and ws:IsA("IntValue") then
		ws.Value = 0
	end
end
local function getWinstreakValue(player)
	local stats = player and player:FindFirstChild("leaderstats")
	local ws = stats and stats:FindFirstChild("Winstreak")
	return (ws and ws:IsA("IntValue")) and ws.Value or 0
end
local function getOtherPlayer(session, player)
	if player == session.playerA then return session.playerB end
	if player == session.playerB then return session.playerA end
	return nil
end

local function getSlot(session, player)
	if player == session.playerA then return "A" end
	if player == session.playerB then return "B" end
	return nil
end

local function getSecret(session, player)
	return session.secret[player.UserId]
end

local function getProgress(session, player)
	return session.progress[player.UserId]
end

local function setTableStatus(tableId, text)
	E.TableStatus:FireAllClients(tableId, text)
end

local function setTableCountdown(tableId, value)
	E.TableCountdown:FireAllClients(tableId, value)
end

local function fireBoth(session, remote, ...)
	if session.playerA then remote:FireClient(session.playerA, ...) end
	if session.playerB then remote:FireClient(session.playerB, ...) end

end

local function clearSession(tableId)
	local session = sessions[tableId]
	if not session then return end

	sessions[tableId] = nil
	if session.playerA and session.playerB then
		E.SetHeadTagsVisible:FireAllClients({session.playerA.Name, session.playerB.Name}, true)
	end

	if _G.SeatManager and _G.SeatManager.setTablePromptEnabled then
		_G.SeatManager.setTablePromptEnabled(tableId, true)
	end
	if session.playerA then playerToTable[session.playerA.UserId] = nil end
	if session.playerB then playerToTable[session.playerB.UserId] = nil end
	setTableStatus(tableId, "")
	setTableCountdown(tableId, 0)
	if _G.SeatManager and _G.SeatManager.setTableLocked then
		_G.SeatManager.setTableLocked(tableId, false)
	end
end

local function endSessionWithWinner(tableId, winner, reason)

	local session = sessions[tableId]
	if not session or not session.active or session.ending then return end

	session.ending = true
	session.active = false
	session.token += 1

	local loser = getOtherPlayer(session, winner)
	if _G.DailyQuestMarkWinWithFriend then
		_G.DailyQuestMarkWinWithFriend(winner, loser)
	end
	-- Reward winner + reset loser streak
	awardWinner(winner)
	resetLoserStreak(loser)

	local winnerName = winner and winner.Name or "Unknown"
	fireBoth(session, E.GameOver, {
		winner = winnerName,
		reason = reason or "",
		rewardCash = REWARDS.WinCash,
	})

	-- Temporary winner flame above head
	if winner then
		local streak = getWinstreakValue(winner)
		local flames = string.rep("🔥", math.clamp(streak, 1, 5))
		fireBoth(session, E.ShowBillboard, winner.Name, winner.Name .. " " .. flames, "green")
	end

	-- Winner stands
	task.delay(0.35, function()
		if _G.SeatManager and _G.SeatManager.standPlayer and winner then
			_G.SeatManager.standPlayer(winner, true)		end
	end)

	-- Loser dies
	task.delay(1.0, function()
		if loser and loser.Character then
			local hum = loser.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				hum.Health = 0
			end
		end
	end)

	task.delay(1.5, function()
		clearSession(tableId)
	end)
end

local function openTurn(session)
	if not session.active then return end

	local turnPlayer = session.turnPlayer
	local other = getOtherPlayer(session, turnPlayer)
	if not turnPlayer or not other then return end

	local mySecret = getSecret(session, turnPlayer)
	local myProgress = getProgress(session, turnPlayer)
	local oppSecret = getSecret(session, other)
	if not mySecret or not myProgress or not oppSecret then return end

	session.phase = "turn"
	session.token += 1
	session.started = true
	local token = session.token

	local mySlot = getSlot(session, turnPlayer)
	fireBoth(session, E.ShowWait, turnPlayer.Name .. " is guessing...", turnPlayer.Name, mySlot, nil)

	if not myProgress.letterKnown then
		E.ShowLetterGuess:FireClient(turnPlayer, {
			opponentName = other.Name,
			eliminatedMin = mySecret.elimMin,
			eliminatedMax = mySecret.elimMax,
			timeLeft = CFG.TURN_TIME,
		})
	else
		local wrongList = {}
		for countryName, used in pairs(mySecret.wrongCountries) do
			if used then table.insert(wrongList, countryName) end
		end
		table.sort(wrongList)

		E.ShowCountryGuess:FireClient(turnPlayer, {
			opponentName = other.Name,
			letter = oppSecret.letter,
			countries = countryListForLetter(oppSecret.letter),
			wrongList = wrongList,
			timeLeft = CFG.TURN_TIME,
		})
	end

	task.spawn(function()
		for t = CFG.TURN_TIME, 1, -1 do
			if not session.active or session.token ~= token or session.turnPlayer ~= turnPlayer then return end
			E.TimerTick:FireClient(turnPlayer, t)
			task.wait(1)
		end

		if not session.active or session.token ~= token or session.turnPlayer ~= turnPlayer then return end

		if not myProgress.letterKnown then
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
				wrongList = {},
			})
		end

		session.turnPlayer = other
		task.delay(CFG.RESPONSE_DISPLAY_TIME + CFG.TURN_SWITCH_BUFFER, function()
			if session.active then openTurn(session) end
		end)
	end)
end

local function maybeStartGame(tableId)
	local session = sessions[tableId]
	if not session or not session.active then return end

	local a = getSecret(session, session.playerA)
	local b = getSecret(session, session.playerB)
	if not a or not b or not a.country or not b.country then return end

	session.phase = "pre-turn"
	session.turnPlayer = (math.random(1, 2) == 1) and session.playerA or session.playerB
	setTableStatus(tableId, "Get ready...")

	-- hide player name tags during gameplay
	E.SetHeadTagsVisible:FireAllClients({session.playerA.Name, session.playerB.Name}, false)

	-- short pause before first guess turn
	fireBoth(session, E.ShowWait, "Get ready...", nil, nil, nil)

	task.delay(CFG.POST_PICK_TO_FIRST_TURN_DELAY, function()
		if not session.active then return end
		session.phase = "turn"
		setTableStatus(tableId, "In match")
		openTurn(session)
	end)
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
		started = false,
		active = true,
		ending = false,
		phase = "countdown",
		token = 0,
		turnPlayer = nil,

		secret = {
			[playerA.UserId] = { letter = nil, country = nil, elimMin = 0, elimMax = 27, wrongCountries = {} },
			[playerB.UserId] = { letter = nil, country = nil, elimMin = 0, elimMax = 27, wrongCountries = {} },
		},
		progress = {
			[playerA.UserId] = { letterKnown = false },
			[playerB.UserId] = { letterKnown = false },
		},
	}

	sessions[tableId] = session
	playerToTable[playerA.UserId] = tableId
	playerToTable[playerB.UserId] = tableId

	if _G.SeatManager and _G.SeatManager.setTablePromptEnabled then
		_G.SeatManager.setTablePromptEnabled(tableId, false)
	end
	if _G.SeatManager and _G.SeatManager.setTableLocked then
		_G.SeatManager.setTableLocked(tableId, true)
	end
	setTableStatus(tableId, "Both players are ready")
	if _G.DailyQuestMarkPlayedWithFriend then
		_G.DailyQuestMarkPlayedWithFriend(playerA, playerB)
	end
	task.spawn(function()
		for t = CFG.COUNTDOWN_START, 1, -1 do
			if not session.active then return end
			setTableCountdown(tableId, t)
			task.wait(1)
		end

		-- Countdown ended: lock now (game start)
		if _G.SeatManager and _G.SeatManager.setTableLocked then
			_G.SeatManager.setTableLocked(tableId, true)
		end

		setTableCountdown(tableId, 0)
		beginLetterPick(tableId)
	end)
	end

_G.OnBothSeated = function(tableId, playerA, playerB)
	createSession(tableId, playerA, playerB)
end
local function cancelSessionNoWinner(tableId, reason)
	local session = sessions[tableId]
	if not session or not session.active then return end

	session.active = false
	session.ending = true
	session.token += 1

	-- Optional info message (no rewards)
	fireBoth(session, E.ShowWait, reason or "Match cancelled", nil, nil, nil)

	-- Stand both players safely
	task.delay(0.2, function()
		if _G.SeatManager and _G.SeatManager.standPlayer then
			if session.playerA then _G.SeatManager.standPlayer(session.playerA, true) end
			if session.playerB then _G.SeatManager.standPlayer(session.playerB, true) end
		end
	end)

	task.delay(0.5, function()
		clearSession(tableId)
	end)
end
_G.OnPlayerStood = function(player, tableId)
	local session = sessions[tableId]
	if not session or not session.active then return end

	local other = getOtherPlayer(session, player)

	-- If gameplay has not started yet, cancel session without winner/rewards.
	if not session.started then
		cancelSessionNoWinner(tableId, "Player left before match start")
		return
	end

	-- Gameplay started: leaving counts as forfeit.
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
	if not session or not session.active then return end
	if session.phase ~= "letter-pick" and session.phase ~= "country-pick" then return end

	local secret = getSecret(session, player)
	if not secret then return end

	local upper = string.upper(tostring(letter or ""))
	if #countryListForLetter(upper) == 0 then return end

	secret.letter = upper

	-- Immediate country pick for this same player (no waiting for opponent letter)
	E.ShowCountryPick:FireClient(player, upper, countryListForLetter(upper))

	-- Keep phase open until both countries are set
	session.phase = "country-pick"
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
	E.ShowWait:FireClient(player, "Secret country chosen", nil, nil, nil)

	maybeStartGame(tableId)
end)

E.SubmitLetterGuess.OnServerEvent:Connect(function(player, guessLetter)
	local tableId = playerToTable[player.UserId]
	if not tableId then return end

	local session = sessions[tableId]
	if not session or not session.active or session.phase ~= "turn" then return end
	if session.turnPlayer ~= player then return end

	local me = getSecret(session, player)
	local meProgress = getProgress(session, player)
	local other = getOtherPlayer(session, player)
	local otherSecret = getSecret(session, other)
	if not me or not meProgress or not otherSecret or meProgress.letterKnown then return end

	local guess = string.upper(tostring(guessLetter or ""))
	if #guess ~= 1 then return end

	session.token += 1
	local token = session.token

	local askedText = "Is your letter " .. guess .. "?"
	fireBoth(session, E.ShowBillboard, player.Name, askedText, "white")

	task.delay(CFG.ASK_TO_RESPONSE_DELAY, function()
		if not session.active or session.token ~= token then return end

		local guessed = string.byte(guess) - 64
		local actual = string.byte(otherSecret.letter) - 64
		local message, result

		if guessed == actual then
			meProgress.letterKnown = true
			result = "correct"
			message = "YES"
			fireBoth(session, E.ShowBillboard, other.Name, "YES", "green")
		elseif guessed < actual then
			me.elimMin = math.max(me.elimMin, guessed)
			result = "higher"
			message = "HIGHER"
			fireBoth(session, E.ShowBillboard, other.Name, "HIGHER", "yellow")
		else
			me.elimMax = math.min(me.elimMax, guessed)
			result = "lower"
			message = "LOWER"
			fireBoth(session, E.ShowBillboard, other.Name, "LOWER", "yellow")
		end

		E.LetterGuessResult:FireClient(player, {
			result = result,
			message = message,
			eliminatedMin = me.elimMin,
			eliminatedMax = me.elimMax,
		})

		task.delay(CFG.RESPONSE_DISPLAY_TIME, function()
			if not session.active then return end
			-- Always alternate turns
			session.turnPlayer = other
			task.delay(CFG.TURN_SWITCH_BUFFER, function()
				if session.active then openTurn(session) end
			end)
		end)
	end)
end)

E.SubmitCountryGuess.OnServerEvent:Connect(function(player, countryGuess)
	local tableId = playerToTable[player.UserId]
	if not tableId then return end

	local session = sessions[tableId]
	if not session or not session.active or session.phase ~= "turn" then return end
	if session.turnPlayer ~= player then return end

	local me = getSecret(session, player)
	local meProgress = getProgress(session, player)
	local other = getOtherPlayer(session, player)
	local otherSecret = getSecret(session, other)
	if not me or not meProgress or not otherSecret or not meProgress.letterKnown then return end

	local guess = tostring(countryGuess or "")
	if guess == "" then return end

	session.token += 1
	local token = session.token

	local askedText = "Is your country " .. guess .. "?"
	fireBoth(session, E.ShowBillboard, player.Name, askedText, "white")

	task.delay(CFG.ASK_TO_RESPONSE_DELAY, function()
		if not session.active or session.token ~= token then return end

		if string.lower(guess) == string.lower(otherSecret.country) then
			fireBoth(session, E.ShowBillboard, other.Name, "YES", "green")
			E.CountryGuessResult:FireClient(player, {
				result = "correct",
				message = "YES",
				wrongList = {},
			})
			task.delay(CFG.RESPONSE_DISPLAY_TIME, function()
				if session.active then
					endSessionWithWinner(tableId, player, "country_guessed")
				end
			end)
			return
		end

		me.wrongCountries[guess] = true
		local wrongList = {}
		for name, used in pairs(me.wrongCountries) do
			if used then table.insert(wrongList, name) end
		end
		table.sort(wrongList)

		fireBoth(session, E.ShowBillboard, other.Name, "NO", "red")
		E.CountryGuessResult:FireClient(player, {
			result = "no",
			message = "NO",
			wrongName = guess,
			wrongList = wrongList,
		})

		task.delay(CFG.RESPONSE_DISPLAY_TIME, function()
			if not session.active then return end
			session.turnPlayer = other
			task.delay(CFG.TURN_SWITCH_BUFFER, function()
				if session.active then openTurn(session) end
			end)
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local tableId = playerToTable[player.UserId]
	if not tableId then return end
	local function hardCancelSession(tableId, reason)
		local session = sessions[tableId]
		if not session then return end

		session.active = false
		session.ending = true
		session.token += 1

		if _G.SeatManager and _G.SeatManager.standPlayer then
			if session.playerA then _G.SeatManager.standPlayer(session.playerA, true) end
			if session.playerB then _G.SeatManager.standPlayer(session.playerB, true) end
		end

		clearSession(tableId)
	end
	local session = sessions[tableId]
	if not session then
		playerToTable[player.UserId] = nil
		return
	end

	local other = getOtherPlayer(session, player)

	if not session.started then
		cancelSessionNoWinner(tableId, "Player disconnected before match start")
		return
	end

	if other then
		endSessionWithWinner(tableId, other, "opponent_left")
	else
		clearSession(tableId)
	end
end)

print("[GameManager] Loaded. _G.OnBothSeated =", _G.OnBothSeated ~= nil)
