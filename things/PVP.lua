-- // Переменная для включения/выключения (управляется твоим тоглом)
_G.PVP = false -- Изначально выключен, пока не активируешь в UI

-- // Настройки скрипта
local DISTANCE_TO_REPULSE = 15 -- Дистанция авто-отвода от врагов
local TELEPORT_DISTANCE = 100  -- Радиус твоей ТП-атаки
local REPULSE_POWER = 25       -- Сила отталкивания тебя от врагов

local TARGET_TOOLS = { ["Bat"] = true, ["Slap"] = true }

-- // Сервисы Roblox
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- // Внутренние переменные контроля конфликтов
local isAttacking = false -- Флаг атаки (когда true -> авто-отвод полностью изолирован)

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

-- // 1. ЛОГИКА АВТО-ОТВОДА (Защита от чужих ударов)
RunService.Heartbeat:Connect(function()
    -- Полный стоп, если выключен тумблер ИЛИ если мы сами прямо сейчас летим атаковать
    if not _G.PVP or isAttacking then return end 
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local myHrp = character.HumanoidRootPart

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local enemyChar = player.Character
            local enemyHrp = enemyChar:FindFirstChild("HumanoidRootPart")
            
            -- Проверяем, экипирован ли у врага опасный тул
            local hasTool = false
            for _, child in ipairs(enemyChar:GetChildren()) do
                if child:IsA("Tool") and TARGET_TOOLS[child.Name] then
                    hasTool = true
                    break
                end
            end
            
            -- Если враг с тулом подошел слишком близко — спасаем свою шкуру
            if hasTool and enemyHrp then
                local direction = (myHrp.Position - enemyHrp.Position)
                local distance = direction.Magnitude
                
                if distance <= DISTANCE_TO_REPULSE then
                    local pushDir = direction.Unit
                    if pushDir.X ~= pushDir.X then pushDir = Vector3.new(0, 0, 1) end -- Защита от багов CFrame
                    
                    -- Мгновенный сейв-эскейп назад
                    myHrp.CFrame = myHrp.CFrame + (pushDir * 3) 
                    myHrp.AssemblyLinearVelocity = pushDir * REPULSE_POWER
                end
            end
        end
    end
end)

-- // 2. ЛОГИКА ТЕЛЕПОРТА ЗА СПИНУ ПРИ НАЖАТИИ ЛКМ (Твоя атака)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    -- Если печатаешь в чате или тумблер выключен — игнорим клики
    if gameProcessed or not _G.PVP then return end
    
    -- Реагируем на Левую Кнопку Мыши
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        
        -- Проверяем, держишь ли ТЫ в руках Bat или Slap
        local holdingValidTool = false
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") and TARGET_TOOLS[child.Name] then
                holdingValidTool = true
                break
            end
        end
        
        -- Если ты готов к бою, ищем цель в радиусе 100 студов
        if holdingValidTool then
            local targetPlayer = getClosestPlayer(TELEPORT_DISTANCE)
            
            if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = character.HumanoidRootPart
                local enemyHrp = targetPlayer.Character.HumanoidRootPart
                
                -- ЖЕСТКИЙ БЛОК АВТО-ОТВОДА: теперь враг нас не оттолкнет во время нашего ТП
                isAttacking = true
                
                -- Запоминаем точку, откуда прилетели
                local oldCFrame = myHrp.CFrame
                
                -- Высчитываем позицию строго ЗА спиной чела (на расстоянии 2.5 студов для стопроцентного хита)
                -- И разворачиваем наше лицо (LookVector) в сторону его спины/головы
                local backPosition = enemyHrp.Position - (enemyHrp.CFrame.LookVector * 2.5)
                local targetCFrame = CFrame.new(backPosition, enemyHrp.Position)
                
                -- Влетаем со спины
                myHrp.CFrame = targetCFrame
                
                -- Задержка в 0.25 сек. Пока идет задержка, скрипт игнорирует отбрасывание,
                -- твоя игра успевает нанести урон, и анимация засчитывает удар.
                task.wait(0.25)
                
                -- Безопасно возвращаемся назад, откуда пришли
                myHrp.CFrame = oldCFrame
                
                -- Включаем авто-отвод обратно в штатный режим
                isAttacking = false
            end
        end
    end
end)
