-- // Переменная для включения/выключения (управляется твоим тоглом)
_G.PVP = false 

-- // Настройки скрипта
local BASE_DISTANCE = 16       -- Базовая дистанция авто-отвода
local TELEPORT_DISTANCE = 100  -- Радиус твоей ТП-Атаки
local HORIZONTAL_POWER = 35    -- Сила отбрасывания назад (увеличено)
local VERTICAL_POWER = 40      -- Сила подбрасывания вверх (чтобы скоростные пролетали снизу)

local TARGET_TOOLS = { ["Bat"] = true, ["Slap"] = true }

-- // Сервисы Roblox
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local isAttacking = false 

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

-- // 1. УЛУЧШЕННАЯ ЛОГИКА АВТО-ОТВОДА (Анти-спидхак защита)
RunService.Heartbeat:Connect(function()
    if not _G.PVP or isAttacking then return end 
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local myHrp = character.HumanoidRootPart

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local enemyChar = player.Character
            local enemyHrp = enemyChar:FindFirstChild("HumanoidRootPart")
            
            local hasTool = false
            for _, child in ipairs(enemyChar:GetChildren()) do
                if child:IsA("Tool") and TARGET_TOOLS[child.Name] then
                    hasTool = true
                    break
                end
            end
            
            if hasTool and enemyHrp then
                -- Считаем скорость врага. Если он бежит слишком быстро, расширяем зону защиты
                local enemyVelocity = enemyHrp.AssemblyLinearVelocity.Magnitude
                local dynamicDistance = BASE_DISTANCE
                if enemyVelocity > 25 then
                    dynamicDistance = BASE_DISTANCE + (enemyVelocity * 0.15) -- Увеличиваем радиус под быструю цель
                end

                local direction = (myHrp.Position - enemyHrp.Position)
                local distance = direction.Magnitude
                
                if distance <= dynamicDistance then
                    local pushDir = direction.Unit
                    if pushDir.X ~= pushDir.X then pushDir = Vector3.new(0, 0, 1) end 
                    
                    -- Убираем Y координату из направления, чтобы чистый горизонтальный вектор шел назад
                    local flatPushDir = Vector3.new(pushDir.X, 0, pushDir.Z).Unit
                    
                    -- Телепортируем немного вверх и назад, чтобы разорвать дистанцию
                    myHrp.CFrame = myHrp.CFrame + Vector3.new(0, 2, 0) + (flatPushDir * 4)
                    
                    -- Задаем импульс: HORIZONTAL_POWER улетает назад, VERTICAL_POWER подкидывает в воздух
                    myHrp.AssemblyLinearVelocity = (flatPushDir * HORIZONTAL_POWER) + Vector3.new(0, VERTICAL_POWER, 0)
                end
            end
        end
    end
end)

-- // 2. ЛОГИКА ТЕЛЕПОРТА ЗА СПИНУ ПРИ НАЖАТИИ ЛКМ 
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not _G.PVP then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        
        local holdingValidTool = false
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") and TARGET_TOOLS[child.Name] then
                holdingValidTool = true
                break
            end
        end
        
        if holdingValidTool then
            local targetPlayer = getClosestPlayer(TELEPORT_DISTANCE)
            
            if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = character.HumanoidRootPart
                local enemyHrp = targetPlayer.Character.HumanoidRootPart
                
                isAttacking = true
                
                local oldCFrame = myHrp.CFrame
                
                -- Появление четко за спиной на расстоянии 2.3 студа (еще ближе для точности)
                local backPosition = enemyHrp.Position - (enemyHrp.CFrame.LookVector * 2.3)
                local targetCFrame = CFrame.new(backPosition, enemyHrp.Position)
                
                myHrp.CFrame = targetCFrame
                
                task.wait(0.22) -- Чуть уменьшил задержку, чтобы удар проходил молниеносно
                
                myHrp.CFrame = oldCFrame
                
                isAttacking = false
            end
        end
    end
end)-- // Переменная для включения/выключения (управляется твоим тоглом)
_G.PVP = false 

-- // Настройки скрипта
local BASE_DISTANCE = 16       -- Базовая дистанция авто-отвода
local TELEPORT_DISTANCE = 100  -- Радиус твоей ТП-Атаки
local HORIZONTAL_POWER = 35    -- Сила отбрасывания назад (увеличено)
local VERTICAL_POWER = 40      -- Сила подбрасывания вверх (чтобы скоростные пролетали снизу)

local TARGET_TOOLS = { ["Bat"] = true, ["Slap"] = true }

-- // Сервисы Roblox
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local isAttacking = false 

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

-- // 1. УЛУЧШЕННАЯ ЛОГИКА АВТО-ОТВОДА (Анти-спидхак защита)
RunService.Heartbeat:Connect(function()
    if not _G.PVP or isAttacking then return end 
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local myHrp = character.HumanoidRootPart

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local enemyChar = player.Character
            local enemyHrp = enemyChar:FindFirstChild("HumanoidRootPart")
            
            local hasTool = false
            for _, child in ipairs(enemyChar:GetChildren()) do
                if child:IsA("Tool") and TARGET_TOOLS[child.Name] then
                    hasTool = true
                    break
                end
            end
            
            if hasTool and enemyHrp then
                -- Считаем скорость врага. Если он бежит слишком быстро, расширяем зону защиты
                local enemyVelocity = enemyHrp.AssemblyLinearVelocity.Magnitude
                local dynamicDistance = BASE_DISTANCE
                if enemyVelocity > 25 then
                    dynamicDistance = BASE_DISTANCE + (enemyVelocity * 0.15) -- Увеличиваем радиус под быструю цель
                end

                local direction = (myHrp.Position - enemyHrp.Position)
                local distance = direction.Magnitude
                
                if distance <= dynamicDistance then
                    local pushDir = direction.Unit
                    if pushDir.X ~= pushDir.X then pushDir = Vector3.new(0, 0, 1) end 
                    
                    -- Убираем Y координату из направления, чтобы чистый горизонтальный вектор шел назад
                    local flatPushDir = Vector3.new(pushDir.X, 0, pushDir.Z).Unit
                    
                    -- Телепортируем немного вверх и назад, чтобы разорвать дистанцию
                    myHrp.CFrame = myHrp.CFrame + Vector3.new(0, 2, 0) + (flatPushDir * 4)
                    
                    -- Задаем импульс: HORIZONTAL_POWER улетает назад, VERTICAL_POWER подкидывает в воздух
                    myHrp.AssemblyLinearVelocity = (flatPushDir * HORIZONTAL_POWER) + Vector3.new(0, VERTICAL_POWER, 0)
                end
            end
        end
    end
end)

-- // 2. ЛОГИКА ТЕЛЕПОРТА ЗА СПИНУ ПРИ НАЖАТИИ ЛКМ 
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not _G.PVP then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        
        local holdingValidTool = false
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") and TARGET_TOOLS[child.Name] then
                holdingValidTool = true
                break
            end
        end
        
        if holdingValidTool then
            local targetPlayer = getClosestPlayer(TELEPORT_DISTANCE)
            
            if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local myHrp = character.HumanoidRootPart
                local enemyHrp = targetPlayer.Character.HumanoidRootPart
                
                isAttacking = true
                
                local oldCFrame = myHrp.CFrame
                
                -- Появление четко за спиной на расстоянии 2.3 студа (еще ближе для точности)
                local backPosition = enemyHrp.Position - (enemyHrp.CFrame.LookVector * 2.3)
                local targetCFrame = CFrame.new(backPosition, enemyHrp.Position)
                
                myHrp.CFrame = targetCFrame
                
                task.wait(0.22) -- Чуть уменьшил задержку, чтобы удар проходил молниеносно
                
                myHrp.CFrame = oldCFrame
                
                isAttacking = false
            end
        end
    end
end)
