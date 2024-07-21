local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local config = {
    savedPosition = nil,
    originalCameraCFrame = nil,
    cameraFollowConnection = nil,
    flying = false,
    flyVelocity = 50, -- Скорость полета
    standing = false, -- Переменная для отслеживания состояния стояния
    attachMotor = nil,
    targetPlayerName = nil,
    controlledPlayer = nil, -- Игрок, управление которым взято на себя
    originalControl = nil, -- Оригинальное управление
    islandPart = nil, -- Переменная для хранения острова
    isOnIsland = false, -- Переменная для отслеживания нахождения на острове
    afkConnection = nil, -- Переменная для хранения подключения к событию
    noclipConnection = nil, -- Переменная для хранения состояния noclip
    invisibilityConnection = nil, -- Переменная для хранения состояния невидимости
    followConnection = nil, -- Переменная для хранения подключения к событию следования
    infJumpActive = false -- Переменная для отслеживания состояния бесконечного прыжка
}

-- Функция поиска игрока по части имени
local function findPlayerByName(namePart)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower():find(namePart:lower()) then
            return player
        end
    end
    return nil
end

-- Функция отправки сообщения в чат
local function SendChatMessage(message, color)
    local ChatService = game:GetService("Chat")
    local success, err = pcall(function()
        ChatService:Chat(Players.LocalPlayer.Character.HumanoidRootPart, message, color)
    end)
    
    if not success then
        warn("Failed to send chat message: " .. err)
    end
end

-- Функция сохранения текущей позиции
local function savePoint()
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        config.savedPosition = character.HumanoidRootPart.CFrame -- Сохраняем CFrame для точности
    end
end

-- Функция возврата на сохраненную позицию
local function comeBack()
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") and config.savedPosition then
        character.HumanoidRootPart.CFrame = config.savedPosition
    end
end

-- Функция телепортации к игроку
local function teleportToPlayer(playerNamePart)
    local targetPlayer = findPlayerByName(playerNamePart)
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local character = Players.LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            -- Телепортируем локального игрока к целевому игроку
            character.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame
        end
    end
end

-- Функция создания острова
local function createIsland()
    if not config.islandPart then
        config.islandPart = Instance.new("Part")
        config.islandPart.Size = Vector3.new(50, 50, 50) -- Размер острова
        config.islandPart.Position = Vector3.new(5000, -50, 5000) -- Позиция острова за пределами карты
        config.islandPart.Anchored = true
        config.islandPart.Parent = Workspace

        -- Задержка перед телепортацией
        wait(2)

        local character = Players.LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            character.HumanoidRootPart.CFrame = config.islandPart.CFrame + Vector3.new(0, 10, 0) -- Телепортируем игрока на остров
            config.isOnIsland = true
        end
    end
end

-- Функция удаления острова
local function removeIsland()
    if config.islandPart then
        config.islandPart:Destroy()
        config.islandPart = nil
        config.isOnIsland = false

        -- Телепортируем игрока обратно на сохраненную позицию или исходную позицию
        local character = Players.LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            if config.savedPosition then
                character.HumanoidRootPart.CFrame = config.savedPosition
            else
                -- Если сохраненная позиция отсутствует, можно телепортировать игрока на стандартную позицию
                character.HumanoidRootPart.CFrame = CFrame.new(0, 10, 0)
            end
        end
    end
end

-- Функция установки скорости
local function setSpeed(value)
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.WalkSpeed = value
    end
end

-- Функция установки силы прыжка (переименованная функция)
local function setInfJump(value)
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.JumpPower = value
    end
end

-- Функция активации бесконечного прыжка
local function enableInfJump()
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        config.infJumpActive = true
        character.Humanoid.Jumping:Connect(function()
            if config.infJumpActive then
                character.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
                character.Humanoid:ChangeState(Enum.HumanoidStateType.Seated)
            end
        end)
    end
end

-- Функция отключения бесконечного прыжка
local function disableInfJump()
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        config.infJumpActive = false
    end
end

-- Функция включения режима Noclip
local function enableNoclip()
    local character = Players.LocalPlayer.Character
    if character then
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
        config.noclipConnection = RunService.Stepped:Connect(function()
            for _, part in ipairs(character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    end
end

-- Функция отключения режима Noclip
local function disableNoclip()
    local character = Players.LocalPlayer.Character
    if character then
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
        if config.noclipConnection then
            config.noclipConnection:Disconnect()
            config.noclipConnection = nil
        end
    end
end

-- Функция активации невидимости
local function enableInvisibility()
    local character = Players.LocalPlayer.Character
    if character then
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = 1
                part.CanCollide = false
            end
        end
        config.invisibilityConnection = RunService.RenderStepped:Connect(function()
            for _, part in ipairs(character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Transparency = 1
                    part.CanCollide = false
                end
            end
        end)
    end
end

-- Функция деактивации невидимости
local function disableInvisibility()
    local character = Players.LocalPlayer.Character
    if character then
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
                part.CanCollide = true
            end
        end
        if config.invisibilityConnection then
            config.invisibilityConnection:Disconnect()
            config.invisibilityConnection = nil
        end
    end
end

-- Функция активации режима AFK
local function enableAFK()
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        config.afkConnection = RunService.RenderStepped:Connect(function()
            character.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end)
    end
end

-- Функция деактивации режима AFK
local function disableAFK()
    if config.afkConnection then
        config.afkConnection:Disconnect()
        config.afkConnection = nil
    end
end

-- Функция отображения списка команд
local function displayHelp()
    local commands = {
        "f.save - Save your current position.",
        "f.comeback - Return to the saved position.",
        "f.tp <player> - Teleport to the specified player.",
        "f.island - Create an island and teleport to it.",
        "f.back - Remove the island and return to your previous position.",
        "f.speed <value> - Set your walk speed.",
        "f.infjump <value> - Set your jump power and enable infinite jump.",
        "f.noclip - Enable noclip mode.",
        "f.invis - Enable invisibility.",
        "f.visible - Disable invisibility.",
        "f.afk - Enable AFK mode.",
        "f.help - Display this help message.",
        "f.follow <player> - Follow the specified player.",
        "f.unfollow - Stop following."
    }
    local message = table.concat(commands, "\n")
    SendChatMessage(message, Enum.ChatColor.Green)
end

-- Функция следования за игроком
local function startFollowing(playerNamePart)
    local targetPlayer = findPlayerByName(playerNamePart)
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        if config.followConnection then
            config.followConnection:Disconnect()
        end

        config.targetPlayerName = targetPlayer.Name
        config.followConnection = RunService.RenderStepped:Connect(function()
            local character = Players.LocalPlayer.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                character.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame
            end
        end)
        SendChatMessage("Now following " .. targetPlayer.Name, Enum.ChatColor.Yellow)
    else
        SendChatMessage("Player not found.", Enum.ChatColor.Red)
    end
end

-- Функция прекращения следования за игроком
local function stopFollowing()
    if config.followConnection then
        config.followConnection:Disconnect()
        config.followConnection = nil
        config.targetPlayerName = nil
        SendChatMessage("Stopped following.", Enum.ChatColor.Yellow)
    else
        SendChatMessage("Not currently following anyone.", Enum.ChatColor.Red)
    end
end

-- Обработчик команд
local function handleCommand(command)
    local args = command:split(" ")
    local cmd = args[1]
    
    if cmd == "f.save" then
        savePoint()
        SendChatMessage("Position saved.", Enum.ChatColor.Green)
    elseif cmd == "f.comeback" then
        comeBack()
        SendChatMessage("Returned to saved position.", Enum.ChatColor.Green)
    elseif cmd == "f.tp" and args[2] then
        teleportToPlayer(args[2])
        SendChatMessage("Teleported to " .. args[2], Enum.ChatColor.Green)
    elseif cmd == "f.island" then
        createIsland()
        SendChatMessage("Island created.", Enum.ChatColor.Green)
    elseif cmd == "f.back" then
        removeIsland()
        SendChatMessage("Island removed and returned to saved position.", Enum.ChatColor.Green)
    elseif cmd == "f.speed" and args[2] then
        local value = tonumber(args[2])
        if value then
            setSpeed(value)
            SendChatMessage("Speed set to " .. value, Enum.ChatColor.Green)
        else
            SendChatMessage("Invalid speed value.", Enum.ChatColor.Red)
        end
    elseif cmd == "f.infjump" and args[2] then
        local value = tonumber(args[2])
        if value then
            setInfJump(value)
            enableInfJump()
            SendChatMessage("Infinite jump enabled with jump power " .. value, Enum.ChatColor.Green)
        else
            SendChatMessage("Invalid jump power value.", Enum.ChatColor.Red)
        end
    elseif cmd == "f.noclip" then
        enableNoclip()
        SendChatMessage("Noclip mode enabled.", Enum.ChatColor.Green)
    elseif cmd == "f.invis" then
        enableInvisibility()
        SendChatMessage("Invisibility enabled.", Enum.ChatColor.Green)
    elseif cmd == "f.visible" then
        disableInvisibility()
        SendChatMessage("Invisibility disabled.", Enum.ChatColor.Green)
    elseif cmd == "f.afk" then
        enableAFK()
        SendChatMessage("AFK mode enabled.", Enum.ChatColor.Green)
    elseif cmd == "f.help" then
        displayHelp()
    elseif cmd == "f.follow" and args[2] then
        startFollowing(args[2])
    elseif cmd == "f.unfollow" then
        stopFollowing()
    else
        SendChatMessage("Unknown command. Use 'f.help' for a list of commands.", Enum.ChatColor.Red)
    end
end

-- Подключаем обработчик команд к чату
Players.LocalPlayer.Chatted:Connect(function(message)
    handleCommand(message)
end)
