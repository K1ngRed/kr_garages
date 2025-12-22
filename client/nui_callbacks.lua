--[[
    client/nui_callbacks.lua
    Callbacks de la interfaz NUI
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Maneja toda la comunicación entre JS y Lua
--]]

while not FrameworkBridge do Wait(100) end

-- Control de UI
RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Spawn de vehículos
RegisterNUICallback('spawnVehicle', function(data, cb)
    cb('ok')
    
    if not data or not data.plate then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeUI' })
        FrameworkBridge.ShowNotification('~r~Error: Placa no proporcionada')
        return
    end
    
    local garage = exports['kr_garages']:GetCurrentGarage()
    local garageId = garage and garage.id or nil
    
    if not garageId then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeUI' })
        FrameworkBridge.ShowNotification('~r~Error: No se pudo determinar el garaje actual')
        return
    end
    
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
    
    FrameworkBridge.TriggerCallback('kr_garages:server:SpawnVehicle', function(success, vehicleData, errorMsg)
        if not success or not vehicleData then
            FrameworkBridge.ShowNotification('~r~' .. (errorMsg or 'Error al usar el vehículo'))
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'closeUI' })
            return
        end
        
        local spawnSuccess = pcall(function()
            SpawnVehicleFromData(vehicleData)
        end)
        
        if spawnSuccess then
            TriggerServerEvent('kr_garages:server:VehicleSpawnedNearby', data.plate)
        else
            FrameworkBridge.ShowNotification('~r~Error al spawnear el vehículo')
        end
        
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeUI' })
    end, data.plate, garageId)
end)

-- ============================================
-- REPAIR AND SPAWN VEHICLE
-- ============================================

RegisterNUICallback('repairAndSpawnVehicle', function(data, cb)
    -- Responder inmediatamente al NUI para evitar freeze
    cb('ok')
    
    if not data or not data.plate then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeUI' })
        FrameworkBridge.ShowNotification('~r~Error: Placa no proporcionada')
        return
    end
    
    -- Obtener garaje ANTES de cerrar la UI
    local garage = exports['kr_garages']:GetCurrentGarage()
    local garageId = garage and garage.id or nil
    local savedGarage = garage
    
    if not garageId or not savedGarage then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeUI' })
        FrameworkBridge.ShowNotification('~r~Error: No se pudo determinar el garaje actual')
        return
    end
    
    -- Cerrar UI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
    
    -- Eliminar el vehículo destruido si existe en el mundo
    local plateToFind = data.plate
    local worldVehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(worldVehicles) do
        if DoesEntityExist(veh) then
            local vehPlate = GetVehicleNumberPlateText(veh)
            if vehPlate then
                vehPlate = vehPlate:gsub('%s+', ' '):match('^%s*(.-)%s*$')
                if vehPlate == plateToFind then
                    SetEntityAsMissionEntity(veh, true, true)
                    DeleteVehicle(veh)
                    break
                end
            end
        end
    end
    
    -- Llamar al servidor para reparar y spawnear
    FrameworkBridge.TriggerCallback('kr_garages:server:RepairAndSpawnVehicle', function(success, vehicleData, errorMsg)
        if not success then
            FrameworkBridge.ShowNotification('~r~' .. (errorMsg or 'Error al reparar el vehículo'))
            return
        end
        
        if not vehicleData then
            FrameworkBridge.ShowNotification('~r~Error: No se recibieron datos del vehículo')
            return
        end
        
        if not savedGarage then
            FrameworkBridge.ShowNotification('~r~Error: Garaje no disponible')
            return
        end
        
        -- Restaurar currentGarage global con protección
        local updateSuccess, updateErr = pcall(function()
            exports['kr_garages']:UpdateCurrentGarage(savedGarage)
        end)
        
        if not updateSuccess then
            print('[KR_GARAGES] Error al restaurar garaje: ' .. tostring(updateErr))
        end
        
        -- Spawn del vehículo reparado con protección pcall
        local spawnSuccess = false
        local pcallSuccess, pcallErr = pcall(function()
            spawnSuccess = SpawnVehicleFromData(vehicleData)
        end)
        
        if not pcallSuccess then
            print('[KR_GARAGES] Error en SpawnVehicleFromData (repair): ' .. tostring(pcallErr))
            FrameworkBridge.ShowNotification('~r~Error al spawnear el vehículo reparado')
            return
        end
        
        if spawnSuccess then
            -- CRÍTICO: Notificar al servidor que el vehículo está spawneado cerca del jugador
            TriggerServerEvent('kr_garages:server:VehicleSpawnedNearby', data.plate)
            FrameworkBridge.ShowNotification('~g~Vehículo reparado y spawneado correctamente')
        else
            FrameworkBridge.ShowNotification('~y~Vehículo reparado pero hubo un problema al spawnearlo')
        end
    end, data.plate, garageId)
end)

-- ============================================
-- RECOVER AND SPAWN VEHICLE (exists in world)
-- ============================================

RegisterNUICallback('recoverAndSpawnVehicle', function(data, cb)
    -- Responder inmediatamente al NUI para evitar freeze
    cb('ok')
    
    if not data or not data.plate then
        FrameworkBridge.ShowNotification('~r~Error: Placa no proporcionada')
        return
    end
    
    -- Obtener garaje actual (NO cerrar la UI, se refrescará desde JS)
    local garage = exports['kr_garages']:GetCurrentGarage()
    local garageId = garage and garage.id or nil
    local savedGarage = garage
    
    if not garageId or not savedGarage then
        FrameworkBridge.ShowNotification('~r~Error: No se pudo determinar el garaje actual')
        return
    end
    
    -- Eliminar el vehículo que está en el mundo
    local plateToFind = data.plate
    local worldVehicles = GetGamePool('CVehicle')
    
    for _, veh in ipairs(worldVehicles) do
        if DoesEntityExist(veh) then
            local vehPlate = GetVehicleNumberPlateText(veh)
            if vehPlate then
                vehPlate = vehPlate:gsub('%s+', ' '):match('^%s*(.-)%s*$')
                if vehPlate == plateToFind then
                    SetEntityAsMissionEntity(veh, true, true)
                    DeleteVehicle(veh)
                    break
                end
            end
        end
    end
    
    -- Llamar al servidor para recuperar el vehículo al garaje actual
    FrameworkBridge.TriggerCallback('kr_garages:server:RecoverAndSpawnVehicle', function(success, vehicleData, errorMsg)
        if not success then
            FrameworkBridge.ShowNotification('~r~' .. (errorMsg or 'Error al recuperar el vehículo'))
            return
        end
        
        -- El vehículo fue recuperado y guardado en el garaje actual
        -- Eliminar el vehículo abandonado del mundo (si existe)
        TriggerServerEvent('kr_garages:server:DeleteWorldVehicle', data.plate)
        
        -- Notificar éxito
        FrameworkBridge.ShowNotification('~g~Vehículo recuperado y guardado en este garaje')
        
        -- La UI se refrescará automáticamente desde JavaScript
    end, data.plate, garageId)
end)

-- ============================================
-- REPAIR ONLY (sin usar del garaje)
-- ============================================

RegisterNUICallback('repairOnlyVehicle', function(data, cb)
    -- Responder inmediatamente al NUI
    cb('ok')
    
    if not data or not data.plate then
        FrameworkBridge.ShowNotification('~r~Error: Placa no proporcionada')
        return
    end
    
    -- Obtener garaje actual
    local garage = exports['kr_garages']:GetCurrentGarage()
    local garageId = garage and garage.id or nil
    
    -- Eliminar el vehículo del mundo si existe (para vehículos abandonados)
    local plateToFind = data.plate
    local worldVehicles = GetGamePool('CVehicle')
    for _, veh in ipairs(worldVehicles) do
        if DoesEntityExist(veh) then
            local vehPlate = GetVehicleNumberPlateText(veh)
            if vehPlate then
                vehPlate = vehPlate:gsub('%s+', ' '):match('^%s*(.-)%s*$')
                if vehPlate == plateToFind then
                    SetEntityAsMissionEntity(veh, true, true)
                    DeleteVehicle(veh)
                    break
                end
            end
        end
    end
    
    -- Llamar al servidor para solo reparar (sin spawn)
    FrameworkBridge.TriggerCallback('kr_garages:server:RepairOnlyVehicle', function(success, errorMsg)
        if not success then
            FrameworkBridge.ShowNotification('~r~' .. (errorMsg or 'Error al reparar el vehículo'))
            return
        end
        
        FrameworkBridge.ShowNotification('~g~Vehículo reparado correctamente. Ya puedes usarlo cuando quieras.')
    end, data.plate, garageId)
end)

-- ============================================
-- GPS TO IMPOUND (Vehículos Incautados)
-- ============================================

RegisterNUICallback('gpsToImpound', function(data, cb)
    cb('ok')
    
    if not data or not data.impoundId then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'closeUI' })
        FrameworkBridge.ShowNotification('~r~Error: Información del depósito no disponible')
        return
    end
    
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
    
    -- Buscar las coordenadas del impound
    local impoundCoords = nil
    for _, impound in ipairs(Config.Impounds or {}) do
        if impound.id == data.impoundId then
            impoundCoords = impound.coords
            break
        end
    end
    
    if not impoundCoords then
        FrameworkBridge.ShowNotification('~r~Error: No se encontró la ubicación del depósito')
        return
    end
    
    -- Activar GPS/Waypoint
    SetNewWaypoint(impoundCoords.x, impoundCoords.y)
    
    -- Notificar al jugador
    local impoundName = data.impoundName or 'Depósito'
    local fee = data.impoundFee or 500
    FrameworkBridge.ShowNotification(('~b~GPS activado: %s~n~~w~Ve al depósito para recuperar tu vehículo~n~~y~Tarifa: $%d'):format(impoundName, fee))
end)

RegisterNUICallback('storeVehicle', function(data, cb)
    -- Llamar directamente a la función global
    StoreVehicle()
    cb('ok')
end)

RegisterNUICallback('getVehicles', function(data, cb)
    local garageId = data and data.garageId or nil
    
    -- Obtener vehículos directamente del servidor (el cache ya fue actualizado por OpenGarage)
    FrameworkBridge.TriggerCallback('kr_garages:server:GetVehicles', function(vehicles)
        cb(vehicles or {})
    end, garageId)
end)

-- ============================================
-- VEHICLE TRANSFER
-- ============================================

RegisterNUICallback('transferVehicle', function(data, cb)
    if not data or not data.plate or not data.target or not data.transferType then
        cb('error')
        return
    end
    
    -- Normalizar target (convertir a número si es posible)
    local target = data.target
    local targetAsNumber = tonumber(target)
    if targetAsNumber then
        target = targetAsNumber
    end
    
    -- Enviar evento al servidor (arquitectura basada en npwd_jg_advancedgarages)
    TriggerServerEvent('kr_garages:server:TransferVehicle', data.plate, target, data.transferType)
    
    -- CRÍTICO: Refrescar la lista después de transferir
    -- Esperar a que el servidor procese la transferencia
    Citizen.SetTimeout(1500, function()
        local garage = exports['kr_garages']:GetCurrentGarage()
        if garage then
            FrameworkBridge.TriggerCallback('kr_garages:server:GetVehicles', function(vehicles)
                SendNUIMessage({
                    action = 'refreshVehicles',
                    vehicles = vehicles or {}
                })
            end, garage.id)
        end
    end)
    
    cb('ok')
end)

-- ============================================
-- BRING VEHICLE HERE (Traer vehículo aquí)
-- ============================================
RegisterNUICallback('bringVehicleHere', function(data, cb)
    cb('ok') -- Responder inmediatamente para no bloquear la UI
    
    if not data or not data.plate or not data.targetGarageId then
        FrameworkBridge.ShowNotification('~r~Datos inválidos')
        return
    end
    
    -- Llamar al servidor para transferir el vehículo al garaje actual
    TriggerServerEvent('kr_garages:server:BringVehicleHere', data.plate, data.targetGarageId)
    
    -- Refrescar la lista después de un momento
    Citizen.SetTimeout(1500, function()
        local garage = exports['kr_garages']:GetCurrentGarage()
        if garage then
            FrameworkBridge.TriggerCallback('kr_garages:server:GetVehicles', function(vehicles)
                SendNUIMessage({
                    action = 'refreshVehicles',
                    vehicles = vehicles or {}
                })
            end, garage.id)
        end
    end)
end)

-- Evento para refrescar vehículos después de transferir
RegisterNetEvent('kr_garages:client:VehicleTransferred', function()
    -- Obtener el garaje actual desde el export
    local garage = exports['kr_garages']:GetCurrentGarage()
    
    -- Esperar un momento para que la BD se actualice
    Citizen.Wait(1000)
    
    -- Si hay un garaje abierto, refrescar la lista
    if garage then
        FrameworkBridge.TriggerCallback('kr_garages:server:GetVehicles', function(vehicles)
            SendNUIMessage({
                action = 'refreshVehicles',
                vehicles = vehicles or {}
            })
        end, garage.id)
    end
end)

RegisterNUICallback('getNearbyPlayers', function(data, cb)
    FrameworkBridge.TriggerCallback('kr_garages:server:GetNearbyPlayers', function(players)
        if not players then
            cb({})
        else
            cb(players)
        end
    end)
end)

RegisterNUICallback('getPublicGarages', function(data, cb)
    -- Obtener garajes PÚBLICOS (no privados) para transferencia
    FrameworkBridge.TriggerCallback('kr_garages:server:GetPublicGarages', function(garages)
        if not garages then
            cb({})
        else
            cb(garages)
        end
    end)
end)

-- Store callback for async response
local pendingTransferGaragesCallback = nil
local transferGaragesTimeout = nil

RegisterNUICallback('getAllGaragesForTransfer', function(data, cb)
    -- Clear any existing timeout
    if transferGaragesTimeout then
        ClearTimeout(transferGaragesTimeout)
    end
    
    -- Store the callback to be called later
    pendingTransferGaragesCallback = cb
    
    -- Set timeout fallback (5 seconds)
    transferGaragesTimeout = SetTimeout(5000, function()
        if pendingTransferGaragesCallback then
            pendingTransferGaragesCallback({})
            pendingTransferGaragesCallback = nil
        end
    end)
    
    -- Trigger event to main client thread (where ESX is available)
    TriggerEvent('kr_garages:client:RequestTransferGarages')
end)

-- Event handler in main client thread
RegisterNetEvent('kr_garages:client:RequestTransferGarages')
AddEventHandler('kr_garages:client:RequestTransferGarages', function()
    -- Enviar evento al servidor
    TriggerServerEvent('kr_garages:server:GetTransferGarages')
end)

-- Recibir respuesta del servidor
RegisterNetEvent('kr_garages:client:ReceiveTransferGarages')
AddEventHandler('kr_garages:client:ReceiveTransferGarages', function(garages)
    -- Clear timeout
    if transferGaragesTimeout then
        ClearTimeout(transferGaragesTimeout)
        transferGaragesTimeout = nil
    end
    
    if pendingTransferGaragesCallback then
        pendingTransferGaragesCallback(garages or {})
        pendingTransferGaragesCallback = nil
    end
end)

RegisterNUICallback('checkInsideGarage', function(data, cb)
    -- Verificar si el jugador está dentro del área de un garaje
    cb({inside = isInsideGarageArea})
end)

RegisterNUICallback('getAvailableGarages', function(data, cb)
    -- Crear un pequeño delay para asegurar que currentGarage esté disponible
    CreateThread(function()
        local garages = {}
        local attempt = 0
        
        -- Intentar obtener el garaje actual
        while attempt < 10 do
            local currentGarage = exports['kr_garages']:GetCurrentGarage()
            
            if currentGarage then
                for _, g in pairs(Config.Garages) do
                    if g.id ~= currentGarage.id and g.vehicleType == currentGarage.vehicleType then
                        table.insert(garages, {id = g.id, name = g.name})
                    end
                end
                break
            end
            
            attempt = attempt + 1
            Wait(50)
        end
        
        cb(garages)
    end)
end)

-- ============================================
-- PRIVATE GARAGES - CRUD
-- ============================================

RegisterNUICallback('getPrivateGarages', function(data, cb)
    FrameworkBridge.TriggerCallback('kr_garages:server:GetPrivateGarages', function(garages)
        if not garages or type(garages) ~= 'table' then
            cb({})
        else
            cb(garages)
        end
    end)
end)

RegisterNUICallback('createPrivateGarage', function(data, cb)
    if not data or not data.name or not data.x or not data.y or not data.z then
        cb({ok = false, reason = 'Datos inválidos'})
        return
    end
    
    FrameworkBridge.TriggerCallback('kr_garages:server:CreatePrivateGarage', function(success, newId, message)
        if success then
            FrameworkBridge.ShowNotification('~g~Garaje privado creado (ID: ' .. tostring(newId) .. ')')
            
            -- Notificar a garage_markers para crear blip
            TriggerEvent('kr_garages:client:PrivateGarageCreated', {
                id = newId,
                name = data.name,
                type = data.type,
                x = data.x,
                y = data.y,
                z = data.z,
                heading = data.heading,
                radius = data.radius
            })
            
            cb({ok = true, id = newId})
        else
            FrameworkBridge.ShowNotification('~r~' .. (message or 'Error al crear garaje'))
            cb({ok = false, reason = message})
        end
    end, data)
end)

RegisterNUICallback('updatePrivateGarage', function(data, cb)
    if not data or not data.id then
        cb({ok = false, reason = 'ID inválido'})
        return
    end
    
    FrameworkBridge.TriggerCallback('kr_garages:server:UpdatePrivateGarage', function(success, message)
        if success then
            FrameworkBridge.ShowNotification('~b~Garaje actualizado')
            
            -- Notificar a garage_markers para actualizar blip
            TriggerEvent('kr_garages:client:PrivateGarageUpdated', data)
            
            cb({ok = true})
        else
            FrameworkBridge.ShowNotification('~r~' .. (message or 'Error al actualizar'))
            cb({ok = false, reason = message})
        end
    end, data)
end)

RegisterNUICallback('deletePrivateGarage', function(data, cb)
    if not data or not data.id then
        cb({ok = false, reason = 'ID inválido'})
        return
    end
    
    FrameworkBridge.TriggerCallback('kr_garages:server:DeletePrivateGarage', function(success, message)
        if success then
            FrameworkBridge.ShowNotification('~g~Garaje eliminado')
            
            -- Notificar a garage_markers para remover blip
            TriggerEvent('kr_garages:client:PrivateGarageDeleted', data.id)
            
            cb({ok = true})
        else
            FrameworkBridge.ShowNotification('~r~' .. (message or 'Error al eliminar'))
            cb({ok = false, reason = message})
        end
    end, tostring(data.id))
end)

-- ============================================
-- UTILITY
-- ============================================

RegisterNUICallback('getPlayerLocation', function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    cb({
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading
    })
end)

-- ============================================
-- GARAGE ACCESS SHARING
-- ============================================

RegisterNUICallback('getGarageMembers', function(data, cb)
    if not data or not data.garageId then
        cb({ok = false, reason = 'ID de garaje inválido', members = {}})
        return
    end
    
    FrameworkBridge.TriggerCallback('kr_garages:server:GetGarageMembers', function(success, message, members)
        cb({
            ok = success,
            reason = message,
            members = members or {}
        })
    end, data.garageId)
end)

RegisterNUICallback('getOnlinePlayers', function(data, cb)
    FrameworkBridge.TriggerCallback('kr_garages:server:GetOnlinePlayers', function(players)
        cb(players or {})
    end)
end)

RegisterNUICallback('addGarageMember', function(data, cb)
    if not data or not data.garageId or not data.identifier then
        cb({ok = false, reason = 'Datos inválidos'})
        return
    end
    
    FrameworkBridge.TriggerCallback('kr_garages:server:AddGarageMember', function(success, message)
        if success then
            FrameworkBridge.ShowNotification('~g~' .. message)
            cb({ok = true})
        else
            FrameworkBridge.ShowNotification('~r~' .. message)
            cb({ok = false, reason = message})
        end
    end, data.garageId, data.identifier)
end)

RegisterNUICallback('removeGarageMember', function(data, cb)
    if not data or not data.garageId or not data.identifier then
        cb({ok = false, reason = 'Datos inválidos'})
        return
    end
    
    FrameworkBridge.TriggerCallback('kr_garages:server:RemoveGarageMember', function(success, message)
        if success then
            FrameworkBridge.ShowNotification('~g~' .. message)
            cb({ok = true})
        else
            FrameworkBridge.ShowNotification('~r~' .. message)
            cb({ok = false, reason = message})
        end
    end, data.garageId, data.identifier)
end)

-- ============================================
-- PUBLIC GARAGES ADMIN
-- ============================================

RegisterNUICallback('getCurrentPosition', function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    cb({
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading
    })
end)

RegisterNUICallback('teleportToCoords', function(data, cb)
    cb('ok')
    
    if not data or not data.x or not data.y or not data.z then
        FrameworkBridge.ShowNotification('~r~Coordenadas inválidas')
        return
    end
    
    -- SEGURIDAD: Verificar permisos de admin en el servidor antes de teletransportar
    FrameworkBridge.TriggerCallback('kr_garages:server:CheckAdminPermission', function(isAdmin)
        if not isAdmin then
            FrameworkBridge.ShowNotification('~r~No tienes permisos para usar esta función')
            return
        end
        
        local ped = PlayerPedId()
        SetEntityCoords(ped, data.x, data.y, data.z, false, false, false, true)
        FrameworkBridge.ShowNotification('~g~Teletransportado al garaje')
    end)
end)

RegisterNUICallback('savePublicGarage', function(data, cb)
    cb('ok')
    
    if not data or not data.garage then
        FrameworkBridge.ShowNotification('~r~Datos del garaje inválidos')
        return
    end
    
    -- Guardar en el servidor (que escribirá a un archivo o tabla)
    TriggerServerEvent('kr_garages:server:SavePublicGarage', data.garage, data.isEdit)
end)

RegisterNUICallback('deletePublicGarage', function(data, cb)
    cb('ok')
    
    if not data or not data.garageId then
        FrameworkBridge.ShowNotification('~r~ID del garaje inválido')
        return
    end
    
    TriggerServerEvent('kr_garages:server:DeletePublicGarage', data.garageId)
end)

RegisterNetEvent('kr_garages:client:PublicGarageSaved')
AddEventHandler('kr_garages:client:PublicGarageSaved', function(success, message)
    if success then
        FrameworkBridge.ShowNotification('~g~' .. (message or 'Garaje guardado correctamente'))
    else
        FrameworkBridge.ShowNotification('~r~' .. (message or 'Error al guardar el garaje'))
    end
end)
