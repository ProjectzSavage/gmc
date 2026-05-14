local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local NumberFormat = require(RS:WaitForChild("NumberFormat"))

local localPlayer = Players.LocalPlayer
local Events = RS:WaitForChild("Events")
local StealRequest = Events:WaitForChild("StealRequest")
local StealQuote = Events:WaitForChild("StealQuote")
local TestSteal = Events:WaitForChild("TestSteal")

local IS_STUDIO = RunService:IsStudio()

local function compact(n)
	return NumberFormat.compact(n)
end

local function getCashValue(plr)
	local ls = plr:FindFirstChild("leaderstats") or plr:WaitForChild("leaderstats", 15)
	local cash = ls and (ls:FindFirstChild("Cash") or ls:WaitForChild("Cash", 15))
	return cash
end

local function attachCashTag(plr)
	if plr == localPlayer then return end
	local char = plr.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end

	local old = head:FindFirstChild("OtherCashTag")
	if old then old:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name = "OtherCashTag"
	bb.Size = UDim2.new(4, 0, 0.8, 0)
	bb.StudsOffset = Vector3.new(0, -2.5, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 45
	bb.Parent = head

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(15, 20, 35)
	frame.BackgroundTransparency = 0.15
	frame.Parent = bb
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -8, 1, 0)
	lbl.Position = UDim2.new(0, 4, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
	lbl.TextStrokeTransparency = 0.25
	lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	lbl.Parent = frame

	local cash = getCashValue(plr)
	local function update()
		if not lbl or not lbl.Parent then return end
		local v = (cash and cash.Value) or 0
		lbl.Text = "Cash: $" .. compact(v)
	end

	if cash then
		cash:GetPropertyChangedSignal("Value"):Connect(update)
	end
	update()
end

local function attachStealPrompt(plr)
	if plr == localPlayer then return end
	local char = plr.Character
	local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 15))
	if not hrp then return end

	local old = hrp:FindFirstChild("StealPrompt")
	if old then old:Destroy() end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = plr.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = hrp

	local cash = getCashValue(plr)
	local function updatePrompt()
		local v = (cash and cash.Value) or 0
		prompt.ObjectText = plr.Name .. " | $" .. compact(v)
		prompt.Enabled = v > 0
	end

	if cash then
		cash:GetPropertyChangedSignal("Value"):Connect(updatePrompt)
	end
	updatePrompt()

	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= localPlayer then return end
		if IS_STUDIO then
			TestSteal:FireServer(plr.UserId)
		else
			StealRequest:FireServer(plr.UserId)
		end
	end)
end

local function hook(plr)
	if plr == localPlayer then return end

	plr.CharacterAdded:Connect(function()
		task.wait(0.35)
		attachCashTag(plr)
		attachStealPrompt(plr)
	end)

	if plr.Character then
		task.defer(function()
			attachCashTag(plr)
			attachStealPrompt(plr)
		end)
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	hook(p)
end
Players.PlayerAdded:Connect(hook)

StealQuote.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if not data.canSteal then return end
	if IS_STUDIO then return end
	local productId = tonumber(data.productId) or 0
	if productId > 0 then
		MarketplaceService:PromptProductPurchase(localPlayer, productId)
	end
end)

print("[CashDisplayController] Ready")
