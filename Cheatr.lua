local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local config = {
    savedPosition = nil,
    originalCameraCFrame = nil,
    cameraFollowConnection = nil,
    flying = false,
    flyVelocity = 50,
    standing = false,
    attachMotor = nil,
    targetPlayerName = nil,
    controlledPlayer = nil,
    originalControl = nil,
    islandPart = nil,
    isOnIsland = false,
    afkConnection = nil,
    jumpPower = 50,
    targetPlayer = nil,
    originalLightingSettings = nil, -- Переменная для хранения начальных настроек освещения
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

-- Функция отправки сообщения в чат от имени всех игроков
local function sayToAll(message)
    local ChatService = game:GetService("Chat")
    for _, player in ipairs(Players:GetPlayers()) do
        local success, err = pcall(function()
            ChatService:Chat(player.Character.HumanoidRootPart, message, Enum.ChatColor.White)
        end)
        
        if not success then
            warn("Failed to send chat message from player " .. player.Name .. ": " .. err)
        end
    end
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
        config.savedPosition = character.HumanoidRootPart.CFrame
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
            character.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame
        end
    end
end

-- Функция создания острова
local function createIsland()
    if not config.islandPart then
        config.islandPart = Instance.new("Part")
        config.islandPart.Size = Vector3.new(50, 50, 50)
        config.islandPart.Position = Vector3.new(5000, -50, 5000)
        config.islandPart.Anchored = true
        config.islandPart.Parent = Workspace

        wait(2)

        local character = Players.LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            character.HumanoidRootPart.CFrame = config.islandPart.CFrame + Vector3.new(0, 10, 0)
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

        local character = Players.LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            if config.savedPosition then
                character.HumanoidRootPart.CFrame = config.savedPosition
            else
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

-- Функция установки силы прыжка
local function setJumpPower(value)
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        config.jumpPower = value
        character.Humanoid.JumpPower = value
    end
end

-- Функция активации бесконечного прыжка
local function enableJumpPower()
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.Jumping:Connect(function()
            if config.jumpPower > 0 then
                character.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
                character.Humanoid:ChangeState(Enum.HumanoidStateType.Seated)
            end
        end)
    end
end

-- Функция отключения бесконечного прыжка
local function disableJumpPower()
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        config.jumpPower = 0
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
        "f.jump <value> - Set your jump power.",
        "f.afk - Enable AFK mode.",
        "f.reset - Set your health to 0.",
        "f.spectate <player> - Move your camera to the specified player's position.",
        "f.unspectate - Return your camera to its original position.",
        "f.help - Display this help message.",
        "f.say <message> - Send a message to the chat from all players.",
        "f.night - Change the environment to nighttime.",
        "f.light - Return the environment to its initial state."
    }
    local message = table.concat(commands, "\n")
    SendChatMessage(message, Enum.ChatColor.Green)
end

-- Функция телепортации по клику мыши
local function teleportToMouse()
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local mouse = Players.LocalPlayer:GetMouse()
        local targetPosition = mouse.Hit.p + Vector3.new(0, 4, 0) -- Телепортация с небольшим подъемом
        character.HumanoidRootPart.CFrame = CFrame.new(targetPosition)
    end
end

-- Функция сброса здоровья игрока
local function resetHealth()
    local character = Players.LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.Health = 0
    end
end

-- Функция активации режима спекейт
local function spectatePlayer(playerNamePart)
    local targetPlayer = findPlayerByName(playerNamePart)
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        if not config.originalCameraCFrame then
            config.originalCameraCFrame = Workspace.CurrentCamera.CFrame
        end
        Workspace.CurrentCamera.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame
        config.targetPlayer = targetPlayer
    end
end

-- Функция деактивации режима спекейт
local function unspectatePlayer()
    if config.originalCameraCFrame then
        Workspace.CurrentCamera.CFrame = config.originalCameraCFrame
        config.originalCameraCFrame = nil
        config.targetPlayer = nil
    end
end

-- Функция установки ночного времени
local function setNightMode()
    if not config.originalLightingSettings then
        -- Сохраняем начальные настройки освещения
        config.originalLightingSettings = {
            ClockTime = Lighting.ClockTime,
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            Brightness = Lighting.Brightness,
            FogColor = Lighting.FogColor,
            FogEnd = Lighting.FogEnd
        }
    end

    -- Устанавливаем ночные настройки
    Lighting.ClockTime = 0 -- Устанавливаем время суток на 00:00
    Lighting.Ambient = Color3.fromRGB(30, 30, 30) -- Устанавливаем темный амбиент
    Lighting.OutdoorAmbient = Color3.fromRGB(20, 20, 20) -- Устанавливаем темное окружение
    Lighting.Brightness = 2 -- Уменьшаем яркость
    Lighting.FogColor = Color3.fromRGB(0, 0, 0) -- Устанавливаем цвет тумана на черный
    Lighting.FogEnd = 1000 -- Устанавливаем расстояние тумана
end

-- Функция возврата начальных настроек освещения
local function setLightMode()
    if config.originalLightingSettings then
        -- Восстанавливаем начальные настройки освещения
        Lighting.ClockTime = config.originalLightingSettings.ClockTime
        Lighting.Ambient = config.originalLightingSettings.Ambient
        Lighting.OutdoorAmbient = config.originalLightingSettings.OutdoorAmbient
        Lighting.Brightness = config.originalLightingSettings.Brightness
        Lighting.FogColor = config.originalLightingSettings.FogColor
        Lighting.FogEnd = config.originalLightingSettings.FogEnd

        -- Очищаем сохраненные настройки
        config.originalLightingSettings = nil
    end
end

-- Обработчик команд
local function handleCommand(message)
    local args = message:split(" ")
    local cmd = args[1]:lower()
    if cmd == "f.save" or cmd == "f.savepoint" then
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
        SendChatMessage("Island created and player teleported to it.", Enum.ChatColor.Green)
    elseif cmd == "f.back" then
        removeIsland()
        SendChatMessage("Returned to previous position.", Enum.ChatColor.Green)
    elseif cmd == "f.speed" and args[2] then
        local value = tonumber(args[2])
        if value then
            setSpeed(value)
            SendChatMessage("Speed set to " .. value, Enum.ChatColor.Green)
        else
            SendChatMessage("Invalid speed value.", Enum.ChatColor.Red)
        end
    elseif cmd == "f.jump" and args[2] then
        local value = tonumber(args[2])
        if value then
            setJumpPower(value)
            enableJumpPower()
            SendChatMessage("Jump power set to " .. value, Enum.ChatColor.Green)
        else
            SendChatMessage("Invalid jump power value.", Enum.ChatColor.Red)
        end
    elseif cmd == "f.afk" then
        enableAFK()
        SendChatMessage("AFK mode enabled.", Enum.ChatColor.Green)
    elseif cmd == "f.reset" then
        resetHealth()
        SendChatMessage("Player health set to 0.", Enum.ChatColor.Green)
    elseif cmd == "f.spectate" and args[2] then
        spectatePlayer(args[2])
        SendChatMessage("Spectating player " .. args[2], Enum.ChatColor.Green)
    elseif cmd == "f.unspectate" then
        unspectatePlayer()
        SendChatMessage("Stopped spectating.", Enum.ChatColor.Green)
    elseif cmd == "f.say" and args[2] then
        local message = table.concat(args, " ", 2)
        sayToAll(message)
        SendChatMessage("Message sent to all players: " .. message, Enum.ChatColor.Green)
    elseif cmd == "f.night" then
        setNightMode()
        SendChatMessage("Environment changed to nighttime.", Enum.ChatColor.Green)
    elseif cmd == "f.light" then
        setLightMode()
        SendChatMessage("Environment returned to initial state.", Enum.ChatColor.Green)
    elseif cmd == "f.help" then
        displayHelp()
    else
        SendChatMessage("Unknown command. Use 'f.help' for a list of commands.", Enum.ChatColor.Red)
    end
end

-- Подключаем обработчик команд к чату
Players.LocalPlayer.Chatted:Connect(function(message)
    handleCommand(message)
end)

-- Подключаем обработчик нажатия клавиши Z для телепортации к курсору мыши
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.KeyCode == Enum.KeyCode.Z then
        teleportToMouse()
    end
end)
