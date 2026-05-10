local RS      = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player  = Players.LocalPlayer

local Events     = RS:WaitForChild("Events")
local ChairSync  = Events:WaitForChild("ChairSync")
local RequestSync= Events:WaitForChild("RequestSync")
local EquipChair = Events:WaitForChild("EquipChair")

local PlayerGui  = player:WaitForChild("PlayerGui")
local GameGui    = PlayerGui:WaitForChild("GameGui")
local Panel      = GameGui:WaitForChild("ChairInvPanel")
local openInvBtn = GameGui:FindFirstChild("OpenChairInvBtn")
	or GameGui:FindFirstChild("OpenInventoryBtn")
	or GameGui:FindFirstChild("OpenInvBtn")
local closeInvBtn= Panel:FindFirstChild("CloseBtn")

Panel.Visible = false

local Grid     = Panel:WaitForChild("Grid")
local Template = Grid:WaitForChild("Template")
Template.Visible = false

local function updateUI(data)
	if not data then return end
	for _, child in ipairs(Grid:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "Template" then child:Destroy() end
	end
	for _, name in ipairs(data.owned) do
		local btn = Template:Clone()
		btn.Name = name
		btn.NameLbl.Text = name
		btn.Visible = true
		btn.Parent  = Grid

		local view = btn:FindFirstChild("ViewportFrame") or Instance.new("ViewportFrame", btn)
		view.Name = "ViewportFrame"
		view.Size = UDim2.new(1, 0, 1.2, 0)
		view.BackgroundTransparency = 1

		local model = RS.Chairs.ShopChairs:FindFirstChild(name)
			or RS.Chairs.EquippableChairs:FindFirstChild(name)
		if model then
			local clone = model:Clone()
			clone.Parent = view
			local cam = Instance.new("Camera", view)
			view.CurrentCamera = cam
			local _, size = clone:GetBoundingBox()
			cam.CFrame = CFrame.new(
				clone:GetPivot().Position + Vector3.new(size.X*2, size.Y, size.Z*2),
				clone:GetPivot().Position
			)
		end

		local eb = btn.EquipBtn
		if data.equipped == name then
			eb.Text = "Equipped"; eb.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
		else
			eb.Text = "Equip";    eb.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
		end
		eb.MouseButton1Click:Connect(function()
			eb.Text = "Equipping..."
			EquipChair:FireServer(name)
		end)
	end
end

-- Wait for animator, then register — animator owns the open/close buttons
local t = 0
while not _G.UIWindowAnimator and t < 5 do task.wait(0.1); t += 0.1 end

if _G.UIWindowAnimator then
	_G.UIWindowAnimator.register("inventory", Panel, openInvBtn, closeInvBtn, function()
		-- Fire a refresh when inventory opens
		task.spawn(function()
			if RequestSync:IsA("RemoteFunction") then
				local data = RequestSync:InvokeServer()
				updateUI(data)
			end
		end)
	end)
else
	-- Fallback only
	if openInvBtn then
		openInvBtn.MouseButton1Click:Connect(function() Panel.Visible = not Panel.Visible end)
	end
	if closeInvBtn then
		closeInvBtn.MouseButton1Click:Connect(function() Panel.Visible = false end)
	end
end

task.spawn(function()
	local data = RequestSync:InvokeServer()
	updateUI(data)
end)

ChairSync.OnClientEvent:Connect(updateUI)
