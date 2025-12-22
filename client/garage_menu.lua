--[[
    client/garage_menu.lua
    Menú de garaje y función OpenGarage
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Función principal que abre la interfaz de garajes
--]]

while not FrameworkBridge do Wait(100) end

function OpenGarage(garage)
    if not CanAccessGarage(garage) then
        FrameworkBridge.ShowNotification('~r~No tienes acceso a este garaje')
        return
    end
    
    currentGarage = garage
    
    -- Obtener posición del jugador (para calcular distancia a vehículos)
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    -- Verificar qué vehículos existen en el mundo ANTES de abrir el garaje
    local worldVehicles = GetGamePool('CVehicle')
    local nearbyPlates = {}
    local allPlatesInWorld = {}
    local vehicleStates = {}
    
    local MAX_NEARBY_DISTANCE = 50.0
    
    for _, veh in ipairs(worldVehicles) do
        if DoesEntityExist(veh) then
            local plate = FrameworkBridge.GetPlate(veh)
            if plate then
                table.insert(allPlatesInWorld, plate)
                
                local vehCoords = GetEntityCoords(veh)
                local distanceToPlayer = #(vehCoords - playerCoords)
                
                if distanceToPlayer <= MAX_NEARBY_DISTANCE then
                    table.insert(nearbyPlates, plate)
                end
                
                vehicleStates[plate] = {
                    engine = GetVehicleEngineHealth(veh),
                    body = GetVehicleBodyHealth(veh),
                    fuel = GetFuelLevel(veh)
                }
            end
        end
    end
    
    -- Enviar lista de placas cercanas, todas las placas y estados al servidor
    TriggerServerEvent('kr_garages:server:CheckAllVehiclesStatus', garage.id, nearbyPlates, allPlatesInWorld, vehicleStates)
    
    -- Esperar brevemente para que el servidor procese y luego obtener vehículos
    CreateThread(function()
        Wait(100)
        
        FrameworkBridge.TriggerCallback('kr_garages:server:GetVehicles', function(vehicles)
            currentVehicles = vehicles
            
            -- Normalizar spawnPoints (convertir vector4 a tablas)
            local spawnPoints = {}
            if garage.spawnPoints and #garage.spawnPoints > 0 then
                for _, point in ipairs(garage.spawnPoints) do
                    if type(point) == 'vector4' then
                        table.insert(spawnPoints, {x = point.x, y = point.y, z = point.z, w = point.w})
                    elseif type(point) == 'table' and point.x then
                        table.insert(spawnPoints, point)
                    end
                end
            end
            
            if #spawnPoints == 0 then
                if garage.coords then
                    table.insert(spawnPoints, {x = garage.coords.x, y = garage.coords.y, z = garage.coords.z, w = garage.heading or 0.0})
                elseif garage.x and garage.y and garage.z then
                    table.insert(spawnPoints, {x = garage.x, y = garage.y, z = garage.z, w = garage.heading or 0.0})
                end
            end
            
            currentGarage.spawnPoints = spawnPoints
            
            SendNUIMessage({
                action = 'openGarage',
                garage = {
                    id = garage.id,
                    name = garage.name,
                    type = garage.type or garage.vehicleType or 'car',
                    garageType = garage.garageType,
                    isOwner = garage.isOwner,
                    spawnPoints = spawnPoints
                },
                vehicles = vehicles,
                locale = Config.Locale or 'es'
            })
            SetNuiFocus(true, true)
        end, garage.id)
    end)
end

-- ============================================
-- EXPORTS
-- ============================================

exports('OpenGarage', OpenGarage)
exports('GetCurrentGarage', function() return currentGarage end)
exports('GetCurrentVehicles', function() return currentVehicles end)

-- Export para actualizar currentGarage desde otros archivos
exports('UpdateCurrentGarage', function(garage)
    currentGarage = garage
end)
