-- // Переменная для включения/выключения (глобальная, как ты просил)
_G.PVP = false -- Поставь false, если хочешь изначально выключить

-- // Настройки скрипта
local DISTANCE_TO_REPULSE = 15 -- Дистанция, ближе которой враг не подобается (авто-отвод)
local TELEPORT_DISTANCE = 100  -- Дистанция твоей атаки
local REPULSE_POWER = 25       -- Сила, с которой тебя отталкивает назад от врага

local TARGET_TOOLS = { ["Bat"] = true, ["Slap"] = true }

-- // Сервисы Roblox
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- // Внутренние переменные контроля
local isAttacking = false -- Флаг, чтобы авто-отвод не мешал во время ТП-удара

-- // Функция поиска ближайшего игрока для ТП-атаки
local function getClosestPlayer(maxDistance)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    
    local myHrp = character.HumanoidRootPart
    local closestPlayer = nil
    local shortestDistance = maxDistance

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local enemyHrp = player.Character.HumanoidRootPart
            local distance = (myHrp.Position - enemyHrp.Position).Magnitude
            
            if distance < shortestDistance then
                shortestDistance = distance
                closestPlayer = player
            end
        end
    end
    return closestPlayer
end

-- // 1. ЛОГИКА АВТО-ОТВОДА (Защита от ударов)
RunService.Heartbeat:Connect(function()
    if not _G.PVP or isAttacking then return end -- Если выключен или мы сами атакуем — отдыхаем
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local myHrp = character.HumanoidRootPart

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local enemyChar = player.Character
            local enemyHrp = enemyChar:FindFirstChild("HumanoidRootPart")
            
            -- Проверяем, держит ли враг Bat или Slap (тул появляется прямо в модели персонажа)
            local hasTool = false
            for _, child in ipairs(enemyChar:GetChildren()) do
                if child:IsA("Tool") and TARGET_TOOLS[child.Name] then
                    hasTool = true
                    break
                end
            end
            
            -- Если у него есть тул и он близко
            if hasTool and enemyHrp then
                local direction = (myHrp.Position - enemyHrp.Position)
                local distance = direction.Magnitude
                
                if distance <= DISTANCE_TO_REPULSE then
                    -- Отталкиваем нашего персонажа назад от врага
                    local pushDir = direction.Unit
                    if pushDir.X ~= pushDir.X then pushDir = Vector3.new(0, 0, 1) end -- Фикс бага NaN
                    
                    -- Смещение позиции + небольшой импульс скорости для плавности
                    myHrp.CFrame = myHrp.CFrame + (pushDir * 3) 
                    myHrp.AssemblyLinearVelocity = pushDir * REPULSE_POWER
                end
            end
        end
    end
end)

-- // 2. ЛОГИКА ТЕЛЕПОРТА ПРИ НАЖАТИИ ЛКМ (Твоя атака)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not _G.PVP then return end
    
    -- Проверяем нажатие Левой Кнопки Мыши
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        
        -- Проверяем, экипирован ли тул у ТЕБЯ
        local holdingValidTool = false
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") and TARGET_TOOLS[child.Name] then
                holdingValidTool = true
                break
            end
        end
        
        -- Если тул в руках, ищем жертву в радиусе 100 студов
        if holdingValidTool then
            local targetPlayer = getClosestPlayer(TELEPORT_DISTANCE)
            
            if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = character.HumanoidRootPart
                local enemyHrp = targetPlayer.Character.HumanoidRootPart
                
                -- Блокируем авто-отвод, чтобы не было конфликта
                isAttacking = true
                
                -- Сохраняем нашу старую позицию, чтобы вернуться
                local oldCFrame = myHrp.CFrame
                
                -- Считаем позицию СЗАДИ врага (на расстоянии 3 студа) и смотрим прямо на него
                local backPosition = enemyHrp.Position - (enemyHrp.CFrame.LookVector * 3)
                local targetCFrame = CFrame.new(backPosition, enemyHrp.Position)
                
                -- ТП к нему за спину
                myHrp.CFrame = targetCFrame
                
                -- Небольшая задержка, чтобы анимация твоего удара прошла (0.2 - 0.3 сек)
                task.wait(0.25)
                
                -- ТП обратно на исходную позицию
                myHrp.CFrame = oldCFrame
                
                -- Возвращаем авто-отвод в работу
                isAttacking = false
            end
        end
    end
end)
