-- PetBaseGUI LocalScript
-- Показывает всех петов по этажам, их инфу и кнопку апгрейдавыфвы

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local RequestSlotUpgrade = ReplicatedStorage:WaitForChild("Events"):WaitForChild("RequestSlotUpgrade")

local PetBaseGUI = nil          -- ←←← Добавь это
local CurrentScrollFrame = nil  -- ←←← Добавь это

-- ══════════════════════════════════════════
--  УТИЛИТЫ
-- ══════════════════════════════════════════

local function stripRichText(s)
	return (s or ""):gsub("<[^<>]+>", "")
end

-- Цвет редкости
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

local DEFAULT_MUTATION_COLOR = Color3.fromRGB(200, 160, 255)

local function rarityColor(rarity)
	for k, v in pairs(RARITY_COLORS) do
		if rarity:lower():find(k:lower()) then return v end
	end
	return Color3.fromRGB(200, 200, 200)
end

-- ══════════════════════════════════════════
--  ЧТЕНИЕ ДАННЫХ ПЕТА ИЗ СЛОТА
-- ══════════════════════════════════════════

local function getPetData(slot)
	local spawn = slot:FindFirstChild("Spawn")
	if not spawn then return nil end

	local pet = spawn:FindFirstChild("VisualItem")
	if not pet then return nil end

	local data = {
		name      = "Unknown",
		rarity    = "",
		mutation  = "",
		earnings  = "",
		imageId   = "",
	}

	-- InfoGUI → TextLabels
	local infoGUI = pet:FindFirstChild("InfoGUI")
	if infoGUI then
		local textLabels = infoGUI:FindFirstChild("TextLabels")
		if textLabels then
			local nameLabel     = textLabels:FindFirstChild("Name")
			local rarityLabel   = textLabels:FindFirstChild("Rarity")
			local mutLabel      = textLabels:FindFirstChild("Mutation")
			local earningsLabel = textLabels:FindFirstChild("Earnings")

			if nameLabel     then data.name     = stripRichText(nameLabel.Text)     end
			if rarityLabel   then data.rarity   = stripRichText(rarityLabel.Text)   end
			if mutLabel      then data.mutation = stripRichText(mutLabel.Text)      end
			if earningsLabel then data.earnings = stripRichText(earningsLabel.Text) end
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

-- ══════════════════════════════════════════
--  ЧТЕНИЕ СТОИМОСТИ АПГРЕЙДА ИЗ СЛОТА
-- ══════════════════════════════════════════

local function getUpgradeCost(slot)
	-- Ищем SurfaceGui с атрибутом SlotName (по аналогии с оригинальным скриптом)
	for _, desc in ipairs(slot:GetDescendants()) do
		if desc:IsA("SurfaceGui") then
			-- Пробуем найти цену апгрейда (TextLabel с числом или атрибут)
			local costAttr = desc:GetAttribute("UpgradeCost") or desc:GetAttribute("Cost")
			if costAttr then return tostring(costAttr) end

			-- Иначе ищем TextLabel "Cost" / "Price" / "UpgradeCost"
			for _, child in ipairs(desc:GetDescendants()) do
				if child:IsA("TextLabel") then
					local n = child.Name:lower()
					if n:find("cost") or n:find("price") or n:find("upgrade") then
						local txt = stripRichText(child.Text)
						if txt ~= "" and txt ~= "0" then return txt end
					end
				end
			end

			-- Fallback: UpgradeButton рядом — ищем любой TextLabel с числом
			local btn = desc:FindFirstChild("UpgradeButton", true)
			if btn then
				for _, sib in ipairs(desc:GetDescendants()) do
					if sib:IsA("TextLabel") then
						local txt = stripRichText(sib.Text)
						if txt:match("%d") then return txt end
					end
				end
			end
		end
	end
	return nil
end

-- FloorName и SlotName из SurfaceGui атрибутов
local function getSlotMeta(slot)
	for _, desc in ipairs(slot:GetDescendants()) do
		if desc:IsA("SurfaceGui") then
			local sn = desc:GetAttribute("SlotName")
			local fn = desc:GetAttribute("FloorName")
			if sn and fn then return fn, sn end
		end
	end
	-- Fallback по именам родителей
	local slotName  = slot.Name
	local floorName = slot.Parent and slot.Parent.Parent and slot.Parent.Parent.Name or ""
	return floorName, slotName
end

-- ══════════════════════════════════════════
--  СБОР ВСЕХ ДАННЫХ ПО БАЗЕ
-- ══════════════════════════════════════════

local function collectBaseData(plot)
	local floors = {}

	for _, floorObj in ipairs(plot:GetChildren()) do
		if floorObj.Name:lower():find("floor") then
			local slotsFolder = floorObj:FindFirstChild("Slots")
			if not slotsFolder then continue end

			local floorData = { name = floorObj.Name, slots = {} }

			for _, slot in ipairs(slotsFolder:GetChildren()) do
				local petData    = getPetData(slot)
				local upgradeCost = getUpgradeCost(slot)

				-- Показываем слот только если есть пет ИЛИ есть кнопка апгрейда
				if petData then
					local floorName, slotName = getSlotMeta(slot)
					table.insert(floorData.slots, {
						slotName    = slotName,
						floorName   = floorName,
						pet         = petData,
						upgradeCost = upgradeCost,
					})
				end
			end

			if #floorData.slots > 0 then
				table.insert(floors, floorData)
			end
		end
	end

	-- Сортировка этажей по номеру
	table.sort(floors, function(a, b)
		local na = tonumber(a.name:match("%d+")) or 0
		local nb = tonumber(b.name:match("%d+")) or 0
		return na < nb
	end)

	return floors
end

local function updateGUISlots(floors)
	if not CurrentScrollFrame then return end

	-- Очищаем только содержимое скролла
	for _, child in ipairs(CurrentScrollFrame:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then  -- floorHeader, card, emptyNotice
			child:Destroy()
		end
	end

	local totalPets = 0
	for _, f in ipairs(floors) do
		for _, s in ipairs(f.slots) do
			if s.pet then totalPets += 1 end
		end
	end

	-- Обновляем статус
	local statusBar = PetBaseGUI:FindFirstChild("Main", true):FindFirstChild("StatusBar")
	local statusLabel = statusBar and statusBar:FindFirstChildWhichIsA("TextLabel")
	if statusLabel then
		statusLabel.Text = string.format("📊  %d Floors  •  %d pets found", #floors, totalPets)
	end

	-- Создаём новые карточки
	for fi, floorData in ipairs(floors) do
		-- Заголовок этажа
		local floorHeader = Instance.new("Frame")
		floorHeader.Size = UDim2.new(1, 0, 0, 32)
		floorHeader.BackgroundColor3 = Color3.fromRGB(30, 38, 68)
		floorHeader.BorderSizePixel = 0
		floorHeader.LayoutOrder = fi * 100
		floorHeader.Parent = CurrentScrollFrame
		Instance.new("UICorner", floorHeader).CornerRadius = UDim.new(0, 8)

		local floorGrad = Instance.new("UIGradient")
		floorGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 60, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 30, 65)),
		})
		floorGrad.Rotation = 0
		floorGrad.Parent = floorHeader

		local floorLabel = Instance.new("TextLabel")
		floorLabel.Text = "🏢  " .. floorData.name:upper()
		floorLabel.Font = Enum.Font.GothamBold
		floorLabel.TextSize = 13
		floorLabel.TextColor3 = Color3.fromRGB(160, 200, 255)
		floorLabel.BackgroundTransparency = 1
		floorLabel.Size = UDim2.new(1, -16, 1, 0)
		floorLabel.Position = UDim2.new(0, 12, 0, 0)
		floorLabel.TextXAlignment = Enum.TextXAlignment.Left
		floorLabel.Parent = floorHeader

		-- Карточки слотов
		for si, slotData in ipairs(floorData.slots) do
			local card = Instance.new("Frame")
			card.Size            = UDim2.new(1, 0, 0, 90)
			card.BackgroundColor3 = Color3.fromRGB(18, 22, 38)
			card.BorderSizePixel = 0
			card.LayoutOrder     = fi * 100 + si
			card.Parent          = CurrentScrollFrame
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

			local cardStroke = Instance.new("UIStroke")
			cardStroke.Color = Color3.fromRGB(40, 55, 100)
			cardStroke.Thickness = 1
			cardStroke.Transparency = 0.5
			cardStroke.Parent = card

			-- Левая полоска
			local accent = Instance.new("Frame")
			accent.Size = UDim2.new(0, 4, 1, -16)
			accent.Position = UDim2.new(0, 0, 0.5, 0)
			accent.AnchorPoint = Vector2.new(0, 0.5)
			accent.BorderSizePixel = 0
			accent.BackgroundColor3 = slotData.pet and rarityColor(slotData.pet.rarity) or Color3.fromRGB(60, 70, 100)
			accent.Parent = card
			Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 4)

			local pet = slotData.pet

			if pet then
				-- Изображение
				local petImg = Instance.new("ImageLabel")
				petImg.Size   = UDim2.new(0, 70, 0, 70)
				petImg.Position = UDim2.new(0, 14, 0.5, 0)
				petImg.AnchorPoint = Vector2.new(0, 0.5)
				petImg.BackgroundColor3 = Color3.fromRGB(25, 30, 52)
				petImg.BorderSizePixel = 0
				petImg.Image = pet.imageId
				petImg.ScaleType = Enum.ScaleType.Fit
				petImg.Parent = card
				Instance.new("UICorner", petImg).CornerRadius = UDim.new(0, 8)

				-- Имя
				local nameLabel = Instance.new("TextLabel")
				nameLabel.Text = pet.name
				nameLabel.Font = Enum.Font.GothamBold
				nameLabel.TextSize = 14
				nameLabel.TextColor3 = Color3.fromRGB(230, 240, 255)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Size = UDim2.new(0, 200, 0, 20)
				nameLabel.Position = UDim2.new(0, 96, 0, 12)
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
				nameLabel.Parent = card

				-- Редкость
				if pet.rarity ~= "" then
					local rarBadge = Instance.new("Frame")
					rarBadge.Size = UDim2.new(0, 0, 0, 18)
					rarBadge.AutomaticSize = Enum.AutomaticSize.X
					rarBadge.Position = UDim2.new(0, 96, 0, 34)
					rarBadge.BackgroundColor3 = rarityColor(pet.rarity)
					rarBadge.BorderSizePixel = 0
					rarBadge.Parent = card
					Instance.new("UICorner", rarBadge).CornerRadius = UDim.new(0, 5)

					local rarPad = Instance.new("UIPadding")
					rarPad.PaddingLeft  = UDim.new(0, 6)
					rarPad.PaddingRight = UDim.new(0, 6)
					rarPad.Parent = rarBadge

					local rarLabel = Instance.new("TextLabel")
					rarLabel.Text = pet.rarity
					rarLabel.Font = Enum.Font.GothamBold
					rarLabel.TextSize = 10
					rarLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
					rarLabel.BackgroundTransparency = 1
					rarLabel.Size = UDim2.new(1, 0, 1, 0)
					rarLabel.TextXAlignment = Enum.TextXAlignment.Center
					rarLabel.Parent = rarBadge
				end

				-- Мутация
				if pet.mutation ~= "" and pet.mutation:lower() ~= "none" and pet.mutation ~= "-" then
					local mutLabel = Instance.new("TextLabel")
					mutLabel.Text = "✨ " .. pet.mutation
					mutLabel.Font = Enum.Font.Gotham
					mutLabel.TextSize = 11

					local targetColor = DEFAULT_MUTATION_COLOR
					for mutName, color in pairs(MUTATION_COLORS) do
						if mutName:lower() == pet.mutation:lower() then
							targetColor = color
							break
						end
					end

					mutLabel.TextColor3 = targetColor
					mutLabel.BackgroundTransparency = 1
					mutLabel.Size = UDim2.new(0, 150, 0, 16)
					mutLabel.Position = UDim2.new(0, 96, 0, 55)
					mutLabel.TextXAlignment = Enum.TextXAlignment.Left
					mutLabel.Parent = card
				end

				-- Заработок
				if pet.earnings ~= "" then
					local earnLabel = Instance.new("TextLabel")
					earnLabel.Text = "💰 " .. pet.earnings
					earnLabel.Font = Enum.Font.Gotham
					earnLabel.TextSize = 11
					earnLabel.TextColor3 = Color3.fromRGB(255, 210, 80)
					earnLabel.BackgroundTransparency = 1
					earnLabel.Size = UDim2.new(0, 150, 0, 16)
					earnLabel.Position = UDim2.new(0, 96, 0, 70)
					earnLabel.TextXAlignment = Enum.TextXAlignment.Left
					earnLabel.Parent = card
				end

			-- Кнопка апгрейда
			if slotData.upgradeCost and slotData.floorName ~= "" and slotData.slotName ~= "" then
				local upgradeBtn = Instance.new("TextButton")
				upgradeBtn.Size  = UDim2.new(0, 110, 0, 36)
				upgradeBtn.Position = UDim2.new(1, -120, 0.5, -18)
				upgradeBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 255)
				upgradeBtn.BorderSizePixel = 0
				upgradeBtn.Text = ""
				upgradeBtn.Parent = card
				Instance.new("UICorner", upgradeBtn).CornerRadius = UDim.new(0, 9)

				local upgGrad = Instance.new("UIGradient")
				upgGrad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 130, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(30,  70, 220)),
				})
				upgGrad.Rotation = 90
				upgGrad.Parent = upgradeBtn

				local upgText = Instance.new("TextLabel")
				upgText.Text = "⬆ UPGRADE\n" .. slotData.upgradeCost
				upgText.Font = Enum.Font.GothamBold
				upgText.TextSize = 11
				upgText.TextColor3 = Color3.fromRGB(255, 255, 255)
				upgText.BackgroundTransparency = 1
				upgText.Size = UDim2.new(1, 0, 1, 0)
				upgText.TextXAlignment = Enum.TextXAlignment.Center
				upgText.Parent = upgradeBtn

				-- Hover
				upgradeBtn.MouseEnter:Connect(function()
					TweenService:Create(upgradeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(80, 150, 255)}):Play()
				end)
				upgradeBtn.MouseLeave:Connect(function()
					TweenService:Create(upgradeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(50, 100, 255)}):Play()
				end)

				-- Клик
				local fn = slotData.floorName
				local sn = slotData.slotName
				upgradeBtn.MouseButton1Click:Connect(function()
					RequestSlotUpgrade:FireServer(fn, sn)
					upgText.Text = "⏳ Send"
					task.delay(1.5, function()
						if upgText and upgText.Parent then
							upgText.Text = "⬆ UPGRADE\n" .. slotData.upgradeCost
						end
					end)
				end)
			end
		end
	end

	-- Если ничего нет
	if #floors == 0 then
		local emptyNotice = Instance.new("TextLabel")
		emptyNotice.Text = "База не найдена\nили все слоты пусты"
		emptyNotice.Font = Enum.Font.Gotham
		emptyNotice.TextSize = 14
		emptyNotice.TextColor3 = Color3.fromRGB(100, 120, 180)
		emptyNotice.BackgroundTransparency = 1
		emptyNotice.Size = UDim2.new(1, 0, 0, 60)
		emptyNotice.TextXAlignment = Enum.TextXAlignment.Center
		emptyNotice.Parent = CurrentScrollFrame
	end
end

-- ══════════════════════════════════════════
--  ПОСТРОЕНИЕ GUI
-- ══════════════════════════════════════════

local function buildGUI(floors)
	-- Удаляем старый если есть
	if PetBaseGUI then PetBaseGUI:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name          = "PetBaseGUI"
	screenGui.ResetOnSpawn  = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent        = LocalPlayer.PlayerGui

	PetBaseGUI = screenGui  -- ← сохраняем ссылку

	-- ── Главный фрейм ──────────────────────────────────────────
	local MAIN_W, MAIN_H = 520, 560
	local main = Instance.new("Frame")
	main.Name            = "Main"
	main.Size            = UDim2.new(0, MAIN_W, 0, MAIN_H)
	main.Position        = UDim2.new(0.5, -MAIN_W/2, 0.5, -MAIN_H/2)
	main.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
	main.BorderSizePixel = 0
	main.ClipsDescendants = true
	main.Parent          = screenGui

	-- Скруглённые углы
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = main

	-- Градиентная рамка
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 120, 255)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.4
	stroke.Parent = main

	-- Фоновый градиент
	local bgGrad = Instance.new("UIGradient")
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(12, 14, 28)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(8,  10, 20)),
	})
	bgGrad.Rotation = 135
	bgGrad.Parent = main

	-- ── Шапка ──────────────────────────────────────────────────
	local header = Instance.new("Frame")
	header.Name            = "Header"
	header.Size            = UDim2.new(1, 0, 0, 52)
	header.BackgroundColor3 = Color3.fromRGB(20, 24, 44)
	header.BorderSizePixel = 0
	header.Parent          = main

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 14)
	headerCorner.Parent = header

	-- Нижние углы шапки — прямые
	local headerFix = Instance.new("Frame")
	headerFix.Size  = UDim2.new(1, 0, 0, 14)
	headerFix.Position = UDim2.new(0, 0, 1, -14)
	headerFix.BackgroundColor3 = Color3.fromRGB(20, 24, 44)
	headerFix.BorderSizePixel = 0
	headerFix.Parent = header

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = "🐾  BASE PETS"
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Color3.fromRGB(210, 225, 255)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, -110, 1, 0)
	titleLabel.Position = UDim2.new(0, 16, 0, 0)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = header

	-- Кнопка свернуть
	local minimizeBtn = Instance.new("TextButton")
	minimizeBtn.Text = "—"
	minimizeBtn.Font = Enum.Font.GothamBold
	minimizeBtn.TextSize = 16
	minimizeBtn.TextColor3 = Color3.fromRGB(130, 180, 255)
	minimizeBtn.BackgroundColor3 = Color3.fromRGB(30, 36, 60)
	minimizeBtn.Size = UDim2.new(0, 34, 0, 34)
	minimizeBtn.Position = UDim2.new(1, -56, 0.5, -17)
	minimizeBtn.BorderSizePixel = 0
	minimizeBtn.Parent = header
	Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 8)

	-- Кнопка закрыть
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 15
	closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 25)
	closeBtn.Size = UDim2.new(0, 34, 0, 34)
	closeBtn.Position = UDim2.new(1, -14, 0.5, -17)
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = header
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

	-- ── Счётчик / статус строка ────────────────────────────────
	local statusBar = Instance.new("Frame")
	statusBar.Size = UDim2.new(1, -24, 0, 28)
	statusBar.Position = UDim2.new(0, 12, 0, 58)
	statusBar.BackgroundColor3 = Color3.fromRGB(20, 26, 46)
	statusBar.BorderSizePixel = 0
	statusBar.Parent = main
	Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 8)

	local totalPets = 0
	for _, f in ipairs(floors) do
		for _, s in ipairs(f.slots) do
			if s.pet then totalPets += 1 end
		end
	end

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Text = string.format("📊  %d Floors  •  %d pets found", #floors, totalPets)
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 12
	statusLabel.TextColor3 = Color3.fromRGB(100, 140, 220)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Size = UDim2.new(1, -12, 1, 0)
	statusLabel.Position = UDim2.new(0, 10, 0, 0)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = statusBar

	-- ── Прокручиваемая область ──────────────────────────────────
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name              = "ScrollFrame"
	scrollFrame.Size              = UDim2.new(1, -16, 1, -100)
	scrollFrame.Position          = UDim2.new(0, 8, 0, 94)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel   = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
	scrollFrame.CanvasSize        = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent            = main

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding   = UDim.new(0, 10)
	listLayout.Parent    = scrollFrame

	local scrollPad = Instance.new("UIPadding")
	scrollPad.PaddingTop    = UDim.new(0, 4)
	scrollPad.PaddingBottom = UDim.new(0, 10)
	scrollPad.PaddingLeft   = UDim.new(0, 4)
	scrollPad.PaddingRight  = UDim.new(0, 4)
	scrollPad.Parent        = scrollFrame
	
	CurrentScrollFrame = scrollFrame

	-- ── Карточки по этажам ─────────────────────────────────────
	for fi, floorData in ipairs(floors) do
		-- Заголовок этажа
		local floorHeader = Instance.new("Frame")
		floorHeader.Size = UDim2.new(1, 0, 0, 32)
		floorHeader.BackgroundColor3 = Color3.fromRGB(30, 38, 68)
		floorHeader.BorderSizePixel = 0
		floorHeader.LayoutOrder = fi * 100
		floorHeader.Parent = scrollFrame
		Instance.new("UICorner", floorHeader).CornerRadius = UDim.new(0, 8)

		local floorGrad = Instance.new("UIGradient")
		floorGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 60, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 30, 65)),
		})
		floorGrad.Rotation = 0
		floorGrad.Parent = floorHeader

		local floorLabel = Instance.new("TextLabel")
		floorLabel.Text = "🏢  " .. floorData.name:upper()
		floorLabel.Font = Enum.Font.GothamBold
		floorLabel.TextSize = 13
		floorLabel.TextColor3 = Color3.fromRGB(160, 200, 255)
		floorLabel.BackgroundTransparency = 1
		floorLabel.Size = UDim2.new(1, -16, 1, 0)
		floorLabel.Position = UDim2.new(0, 12, 0, 0)
		floorLabel.TextXAlignment = Enum.TextXAlignment.Left
		floorLabel.Parent = floorHeader

		-- Карточки слотов
		for si, slotData in ipairs(floorData.slots) do
			local card = Instance.new("Frame")
			card.Size            = UDim2.new(1, 0, 0, 90)
			card.BackgroundColor3 = Color3.fromRGB(18, 22, 38)
			card.BorderSizePixel = 0
			card.LayoutOrder     = fi * 100 + si
			card.Parent          = scrollFrame
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

			-- Рамка карточки
			local cardStroke = Instance.new("UIStroke")
			cardStroke.Color = Color3.fromRGB(40, 55, 100)
			cardStroke.Thickness = 1
			cardStroke.Transparency = 0.5
			cardStroke.Parent = card

			-- Левая цветная полоска (редкость)
			local accent = Instance.new("Frame")
			accent.Size = UDim2.new(0, 4, 1, -16)
			accent.Position = UDim2.new(0, 0, 0.5, 0)
			accent.AnchorPoint = Vector2.new(0, 0.5)
			accent.BorderSizePixel = 0
			accent.BackgroundColor3 = slotData.pet
				and rarityColor(slotData.pet.rarity)
				or  Color3.fromRGB(60, 70, 100)
			accent.Parent = card
			Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 4)

			local pet = slotData.pet

			if pet then
				-- Картинка пета
				local petImg = Instance.new("ImageLabel")
				petImg.Size   = UDim2.new(0, 70, 0, 70)
				petImg.Position = UDim2.new(0, 14, 0.5, 0)
				petImg.AnchorPoint = Vector2.new(0, 0.5)
				petImg.BackgroundColor3 = Color3.fromRGB(25, 30, 52)
				petImg.BorderSizePixel = 0
				petImg.Image = pet.imageId
				petImg.ScaleType = Enum.ScaleType.Fit
				petImg.Parent = card
				Instance.new("UICorner", petImg).CornerRadius = UDim.new(0, 8)

				-- Имя
				local nameLabel = Instance.new("TextLabel")
				nameLabel.Text = pet.name
				nameLabel.Font = Enum.Font.GothamBold
				nameLabel.TextSize = 14
				nameLabel.TextColor3 = Color3.fromRGB(230, 240, 255)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Size = UDim2.new(0, 200, 0, 20)
				nameLabel.Position = UDim2.new(0, 96, 0, 12)
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
				nameLabel.Parent = card

				-- Редкость (бейдж)
				if pet.rarity ~= "" then
					local rarBadge = Instance.new("Frame")
					rarBadge.Size = UDim2.new(0, 0, 0, 18)
					rarBadge.AutomaticSize = Enum.AutomaticSize.X
					rarBadge.Position = UDim2.new(0, 96, 0, 34)
					rarBadge.BackgroundColor3 = rarityColor(pet.rarity)
					rarBadge.BorderSizePixel = 0
					rarBadge.Parent = card
					Instance.new("UICorner", rarBadge).CornerRadius = UDim.new(0, 5)

					local rarPad = Instance.new("UIPadding")
					rarPad.PaddingLeft  = UDim.new(0, 6)
					rarPad.PaddingRight = UDim.new(0, 6)
					rarPad.Parent = rarBadge

					local rarLabel = Instance.new("TextLabel")
					rarLabel.Text = pet.rarity
					rarLabel.Font = Enum.Font.GothamBold
					rarLabel.TextSize = 10
					rarLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
					rarLabel.BackgroundTransparency = 1
					rarLabel.Size = UDim2.new(1, 0, 1, 0)
					rarLabel.TextXAlignment = Enum.TextXAlignment.Center
					rarLabel.Parent = rarBadge
				end

				-- Мутация
				if pet.mutation ~= "" and pet.mutation:lower() ~= "none" and pet.mutation ~= "-" then
	local mutLabel = Instance.new("TextLabel")
	mutLabel.Text = "✨ " .. pet.mutation
	mutLabel.Font = Enum.Font.Gotham
	mutLabel.TextSize = 11
	
	-- Ищем цвет в таблице. Проверяем совпадение, приводя всё к нижнему регистру
	local targetColor = DEFAULT_MUTATION_COLOR
	for mutName, color in pairs(MUTATION_COLORS) do
		if mutName:lower() == pet.mutation:lower() then
			targetColor = color
			break
		end
	end
	
	mutLabel.TextColor3 = targetColor
	mutLabel.BackgroundTransparency = 1
	mutLabel.Size = UDim2.new(0, 150, 0, 16)
	mutLabel.Position = UDim2.new(0, 96, 0, 55)
	mutLabel.TextXAlignment = Enum.TextXAlignment.Left
	mutLabel.Parent = card
end

				-- Заработок
				if pet.earnings ~= "" then
					local earnLabel = Instance.new("TextLabel")
					earnLabel.Text = "💰 " .. pet.earnings
					earnLabel.Font = Enum.Font.Gotham
					earnLabel.TextSize = 11
					earnLabel.TextColor3 = Color3.fromRGB(255, 210, 80)
					earnLabel.BackgroundTransparency = 1
					earnLabel.Size = UDim2.new(0, 150, 0, 16)
					earnLabel.Position = UDim2.new(0, 96, 0, 70)
					earnLabel.TextXAlignment = Enum.TextXAlignment.Left
					earnLabel.Parent = card
				end
			else
				-- Слот без пета (только апгрейд)
				local emptyLabel = Instance.new("TextLabel")
				emptyLabel.Text = "🔒  Empty Slot"
				emptyLabel.Font = Enum.Font.Gotham
				emptyLabel.TextSize = 13
				emptyLabel.TextColor3 = Color3.fromRGB(100, 110, 150)
				emptyLabel.BackgroundTransparency = 1
				emptyLabel.Size = UDim2.new(0, 220, 0, 26)
				emptyLabel.Position = UDim2.new(0, 20, 0.5, -13)
				emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
				emptyLabel.Parent = card
			end

			-- Кнопка апгрейда (если есть стоимость и флур/слот данные)
			if slotData.upgradeCost and slotData.floorName ~= "" and slotData.slotName ~= "" then
				local upgradeBtn = Instance.new("TextButton")
				upgradeBtn.Size  = UDim2.new(0, 110, 0, 36)
				upgradeBtn.Position = UDim2.new(1, -120, 0.5, -18)
				upgradeBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 255)
				upgradeBtn.BorderSizePixel = 0
				upgradeBtn.Text = ""
				upgradeBtn.Parent = card
				Instance.new("UICorner", upgradeBtn).CornerRadius = UDim.new(0, 9)

				local upgGrad = Instance.new("UIGradient")
				upgGrad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 130, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(30,  70, 220)),
				})
				upgGrad.Rotation = 90
				upgGrad.Parent = upgradeBtn

				local upgText = Instance.new("TextLabel")
				upgText.Text = "⬆ UPGRADE\n" .. slotData.upgradeCost
				upgText.Font = Enum.Font.GothamBold
				upgText.TextSize = 11
				upgText.TextColor3 = Color3.fromRGB(255, 255, 255)
				upgText.BackgroundTransparency = 1
				upgText.Size = UDim2.new(1, 0, 1, 0)
				upgText.TextXAlignment = Enum.TextXAlignment.Center
				upgText.Parent = upgradeBtn

				-- Hover эффекты
				upgradeBtn.MouseEnter:Connect(function()
					TweenService:Create(upgradeBtn, TweenInfo.new(0.15), {
						BackgroundColor3 = Color3.fromRGB(80, 150, 255)
					}):Play()
				end)
				upgradeBtn.MouseLeave:Connect(function()
					TweenService:Create(upgradeBtn, TweenInfo.new(0.15), {
						BackgroundColor3 = Color3.fromRGB(50, 100, 255)
					}):Play()
				end)

				-- Клик — апгрейд
				local fn = slotData.floorName
				local sn = slotData.slotName
				upgradeBtn.MouseButton1Click:Connect(function()
					RequestSlotUpgrade:FireServer(fn, sn)
					-- Визуальный фидбек
					upgText.Text = "⏳ Send"
					task.delay(1.5, function()
						if upgText and upgText.Parent then
							upgText.Text = "⬆ UPGRADE\n" .. slotData.upgradeCost
						end
					end)
				end)
			end
		end
	end

	-- Если пусто
	if #floors == 0 then
		local emptyNotice = Instance.new("TextLabel")
		emptyNotice.Text = "База не найдена\nили все слоты пусты"
		emptyNotice.Font = Enum.Font.Gotham
		emptyNotice.TextSize = 14
		emptyNotice.TextColor3 = Color3.fromRGB(100, 120, 180)
		emptyNotice.BackgroundTransparency = 1
		emptyNotice.Size = UDim2.new(1, 0, 0, 60)
		emptyNotice.TextXAlignment = Enum.TextXAlignment.Center
		emptyNotice.Parent = scrollFrame
	end

	-- ── Кнопка закрыть ──────────────────────────────────────────
	closeBtn.MouseButton1Click:Connect(function()
		TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, MAIN_W, 0, 0),
			Position = UDim2.new(0.5, -MAIN_W/2, 0.5, 0),
		}):Play()
		task.delay(0.3, function() screenGui:Destroy() end)
	end)

	-- ── Кнопка свернуть ─────────────────────────────────────────
	local minimized = false
	minimizeBtn.MouseButton1Click:Connect(function()
		if not minimized then
			TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
				Size = UDim2.new(0, MAIN_W, 0, 52),
			}):Play()
			minimized = true
			minimizeBtn.Text = "—"
		else
			TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
				Size = UDim2.new(0, MAIN_W, 0, MAIN_H),
			}):Play()
			minimized = false
			minimizeBtn.Text = "—"
		end
	end)

	-- ── Перетаскивание ──────────────────────────────────────────
	local dragging, dragStart, startPos
	header.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			dragging  = true
			dragStart = inp.Position
			startPos  = main.Position
		end
	end)
	header.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
		              or inp.UserInputType == Enum.UserInputType.Touch) then
			local delta = inp.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
	header.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	-- Анимация появления
	main.Size = UDim2.new(0, MAIN_W, 0, 0)
	main.Position = UDim2.new(0.5, -MAIN_W/2, 0.5, 0)
	TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, MAIN_W, 0, MAIN_H),
		Position = UDim2.new(0.5, -MAIN_W/2, 0.5, -MAIN_H/2),
	}):Play()
end

-- ══════════════════════════════════════════
--  ТОЧКА ВХОДА
-- ══════════════════════════════════════════

task.spawn(function()
	local plotName = "Plot_" .. LocalPlayer.Name
	local plot = workspace:WaitForChild(plotName, 15)
	if not plot then
		warn("[PetBaseGUI] No Plot: " .. plotName)
		return
	end

	local firstFloors = collectBaseData(plot)
	buildGUI(firstFloors)

	-- Автообновление каждые 5 секунд
	while PetBaseGUI and PetBaseGUI.Parent do
		task.wait(5)
		local newFloors = collectBaseData(plot)
		updateGUISlots(newFloors)
	end
end)

return {}
