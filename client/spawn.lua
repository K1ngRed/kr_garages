--[[
    client/spawn.lua
    Funciones de spawn de vehículos
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Maneja la creación de vehículos y aplicación de propiedades
--]]

while not FrameworkBridge do Wait(100) end

-- Spawn simple
function SpawnVehicle(vehicleData)
    if not currentGarage or not currentGarage.spawnPoints or #currentGarage.spawnPoints == 0 then
        FrameworkBridge.ShowNotification('~r~No hay puntos de spawn configurados en este garaje')
        return
    end
    
    local garageId = currentGarage.id or currentGarage.garageId

    FrameworkBridge.TriggerCallback('kr_garages:server:SpawnVehicle', function(success, vehicle, errorMsg)
        if not success then
            FrameworkBridge.ShowNotification('~r~' .. (errorMsg or 'Error al usar el vehículo'))
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'closeUI' })
            return
        end
        if not vehicle then
            FrameworkBridge.ShowNotification('~r~Datos de vehículo incompletos')
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'closeUI' })
            return
        end

        -- MEJORADO: Manejar tanto strings como hashes numéricos
        local modelValue = vehicle.vehicle or vehicle.model
        local model = nil
        
        if type(modelValue) == 'string' then
            model = GetHashKey(modelValue)
        elseif type(modelValue) == 'number' then
            model = modelValue
        else
            FrameworkBridge.ShowNotification('~r~Error: Modelo de vehículo inválido')
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'closeUI' })
            return
        end
        
        -- Verificar si el modelo es válido (existe en el juego)
        if not IsModelValid(model) then
            FrameworkBridge.ShowNotification('~r~Error: El modelo del vehículo no existe')
            print(('[kr_garages] ERROR: Invalid model: %s (hash: %s)'):format(tostring(modelValue), tostring(model)))
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'closeUI' })
            return
        end
        
        RequestModel(model)
        local timeout = 0
        while not HasModelLoaded(model) and timeout < 100 do
            Wait(50)
            timeout = timeout + 1
        end
        
        if not HasModelLoaded(model) then
            FrameworkBridge.ShowNotification('~r~Error al cargar el modelo del vehículo')
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'closeUI' })
            return
        end
        SetModelAsNoLongerNeeded(model)
        
        -- Buscar spawn point libre
        local spawnPoint = nil
        for _, point in ipairs(currentGarage.spawnPoints) do
            if FrameworkBridge.IsSpawnPointClear(vector3(point.x, point.y, point.z), 2.5) then
                spawnPoint = point
                break
            end
        end
        
        if not spawnPoint then
            spawnPoint = currentGarage.spawnPoints[1]
        end
        
        -- Crear vehículo
        local veh = CreateVehicle(model, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, false)
        if DoesEntityExist(veh) then
            SetEntityAsMissionEntity(veh, true, true)
        end
        
        -- Esperar a que el vehículo exista
        local timeout2 = 0
        while not DoesEntityExist(veh) and timeout2 < 50 do
            Wait(50)
            timeout2 = timeout2 + 1
        end
        
        if not DoesEntityExist(veh) then
            FrameworkBridge.ShowNotification('~r~Error al crear el vehículo')
            return
        end
        
        -- Configurar vehículo
        SetVehicleNumberPlateText(veh, vehicle.plate)
        SetEntityHeading(veh, spawnPoint.w)
        SetVehicleEngineHealth(veh, vehicle.engine + 0.0)
        SetVehicleBodyHealth(veh, vehicle.body + 0.0)
        SetFuelLevel(veh, vehicle.fuel)
        
        -- Aplicar propiedades
        if vehicle.props and type(vehicle.props) == 'table' then
            FrameworkBridge.SetVehicleProperties(veh, vehicle.props)
        elseif vehicle.mods and type(vehicle.mods) == 'string' and vehicle.mods ~= '' then
            local ok, props = pcall(function() return json.decode(vehicle.mods) end)
            if ok and type(props) == 'table' then
                FrameworkBridge.SetVehicleProperties(veh, props)
            end
        end
        
        -- Dar llaves
        GiveVehicleKeys(vehicle.plate)
        
        -- Poner jugador en vehículo
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        
        FrameworkBridge.ShowNotification('~g~Vehículo sacado del garaje')
        
        -- Cerrar UI si está abierta
        if currentGarage then
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'closeUI' })
        end
    end, vehicleData.plate, garageId)
end

-- ============================================
-- SPAWN VEHICLE FROM DATA (Desde NUI)
-- ============================================

function SpawnVehicleFromData(vehicleData)
    -- Función helper para mostrar error
    local function ShowError(msg)
        FrameworkBridge.ShowNotification('~r~' .. msg)
        return false
    end
    
    if not vehicleData then
        return ShowError('Datos de vehículo inválidos')
    end
    
    -- Verificar currentGarage - si no hay, intentar usar datos del vehicleData
    local garageToUse = currentGarage
    
    if not garageToUse then
        -- Si tenemos coords en vehicleData, crear garaje temporal
        if vehicleData.coords then
            garageToUse = {
                spawnPoints = {{
                    x = vehicleData.coords.x,
                    y = vehicleData.coords.y,
                    z = vehicleData.coords.z,
                    w = vehicleData.heading or 0.0
                }}
            }
        else
            return ShowError('No hay garaje actual seleccionado')
        end
    end
    
    -- Normalizar spawnPoints si no están normalizados
    if garageToUse.spawnPoints and #garageToUse.spawnPoints > 0 then
        local normalized = {}
        for _, point in ipairs(garageToUse.spawnPoints) do
            if type(point) == 'vector4' then
                table.insert(normalized, {x = point.x, y = point.y, z = point.z, w = point.w})
            elseif type(point) == 'table' and point.x then
                table.insert(normalized, point)
            end
        end
        garageToUse.spawnPoints = normalized
    elseif not garageToUse.spawnPoints or #garageToUse.spawnPoints == 0 then
        -- Intentar crear spawnPoints desde los datos del garaje
        if garageToUse.coords then
            garageToUse.spawnPoints = {{x = garageToUse.coords.x, y = garageToUse.coords.y, z = garageToUse.coords.z, w = garageToUse.heading or 0.0}}
        elseif garageToUse.x and garageToUse.y and garageToUse.z then
            garageToUse.spawnPoints = {{x = garageToUse.x, y = garageToUse.y, z = garageToUse.z, w = garageToUse.heading or 0.0}}
        end
    end
    
    if not garageToUse.spawnPoints or #garageToUse.spawnPoints == 0 then
        return ShowError('No hay puntos de spawn configurados en este garaje')
    end
    
    -- Buscar un spawn point disponible (alejado del jugador)
    local playerPos = GetEntityCoords(PlayerPedId())
    local spawnPoint = nil
    
    for _, point in ipairs(garageToUse.spawnPoints) do
        local pointPos = vector3(point.x, point.y, point.z)
        local distFromPlayer = #(playerPos - pointPos)
        
        -- Asegurar que el punto esté al menos a 3 metros del jugador
        if distFromPlayer > 3.0 and FrameworkBridge.IsSpawnPointClear(pointPos, 2.0) then
            spawnPoint = point
            break
        end
    end
    
    -- Si no hay ninguno libre Y alejado, usar el primero disponible
    if not spawnPoint then
        for _, point in ipairs(garageToUse.spawnPoints) do
            local pointPos = vector3(point.x, point.y, point.z)
            if FrameworkBridge.IsSpawnPointClear(pointPos, 2.0) then
                spawnPoint = point
                break
            end
        end
    end
    
    -- Si todavía no hay, usar el primer punto aunque esté ocupado
    if not spawnPoint then
        spawnPoint = garageToUse.spawnPoints[1]
    end
    
    -- CRÍTICO: Usar vehicleData.model o vehicleData.vehicle directamente
    local modelName = vehicleData.model or vehicleData.vehicle
    local modelHash = nil
    
    if not modelName then
        return ShowError('No se pudo determinar el modelo del vehículo')
    end
    
    -- Si modelName es un número (hash), usarlo directamente
    if type(modelName) == 'number' then
        modelHash = modelName
        
        -- Intentar obtener el nombre desde VehicleData
        if VehicleData and VehicleData.HashToName then
            local convertedName = VehicleData.HashToName(modelName)
            if convertedName then
                modelName = convertedName
            end
        end
    elseif type(modelName) == 'string' and modelName ~= '' then
        -- Es un string, limpiar y obtener el hash
        -- CRÍTICO: Convertir espacios a guiones bajos (común en addons)
        modelName = string.lower(modelName):gsub('%s+', '_')
        modelHash = GetHashKey(modelName)
    else
        return ShowError('Modelo de vehículo inválido')
    end
    
    -- Verificar si el modelo es válido
    if not IsModelValid(modelHash) then
        -- FALLBACK: Intentar con el hash original de props si existe
        if vehicleData.props and vehicleData.props.model and type(vehicleData.props.model) == 'number' then
            modelHash = vehicleData.props.model
            if IsModelValid(modelHash) then
                modelName = modelHash
            else
                return ShowError('Modelo de vehículo no existe: ' .. tostring(modelName or modelHash))
            end
        elseif vehicleData.props and vehicleData.props.modelHash and type(vehicleData.props.modelHash) == 'number' then
            modelHash = vehicleData.props.modelHash
            if IsModelValid(modelHash) then
                modelName = modelHash
            else
                return ShowError('Modelo de vehículo no existe: ' .. tostring(modelName or modelHash))
            end
        else
            return ShowError('Modelo de vehículo no existe: ' .. tostring(modelName or modelHash))
        end
    end
    
    if not IsModelAVehicle(modelHash) then
        return ShowError('El modelo no es un vehículo: ' .. tostring(modelName or modelHash))
    end
    
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 200 do
        Wait(50)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(modelHash) then
        SetModelAsNoLongerNeeded(modelHash)
        return ShowError('Error al cargar modelo del vehículo: ' .. tostring(modelName or modelHash))
    end
    
    -- Obtener coordenadas y heading correctos
    local spawnX = spawnPoint.x
    local spawnY = spawnPoint.y
    local spawnZ = spawnPoint.z
    local spawnH = spawnPoint.w or 0.0
    
    -- Crear vehículo en el spawn point del garaje
    local veh = CreateVehicle(modelHash, spawnX, spawnY, spawnZ + 0.5, spawnH, true, false)
    
    SetModelAsNoLongerNeeded(modelHash)
    
    -- CRÍTICO: Esperar a que el vehículo se cree completamente
    timeout = 0
    while not DoesEntityExist(veh) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    
    if not DoesEntityExist(veh) then
        return ShowError('Error al crear vehículo')
    end
    
    -- Configurar como entidad de red (SOLO SI EXISTE)
    SetEntityAsMissionEntity(veh, true, true)
    
    -- Obtener NetworkId solo después de confirmar que existe
    if NetworkGetEntityIsNetworked(veh) then
        local netId = NetworkGetNetworkIdFromEntity(veh)
        if netId and netId ~= 0 then
            SetNetworkIdCanMigrate(netId, true)
            SetNetworkIdExistsOnAllMachines(netId, true)
        end
    end
    
    -- Configurar placa
    local plate = vehicleData.plate or 'UNKNOWN'
    SetVehicleNumberPlateText(veh, plate)
    
    -- Registrar vehículo spawneado
    spawnedVehicles[plate] = veh
    
    -- Obtener valores de salud del servidor
    local engineHealth = vehicleData.engine or 1000
    local bodyHealth = vehicleData.body or 1000
    local fuel = vehicleData.fuel or 100
    local isRepaired = (engineHealth >= 1000 and bodyHealth >= 1000 and fuel >= 100)
    
    -- Aplicar propiedades del vehículo (mods, colores, etc)
    if vehicleData.props and type(vehicleData.props) == 'table' then
        -- CRÍTICO: SIEMPRE limpiar fuelLevel de las props para que no sobrescriba nuestro valor
        vehicleData.props.fuelLevel = nil
        
        -- Si el vehículo viene reparado, limpiar TODOS los datos de daño de las props
        if isRepaired then
            vehicleData.props.bodyHealth = nil
            vehicleData.props.engineHealth = nil
            vehicleData.props.tankHealth = nil
            vehicleData.props.dirtLevel = nil
            vehicleData.props.windows = nil
            vehicleData.props.doors = nil
            vehicleData.props.tyres = nil
            vehicleData.props.wheels = nil
        end
        
        FrameworkBridge.SetVehicleProperties(veh, vehicleData.props)
    end
    
    -- CRÍTICO: Esperar después de aplicar props para que se sincronicen
    Wait(100)
    
    -- Si el vehículo viene reparado, hacer reparación visual completa
    if isRepaired then
        -- Reparación completa
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleUndriveable(veh, false)
        SetVehicleDirtLevel(veh, 0.0)
        
        -- Aplicar valores de salud
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        
        -- Resetear ruedas
        for i = 0, 5 do
            SetVehicleTyreBurst(veh, i, false, 1000.0)
            SetVehicleTyreFixed(veh, i)
        end
        
        -- Resetear puertas y ventanas
        for i = 0, 7 do
            SetVehicleDoorShut(veh, i, false)
            FixVehicleWindow(veh, i)
        end
        
        Wait(50)
        
        -- FORZAR de nuevo después de esperar
        SetVehicleFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        
        -- Forzar fuel a 100
        fuel = 100
    else
        -- Aplicar valores de salud normales (vehículo con daño)
        SetVehicleEngineHealth(veh, engineHealth + 0.0)
        SetVehicleBodyHealth(veh, bodyHealth + 0.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
    end
    
    -- Configurar combustible SIEMPRE al final
    SetFuelLevel(veh, fuel)
    DecorSetInt(veh, "_FUEL_LEVEL", math.floor(fuel))
    
    -- Asegurarse de que el vehículo está en el suelo correctamente
    SetVehicleOnGroundProperly(veh)
    
    -- Aplicar heading correcto del spawn point
    SetEntityHeading(veh, spawnPoint.w or 0.0)
    
    -- Esperar un poco y volver a colocar en el suelo
    Wait(100)
    SetVehicleOnGroundProperly(veh)
    
    -- CRÍTICO: Configurar vehículo como driveable y sin restricciones
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehicleEngineCanDegrade(veh, false)
    
    -- Dar llaves al jugador ANTES de meter al jugador
    GiveVehicleKeys(plate)
    
    -- Esperar para que las llaves se asignen
    Wait(100)
    
    -- Poner al jugador DENTRO del vehículo
    local ped = PlayerPedId()
    TaskWarpPedIntoVehicle(ped, veh, -1)
    
    -- Esperar a que el jugador esté dentro
    timeout = 0
    while GetVehiclePedIsIn(ped, false) ~= veh and timeout < 50 do
        Wait(10)
        timeout = timeout + 1
    end
    
    -- CRÍTICO: Configurar motor y extras después de que el jugador esté dentro
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleUndriveable(veh, false)
    SetVehicleDoorsLocked(veh, 0) -- Desbloquear todas las puertas
    
    -- Asegurar que el motor puede encenderse
    Wait(50)
    if not GetIsVehicleEngineRunning(veh) then
        SetVehicleEngineOn(veh, true, true, false)
    end
    
    SetVehRadioStation(veh, 'OFF')
    
    FrameworkBridge.ShowNotification('~g~Vehículo sacado del garaje')
    
    -- Cerrar UI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
    
    return true
end

-- ============================================
-- EXPORTS
-- ============================================

exports('SpawnVehicle', SpawnVehicle)
