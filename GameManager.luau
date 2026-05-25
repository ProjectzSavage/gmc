-- GameManager v2 (multi-table, paced turns, robust pick watchdog)
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
	SetHeadTagsVisible = event("SetHeadTagsVisible"),
}
local function ensureRemote(name)
	local r = events:FindFirstChild(name)
	if r then return r end
	r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = events
	return r
end

local PickCountdown = ensureRemote("PickCountdown")
local PickBackToLetter = ensureRemote("PickBackToLetter")
local CFG = {
	COUNTDOWN_START = 3,
	TURN_TIME = 60,
	ASK_TO_RESPONSE_DELAY = 1.2,
	RESPONSE_DISPLAY_TIME = 1.7,
	TURN_SWITCH_BUFFER = 0.65,
	POST_PICK_TO_FIRST_TURN_DELAY = 2.0,
	PICK_REMINDER_INTERVAL = 6,
	PICK_TIMEOUT = 45,
}

local REWARDS = {
	WinCash = 200,
	WinIncrease = 1,
	WinstreakIncrease = 1,
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

local function fireBillboardAll(session, targetName, text, colorName)
	E.ShowBillboard:FireAllClients(targetName, tostring(text or ""), colorName, session.tableId)
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

local function awardWinner(player)
	if not player then return end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end

	local cash = stats:FindFirstChild("Cash")
	local wins = stats:FindFirstChild("Wins")
	local winstreak = stats:FindFirstChild("Winstreak")

	local cashMult = (_G.RewardsCashMultiplier and _G.RewardsCashMultiplier(player)) or 1
	local streakMult = (_G.RewardsStreakMultiplier and _G.RewardsStreakMultiplier(player)) or 1

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

	if session.playerA and playerToTable[session.playerA.UserId] == tableId then
		playerToTable[session.playerA.UserId] = nil
	end
	if session.playerB and playerToTable[session.playerB.UserId] == tableId then
		playerToTable[session.playerB.UserId] = nil
	end

	if session.playerA and session.playerB then
		E.SetHeadTagsVisible:FireAllClients({ session.playerA.Name, session.playerB.Name }, true)
	end

	if _G.SeatManager and _G.SeatManager.setTablePromptEnabled then
		_G.SeatManager.setTablePromptEnabled(tableId, true)
	end
	if _G.SeatManager and _G.SeatManager.setTableLocked then
		_G.SeatManager.setTableLocked(tableId, false)
	end

	setTableStatus(tableId, "")
	setTableCountdown(tableId, 0)
end

local function cancelSessionNoWinner(tableId, reason)
	local session = sessions[tableId]
	if not session or not session.active then return end

	session.active = false
	session.ending = true
	session.token += 1

	fireBoth(session, E.ShowWait, reason or "Match cancelled", nil, nil, nil)

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

	awardWinner(winner)
	resetLoserStreak(loser)

	local winnerName = winner and winner.Name or "Unknown"
	fireBoth(session, E.GameOver, {
		winner = winnerName,
		reason = reason or "",
		rewardCash = REWARDS.WinCash,
	})

	if winner then
		local streak = getWinstreakValue(winner)
		local flames = string.rep("🔥", math.clamp(streak, 1, 5))
		fireBillboardAll(session, winner.Name, winner.Name .. " " .. flames, "green")
	end

	task.delay(0.35, function()
		if _G.SeatManager and _G.SeatManager.standPlayer and winner then
			_G.SeatManager.standPlayer(winner, true)
		end
	end)

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

local function getMissingPickPlayers(session)
	local missing = {}

	local aSec = getSecret(session, session.playerA)
	local bSec = getSecret(session, session.playerB)

	if not aSec or not aSec.letter then
		table.insert(missing, { player = session.playerA, need = "letter" })
	elseif not aSec.country then
		table.insert(missing, { player = session.playerA, need = "country", letter = aSec.letter })
	end

	if not bSec or not bSec.letter then
		table.insert(missing, { player = session.playerB, need = "letter" })
	elseif not bSec.country then
		table.insert(missing, { player = session.playerB, need = "country", letter = bSec.letter })
	end

	return missing
end

local function startPickWatchdog(session)
	if session.pickWatchdogStarted then return end
	session.pickWatchdogStarted = true

	local watchToken = session.token
	local startAt = os.clock()

	task.spawn(function()
		while session.active and session.token == watchToken and not session.started do
			task.wait(CFG.PICK_REMINDER_INTERVAL)

			if not session.active or session.token ~= watchToken or session.started then
				return
			end

			local missing = getMissingPickPlayers(session)
			if #missing == 0 then
				return
			end

			setTableStatus(session.tableId, "Waiting for picks...")

			for _, m in ipairs(missing) do
				if m.need == "letter" then
					E.ShowLetterPick:FireClient(m.player)
				elseif m.need == "country" then
					E.ShowCountryPick:FireClient(m.player, m.letter, countryListForLetter(m.letter))
				end
			end

			if os.clock() - startAt >= CFG.PICK_TIMEOUT then
				cancelSessionNoWinner(session.tableId, "Pick timeout - resetting table")
				return
			end
		end
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
	if session.started then return end

	local a = getSecret(session, session.playerA)
	local b = getSecret(session, session.playerB)

	if not a or not b or not a.country or not b.country then
		print(
			"[GameManager] maybeStartGame waiting",
			tableId,
			"A(letter,country)=", a and a.letter, a and a.country,
			"B(letter,country)=", b and b.letter, b and b.country
		)
		return
	end

	session.phase = "pre-turn"
	session.turnPlayer = (math.random(1, 2) == 1) and session.playerA or session.playerB
	setTableStatus(tableId, "Get ready...")

	E.SetHeadTagsVisible:FireAllClients({ session.playerA.Name, session.playerB.Name }, false)
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
	session.pickDeadline = os.time() + 30

	if not session.pickTimerRunning then
		session.pickTimerRunning = true
		task.spawn(function()
			while session.active and not session.started and os.time() <= session.pickDeadline do
				local left = math.max(0, session.pickDeadline - os.time())
				PickCountdown:FireClient(session.playerA, left)
				PickCountdown:FireClient(session.playerB, left)
				task.wait(1)
			end

			if session.active and not session.started then
				cancelSessionNoWinner(session.tableId, "Pick timeout - resetting table")
			end

			session.pickTimerRunning = false
		end)
	end

	E.ShowLetterPick:FireClient(session.playerA)
	E.ShowLetterPick:FireClient(session.playerB)
end
	PickBackToLetter.OnServerEvent:Connect(function(player)
		local tableId = playerToTable[player.UserId]
		if not tableId then return end
		local session = sessions[tableId]
		if not session or not session.active or session.started then return end

		local secret = getSecret(session, player)
		if not secret then return end

		secret.letter = nil
		secret.country = nil

		E.ShowLetterPick:FireClient(player)

		local left = math.max(0, (session.pickDeadline or os.time()) - os.time())
		PickCountdown:FireClient(player, left)
	end)
local function forceClearPlayerFromOtherSession(player)
	local oldTable = playerToTable[player.UserId]
	if not oldTable then return end
	if sessions[oldTable] then
		cancelSessionNoWinner(oldTable, "Session resync")
	else
		playerToTable[player.UserId] = nil
	end
end

local function createSession(tableId, playerA, playerB)
	if sessions[tableId] and sessions[tableId].active then return end

	forceClearPlayerFromOtherSession(playerA)
	forceClearPlayerFromOtherSession(playerB)

	local session = {
		pickDeadline = 0,
		pickTimerRunning = false,
		tableId = tableId,
		playerA = playerA,
		playerB = playerB,
		started = false,
		active = true,
		ending = false,
		phase = "countdown",
		token = 0,
		turnPlayer = nil,
		pickWatchdogStarted = false,

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

		if not session.active then return end

		if _G.SeatManager and _G.SeatManager.setTableLocked then
			_G.SeatManager.setTableLocked(tableId, true)
		end

		setTableCountdown(tableId, 0)
		beginLetterPick(tableId)
		startPickWatchdog(session)
	end)
end

_G.OnBothSeated = function(tableId, playerA, playerB)
	createSession(tableId, playerA, playerB)
end

_G.OnPlayerStood = function(player, tableId)
	local session = sessions[tableId]
	if not session or not session.active then return end

	local other = getOtherPlayer(session, player)

	if not session.started then
		cancelSessionNoWinner(tableId, "Player left before match start")
		return
	end

	if other then
		endSessionWithWinner(tableId, other, "opponent_left")
	else
		clearSession(tableId)
	end
end

E.LetterChosen.OnServerEvent:Connect(function(player, letter)
	local tableId = playerToTable[player.UserId]
	if not tableId then
		for tid, s in pairs(sessions) do
			if s.active and (s.playerA == player or s.playerB == player) then
				tableId = tid
				playerToTable[player.UserId] = tid
				break
			end
		end
		if not tableId then return end
	end

	local session = sessions[tableId]
	if not session or not session.active then return end
	if session.phase ~= "letter-pick" and session.phase ~= "country-pick" then return end

	local secret = getSecret(session, player)
	if not secret then return end

	local upper = string.upper(tostring(letter or ""))
	if #countryListForLetter(upper) == 0 then return end

	secret.letter = upper
	session.phase = "country-pick"

	E.ShowCountryPick:FireClient(player, upper, countryListForLetter(upper))
end)

E.CountryChosen.OnServerEvent:Connect(function(player, countryName)
	local tableId = playerToTable[player.UserId]
	if not tableId then
		for tid, s in pairs(sessions) do
			if s.active and (s.playerA == player or s.playerB == player) then
				tableId = tid
				playerToTable[player.UserId] = tid
				break
			end
		end
		if not tableId then return end
	end

	local session = sessions[tableId]
	if not session or not session.active then return end
	if session.phase ~= "country-pick" and session.phase ~= "letter-pick" then return end

	local secret = getSecret(session, player)
	if not secret or not secret.letter then return end

	local picked = tostring(countryName or "")
	if picked == "" then return end
	picked = picked:gsub("^%s+", ""):gsub("%s+$", "")

	if not countryExistsForLetter(secret.letter, picked) then
		warn("[GameManager] CountryRejected", player.Name, "letter=", secret.letter, "country=", picked)
		E.ShowCountryPick:FireClient(player, secret.letter, countryListForLetter(secret.letter))
		return
	end

	secret.country = picked
	E.ShowWait:FireClient(player, "Secret country chosen", nil, nil, nil)

	print("[GameManager] CountryChosen", player.Name, "table", tableId, "country", picked)
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
	fireBillboardAll(session, player.Name, askedText, "white")

	task.delay(CFG.ASK_TO_RESPONSE_DELAY, function()
		if not session.active or session.token ~= token then return end

		local guessed = string.byte(guess) - 64
		local actual = string.byte(otherSecret.letter) - 64
		local message, result

		if guessed == actual then
			meProgress.letterKnown = true
			result = "correct"
			message = "YES"
			fireBillboardAll(session, other.Name, "YES", "green")
		elseif guessed < actual then
			me.elimMin = math.max(me.elimMin, guessed)
			result = "higher"
			message = "HIGHER"
			fireBillboardAll(session, other.Name, "HIGHER", "yellow")
		else
			me.elimMax = math.min(me.elimMax, guessed)
			result = "lower"
			message = "LOWER"
			fireBillboardAll(session, other.Name, "LOWER", "yellow")
		end

		E.LetterGuessResult:FireClient(player, {
			result = result,
			message = message,
			eliminatedMin = me.elimMin,
			eliminatedMax = me.elimMax,
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
	fireBillboardAll(session, player.Name, askedText, "white")

	task.delay(CFG.ASK_TO_RESPONSE_DELAY, function()
		if not session.active or session.token ~= token then return end

		if string.lower(guess) == string.lower(otherSecret.country) then
			fireBillboardAll(session, other.Name, "YES", "green")
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

		fireBillboardAll(session, other.Name, "NO", "red")
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
task.spawn(function()
	while true do
		task.wait(10)
		local active = 0
		local waiting = 0
		local turn = 0

		for tableId, s in pairs(sessions) do
			if s.active then
				active += 1
				if s.phase == "country-pick" or s.phase == "letter-pick" then
					waiting += 1
				elseif s.phase == "turn" then
					turn += 1
				end
			end
		end

		print(string.format("[GM MON] active=%d waitingPick=%d inTurn=%d", active, waiting, turn))
	end
end)
print("[GameManager v2] Loaded. _G.OnBothSeated =", _G.OnBothSeated ~= nil)
