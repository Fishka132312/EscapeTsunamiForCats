--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║              PET MONITOR — LocalScript v2.0                     ║
    ║  Мониторинг, фильтрация и кража петов в реальном времени        ║
    ╚══════════════════════════════════════════════════════════════════╝

    СТРУКТУРА:
      1. Константы и зависимости
      2. Состояние фильтров
      3. Кэш петов
      4. Создание GUI
      5. Вспомогательные функции UI
      6. Логика рендера карточек
      7. Функция Steal
      8. Обновление таймеров (RunService)
      9. Подписка на ChildAdded / ChildRemoved
     10. Инициализация

--]]

-- ══════════════════════════════════════════════════════════════
-- 1. ЗАВИСИМОСТИ И КОНСТАНТЫ
-- ══════════════════════════════════════════════════════════════

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local VirtualUser        = game:GetService("VirtualUser")   -- для FireProximityPrompt

local LocalPlayer        = Players.LocalPlayer
local PlayerGui          = LocalPlayer:WaitForChild("PlayerGui")
local Character          = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart   = Character:WaitForChild("HumanoidRootPart")

local workspace          = game:GetService("Workspace")
local ItemSpawners       = workspace:WaitForChild("ItemSpawners")

-- Папки-редкости, которые нас интересуют
local RARITY_FOLDERS = {
    "Common", "Epic", "Mythic", "Legendary", "OG", "SpecialItemSpawn"
}

-- Порядок редкостей: индекс = приоритет (меньше = лучше в сортировке)
local RARITY_ORDER = {
    OG              = 1,
    SpecialItemSpawn= 2,
    Legendary       = 3,
    Mythic          = 4,
    Epic            = 5,
    Common          = 6,
}

-- Отображаемые имена редкостей (для CheckBox-ов)
local RARITY_DISPLAY = {
    Common          = "Common",
    Epic            = "Epic",
    Mythic          = "Mythic",
    Legendary       = "Legendary",
    OG              = "OG",
    SpecialItemSpawn= "Special",
}

-- Цвета редкостей
local RARITY_COLORS = {
    Common          = Color3.fromRGB(180, 180, 180),
    Epic            = Color3.fromRGB(160,  80, 240),
    Mythic          = Color3.fromRGB(255, 150,  50),
    Legendary       = Color3.fromRGB(255, 215,   0),
    OG              = Color3.fromRGB(255,  60,  60),
    SpecialItemSpawn= Color3.fromRGB( 80, 220, 255),
}

-- Порядок мутаций (индекс = приоритет, меньше = лучше)
local MUTATION_ORDER = {
    Divine  = 1,
    Neon    = 2,
    Blood   = 3,
    Rainbow = 4,
    Ruby    = 5,
    Diamond = 6,
    Golden  = 7,
    Normal  = 8,
}

-- Цвета мутаций
local MUTATION_COLORS = {
    Normal  = Color3.fromRGB(200, 200, 200),
    Golden  = Color3.fromRGB(255, 215,   0),
    Diamond = Color3.fromRGB(100, 220, 255),
    Ruby    = Color3.fromRGB(220,  50,  50),
    Rainbow = Color3.fromRGB(255, 120, 200),
    Blood   = Color3.fromRGB(160,   0,   0),
    Neon    = Color3.fromRGB( 80, 255, 120),
    Divine  = Color3.fromRGB(200, 150, 255),
}

-- Список мутаций в порядке от худшей к лучшей (для UI)
local MUTATION_LIST = {
    "Normal", "Golden", "Diamond", "Ruby", "Rainbow", "Blood", "Neon", "Divine"
}

-- Задержки для функции Steal
local STEAL_TELEPORT_WAIT  = 0.35  -- сек ждать после телепорта к пету
local STEAL_PROMPT_WAIT    = 0.15  -- сек ждать перед активацией промпта
local STEAL_RETURN_WAIT    = 0.5   -- сек ждать перед телепортом в SafeZone

-- ══════════════════════════════════════════════════════════════
-- 2. СОСТОЯНИЕ ФИЛЬТРОВ
-- ══════════════════════════════════════════════════════════════

-- activeFilters хранит текущее состояние всех фильтров
local activeFilters = {
    rarities  = {
        Common          = true,
        Epic            = true,
        Mythic          = true,
        Legendary       = true,
        OG              = true,
        SpecialItemSpawn= true,
    },
    mutations = {
        Normal  = true,
        Golden  = true,
        Diamond = true,
        Ruby    = true,
        Rainbow = true,
        Blood   = true,
        Neon    = true,
        Divine  = true,
    },
}

-- ══════════════════════════════════════════════════════════════
-- 3. КЭШ ПЕТОВ
-- ══════════════════════════════════════════════════════════════

-- petCache[pet] = { rarityKey, name, mutation, timerText, earnings, imageId, headPart, prompt }
local petCache = {}

-- Функция: извлечь данные пета из его InfoGUI и Head
-- Функция: извлечь данные пета из его InfoGUI и Head (ОБНОВЛЕННАЯ СТРУКТУРА)
local function extractPetData(pet, rarityKey)
    local data = {
        rarityKey = rarityKey,
        name      = "Unknown",
        mutation  = "Normal",
        timerText = "—",
        earnings  = "—",
        imageId   = nil,
        headPart  = nil,
        prompt    = nil,
    }

    -- ══════════════════════════════════════════════════════════════
    -- 4. ОБНОВЛЕННЫЙ ПУТЬ ЧЕРЕЗ TextLabels
    -- ══════════════════════════════════════════════════════════════
    local infoGUI = pet:FindFirstChild("InfoGUI")
    if infoGUI then
        -- Переходим в папку TextLabels, где лежат все текстовые свойства
        local textLabels = infoGUI:FindFirstChild("TextLabels")
        if textLabels then
            local nameLabel     = textLabels:FindFirstChild("Name")
            local rarityLabel   = textLabels:FindFirstChild("Rarity")
            local mutLabel      = textLabels:FindFirstChild("Mutation")
            local timerLabel    = textLabels:FindFirstChild("Timer")
            local earningsLabel = textLabels:FindFirstChild("Earnings")

            -- Извлекаем текст и очищаем от HTML/RichText тегов (если они есть)
            if nameLabel     then data.name      = nameLabel.Text:gsub("<[^<>]+>", "") end
            if mutLabel      then data.mutation  = mutLabel.Text:gsub("<[^<>]+>", "") end
            if timerLabel    then data.timerText = timerLabel.Text end
            if earningsLabel then data.earnings  = earningsLabel.Text:gsub("<[^<>]+>", "") end
        end
    end

    -- Head + ProximityPrompt
    local head = pet:FindFirstChild("Head")
    if head then
        data.headPart = head
        local prompt = head:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            data.prompt = prompt
        end
    end

    -- Картинка пета
    local openThis = pet:FindFirstChild("Open This")
    if openThis then
        local imgHolder = openThis:FindFirstChild("Paste the link to the image in here")
        if imgHolder and imgHolder:IsA("ImageLabel") then
            data.imageId = imgHolder.Image
        end
    end

    return data
end

-- ══════════════════════════════════════════════════════════════
-- 4. СОЗДАНИЕ GUI
-- ══════════════════════════════════════════════════════════════

-- Удаляем предыдущий инстанс если есть (для hot-reload)
if PlayerGui:FindFirstChild("PetMonitorGui") then
    PlayerGui:FindFirstChild("PetMonitorGui"):Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "PetMonitorGui"
screenGui.ResetOnSpawn    = false
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset  = true
screenGui.Parent          = PlayerGui

-- ══ Главный фрейм ══════════════════════════════════════════
local mainFrame = Instance.new("Frame")
mainFrame.Name            = "MainFrame"
mainFrame.Size            = UDim2.new(0, 520, 0, 620)
mainFrame.Position        = UDim2.new(0.5, -260, 0.5, -310)
mainFrame.BackgroundColor3= Color3.fromRGB(12, 14, 22)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants= true
mainFrame.Parent          = screenGui

-- Скруглённые углы
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent       = mainFrame

-- Градиент фона
local mainGradient = Instance.new("UIGradient")
mainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB( 15, 18, 32)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB( 10, 13, 24)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB( 18, 22, 40)),
})
mainGradient.Rotation = 135
mainGradient.Parent   = mainFrame

-- Внешний Stroke (граница)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color     = Color3.fromRGB(80, 100, 200)
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.4
mainStroke.Parent    = mainFrame

-- Декоративная полоса сверху (акцентный цвет)
local topAccent = Instance.new("Frame")
topAccent.Name              = "TopAccent"
topAccent.Size              = UDim2.new(1, 0, 0, 3)
topAccent.Position          = UDim2.new(0, 0, 0, 0)
topAccent.BackgroundColor3  = Color3.fromRGB(100, 140, 255)
topAccent.BorderSizePixel   = 0
topAccent.ZIndex            = 5
topAccent.Parent            = mainFrame

local topAccentGrad = Instance.new("UIGradient")
topAccentGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB( 80, 120, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 100, 255)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB( 80, 200, 255)),
})
topAccentGrad.Parent = topAccent

-- ══ Шапка (Header) ═════════════════════════════════════════
local header = Instance.new("Frame")
header.Name             = "Header"
header.Size             = UDim2.new(1, 0, 0, 48)
header.Position         = UDim2.new(0, 0, 0, 3)
header.BackgroundColor3 = Color3.fromRGB(18, 22, 40)
header.BorderSizePixel  = 0
header.ZIndex           = 4
header.Parent           = mainFrame

local headerGrad = Instance.new("UIGradient")
headerGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 28, 55)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 18, 36)),
})
headerGrad.Rotation = 90
headerGrad.Parent   = header

-- Иконка / заголовок
local titleLabel = Instance.new("TextLabel")
titleLabel.Name             = "Title"
titleLabel.Size             = UDim2.new(1, -100, 1, 0)
titleLabel.Position         = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font             = Enum.Font.GothamBold
titleLabel.Text             = "🐾  PET MONITOR"
titleLabel.TextColor3       = Color3.fromRGB(220, 230, 255)
titleLabel.TextSize         = 17
titleLabel.TextXAlignment   = Enum.TextXAlignment.Left
titleLabel.ZIndex           = 5
titleLabel.Parent           = header

-- Счётчик (кол-во показанных петов)
local countLabel = Instance.new("TextLabel")
countLabel.Name             = "Count"
countLabel.Size             = UDim2.new(0, 80, 1, 0)
countLabel.Position         = UDim2.new(0, 180, 0, 0)
countLabel.BackgroundTransparency = 1
countLabel.Font             = Enum.Font.Gotham
countLabel.Text             = "0 pets"
countLabel.TextColor3       = Color3.fromRGB(120, 140, 200)
countLabel.TextSize         = 13
countLabel.TextXAlignment   = Enum.TextXAlignment.Left
countLabel.ZIndex           = 5
countLabel.Parent           = header

-- Кнопка сворачивания
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name            = "MinimizeBtn"
minimizeBtn.Size            = UDim2.new(0, 32, 0, 32)
minimizeBtn.Position        = UDim2.new(1, -76, 0.5, -16)
minimizeBtn.BackgroundColor3= Color3.fromRGB(30, 36, 65)
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Font            = Enum.Font.GothamBold
minimizeBtn.Text            = "—"
minimizeBtn.TextColor3      = Color3.fromRGB(170, 190, 255)
minimizeBtn.TextSize        = 16
minimizeBtn.ZIndex          = 6
minimizeBtn.Parent          = header

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 8)
minCorner.Parent       = minimizeBtn

-- Кнопка закрытия
local closeBtn = Instance.new("TextButton")
closeBtn.Name           = "CloseBtn"
closeBtn.Size           = UDim2.new(0, 32, 0, 32)
closeBtn.Position       = UDim2.new(1, -38, 0.5, -16)
closeBtn.BackgroundColor3= Color3.fromRGB(180, 40, 60)
closeBtn.BorderSizePixel = 0
closeBtn.Font           = Enum.Font.GothamBold
closeBtn.Text           = "X"
closeBtn.TextColor3     = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize       = 15
closeBtn.ZIndex         = 6
closeBtn.Parent         = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent       = closeBtn

-- ══ Панель фильтров ════════════════════════════════════════
local filterPanel = Instance.new("Frame")
filterPanel.Name            = "FilterPanel"
filterPanel.Size            = UDim2.new(1, -20, 0, 108)
filterPanel.Position        = UDim2.new(0, 10, 0, 58)
filterPanel.BackgroundColor3= Color3.fromRGB(18, 22, 42)
filterPanel.BorderSizePixel = 0
filterPanel.ZIndex          = 4
filterPanel.Parent          = mainFrame

local filterCorner = Instance.new("UICorner")
filterCorner.CornerRadius = UDim.new(0, 10)
filterCorner.Parent       = filterPanel

local filterStroke = Instance.new("UIStroke")
filterStroke.Color       = Color3.fromRGB(50, 65, 130)
filterStroke.Thickness   = 1
filterStroke.Transparency= 0.5
filterStroke.Parent      = filterPanel

-- Метка "Rarities"
local rarityFilterLabel = Instance.new("TextLabel")
rarityFilterLabel.Size             = UDim2.new(1, -10, 0, 18)
rarityFilterLabel.Position         = UDim2.new(0, 10, 0, 6)
rarityFilterLabel.BackgroundTransparency = 1
rarityFilterLabel.Font             = Enum.Font.GothamBold
rarityFilterLabel.Text             = "RARITIES"
rarityFilterLabel.TextColor3       = Color3.fromRGB(100, 130, 220)
rarityFilterLabel.TextSize         = 11
rarityFilterLabel.TextXAlignment   = Enum.TextXAlignment.Left
rarityFilterLabel.ZIndex           = 5
rarityFilterLabel.Parent           = filterPanel

-- Строка CheckBox-ов редкостей
local rarityRow = Instance.new("Frame")
rarityRow.Name            = "RarityRow"
rarityRow.Size            = UDim2.new(1, -10, 0, 26)
rarityRow.Position        = UDim2.new(0, 5, 0, 24)
rarityRow.BackgroundTransparency = 1
rarityRow.ZIndex          = 5
rarityRow.Parent          = filterPanel

local rarityRowLayout = Instance.new("UIListLayout")
rarityRowLayout.FillDirection    = Enum.FillDirection.Horizontal
rarityRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
rarityRowLayout.Padding          = UDim.new(0, 5)
rarityRowLayout.Parent           = rarityRow

-- Метка "Mutations"
local mutFilterLabel = Instance.new("TextLabel")
mutFilterLabel.Size             = UDim2.new(1, -10, 0, 18)
mutFilterLabel.Position         = UDim2.new(0, 10, 0, 56)
mutFilterLabel.BackgroundTransparency = 1
mutFilterLabel.Font             = Enum.Font.GothamBold
mutFilterLabel.Text             = "MUTATIONS"
mutFilterLabel.TextColor3       = Color3.fromRGB(100, 130, 220)
mutFilterLabel.TextSize         = 11
mutFilterLabel.TextXAlignment   = Enum.TextXAlignment.Left
mutFilterLabel.ZIndex           = 5
mutFilterLabel.Parent           = filterPanel

-- Строка CheckBox-ов мутаций
local mutRow = Instance.new("Frame")
mutRow.Name            = "MutRow"
mutRow.Size            = UDim2.new(1, -10, 0, 26)
mutRow.Position        = UDim2.new(0, 5, 0, 74)
mutRow.BackgroundTransparency = 1
mutRow.ZIndex          = 5
mutRow.Parent          = filterPanel

local mutRowLayout = Instance.new("UIListLayout")
mutRowLayout.FillDirection    = Enum.FillDirection.Horizontal
mutRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
mutRowLayout.Padding          = UDim.new(0, 4)
mutRowLayout.Parent           = mutRow

-- ══ Область списка петов ════════════════════════════════════
local listContainer = Instance.new("Frame")
listContainer.Name            = "ListContainer"
listContainer.Size            = UDim2.new(1, -20, 1, -182)
listContainer.Position        = UDim2.new(0, 10, 0, 176)
listContainer.BackgroundColor3= Color3.fromRGB(12, 15, 28)
listContainer.BorderSizePixel = 0
listContainer.ClipsDescendants= true
listContainer.ZIndex          = 3
listContainer.Parent          = mainFrame

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 10)
listCorner.Parent       = listContainer

local listStroke = Instance.new("UIStroke")
listStroke.Color       = Color3.fromRGB(40, 55, 110)
listStroke.Thickness   = 1
listStroke.Transparency= 0.6
listStroke.Parent      = listContainer

-- ScrollingFrame
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name                 = "ScrollFrame"
scrollFrame.Size                 = UDim2.new(1, 0, 1, 0)
scrollFrame.Position             = UDim2.new(0, 0, 0, 0)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel      = 0
scrollFrame.ScrollBarThickness   = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 110, 220)
scrollFrame.CanvasSize           = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize  = Enum.AutomaticSize.Y
scrollFrame.ZIndex               = 4
scrollFrame.Parent               = listContainer

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.SortOrder    = Enum.SortOrder.LayoutOrder
scrollLayout.Padding      = UDim.new(0, 6)
scrollLayout.Parent       = scrollFrame

local scrollPadding = Instance.new("UIPadding")
scrollPadding.PaddingTop    = UDim.new(0, 6)
scrollPadding.PaddingBottom = UDim.new(0, 6)
scrollPadding.PaddingLeft   = UDim.new(0, 6)
scrollPadding.PaddingRight  = UDim.new(0, 10)
scrollPadding.Parent        = scrollFrame

-- ══════════════════════════════════════════════════════════════
-- 5. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ UI
-- ══════════════════════════════════════════════════════════════

-- Создать CheckBox-кнопку фильтра
local checkboxRefs = {}   -- checkboxRefs[key] = {button, indicator}

local function createCheckbox(parent, key, displayText, textColor, defaultOn, onToggle)
    local btn = Instance.new("TextButton")
    btn.Name              = "CB_" .. key
    btn.Size              = UDim2.new(0, 0, 1, 0)   -- авто-ширина через AutomaticSize
    btn.AutomaticSize     = Enum.AutomaticSize.X
    btn.BackgroundColor3  = defaultOn
        and Color3.fromRGB(25, 35, 70)
        or  Color3.fromRGB(18, 22, 45)
    btn.BorderSizePixel   = 0
    btn.Text              = ""
    btn.ZIndex            = 6
    btn.Parent            = parent

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent       = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color     = defaultOn and textColor or Color3.fromRGB(50, 60, 100)
    btnStroke.Thickness = 1
    btnStroke.Parent    = btn

    local btnPad = Instance.new("UIPadding")
    btnPad.PaddingLeft  = UDim.new(0, 7)
    btnPad.PaddingRight = UDim.new(0, 7)
    btnPad.Parent       = btn

    local btnLabel = Instance.new("TextLabel")
    btnLabel.Size             = UDim2.new(1, 0, 1, 0)
    btnLabel.BackgroundTransparency = 1
    btnLabel.Font             = Enum.Font.GothamBold
    btnLabel.Text             = displayText
    btnLabel.TextColor3       = defaultOn
        and textColor
        or  Color3.fromRGB(80, 90, 130)
    btnLabel.TextSize         = 11
    btnLabel.ZIndex           = 7
    btnLabel.AutomaticSize    = Enum.AutomaticSize.X
    btnLabel.Parent           = btn

    -- Состояние
    local isOn = defaultOn

    btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        if isOn then
            btn.BackgroundColor3 = Color3.fromRGB(25, 35, 70)
            btnStroke.Color      = textColor
            btnLabel.TextColor3  = textColor
        else
            btn.BackgroundColor3 = Color3.fromRGB(18, 22, 45)
            btnStroke.Color      = Color3.fromRGB(50, 60, 100)
            btnLabel.TextColor3  = Color3.fromRGB(80, 90, 130)
        end
        onToggle(isOn)
    end)

    -- Hover эффект
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = isOn
                and Color3.fromRGB(35, 50, 100)
                or  Color3.fromRGB(22, 28, 55)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = isOn
                and Color3.fromRGB(25, 35, 70)
                or  Color3.fromRGB(18, 22, 45)
        }):Play()
    end)
end

-- Создаём все CheckBox-ы редкостей
for _, rarKey in ipairs(RARITY_FOLDERS) do
    local displayName = RARITY_DISPLAY[rarKey] or rarKey
    local color       = RARITY_COLORS[rarKey]  or Color3.fromRGB(200, 200, 200)
    createCheckbox(rarityRow, rarKey, displayName, color, true, function(state)
        activeFilters.rarities[rarKey] = state
        -- renderList вызывается ниже после определения функции
        _G.PetMonitorRenderList()
    end)
end

-- Создаём все CheckBox-ы мутаций
for _, mutKey in ipairs(MUTATION_LIST) do
    local color = MUTATION_COLORS[mutKey] or Color3.fromRGB(200, 200, 200)
    createCheckbox(mutRow, mutKey, mutKey, color, true, function(state)
        activeFilters.mutations[mutKey] = state
        _G.PetMonitorRenderList()
    end)
end

-- ══════════════════════════════════════════════════════════════
-- DRAGGABLE (перетаскивание главного окна)
-- ══════════════════════════════════════════════════════════════

do
    local dragging     = false
    local dragInput    = nil
    local dragStart    = nil
    local startPos     = nil

    local function onInputChanged(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end

    header.InputBegan:Connect(function(input)
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

    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(onInputChanged)
end

-- ══════════════════════════════════════════════════════════════
-- MINIMIZE / CLOSE
-- ══════════════════════════════════════════════════════════════

local isMinimized = false

minimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    local targetSize = isMinimized
        and UDim2.new(0, 520, 0, 54)
        or  UDim2.new(0, 520, 0, 620)
    TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
        Size = targetSize
    }):Play()
    minimizeBtn.Text = isMinimized and "—" or "—"
    filterPanel.Visible  = not isMinimized
    listContainer.Visible= not isMinimized
end)

closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(
            mainFrame.Position.X.Scale,
            mainFrame.Position.X.Offset + 260,
            mainFrame.Position.Y.Scale,
            mainFrame.Position.Y.Offset + 310
        )
    }):Play()
    task.delay(0.25, function() screenGui:Destroy() end)
end)

-- ══════════════════════════════════════════════════════════════
-- 6. ЛОГИКА РЕНДЕРА КАРТОЧЕК ПЕТОВ
-- ══════════════════════════════════════════════════════════════

-- Таблица активных Frame-карточек: cardFrames[pet] = frame
local cardFrames = {}

-- Функция: получить числовой приоритет сортировки мутации
local function getMutationOrder(mutation)
    return MUTATION_ORDER[mutation] or 99
end

-- Функция: получить числовой приоритет редкости
local function getRarityOrder(rarityKey)
    return RARITY_ORDER[rarityKey] or 99
end

-- Функция: пет проходит текущие фильтры?
local function petPassesFilter(data)
    if not activeFilters.rarities[data.rarityKey] then return false end

    -- Нормализуем мутацию (убираем пробелы и т.п.)
    local mut = data.mutation or "Normal"
    mut = mut:match("^%s*(.-)%s*$")   -- trim

    -- Если ни одна из записанных мутаций не совпадает — Normal
    local filterKey = "Normal"
    for _, m in ipairs(MUTATION_LIST) do
        if mut:lower() == m:lower() then
            filterKey = m
            break
        end
    end

    if not activeFilters.mutations[filterKey] then return false end
    return true
end

-- Функция: создать карточку пета
local function createPetCard(pet, data)
    local frame = Instance.new("Frame")
    frame.Name              = "PetCard_" .. pet.Name
    frame.Size              = UDim2.new(1, 0, 0, 72)
    frame.BackgroundColor3  = Color3.fromRGB(18, 22, 42)
    frame.BorderSizePixel   = 0
    frame.ZIndex            = 5
    frame.ClipsDescendants  = true
    frame.Parent            = scrollFrame

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 8)
    fCorner.Parent       = frame

    local rarColor = RARITY_COLORS[data.rarityKey] or Color3.fromRGB(200,200,200)
    local fStroke = Instance.new("UIStroke")
    fStroke.Color       = rarColor
    fStroke.Thickness   = 1
    fStroke.Transparency= 0.65
    fStroke.Parent      = frame

    -- Левый цветной акцент (редкость)
    local leftAccent = Instance.new("Frame")
    leftAccent.Size            = UDim2.new(0, 4, 1, -12)
    leftAccent.Position        = UDim2.new(0, 6, 0, 6)
    leftAccent.BackgroundColor3= rarColor
    leftAccent.BorderSizePixel = 0
    leftAccent.ZIndex          = 6
    leftAccent.Parent          = frame

    local laCorner = Instance.new("UICorner")
    laCorner.CornerRadius = UDim.new(1, 0)
    laCorner.Parent       = leftAccent

    -- Картинка пета
    local petImage = Instance.new("ImageLabel")
    petImage.Name               = "PetImage"
    petImage.Size               = UDim2.new(0, 56, 0, 56)
    petImage.Position           = UDim2.new(0, 16, 0.5, -28)
    petImage.BackgroundColor3   = Color3.fromRGB(12, 15, 28)
    petImage.BorderSizePixel    = 0
    petImage.ZIndex             = 6
    petImage.ScaleType          = Enum.ScaleType.Fit
    petImage.Image              = data.imageId or ""
    petImage.ImageTransparency  = data.imageId and 0 or 1
    petImage.Parent             = frame

    local imgCorner = Instance.new("UICorner")
    imgCorner.CornerRadius = UDim.new(0, 8)
    imgCorner.Parent       = petImage

    -- Заглушка если нет картинки
    if not data.imageId then
        local noImg = Instance.new("TextLabel")
        noImg.Size             = UDim2.new(1, 0, 1, 0)
        noImg.BackgroundTransparency = 1
        noImg.Font             = Enum.Font.GothamBold
        noImg.Text             = "🐾"
        noImg.TextSize         = 26
        noImg.TextColor3       = Color3.fromRGB(80, 90, 140)
        noImg.ZIndex           = 7
        noImg.Parent           = petImage
    end

    -- Блок текстовой информации
    local textBlock = Instance.new("Frame")
    textBlock.Name            = "TextBlock"
    textBlock.Size            = UDim2.new(1, -168, 1, 0)
    textBlock.Position        = UDim2.new(0, 80, 0, 0)
    textBlock.BackgroundTransparency = 1
    textBlock.ZIndex          = 6
    textBlock.Parent          = frame

    -- Название пета
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name            = "NameLabel"
    nameLabel.Size            = UDim2.new(1, 0, 0, 20)
    nameLabel.Position        = UDim2.new(0, 0, 0, 8)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font            = Enum.Font.GothamBold
    nameLabel.Text            = data.name
    nameLabel.TextColor3      = Color3.fromRGB(230, 235, 255)
    nameLabel.TextSize        = 14
    nameLabel.TextXAlignment  = Enum.TextXAlignment.Left
    nameLabel.TextTruncate    = Enum.TextTruncate.AtEnd
    nameLabel.ZIndex          = 7
    nameLabel.Parent          = textBlock

    -- Редкость + мутация в одной строке
    local subLabel = Instance.new("TextLabel")
    subLabel.Name            = "SubLabel"
    subLabel.Size            = UDim2.new(1, 0, 0, 16)
    subLabel.Position        = UDim2.new(0, 0, 0, 29)
    subLabel.BackgroundTransparency = 1
    subLabel.Font            = Enum.Font.Gotham
    subLabel.Text            = ""    -- строится ниже
    subLabel.TextSize        = 12
    subLabel.TextXAlignment  = Enum.TextXAlignment.Left
    subLabel.ZIndex          = 7
    subLabel.RichText        = true
    subLabel.Parent          = textBlock

    -- Нормализуем мутацию для цвета
    local mutKey    = "Normal"
    local mutRaw    = (data.mutation or "Normal"):match("^%s*(.-)%s*$")
    for _, m in ipairs(MUTATION_LIST) do
        if mutRaw:lower() == m:lower() then mutKey = m break end
    end
    local mutColor  = MUTATION_COLORS[mutKey] or Color3.fromRGB(200,200,200)
    local rarColorHex = string.format("rgb(%d,%d,%d)", rarColor.R*255, rarColor.G*255, rarColor.B*255)
    local mutColorHex = string.format("rgb(%d,%d,%d)", mutColor.R*255, mutColor.G*255, mutColor.B*255)

    subLabel.Text = string.format(
        '<font color="%s"><b>%s</b></font>  <font color="%s">✦ %s</font>',
        rarColorHex,
        RARITY_DISPLAY[data.rarityKey] or data.rarityKey,
        mutColorHex,
        mutKey
    )

    -- Таймер
    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name           = "TimerLabel"
    timerLabel.Size           = UDim2.new(1, 0, 0, 16)
    timerLabel.Position       = UDim2.new(0, 0, 0, 48)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font           = Enum.Font.Gotham
    timerLabel.Text           = "⏱ " .. (data.timerText or "—")
    timerLabel.TextColor3     = Color3.fromRGB(140, 160, 220)
    timerLabel.TextSize       = 11
    timerLabel.TextXAlignment = Enum.TextXAlignment.Left
    timerLabel.ZIndex         = 7
    timerLabel.Parent         = textBlock

    -- Earnings
    local earningsLabel = Instance.new("TextLabel")
    earningsLabel.Name           = "EarningsLabel"
    earningsLabel.Size           = UDim2.new(0, 80, 0, 16)
    earningsLabel.Position       = UDim2.new(0, 0, 1, -22)
    earningsLabel.BackgroundTransparency = 1
    earningsLabel.Font           = Enum.Font.GothamBold
    earningsLabel.Text           = "💰 " .. (data.earnings or "—")
    earningsLabel.TextColor3     = Color3.fromRGB(255, 215, 80)
    earningsLabel.TextSize       = 11
    earningsLabel.TextXAlignment = Enum.TextXAlignment.Left
    earningsLabel.ZIndex         = 7
    earningsLabel.Parent         = textBlock

    -- Кнопка STEAL
    local stealBtn = Instance.new("TextButton")
    stealBtn.Name             = "StealBtn"
    stealBtn.Size             = UDim2.new(0, 72, 0, 36)
    stealBtn.Position         = UDim2.new(1, -80, 0.5, -18)
    stealBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 80)
    stealBtn.BorderSizePixel  = 0
    stealBtn.Font             = Enum.Font.GothamBold
    stealBtn.Text             = "STEAL"
    stealBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    stealBtn.TextSize         = 13
    stealBtn.ZIndex           = 7
    stealBtn.Parent           = frame

    local sbCorner = Instance.new("UICorner")
    sbCorner.CornerRadius = UDim.new(0, 8)
    sbCorner.Parent       = stealBtn

    local sbGrad = Instance.new("UIGradient")
    sbGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 100)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 30, 60)),
    })
    sbGrad.Rotation = 90
    sbGrad.Parent   = stealBtn

    -- Hover эффект на кнопке Steal
    stealBtn.MouseEnter:Connect(function()
        TweenService:Create(stealBtn, TweenInfo.new(0.12), {
            Size = UDim2.new(0, 76, 0, 38),
            Position = UDim2.new(1, -82, 0.5, -19)
        }):Play()
    end)
    stealBtn.MouseLeave:Connect(function()
        TweenService:Create(stealBtn, TweenInfo.new(0.12), {
            Size = UDim2.new(0, 72, 0, 36),
            Position = UDim2.new(1, -80, 0.5, -18)
        }):Play()
    end)

    -- Привязываем логику Steal (см. раздел 7)
    stealBtn.MouseButton1Click:Connect(function()
        _G.PetMonitorSteal(pet, data)
    end)

    return frame
end

-- Функция: вычислить LayoutOrder карточки для сортировки
local function getCardSortOrder(data)
    local rO = getRarityOrder(data.rarityKey)
    local mO = getMutationOrder((data.mutation or "Normal"):match("^%s*(.-)%s*$"))

    -- Пробуем прочитать таймер как число (секунды)
    local timerVal = 9999
    local timerStr = data.timerText or ""
    local mins, secs = timerStr:match("(%d+):(%d+)")
    if mins and secs then
        timerVal = tonumber(mins) * 60 + tonumber(secs)
    else
        local s = timerStr:match("(%d+)")
        if s then timerVal = tonumber(s) end
    end

    -- LayoutOrder: редкость * 10000 + мутация * 1000 + таймер
    return rO * 10000 + mO * 1000 + math.floor(timerVal)
end

-- Глобальная функция рендера (вызывается из CheckBox коллбэков)
function _G.PetMonitorRenderList()
    -- Убрать все текущие карточки
    for _, f in pairs(cardFrames) do
        f:Destroy()
    end
    cardFrames = {}

    local shown = 0

    -- Собираем петов, прошедших фильтр
    local filtered = {}
    for pet, data in pairs(petCache) do
        if petPassesFilter(data) then
            table.insert(filtered, { pet = pet, data = data })
        end
    end

    -- Сортируем
    table.sort(filtered, function(a, b)
        return getCardSortOrder(a.data) < getCardSortOrder(b.data)
    end)

    -- Создаём карточки
    for i, entry in ipairs(filtered) do
        local card = createPetCard(entry.pet, entry.data)
        card.LayoutOrder = i
        cardFrames[entry.pet] = card
        shown = shown + 1
    end

    countLabel.Text = shown .. " pet" .. (shown ~= 1 and "s" or "")
end

-- ══════════════════════════════════════════════════════════════
-- 7. ФУНКЦИЯ STEAL
-- ══════════════════════════════════════════════════════════════

function _G.PetMonitorSteal(pet, data)
    -- Проверяем, жив ли пет ещё
    if not pet or not pet.Parent then
        warn("[PetMonitor] Pet уже исчез, Steal отменён.")
        return
    end

    local head = data.headPart or pet:FindFirstChild("Head")
    if not head then
        warn("[PetMonitor] Head не найден для: " .. pet.Name)
        return
    end

    local prompt = data.prompt or head:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        warn("[PetMonitor] ProximityPrompt не найден для: " .. pet.Name)
        return
    end

    -- Блокируем кнопку на время (через карточку)
    local card = cardFrames[pet]
    local stealBtn = card and card:FindFirstChild("StealBtn")
    if stealBtn then
        stealBtn.Text    = "..."
        stealBtn.Active  = false
    end

    -- 1. Телепортируем к голове пета
    local chr = LocalPlayer.Character
    if not chr then return end
    local hrp = chr:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    hrp.CFrame = head.CFrame * CFrame.new(0, 0, 2.5)
    task.wait(STEAL_TELEPORT_WAIT)

    -- 2. Активируем ProximityPrompt
    if prompt and prompt.Parent then
        task.wait(STEAL_PROMPT_WAIT)
        fireproximityprompt(prompt)  -- встроенная функция Roblox executor'ов
        -- Альтернатива если выше не работает:
        -- VirtualUser:ClickButton2(Vector2.new(), workspace.CurrentCamera)
    end

    task.wait(STEAL_RETURN_WAIT)

    -- 3. Телепортируем в SafeZone
    local safeZone = workspace:FindFirstChild("SafeZone")
    if safeZone then
        chr = LocalPlayer.Character
        hrp = chr and chr:FindFirstChild("HumanoidRootPart")
        if hrp then
            if safeZone:IsA("BasePart") then
                hrp.CFrame = safeZone.CFrame + Vector3.new(0, 3, 0)
            elseif safeZone:IsA("Model") then
                local szPrimary = safeZone.PrimaryPart
                    or safeZone:FindFirstChildOfClass("BasePart")
                if szPrimary then
                    hrp.CFrame = szPrimary.CFrame + Vector3.new(0, 3, 0)
                end
            end
        end
    else
        warn("[PetMonitor] SafeZone не найден в workspace.")
    end

    -- Разблокируем кнопку
    if stealBtn and stealBtn.Parent then
        stealBtn.Text   = "STEAL"
        stealBtn.Active = true
    end
end

-- ══════════════════════════════════════════════════════════════
-- 8. ОБНОВЛЕНИЕ ТАЙМЕРОВ (RunService.Heartbeat)
-- ══════════════════════════════════════════════════════════════

-- Обновляем таймеры не каждый кадр, а раз в секунду
local lastTimerUpdate = 0

RunService.Heartbeat:Connect(function(dt)
    lastTimerUpdate = lastTimerUpdate + dt
    if lastTimerUpdate < 1 then return end
    lastTimerUpdate = 0

    -- Для каждого пета в кэше обновляем таймер из InfoGUI
    for pet, data in pairs(petCache) do
        local infoGUI = pet:FindFirstChild("InfoGUI")
        if infoGUI then
            local timerLabel = infoGUI:FindFirstChild("Timer")
            if timerLabel then
                data.timerText = timerLabel.Text
                -- Обновляем карточку если она видима
                local card = cardFrames[pet]
                if card then
                    local tb = card:FindFirstChild("TextBlock")
                    if tb then
                        local tl = tb:FindFirstChild("TimerLabel")
                        if tl then
                            tl.Text = "⏱ " .. data.timerText
                        end
                    end
                end
            end
            -- Также обновляем earnings
            local earningsLabel = infoGUI:FindFirstChild("Earnings")
            if earningsLabel then
                data.earnings = earningsLabel.Text
                local card = cardFrames[pet]
                if card then
                    local tb = card:FindFirstChild("TextBlock")
                    if tb then
                        local el = tb:FindFirstChild("EarningsLabel")
                        if el then
                            el.Text = "💰 " .. data.earnings
                        end
                    end
                end
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
-- 9. ПОДПИСКА НА ChildAdded / ChildRemoved
-- ══════════════════════════════════════════════════════════════

-- Добавить пета в кэш и перерендерить
local function onPetAdded(pet, rarityKey)
    if petCache[pet] then return end   -- уже есть
    local data = extractPetData(pet, rarityKey)
    petCache[pet] = data
    _G.PetMonitorRenderList()
end

-- Удалить пета из кэша и перерендерить
local function onPetRemoved(pet)
    if not petCache[pet] then return end
    petCache[pet] = nil
    -- Удалить карточку напрямую если есть
    if cardFrames[pet] then
        cardFrames[pet]:Destroy()
        cardFrames[pet] = nil
    end
    -- Пересчитать счётчик
    local count = 0
    for _ in pairs(petCache) do count = count + 1 end
    countLabel.Text = count .. " pet" .. (count ~= 1 and "s" or "")
end

-- Слушать изменения в каждой папке редкости
local function watchFolder(folder, rarityKey)
    -- Загружаем уже существующих петов
    for _, pet in ipairs(folder:GetChildren()) do
        task.spawn(onPetAdded, pet, rarityKey)
    end

    folder.ChildAdded:Connect(function(pet)
        -- Небольшая задержка чтобы InfoGUI успел загрузиться
        task.wait(0.25)
        onPetAdded(pet, rarityKey)
    end)

    folder.ChildRemoved:Connect(function(pet)
        onPetRemoved(pet)
    end)
end

-- Подписываемся на все известные папки и на новые
local function initFolderWatchers()
    for _, rarKey in ipairs(RARITY_FOLDERS) do
        local folder = ItemSpawners:FindFirstChild(rarKey)
        if folder then
            watchFolder(folder, rarKey)
        end
    end

    -- Если появятся новые папки (на случай расширения)
    ItemSpawners.ChildAdded:Connect(function(newFolder)
        local rarKey = newFolder.Name
        -- Проверяем, есть ли мы его уже в нашем списке
        local known = false
        for _, k in ipairs(RARITY_FOLDERS) do
            if k == rarKey then known = true break end
        end
        if known then
            watchFolder(newFolder, rarKey)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
-- 10. ИНИЦИАЛИЗАЦИЯ
-- ══════════════════════════════════════════════════════════════

-- Анимация появления GUI
mainFrame.Size     = UDim2.new(0, 0, 0, 0)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size     = UDim2.new(0, 520, 0, 620),
    Position = UDim2.new(0.5, -260, 0.5, -310)
}):Play()

-- Запускаем наблюдатели за папками
initFolderWatchers()

-- Первоначальный рендер
task.delay(0.5, function()
    _G.PetMonitorRenderList()
end)

print("[PetMonitor] ✅ Загружен. Мониторинг запущен!")
