local Players         = game:GetService("Players")
local Workspace       = game:GetService("Workspace")
local VirtualUser     = game:GetService("VirtualUser")

local LocalPlayer     = Players.LocalPlayer
local Character       = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local ItemSpawners    = Workspace:WaitForChild("ItemSpawners")

-- ══════════════════════════════════════════════════════════════
-- НАСТРОЙКИ АВТОФАРМА
-- ══════════════════════════════════════════════════════════════
local TARGET_RARITIES = {
    ["Common"] = true,
    ["Uncommon"] = true,
    ["Rare"] = true,
    ["Epic"] = true
}

local DELAY_AFTER_TP = 0.35   -- Задержка после телепорта к пету (чтобы игра прогрузила его)
local DELAY_PROMPT   = 0.15   -- Задержка перед/после активации промпта
local LOOP_COOLDOWN  = 1.0    -- Пауза между кругами фарма, когда сундук забит и мы вернулись на базу

-- ══════════════════════════════════════════════════════════════
-- ФУНКЦИИ ПОЛУЧЕНИЯ ИНФОРМАЦИИ
-- ══════════════════════════════════════════════════════════════

-- Функция получения текущего лимита вместимости из UI
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
                    -- Извлекаем только цифры из текста (например "6" из текста "6" или "6/10")
                    local limit = tonumber(beforeText.Text:match("%d+"))
                    if limit then return limit end
                end
            end
        end
    end
    
    warn("[AutoFarm] Не удалось прочитать лимит из UI! Попробуй открыть меню Carry. По умолчанию взят лимит: 1")
    return 1 -- Безопасное значение, если UI закрыт или не найден
end

-- Функция сбора всех валидных петов на карте по вашим фильтрам
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
                        table.insert(validPets, {
                            Item = pet,
                            Head = head,
                            Prompt = prompt,
                            Rarity = rarityName
                        })
                    end
                end
            end
        end
    end
    return validPets
end

-- Имитация нажатия клавиши для ProximityPrompt
local function firePrompt(prompt)
    if prompt then
        prompt:InputHoldBegin()
        task.wait(0.05)
        prompt:InputHoldEnd()
    end
end

-- ══════════════════════════════════════════════════════════════
-- ОСНОВНОЙ ЛУП АВТОФАРМА
-- ══════════════════════════════════════════════════════════════

print("[AutoFarm] Скрипт запущен!")

-- Запоминаем позицию старта (нашу SafeZone) перед началом цикла
local safeZoneCFrame = HumanoidRootPart.CFrame
print("[AutoFarm] Точка SafeZone сохранена на вашей текущей позиции!")

while true do
    -- 1. Обновляем максимальный лимит вместимости
    local maxCarry = getCurrentCarryLimit()
    
    -- 2. Получаем список доступных петов
    local allPets = getAvailablePets()
    
    if #allPets == 0 then
        print("[AutoFarm] Подходящих петов на карте пока нет. Ждем новые спавны...")
        task.wait(3)
    else
        print(string.format("[AutoFarm] Найдено подходящих петов: %d. Начинаем сбор (Лимит: %d)...", #allPets, maxCarry))
        
        local gatheredThisRound = 0
        
        -- Перемешиваем таблицу петов, чтобы телепортироваться к РАНДОМНЫМ
        for i = #allPets, 2, -1 do
            local j = math.random(i)
            allPets[i], allPets[j] = allPets[j], allPets[i]
        end
        
        -- Сбор петов
        for _, petData in ipairs(allPets) do
            -- Проверяем, не удалили ли пета (например, кто-то другой забрал) и существует ли еще персонаж
            if petData.Item and petData.Item.Parent and HumanoidRootPart then
                
                if gatheredThisRound >= maxCarry then 
                    break -- Достигли лимита вместимости, выходим из цикла сбора
                end
                
                print(string.format("[AutoFarm] ТП к пету [%s]. Собрано в этом раунде: %d/%d", petData.Rarity, gatheredThisRound, maxCarry))
                
                -- Телепортируем персонажа чуть выше головы пета, чтобы не застрять
                HumanoidRootPart.CFrame = petData.Head.CFrame + Vector3.new(0, 2, 0)
                task.wait(DELAY_AFTER_TP)
                
                -- Активируем сбор
                firePrompt(petData.Prompt)
                task.wait(DELAY_PROMPT)
                
                gatheredThisRound = gatheredThisRound + 1
            end
        end
        
        -- 3. Возвращение в SafeZone после заполнения сумки
        print("[AutoFarm] Лимит достигнут или петы кончились! Возвращаемся в SafeZone для разгрузки...")
        HumanoidRootPart.CFrame = safeZoneCFrame
        
        -- Даем игре время разгрузить петов/обновить статус
        task.wait(LOOP_COOLDOWN)
    end
end
