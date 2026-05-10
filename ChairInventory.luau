local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local Events = RS:WaitForChild("Events")

local ChairSync = Events:WaitForChild("ChairSync")
local RequestSync = Events:WaitForChild("RequestSync")
local EquipChair = Events:WaitForChild("EquipChair")

local PlayerGui = player:WaitForChild("PlayerGui")
local GameGui = PlayerGui:WaitForChild("GameGui")
local Panel = GameGui:WaitForChild("ChairInvPanel")
local Grid = Panel:WaitForChild("Grid")
local Template = Grid:WaitForChild("Template")

Template.Visible = false

local ChairsRoot = RS:WaitForChild("Chairs")
local ShopChairs = ChairsRoot:WaitForChild("ShopChairs")
local EquippableChairs = ChairsRoot:WaitForChild("EquippableChairs")

local state = {
	owned = {},
	equipped = "Default",
}

local function getChairModel(name)
	return ShopChairs:FindFirstChild(name) or EquippableChairs:FindFirstChild(name)
end

local function clearViewport(vp)
	for _, c in ipairs(vp:GetChildren()) do
		c:Destroy()
	end
end

local function setupViewport(vp, chairName)
	clearViewport(vp)

	local model = getChairModel(chairName)
	if not model then return end

	local world = Instance.new("WorldModel")
	world.Parent = vp

	local clone = model:Clone()
	clone.Parent = world

	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end

	local cam = Instance.new("Camera")
	cam.Parent = vp
	vp.CurrentCamera = cam

	local cf, size = clone:GetBoundingBox()
	local center = cf.Position
	local radius = math.max(size.X, size.Y, size.Z)
	local dist = math.max(radius * 1.35, 2.2)

	cam.CFrame = CFrame.new(center + Vector3.new(dist, dist * 0.45, dist), center)
end

local function rebuildUI()
	for _, child in ipairs(Grid:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "Template" then
			child:Destroy()
		end
	end

	for _, chairName in ipairs(state.owned) do
		local row = Template:Clone()
		row.Name = chairName
		row.Visible = true
		row.Parent = Grid

		local nameLbl = row:FindFirstChild("NameLbl")
		if nameLbl and nameLbl:IsA("TextLabel") then
			nameLbl.Text = chairName
		end

		local vp = row:FindFirstChild("ViewportFrame")
		if not vp then
			vp = Instance.new("ViewportFrame")
			vp.Name = "ViewportFrame"
			vp.Parent = row
		end

		vp.Size = UDim2.new(0, 180, 0, 180)
		vp.Position = UDim2.new(0, -26, 0.45, -90)
		vp.BackgroundTransparency = 1
		vp.BorderSizePixel = 0

		setupViewport(vp, chairName)

		local equipBtn = row:FindFirstChild("EquipBtn")
		if equipBtn and equipBtn:IsA("TextButton") then
			if state.equipped == chairName then
				equipBtn.Text = "Equipped"
				equipBtn.BackgroundColor3 = Color3.fromRGB(85, 255, 127)
			else
				equipBtn.Text = "Equip"
				equipBtn.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
			end

			equipBtn.MouseButton1Click:Connect(function()
				equipBtn.Text = "Equipping..."
				EquipChair:FireServer(chairName)
			end)
		end
	end
end

local function mergeData(incoming)
	if type(incoming) ~= "table" then return end
	if type(incoming.owned) == "table" then
		state.owned = incoming.owned
	end
	if type(incoming.equipped) == "string" and incoming.equipped ~= "" then
		state.equipped = incoming.equipped
	end
end

task.spawn(function()
	local ok, data = pcall(function()
		return RequestSync:InvokeServer()
	end)
	if ok then
		mergeData(data)
		rebuildUI()
	end
end)

ChairSync.OnClientEvent:Connect(function(data)
	mergeData(data)
	rebuildUI()
end)
