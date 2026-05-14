local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local DS = game:GetService("DataStoreService"):GetDataStore("GMC_Chairs_V1")
local GROUP_ID = 35973544 -- TODO: replace with your Roblox group id
-- 1. SETUP EVENTS
local Events = RS:WaitForChild("Events")
local function ensureEvent(name, class)
	local e = Events:FindFirstChild(name)
	if not e then e = Instance.new(class); e.Name = name; e.Parent = Events end
	return e
end

local EquipChair = ensureEvent("EquipChair", "RemoteEvent")
local ChairSync = ensureEvent("ChairSync", "RemoteEvent")
local NotifyPlayer = ensureEvent("NotifyPlayer", "RemoteEvent")
local RequestSync = ensureEvent("RequestSync", "RemoteFunction")
local MarketplaceService = game:GetService("MarketplaceService")

local RAINBOW_BLOODMOON_PASS_ID = 1840862526 -- TODO: replace with your gamepass id
local PASS_CHAIRS = { "Rainbow", "Bloodmoon" }
-- 2. CONFIG & FOLDERS
local REFRESH_INTERVAL = 30
local SHOP_HEIGHT_OFFSET = 0.15
local CHAIR_POOL = {
	Common = {"Cardboard","Rusty","Metal","Sand","Joker"},
	Uncommon = {"Rock","Grass","Ice","Candy"},
	Rare = {"Shiny","Snow","Brick","Water","Magma","Mirror"},
	Legendary = {"Lava","Zap","Radioactive","Angel","Demon"},
	Secret = {"Pure","Void"}
}
local CHAIR_PRICES = {
	Cardboard=200, Metal=400, Rusty=600, Sand=800, Joker=900, Grass=1000, Rock=1400, 
	Brick=1800, Candy=2400, Ice=3000, Snow=4000, Shiny=5000, Mirror=6500, Magma=8000, 
	Water=7000, Zap=12000, Radioactive=16000, Lava=20000, Demon=24000, Angel=30000, 
	Pure=50000, Void=50000
}

local ShopChairs = RS:WaitForChild("Chairs"):WaitForChild("ShopChairs")
local Podium = workspace:WaitForChild("ChairPodium")
local Pads = {
	Common = Podium:WaitForChild("CommonPad"),
	Uncommon1 = Podium:WaitForChild("UncommonPad1"),
	Uncommon2 = Podium:WaitForChild("UncommonPad2"),
	Rare1 = Podium:WaitForChild("RarePad1"),
	Rare2 = Podium:WaitForChild("RarePad2"),
	LegSec = Podium:WaitForChild("LegSecPad"),
}
local CountdownLbl = Podium:WaitForChild("CountdownPart"):WaitForChild("CountdownLabel"):WaitForChild("Text"):WaitForChild("ChairLbl")

local playerData = {}
local function saveChairData(userId)
	local data = playerData[userId]
	if not data then return end
	pcall(function()
		DS:SetAsync("c_" .. userId, data)
	end)
end
local function grantPassChairs(player)
	local data = playerData[player.UserId]
	if not data then return end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, RAINBOW_BLOODMOON_PASS_ID)
	end)
	if not ok or not owns then return end

	local changed = false
	for _, chairName in ipairs(PASS_CHAIRS) do
		if not table.find(data.owned, chairName) then
			table.insert(data.owned, chairName)
			changed = true
		end
	end

	if changed then
		pcall(function()
			DS:SetAsync("c_" .. player.UserId, data)
		end)
		ChairSync:FireClient(player, data)
		NotifyPlayer:FireClient(player, {
			title = "Gamepass Chairs",
			message = "Rainbow + Bloodmoon unlocked",
			kind = "success",
			duration = 3,
		})
	end
end
local function hasChair(data, chairName)
	if not data or type(data.owned) ~= "table" then return false end
	return table.find(data.owned, chairName) ~= nil
end

local function grantChair(player, chairName, notifyText)
	local data = playerData[player.UserId]
	if not data then return false end

	if not hasChair(data, chairName) then
		table.insert(data.owned, chairName)
		saveChairData(player.UserId)
		ChairSync:FireClient(player, data)
		if notifyText and NotifyPlayer then
			NotifyPlayer:FireClient(player, {
				title = "Chair Unlocked",
				message = notifyText,
				kind = "success",
				duration = 3,
			})
		end
		return true
	end

	return false
end

-- 3. GLOBAL HELPER
_G.GetEquippedChair = function(p)
	if not p or not playerData[p.UserId] then return "Default" end
	return playerData[p.UserId].equipped or "Default"
end
_G.PlayerOwnsChair = function(player, chairName)
	local data = player and playerData[player.UserId]
	return hasChair(data, chairName)
end

_G.ChairGrantToPlayer = function(player, chairName, notifyText)
	if not player or not chairName then return false end
	return grantChair(player, chairName, notifyText)
end

_G.ChairGrantMystery = function(player, count, pool)
	local data = player and playerData[player.UserId]
	if not data then return {} end

	count = math.max(1, tonumber(count) or 1)
	local granted = {}

	for _ = 1, count do
		local candidates = {}
		for _, chairName in ipairs(pool) do
			if not hasChair(data, chairName) then
				table.insert(candidates, chairName)
			end
		end
		if #candidates == 0 then break end

		local pick = candidates[math.random(1, #candidates)]
		if grantChair(player, pick, nil) then
			table.insert(granted, pick)
		end
	end

	if #granted > 0 and NotifyPlayer then
		NotifyPlayer:FireClient(player, {
			title = "Mystery Reward",
			message = "You got: " .. table.concat(granted, ", "),
			kind = "success",
			duration = 4,
		})
	end

	return granted
end
-- 4. PLACEMENT LOGIC
local function placeOnPad(pad, name)
	for _, c in ipairs(pad:GetChildren()) do 
		if c:IsA("Model") or c:IsA("ProximityPrompt") then c:Destroy() end 
	end

	local m = ShopChairs:FindFirstChild(name)
	if not m then return end

	local clone = m:Clone()
	clone.Name = "ShopChair"
	clone.Parent = pad
	local _, size = clone:GetBoundingBox()
	clone:PivotTo(pad.CFrame * CFrame.new(0, (size.Y/2) + SHOP_HEIGHT_OFFSET, 0))

	local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
	if primary then
		primary.Anchored = true
		local startCF = clone:GetPivot()
		task.spawn(function()
			local angle = 0
			while clone and clone.Parent do
				angle += 0.02
				clone:PivotTo(startCF * CFrame.Angles(0, angle, 0) * CFrame.new(0, math.sin(tick()*2)*0.25, 0))
				RunService.Heartbeat:Wait()
			end
		end)
	end

	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Buy " .. name
	pr.ObjectText = "$" .. (CHAIR_PRICES[name] or 1000)
	pr.Parent = pad
	pr.Triggered:Connect(function(player)
		local data = playerData[player.UserId]
		if not data or table.find(data.owned, name) then return end
		local cash = player.leaderstats.Cash
		local cost = CHAIR_PRICES[name] or 1000
		if cash.Value >= cost then
			cash.Value -= cost
			table.insert(data.owned, name)
			ChairSync:FireClient(player, data)
			NotifyPlayer:FireClient(player, {title="Purchased", message=name, kind="success"})
		end
	end)
end

local function refreshAll()
	local rng = Random.new()
	local isSecret = rng:NextNumber(0, 100) < 4
	local picks = {
		Common = CHAIR_POOL.Common[rng:NextInteger(1, #CHAIR_POOL.Common)],
		Uncommon1 = CHAIR_POOL.Uncommon[rng:NextInteger(1, #CHAIR_POOL.Uncommon)],
		Uncommon2 = CHAIR_POOL.Uncommon[rng:NextInteger(1, #CHAIR_POOL.Uncommon)],
		Rare1 = CHAIR_POOL.Rare[rng:NextInteger(1, #CHAIR_POOL.Rare)],
		Rare2 = CHAIR_POOL.Rare[rng:NextInteger(1, #CHAIR_POOL.Rare)],
		LegSec = isSecret and CHAIR_POOL.Secret[rng:NextInteger(1, #CHAIR_POOL.Secret)] or CHAIR_POOL.Legendary[rng:NextInteger(1, #CHAIR_POOL.Legendary)]
	}
	for key, pad in pairs(Pads) do placeOnPad(pad, picks[key]) end
end

-- 5. DATA & EVENTS
Players.PlayerAdded:Connect(function(p)
	local ok, d = pcall(function() return DS:GetAsync("c_"..p.UserId) end)
	playerData[p.UserId] = (ok and d) or { owned = {"Default"}, equipped = "Default" }
	local data = playerData[p.UserId]
	if data then
		data.owned = data.owned or {"Default"}
		data.equipped = data.equipped or "Default"
		grantPassChairs(p)
		local ok, inGroup = pcall(function()
			return GROUP_ID > 0 and p:IsInGroupAsync(GROUP_ID)
		end)

		if ok and inGroup then
			if not table.find(data.owned, "Deer") then
				table.insert(data.owned, "Deer")
				pcall(function() DS:SetAsync("c_" .. p.UserId, data) end)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	if playerData[p.UserId] then pcall(function() DS:SetAsync("c_"..p.UserId, playerData[p.UserId]) end) end
	playerData[p.UserId] = nil
end)

-- THE MISSING EQUIP EVENT
EquipChair.OnServerEvent:Connect(function(p, name)
	local data = playerData[p.UserId]
	if data and table.find(data.owned, name) then
		data.equipped = name
		ChairSync:FireClient(p, data)
		NotifyPlayer:FireClient(p, {title="Equipped", message=name, kind="info"})
	end
end)

RequestSync.OnServerInvoke = function(p) grantPassChairs(p)
	return playerData[p.UserId] end

task.spawn(function()
	while true do
		local diff = REFRESH_INTERVAL - (os.time() % REFRESH_INTERVAL)
		CountdownLbl.Text = string.format("%02d:%02d", math.floor(diff/60), diff%60)
		if diff <= 1 then task.wait(1.1); refreshAll() end
		task.wait(1)
	end
end)

refreshAll()
