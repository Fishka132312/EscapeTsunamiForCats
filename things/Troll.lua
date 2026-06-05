local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- Настройки задержек (подкрути, если кикает за телепорт)
local TELEPORT_WAIT = 0.25 -- Время ожидания после ТП перед сбором
local PROMPT_WAIT = 0.1   -- Время на активацию промпта
local SAFE_ZONE_WAIT = 1.0 -- Сколько стоять в SafeZone, чтобы петы сдались

-- Нужные редкости (True = собираем, False = игнорируем)
local TARGET_RARITIES = {
    Common = true,
    Uncommon = true,
    Rare = true,
    Epic = true,
    -- Остальные отключены, чтобы не трогать легендарок и т.д.
    Legendary = false,
    Mythical = false,
    OG = false,
    SpecialItemSpawn = false
}

-- Папка, где спавнятся петы
local ItemSpawners = Workspace:WaitForChild("ItemSpawners")

-- 1. ФУНКЦИЯ ПОЛУЧЕНИЯ МАКСИМАЛЬНОГО ЛИМИТА ИЗ UI
local function getMaxCarry()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local carryFrame = playerGui:WaitForChild("GUI", 5):WaitForChild("Frames", 5):WaitForChild("Carry", 5):WaitForChild("Scrolling", 5)
    
    if carryFrame then
        local upgradeTemplate = carryFrame:FindFirstChild("CarryUpgrade")
        if upgradeTemplate then
            local stats = upgradeTemplate:FindFirstChild("Stats")
            if stats and stats:FindFirstChild("Before") and stats.Before:FindFirstChild("Text") then
                local text = stats.Before.Text
                -- Вытаскиваем только цифры из текста (например "6" из "6/6" или "6 Pets")
                local num = text:match("%d+")
                if num then
                    return tonumber(num)
                end
            end
        end
    end
    print("[AutoFarm] Не удалось прочитать UI лимита, ставим стандартный: 6")
    return 6 -- Дефолтное значение, если UI не загрузился
end

-- 2. ФУНКЦИЯ АКТИВАЦИИ PROXIMITY PROMPT
local function firePrompt(prompt)
    if prompt then
        -- Виртуальное нажатие для обхода защиты некоторых игр
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0,0))
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration + 0.05)
        prompt:InputHoldEnd()
    end
end

-- 3. ФУНКЦИЯ СБОРА ДОСТУПНЫХ ПЕТОВ
local function getAvailablePets()
    local pets = {}
    
    for _, folderName in ipairs({"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "OG", "SpecialItemSpawn"}) do
        if TARGET_RARITIES[folderName] then
            local folder = ItemSpawners:FindFirstChild(folderName)
            if folder then
                for _, pet in ipairs(folder:GetChildren()) do
                    local head = pet:FindFirstChild("Head")
                    local prompt = head and head:FindFirstChildOfClass("ProximityPrompt")
                    
                    if head and prompt then
                        table.insert(pets, {
                            petObject = pet,
                            head = head,
                            prompt = prompt
                        })
                    end
                end
            end
        end
    end
    return pets
end

-- 4. ОСНОВНОЙ ЦИКЛ АВТОФАРМА
print("[AutoFarm] Скрипт запущен!")

while true do
    local maxCarry = getMaxCarry()
    local currentCarried = 0
    
    local availablePets = getAvailablePets()
    
    if #availablePets > 0 then
        print(string.size("[AutoFarm] Найдено петов для сбора: " .. #availablePets))
        
        for _, petData in ipairs(availablePets) do
            -- Проверяем, не заполнилась ли сумка на этом шаге
            if currentCarried >= maxCarry then 
                break 
            end
            
            -- Проверяем существование персонажа
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local hrp = character:WaitForChild("HumanoidRootPart", 5)
            
            -- Если пет всё еще существует на карте
            if petData.petObject and petData.petObject.Parent and hrp then
                print("[AutoFarm] ТП к пету: " .. petData.petObject.Name)
                
                -- Телепортируемся прямо к Head пета
                hrp.CFrame = petData.head.CFrame + Vector3.new(0, 2, 0) -- Чуть выше головы, чтобы не провалиться
                task.wait(TELEPORT_WAIT)
                
                -- Собираем
                firePrompt(petData.prompt)
                task.wait(PROMPT_WAIT)
                
                currentCarried = currentCarried + 1
            end
        end
    else
        print("[AutoFarm] Нужных петов на карте пока нет. Ждем 5 секунд...")
        task.wait(5)
    end
    
    -- Когда собрали максимум ИЛИ петы на карте кончились, летим разгружаться
    if currentCarried > 0 then
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local safeZone = Workspace:FindFirstChild("SafeZone") or Workspace:FindFirstChild("Safe Zone") -- Ищет SafeZone в Workspace
        
        if hrp and safeZone then
            print("[AutoFarm] Сумка заполнена ("..currentCarried.."/"..maxCarry.."). Телепорт в SafeZone...")
            
            -- Перемещаем в SafeZone (скрипт ищет парт с таким именем)
            hrp.CFrame = safeZone.CFrame + Vector3.new(0, 3, 0)
            task.wait(SAFE_ZONE_WAIT) -- Ждем разгрузки сумки в зоне
        else
            warn("[AutoFarm] Ошибка: Не найден объект SafeZone в Workspace! Добавь его или переименуй парт базы.")
            task.wait(2)
        end
    end
    
    task.wait(0.5) -- Небольшая пауза между кругами фармера
end
