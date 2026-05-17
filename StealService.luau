local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = RS:WaitForChild("Events")

local function ensureEvent(name)
	local e = Events:FindFirstChild(name)
	if e then return e end
	e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = Events
	return e
end

local StealRequest = ensureEvent("StealRequest")
local StealQuote = ensureEvent("StealQuote")
local TestSteal = ensureEvent("TestSteal")
local NotifyPlayer = Events:WaitForChild("NotifyPlayer")

local TEXT = {
	TitleSuccess = "Steal Successful",
	TitleFail = "Steal Failed",
	SuccessThief = "You stole $%s from %s",
	SuccessVictim = "%s stole $%s from you",
	NoTarget = "No valid target nearby.",
	TooPoor = "%s has no cash.",
}

local TIERS = {
	{ minCash = 0,      maxCash = 999,      robux = 9,   productId = 3594146537, label = "Street Pick" },
	{ minCash = 1000,   maxCash = 4999,     robux = 19,  productId = 3594144490, label = "Night Snatch" },
	{ minCash = 5000,   maxCash = 19999,    robux = 49,  productId = 3594142948, label = "Bank Swipe" },
	{ minCash = 20000,  maxCash = 49999,    robux = 89,  productId = 3594147034, label = "Vault Crack" },
	{ minCash = 50000,  maxCash = 99999,    robux = 129, productId = 3594143136, label = "Grand Heist" },
	{ minCash = 100000, maxCash = 99999999, robux = 199, productId = 3594144009, label = "Legendary Raid" },
}

local pendingTarget = {}
local PRODUCT_TO_TIER = {}
for _, t in ipairs(TIERS) do
	if t.productId ~= 0 then PRODUCT_TO_TIER[t.productId] = t end
end

local function getCashValue(plr)
	local ls = plr:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then return cash end
	return nil
end

local function getTier(cash)
	for _, t in ipairs(TIERS) do
		if cash >= t.minCash and cash <= t.maxCash then return t end
	end
	return nil
end

local function executeSteal(thief, victim)
	local tCash = getCashValue(thief)
	local vCash = getCashValue(victim)
	if not tCash or not vCash then return end

	local stolen = vCash.Value
	if stolen <= 0 then
		NotifyPlayer:FireClient(thief, {
			title = TEXT.TitleFail,
			message = string.format(TEXT.TooPoor, victim.Name),
			kind = "warn",
			duration = 3,
		})
		return
	end

	vCash.Value = 0
	tCash.Value += stolen

	NotifyPlayer:FireClient(thief, {
		title = TEXT.TitleSuccess,
		message = string.format(TEXT.SuccessThief, tostring(stolen), victim.Name),
		kind = "success",
		duration = 4,
	})

	NotifyPlayer:FireClient(victim, {
		title = "You Were Robbed",
		message = string.format(TEXT.SuccessVictim, thief.Name, tostring(stolen)),
		kind = "error",
		duration = 4,
	})
end

StealRequest.OnServerEvent:Connect(function(player, targetUserId)
	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or -1)
	if not target or target == player then return end

	local pHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local tHrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not pHrp or not tHrp then return end

	if (pHrp.Position - tHrp.Position).Magnitude > 999999999999999 then
		NotifyPlayer:FireClient(player, {
			title = TEXT.TitleFail,
			message = TEXT.NoTarget,
			kind = "warn",
			duration = 2.5,
		})
		return
	end

	local vCash = getCashValue(target)
	local amount = vCash and vCash.Value or 0
	local tier = getTier(amount)

	if not tier then
		StealQuote:FireClient(player, {
			canSteal = false,
			targetName = target.Name,
			targetCash = amount,
			message = string.format(TEXT.TooPoor, target.Name),
		})
		return
	end

	-- Studio or no product configured: direct steal
	if RunService:IsStudio() or tier.productId == 0 then
		executeSteal(player, target)
		return
	end

	pendingTarget[player.UserId] = target.UserId
	StealQuote:FireClient(player, {
		canSteal = true,
		targetName = target.Name,
		targetCash = amount,
		wouldSteal = amount,
		robuxCost = tier.robux,
		label = tier.label,
		productId = tier.productId,
	})
end)

TestSteal.OnServerEvent:Connect(function(player, targetUserId)
	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or -1)
	if target and target ~= player then
		executeSteal(player, target)
	end
end)

_G.TryHandleStealReceipt = function(receiptInfo, buyerPlayer)
	local tier = PRODUCT_TO_TIER[receiptInfo.ProductId]
	if not tier then return false end

	local targetUserId = pendingTarget[buyerPlayer.UserId]
	pendingTarget[buyerPlayer.UserId] = nil
	if not targetUserId then
		NotifyPlayer:FireClient(buyerPlayer, {
			title = TEXT.TitleFail,
			message = TEXT.NoTarget,
			kind = "warn",
			duration = 2.5,
		})
		return true
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == buyerPlayer then
		NotifyPlayer:FireClient(buyerPlayer, {
			title = TEXT.TitleFail,
			message = TEXT.NoTarget,
			kind = "warn",
			duration = 2.5,
		})
		return true
	end

	executeSteal(buyerPlayer, target)
	return true
end

print("[StealService] Ready")
