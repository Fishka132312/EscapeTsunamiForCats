local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()
local Window = OrionLib:MakeWindow({Name = "Tsunami For Cats", HidePremium = false, SaveConfig = true, ConfigFolder = "StealAPushin"})

local Tab = Window:MakeTab({
	Name = "Main",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
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



local Tab = Window:MakeTab({
	Name = "Free things",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
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
		-- Создаем флаг внутри функции, чтобы отслеживать состояние
		_G.isFusing = Value 
		print(Value)

		if _G.isFusing then
			task.spawn(function()
				-- Получаем сервисы прямо здесь, чтобы не засорять начало скрипта
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
					
					task.wait(0.5) -- Задержка полсекунды, чтобы не крашнуло
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

Tab:AddButton({
	Name = "Auto Speed",
	Callback = function()
        while true do
            local args = {
	10
}
game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("PurchaseSpeed"):FireServer(unpack(args))
wait(0.5)
  	end    
})

Tab:AddButton({
	Name = "Auto Rebirth",
	Callback = function()
        while true do
            game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("RequestRebirth"):FireServer()
            wait(2)
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

local Tab = Window:MakeTab({
	Name = "Rebirth",
	Icon = "rbxassetid://4483345998",
	PremiumOnly = false
})

Tab:AddButton({
	Name = "Auto Rebirth",
	Callback = function()
        while true do
            game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("RequestRebirth"):FireServer()
            wait(0.5)
        end
  	end    
})

Tab:AddToggle({
	Name = "Loop Dupe",
	Default = false,
	Callback = function(Value)
		-- Создаем флаг внутри функции, чтобы отслеживать состояние
		_G.isFusing = Value 
		print(Value)

		if _G.isFusing then
			task.spawn(function()
				-- Получаем сервисы прямо здесь, чтобы не засорять начало скрипта
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
					
					task.wait(0.5) -- Задержка полсекунды, чтобы не крашнуло
				end
			end)
		end
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
