--[[
    client/utils.lua
    Utilidades: fuel, sonidos, texto, visibilidad
--]]

while not FrameworkBridge do Wait(100) end

-- Sonidos
function PlayInteractionSound()
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end

function PlayEnterZoneSound()
    PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end

-- Fuel
function GetFuelLevel(vehicle)
    if Config.FuelSystem == 'LegacyFuel' then
        return exports['LegacyFuel']:GetFuel(vehicle)
    elseif Config.FuelSystem == 'ox_fuel' then
        return Entity(vehicle).state.fuel or 100
    elseif Config.FuelSystem == 'esx_fuel' then
        return GetVehicleFuelLevel(vehicle)
    elseif Config.FuelSystem == 'native' then
        return GetVehicleFuelLevel(vehicle)
    end
    -- Fallback: intentar nativo de GTA
    return GetVehicleFuelLevel(vehicle)
end

function SetFuelLevel(vehicle, fuel)
    if Config.FuelSystem == 'LegacyFuel' then
        local success = pcall(function()
            exports['LegacyFuel']:SetFuel(vehicle, fuel)
        end)
        if not success then
            local success2 = pcall(function()
                exports.LegacyFuel:SetFuel(vehicle, fuel)
            end)
            if not success2 then
                SetVehicleFuelLevel(vehicle, fuel + 0.0)
            end
        end
    elseif Config.FuelSystem == 'ox_fuel' then
        Entity(vehicle).state.fuel = fuel
    elseif Config.FuelSystem == 'native' then
        SetVehicleFuelLevel(vehicle, fuel + 0.0)
    else
        SetVehicleFuelLevel(vehicle, fuel + 0.0)
    end
end

-- ============================================
-- BLIPS
-- ============================================

function CreateGarageBlips()
    -- Limpiar blips existentes
    for _, blip in pairs(garageBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    garageBlips = {}
    
    -- NOTA: Los blips de garajes públicos se manejan en garage_markers.lua 
    -- con CreatePublicGarageBlips() que lee de la base de datos
    
    -- NOTA: Los blips de impounds se manejan en impound.lua junto con los NPCs
end

-- ============================================
-- LINE OF SIGHT CHECK (Verificación de paredes)
-- ============================================

function HasLineOfSight(from, to, isInVehicle)
    -- Si está en vehículo, no verificar línea de visión para permitir guardar desde distancia
    if isInVehicle then
        return true
    end
    
    -- Solo verificar paredes si la distancia es mayor a 3 metros
    -- Para distancias cortas, asumimos que hay línea de visión
    local dist = #(from - to)
    if dist < 3.5 then
        return true
    end
    
    -- Raycast desde el jugador hacia el punto del garaje
    -- Flags: 1 = Mundo (edificios/paredes), ignoramos objetos pequeños
    local rayHandle = StartShapeTestRay(
        from.x, from.y, from.z + 1.0,  -- Desde la altura del pecho del jugador
        to.x, to.y, to.z + 1.0,        -- Hacia la altura del marker
        1,                              -- Solo colisión con mundo (paredes/edificios)
        PlayerPedId(),                  -- Ignorar al jugador
        0
    )
    local _, hit, _, _, _ = GetShapeTestResult(rayHandle)
    
    -- Si hit es true, hay una pared bloqueando
    return not hit
end

-- ============================================
-- STYLED 3D TEXT
-- ============================================

function DrawStyledText3D(x, y, z, text, scale, r, g, b, a)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z + 1.0)
    
    if not onScreen then return end
    
    local camCoords = GetGameplayCamCoord()
    local dist = #(vector3(x, y, z) - camCoords)
    
    scale = (scale or 0.35) * (1 / dist) * 2.0
    if scale > 0.5 then scale = 0.5 end
    if scale < 0.15 then scale = 0.15 end
    
    -- Fondo semi-transparente
    SetTextFont(4) -- Condensed font
    SetTextProportional(true)
    SetTextScale(scale, scale)
    SetTextColour(r or 52, g or 235, b or 216, a or 220)
    SetTextDropshadow(2, 0, 0, 0, 200)
    SetTextEdge(1, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(_x, _y)
end

function DrawInteractionText(garageName, action, garageType)
    local actionText = ""
    
    if action == "store" then
        actionText = "Guardar en "
    else
        actionText = "Abrir "
    end
    
    local restText = actionText .. garageName
    local fullText = "[E] " .. restText
    
    -- Fuente 0 = Chalet London (más redondeada)
    local fontId = 0
    local textScale = 0.28
    
    -- Calcular ancho real del texto usando nativas
    SetTextFont(fontId)
    SetTextScale(0.0, textScale)
    BeginTextCommandGetWidth("STRING")
    AddTextComponentSubstringPlayerName(fullText)
    local textWidth = EndTextCommandGetWidth(true)
    
    -- Calcular ancho de [E] para posicionar el resto
    SetTextFont(fontId)
    SetTextScale(0.0, textScale)
    BeginTextCommandGetWidth("STRING")
    AddTextComponentSubstringPlayerName("[E] ")
    local eWidth = EndTextCommandGetWidth(true)
    
    -- Padding mínimo e igual arriba/abajo
    local paddingH = 0.003
    local paddingV = 0.003
    local containerWidth = textWidth + (paddingH * 2)
    local textHeight = 0.016
    local containerHeight = textHeight + (paddingV * 2)
    
    local containerX = 0.008 + (containerWidth / 2)
    local containerY = 0.030
    local textStartX = 0.008 + paddingH
    local textY = containerY - (textHeight / 2) - 0.001
    
    -- Fondo del contenedor
    DrawRect(containerX, containerY, containerWidth, containerHeight, 0, 0, 0, 180)
    
    -- Dibujar [E] en cyan
    SetTextFont(fontId)
    SetTextProportional(true)
    SetTextScale(0.0, textScale)
    SetTextColour(52, 235, 216, 255)
    SetTextDropshadow(1, 0, 0, 0, 255)
    SetTextJustification(1)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName("[E]")
    EndTextCommandDisplayText(textStartX, textY)
    
    -- Dibujar resto del texto en blanco
    SetTextFont(fontId)
    SetTextProportional(true)
    SetTextScale(0.0, textScale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(1, 0, 0, 0, 200)
    SetTextJustification(1)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(" " .. restText)
    EndTextCommandDisplayText(textStartX + eWidth - 0.003, textY)
end

-- ============================================
-- ACCESS CONTROL
-- ============================================

function CanAccessGarage(garage)
    -- Garajes públicos: no tienen restricción de job/gang
    if not garage.job and not garage.gang then
        return true
    end
    
    -- Garajes de trabajo
    if garage.job then
        local jobName = FrameworkBridge.GetJobName()
        return jobName == garage.job
    end
    
    -- Garajes de banda
    if garage.gang then
        local gangName = FrameworkBridge.GetGangName()
        return gangName == garage.gang
    end
    
    return false
end

-- ============================================
-- VEHICLE KEYS
-- ============================================

function GiveVehicleKeys(plate)
    -- Dar llaves según el sistema configurado
    if Config.Keys == 'esx_vehiclekeys' then
        TriggerServerEvent('esx_vehiclekeys:givekey', plate)
    elseif Config.Keys == 'wasabi_carlock' then
        local success = pcall(function()
            exports.wasabi_carlock:GiveKey(plate)
        end)
        if not success then
            print('[kr_garages] Error giving keys via wasabi_carlock')
        end
    elseif Config.Keys == 'qb-vehiclekeys' then
        TriggerEvent("vehiclekeys:client:SetOwner", plate)
    elseif Config.Keys == 'none' or not Config.Keys then
        -- Sin sistema de llaves, no hacer nada
        return
    end
end

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Helper para obtener garaje por ID
function GetGarageById(garageId)
    -- Buscar en garajes públicos
    for _, garage in pairs(Config.Garages or {}) do
        if garage.id == garageId then
            return garage
        end
    end
    
    -- Buscar en impounds
    for _, impound in pairs(Config.Impounds or {}) do
        if impound.id == garageId then
            return impound
        end
    end
    
    return nil
end
