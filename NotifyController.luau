local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gameGui = player:WaitForChild("PlayerGui"):WaitForChild("GameGui")
local events = RS:WaitForChild("Events")
local notifyEvent = events:WaitForChild("NotifyPlayer")

local root = gameGui:WaitForChild("NotifyF")
root.Visible = true
root.AnchorPoint = Vector2.new(0.5, 0)
root.Size = UDim2.new(0.446, 0, 0.056, 0)
root.Position = UDim2.new(0.5, 0, 0.56, 0) -- safe top position for mobile
root.BackgroundTransparency = 1

local function getTargetPosition()
	-- keep on-screen for all devices
	if _G and _G.ActiveBotTableId ~= nil then
		return UDim2.fromScale(0.5, 0.56)
	end
	return UDim2.fromScale(0.5, 0.56)
end
local function refreshPosition()
	local pos = getTargetPosition()
	if typeof(pos) ~= "UDim2" then
		pos = UDim2.new(0.5, -190, 0, 0)
	end
	root.Position = pos
end

local list = root:FindFirstChildOfClass("UIListLayout")
if not list then
	list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = root
end

local pad = root:FindFirstChildOfClass("UIPadding")
if not pad then
	pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.Parent = root
end

local function accentFor(kind)
	if kind == "success" then return Color3.fromRGB(74, 222, 128) end
	if kind == "warn" then return Color3.fromRGB(250, 204, 21) end
	if kind == "error" then return Color3.fromRGB(248, 113, 113) end
	if kind == "robux" then return Color3.fromRGB(74, 222, 128) end
	return Color3.fromRGB(125, 211, 252)
end

local function newCard(title, msg, kind)
	local accent = accentFor(kind)

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 58)                                         -- card.Size = UDim2.new(1, 0, 0.115, 0)
	card.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	card.BackgroundTransparency = 0.08
	card.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.18, 0)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1.4
	stroke.Parent = card

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0.012, 0, 0.98, 0)
	bar.Position = UDim2.new(0.02, 0, 0.11, 0)
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = accent
	bar.Parent = card

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0.5, 0)
	barCorner.Parent = bar

	local titleLbl = Instance.new("TextLabel")
	titleLbl.BackgroundTransparency = 1
	titleLbl.Size = UDim2.new(0.9, 0, 0.16, 0)
	titleLbl.Position = UDim2.new(0.07, 0, 0.08, 0)
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Font = Enum.Font.FredokaOne
	titleLbl.TextScaled = true
	titleLbl.TextColor3 = accent
	titleLbl.Text = tostring(title or "Notification")
	titleLbl.Parent = card

	local msgLbl = Instance.new("TextLabel")
	msgLbl.BackgroundTransparency = 1
	msgLbl.Size = UDim2.new(0.9, 0, 0.36, 0)
	msgLbl.Position = UDim2.new(0.07, 0, 0.48, 0)
	msgLbl.TextXAlignment = Enum.TextXAlignment.Left
	msgLbl.Font = Enum.Font.FredokaOne
	msgLbl.TextScaled = true
	msgLbl.TextColor3 = Color3.fromRGB(226, 232, 240)
	msgLbl.TextTruncate = Enum.TextTruncate.AtEnd
	msgLbl.Text = tostring(msg or "")
	msgLbl.Parent = card

	return card
end

notifyEvent.OnClientEvent:Connect(function(payload)
	refreshPosition()

	if type(payload) ~= "table" then return end
	local card = newCard(payload.title, payload.message, payload.kind)
	local duration = tonumber(payload.duration) or 2.5

	card.BackgroundTransparency = 1
	card.Position = UDim2.new(0, 0, 0, -12)

	TweenService:Create(card, TweenInfo.new(0.16), {
		BackgroundTransparency = 0.08,
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()

	task.delay(duration, function()
		if not card or not card.Parent then return end
		local out = TweenService:Create(card, TweenInfo.new(0.2), {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
		})
		out:Play()
		out.Completed:Wait()
		if card and card.Parent then
			card:Destroy()
		end
	end)
end)

task.spawn(function()
	while true do
		refreshPosition()
		task.wait(0.2)
	end
end)
