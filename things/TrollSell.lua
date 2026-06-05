local Players         = game:GetService("Players")
local Workspace       = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui      = game:GetService("StarterGui")

local LocalPlayer     = Players.LocalPlayer
local ItemSpawners    = Workspace:WaitForChild("ItemSpawners")
local SellRemote      = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RequestSell")

-- Настройки фильтра редкостей
local TARGET_RARITIES = {
    ["Common"] = true,
    ["Uncommon"] = true,
    ["Rare"] = true,
    ["Epic"] = true,
    ["Legendary"] = true,
    ["Mythical"] = true,
    ["OG"] = true,
    ["SpecialItemSpawn"] = true
}

-- Тайминги (оптимальные для обхода античита и прогрузки)
local DELAY_AFTER_TP   = 0.3
local DELAY_PROMPT     = 0.15
local DELAY_AFTER_SELL = 0.5

-- Переменная базы
local safeZoneCFrame = nil

-- Функция для вывода уведомлений прямо на экран игры
local function sendNotification(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 3
        })
    end)
end

-- Функция получения лимита вместимости из твоего UI
local function getCurrentCarryLimit()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local carryFrame = playerGui:FindFirstChild("GUI") 
        and playerGui.GUI:FindFirstChild("Frames") 
        and playerGui.GUI.Frames:FindFirstChild("Carry") 
        and playerGui.GUI.Frames.Carry:FindFirstChild("Scrolling")

    if carryFrame then
        local upgradeTemplate = carryFrame:FindFirstChild("CarryUpgrade")
        if upgradeTemplate then
            local stats = upgradeTemplate:FindFirstChild("Stats")
            if stats then
                local beforeText = stats:FindFirstChild("Before") and stats.Before:FindFirstChild("Text")
                if beforeText and beforeText.Text then
                    local limit = tonumber(beforeText.Text:match("%d+"))
                    if limit then return limit end
                end
            end
        end
    end
    return 1
end

-- Функция сбора петов (оставляет по 1 на локацию)
local function getAvailablePetsWithLimit()
    local validPets = {}
    for _, rarityFolder in ipairs(ItemSpawners:GetChildren()) do
        if TARGET_RARITIES[rarityFolder.Name] then
            local allChildren = rarityFolder:GetChildren()
            if #allChildren > 1 then
                for i = 2, #allChildren do
                    local pet = allChildren[i]
                    local head = pet:FindFirstChild("Head")
                    local prompt = head and head:FindFirstChildOfClass("ProximityPrompt")
                    
                    if head and prompt then
                        table.insert(validPets, { 
                            Item = pet, 
                            Head = head, 
                            Prompt = prompt 
                        })
                    end
                end
            end
        end
    end
    return validPets
end

local function firePrompt(prompt)
    if prompt then
        prompt:InputHoldBegin()
        task.wait(0.05)
        prompt:InputHoldEnd()
    end
end

-- Создаем отдельный независимый поток для главного цикла
task.spawn(function()
    sendNotification("AutoFarm", "Фоновый скрипт загружен! Включи тумблер.")
    
    while true do
        task.wait(0.2)
        
        -- Проверяем глобальный флаг кнопки
        if _G.AutoSellEnabled == true then
            local Character = LocalPlayer.Character
            local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
            
            if HumanoidRootPart then
                -- Фиксируем базу при старте
                if not safeZoneCFrame then
                    safeZoneCFrame = HumanoidRootPart.CFrame
                    sendNotification("AutoFarm", "Базовая точка сохранена!")
                end

                local maxCarry = getCurrentCarryLimit()
                local allPets = getAvailablePetsWithLimit()
                
                if #allPets > 0 then
                    -- Перемешиваем
                    for i = #allPets, 2, -1 do
                        local j = math.random(i)
                        allPets[i], allPets[j] = allPets[j], allPets[i]
                    end
                    
                    local gatheredCount = 0
                    
                    for _, petData in ipairs(allPets) do
                        if _G.AutoSellEnabled ~= true then break end
                        if gatheredCount >= maxCarry then break end
                        
                        if petData.Item and petData.Item.Parent and Character.Parent then
                            HumanoidRootPart.CFrame = petData.Head.CFrame + Vector3.new(0, 2, 0)
                            task.wait(DELAY_AFTER_TP)
                            
                            firePrompt(petData.Prompt)
                            task.wait(DELAY_PROMPT)
                            
                            gatheredCount = gatheredCount + 1
                        end
                    end
                    
                    -- Возврат на сохраненную базу
                    if safeZoneCFrame then
                        HumanoidRootPart.CFrame = safeZoneCFrame
                    end
                    task.wait(0.3)
                    
                    -- Продажа
                    if _G.AutoSellEnabled == true then
                        pcall(function()
                            SellRemote:FireServer(unpack({ "Inventory" }))
                        end)
                    end
                    
                    task.wait(DELAY_AFTER_SELL)
                else
                    task.wait(1.5)
                end
            end
        else
            -- Сброс базы при выключении кнопки
            safeZoneCFrame = nil
        end
    end
end)
