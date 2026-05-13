-- NotifyController - Uses existing NotifyF, stacks
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gameGui = player:WaitForChild("PlayerGui"):WaitForChild("GameGui")
local Events = RS:WaitForChild("Events")
local NotifyPlayer = Events:WaitForChild("NotifyPlayer")

local root = gameGui:WaitForChild("NotifyF")
root.Visible = true; root.BackgroundTransparency = 1
root.Size = UDim2.new(0, 380, 1, 0); root.Position = UDim2.new(0.5, -190, 0, -100); root.AnchorPoint = Vector2.new(0, 0)

local oldTitle = root:FindFirstChild("TitleLbl")
local oldMsg = root:FindFirstChild("MsgLbl")
if oldTitle then oldTitle.Visible = false end
if oldMsg then oldMsg.Visible = false end

if not root:FindFirstChildOfClass("UIListLayout") then
	local layout = Instance.new("UIListLayout"); layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8); layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; layout.Parent = root
end
if not root:FindFirstChildOfClass("UIPadding") then
	local pad = Instance.new("UIPadding"); pad.PaddingBottom = UDim.new(0, 16); pad.Parent = root
end

local nextOrder = 0
local function colorsFor(kind)
	if kind == "success" then return Color3.fromRGB(55,230,95)
	elseif kind == "warn" then return Color3.fromRGB(255,190,70)
	elseif kind == "error" then return Color3.fromRGB(255,90,90)
	elseif kind == "robux" then return Color3.fromRGB(0,255,100)
	end
	return Color3.fromRGB(120,220,255)
end

NotifyPlayer.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	local title = tostring(payload.title or "Notification")
	local message = tostring(payload.message or "")
	local kind = tostring(payload.kind or "info")
	local duration = tonumber(payload.duration) or 2.5
	local accent = colorsFor(kind)
	nextOrder += 1

	local card = Instance.new("Frame"); card.Name="NotifyCard_"..nextOrder; card.Size=UDim2.new(1,0,0,60)
	card.BackgroundColor3=Color3.fromRGB(12,16,30); card.BackgroundTransparency=1; card.LayoutOrder=nextOrder; card.ZIndex=50; card.Parent=root
	Instance.new("UICorner",card).CornerRadius=UDim.new(0,12)
	local stroke=Instance.new("UIStroke",card); stroke.Color=accent; stroke.Thickness=1.2; stroke.Transparency=1
	local bar=Instance.new("Frame"); bar.Size=UDim2.new(0,4,0.7,0); bar.Position=UDim2.new(0,6,0.15,0)
	bar.BackgroundColor3=accent; bar.BackgroundTransparency=1; bar.ZIndex=51; bar.Parent=card; Instance.new("UICorner",bar).CornerRadius=UDim.new(0,2)

	local tl=Instance.new("TextLabel"); tl.Size=UDim2.new(1,-24,0,22); tl.Position=UDim2.new(0,18,0,6)
	tl.BackgroundTransparency=1; tl.Text=title; tl.Font=Enum.Font.GothamBold; tl.TextSize=14
	tl.TextColor3=accent; tl.TextTransparency=1; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.ZIndex=51; tl.Parent=card
	local ml=Instance.new("TextLabel"); ml.Size=UDim2.new(1,-24,0,22); ml.Position=UDim2.new(0,18,0,30)
	ml.BackgroundTransparency=1; ml.Text=message; ml.Font=Enum.Font.Gotham; ml.TextSize=13
	ml.TextColor3=Color3.fromRGB(200,210,230); ml.TextTransparency=1; ml.TextXAlignment=Enum.TextXAlignment.Left; ml.TextTruncate=Enum.TextTruncate.AtEnd; ml.ZIndex=51; ml.Parent=card

	root.Visible = true
	root.ZIndex = 300
	card.ZIndex = 301
	bar.ZIndex = 302
	tl.ZIndex = 302
	ml.ZIndex = 302
	TweenService:Create(card, TweenInfo.new(0.2), {BackgroundTransparency=0.08}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency=0}):Play()
	TweenService:Create(bar, TweenInfo.new(0.15), {BackgroundTransparency=0}):Play()
	TweenService:Create(tl, TweenInfo.new(0.15), {TextTransparency=0}):Play()
	TweenService:Create(ml, TweenInfo.new(0.15), {TextTransparency=0}):Play()

	task.delay(duration, function()
		if not card or not card.Parent then return end
		TweenService:Create(card, TweenInfo.new(0.25), {BackgroundTransparency=1}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.25), {Transparency=1}):Play()
		TweenService:Create(bar, TweenInfo.new(0.25), {BackgroundTransparency=1}):Play()
		TweenService:Create(tl, TweenInfo.new(0.25), {TextTransparency=1}):Play()
		TweenService:Create(ml, TweenInfo.new(0.25), {TextTransparency=1}):Play()
		task.delay(0.3, function() if card and card.Parent then card:Destroy() end end)
	end)
end)

print("[NotifyController] Ready")
