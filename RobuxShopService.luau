local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
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

local ShopSync = ensureEvent("ShopSync")
local ShopRequestRefresh = ensureEvent("ShopRequestRefresh")

-- Replace all id=0 with your real IDs.
local SHOP = {
	vip_pack       = { kind = "gamepass",   id = 1839628382, perk = "VIPPack" },
	double_streak = { kind = "gamepass",   id = 1840844336, perk = "DoubleStreak" },
	double_cash   = { kind = "gamepass",   id = 1841496309, perk = "DoubleCash" },
	double_wins   = { kind = "gamepass",   id = 1841592323, perk = "DoubleWins" },

	cash_300      = { kind = "devproduct", id = 3594141921, grant = { cash = 300 } },
	cash_1000     = { kind = "devproduct", id = 3594140809, grant = { cash = 1000 } },
	cash_2500     = { kind = "devproduct", id = 3594141403, grant = { cash = 2500 } },
	cash_5000     = { kind = "devproduct", id = 3594142592, grant = { cash = 5000 } },

	wins_10       = { kind = "devproduct", id = 3594139812, grant = { wins = 10 } },
	wins_25       = { kind = "devproduct", id = 3594141145, grant = { wins = 25 } },
	wins_50       = { kind = "devproduct", id = 3594142075, grant = { wins = 50 } },
	wins_100      = { kind = "devproduct", id = 3594140262, grant = { wins = 100 } },
	game_hint           = { kind = "devproduct", id = 3594143882, grant = { game_powerup = "hint" } },
	game_reveal_country = { kind = "devproduct", id = 3594145422, grant = { game_powerup = "reveal_country" } },
	game_reveal_letter  = { kind = "devproduct", id = 3594145940, grant = { game_powerup = "reveal_letter" } },
}

local PRODUCT_TO_KEY = {}
for key, def in pairs(SHOP) do
	if def.kind == "devproduct" then
		PRODUCT_TO_KEY[def.id] = key
	end
end

local function getLeaderstats(player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then return nil end
	return ls, ls:FindFirstChild("Cash"), ls:FindFirstChild("Wins")
end

local function getPerksFolder(player)
	local f = player:FindFirstChild("ShopPerks")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ShopPerks"
		f.Parent = player
	end
	return f
end

local function setPerk(player, perkName, value)
	local f = getPerksFolder(player)
	local b = f:FindFirstChild(perkName)
	if not b then
		b = Instance.new("BoolValue")
		b.Name = perkName
		b.Parent = f
	end
	b.Value = value == true
end

local function grantProduct(player, key)
	local def = SHOP[key]
	if not def or def.kind ~= "devproduct" then return end
	local _, cash, wins = getLeaderstats(player)

	if def.grant.cash and cash and cash:IsA("IntValue") then
		cash.Value += def.grant.cash
	end
	if def.grant.wins and wins and wins:IsA("IntValue") then
		wins.Value += def.grant.wins
	end

	-- Game powerup grants
	if def.grant.game_powerup then
		task.delay(0.5, function()
			if _G.ApplyGamePowerup then
				_G.ApplyGamePowerup(player, def.grant.game_powerup)
			end
		end)
	end
end

local function syncPlayer(player)
	local owned = {}
	for key, def in pairs(SHOP) do
		if def.kind == "gamepass" then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.id)
			end)
			local isOwned = ok and owns or false
			owned[key] = isOwned
			if def.perk then
				setPerk(player, def.perk, isOwned)
			end
		end
	end

	ShopSync:FireClient(player, {
		catalog = SHOP,
		owned = owned,
	})
end

ShopRequestRefresh.OnServerEvent:Connect(function(player)
	syncPlayer(player)
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- optional robux spent tracking
	local okInfo, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(receiptInfo.ProductId, Enum.InfoType.Product)
	end)
	local price = (okInfo and info and (info.PriceInRobux or info.Price)) or 0
	if _G.RewardsAddRobuxSpent then
		_G.RewardsAddRobuxSpent(player, price)
	end

	-- 1) Streak buyback FIRST
	if _G.TryHandleStreakBuybackReceipt then
		local ok, handled = pcall(function()
			return _G.TryHandleStreakBuybackReceipt(receiptInfo, player)
		end)
		if ok and handled then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		elseif not ok then
			warn("[ProcessReceipt] Streak handler error:", handled)
		end
	end

	-- 2) Existing shop devproducts
	local key = PRODUCT_TO_KEY[receiptInfo.ProductId]
	if key then
		grantProduct(player, key)
		task.defer(function()
			syncPlayer(player)
		end)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- 3) Existing game powerups
	if _G.GamePowerupProductToType then
		local pType = _G.GamePowerupProductToType[receiptInfo.ProductId]
		if pType then
			task.delay(0.5, function()
				if _G.ApplyGamePowerup then
					_G.ApplyGamePowerup(player, pType)
				end
			end)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	-- 4) Existing steal receipt handler (if used)
	if _G.TryHandleStealReceipt then
		local ok, handled = pcall(function()
			return _G.TryHandleStealReceipt(receiptInfo, player)
		end)
		if ok and handled then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		elseif not ok then
			warn("[ProcessReceipt] Steal handler error:", handled)
		end
	end

	-- unknown product fallback
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		syncPlayer(player)
	end)
end)

print("[RobuxShopService] Ready")
