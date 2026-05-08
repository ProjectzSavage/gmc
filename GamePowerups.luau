-- GamePowerups - Server Script
-- Place in ServerScriptService
-- FIXED: Always applies effect, inventory optional

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Events = RS:WaitForChild("Events")

local function ensureEvent(name)
	local e = Events:FindFirstChild(name)
	if e then return e end
	e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = Events
	return e
end

local GamePowerupEffect = ensureEvent("GamePowerupEffect")
local GuessPhaseStart = ensureEvent("GuessPhaseStart")
local NotifyPlayer = Events:WaitForChild("NotifyPlayer")
local TestGamePowerup = ensureEvent("TestGamePowerup")
local UseFreePowerup = ensureEvent("UseFreePowerup")

local POWERUP_PRODUCTS = {
	hint = 0,
	reveal_country = 0,
	reveal_letter = 0,
}

local PRODUCT_TO_TYPE = {}
for ptype, id in pairs(POWERUP_PRODUCTS) do
	if id ~= 0 then PRODUCT_TO_TYPE[id] = ptype end
end

local POWERUP_TO_INV = {
	hint = "magnifier",
	reveal_country = "hook",
	reveal_letter = "mystery",
}

----------------------------------------------------------------
-- Find country entry
----------------------------------------------------------------
local function findCountryEntry(countryName)
	local CountryData = require(RS:WaitForChild("CountryData"))
	local letter = string.upper(string.sub(countryName, 1, 1))
	local list = CountryData.ByLetter[letter] or {}
	for _, c in ipairs(list) do
		if string.lower(c.name) == string.lower(countryName) then
			return c
		end
	end
	return nil
end

----------------------------------------------------------------
-- Build random hint
----------------------------------------------------------------
local function buildRandomHint(countryName)
	local entry = findCountryEntry(countryName)
	if entry then
		local hints = {}
		table.insert(hints, { title = "Hint: Continent", message = "Opponent's country is in: " .. tostring(entry.continent or "Unknown") })
		if entry.population then table.insert(hints, { title = "Hint: Population", message = "Population: " .. tostring(entry.population) }) end
		if entry.economy then table.insert(hints, { title = "Hint: Economy", message = "Economy: " .. tostring(entry.economy) }) end
		if entry.flagColors and #entry.flagColors > 0 then table.insert(hints, { title = "Hint: Flag Colors", message = "Flag: " .. table.concat(entry.flagColors, ", ") }) end
		if entry.capitalLetter then table.insert(hints, { title = "Hint: Capital", message = "Capital starts with: " .. tostring(entry.capitalLetter) }) end
		if #hints > 0 then
			local pick = hints[math.random(1, #hints)]
			return pick.title, pick.message
		end
	end
	local CountryData = require(RS:WaitForChild("CountryData"))
	local letter = string.upper(string.sub(countryName, 1, 1))
	local list = CountryData.ByLetter[letter] or {}
	local continent = "Unknown"
	for _, c in ipairs(list) do
		if string.lower(c.name) == string.lower(countryName) then continent = c.continent or "Unknown"; break end
	end
	return "Hint: Continent", "Opponent's country is in: " .. continent
end

----------------------------------------------------------------
-- Try deduct from inventory (returns true/false, doesn't block)
----------------------------------------------------------------
local function tryDeductInventory(player, powerupType)
	local invKey = POWERUP_TO_INV[powerupType]

	-- Try _G.RewardsUsePowerup
	if _G.RewardsUsePowerup then
		local ok, result = pcall(function() return _G.RewardsUsePowerup(player, powerupType) end)
		if ok and result then return true end
	end

	-- Try direct data access
	if _G.RewardsPlayerData then
		local ok, data = pcall(function() return _G.RewardsPlayerData(player) end)
		if ok and data and data.powerups then
			local count = data.powerups[invKey] or 0
			if count > 0 then
				data.powerups[invKey] = count - 1
				pcall(function() if _G.RewardsSaveData then _G.RewardsSaveData(player) end end)
				pcall(function() if _G.RewardsSyncPlayer then _G.RewardsSyncPlayer(player) end end)
				return true
			end
		end
	end

	return false
end

----------------------------------------------------------------
-- Apply effect
----------------------------------------------------------------
_G.ApplyGamePowerup = function(player, powerupType)
	local session = _G.CurrentGameSession
	if not session or not session.active then
		NotifyPlayer:FireClient(player, {
			title = "No Active Game", message = "No active game.",
			kind = "warn", duration = 3,
		})
		return false
	end
	if player ~= session.playerA and player ~= session.playerB then return false end
	local other = (player == session.playerA) and session.playerB or session.playerA
	if not other then return false end
	local oppSecret = session.secret[other.UserId]
	if not oppSecret then return false end

	if powerupType == "hint" then
		local country = oppSecret.country
		if not country then return false end
		local ht, hm = buildRandomHint(country)
		GamePowerupEffect:FireClient(player, { type = "hint", title = ht, message = hm, duration = 4 })
		return true
	elseif powerupType == "reveal_country" then
		local country = oppSecret.country
		if not country then return false end
		GamePowerupEffect:FireClient(player, { type = "reveal_country", title = "Country Revealed!", message = "Opponent's country is: " .. country, duration = 5 })
		return true
	elseif powerupType == "reveal_letter" then
		local letter = oppSecret.letter
		if not letter then return false end
		GamePowerupEffect:FireClient(player, { type = "reveal_letter", title = "Letter Revealed!", message = "Opponent's letter is: " .. letter, duration = 5 })
		return true
	end
	return false
end

_G.GamePowerupProductToType = PRODUCT_TO_TYPE

-- Free powerup: try inventory, ALWAYS apply effect
UseFreePowerup.OnServerEvent:Connect(function(player, powerupType)
	print("[GamePowerups] Free request:", player.Name, powerupType)
	local used = tryDeductInventory(player, powerupType)
	if used then
		print("[GamePowerups] Deducted from inventory")
	else
		print("[GamePowerups] No inventory found, applying free")
	end
	-- ALWAYS apply the effect
	_G.ApplyGamePowerup(player, powerupType)
end)

-- Studio test
TestGamePowerup.OnServerEvent:Connect(function(player, powerupType)
	print("[GamePowerups] TEST:", player.Name, powerupType)
	_G.ApplyGamePowerup(player, powerupType)
end)

print("[GamePowerups] Ready")