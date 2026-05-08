local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("GameGui")

local openBtn = gui:WaitForChild("OpenShopBtn")
local shop = gui:WaitForChild("ShopF")
local scroll = shop:WaitForChild("Scroll")
local closeBtn = shop:FindFirstChild("CloseBtn")

local Events = RS:WaitForChild("Events")
local ShopSync = Events:WaitForChild("ShopSync")
local ShopRequestRefresh = Events:WaitForChild("ShopRequestRefresh")

local FRAME_TO_KEY = {
	VIPPack = "vip_pack",
	DoubleStreak = "double_streak",
	DoubleCash = "double_cash",
	DoubleWins = "double_wins",

	Cash300 = "cash_300",
	Cash1000 = "cash_1000",
	Cash2500 = "cash_2500",
	Cash5000 = "cash_5000",

	Wins10 = "wins_10",
	Wins25 = "wins_25",
	Wins50 = "wins_50",
	Wins100 = "wins_100",
}

local catalog = {}
local owned = {}
local refs = {}
local priceCache = {}

for frameName, key in pairs(FRAME_TO_KEY) do
	local row = scroll:FindFirstChild(frameName)
	if row and row:IsA("Frame") then
		refs[key] = {
			row = row,
			buyBtn = row:FindFirstChild("BuyBtn"),
		}
	end
end

local function getRobuxPrice(kind, id)
	local cacheKey = tostring(kind) .. ":" .. tostring(id)
	if priceCache[cacheKey] then return priceCache[cacheKey] end

	local infoType = (kind == "gamepass") and Enum.InfoType.GamePass or Enum.InfoType.Product
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType)
	end)

	local text = "R$ ?"
	if ok and info then
		local p = info.PriceInRobux or info.Price
		if typeof(p) == "number" then
			text = "" .. tostring(p)
		end
	end

	priceCache[cacheKey] = text
	return text
end

local function promptPurchase(key)
	local def = catalog[key]
	if not def then return end

	if def.kind == "gamepass" then
		MarketplaceService:PromptGamePassPurchase(player, def.id)
	elseif def.kind == "devproduct" then
		MarketplaceService:PromptProductPurchase(player, def.id)
	end
end

local function applyRowState(key)
	local def = catalog[key]
	local r = refs[key]
	if not def or not r or not r.buyBtn or not r.buyBtn:IsA("TextButton") then return end

	if def.kind == "gamepass" and owned[key] == true then
		r.buyBtn.Text = "OWN"
		r.buyBtn.Active = false
		r.buyBtn.AutoButtonColor = false
		r.buyBtn.BackgroundColor3 = Color3.fromRGB(50, 190, 70)
		return
	end

	-- By request: do NOT touch PriceLbl. Use BuyBtn text only.
	r.buyBtn.Text = getRobuxPrice(def.kind, def.id)
	r.buyBtn.Active = true
	r.buyBtn.AutoButtonColor = false
	r.buyBtn.BackgroundColor3 = Color3.fromRGB(45, 225, 70)
end

for key, r in pairs(refs) do
	if r.buyBtn and r.buyBtn:IsA("TextButton") then
		r.buyBtn.MouseButton1Click:Connect(function()
			promptPurchase(key)
		end)
	end
end

shop.Visible = false

openBtn.MouseButton1Click:Connect(function()
	shop.Visible = not shop.Visible
	if shop.Visible then
		ShopRequestRefresh:FireServer()
	end
end)

if closeBtn and closeBtn:IsA("TextButton") then
	closeBtn.MouseButton1Click:Connect(function()
		shop.Visible = false
	end)
end

ShopSync.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	catalog = payload.catalog or {}
	owned = payload.owned or {}

	for key in pairs(refs) do
		applyRowState(key)
	end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p)
	if p ~= player then return end
	task.delay(0.3, function()
		ShopRequestRefresh:FireServer()
	end)
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId)
	if userId ~= player.UserId then return end
	task.delay(0.3, function()
		ShopRequestRefresh:FireServer()
	end)
end)

print("[ShopController] Ready")