-- ============================================================
-- PetTrackerGUI — LocalScript
-- Отслеживание и сбор заспавненных петов в workspace.ItemSpawners
-- ============================================================

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player         = Players.LocalPlayer
local character      = player.Character or player.CharacterAdded:Wait()
local humanoidRoot   = character:WaitForChild("HumanoidRootPart")

-- Ждём появления персонажа при респавне
player.CharacterAdded:Connect(function(char)
    character     = char
    humanoidRoot  = char:WaitForChild("HumanoidRootPart")
end)

-- ============================================================
-- НАСТРОЙКИ (редактируй под нужды)
-- ============================================================
local CONFIG = {
    UPDATE_INTERVAL   = 1,          -- секунд между обновлениями списка
    STEAL_WAIT        = 2,          -- секунд ожидания в SafeZone перед возвратом
    SAFE_ZONE_NAME    = "SafeZone", -- имя объекта в workspace
    SPAWNERS_FOLDER   = "ItemSpawners",
    PET_MODEL_NAMES   = {"SpawnedItem", "VisualItem"}, -- возможные имена моделей
    -- Порядок мутаций (для фильтра)
    MUTATIONS = {"Normal","Golden","Diamond","Ruby","Rainbow","Blood","Neon","Divine"},
    -- Цвет рамки по мутации
    MUTATION_COLORS = {
        Normal  = Color3.fromRGB(200, 200, 200),
        Golden  = Color3.fromRGB(255, 215,   0),
        Diamond = Color3.fromRGB( 80, 220, 255),
        Ruby    = Color3.fromRGB(220,  30,  60),
        Rainbow = Color3.fromRGB(180,   0, 255),
        Blood   = Color3.fromRGB(140,   0,   0),
        Neon    = Color3.fromRGB(  0, 255, 160),
        Divine  = Color3.fromRGB(255, 255, 160),
    },
}

-- ============================================================
-- УТИЛИТЫ
-- ============================================================

--- Безопасное чтение TextLabel
local function getLabel(model, labelName)
    local ok, val = pcall(function()
        return model.InfoGUI.TextLabels[labelName].Text
    end)
    return ok and val or ""
end

--- Безопасное чтение image ID
local function getImageId(model)
    local ok, val = pcall(function()
        return model["Open This"]["Paste the link to the image in here"].Image
    end)
    return ok and val or "rbxassetid://0"
end

--- Безопасный доступ к ProximityPrompt внутри Head
local function getPrompt(model)
    local ok, prompt = pcall(function()
        return model.Head:FindFirstChildOfClass("ProximityPrompt")
    end)
    return ok and prompt or nil
end

--- Создать рамку для анимации (TweenInfo)
local function quickTween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end

-- ============================================================
-- СБОР ДАННЫХ О ПЕТАХ
-- ============================================================

--- Вернуть таблицу всех петов из workspace.ItemSpawners
--- Каждый элемент: { model, name, rarity, mutation, earnings, timer, imageId, prompt }
local function collectPets()
    local spawnersFolder = workspace:FindFirstChild(CONFIG.SPAWNERS_FOLDER)
    if not spawnersFolder then return {} end

    local pets = {}

    for _, rarityPart in ipairs(spawnersFolder:GetChildren()) do
        -- Внутри парта ищем все модели петов
        for _, child in ipairs(rarityPart:GetChildren()) do
            local isPet = false
            for _, n in ipairs(CONFIG.PET_MODEL_NAMES) do
                if child.Name == n then isPet = true; break end
            end
            -- Также принимаем любую модель — на случай нестандартных имён
            if not isPet and child:IsA("Model") then isPet = true end

            if isPet then
                local pet = {
                    model    = child,
                    name     = getLabel(child, "Name"),
                    rarity   = getLabel(child, "Rarity"),
                    mutation = getLabel(child, "Mutation"),
                    earnings = getLabel(child, "Earnings"),
                    timer    = getLabel(child, "Timer"),
                    imageId  = getImageId(child),
                    prompt   = getPrompt(child),
                }
                if pet.name ~= "" then
                    table.insert(pets, pet)
                end
            end
        end
    end

    return pets
end

--- Получить уникальный список редкостей из папки
local function getUniqueRarities()
    local spawnersFolder = workspace:FindFirstChild(CONFIG.SPAWNERS_FOLDER)
    if not spawnersFolder then return {} end
    local seen, list = {}, {}
    for _, child in ipairs(spawnersFolder:GetChildren()) do
        if child:IsA("BasePart") and not seen[child.Name] then
            seen[child.Name] = true
            table.insert(list, child.Name)
        end
    end
    table.sort(list)
    return list
end

-- ============================================================
-- STEAL-ЛОГИКА
-- ============================================================

local isStealBusy = false  -- блокировка повторных нажатий

local function stealPet(petData)
    if isStealBusy then return end
    isStealBusy = true

    -- Сохраняем позицию
    local savedCFrame = humanoidRoot.CFrame

    local success = pcall(function()
        -- 1. Телепорт к голове пета
        local headPart = petData.model:FindFirstChild("Head")
        assert(headPart, "Head не найден")
        humanoidRoot.CFrame = headPart.CFrame + Vector3.new(0, 2, 0)
        task.wait(0.1)

        -- 2. Активируем ProximityPrompt
        local prompt = petData.prompt
        if prompt then
            -- Пробуем оба метода; второй используется в ряде игр
            local ok = pcall(function()
                fireclickdetector(prompt) -- fallback
            end)
            if not ok then
                -- Стандартный способ через InputHoldBegin
                prompt:InputHoldBegin()
                task.wait(prompt.HoldDuration + 0.05)
                prompt:InputHoldEnd()
            end
        end

        -- 3. Телепорт в SafeZone
        local safeZone = workspace:FindFirstChild(CONFIG.SAFE_ZONE_NAME)
        if safeZone then
            if safeZone:IsA("BasePart") then
                humanoidRoot.CFrame = safeZone.CFrame + Vector3.new(0, 3, 0)
            elseif safeZone:IsA("Model") and safeZone.PrimaryPart then
                humanoidRoot.CFrame = safeZone.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
            end
        end

        -- 4. Ждём
        task.wait(CONFIG.STEAL_WAIT)
    end)

    if not success then
        warn("[PetTracker] Ошибка во время steal — возвращаем игрока на место")
    end

    -- 5. Возврат на сохранённую позицию
    pcall(function()
        humanoidRoot.CFrame = savedCFrame
    end)

    isStealBusy = false
end

-- ============================================================
-- ПОСТРОЕНИЕ GUI
-- ============================================================

-- Удаляем старый GUI при перезагрузке скрипта (Studio)
local oldGui = player.PlayerGui:FindFirstChild("PetTrackerGUI")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "PetTrackerGUI"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.Parent          = player.PlayerGui

-- ── Основное окно ─────────────────────────────────────────
local mainFrame = Instance.new("Frame")
mainFrame.Name            = "MainFrame"
mainFrame.Size            = UDim2.new(0, 480, 0, 560)
mainFrame.Position        = UDim2.new(0.5, -240, 0.5, -280)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = false
mainFrame.Parent          = screenGui

-- Скруглённые углы
local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 10)

-- Тень
local shadow = Instance.new("ImageLabel", mainFrame)
shadow.Name              = "Shadow"
shadow.Size              = UDim2.new(1, 30, 1, 30)
shadow.Position          = UDim2.new(0, -15, 0, -15)
shadow.BackgroundTransparency = 1
shadow.Image             = "rbxassetid://5028857084"
shadow.ImageColor3       = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.6
shadow.ScaleType         = Enum.ScaleType.Slice
shadow.SliceCenter       = Rect.new(24, 24, 276, 276)
shadow.ZIndex            = 0

-- ── Заголовок ─────────────────────────────────────────────
local titleBar = Instance.new("Frame", mainFrame)
titleBar.Name              = "TitleBar"
titleBar.Size              = UDim2.new(1, 0, 0, 42)
titleBar.BackgroundColor3  = Color3.fromRGB(22, 22, 32)
titleBar.BorderSizePixel   = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

-- Нижнее скругление заголовка убираем через оверлей
local titleFix = Instance.new("Frame", titleBar)
titleFix.Size              = UDim2.new(1, 0, 0.5, 0)
titleFix.Position          = UDim2.new(0, 0, 0.5, 0)
titleFix.BackgroundColor3  = Color3.fromRGB(22, 22, 32)
titleFix.BorderSizePixel   = 0

local titleLabel = Instance.new("TextLabel", titleBar)
titleLabel.Size             = UDim2.new(1, -90, 1, 0)
titleLabel.Position         = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text             = "🐾  Pet Tracker"
titleLabel.TextColor3       = Color3.fromRGB(220, 220, 255)
titleLabel.TextSize         = 16
titleLabel.Font             = Enum.Font.GothamBold
titleLabel.TextXAlignment   = Enum.TextXAlignment.Left

-- Кнопка скрыть/показать
local toggleBtn = Instance.new("TextButton", titleBar)
toggleBtn.Name              = "ToggleBtn"
toggleBtn.Size              = UDim2.new(0, 28, 0, 28)
toggleBtn.Position          = UDim2.new(1, -36, 0.5, -14)
toggleBtn.BackgroundColor3  = Color3.fromRGB(60, 60, 80)
toggleBtn.Text              = "−"
toggleBtn.TextColor3        = Color3.fromRGB(220, 220, 255)
toggleBtn.TextSize          = 18
toggleBtn.Font              = Enum.Font.GothamBold
toggleBtn.BorderSizePixel   = 0
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)

-- Счётчик петов
local countLabel = Instance.new("TextLabel", titleBar)
countLabel.Name             = "CountLabel"
countLabel.Size             = UDim2.new(0, 100, 1, 0)
countLabel.Position         = UDim2.new(0, 160, 0, 0)
countLabel.BackgroundTransparency = 1
countLabel.Text             = "0 pets"
countLabel.TextColor3       = Color3.fromRGB(120, 120, 160)
countLabel.TextSize         = 13
countLabel.Font             = Enum.Font.Gotham
countLabel.TextXAlignment   = Enum.TextXAlignment.Left

-- ── Тело окна (скрывается при сворачивании) ──────────────
local bodyFrame = Instance.new("Frame", mainFrame)
bodyFrame.Name              = "Body"
bodyFrame.Size              = UDim2.new(1, 0, 1, -42)
bodyFrame.Position          = UDim2.new(0, 0, 0, 42)
bodyFrame.BackgroundTransparency = 1
bodyFrame.ClipsDescendants  = false

-- ── Панель фильтров ───────────────────────────────────────
local filterFrame = Instance.new("Frame", bodyFrame)
filterFrame.Name             = "FilterFrame"
filterFrame.Size             = UDim2.new(1, -16, 0, 90)
filterFrame.Position         = UDim2.new(0, 8, 0, 8)
filterFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
filterFrame.BorderSizePixel  = 0
Instance.new("UICorner", filterFrame).CornerRadius = UDim.new(0, 8)

local filterTitle = Instance.new("TextLabel", filterFrame)
filterTitle.Size             = UDim2.new(1, -10, 0, 22)
filterTitle.Position         = UDim2.new(0, 8, 0, 4)
filterTitle.BackgroundTransparency = 1
filterTitle.Text             = "ФИЛЬТРЫ"
filterTitle.TextColor3       = Color3.fromRGB(100, 100, 140)
filterTitle.TextSize         = 11
filterTitle.Font             = Enum.Font.GothamBold
filterTitle.TextXAlignment   = Enum.TextXAlignment.Left

-- ScrollingFrame для чекбоксов редкостей
local rarityScroll = Instance.new("ScrollingFrame", filterFrame)
rarityScroll.Name            = "RarityScroll"
rarityScroll.Size            = UDim2.new(1, -10, 0, 32)
rarityScroll.Position        = UDim2.new(0, 5, 0, 26)
rarityScroll.BackgroundTransparency = 1
rarityScroll.ScrollBarThickness = 0
rarityScroll.ScrollingDirection = Enum.ScrollingDirection.X
rarityScroll.CanvasSize      = UDim2.new(0, 0, 1, 0)
rarityScroll.AutomaticCanvasSize = Enum.AutomaticSize.X

local rarityLayout = Instance.new("UIListLayout", rarityScroll)
rarityLayout.FillDirection   = Enum.FillDirection.Horizontal
rarityLayout.Padding         = UDim.new(0, 5)
rarityLayout.SortOrder       = Enum.SortOrder.Name

-- ScrollingFrame для чекбоксов мутаций
local mutationScroll = Instance.new("ScrollingFrame", filterFrame)
mutationScroll.Name          = "MutationScroll"
mutationScroll.Size          = UDim2.new(1, -10, 0, 32)
mutationScroll.Position      = UDim2.new(0, 5, 0, 60)
mutationScroll.BackgroundTransparency = 1
mutationScroll.ScrollBarThickness = 0
mutationScroll.ScrollingDirection = Enum.ScrollingDirection.X
mutationScroll.CanvasSize    = UDim2.new(0, 0, 1, 0)
mutationScroll.AutomaticCanvasSize = Enum.AutomaticSize.X

local mutationLayout = Instance.new("UIListLayout", mutationScroll)
mutationLayout.FillDirection = Enum.FillDirection.Horizontal
mutationLayout.Padding       = UDim.new(0, 5)
mutationLayout.SortOrder     = Enum.SortOrder.Name

-- ── ScrollingFrame со списком петов ──────────────────────
local petScroll = Instance.new("ScrollingFrame", bodyFrame)
petScroll.Name               = "PetScroll"
petScroll.Size               = UDim2.new(1, -16, 1, -114)
petScroll.Position           = UDim2.new(0, 8, 0, 106)
petScroll.BackgroundColor3   = Color3.fromRGB(18, 18, 26)
petScroll.BorderSizePixel    = 0
petScroll.ScrollBarThickness = 4
petScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 120)
petScroll.CanvasSize         = UDim2.new(0, 0, 0, 0)
petScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", petScroll).CornerRadius = UDim.new(0, 8)

local listLayout = Instance.new("UIListLayout", petScroll)
listLayout.Padding           = UDim.new(0, 4)
listLayout.SortOrder         = Enum.SortOrder.LayoutOrder

local listPadding = Instance.new("UIPadding", petScroll)
listPadding.PaddingTop       = UDim.new(0, 6)
listPadding.PaddingLeft      = UDim.new(0, 6)
listPadding.PaddingRight     = UDim.new(0, 10)
listPadding.PaddingBottom    = UDim.new(0, 6)

-- Плейсхолдер "нет петов"
local emptyLabel = Instance.new("TextLabel", petScroll)
emptyLabel.Name              = "EmptyLabel"
emptyLabel.Size              = UDim2.new(1, 0, 0, 40)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Text              = "Петов не найдено"
emptyLabel.TextColor3        = Color3.fromRGB(80, 80, 100)
emptyLabel.TextSize          = 14
emptyLabel.Font              = Enum.Font.Gotham
emptyLabel.Visible           = true

-- ============================================================
-- ФИЛЬТРЫ: состояние и создание чекбоксов
-- ============================================================

local activeRarities  = {}  -- { [rarityName] = bool }
local activeMutations = {}  -- { [mutationName] = bool }

-- Инициализируем мутации (все вкл. по умолчанию)
for _, m in ipairs(CONFIG.MUTATIONS) do
    activeMutations[m] = true
end

--- Создать чекбокс-кнопку фильтра
local function makeFilterButton(parent, labelText, color, stateTable, key)
    local btn = Instance.new("TextButton", parent)
    btn.Size              = UDim2.new(0, 0, 1, 0)
    btn.AutomaticSize     = Enum.AutomaticSize.X
    btn.BackgroundColor3  = stateTable[key]
        and (color or Color3.fromRGB(80, 80, 140))
        or  Color3.fromRGB(35, 35, 50)
    btn.Text              = "  " .. labelText .. "  "
    btn.TextColor3        = Color3.fromRGB(220, 220, 255)
    btn.TextSize          = 12
    btn.Font              = Enum.Font.GothamSemibold
    btn.BorderSizePixel   = 0
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        stateTable[key] = not stateTable[key]
        quickTween(btn, {
            BackgroundColor3 = stateTable[key]
                and (color or Color3.fromRGB(80, 80, 140))
                or  Color3.fromRGB(35, 35, 50)
        })
    end)

    return btn
end

-- Кнопки мутаций — создаём сразу (они фиксированы)
for _, m in ipairs(CONFIG.MUTATIONS) do
    makeFilterButton(
        mutationScroll, m,
        CONFIG.MUTATION_COLORS[m] and
            Color3.fromRGB(
                math.clamp(CONFIG.MUTATION_COLORS[m].R * 180, 0, 255),
                math.clamp(CONFIG.MUTATION_COLORS[m].G * 180, 0, 255),
                math.clamp(CONFIG.MUTATION_COLORS[m].B * 180, 0, 255)
            ) or nil,
        activeMutations, m
    )
end

-- Кнопки редкостей — обновляются динамически
local rarityButtons = {}

local function rebuildRarityFilters()
    -- Удаляем старые кнопки
    for _, b in ipairs(rarityButtons) do b:Destroy() end
    rarityButtons = {}

    local rarities = getUniqueRarities()

    -- Добавляем новые редкости в стейт (вкл. по умолчанию)
    for _, r in ipairs(rarities) do
        if activeRarities[r] == nil then
            activeRarities[r] = true
        end
    end

    for _, r in ipairs(rarities) do
        local btn = makeFilterButton(rarityScroll, r, nil, activeRarities, r)
        table.insert(rarityButtons, btn)
    end
end

-- ============================================================
-- КАРТОЧКА ПЕТА
-- ============================================================

--- Создать UI-карточку для одного пета
local function makePetCard(petData, index)
    local mutColor = CONFIG.MUTATION_COLORS[petData.mutation] or Color3.fromRGB(200,200,200)

    local card = Instance.new("Frame")
    card.Name              = "Card_" .. index
    card.Size              = UDim2.new(1, 0, 0, 64)
    card.BackgroundColor3  = Color3.fromRGB(26, 26, 38)
    card.BorderSizePixel   = 0
    card.LayoutOrder       = index
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    -- Цветная полоска мутации (левый край)
    local stripe = Instance.new("Frame", card)
    stripe.Size            = UDim2.new(0, 4, 1, -12)
    stripe.Position        = UDim2.new(0, 0, 0, 6)
    stripe.BackgroundColor3 = mutColor
    stripe.BorderSizePixel = 0
    Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 3)

    -- Картинка пета
    local img = Instance.new("ImageLabel", card)
    img.Size               = UDim2.new(0, 52, 0, 52)
    img.Position           = UDim2.new(0, 10, 0.5, -26)
    img.BackgroundColor3   = Color3.fromRGB(15, 15, 22)
    img.Image              = petData.imageId
    img.ScaleType          = Enum.ScaleType.Fit
    Instance.new("UICorner", img).CornerRadius = UDim.new(0, 6)

    -- Имя пета
    local nameLabel = Instance.new("TextLabel", card)
    nameLabel.Size          = UDim2.new(0, 200, 0, 18)
    nameLabel.Position      = UDim2.new(0, 70, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text          = petData.name
    nameLabel.TextColor3    = Color3.fromRGB(230, 230, 255)
    nameLabel.TextSize      = 13
    nameLabel.Font          = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Мутация
    local mutLabel = Instance.new("TextLabel", card)
    mutLabel.Size           = UDim2.new(0, 130, 0, 16)
    mutLabel.Position       = UDim2.new(0, 70, 0, 28)
    mutLabel.BackgroundTransparency = 1
    mutLabel.Text           = petData.mutation .. " · " .. petData.rarity
    mutLabel.TextColor3     = mutColor
    mutLabel.TextSize       = 11
    mutLabel.Font           = Enum.Font.GothamSemibold
    mutLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Доход
    local earningsLabel = Instance.new("TextLabel", card)
    earningsLabel.Size      = UDim2.new(0, 130, 0, 14)
    earningsLabel.Position  = UDim2.new(0, 70, 0, 44)
    earningsLabel.BackgroundTransparency = 1
    earningsLabel.Text      = "💰 " .. petData.earnings .. "/s"
    earningsLabel.TextColor3 = Color3.fromRGB(140, 220, 140)
    earningsLabel.TextSize  = 11
    earningsLabel.Font      = Enum.Font.Gotham
    earningsLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Таймер
    local timerLabel = Instance.new("TextLabel", card)
    timerLabel.Size         = UDim2.new(0, 80, 0, 14)
    timerLabel.Position     = UDim2.new(0, 220, 0, 44)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Text         = "⏱ " .. petData.timer
    timerLabel.TextColor3   = Color3.fromRGB(180, 140, 100)
    timerLabel.TextSize     = 11
    timerLabel.Font         = Enum.Font.Gotham
    timerLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Кнопка Steal
    local stealBtn = Instance.new("TextButton", card)
    stealBtn.Size           = UDim2.new(0, 60, 0, 28)
    stealBtn.Position       = UDim2.new(1, -70, 0.5, -14)
    stealBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 60)
    stealBtn.Text           = "Steal"
    stealBtn.TextColor3     = Color3.fromRGB(255, 255, 255)
    stealBtn.TextSize       = 13
    stealBtn.Font           = Enum.Font.GothamBold
    stealBtn.BorderSizePixel = 0
    Instance.new("UICorner", stealBtn).CornerRadius = UDim.new(0, 6)

    stealBtn.MouseEnter:Connect(function()
        quickTween(stealBtn, { BackgroundColor3 = Color3.fromRGB(240, 60, 80) })
    end)
    stealBtn.MouseLeave:Connect(function()
        quickTween(stealBtn, { BackgroundColor3 = Color3.fromRGB(200, 40, 60) })
    end)

    stealBtn.MouseButton1Click:Connect(function()
        -- Проверяем, что пет ещё существует
        if not petData.model or not petData.model.Parent then
            warn("[PetTracker] Пет уже исчез")
            return
        end
        stealBtn.Text = "..."
        stealBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)

        task.spawn(function()
            stealPet(petData)
            -- Восстанавливаем кнопку (если карточка ещё жива)
            if stealBtn and stealBtn.Parent then
                stealBtn.Text = "Steal"
                stealBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 60)
            end
        end)
    end)

    return card
end

-- ============================================================
-- ОБНОВЛЕНИЕ СПИСКА
-- ============================================================

local currentCards = {} -- кэш существующих карточек

local function refreshList()
    local pets = collectPets()

    -- Применяем фильтры
    local filtered = {}
    for _, pet in ipairs(pets) do
        local rarityOk   = activeRarities[pet.rarity]  == true
        local mutationOk = activeMutations[pet.mutation] == true
        if rarityOk and mutationOk then
            table.insert(filtered, pet)
        end
    end

    -- Обновляем счётчик
    countLabel.Text = #filtered .. " / " .. #pets .. " pets"

    -- Удаляем старые карточки
    for _, card in ipairs(currentCards) do
        if card and card.Parent then card:Destroy() end
    end
    currentCards = {}

    emptyLabel.Visible = (#filtered == 0)

    -- Создаём новые
    for i, pet in ipairs(filtered) do
        local card = makePetCard(pet, i)
        card.Parent = petScroll
        table.insert(currentCards, card)
    end
end

-- ============================================================
-- ПЕРЕТАСКИВАНИЕ ОКНА
-- ============================================================

do
    local dragging, dragStart, startPos
    local function updateDrag(input)
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateDrag(input)
        end
    end)
end

-- ============================================================
-- СВЕРНУТЬ / РАЗВЕРНУТЬ
-- ============================================================

local isCollapsed = false

toggleBtn.MouseButton1Click:Connect(function()
    isCollapsed = not isCollapsed
    if isCollapsed then
        quickTween(mainFrame, { Size = UDim2.new(0, 480, 0, 42) }, 0.2)
        bodyFrame.Visible = false
        toggleBtn.Text    = "+"
    else
        bodyFrame.Visible = true
        quickTween(mainFrame, { Size = UDim2.new(0, 480, 0, 560) }, 0.2)
        toggleBtn.Text    = "−"
    end
end)

-- ============================================================
-- ГЛАВНЫЙ ЦИКЛ ОБНОВЛЕНИЯ
-- ============================================================

-- Первоначальная инициализация редкостей
rebuildRarityFilters()
refreshList()

local updateTimer = 0

RunService.RenderStepped:Connect(function(dt)
    updateTimer = updateTimer + dt
    if updateTimer >= CONFIG.UPDATE_INTERVAL then
        updateTimer = 0
        -- Обновляем кнопки редкостей (могут появиться новые)
        rebuildRarityFilters()
        -- Обновляем список петов
        refreshList()
    end
end)

print("[PetTracker] GUI загружен ✓")
