--[[
    PVP Utility Script
    LocalScript (Executor)
    Luau | Roblox

    Управление: _G.PVP = true/false
--]]

-- ============================================================
--  КОНФИГ — все настройки в одном месте
-- ============================================================
local CONFIG = {
    DODGE_RADIUS    = 11,   -- Студов: дистанция, при которой срабатывает авто-додж
    ATTACK_RADIUS   = 100,  -- Студов: макс. дистанция для блинк-атаки
    ATTACK_DURATION = 1,    -- Секунд: сколько держимся за спиной цели
    BEHIND_OFFSET   = 3.5,  -- Студов: насколько сзади мы встаём (от центра тела)
    TOOL_NAMES      = { Bat = true, Slap = true }, -- Инструменты, на которые реагируем
}

-- ============================================================
--  СЕРВИСЫ
-- ============================================================
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace      = game:GetService("Workspace")

-- ============================================================
--  ССЫЛКИ НА ЛОКАЛЬНОГО ИГРОКА
-- ============================================================
local LocalPlayer = Players.LocalPlayer

-- ============================================================
--  ФЛАГИ СОСТОЯНИЯ (анти-глитч / дебаунс)
-- ============================================================
local isAttacking = false   -- true во время блинк-атаки
local isDodging   = false   -- true во время авто-доджа

-- Текущая цель атаки (чтобы додж игнорировал именно её)
local attackTarget: Player? = nil

-- ============================================================
--  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================

--- Возвращает корневую часть (HumanoidRootPart) персонажа игрока,
--- или nil, если персонаж не загружен / мёртв.
local function getRootPart(player: Player): BasePart?
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid?
    if not hum or hum.Health <= 0 then return nil end
    return hrp
end

--- Проверяет, экипирован ли у игрока Tool из списка CONFIG.TOOL_NAMES.
local function hasDangerousTool(player: Player): boolean
    local char = player.Character
    if not char then return false end
    for _, obj in char:GetChildren() do
        if obj:IsA("Tool") and CONFIG.TOOL_NAMES[obj.Name] then
            return true
        end
    end
    return false
end

--- Возвращает позицию ЗА СПИНОЙ указанной BasePart.
--- offset — расстояние сзади в студах.
local function getBehindPosition(targetRoot: BasePart, offset: number): Vector3
    -- LookVector смотрит вперёд; -LookVector — назад
    return targetRoot.Position - (targetRoot.CFrame.LookVector * offset)
end

--- Raycast-проверка: можно ли безопасно встать в точку dest из точки origin?
--- Возвращает (безопасно: bool, скорректированная точка: Vector3).
local function findSafePosition(origin: Vector3, dest: Vector3): (boolean, Vector3)
    local direction = dest - origin
    local distance  = direction.Magnitude

    if distance < 0.01 then
        -- Точки совпадают — просто разрешаем
        return true, dest
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    -- Исключаем собственного персонажа из Raycast
    local myChar = LocalPlayer.Character
    if myChar then
        rayParams.FilterDescendantsInstances = { myChar }
    end

    local result = Workspace:Raycast(origin, direction.Unit * distance, rayParams)

    if result then
        -- Луч что-то задел — берём точку чуть ПЕРЕД препятствием (0.5 ст. отступ)
        local safePoint = result.Position + result.Normal * 0.5
        return false, safePoint
    end

    return true, dest
end

--- Мгновенно телепортирует LocalPlayer в указанную позицию.
--- Разворачивает персонажа лицом к faceTarget (если передан).
local function teleportTo(position: Vector3, faceTarget: Vector3?)
    local myRoot = getRootPart(LocalPlayer)
    if not myRoot then return end

    local newCF: CFrame
    if faceTarget then
        -- Смотрим на цель, но берём только горизонтальную ориентацию
        local lookAt = Vector3.new(faceTarget.X, position.Y, faceTarget.Z)
        newCF = CFrame.lookAt(position, lookAt)
    else
        newCF = CFrame.new(position)
    end

    myRoot.CFrame = newCF
end

--- Возвращает ближайшего живого врага в радиусе maxDist (в студах).
--- Исключает самого LocalPlayer.
local function findNearestEnemy(maxDist: number): (Player?, BasePart?)
    local myRoot = getRootPart(LocalPlayer)
    if not myRoot then return nil, nil end

    local bestDist   = maxDist
    local bestPlayer: Player? = nil
    local bestRoot:   BasePart? = nil

    for _, player in Players:GetPlayers() do
        if player == LocalPlayer then continue end

        local root = getRootPart(player)
        if not root then continue end

        local dist = (root.Position - myRoot.Position).Magnitude
        if dist < bestDist then
            bestDist   = dist
            bestPlayer = player
            bestRoot   = root
        end
    end

    return bestPlayer, bestRoot
end

-- ============================================================
--  БЛИНК-АТАКА
-- ============================================================

--- Исполняется при активации Tool (ЛКМ).
--- Телепортирует нас за спину ближайшего врага, удерживает ATTACK_DURATION сек,
--- затем возвращает на исходную позицию.
local function doBlinkAttack()
    -- Не атакуем, если уже атакуем или уклоняемся
    if isAttacking or isDodging then return end
    -- Скрипт работает только при _G.PVP == true
    if not _G.PVP then return end

    local myRoot = getRootPart(LocalPlayer)
    if not myRoot then return end

    local targetPlayer, targetRoot = findNearestEnemy(CONFIG.ATTACK_RADIUS)
    if not targetPlayer or not targetRoot then return end

    -- Запоминаем исходную позицию
    local originPosition = myRoot.Position

    -- Вычисляем позицию за спиной
    local behindPos = getBehindPosition(targetRoot, CONFIG.BEHIND_OFFSET)
    local _, safeDest = findSafePosition(myRoot.Position, behindPos)

    -- Устанавливаем флаги
    isAttacking  = true
    attackTarget = targetPlayer

    -- Телепортируемся за спину, смотрим на врага
    teleportTo(safeDest, targetRoot.Position)

    -- ── Target Tracking: прилипаем к спине в течение ATTACK_DURATION ──
    local elapsed = 0
    local connection: RBXScriptConnection

    connection = RunService.Heartbeat:Connect(function(dt)
        -- Прерываем, если PVP выключили во время атаки
        if not _G.PVP then
            connection:Disconnect()
            isAttacking  = false
            attackTarget = nil
            return
        end

        elapsed += dt
        if elapsed >= CONFIG.ATTACK_DURATION then
            connection:Disconnect()

            -- Возвращаемся на исходную позицию (или ближайшую безопасную)
            local _, safeOrigin = findSafePosition(
                getRootPart(LocalPlayer) and getRootPart(LocalPlayer).Position or originPosition,
                originPosition
            )
            teleportTo(safeOrigin)

            -- Снимаем флаги
            isAttacking  = false
            attackTarget = nil
            return
        end

        -- Обновляем позицию: цель могла сдвинуться
        local currentRoot = getRootPart(targetPlayer)
        if not currentRoot then
            -- Цель умерла или вышла — возвращаемся
            connection:Disconnect()
            local _, safeOrigin = findSafePosition(
                getRootPart(LocalPlayer) and getRootPart(LocalPlayer).Position or originPosition,
                originPosition
            )
            teleportTo(safeOrigin)
            isAttacking  = false
            attackTarget = nil
            return
        end

        local newBehind = getBehindPosition(currentRoot, CONFIG.BEHIND_OFFSET)
        local _, newSafe = findSafePosition(
            getRootPart(LocalPlayer) and getRootPart(LocalPlayer).Position or newBehind,
            newBehind
        )
        teleportTo(newSafe, currentRoot.Position)
    end)
end

-- ============================================================
--  АВТО-ДОДЖ
-- ============================================================

--- Вызывается из главного цикла при обнаружении угрозы.
--- Телепортирует LocalPlayer в безопасную точку подальше от врага.
local function doDodge(threatRoot: BasePart)
    if isDodging or isAttacking then return end

    local myRoot = getRootPart(LocalPlayer)
    if not myRoot then return end

    isDodging = true

    -- Направление ОТСТУПЛЕНИЯ: от врага к нам, затем за нас
    local awayDir = (myRoot.Position - threatRoot.Position).Unit
    local dodgeTarget = myRoot.Position + awayDir * (CONFIG.DODGE_RADIUS * 1.5)

    -- Raycast-проверка, чтобы не влететь в стену
    local _, safeDest = findSafePosition(myRoot.Position, dodgeTarget)

    teleportTo(safeDest)

    -- Короткий кулдаун, чтобы не спамить доджи подряд
    task.delay(0.3, function()
        isDodging = false
    end)
end

-- ============================================================
--  ПОДКЛЮЧЕНИЕ К ИНСТРУМЕНТАМ ЛОКАЛЬНОГО ИГРОКА
-- ============================================================

--- Вешает Activated на Tool, если его имя в списке CONFIG.TOOL_NAMES.
local function hookTool(tool: Tool)
    if not CONFIG.TOOL_NAMES[tool.Name] then return end

    tool.Activated:Connect(function()
        if _G.PVP then
            task.spawn(doBlinkAttack)
        end
    end)
end

--- Отслеживаем экипировку/деэкипировку инструментов у LocalPlayer.
local function watchCharacter(character: Model)
    -- Инструменты, экипированные прямо сейчас
    for _, obj in character:GetChildren() do
        if obj:IsA("Tool") then
            hookTool(obj :: Tool)
        end
    end

    -- Инструменты, добавляемые позже
    character.ChildAdded:Connect(function(obj)
        if obj:IsA("Tool") then
            hookTool(obj :: Tool)
        end
    end)
end

-- Применяем к уже загруженному персонажу
if LocalPlayer.Character then
    watchCharacter(LocalPlayer.Character)
end
-- И к будущим (после смерти/респауна)
LocalPlayer.CharacterAdded:Connect(watchCharacter)

-- ============================================================
--  ГЛАВНЫЙ ЦИКЛ: АВТО-ДОДЖ (проверка каждые ~0.05 с)
-- ============================================================

-- Используем Heartbeat — самое частое событие, не требует sleep-цикла
RunService.Heartbeat:Connect(function()
    -- Выключено — ничего не делаем
    if not _G.PVP then return end
    -- Мы уже уклоняемся или атакуем — пропускаем
    if isDodging or isAttacking then return end

    local myRoot = getRootPart(LocalPlayer)
    if not myRoot then return end

    for _, player in Players:GetPlayers() do
        if player == LocalPlayer then continue end
        -- Пропускаем текущую цель атаки (анти-глитч)
        if player == attackTarget then continue end

        local enemyRoot = getRootPart(player)
        if not enemyRoot then continue end

        -- Проверяем дистанцию
        local dist = (enemyRoot.Position - myRoot.Position).Magnitude
        if dist > CONFIG.DODGE_RADIUS then continue end

        -- Проверяем наличие опасного инструмента
        if not hasDangerousTool(player) then continue end

        -- Угроза обнаружена — уклоняемся
        task.spawn(doDodge, enemyRoot)
        break -- Обрабатываем одну угрозу за раз
    end
end)

-- ============================================================
--  ИНИЦИАЛИЗАЦИЯ _G.PVP
-- ============================================================
-- По умолчанию скрипт ВЫКЛЮЧЕН. Включить: _G.PVP = true
if _G.PVP == nil then
    _G.PVP = false
end

print("[PVP Script] Загружен. _G.PVP =", _G.PVP)
print("[PVP Script] Для включения выполните: _G.PVP = true")
