local Players         = game:GetService("Players")
local Workspace       = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer     = Players.LocalPlayer
local ItemSpawners    = Workspace:WaitForChild("ItemSpawners")
local SellRemote      = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RequestSell")

-- Настройки фильтра редкостей (добавлены все основные, какие тебе нужны)
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

-- Тайминги
local DELAY_AFTER_TP = 0.15   -- Задержка после телепорта к пету
local DELAY_PROMPT   = 0.1   -- Задержка промпта
local DELAY_AFTER_SELL = 0.1  -- Пауза после продажи перед новым кругом

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
    
    -- Сканируем все папки внутри ItemSpawners
    for _, rarityFolder in ipairs(ItemSpawners:GetChildren()) do
        if TARGET_RARITIES[rarityFolder.Name] then
            local allChildren = rarityFolder:GetChildren()
            
            -- Если в папке больше 1 пета, мы можем собирать их, оставляя последний 1
            if #allChildren > 1 then
                -- Пробегаемся по петрам, но не трогаем самого последнего (индекс 1)
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

print("[Core Sell] Фоновый скрипт авто-продажи запущен!")

while true do
    task.wait(0.5) -- Защита от лагов, пока тумблер выключен
    
    if _G.AutoSellEnabled then
        local Character = LocalPlayer.Character
        local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
        
        if HumanoidRootPart then
            -- 1. Запоминаем Сейфзону перед началом круга
            local safeZoneCFrame = HumanoidRootPart.CFrame
            local maxCarry = getCurrentCarryLimit()
            local allPets = getAvailablePetsWithLimit()
            
            if #allPets > 0 then
                -- Перемешиваем доступных петов для рандомного ТП
                for i = #allPets, 2, -1 do
                    local j = math.random(i)
                    allPets[i], allPets[j] = allPets[j], allPets[i]
                end
                
                local gatheredCount = 0
                
                -- Начинаем сбор по локациям
                for _, petData in ipairs(allPets) do
                    -- Прерываем круг, если посреди фарма выключили Toggle
                    if not _G.AutoSellEnabled then break end
                    -- Если забили сумку — выходим из сбора
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
                
                -- 2. ТП на базу в безопасную зону
                print("[Core Sell] Рюкзак забит или петы кончились. Летим в SafeZone...")
                HumanoidRootPart.CFrame = safeZoneCFrame
                task.wait(0.1)
                
                -- 3. Юзаем Ремоут на продажу инвентаря
                if _G.AutoSellEnabled then
                    print("[Core Sell] Продаем собранных петов...")
                    pcall(function()
                        SellRemote:FireServer(unpack({ "Inventory" }))
                    end)
                end
                
                task.wait(DELAY_AFTER_SELL)
            else
                print("[Core Sell] На карте остались только 'последние' петы (по 1 в каждой папке). Ждем респавна...")
                task.wait(3)
            end
        end
    end
end
