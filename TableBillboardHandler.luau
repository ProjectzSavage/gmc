local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Events = RS:WaitForChild("Events")
local PlayerSat = Events:WaitForChild("PlayerSat")
local PlayerStood = Events:WaitForChild("PlayerStood")
local TableCountdown = Events:WaitForChild("TableCountdown")
local TableStatus = Events:WaitForChild("TableStatus")

local Table = workspace:WaitForChild("Table")
local TableTop = Table:WaitForChild("TableTop") or Table:FindFirstChildWhichIsA("BasePart")
local Billboard = TableTop and (TableTop:FindFirstChild("TableBillboard") or TableTop:FindFirstChildWhichIsA("BillboardGui"))
if not Billboard then
	warn("[TableBillboardHandler] Missing BillboardGui on TableTop")
	return
end

local function findLabel(name)
	local direct = Billboard:FindFirstChild(name, true)
	if direct and direct:IsA("TextLabel") then return direct end
	return nil
end

local CountLbl = findLabel("CountLbl")
local WinLbl = findLabel("WinLbl")
local CountdownLbl = findLabel("CountdownLbl")
local StatusLbl = findLabel("StatusLbl") or CountdownLbl

local playerCount = 0
local statusActive = false

local function updateDefaultState()
	if statusActive then return end
	if CountLbl then
		CountLbl.Visible = true
		CountLbl.Text = tostring(playerCount) .. "/2 Players"
	end
	if WinLbl then
		WinLbl.Visible = true
	end
	if CountdownLbl then
		CountdownLbl.Visible = false
	end
	if StatusLbl and StatusLbl ~= CountdownLbl then
		StatusLbl.Visible = false
	end
end

PlayerSat.OnClientEvent:Connect(function()
	playerCount = math.min(playerCount + 1, 2)
	updateDefaultState()
end)

PlayerStood.OnClientEvent:Connect(function()
	playerCount = math.max(playerCount - 1, 0)
	statusActive = false
	updateDefaultState()
end)

TableCountdown.OnClientEvent:Connect(function(t)
	if t and t > 0 then
		if playerCount < 2 then return end
		statusActive = false
		if CountLbl then CountLbl.Visible = false end
		if WinLbl then WinLbl.Visible = false end
		if CountdownLbl then
			CountdownLbl.Visible = true
			CountdownLbl.Text = tostring(t)
		end
		if StatusLbl and StatusLbl ~= CountdownLbl then
			StatusLbl.Visible = false
		end
	else
		if CountdownLbl then CountdownLbl.Visible = false end
		updateDefaultState()
	end
end)

TableStatus.OnClientEvent:Connect(function(text)
	local msg = tostring(text or "")
	if msg == "" then
		statusActive = false
		updateDefaultState()
		return
	end

	statusActive = true
	if CountLbl then CountLbl.Visible = false end
	if WinLbl then WinLbl.Visible = false end
	if CountdownLbl then CountdownLbl.Visible = false end
	if StatusLbl then
		StatusLbl.Visible = true
		StatusLbl.Text = msg
	end
end)

updateDefaultState()
print("[TableBillboardHandler] Ready")