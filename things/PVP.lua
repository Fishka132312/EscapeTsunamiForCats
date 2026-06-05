-- ============================================================
--  PVP LocalScript | Roblox
--  Требования: LocalScript внутри StarterPlayerScripts
-- ============================================================

-- ┌─────────────────────────────────────────────────────────┐
-- │                   НАСТРОЙКИ (CONFIG)                    │
-- └─────────────────────────────────────────────────────────┘
local CONFIG = {
    -- Анти-атака
    ANTI_ATTACK_RADIUS   = 9,      -- studs: радиус срабатывания защиты
    PUSHBACK_FORCE       = 90,     -- сила отталкивания (studs/s)
    PUSHBACK_Y           = 8,      -- вертикальная составляющая отталкивания
    PUSHBACK_DURATION    = 0.18,   -- секунд действия BodyVelocity

    -- Атака
    ATTACK_RADIUS        = 100,    -- studs: радиус поиска цели
    TELEPORT_BEHIND_DIST = 3.5,    -- studs: насколько сзади цели встать
    RETURN_DELAY         = 0.45,   -- секунд до возврата на исходную позицию
    ATTACK_COOLDOWN      = 0.6,    -- секунд между атаками

    -- Системные
    ATTACK_TOOLS         = {"Bat", "Slap"},  -- имена инструментов
    PUSHBACK_IMMUNE_TIME = 0.7,    -- секунд иммунитета к отталкиванию после телепорта
}

-- ┌─────────────────────────────────────────────────────────┐
-- │                   СЕРВИСЫ                               │
-- └─────────────────────────────────────────────────────────┘
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- ┌─────────────────────────────────────────────────────────┐
-- │                   СОСТОЯНИЕ                             │
-- └─────────────────────────────────────────────────────────┘
local State = {
    isTeleporting    = false,   -- флаг: сейчас выполняется телепорт-атака
    lastAttackTime   = 0,       -- тик последней атаки
    connections      = {},      -- все соединения для cleanup
    toolConnections  = {},      -- соединения конкретного инструмента
}

-- ┌─────────────────────────────────────────────────────────┐
-- │                   ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ               │
-- └─────────────────────────────────────────────────────────┘

--- Получить символ и HRP локального игрока (или nil)
local function getLocalCharacter()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return nil, nil end
    return char, hrp
end

--- Проверить: имя инструмента входит в список атакующих
local function isAttackTool(name)
    for _, n in ipairs(CONFIG.ATTACK_TOOLS) do
        if n == name then return true end
    end
    return false
end

--- Получить экипированный атакующий инструмент игрока (или nil)
local function getEquippedAttackTool(character)
    if not character then return nil end
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") and isAttackTool(child.Name) then
            return child
        end
    end
    return nil
end

--- Найти ближайшего живого игрока (исключая Local) в радиусе
local function getNearestPlayer(origin, radius)
    local closest, closestDist = nil, radius + 1
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end
        local dist = (hrp.Position - origin).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = player
        end
    end
    return closest
end

--- Безопасно отключить и очистить список соединений
local function cleanupConnections(list)
    for _, conn in ipairs(list) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    table.clear(list)
end

-- ┌─────────────────────────────────────────────────────────┐
-- │               АНТИ-АТАКА (ЗАЩИТА)                       │
-- └─────────────────────────────────────────────────────────┘

--- Создать кратковременный BodyVelocity для отталкивания
local function applyPushback(hrp, direction)
    -- Убираем старый BV если есть
    local old = hrp:FindFirstChild("__PVP_BV")
    if old then old:Destroy() end

    local bv = Instance.new("BodyVelocity")
    bv.Name      = "__PVP_BV"
    bv.Velocity  = direction
    bv.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
    bv.P         = 1e4
    bv.Parent    = hrp

    task.delay(CONFIG.PUSHBACK_DURATION, function()
        if bv and bv.Parent then bv:Destroy() end
    end)
end

--- Основной цикл анти-атаки — вызывается каждый Heartbeat
local function antiAttackStep()
    -- Не работаем во время телепорт-атаки
    if State.isTeleporting then return end

    local char, hrp = getLocalCharacter()
    if not char then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local enemyChar = player.Character
        if not enemyChar then continue end

        -- Проверяем экипированный инструмент врага
        if not getEquippedAttackTool(enemyChar) then continue end

        local enemyHRP = enemyChar:FindFirstChild("HumanoidRootPart")
        if not enemyHRP then continue end

        local dist = (hrp.Position - enemyHRP.Position).Magnitude
        if dist < CONFIG.ANTI_ATTACK_RADIUS then
            -- Направление от врага к нам + небольшой Y
            local pushDir = (hrp.Position - enemyHRP.Position).Unit
            pushDir = Vector3.new(pushDir.X, 0.15, pushDir.Z).Unit
            applyPushback(hrp, pushDir * CONFIG.PUSHBACK_FORCE
                + Vector3.new(0, CONFIG.PUSHBACK_Y, 0))
        end
    end
end

-- ┌─────────────────────────────────────────────────────────┐
-- │               ТЕЛЕПОРТ-АТАКА                            │
-- └─────────────────────────────────────────────────────────┘

--- Выполнить телепорт-атаку к цели и обратно
local function performAttack(localChar, localHRP)
    local now = tick()
    if now - State.lastAttackTime < CONFIG.ATTACK_COOLDOWN then return end

    local target = getNearestPlayer(localHRP.Position, CONFIG.ATTACK_RADIUS)
    if not target then return end

    local targetChar = target.Character
    if not targetChar then return end
    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    -- Запоминаем исходную позицию и угол
    local originCFrame = localHRP.CFrame
    State.lastAttackTime = now
    State.isTeleporting  = true

    -- Вычисляем позицию «за спиной» цели
    local targetCF = targetHRP.CFrame
    -- Вектор «назад» для цели (её -LookVector = направление за спину)
    local behindPos = targetCF.Position - targetCF.LookVector * CONFIG.TELEPORT_BEHIND_DIST

    -- Смотрим лицом к цели
    local facingCF = CFrame.new(behindPos, targetHRP.Position)

    -- Телепорт к цели
    localHRP.CFrame = facingCF

    -- Небольшая пауза (имитация удара)
    task.wait(CONFIG.RETURN_DELAY)

    -- Проверяем, жив ли ещё персонаж
    local stillAlive = localChar
        and localChar.Parent
        and localHRP.Parent == localChar

    if stillAlive then
        -- Возврат на исходную позицию
        localHRP.CFrame = originCFrame
    end

    -- Даём системе «успокоиться» перед снятием флага
    task.wait(0.05)
    State.isTeleporting = false
end

-- ┌─────────────────────────────────────────────────────────┐
-- │          ПОДКЛЮЧЕНИЕ/ОТКЛЮЧЕНИЕ ИНСТРУМЕНТА             │
-- └─────────────────────────────────────────────────────────┘

--- Навесить обработчик Activated на атакующий инструмент
local function hookTool(tool)
    if not isAttackTool(tool.Name) then return end

    cleanupConnections(State.toolConnections)

    local conn = tool.Activated:Connect(function()
        if not _G.PVP then return end
        local char, hrp = getLocalCharacter()
        if not char then return end
        performAttack(char, hrp)
    end)
    table.insert(State.toolConnections, conn)
end

--- Отслеживать экипировку/снятие инструментов персонажа
local function watchCharacterTools(character)
    -- Уже экипированный инструмент (при ресете персонаж создаётся заново)
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then hookTool(child) end
    end

    -- Новые инструменты
    local addedConn = character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then hookTool(child) end
    end)
    local removedConn = character.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            cleanupConnections(State.toolConnections)
        end
    end)
    table.insert(State.connections, addedConn)
    table.insert(State.connections, removedConn)
end

-- ┌─────────────────────────────────────────────────────────┐
-- │            ОСНОВНОЙ HEARTBEAT LOOP                      │
-- └─────────────────────────────────────────────────────────┘

local heartbeatConn = RunService.Heartbeat:Connect(function()
    -- Скрипт работает только при PVP = true
    if not _G.PVP then return end
    antiAttackStep()
end)
table.insert(State.connections, heartbeatConn)

-- ┌─────────────────────────────────────────────────────────┐
-- │            СЛЕЖЕНИЕ ЗА ПЕРСОНАЖЕМ (RESPAWN)             │
-- └─────────────────────────────────────────────────────────┘

local function onCharacterAdded(character)
    -- Сбрасываем состояние при ресете
    State.isTeleporting  = false
    State.lastAttackTime = 0
    cleanupConnections(State.toolConnections)

    -- Ждём полной загрузки персонажа
    character:WaitForChild("HumanoidRootPart", 10)
    character:WaitForChild("Humanoid", 10)

    watchCharacterTools(character)
end

-- Подключаем для текущего и будущих персонажей
if LocalPlayer.Character then
    task.spawn(onCharacterAdded, LocalPlayer.Character)
end
local charAddedConn = LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
table.insert(State.connections, charAddedConn)

-- ┌─────────────────────────────────────────────────────────┐
-- │            CLEANUP ПРИ ВЫХОДЕ / ОТКЛЮЧЕНИИ              │
-- └─────────────────────────────────────────────────────────┘

-- При выходе игрока — чистим всё
local removingConn = Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        cleanupConnections(State.toolConnections)
        cleanupConnections(State.connections)
    end
end)
-- (removingConn сам по себе не нужно хранить — процесс всё равно умирает)

-- ============================================================
--  Использование:
--    _G.PVP = true   → включить скрипт
--    _G.PVP = false  → выключить (по умолчанию)
-- ============================================================
_G.PVP = _G.PVP or false
print("[PVP Script] Загружен. _G.PVP =", _G.PVP)
