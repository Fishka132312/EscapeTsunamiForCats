local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Frame = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("GUI"):WaitForChild("Frames"):WaitForChild("Index")
local Scrolling = Frame:WaitForChild("Scrolling")

-- Запускаем бесконечный, но ОЧЕНЬ легкий цикл
task.spawn(function()
    while true do
        local items = Scrolling:GetChildren()
        for i = 1, #items do
            local itemFrame = items[i]
            if itemFrame:IsA("Frame") then
                local image = itemFrame:FindFirstChild("Image")
                if image and image:IsA("ImageLabel") and image.ImageTransparency ~= 0 then
                    -- Насильно открываем картинку
                    image.ImageColor3 = Color3.fromRGB(255, 255, 255)
                    image.ImageTransparency = 0
                end
            end
            -- Раз в 10 предметов делаем микро-паузу, чтобы у тебя ВООБЩЕ не лагало
            if i % 10 == 0 then
                task.wait()
            end
        end
        task.wait(1) -- Проверяем заново раз в секунду
    end
end)
