-- ╔══════════════════════════════════════════════════════════╗ ццц
-- ║          PET INVENTORY VIEWER  —  LocalScript            ║
-- ║  Вставь в StarterPlayerScripts или запусти через executor║
-- ╚══════════════════════════════════════════════════════════╝

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer  = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────
--  НАСТРОЙКИ
-- ─────────────────────────────────────────────────────────────
local IGNORE_TOOLS = { Bat = true, Slap = true }

local RARITY_ORDER = {
    SpecialItemSpawn = 1, OG = 2, Mythical = 3, Legendary = 4,
    Epic = 5, Rare = 6, Uncommon = 7, Common = 8,
}
local MUTATION_ORDER = {
    Divine = 1, Neon = 2, Blood = 3, Rainbow = 4,
    Ruby = 5, Diamond = 6, Golden = 7, Normal = 8,
}
local RARITY_COLORS = {
    Common           = Color3.fromRGB(180, 180, 180),
    Uncommon         = Color3.fromRGB(71,  231, 160),
    Rare             = Color3.fromRGB(0,   242, 255),
    Epic             = Color3.fromRGB(255,  71, 255),
    Legendary        = Color3.fromRGB(255, 162,   0),
    Mythical         = Color3.fromRGB(255,  99, 152),
    OG               = Color3.fromRGB(52,  214, 137),
    SpecialItemSpawn = Color3.fromRGB(80,  220, 255),
}
local MUTATION_COLORS = {
    Normal  = Color3.fromRGB(200, 200, 200),
    Golden  = Color3.fromRGB(255, 247,   0),
    Diamond = Color3.fromRGB(25,  255, 255),
    Ruby    = Color3.fromRGB(255,  23,  55),
    Rainbow = Color3.fromRGB(0,   255, 170),
    Blood   = Color3.fromRGB(255,   0,   0),
    Neon    = Color3.fromRGB(215, 255,   0),
    Divine  = Color3.fromRGB(255, 232,  36),
}

-- ─────────────────────────────────────────────────────────────
--  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ─────────────────────────────────────────────────────────────
local FALLBACK_COLOR = Color3.fromRGB(150, 150, 150)

local function getRarityColor(rarity)
    if type(rarity) ~= "string" or rarity == "" then return FALLBACK_COLOR end
    return RARITY_COLORS[rarity] or FALLBACK_COLOR
end
local function getMutationColor(mutation)
    if type(mutation) ~= "string" or mutation == "" then return FALLBACK_COLOR end
    return MUTATION_COLORS[mutation] or FALLBACK_COLOR
end

local function labelColor(c)
    -- делаем полупрозрачный вариант цвета для фона чипа
    if typeof(c) ~= "Color3" then return Color3.fromRGB(25, 25, 40) end
    return Color3.fromRGB(
        math.floor(c.R * 255 * 0.22),
        math.floor(c.G * 255 * 0.22),
        math.floor(c.B * 255 * 0.22)
    )
end

local function newCorner(r, parent)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = parent
    return c
end

local function newStroke(thickness, color, transp, parent)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness
    s.Color = color
    s.Transparency = transp or 0
    s.Parent = parent
    return s
end

local function tween(obj, props, t, style, dir)
    TweenService:Create(obj,
        TweenInfo.new(t or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    ):Play()
end

-- ─────────────────────────────────────────────────────────────
--  ЧТЕНИЕ ПЕТОВ ИЗ БЕКПАКА
-- ─────────────────────────────────────────────────────────────
local function readPets(player)
    local bp = player:FindFirstChild("Backpack") [cite: 7]
    if not bp then return {} end [cite: 7]

    local pets = {} [cite: 7]
    local countMap = {}   -- name+mutation -> count [cite: 7]

    for _, tool in ipairs(bp:GetChildren()) do [cite: 7]
        if tool:IsA("Tool") and not IGNORE_TOOLS[tool.Name] then [cite: 7]
            local ok, err = pcall(function() [cite: 8]
                -- InfoGUI
                local infoGUI = tool:FindFirstChild("InfoGUI") [cite: 8]
                if infoGUI then [cite: 8]
                    local earnings = "" [cite: 8]
                    local mutation = "Normal" [cite: 8]
                    local petName  = tool.Name [cite: 8, 9]
                    local rarity   = "Common" [cite: 9]

                    for _, child in ipairs(infoGUI:GetDescendants()) do [cite: 9]
                        -- Безопасно читаем .Text только у TextLabel/TextBox
                        if not (child:IsA("TextLabel") or child:IsA("TextBox")) then continue end [cite: 9, 10]
                        
                        local txt = child.Text [cite: 10]
                        if type(txt) ~= "string" or txt == "" then continue end [cite: 10]
                        local trimmed = txt:match("^%s*(.-)%s*$") -- убираем пробелы [cite: 10]

                        -- По имени объекта (точное совпадение)
                        local n = child.Name [cite: 10, 11]
                        if n == "Earnings" then [cite: 11]
                            earnings = trimmed [cite: 11]
                        elseif n == "Mutation" then [cite: 11]
                            if trimmed ~= "" then mutation = trimmed end [cite: 11, 12]
                        elseif n == "Name" then [cite: 12]
                            if trimmed ~= "" then petName = trimmed end [cite: 12]
                        elseif n == "Rarity" then [cite: 13]
                            if trimmed ~= "" then rarity = trimmed end [cite: 13]
                        end

                        -- По содержимому (формат "Ключ: Значение")
                        local k, v = trimmed:match("^([%a]+):%s*(.+)$") [cite: 13, 14]
                        if k and v then [cite: 14]
                            k = k:lower() [cite: 14]
                            if k == "earnings" then earnings = v [cite: 14]
                            elseif k == "mutation" and v ~= "" then mutation = v [cite: 14, 15]
                            elseif k == "rarity"   and v ~= "" then rarity   = v [cite: 15]
                            elseif k == "name"     and v ~= "" then petName  = v [cite: 15, 16]
                            end
                        end
                    end

                    -- ИЗОБРАЖЕНИЕ ПЕТА (Безопасное чтение через проверки IsA)
                    local imageId = "" [cite: 16, 17]
                    local openThis = tool:FindFirstChild("Open This") [cite: 17]
                    if openThis then [cite: 17]
                        local imgPart = openThis:FindFirstChild("Paste the link to the image in here") [cite: 17]
                        if imgPart then [cite: 17, 18]
                            if imgPart:IsA("Decal") then [cite: 18]
                                imageId = imgPart.Texture [cite: 18]
                            elseif imgPart:IsA("ImageLabel") or imgPart:IsA("ImageButton") then [cite: 19, 20]
                                imageId = imgPart.Image [cite: 20]
                            elseif imgPart:IsA("StringValue") or imgPart:IsA("ObjectValue") then [cite: 19]
                                imageId = tostring(imgPart.Value) [cite: 19]
                            end
                        end
                    end

                    -- Нормализуем
                    if mutation == "" then mutation = "Normal" end [cite: 22]
                    if rarity   == "" then rarity   = "Common" end [cite: 22]

                    local key = petName .. "|" .. mutation [cite: 23]
                    countMap[key] = (countMap[key] or 0) + 1 [cite: 23]

                    table.insert(pets, { [cite: 23]
                        name     = petName, [cite: 23]
                        rarity   = rarity, [cite: 24]
                        mutation = mutation, [cite: 24]
                        earnings = earnings, [cite: 24]
                        image    = imageId, [cite: 24]
                        key      = key, [cite: 24, 25]
                    })
                end -- if infoGUI
            end) -- pcall
            
            if not ok then [cite: 25]
                warn("[PetViewer] Ошибка чтения tool '" .. tool.Name .. "': " .. tostring(err)) [cite: 25]
            end [cite: 26]
        end [cite: 26]
    end [cite: 26]

    -- Дедупликация — оставляем уникальные (name+mutation), добавляем count
    local seen   = {} [cite: 26]
    local result = {} [cite: 26]
    for _, p in ipairs(pets) do [cite: 26]
        if not seen[p.key] then [cite: 26]
            seen[p.key] = true [cite: 26]
            p.count = countMap[p.key] [cite: 26]
            table.insert(result, p) [cite: 27]
        end [cite: 27]
    end [cite: 27]
    return result [cite: 27]
end

-- ─────────────────────────────────────────────────────────────
--  СОРТИРОВКА
-- ─────────────────────────────────────────────────────────────
local function sortPets(pets, mode)
    local sorted = table.clone(pets)
    if mode == "rarity" then
        table.sort(sorted, function(a, b)
            local ra = RARITY_ORDER[a.rarity] or 99
            local rb = RARITY_ORDER[b.rarity] or 99
            if ra ~= rb then 
                return ra < rb 
            end
            return a.name:lower() < b.name:lower()
        end)
    elseif mode == "mutation" then
        table.sort(sorted, function(a, b)
            local ma = MUTATION_ORDER[a.mutation] or 99
            local mb = MUTATION_ORDER[b.mutation] or 99
            if ma ~= mb then 
                return ma < mb 
            end
            return a.name:lower() < b.name:lower()
        end)
    elseif mode == "count" then
        table.sort(sorted, function(a, b)
            if a.count ~= b.count then 
                return a.count > b.count 
            end
            return a.name:lower() < b.name:lower()
        end)
    else -- "name"
        table.sort(sorted, function(a, b) 
            return a.name:lower() < b.name:lower() 
        end)
    end
    return sorted
end

-- ─────────────────────────────────────────────────────────────
--  ПОСТРОЕНИЕ GUI
-- ─────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name             = "PetInventoryViewer"
screenGui.ResetOnSpawn     = false
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset   = true
screenGui.Parent           = LocalPlayer:WaitForChild("PlayerGui")

-- фон-затемнение
local overlay = Instance.new("Frame")
overlay.Name              = "Overlay"
overlay.Size              = UDim2.fromScale(1, 1)
overlay.BackgroundColor3  = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.Visible           = false
overlay.ZIndex            = 10
overlay.Parent            = screenGui

-- ══════════ ГЛАВНОЕ ОКНО ══════════
local mainFrame = Instance.new("Frame")
mainFrame.Name              = "MainFrame"
mainFrame.Size              = UDim2.new(0, 820, 0, 560)
mainFrame.AnchorPoint       = Vector2.new(0.5, 0.5)
mainFrame.Position          = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3  = Color3.fromRGB(10, 11, 18)
mainFrame.BorderSizePixel   = 0
mainFrame.Visible           = false
mainFrame.ZIndex            = 11
mainFrame.Parent            = screenGui
newCorner(16, mainFrame)
newStroke(1.5, Color3.fromRGB(60, 65, 100), 0.2, mainFrame)

-- градиент сверху
local topGrad = Instance.new("Frame")
topGrad.Size              = UDim2.new(1, 0, 0, 3)
topGrad.BackgroundColor3  = Color3.fromRGB(100, 120, 255)
topGrad.BorderSizePixel   = 0
topGrad.ZIndex            = 12
topGrad.Parent            = mainFrame
local tg = Instance.new("UIGradient")
tg.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 160, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 220, 200)),
}
tg.Parent = topGrad
local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 16)
topCorner.Parent = topGrad

-- ── Шапка ──
local header = Instance.new("Frame")
header.Name             = "Header"
header.Size             = UDim2.new(1, 0, 0, 52)
header.BackgroundTransparency = 1
header.ZIndex           = 12
header.Parent           = mainFrame

local title = Instance.new("TextLabel")
title.Size              = UDim2.new(1, -60, 1, 0)
title.Position          = UDim2.new(0, 18, 0, 0)
title.BackgroundTransparency = 1
title.Font              = Enum.Font.GothamBold
title.TextSize          = 18
title.TextColor3        = Color3.fromRGB(220, 225, 255)
title.TextXAlignment    = Enum.TextXAlignment.Left
title.Text              = "🐾  Pet Inventory Viewer"
title.ZIndex            = 12
title.Parent            = header

-- кнопка закрыть
local closeBtn = Instance.new("TextButton")
closeBtn.Name           = "CloseBtn"
closeBtn.Size           = UDim2.new(0, 32, 0, 32)
closeBtn.AnchorPoint    = Vector2.new(1, 0.5)
closeBtn.Position       = UDim2.new(1, -14, 0.5, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 80)
closeBtn.Font           = Enum.Font.GothamBold
closeBtn.TextSize       = 16
closeBtn.TextColor3     = Color3.white
closeBtn.Text           = "✕"
closeBtn.ZIndex         = 13
closeBtn.Parent         = header
newCorner(8, closeBtn)

-- ── Разделитель ──
local divider = Instance.new("Frame")
divider.Size            = UDim2.new(1, -32, 0, 1)
divider.Position        = UDim2.new(0, 16, 0, 52)
divider.BackgroundColor3 = Color3.fromRGB(40, 45, 70)
divider.BorderSizePixel = 0
divider.ZIndex          = 12
divider.Parent          = mainFrame

-- ── Левая панель (выбор игрока) ──
local leftPanel = Instance.new("Frame")
leftPanel.Name          = "LeftPanel"
leftPanel.Size          = UDim2.new(0, 190, 1, -60)
leftPanel.Position      = UDim2.new(0, 0, 0, 53)
leftPanel.BackgroundColor3 = Color3.fromRGB(14, 15, 25)
leftPanel.BorderSizePixel  = 0
leftPanel.ZIndex        = 12
leftPanel.Parent        = mainFrame
local lpCorner = Instance.new("UICorner")
lpCorner.CornerRadius   = UDim.new(0, 16)
lpCorner.Parent         = leftPanel
-- обрежем правые углы
local lpRight = Instance.new("Frame")
lpRight.Size            = UDim2.new(0, 16, 1, 0)
lpRight.Position        = UDim2.new(1, -16, 0, 0)
lpRight.BackgroundColor3 = Color3.fromRGB(14, 15, 25)
lpRight.BorderSizePixel = 0
lpRight.ZIndex          = 11
lpRight.Parent          = leftPanel

local lpTitle = Instance.new("TextLabel")
lpTitle.Size            = UDim2.new(1, -16, 0, 30)
lpTitle.Position        = UDim2.new(0, 10, 0, 8)
lpTitle.BackgroundTransparency = 1
lpTitle.Font            = Enum.Font.GothamBold
lpTitle.TextSize        = 13
lpTitle.TextColor3      = Color3.fromRGB(120, 130, 180)
lpTitle.TextXAlignment  = Enum.TextXAlignment.Left
lpTitle.Text            = "PLAYERS ON SERVER"
lpTitle.ZIndex          = 13
lpTitle.Parent          = leftPanel

-- скролл для игроков
local playerScroll = Instance.new("ScrollingFrame")
playerScroll.Name           = "PlayerScroll"
playerScroll.Size           = UDim2.new(1, -10, 1, -48)
playerScroll.Position       = UDim2.new(0, 5, 0, 44)
playerScroll.BackgroundTransparency = 1
playerScroll.BorderSizePixel = 0
playerScroll.ScrollBarThickness = 3
playerScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 90, 150)
playerScroll.CanvasSize     = UDim2.new(0, 0, 0, 0)
playerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerScroll.ZIndex         = 13
playerScroll.Parent         = leftPanel

local playerList = Instance.new("UIListLayout")
playerList.Padding         = UDim.new(0, 4)
playerList.SortOrder       = Enum.SortOrder.LayoutOrder
playerList.Parent          = playerScroll

local playerPad = Instance.new("UIPadding")
playerPad.PaddingLeft  = UDim.new(0, 4)
playerPad.PaddingRight = UDim.new(0, 4)
playerPad.Parent       = playerScroll

-- ── Правая панель (контент) ──
local rightPanel = Instance.new("Frame")
rightPanel.Name         = "RightPanel"
rightPanel.Size         = UDim2.new(1, -198, 1, -60)
rightPanel.Position     = UDim2.new(0, 196, 0, 53)
rightPanel.BackgroundTransparency = 1
rightPanel.ZIndex       = 12
rightPanel.Parent       = mainFrame

-- строка инфо / сортировка
local topBar = Instance.new("Frame")
topBar.Size             = UDim2.new(1, 0, 0, 42)
topBar.BackgroundTransparency = 1
topBar.ZIndex           = 12
topBar.Parent           = rightPanel

local infoLabel = Instance.new("TextLabel")
infoLabel.Name          = "InfoLabel"
infoLabel.Size          = UDim2.new(0.5, 0, 1, 0)
infoLabel.BackgroundTransparency = 1
infoLabel.Font          = Enum.Font.GothamMedium
infoLabel.TextSize      = 13
infoLabel.TextColor3    = Color3.fromRGB(150, 160, 210)
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Text          = "← Выбери игрока"
infoLabel.ZIndex        = 13
infoLabel.Parent        = topBar

-- кнопки сортировки
local sortModes = {"rarity", "mutation", "name", "count"}
local sortLabels = {rarity="По редкости", mutation="По мутации", name="По имени", count="По кол-ву"}
local sortBtns = {}
local currentSort = "rarity"

local sortRow = Instance.new("Frame")
sortRow.Size            = UDim2.new(0.5, -4, 1, -10)
sortRow.Position        = UDim2.new(0.5, 0, 0, 5)
sortRow.BackgroundTransparency = 1
sortRow.ZIndex          = 13
sortRow.Parent          = topBar

local sortLayout = Instance.new("UIListLayout")
sortLayout.FillDirection = Enum.FillDirection.Horizontal
sortLayout.Padding       = UDim.new(0, 4)
sortLayout.VerticalAlignment = Enum.VerticalAlignment.Center
sortLayout.Parent        = sortRow

for _, mode in ipairs(sortModes) do
    local btn = Instance.new("TextButton")
    btn.Name            = mode
    btn.Size            = UDim2.new(0, 90, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(22, 24, 40)
    btn.Font            = Enum.Font.GothamSemibold
    btn.TextSize        = 11
    btn.TextColor3      = Color3.fromRGB(140, 150, 200)
    btn.Text            = sortLabels[mode]
    btn.AutoButtonColor = false
    btn.ZIndex          = 14
    btn.Parent          = sortRow
    newCorner(8, btn)
    newStroke(1, Color3.fromRGB(50, 55, 90), 0, btn)
    sortBtns[mode] = btn
end

local function updateSortBtns()
    for mode, btn in pairs(sortBtns) do
        if mode == currentSort then
            btn.BackgroundColor3 = Color3.fromRGB(60, 80, 180)
            btn.TextColor3       = Color3.white
        else
            btn.BackgroundColor3 = Color3.fromRGB(22, 24, 40)
            btn.TextColor3       = Color3.fromRGB(140, 150, 200)
        end
    end
end
updateSortBtns()

-- второй разделитель
local div2 = Instance.new("Frame")
div2.Size               = UDim2.new(1, 0, 0, 1)
div2.Position           = UDim2.new(0, 0, 0, 42)
div2.BackgroundColor3   = Color3.fromRGB(30, 33, 55)
div2.BorderSizePixel    = 0
div2.ZIndex             = 12
div2.Parent             = rightPanel

-- скролл карточек
local cardScroll = Instance.new("ScrollingFrame")
cardScroll.Name             = "CardScroll"
cardScroll.Size             = UDim2.new(1, -8, 1, -52)
cardScroll.Position         = UDim2.new(0, 0, 0, 52)
cardScroll.BackgroundTransparency = 1
cardScroll.BorderSizePixel  = 0
cardScroll.ScrollBarThickness = 4
cardScroll.ScrollBarImageColor3 = Color3.fromRGB(70, 80, 140)
cardScroll.CanvasSize        = UDim2.new(0, 0, 0, 0)
cardScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
cardScroll.ZIndex            = 12
cardScroll.Parent            = rightPanel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize          = UDim2.new(0, 140, 0, 185)
gridLayout.CellPadding       = UDim2.new(0, 10, 0, 10)
gridLayout.SortOrder         = Enum.SortOrder.LayoutOrder
gridLayout.Parent            = cardScroll

local gridPad = Instance.new("UIPadding")
gridPad.PaddingTop    = UDim.new(0, 8)
gridPad.PaddingLeft   = UDim.new(0, 6)
gridPad.PaddingBottom = UDim.new(0, 8)
gridPad.Parent        = cardScroll

-- placeholder
local placeholder = Instance.new("TextLabel")
placeholder.Name            = "Placeholder"
placeholder.Size            = UDim2.new(1, 0, 1, 0)
placeholder.BackgroundTransparency = 1
placeholder.Font            = Enum.Font.GothamMedium
placeholder.TextSize        = 15
placeholder.TextColor3      = Color3.fromRGB(80, 90, 130)
placeholder.Text            = "Выбери игрока слева,\nчтобы увидеть его петов"
placeholder.TextWrapped     = true
placeholder.ZIndex          = 13
placeholder.Parent          = cardScroll

-- ─────────────────────────────────────────────────────────────
--  СОЗДАНИЕ КАРТОЧКИ ПЕТА
-- ─────────────────────────────────────────────────────────────
local function createPetCard(petData, order)
    local rarityColor   = getRarityColor(petData.rarity)
    local mutColor      = getMutationColor(petData.mutation)

    local card = Instance.new("Frame")
    card.Name               = petData.name .. "_card"
    card.Size               = UDim2.new(0, 140, 0, 185)
    card.BackgroundColor3   = Color3.fromRGB(16, 17, 28)
    card.BorderSizePixel    = 0
    card.LayoutOrder        = order
    card.ZIndex             = 14
    card.Parent             = cardScroll
    newCorner(12, card)
    local cardStroke = newStroke(1.5, rarityColor, 0.3, card)

    -- Тонкая полоса сверху цвета редкости
    local rarBar = Instance.new("Frame")
    rarBar.Size             = UDim2.new(1, 0, 0, 3)
    rarBar.BackgroundColor3 = rarityColor
    rarBar.BorderSizePixel  = 0
    rarBar.ZIndex           = 15
    rarBar.Parent           = card
    newCorner(12, rarBar)

    -- Изображение пета
    local imgFrame = Instance.new("Frame")
    imgFrame.Size           = UDim2.new(1, -16, 0, 88)
    imgFrame.Position       = UDim2.new(0, 8, 0, 10)
    imgFrame.BackgroundColor3 = Color3.fromRGB(10, 11, 20)
    imgFrame.BorderSizePixel = 0
    imgFrame.ZIndex         = 15
    imgFrame.Parent         = card
    newCorner(8, imgFrame)

    local imgLabel = Instance.new("ImageLabel")
    imgLabel.Size           = UDim2.new(1, -8, 1, -8)
    imgLabel.Position       = UDim2.new(0, 4, 0, 4)
    imgLabel.BackgroundTransparency = 1
    imgLabel.ScaleType      = Enum.ScaleType.Fit
    imgLabel.ZIndex         = 16
    imgLabel.Image          = petData.image ~= "" and petData.image or "rbxasset://textures/ui/GuiImagePlaceholder.png"
    imgLabel.Parent         = imgFrame

    -- Значок количества (если > 1)
    if petData.count > 1 then
        local countBadge = Instance.new("TextLabel")
        countBadge.Size         = UDim2.new(0, 28, 0, 20)
        countBadge.Position     = UDim2.new(1, -32, 0, 4)
        countBadge.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
        countBadge.Font         = Enum.Font.GothamBold
        countBadge.TextSize     = 11
        countBadge.TextColor3   = Color3.fromRGB(220, 230, 255)
        countBadge.Text         = "×" .. petData.count
        countBadge.ZIndex       = 17
        countBadge.Parent       = card
        newCorner(6, countBadge)
        newStroke(1, Color3.fromRGB(60, 70, 120), 0, countBadge)
    end

    -- Имя
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size          = UDim2.new(1, -10, 0, 22)
    nameLabel.Position      = UDim2.new(0, 5, 0, 102)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font          = Enum.Font.GothamBold
    nameLabel.TextSize      = 12
    nameLabel.TextColor3    = Color3.fromRGB(230, 235, 255)
    nameLabel.TextTruncate  = Enum.TextTruncate.AtEnd
    nameLabel.Text          = petData.name
    nameLabel.ZIndex        = 15
    nameLabel.Parent        = card

    -- Чип редкости
    local rarChip = Instance.new("TextLabel")
    rarChip.Size            = UDim2.new(1, -10, 0, 18)
    rarChip.Position        = UDim2.new(0, 5, 0, 124)
    rarChip.BackgroundColor3 = labelColor(rarityColor)
    rarChip.Font            = Enum.Font.GothamSemibold
    rarChip.TextSize        = 10
    rarChip.TextColor3      = rarityColor
    rarChip.Text            = "✦ " .. petData.rarity
    rarChip.ZIndex          = 15
    rarChip.Parent          = card
    newCorner(5, rarChip)

    -- Чип мутации
    local mutChip = Instance.new("TextLabel")
    mutChip.Size            = UDim2.new(1, -10, 0, 18)
    mutChip.Position        = UDim2.new(0, 5, 0, 144)
    mutChip.BackgroundColor3 = labelColor(mutColor)
    mutChip.Font            = Enum.Font.GothamSemibold
    mutChip.TextSize        = 10
    mutChip.TextColor3      = mutColor
    mutChip.Text            = "◈ " .. petData.mutation
    mutChip.ZIndex          = 15
    mutChip.Parent          = card
    newCorner(5, mutChip)

    -- Заработок
    local earnLabel = Instance.new("TextLabel")
    earnLabel.Size          = UDim2.new(1, -10, 0, 16)
    earnLabel.Position      = UDim2.new(0, 5, 0, 164)
    earnLabel.BackgroundTransparency = 1
    earnLabel.Font          = Enum.Font.Gotham
    earnLabel.TextSize      = 10
    earnLabel.TextColor3    = Color3.fromRGB(100, 230, 120)
    earnLabel.Text          = "💰 " .. (petData.earnings ~= "" and petData.earnings or "—") .. "/s"
    earnLabel.ZIndex        = 15
    earnLabel.Parent        = card

    return card
end

-- ─────────────────────────────────────────────────────────────
--  ОТОБРАЖЕНИЕ ИНВЕНТАРЯ
-- ─────────────────────────────────────────────────────────────
local currentPets = {}

local function clearCards()
    for _, child in ipairs(cardScroll:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "Placeholder" then
            child:Destroy()
        end
    end
end

local function displayPets()
    clearCards()
    local sorted = sortPets(currentPets, currentSort)
    if #sorted == 0 then
        placeholder.Text    = "У игрока нет петов\n(или они не загружены)"
        placeholder.Visible = true
        return
    end
    placeholder.Visible = false
    for i, pet in ipairs(sorted) do
        createPetCard(pet, i)
    end
end

local function loadPlayer(player)
    infoLabel.Text = "⏳  Загружаю " .. player.Name .. "..."
    clearCards()
    placeholder.Visible = true
    placeholder.Text    = "⏳  Читаю бекпак..."

    task.spawn(function()
        local pets = readPets(player)
        currentPets = pets
        infoLabel.Text = "🐾 " .. player.Name .. "  —  " .. #pets .. " уникальных петов"
        displayPets()
    end)
end

-- ─────────────────────────────────────────────────────────────
--  СПИСОК ИГРОКОВ
-- ─────────────────────────────────────────────────────────────
local selectedPlayerBtn = nil

local function updatePlayerColor(btn, selected)
    if selected then
        btn.BackgroundColor3 = Color3.fromRGB(45, 55, 120)
        btn.TextColor3       = Color3.white
    else
        btn.BackgroundColor3 = Color3.fromRGB(20, 22, 38)
        btn.TextColor3       = Color3.fromRGB(170, 180, 220)
    end
end

local function buildPlayerButton(player)
    local btn = Instance.new("TextButton")
    btn.Name            = player.Name
    btn.Size            = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(20, 22, 38)
    btn.Font            = Enum.Font.GothamMedium
    btn.TextSize        = 13
    btn.TextColor3      = Color3.fromRGB(170, 180, 220)
    btn.Text            = "  " .. player.Name
    btn.TextXAlignment  = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.ZIndex          = 14
    btn.Parent          = playerScroll
    newCorner(8, btn)

    btn.MouseButton1Click:Connect(function()
        if selectedPlayerBtn then
            updatePlayerColor(selectedPlayerBtn, false)
        end
        selectedPlayerBtn = btn
        updatePlayerColor(btn, true)
        loadPlayer(player)
    end)

    btn.MouseEnter:Connect(function()
        if btn ~= selectedPlayerBtn then
            tween(btn, {BackgroundColor3 = Color3.fromRGB(30, 34, 60)}, 0.15)
        end
    end)
    btn.MouseLeave:Connect(function()
        if btn ~= selectedPlayerBtn then
            tween(btn, {BackgroundColor3 = Color3.fromRGB(20, 22, 38)}, 0.15)
        end
    end)

    return btn
end

local function refreshPlayerList()
    selectedPlayerBtn = nil -- Сбрасываем ссылку перед удалением кнопок
    for _, child in ipairs(playerScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            buildPlayerButton(player)
        end
    end
end

-- ─────────────────────────────────────────────────────────────
--  СОРТИРОВКА — события
-- ─────────────────────────────────────────────────────────────
for _, mode in ipairs(sortModes) do
    sortBtns[mode].MouseButton1Click:Connect(function()
        currentSort = mode
        updateSortBtns()
        if #currentPets > 0 then displayPets() end
    end)
end

-- ─────────────────────────────────────────────────────────────
--  КНОПКА ЗАКРЫТЬ
-- ─────────────────────────────────────────────────────────────
local isOpen = false

local function openGUI()
    isOpen = true
    overlay.Visible = true
    mainFrame.Visible = true
    
    -- Сбрасываем размер в 0 для эффекта появления
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundTransparency = 1
    
    tween(overlay, {BackgroundTransparency = 0.55}, 0.25)
    tween(mainFrame, {Size = UDim2.new(0, 820, 0, 560)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    
    refreshPlayerList()
end

local function closeGUI()
    isOpen = false
    tween(overlay, {BackgroundTransparency = 1}, 0.2)
    tween(mainFrame, {Size = UDim2.new(0, 0, 0, 0)}, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    
    task.wait(0.22)
    if not isOpen then -- Проверка, чтобы не сломать, если резко открыли назад
        overlay.Visible   = false
        mainFrame.Visible = false
        currentPets       = {}
        selectedPlayerBtn = nil
    end
end

closeBtn.MouseButton1Click:Connect(closeGUI)
overlay.MouseButton1Click:Connect(closeGUI)  -- клик вне окна закрывает

-- ─────────────────────────────────────────────────────────────
--  КНОПКА ОТКРЫТИЯ (в углу экрана)
-- ─────────────────────────────────────────────────────────────
local openBtn = Instance.new("TextButton")
openBtn.Name            = "OpenPetViewer"
openBtn.Size            = UDim2.new(0, 160, 0, 38)
openBtn.Position        = UDim2.new(1, -170, 0, 60)
openBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 75)
openBtn.Font            = Enum.Font.GothamBold
openBtn.TextSize        = 13
openBtn.TextColor3      = Color3.fromRGB(200, 210, 255)
openBtn.Text            = "🐾  Pet Viewer"
openBtn.AutoButtonColor = false
openBtn.ZIndex          = 5
openBtn.Parent          = screenGui
newCorner(10, openBtn)
newStroke(1.5, Color3.fromRGB(70, 90, 200), 0.2, openBtn)

openBtn.MouseEnter:Connect(function()
    tween(openBtn, {BackgroundColor3 = Color3.fromRGB(50, 65, 130)}, 0.15)
end)
openBtn.MouseLeave:Connect(function()
    tween(openBtn, {BackgroundColor3 = Color3.fromRGB(30, 35, 75)}, 0.15)
end)
openBtn.MouseButton1Click:Connect(function()
    if isOpen then closeGUI() else openGUI() end
end)

-- ─────────────────────────────────────────────────────────────
--  АВТООБНОВЛЕНИЕ СПИСКА ИГРОКОВ
-- ─────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function()
    if isOpen then refreshPlayerList() end
end)
Players.PlayerRemoving:Connect(function(player)
    if isOpen then
        local btn = playerScroll:FindFirstChild(player.Name)
        if btn then btn:Destroy() end
    end
end)

print("[PetInventoryViewer] ✅ Загружен. Нажми кнопку 'Pet Viewer' в правом углу.")
