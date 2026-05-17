-- ChairVisualizer (disabled avatar attachment; cleanup leftovers only)
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function cleanupCharacter(character)
	if not character then return end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Model") and child.Name == "EquippedChair" then
			child:Destroy()
		end
	end
end

if player.Character then
	cleanupCharacter(player.Character)
end

player.CharacterAdded:Connect(function(character)
	task.wait(0.2)
	cleanupCharacter(character)
end)
