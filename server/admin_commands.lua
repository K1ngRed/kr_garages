-- server/admin_commands.lua
-- Comandos de administración para vehículos

-- ============================================
-- GENERACIÓN DE PLACAS
-- ============================================

local function GenerateRandomPlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''
    for i = 1, 8 do
        local randomIndex = math.random(1, #chars)
        plate = plate .. chars:sub(randomIndex, randomIndex)
    end
    return plate
end

local function PlateExistsAsync(plate)
    local result = MySQL.scalar.await('SELECT COUNT(*) FROM owned_vehicles WHERE plate = ?', {plate})
    return result and result > 0
end

local function GenerateUniquePlateAsync()
    local attempts = 0
    local maxAttempts = 10
    
    while attempts < maxAttempts do
        local plate = GenerateRandomPlate()
        if not PlateExistsAsync(plate) then
            return plate
        end
        attempts = attempts + 1
    end
    
    return nil
end

-- ============================================
-- DETECTAR TIPO DE VEHÍCULO
-- ============================================

local function GetVehicleTypeFromModel(modelName)
    -- Primero buscar en VehicleData por nombre
    if VehicleData and VehicleData.Vehicles then
        for hash, data in pairs(VehicleData.Vehicles) do
            if data.name and string.lower(data.name) == string.lower(modelName) then
                return data.type or 'car', data.class or 0, data.label or modelName
            end
        end
    end
    
    -- Lista de vehículos aéreos conocidos
    local airVehicles = {
        -- Helicópteros
        'akula', 'annihilator', 'annihilator2', 'buzzard', 'buzzard2', 'cargobob', 'cargobob2', 
        'cargobob3', 'cargobob4', 'conada', 'frogger', 'frogger2', 'havok', 'hunter', 
        'maverick', 'polmav', 'savage', 'seasparrow', 'seasparrow2', 'seasparrow3', 
        'skylift', 'supervolito', 'supervolito2', 'swift', 'swift2', 'valkyrie', 
        'valkyrie2', 'volatus',
        -- Aviones
        'alkonost', 'alphaz1', 'avenger', 'avenger2', 'besra', 'bombushka', 'cargoplane',
        'cuban800', 'dodo', 'duster', 'howard', 'hydra', 'jet', 'lazer', 'luxor', 
        'luxor2', 'mammatus', 'microlight', 'miljet', 'mogul', 'molotok', 'nimbus',
        'nokota', 'pyro', 'rogue', 'seabreeze', 'shamal', 'starling', 'strikeforce',
        'stunt', 'titan', 'tula', 'velum', 'velum2', 'vestra', 'volatol'
    }
    
    -- Lista de vehículos acuáticos conocidos
    local boatVehicles = {
        'avisa', 'dinghy', 'dinghy2', 'dinghy3', 'dinghy4', 'dinghy5', 'jetmax', 
        'kosatka', 'longfin', 'marquis', 'patrolboat', 'predator', 'seashark', 
        'seashark2', 'seashark3', 'speeder', 'speeder2', 'squalo', 'submersible', 
        'submersible2', 'suntrap', 'toro', 'toro2', 'tropic', 'tropic2', 'tug'
    }
    
    local modelLower = string.lower(modelName)
    
    for _, v in ipairs(airVehicles) do
        if v == modelLower then
            return 'air', 15, modelName
        end
    end
    
    for _, v in ipairs(boatVehicles) do
        if v == modelLower then
            return 'boat', 14, modelName
        end
    end
    
    return 'car', 0, modelName
end

-- ============================================
-- /DARAUTO - Dar vehículo a un jugador
-- Uso: /darauto [ID_jugador] [modelo] [placa_opcional]
-- ============================================

RegisterCommand('darauto', function(source, args, rawCommand)
    local src = source
    
    -- Si es consola (source = 0), permitir
    if src ~= 0 then
        local xPlayer = FrameworkBridge.GetPlayer(src)
        if not xPlayer then return end
        
        -- Verificar permisos admin
        if not IsPlayerAdmin(xPlayer) then
            FrameworkBridge.ShowNotification(src, '~r~No tienes permisos para usar este comando')
            return
        end
    end
    
    -- Validar argumentos mínimos (ID y modelo son obligatorios)
    if #args < 2 then
        if src == 0 then
            print('[KR_GARAGES] Uso: darauto [ID_jugador] [modelo] [placa_opcional]')
            print('[KR_GARAGES] Ejemplo: darauto 1 adder')
        else
            FrameworkBridge.ShowNotification(src, '~r~Uso: /darauto [ID] [modelo] [placa]')
        end
        return
    end
    
    -- ========== EJECUCIÓN (2 o 3 argumentos) ==========
    
    local targetId = tonumber(args[1])
    local modelo = string.lower(args[2])
    local placaCustom = args[3] and string.upper(args[3]) or nil
    
    if not targetId then
        if src == 0 then
            print('[KR_GARAGES] ERROR: ID de jugador inválido')
        else
            FrameworkBridge.ShowNotification(src, '~r~ID de jugador inválido')
        end
        return
    end
    
    -- Obtener jugador objetivo
    local targetPlayer = FrameworkBridge.GetPlayer(targetId)
    if not targetPlayer then
        if src == 0 then
            print('[KR_GARAGES] ERROR: Jugador con ID ' .. targetId .. ' no encontrado o no está conectado')
        else
            FrameworkBridge.ShowNotification(src, '~r~Jugador no encontrado o no está conectado')
        end
        return
    end
    
    local targetIdentifier = FrameworkBridge.GetIdentifier(targetPlayer)
    local targetName = FrameworkBridge.GetPlayerName(targetPlayer)
    
    if not targetIdentifier then
        if src == 0 then
            print('[KR_GARAGES] ERROR: No se pudo obtener el identifier del jugador')
        else
            FrameworkBridge.ShowNotification(src, '~r~Error al obtener datos del jugador')
        end
        return
    end
    
    -- Generar o validar placa
    local plate = nil
    
    if placaCustom then
        -- Validar que la placa no exceda 8 caracteres
        if #placaCustom > 8 then
            if src == 0 then
                print('[KR_GARAGES] ERROR: La placa no puede tener más de 8 caracteres')
            else
                FrameworkBridge.ShowNotification(src, '~r~La placa no puede tener más de 8 caracteres')
            end
            return
        end
        
        -- Verificar que la placa no exista
        if PlateExistsAsync(placaCustom) then
            if src == 0 then
                print('[KR_GARAGES] ERROR: La placa ' .. placaCustom .. ' ya existe')
            else
                FrameworkBridge.ShowNotification(src, '~r~La placa ' .. placaCustom .. ' ya existe')
            end
            return
        end
        
        plate = placaCustom
    else
        -- Generar placa automática
        plate = GenerateUniquePlateAsync()
        if not plate then
            if src == 0 then
                print('[KR_GARAGES] ERROR: No se pudo generar una placa única')
            else
                FrameworkBridge.ShowNotification(src, '~r~Error al generar placa única')
            end
            return
        end
    end
    
    -- Detectar tipo de vehículo
    local vehicleType, vehicleClass, vehicleLabel = GetVehicleTypeFromModel(modelo)
    
    -- Crear props del vehículo
    local vehicleProps = {
        model = modelo,
        modelName = modelo,
        modelLabel = vehicleLabel or modelo:gsub("^%l", string.upper),
        plate = plate,
        fuelLevel = 100,
        engineHealth = 1000,
        bodyHealth = 1000,
        class = vehicleClass,
        vehicleClass = vehicleClass,
        _vehicleType = vehicleType  -- CRÍTICO: Esto determina en qué garaje aparece
    }
    
    -- Insertar en la base de datos
    MySQL.insert('INSERT INTO owned_vehicles (owner, plate, vehicle, garage_id, fuel, engine, body, in_garage) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        targetIdentifier,
        plate,
        json.encode(vehicleProps),
        'central_garage',
        100,
        1000,
        1000,
        1
    }, function(insertId)
        if insertId then
            -- Log para consola del servidor
            local adminName = 'CONSOLA'
            if src ~= 0 then
                local adminPlayer = FrameworkBridge.GetPlayer(src)
                adminName = FrameworkBridge.GetPlayerName(adminPlayer) or 'Admin'
            end
            
            local tipoTexto = vehicleType == 'air' and 'AÉREO' or (vehicleType == 'boat' and 'ACUÁTICO' or 'TERRESTRE')
            
            print(('[KR_GARAGES] ADMIN %s dio vehículo %s [%s] (placa: %s) a %s (ID: %d)'):format(
                adminName, modelo, tipoTexto, plate, targetName, targetId
            ))
            
            -- Notificar al admin
            if src == 0 then
                print('[KR_GARAGES] ✓ Vehículo asignado correctamente - Tipo: ' .. tipoTexto)
            else
                FrameworkBridge.ShowNotification(src, ('~g~%s %s asignado a %s (Placa: %s)'):format(tipoTexto, modelo, targetName, plate))
            end
            
            -- Notificar al jugador que recibió el vehículo
            FrameworkBridge.ShowNotification(targetId, ('~g~Has recibido un vehículo: %s (Placa: %s)'):format(modelo, plate))
            
            local garageInfo = vehicleType == 'air' and 'un garaje de aviones/helicópteros' or 
                              (vehicleType == 'boat' and 'un garaje de barcos' or 'cualquier garaje público')
            
            TriggerClientEvent('chat:addMessage', targetId, {
                color = {0, 255, 0},
                multiline = true,
                args = {'Sistema', ('¡Has recibido un nuevo vehículo!\nModelo: %s\nPlaca: %s\nTipo: %s\n\nPuedes encontrarlo en %s.'):format(modelo:upper(), plate, tipoTexto, garageInfo)}
            })
        else
            if src == 0 then
                print('[KR_GARAGES] ERROR: No se pudo insertar el vehículo en la base de datos')
            else
                FrameworkBridge.ShowNotification(src, '~r~Error al guardar el vehículo en la base de datos')
            end
        end
    end)
end, false)

print('[KR_GARAGES] Comando /darauto cargado')
