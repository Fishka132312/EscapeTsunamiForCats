-- LocalScript (помести в StarterPlayer > StarterPlayerScripts)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Основная GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetStealerGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 420, 0, 500)
mainFrame.Position = UDim2.new(0.5, -210, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "Pet Stealer"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 18
title.Font = Enum.Font.GothamBold

-- Close button
local closeBtn = Instance.new("TextButton", mainFrame)
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextSize = 18
closeBtn.Font = Enum.Font.GothamBold
local closeCorner = Instance.new("UICorner", closeBtn)
closeCorner.CornerRadius = UDim.new(0, 8)

-- Scroll для списка петов
local scroll = Instance.new("ScrollingFrame", mainFrame)
scroll.Size = UDim2.new(1, -20, 1, -140)
scroll.Position = UDim2.new(0, 10, 0, 120)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)

local listLayout = Instance.new("UIListLayout", scroll)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 6)

-- Фильтры
local rarityFrame = Instance.new("Frame", mainFrame)
rarityFrame.Size = UDim2.new(1, -20, 0, 70)
rarityFrame.Position = UDim2.new(0, 10, 0, 45)
rarityFrame.BackgroundTransparency = 1

local rarities = {"Common", "Epic", "Mythic", "Legendary", "OG", "Special"}
local rarityChecks = {}

for i, rarity in ipairs(rarities) do
	local check = Instance.new("TextButton")
	check.Size = UDim2.new(0, 18, 0, 18)
	check.Position = UDim2.new(0, (i-1)*65, 0, 0)
	check.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	check.Text = ""
	check.Parent = rarityFrame
	
	local c = Instance.new("UICorner", check)
	c.CornerRadius = UDim.new(0, 4)
	
	local label = Instance.new("TextLabel", rarityFrame)
	label.Size = UDim2.new(0, 60, 0, 20)
	label.Position = UDim2.new(0, (i-1)*65 + 22, 0, -2)
	label.BackgroundTransparency = 1
	label.Text = rarity
	label.TextColor3 = Color3.new(1,1,1)
	label.TextSize = 13
	label.Font = Enum.Font.Gotham
	
	rarityChecks[rarity] = {Button = check, Enabled = true}
end

-- Mutation Filter (Dropdown style)
local mutationLabel = Instance.new("TextLabel", mainFrame)
mutationLabel.Position = UDim2.new(0, 10, 0, 85)
mutationLabel.Size = UDim2.new(0.5, 0, 0, 20)
mutationLabel.BackgroundTransparency = 1
mutationLabel.Text = "Mutation Filter:"
mutationLabel.TextColor3 = Color3.new(1,1,1)
mutationLabel.TextXAlignment = Enum.TextXAlignment.Left
mutationLabel.Font = Enum.Font.Gotham

local mutationDropdown = Instance.new("TextButton", mainFrame)
mutationDropdown.Size = UDim2.new(0.45, 0, 0, 25)
mutationDropdown.Position = UDim2.new(0.52, 0, 0, 82)
mutationDropdown.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
mutationDropdown.Text = "All Mutations"
mutationDropdown.TextColor3 = Color3.new(1,1,1)
local ddCorner = Instance.new("UICorner", mutationDropdown)
ddCorner.CornerRadius = UDim.new(0, 6)

local selectedMutation = "All"

-- Функция обновления списка
local petEntries = {}

local function createPetEntry(pet)
	local folder = pet.Parent.Parent.Name -- OG, Mythic и т.д.
	
	local entry = Instance.new("Frame")
	entry.Size = UDim2.new(1, -10, 0, 85)
	entry.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	entry.Parent = scroll
	local eCorner = Instance.new("UICorner", entry)
	eCorner.CornerRadius = UDim.new(0, 8)
	
	local nameLabel = Instance.new("TextLabel", entry)
	nameLabel.Size = UDim2.new(1, -100, 0, 20)
	nameLabel.Position = UDim2.new(0, 10, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = pet.Name
	nameLabel.TextColor3 = Color3.new(1,1,1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 15
	
	local rarityLabel = Instance.new("TextLabel", entry)
	rarityLabel.Size = UDim2.new(0.4, 0, 0, 18)
	rarityLabel.Position = UDim2.new(0, 10, 0, 28)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = "Rarity: "..folder
	rarityLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	
	local mutLabel = Instance.new("TextLabel", entry)
	mutLabel.Size = UDim2.new(0.4, 0, 0, 18)
	mutLabel.Position = UDim2.new(0, 10, 0, 48)
	mutLabel.BackgroundTransparency = 1
	mutLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	mutLabel.TextXAlignment = Enum.TextXAlignment.Left
	
	local timerLabel = Instance.new("TextLabel", entry)
	timerLabel.Size = UDim2.new(0.3, 0, 0, 18)
	timerLabel.Position = UDim2.new(0.55, 0, 0, 28)
	timerLabel.BackgroundTransparency = 1
	timerLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right
	
	local stealBtn = Instance.new("TextButton", entry)
	stealBtn.Size = UDim2.new(0, 80, 0, 25)
	stealBtn.Position = UDim2.new(1, -90, 0.5, -12)
	stealBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 100)
	stealBtn.Text = "Steal"
	stealBtn.TextColor3 = Color3.new(1,1,1)
	stealBtn.Font = Enum.Font.GothamBold
	local sCorner = Instance.new("UICorner", stealBtn)
	sCorner.CornerRadius = UDim.new(0, 6)
	
	petEntries[pet] = {
		Entry = entry,
		TimerLabel = timerLabel,
		MutLabel = mutLabel,
		StealBtn = stealBtn
	}
	
	-- Steal logic
	stealBtn.MouseButton1Click:Connect(function()
		local head = pet:FindFirstChild("Head")
		if head then
			local prompt = head:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				-- Телепорт к пету
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					player.Character.HumanoidRootPart.CFrame = head.CFrame * CFrame.new(0, 3, 0)
					wait(0.3)
					prompt:InputHoldBegin()
					wait(0.1)
					prompt:InputHoldEnd()
				end
			end
			
			-- Телепорт в сейф зону после кражи
			wait(1.5)
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local safeZone = workspace:FindFirstChild("SafeZone")
				if safeZone and safeZone:FindFirstChild("Part") then
					player.Character.HumanoidRootPart.CFrame = safeZone.Part.CFrame * CFrame.new(0, 5, 0)
				end
			end
		end
	end)
end

local function updatePetList()
	-- Очищаем старые
	for pet, data in pairs(petEntries) do
		if not pet.Parent then
			data.Entry:Destroy()
			petEntries[pet] = nil
		end
	end
	
	local spawners = workspace:WaitForChild("ItemSpawners")
	
	for _, rarityFolder in ipairs(spawners:GetChildren()) do
		local rarityName = rarityFolder.Name
		if not rarityChecks[rarityName] or not rarityChecks[rarityName].Enabled then
			continue
		end
		
		for _, pet in ipairs(rarityFolder:GetChildren()) do
			if pet.Name == "SpawnedItem" or pet:FindFirstChild("InfoGUI") then
				local infoGui = pet:FindFirstChild("InfoGUI")
				if not infoGui then continue end
				
				local mutation = infoGui.TextLabels:FindFirstChild("Mutation")
				local mutText = mutation and mutation.Text or "Normal"
				
				-- Фильтр мутации
				if selectedMutation ~= "All" and mutText ~= selectedMutation then
					continue
				end
				
				if not petEntries[pet] then
					createPetEntry(pet)
				end
			end
		end
	end
end

-- Обновление таймеров
RunService.Heartbeat:Connect(function()
	for pet, data in pairs(petEntries) do
		local infoGui = pet:FindFirstChild("InfoGUI")
		if infoGui then
			local timerLabel = infoGui.TextLabels:FindFirstChild("Timer")
			if timerLabel then
				data.TimerLabel.Text = "Timer: " .. timerLabel.Text
			end
			
			local mutLabel = infoGui.TextLabels:FindFirstChild("Mutation")
			if mutLabel then
				data.MutLabel.Text = "Mutation: " .. mutLabel.Text
			end
		end
	end
end)

-- Чекбоксы редкостей
for rarity, data in pairs(rarityChecks) do
	data.Button.MouseButton1Click:Connect(function()
		data.Enabled = not data.Enabled
		data.Button.BackgroundColor3 = data.Enabled and Color3.fromRGB(0, 170, 100) or Color3.fromRGB(50, 50, 55)
		updatePetList()
	end)
end

-- Mutation dropdown (простой вариант)
mutationDropdown.MouseButton1Click:Connect(function()
	local mutations = {"All", "Normal", "Golden", "Diamond", "Ruby", "Rainbow", "Blood", "Neon", "Divine"}
	local current = table.find(mutations, selectedMutation) or 1
	
	current = current + 1
	if current > #mutations then current = 1 end
	
	selectedMutation = mutations[current]
	mutationDropdown.Text = selectedMutation
	updatePetList()
end)

closeBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)

-- Автообновление списка
spawn(function()
	while wait(1.5) do
		updatePetList()
	end
end)

print("Pet Stealer GUI загружен!")
