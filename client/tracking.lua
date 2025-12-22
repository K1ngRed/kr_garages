--[[
    client/tracking.lua
    Tracking de estado de vehículos
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Detecta daños, destrucción y guardado automático
--]]

while not FrameworkBridge do Wait(100) end

-- Monitor de eliminación de vehículos
CreateThread(function()
    while not resourceStopping do
        Wait(2000)
        if resourceStopping then return end
        
        for plate, veh in pairs(spawnedVehicles) do
            if not DoesEntityExist(veh) then
                -- Ignorar si está siendo incautado
                if not ImpoundingPlates or not ImpoundingPlates[plate] then
                    TriggerServerEvent('kr_garages:server:VehicleDeleted', plate)
                end
                spawnedVehicles[plate] = nil
            end
        end
    end
end)

-- Variables de tracking
local lastEngineHealth = {}
local lastBodyHealth = {}
local lastTrackedVehicle = 0
local lastTrackedPlate = nil

-- Thread único que maneja todas las actualizaciones de estado
CreateThread(function()
    local updateTimer = 0
    local REGULAR_UPDATE_INTERVAL = 5000 -- Actualización regular cada 5 segundos
    local DAMAGE_CHECK_INTERVAL = 1000   -- Verificar daño cada segundo
    
    while not resourceStopping do
        Wait(DAMAGE_CHECK_INTERVAL)
        if resourceStopping then return end
        updateTimer = updateTimer + DAMAGE_CHECK_INTERVAL
        
        local ped = PlayerPedId()
        local currentVeh = GetVehiclePedIsIn(ped, false)
        
        -- Detectar cuando el jugador sale del vehículo
        if lastTrackedVehicle ~= 0 and currentVeh == 0 then
            if DoesEntityExist(lastTrackedVehicle) and lastTrackedPlate then
                local engine = GetVehicleEngineHealth(lastTrackedVehicle)
                local body = GetVehicleBodyHealth(lastTrackedVehicle)
                local fuel = GetFuelLevel(lastTrackedVehicle)
                TriggerServerEvent('kr_garages:server:UpdateVehicleStatus', lastTrackedPlate, engine, body, fuel)
            end
            lastTrackedVehicle = 0
            lastTrackedPlate = nil
        end
        
        -- Si el jugador está en un vehículo
        if currentVeh ~= 0 then
            local plate = FrameworkBridge.GetPlate(currentVeh)
            if plate then
                lastTrackedVehicle = currentVeh
                lastTrackedPlate = plate
                
                local engine = GetVehicleEngineHealth(currentVeh)
                local body = GetVehicleBodyHealth(currentVeh)
                
                local prevEngine = lastEngineHealth[plate] or 1000
                local prevBody = lastBodyHealth[plate] or 1000
                
                -- Actualizar inmediatamente si hay daño significativo
                local significantDamage = (prevEngine - engine) > 50 or (prevBody - body) > 50
                
                -- Actualización regular cada 5 segundos O daño significativo
                if updateTimer >= REGULAR_UPDATE_INTERVAL or significantDamage then
                    local fuel = GetFuelLevel(currentVeh)
                    TriggerServerEvent('kr_garages:server:UpdateVehicleStatus', plate, engine, body, fuel)
                    lastEngineHealth[plate] = engine
                    lastBodyHealth[plate] = body
                    
                    if updateTimer >= REGULAR_UPDATE_INTERVAL then
                        updateTimer = 0
                        
                        -- También actualizar vehículos spawneados que no se están usando
                        for spawnedPlate, vehHandle in pairs(spawnedVehicles) do
                            if spawnedPlate ~= plate and DoesEntityExist(vehHandle) then
                                local spawnedEngine = GetVehicleEngineHealth(vehHandle)
                                local spawnedBody = GetVehicleBodyHealth(vehHandle)
                                local spawnedFuel = GetFuelLevel(vehHandle)
                                TriggerServerEvent('kr_garages:server:UpdateVehicleStatus', spawnedPlate, spawnedEngine, spawnedBody, spawnedFuel)
                            end
                        end
                    end
                end
            end
        else
            -- El jugador no está en un vehículo, solo actualizar spawneados cada 5 segundos
            if updateTimer >= REGULAR_UPDATE_INTERVAL then
                updateTimer = 0
                for plate, vehHandle in pairs(spawnedVehicles) do
                    if DoesEntityExist(vehHandle) then
                        local engine = GetVehicleEngineHealth(vehHandle)
                        local body = GetVehicleBodyHealth(vehHandle)
                        local fuel = GetFuelLevel(vehHandle)
                        TriggerServerEvent('kr_garages:server:UpdateVehicleStatus', plate, engine, body, fuel)
                    end
                end
            end
        end
    end
end)

-- ============================================
-- CLEANUP SPAWNED VEHICLES
-- ============================================

function CleanupSpawnedVehicles()
    for plate, veh in pairs(spawnedVehicles) do
        if DoesEntityExist(veh) then
            local driver = GetPedInVehicleSeat(veh, -1)
            if driver == 0 or driver == PlayerPedId() then
                SetEntityAsMissionEntity(veh, true, true)
                local timeout = 0
                while not NetworkHasControlOfEntity(veh) and timeout < 30 do
                    NetworkRequestControlOfEntity(veh)
                    Wait(50)
                    timeout = timeout + 1
                end
            end
        end
        spawnedVehicles[plate] = nil
    end
end

-- ============================================
-- STORED VEHICLE CLEANUP
-- ============================================

-- Evento para limpiar vehículo de la lista cuando se guarda
RegisterNetEvent('kr_garages:client:VehicleStoredTracking')
AddEventHandler('kr_garages:client:VehicleStoredTracking', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, true)
    if veh and veh ~= 0 then
        local plate = FrameworkBridge.GetPlate(veh)
        if plate and spawnedVehicles[plate] then
            spawnedVehicles[plate] = nil
        end
    end
end)

-- ============================================
-- ADMIN COMMANDS HOOK
-- ============================================

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        TriggerEvent('chat:addSuggestion', '/delveh', 'Eliminar vehículo cercano')
    end
end)

-- Detectar cuando se elimina el vehículo actual del jugador
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        if victim and IsEntityAVehicle(victim) then
            local plate = FrameworkBridge.GetPlate(victim)
            if plate and spawnedVehicles[plate] then
                SetTimeout(500, function()
                    if not DoesEntityExist(victim) then
                        -- Verificar si el vehículo está siendo incautado (ignorar)
                        if not ImpoundingPlates or not ImpoundingPlates[plate] then
                            TriggerServerEvent('kr_garages:server:VehicleDeleted', plate)
                        end
                        spawnedVehicles[plate] = nil
                    end
                end)
            end
        end
    end
end)
