local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))() --dada
local Window = OrionLib:MakeWindow({Name = "Tsunami For Cats", HidePremium = false, SaveConfig = true, ConfigFolder = "StealAPushin"})

local scripts = {
    'Troll.lua', 
	'PVP.lua',
}

local baseUrl = 'https://raw.githubusercontent.com/Fishka132312/EscapeTsunamiForCats/refs/heads/main/things/'

task.spawn(function()
    for i, scriptName in ipairs(scripts) do
        local fullUrl = baseUrl .. scriptName
        
        local success, err = pcall(function()
            local code = game:HttpGet(fullUrl)
            if code then
                loadstring(code)()
            else
                warn("Не удалось получить код для: " .. scriptName)
            end
        end)
        
        if not success then
            warn("Ошибка при загрузке " .. scriptName .. ": " .. tostring(err))
        end
        
        task.wait(0.7) 
    end
end)

local Tab = Window:MakeTab({
	Name = "Main",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
}) 

local Section = Tab:AddSection({
	Name = "Main"
})


Tab:AddButton({
    Name = "tp to last zone",
    Callback = function()
        game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.Map:GetChildren()[41].CFrame * CFrame.new(0, 3, 0)
    end    
})



Tab:AddButton({
    Name = "tp to safe zone",
    Callback = function()
         local hrp = game:GetService("Players").LocalPlayer.Character.HumanoidRootPart
local target = workspace:GetChildren()[50]

hrp.CFrame = (target:IsA("Model") and target:GetPivot() or target.CFrame) * CFrame.new(0, 3, 0)
    end    
}) 

Tab:AddSlider({
    Name = "Change Speed",
    Min = 0,
    Max = 200,
    Default = 22,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 1,
    ValueName = "Speed",
    Callback = function(Value)
        local player = game.Players.LocalPlayer
        if player and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = Value
            end
        end
    end    
})

local Tab = Window:MakeTab({
	Name = "Sniper Pets",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
}) 

local Section = Tab:AddSection({
	Name = "Sniper"
})

Tab:AddButton({
    Name = "Sniper Pets",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/Fishka132312/EscapeTsunamiForCats/refs/heads/main/things/SniperGui.lua'))()
    end    
})


Tab:AddButton({
    Name = "Monitoring pets",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/Fishka132312/EscapeTsunamiForCats/refs/heads/main/things/StealerGui.lua'))()
    end    
})

Tab:AddButton({
    Name = "Local Base",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/Fishka132312/EscapeTsunamiForCats/refs/heads/main/things/LocalBase.lua'))()
    end    
})

Tab:AddButton({
    Name = "Inventory Checker",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/Fishka132312/EscapeTsunamiForCats/refs/heads/main/things/InventoryChecker.lua'))()
    end    
})





local Tab = Window:MakeTab({
	Name = "Free things",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

local Section = Tab:AddSection({
	Name = "Free brat"
})

Tab:AddButton({
    Name = "Free Vip!",
    Callback = function()
        local folderName = "VIP"
        local vipFolder = workspace:FindFirstChild(folderName)
        
        if vipFolder then
            vipFolder:Destroy()
            print("[Anti-VIP] Папка " .. folderName .. " удалена вручную.")
        else
            print("[Anti-VIP] Папка не найдена.")
        end
    end    
})

Tab:AddButton({
    Name = "Delete Tsunamis",
    Callback = function()
        local folderName = "Tsunamis"
        local tsunamisFolder = workspace:FindFirstChild(folderName)
        
        if tsunamisFolder then
            tsunamisFolder:Destroy()
            print("[Anti-Tsunamis] Папка " .. folderName .. " удалена.")
        else
            print("[Anti-Tsunamis] Папка Tsunamis не найдена.")
        end
    end    
})

local Tab = Window:MakeTab({
	Name = "Dupe Pets",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

local Section = Tab:AddSection({
	Name = "Dupe Pets"
})

Tab:AddButton({
    Name = "Dupe",
    Callback = function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local fuseEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RequestFuse")
local backpack = Players.LocalPlayer:WaitForChild("Backpack")

local singleTool = backpack:FindFirstChildWhichIsA("Tool")

if singleTool then
    local fakeData = { singleTool, singleTool, singleTool }
    
    fuseEvent:FireServer(fakeData)
else
end
    end    
})

Tab:AddToggle({
	Name = "Loop Dupe",
	Default = false,
	Callback = function(Value)
		_G.isFusing = Value 
		print(Value)

		if _G.isFusing then
			task.spawn(function()
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Players = game:GetService("Players")
				local fuseEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RequestFuse")
				local player = Players.LocalPlayer

				while _G.isFusing do
					local backpack = player:FindFirstChild("Backpack")
					
					if backpack then
						local singleTool = backpack:FindFirstChildWhichIsA("Tool")
						
						if singleTool then
							local fakeData = { singleTool, singleTool, singleTool }
							fuseEvent:FireServer(fakeData)
						end
					end
					
					task.wait(0.5)
				end
			end)
		end
	end    
})

local Tab = Window:MakeTab({
	Name = "Auto Mission (Maxwell))",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

Tab:AddButton({
	Name = "Tp to Mission",
	Callback = function()
            game.Players.LocalPlayer.Character:MoveTo(workspace.MissionTouch.Position)
  	end    
})

local isSpeedEnabled = false 

Tab:AddToggle({
    Name = "Auto Purchase Speed",
    Default = false,
    Callback = function(Value)
        isSpeedEnabled = Value 
        
        if isSpeedEnabled then
            task.spawn(function()
                while isSpeedEnabled do
                    local args = {10}
                    game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("PurchaseSpeed"):FireServer(unpack(args))
                    task.wait(0.5)
                end
            end)
        end
    end    
})

Tab:AddToggle({
    Name = "Auto Purchase Rebirth",
    Default = false,
    Callback = function(Value)
        _G.AutoRebirth = Value
        
        if _G.AutoRebirth then
            task.spawn(function()
                while _G.AutoRebirth do
                    game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("RequestRebirth"):FireServer()
                    task.wait(2)
                end
            end)
        end
    end    
})

Tab:AddButton({
	Name = "Skip Time",
	Callback = function()
      		local args = {

	100

}

game:GetService("ReplicatedStorage"):WaitForChild("TimeProgressEvent"):FireServer(unpack(args))
  	end    
})

Tab:AddToggle({
    Name = "Redeem Maxwell",
    Default = false,
    Callback = function(Value)
        _G.AutoRewardEnabled = Value 
        
        if _G.AutoRewardEnabled then
            task.spawn(function()
                while _G.AutoRewardEnabled do
                    game:GetService("ReplicatedStorage"):WaitForChild("GiveRewardEvent"):FireServer()
                    task.wait(2)
                end
            end)
        end
    end    
})

Tab:AddToggle({
	Name = "Loop Dupe",
	Default = false,
	Callback = function(Value)
		_G.isFusing = Value 
		print(Value)

		if _G.isFusing then
			task.spawn(function()
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Players = game:GetService("Players")
				local fuseEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RequestFuse")
				local player = Players.LocalPlayer

				while _G.isFusing do
					local backpack = player:FindFirstChild("Backpack")
					
					if backpack then
						local singleTool = backpack:FindFirstChildWhichIsA("Tool")
						
						if singleTool then
							local fakeData = { singleTool, singleTool, singleTool }
							fuseEvent:FireServer(fakeData)
						end
					end
					
					task.wait(0.5)
				end
			end)
		end
	end    
})

local Tab = Window:MakeTab({
	Name = "Auto Buy",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

local Section = Tab:AddSection({
	Name = "Speed"
})

Tab:AddToggle({
    Name = "Auto Purchase Speed",
    Default = false,
    Callback = function(Value)
        isSpeedEnabled = Value 
        
        if isSpeedEnabled then
            task.spawn(function()
                while isSpeedEnabled do
                    local args = {10}
                    game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("PurchaseSpeed"):FireServer(unpack(args))
                    task.wait(0.5)
                end
            end)
        end
    end    
})

local Section = Tab:AddSection({
	Name = "Rebirths"
})

Tab:AddToggle({
    Name = "Auto Purchase Rebirth",
    Default = false,
    Callback = function(Value)
        _G.AutoRebirth = Value
        
        if _G.AutoRebirth then
            task.spawn(function()
                while _G.AutoRebirth do
                    game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("RequestRebirth"):FireServer()
                    task.wait(2)
                end
            end)
        end
    end    
})

local Section = Tab:AddSection({
	Name = "Other"
})

Tab:AddToggle({
    Name = "Remove Annoying Notifications",
    Default = false,
    Callback = function(Value)
        game:GetService("Players").LocalPlayer.PlayerGui.GUI.Frames.Notifications.Visible = not Value
    end    
})

local Tab = Window:MakeTab({
	Name = "Troll",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
}) 

local Section = Tab:AddSection({
	Name = "Spam Gift Pets"
})

-- Глобальные переменные для связи интерфейса с основным скриптом
_G.SelectedPlayer = nil
_G.AutoGiftEnabled = false

-- Функция для получения списка ников всех игроков на сервере
local function getPlayerNames()
    local names = {}
    for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
        -- Не добавляем самих себя в список подарков
        if p ~= game:GetService("Players").LocalPlayer then
            table.insert(names, p.Name)
        end
    end
    -- Если сервер пустой, добавим заглушку
    if #names == 0 then table.insert(names, "Нет игроков") end
    return names
end

-- Создаем Dropdown со списком игроков
local PlayerDropdown = Tab:AddDropdown({
    Name = "Choose Player",
    Default = "Choose Player",
    Options = getPlayerNames(),
    Callback = function(Value)
        if Value ~= "Выбери ник" and Value ~= "Нет игроков" then
            _G.SelectedPlayer = Value
            print("[UI] Выбран игрок для отправки:", _G.SelectedPlayer)
        else
            _G.SelectedPlayer = nil
        end
    end    
})

-- Обновление списка игроков при их входе или выходе
local function refreshDropdown()
    if PlayerDropdown and PlayerDropdown.Refresh then
        PlayerDropdown:Refresh(getPlayerNames(), true)
    end
end
game:GetService("Players").PlayerAdded:Connect(refreshDropdown)
game:GetService("Players").PlayerRemoving:Connect(refreshDropdown)

-- Создаем Toggle (выключатель) для старта автоматики
Tab:AddToggle({
    Name = "Start spam gift",
    Default = false,
    Callback = function(Value)
        _G.AutoGiftEnabled = Value
    end    
})

local Section = Tab:AddSection({
	Name = "Spam Sell"
})

Tab:AddToggle({
    Name = "Start Sell/Steal",
    Default = false,
    Callback = function(Value)
        _G.AutoSellEnabled = Value
    end    
})

Tab:AddButton({
    Name = "Unlock All Index",
    Callback = function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/Fishka132312/EscapeTsunamiForCats/refs/heads/main/things/UnlockAllIndex.lua'))()
    end    
})


local Tab = Window:MakeTab({
	Name = "Total Domination",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
}) 

local Section = Tab:AddSection({
	Name = "Total Domination"
})

Tab:AddToggle({
	Name = "Start",
	Default = false,
	Callback = function(Value)
		_G.PVP = Value
	end    
})

--------------------------------MISC-----------------------------

local Tab = Window:MakeTab({
	Name = "Misc",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

local Section = Tab:AddSection({
	Name = "Tools"
})

Tab:AddButton({
	Name = "Infinite Yield",
	Callback = function()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/Fishka132312/ignore-it/refs/heads/main/infiniteyield'))()
  	end    
})

Tab:AddButton({
	Name = "Destroy Gui",
	Callback = function()
    OrionLib:Destroy()
    end    
})

OrionLib:Init()
