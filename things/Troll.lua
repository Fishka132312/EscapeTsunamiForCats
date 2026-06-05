local Players         = game:GetService("Players")
local Workspace       = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer     = Players.LocalPlayer
local ItemSpawners    = Workspace:WaitForChild("ItemSpawners")
local GiftRemote      = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Events"):WaitForChild("GiftItem")
local ConfirmRemote   = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Events"):WaitForChild("ConfirmGift")

-- Настройки фильтра редкостей
local TARGET_RARITIES = {
    ["Common"] = true,
    ["Uncommon"] = true,
    ["Rare"] = true,
    ["Epic"] = true
}

-- Тайминги (задержки) для стабильной работы без киков
local DELAY_AFTER_TP = 0.35   -- Задержка после ТП к пету
local DELAY_PROMPT   = 0.15   -- Задержка промпта
local DELAY_GIFT     = 0.4    -- Задержка между экипировкой тула и отправкой (чтобы игра засчитала предмет в руке)

-- Функция получения лимита вместимости из UI
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

-- Поиск доступных петов на карте
local function getAvailablePets()
    local validPets = {}
    for rarityName, isTarget in pairs(TARGET_RARITIES) do
        if isTarget then
            local rarityFolder = ItemSpawners:FindFirstChild(rarityName)
            if rarityFolder then
                for _, pet in ipairs(rarityFolder:GetChildren()) do
                    local head = pet:FindFirstChild("Head")
                    local prompt = head and head:FindFirstChildOfClass("ProximityPrompt")
                    if head and prompt then
                        table.insert(validPets, { Item = pet, Head = head, Prompt = prompt })
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

print("[Core] Фоновый скрипт авто-дарения успешно загружен!")

-- Главный цикл
while true do
    task.wait(0.5) -- Защита от зависания, пока скрипт "спит"
    
    -- Скрипт активен только если включен Toggle в UI
    if _G.AutoGiftEnabled then
        local Character = LocalPlayer.Character
        local HumanoidRootPart = Character and Character:FindFirstChild("HumanoidRootPart")
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        
        -- Проверяем, выбран ли игрок и жив ли наш персонаж
        if _G.SelectedPlayer and HumanoidRootPart and Humanoid then
            local targetPlayer = Players:FindFirstChild(_G.SelectedPlayer)
            
            if targetPlayer then
                -- 1. Запоминаем Сейфзону перед кругом фарма
                local safeZoneCFrame = HumanoidRootPart.CFrame
                local maxCarry = getCurrentCarryLimit()
                local allPets = getAvailablePets()
                
                if #allPets > 0 then
                    -- Перемешиваем петов для рандома
                    for i = #allPets, 2, -1 do
                        local j = math.random(i)
                        allPets[i], allPets[j] = allPets[j], allPets[i]
                    end
                    
                    -- Сбор петов до заполнения лимита
                    local gatheredCount = 0
                    for _, petData in ipairs(allPets) do
                        if not _G.AutoGiftEnabled then break end -- Экстренный выход, если выключили во время ТП
                        
                        if gatheredCount >= maxCarry then break end
                        
                        if petData.Item and petData.Item.Parent and Character.Parent then
                            -- ТП к голове пета
                            HumanoidRootPart.CFrame = petData.Head.CFrame + Vector3.new(0, 2, 0)
                            task.wait(DELAY_AFTER_TP)
                            
                            firePrompt(petData.Prompt)
                            task.wait(DELAY_PROMPT)
                            
                            gatheredCount = gatheredCount + 1
                        end
                    end
                    
                    -- 2. Возврат в SafeZone
                    print("[Core] Сбор завершен. Возвращение на базу для разгрузки и дарения...")
                    HumanoidRootPart.CFrame = safeZoneCFrame
                    task.wait(0.5)
                    
                    -- 3. Процесс дарения собранных предметов
                    -- Ищем все инструменты (тулы) в Backpack, которые появились после сбора
                    local backpack = LocalPlayer:FindFirstChild("Backpack")
                    if backpack then
                        local tools = backpack:GetChildren()
                        
                        for _, tool in ipairs(tools) do
                            -- Проверяем условия на каждом шаге (вдруг цель вышла из игры или скрипт отключили)
                            if not _G.AutoGiftEnabled then break end
                            if not Players:FindFirstChild(_G.SelectedPlayer) then 
                                warn("[Core] Целевой игрок вышел из игры!")
                                break 
                            end
                            
                            if tool:IsA("Tool") then
                                print("[Core] Дарим предмет:", tool.Name, "игроку:", _G.SelectedPlayer)
                                
                                -- Достаем тул из рюкзака в руки персонажа
                                Humanoid:EquipTool(tool)
                                task.wait(DELAY_GIFT) -- Обязательно ждем, чтобы игра поняла, что тул в руке
                                
                                -- Стреляем в первый ремонт (отправка запроса на подарок)
                                local success, err = pcall(function()
                                    GiftRemote:FireServer(unpack({ targetPlayer }))
                                end)
                                
                                task.wait(0.15)
                                
                                -- Стреляем во второй ремонт (подтверждение)
                                if success then
                                    pcall(function()
                                        ConfirmRemote:FireServer(unpack({ true }))
                                    end)
                                end
                                
                                task.wait(0.3) -- Небольшая пауза между подарками, чтобы не крашнуть сервер
                            end
                        end
                    end
                    
                else
                    print("[Core] Подходящие петы не найдены. Ждем...")
                    task.wait(2)
                end
            else
                warn("[Core] Выбранный игрок отсутствует на сервере. Выберите другого!")
                task.wait(2)
            end
        else
            if not _G.SelectedPlayer then
                print("[Core] Скрипт включен, но игрок в Dropdown еще не выбран!")
                task.wait(2)
            end
        end
    end
end
