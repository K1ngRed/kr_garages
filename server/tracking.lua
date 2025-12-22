-- server/tracking.lua
-- Sistema de tracking de vehículos

-- ============================================
-- UPDATE VEHICLE STATUS
-- ============================================

RegisterNetEvent('kr_garages:server:UpdateVehicleStatus', function(plate, engine, body, fuel)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    local identifier = GetPlayerIdentifier(xPlayer)
    
    if not plate or type(plate) ~= 'string' then return end
    
    local function isValidNumber(n)
        return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
    end
    
    local validEngine = isValidNumber(engine) and engine or 1000
    local validBody = isValidNumber(body) and body or 1000
    local validFuel = isValidNumber(fuel) and fuel or 100
    
    MySQL.update('UPDATE owned_vehicles SET engine = ?, body = ?, fuel = ? WHERE plate = ? AND owner = ? AND in_garage = 0', {
        math.floor(validEngine),
        math.floor(validBody),
        math.floor(validFuel),
        plate,
        identifier
    })
end)

-- ============================================
-- CHECK ALL VEHICLES STATUS ON GARAGE OPEN
-- ============================================

RegisterNetEvent('kr_garages:server:CheckAllVehiclesStatus', function(garageId, nearbyPlates, allPlatesInWorld, vehicleStates)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    local identifier = GetPlayerIdentifier(xPlayer)
    
    -- Guardar vehículos CERCA del jugador (< 150m)
    playerNearbyVehicles[identifier] = {}
    if nearbyPlates and type(nearbyPlates) == 'table' then
        for _, plate in ipairs(nearbyPlates) do
            playerNearbyVehicles[identifier][plate] = true
        end
    end
    
    -- Guardar TODOS los vehículos en el mundo
    playerWorldVehicles[identifier] = {}
    if allPlatesInWorld and type(allPlatesInWorld) == 'table' then
        for _, plate in ipairs(allPlatesInWorld) do
            playerWorldVehicles[identifier][plate] = true
        end
    end
    
    -- Actualizar el estado de los vehículos detectados en la DB
    if vehicleStates and type(vehicleStates) == 'table' then
        local function isValidNumber(n)
            return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
        end
        
        for plate, state in pairs(vehicleStates) do
            local validEngine = isValidNumber(state.engine) and state.engine or nil
            local validBody = isValidNumber(state.body) and state.body or nil
            local validFuel = isValidNumber(state.fuel) and state.fuel or 100
            
            if validEngine and validBody then
                MySQL.update('UPDATE owned_vehicles SET engine = ?, body = ?, fuel = ? WHERE plate = ? AND owner = ? AND in_garage = 0', {
                    math.floor(validEngine),
                    math.floor(validBody),
                    math.floor(validFuel),
                    plate,
                    identifier
                })
            end
        end
    end
    
    -- Limpiar el cache después de 60 segundos
    SetTimeout(60000, function()
        playerNearbyVehicles[identifier] = nil
        playerWorldVehicles[identifier] = nil
    end)
end)

-- ============================================
-- VEHICLE RECOVERY EVENTS
-- ============================================

RegisterNetEvent('kr_garages:server:ReturnAbandonedVehicle', function(plate, garageId, reason)
    local src = source
    
    if not plate then return end
    
    MySQL.query('SELECT owner, engine, body FROM owned_vehicles WHERE plate = ? AND in_garage = 0', {plate}, function(result)
        if not result or not result[1] then return end
        
        local vehicle = result[1]
        local engine = vehicle.engine or 0
        local body = vehicle.body or 0
        
        MySQL.update('UPDATE owned_vehicles SET in_garage = 1 WHERE plate = ?', {plate}, function(affectedRows)
            if affectedRows > 0 then
                local reasonText = reason == 'destroyed' and 'destruido' or 'abandonado'
                
                local identifier = vehicle.owner
                local xPlayer = FrameworkBridge.GetPlayerByIdentifier(identifier)
                if xPlayer then
                    FrameworkBridge.ShowNotification(xPlayer.source, 
                        ('Tu vehículo %s ha sido devuelto al garaje por estar %s'):format(plate, reasonText))
                end
            end
        end)
    end)
end)

-- Marcar vehículos como destruidos
RegisterNetEvent('kr_garages:server:MarkVehiclesAsDestroyed', function(plates)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    local identifier = GetPlayerIdentifier(xPlayer)
    
    if not plates or #plates == 0 then return end
    
    for _, plate in ipairs(plates) do
        MySQL.update('UPDATE owned_vehicles SET in_garage = 1, engine = 0, body = 0, fuel = 0 WHERE plate = ? AND owner = ?', {
            plate,
            identifier
        })
    end
end)

-- Actualizar vehículo destruido
RegisterNetEvent('kr_garages:server:UpdateDestroyedVehicle', function(plate, garageId, engineHealth, bodyHealth)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    local identifier = GetPlayerIdentifier(xPlayer)
    if not plate then return end
    
    local engine = math.max(0, math.min(1000, math.floor(engineHealth or 0)))
    local body = math.max(0, math.min(1000, math.floor(bodyHealth or 0)))
    
    if engineHealth < 0 or bodyHealth < 0 then
        engine = 0
        body = 0
    end
    
    MySQL.update('UPDATE owned_vehicles SET in_garage = 1, garage_id = ?, engine = ?, body = ? WHERE plate = ? AND owner = ?', {
        GetGarageKey(garageId),
        engine,
        body,
        plate,
        identifier
    })
end)

-- Recuperar vehículos perdidos
RegisterNetEvent('kr_garages:server:RecoverLostVehicles', function()
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    local identifier = GetPlayerIdentifier(xPlayer)
    
    MySQL.query('SELECT plate, garage_id FROM owned_vehicles WHERE owner = ? AND in_garage = 0', {identifier}, function(vehicles)
        if not vehicles or #vehicles == 0 then
            FrameworkBridge.ShowNotification(src, 'No tienes vehículos fuera del garaje')
            return
        end
        
        local recovered = 0
        
        for _, veh in ipairs(vehicles) do
            MySQL.update('UPDATE owned_vehicles SET in_garage = 1, engine = 0, body = 0 WHERE plate = ? AND owner = ?', {
                veh.plate,
                identifier
            }, function(affectedRows)
                if affectedRows > 0 then
                    recovered = recovered + 1
                end
            end)
        end
        
        SetTimeout(1000, function()
            FrameworkBridge.ShowNotification(src, ('~g~%d vehículo(s) recuperado(s). Deberás repararlos antes de usarlos'):format(recovered))
        end)
    end)
end)
