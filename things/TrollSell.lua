local Players         = game:GetService("Players")
local Workspace       = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- Тайминги (чуть увеличили для стабильности детекта промптов)
local DELAY_AFTER_TP   = 0.25  -- Задержка после телепорта к пету (чтобы игра поняла, что ты там)
local DELAY_PROMPT     = 0.15  -- Задержка зажатия промпта
local DELAY_AFTER_SELL = 0.5   -- Пауза после продажи, чтобы инвентарь успел очиститься

-- Переменная для хранения настоящей сейфзоны
local safeZoneCFrame = nil

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
    return 1 -- Безопасный лимит по умолчанию
end

-- Умная функция сбора петов (ОСТАВЛЯЕТ ровно 1 пета в каждой папке локации)
local function getAvailablePetsWithLimit()
    local validPets = {}
    
    for _, rarityFolder in ipairs(ItemSpawners:GetChildren()) do
        if TARGET_RARITIES[rarityFolder.Name] then
            local allChildren = rarityFolder:GetChildren()
            
            -- Проверяем, что в папке больше одного объекта
            if #allChildren > 1 then
                -- Игнорируем индекс 1, собираем со 2-го и дальше
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

-- Использование ProximityPrompt
local function firePrompt(prompt)
    if prompt then
        prompt:InputHoldBegin()
        task.wait(0.05)
        prompt:InputHoldEnd()
    end
end

print("[Core Sell] Фоновый скрипт авто-продажи запущен и готов!")

while true do
    task.wait(0.3) -- Снизили задержку проверки кнопки
    
    if _G.AutoSellEnabled then
        local Character = LocalPlayer.Character
        local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
        
        if HumanoidRootPart then
            -- ИСПРАВЛЕНИЕ 1: Запоминаем базу ОДИН раз строго в момент включения скрипта
            if not safeZoneCFrame then
                safeZoneCFrame = HumanoidRootPart.CFrame
                print("[Core Sell] База успешно сохранена на текущей позиции!")
            end

            local maxCarry = getCurrentCarryLimit()
            local allPets = getAvailablePetsWithLimit()
            
            if #allPets > 0 then
                -- Перемешиваем доступных петов для рандомного ТП
                for i = #allPets, 2, -1 do
                    local j = math.random(i)
                    allPets[i], allPets[j] = allPets[j], allPets[i]
                end
                
                local gatheredCount = 0
                
                -- Начинаем сбор
                for _, petData in ipairs(allPets) do
                    if not _G.AutoSellEnabled then break end
                    if gatheredCount >= maxCarry then break end
                    
                    if petData.Item and petData.Item.Parent and Character.Parent then
                        -- ТП к голове пета
                        HumanoidRootPart.CFrame = petData.Head.CFrame + Vector3.new(0, 2, 0)
                        task.wait(DELAY_AFTER_TP)
                        
                        -- Подбираем
                        firePrompt(petData.Prompt)
                        task.wait(DELAY_PROMPT)
                        
                        gatheredCount = gatheredCount + 1
                    end
                end
                
                -- ТП на сохраненную базу
                if safeZoneCFrame then
                    HumanoidRootPart.CFrame = safeZoneCFrame
                end
                task.wait(0.3)
                
                -- Продажа инвентаря
                if _G.AutoSellEnabled then
                    pcall(function()
                        SellRemote:FireServer(unpack({ "Inventory" }))
                    end)
                end
                
                task.wait(DELAY_AFTER_SELL)
            else
                print("[Core Sell] Свободных петов нет (осталось по 1 на локациях). Ждем респавна...")
                task.wait(2)
            end
        end
    else
        -- Если выключили тумблер — сбрасываем сохраненную базу, чтобы переназначить её при следующем включении
        safeZoneCFrame = nil
    end
end
