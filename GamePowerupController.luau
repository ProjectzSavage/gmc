-- GamePowerupController
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
player.CharacterAdded:Wait()

local playerGui = player:WaitForChild("PlayerGui")
local gameGui = playerGui:WaitForChild("GameGui")
local Events = RS:WaitForChild("Events")

local IsStudio = RunService:IsStudio()
local GuessPhaseStart = Events:WaitForChild("GuessPhaseStart")
local GamePowerupEffect = Events:WaitForChild("GamePowerupEffect")
local TestGamePowerup = Events:WaitForChild("TestGamePowerup")
local UseFreePowerup = Events:WaitForChild("UseFreePowerup")
local RewardSync = Events:WaitForChild("RewardSync")

local PRODUCT_IDS = { hint=3581498716, reveal_country=3581498875, reveal_letter=3581498810 }
local POWERUP_TO_INV = { hint="magnifier", reveal_country="hook", reveal_letter="mystery" }

local container = gameGui:FindFirstChild("GamePowerups")
if not container then warn("[GamePowerupCtrl] 'GamePowerups' not found!"); return end

container.ZIndex = 50; container.Visible = false
local function bumpZ(obj) if obj:IsA("GuiObject") then obj.ZIndex = 51 end for _, c in ipairs(obj:GetChildren()) do bumpZ(c) end end
bumpZ(container)

local hintBtn = container:FindFirstChild("HintBtn")
local revealCountryBtn = container:FindFirstChild("RevealCountryBtn")
local revealLetterBtn = container:FindFirstChild("RevealLetterBtn")

local LGuessF = _G.Frames and _G.Frames.LGuessF or gameGui:FindFirstChild("LGuessF")
local CGuessF = _G.Frames and _G.Frames.CGuessF or gameGui:FindFirstChild("CGuessF")

local myPowerups = { magnifier=0, hook=0, mystery=0 }
local function updateLabel(btn, powerupType)
	if not btn then return end
	local priceLbl = btn:FindFirstChild("PriceLbl")
	if not priceLbl then return end
	local invKey = POWERUP_TO_INV[powerupType]
	local count = myPowerups[invKey] or 0
	if count > 0 then
		priceLbl.Text = count.." Use"..(count~=1 and "s" or ""); priceLbl.TextColor3 = Color3.fromRGB(80,255,120)
	else
		local pid = PRODUCT_IDS[powerupType]
		if pid and pid ~= 0 and not IsStudio then
			priceLbl.Text = "R$ ?"; priceLbl.TextColor3 = Color3.fromRGB(80,220,100)
			task.spawn(function()
				local ok, info = pcall(function() return MarketplaceService:GetProductInfo(pid, Enum.InfoType.Product) end)
				if ok and info and info.PriceInRobux then priceLbl.Text = "R$ "..tostring(info.PriceInRobux) end
			end)
		else priceLbl.Text = "Free"; priceLbl.TextColor3 = Color3.fromRGB(80,220,100) end
	end
end
local function updateAll() updateLabel(hintBtn,"hint"); updateLabel(revealCountryBtn,"reveal_country"); updateLabel(revealLetterBtn,"reveal_letter") end
RewardSync.OnClientEvent:Connect(function(p) if p and type(p)=="table" and p.powerups then myPowerups=p.powerups; updateAll() end end)

local function buy(powerupType)
	local invKey = POWERUP_TO_INV[powerupType]
	if (myPowerups[invKey] or 0) > 0 then UseFreePowerup:FireServer(powerupType)
	elseif IsStudio then TestGamePowerup:FireServer(powerupType)
	elseif PRODUCT_IDS[powerupType] then MarketplaceService:PromptProductPurchase(player, PRODUCT_IDS[powerupType]) end
end

if hintBtn then hintBtn.MouseButton1Click:Connect(function() buy("hint") end) end
if revealCountryBtn then revealCountryBtn.MouseButton1Click:Connect(function() buy("reveal_country") end) end
if revealLetterBtn then revealLetterBtn.MouseButton1Click:Connect(function() buy("reveal_letter") end) end

local function wireHover(btn)
	if not btn then return end
	local n, h = Color3.fromRGB(12,16,30), Color3.fromRGB(28,36,60)
	btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3=h}):Play() end)
	btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3=n}):Play() end)
end
wireHover(hintBtn); wireHover(revealCountryBtn); wireHover(revealLetterBtn)

local function checkVisibility()
	local letterV = LGuessF and LGuessF.Visible or false
	local countryV = CGuessF and CGuessF.Visible or false
	container.Visible = letterV or countryV
end
RunService.RenderStepped:Connect(checkVisibility)

Events.GameOver.OnClientEvent:Connect(function() container.Visible = false end)
Events.ResetAll.OnClientEvent:Connect(function() container.Visible = false end)
Events.PlayerStood.OnClientEvent:Connect(function(_, name) if name == player.Name then container.Visible = false end end)

GamePowerupEffect.OnClientEvent:Connect(function(data)
	local colors = { hint=Color3.fromRGB(70,140,255), reveal_country=Color3.fromRGB(255,180,40), reveal_letter=Color3.fromRGB(160,90,255) }
	local accent = colors[data.type] or Color3.new(1,1,1)
	local card = Instance.new("Frame"); card.Name="PowerupReveal"; card.Size=UDim2.new(0,420,0,130); card.Position=UDim2.new(0.5,-210,0.28,0)
	card.BackgroundColor3=Color3.fromRGB(8,12,24); card.BackgroundTransparency=1; card.ZIndex=80; card.Parent=gameGui
	Instance.new("UICorner",card).CornerRadius=UDim.new(0,18)
	local st=Instance.new("UIStroke",card); st.Color=accent; st.Thickness=2.5
	local glow=Instance.new("Frame"); glow.Size=UDim2.new(1,20,1,20); glow.Position=UDim2.new(0,-10,0,-10)
	glow.BackgroundColor3=accent; glow.BackgroundTransparency=1; glow.ZIndex=79; glow.Parent=card; Instance.new("UICorner",glow).CornerRadius=UDim.new(0,24)
	local tl=Instance.new("TextLabel"); tl.Size=UDim2.new(1,-24,0,44); tl.Position=UDim2.new(0,12,0,10)
	tl.BackgroundTransparency=1; tl.Text=data.title or ""; tl.Font=Enum.Font.GothamBlack; tl.TextScaled=true
	tl.TextColor3=accent; tl.TextTransparency=1; tl.ZIndex=81; tl.Parent=card
	local ml=Instance.new("TextLabel"); ml.Size=UDim2.new(1,-24,0,56); ml.Position=UDim2.new(0,12,0,58)
	ml.BackgroundTransparency=1; ml.Text=data.message or ""; ml.Font=Enum.Font.GothamBold; ml.TextScaled=true
	ml.TextColor3=Color3.new(1,1,1); ml.TextTransparency=1; ml.ZIndex=81; ml.Parent=card
	TweenService:Create(card, TweenInfo.new(0.2), {BackgroundTransparency=0.04}):Play()
	TweenService:Create(glow, TweenInfo.new(0.2), {BackgroundTransparency=0.85}):Play()
	TweenService:Create(tl, TweenInfo.new(0.15), {TextTransparency=0}):Play()
	TweenService:Create(ml, TweenInfo.new(0.15), {TextTransparency=0}):Play()
	task.delay(data.duration or 4, function()
		if not card or not card.Parent then return end
		TweenService:Create(card, TweenInfo.new(0.25), {BackgroundTransparency=1}):Play()
		TweenService:Create(glow, TweenInfo.new(0.25), {BackgroundTransparency=1}):Play()
		TweenService:Create(tl, TweenInfo.new(0.25), {TextTransparency=1}):Play()
		TweenService:Create(ml, TweenInfo.new(0.25), {TextTransparency=1}):Play()
		task.delay(0.3, function() if card and card.Parent then card:Destroy() end end)
	end)
end)

print("[GamePowerupController] Ready - Studio:", IsStudio)