--[[
    client/store.lua
    Función para guardar vehículos
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Valida permisos y guarda propiedades del vehículo
--]]

while not FrameworkBridge do Wait(100) end

function StoreVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    
    if veh == 0 then
        FrameworkBridge.ShowNotification('~r~Debes estar en un vehículo')
        return
    end

    if GetPedInVehicleSeat(veh, -1) ~= ped then
        FrameworkBridge.ShowNotification('~r~Debes estar al volante para guardar el vehículo')
        return
    end

    if not currentGarage then
        FrameworkBridge.ShowNotification('~r~No estás en un garaje apto para guardar vehículos')
        return
    end
    
    -- Bloquear vehículos de trabajo en garajes incorrectos
    local plate = FrameworkBridge.GetPlate(veh)
    local garageType = currentGarage.garageType or 'public'
    local garageJob = currentGarage.job
    
    -- Verificar si es un vehículo policial (placa que empieza con PD)
    local isPoliceVehicle = false
    if plate and string.sub(plate, 1, 2) == 'PD' then
        isPoliceVehicle = true
    end
    
    -- Verificar usando export de Tk_policiatrabajo si está disponible (opcional)
    if not isPoliceVehicle then
        local success, result = pcall(function()
            if GetResourceState('Tk_policiatrabajo') == 'started' then
                return exports['Tk_policiatrabajo']:IsPoliceVehicle(veh)
            end
            return false
        end)
        if success and result then
            isPoliceVehicle = true
        end
    end
    
    -- También verificar por placa spawneada (opcional)
    if not isPoliceVehicle then
        local success, result = pcall(function()
            if GetResourceState('Tk_policiatrabajo') == 'started' then
                return exports['Tk_policiatrabajo']:IsPoliceSpawnedVehicle(veh)
            end
            return false
        end)
        if success and result then
            isPoliceVehicle = true
        end
    end
    
    -- Lógica de bloqueo para vehículos policiales
    if isPoliceVehicle then
        -- Si es garaje de trabajo de policía, permitir guardar
        if garageType == 'job' and garageJob == 'police' then
            -- Vehículo policial temporal - eliminar directamente sin guardar en BD
            local playerPed = PlayerPedId()
            if GetVehiclePedIsIn(playerPed, false) == veh then
                TaskLeaveVehicle(playerPed, veh, 0)
                Wait(1500)
            end
            
            -- Eliminar de forma segura
            SetEntityAsMissionEntity(veh, true, true)
            if NetworkGetEntityIsNetworked(veh) then
                local timeout = 0
                while not NetworkHasControlOfEntity(veh) and timeout < 30 do
                    NetworkRequestControlOfEntity(veh)
                    Wait(100)
                    timeout = timeout + 1
                end
            end
            DeleteVehicle(veh)
            
            -- Notificar a Tk_policiatrabajo para limpiar su registro (si existe)
            pcall(function()
                if GetResourceState('Tk_policiatrabajo') == 'started' then
                    TriggerEvent('Tk_policiatrabajo:vehicleStored', plate)
                end
            end)
            
            FrameworkBridge.ShowNotification('~g~Vehículo policial guardado correctamente')
            return
        else
            -- Bloqueado - no es un garaje de policía
            FrameworkBridge.ShowNotification('~r~Los vehículos policiales solo pueden guardarse en garajes de la policía')
            return
        end
    end
    
    -- Verificar si es un vehículo EMS (placa que empieza con EMS)
    local isEMSVehicle = false
    if plate and string.sub(plate, 1, 3) == 'EMS' then
        isEMSVehicle = true
    end
    
    -- Lógica de bloqueo para vehículos EMS
    if isEMSVehicle then
        -- Si es garaje de trabajo de ambulancia, permitir guardar
        if garageType == 'job' and garageJob == 'ambulance' then
            -- Vehículo EMS temporal - eliminar directamente sin guardar en BD
            local playerPed = PlayerPedId()
            if GetVehiclePedIsIn(playerPed, false) == veh then
                TaskLeaveVehicle(playerPed, veh, 0)
                Wait(1500)
            end
            
            SetEntityAsMissionEntity(veh, true, true)
            if NetworkGetEntityIsNetworked(veh) then
                local timeout = 0
                while not NetworkHasControlOfEntity(veh) and timeout < 30 do
                    NetworkRequestControlOfEntity(veh)
                    Wait(100)
                    timeout = timeout + 1
                end
            end
            DeleteVehicle(veh)
            
            FrameworkBridge.ShowNotification('~g~Vehículo de emergencias guardado correctamente')
            return
        else
            -- Bloqueado - no es un garaje de EMS
            FrameworkBridge.ShowNotification('~r~Los vehículos de emergencias solo pueden guardarse en garajes de EMS')
            return
        end
    end
    -- ============================================
    
    -- Verificar distancia al garaje antes de guardar
    local garageCoords = nil
    if currentGarage.coords then
        garageCoords = vector3(currentGarage.coords.x, currentGarage.coords.y, currentGarage.coords.z)
    elseif currentGarage.x and currentGarage.y and currentGarage.z then
        garageCoords = vector3(currentGarage.x, currentGarage.y, currentGarage.z)
    end
    
    if garageCoords then
        local vehCoords = GetEntityCoords(veh)
        local distance = #(vehCoords - garageCoords)
        local maxStoreDistance = Config.MaxStoreDistance or 50.0
        
        -- Ajustar distancia máxima según tipo de garaje
        if currentGarage.type == 'air' then
            maxStoreDistance = math.max(maxStoreDistance, 200.0)
        elseif currentGarage.type == 'boat' then
            maxStoreDistance = math.max(maxStoreDistance, 150.0)
        elseif currentGarage.garageType == 'private' or currentGarage.owner then
            maxStoreDistance = math.max(maxStoreDistance, 100.0)
        else
            maxStoreDistance = math.max(maxStoreDistance, 50.0)
        end
        
        if distance > maxStoreDistance then
            FrameworkBridge.ShowNotification(('~r~Estás demasiado lejos del garaje (%.0fm). Acércate a menos de %.0fm'):format(distance, maxStoreDistance))
            return
        end
    end
    
    -- Obtener el nombre del modelo de forma confiable
    local modelHash = GetEntityModel(veh)
    
    -- MÉTODO 1: GetEntityArchetypeName (MÁS CONFIABLE para addons)
    local modelName = nil
    local archName = GetEntityArchetypeName(veh)
    if archName and archName ~= '' and archName ~= 'NULL' then
        modelName = string.lower(archName)
    end
    
    -- MÉTODO 2: Intentar VehicleData (base de datos local)
    if not modelName or modelName == '' then
        if VehicleData and VehicleData.HashToName then
            modelName = VehicleData.HashToName(modelHash)
        end
    end
    
    -- MÉTODO 3: GetDisplayNameFromVehicleModel (SOLO para vehículos vanilla)
    if not modelName or modelName == '' then
        local displayName = GetDisplayNameFromVehicleModel(modelHash)
        if displayName and displayName ~= '' and displayName ~= 'CARNOTFOUND' then
            modelName = string.lower(displayName):gsub('%s+', '_')
        end
    end
    
    -- MÉTODO 4: Búsqueda inversa para vehículos vanilla conocidos
    if not modelName or modelName == '' then
        local commonModels = {
            'buzzard', 'frogger', 'maverick', 'polmav', 'swift', 'swift2', 'supervolito', 'supervolito2',
            'valkyrie', 'valkyrie2', 'volatus', 'annihilator', 'savage', 'hunter', 'akula', 'havok',
            'cuban800', 'dodo', 'duster', 'luxor', 'luxor2', 'mammatus', 'miljet', 'nimbus',
            'shamal', 'velum', 'velum2', 'vestra', 'hydra', 'lazer', 'titan', 'besra',
            'dinghy', 'dinghy2', 'dinghy3', 'dinghy4', 'jetmax', 'marquis', 'seashark', 'seashark2',
            'seashark3', 'speeder', 'speeder2', 'squalo', 'suntrap', 'toro', 'toro2', 'tropic',
            'adder', 'banshee2', 'bullet', 'cheetah', 'entityxf', 'entity2', 'entity3', 'fmj',
            'gp1', 'infernus', 'italigtb', 'italigtb2', 'nero', 'nero2', 'osiris', 'penetrator',
            'pfister811', 'reaper', 'sc1', 't20', 'taipan', 'tempesta', 'turismor', 'tyrus',
            'vacca', 'vagner', 'visione', 'voltic', 'xa21', 'zentorno', 'prototipo'
        }
        
        for _, testModel in ipairs(commonModels) do
            local testHash = GetHashKey(testModel)
            if testHash == modelHash then
                modelName = testModel
                break
            end
        end
    end
    
    -- ÚLTIMO RECURSO: Guardar el hash como fallback
    if not modelName or modelName == '' then
        print(('[kr_garages] WARNING: Could not determine model name for hash %s, using hash'):format(modelHash))
    end
    
    local props = FrameworkBridge.GetVehicleProperties(veh)
    local fuel = GetFuelLevel(veh)
    local engine = GetVehicleEngineHealth(veh)
    local body = GetVehicleBodyHealth(veh)
    local vehClass = GetVehicleClass(veh)
    
    -- CRÍTICO: Guardar el hash del modelo para registro dinámico
    props.modelHash = modelHash
    props.class = vehClass
    props.vehicleClass = vehClass
    
    -- Guardar el nombre del modelo en múltiples campos
    if modelName and type(modelName) == 'string' and modelName ~= '' then
        local cleanModelName = string.lower(modelName):gsub('%s+', '_')
        props.model = cleanModelName
        props.modelName = cleanModelName
        local displayLabel = GetDisplayNameFromVehicleModel(modelHash) or cleanModelName
        props.modelLabel = displayLabel
    elseif props.model and type(props.model) == 'number' then
        local displayName = GetDisplayNameFromVehicleModel(props.model)
        if displayName and displayName ~= '' and displayName ~= 'CARNOTFOUND' then
            props.modelName = string.lower(displayName)
            props.modelLabel = displayName
        else
            props.modelName = tostring(props.model)
            props.modelLabel = 'Vehicle'
        end
    else
        props.model = modelHash
        props.modelName = tostring(modelHash)
        props.modelLabel = 'Vehicle'
        print(('[kr_garages] WARNING: Saving vehicle with hash only: %s'):format(modelHash))
    end
    
    -- Verificar tipo de vehículo vs tipo de garaje usando VehicleData
    local garageVehicleType = currentGarage.type or currentGarage.vehicleType or 'car'
    
    local vehicleType = 'car'
    local isCompatible = true
    
    if VehicleData and VehicleData.GetVehicleType then
        vehicleType = VehicleData.GetVehicleType(props.model or modelHash) or 'car'
    end
    
    if VehicleData and VehicleData.CanStoreInGarage then
        isCompatible = VehicleData.CanStoreInGarage(props.model or modelHash, garageVehicleType)
    end
    
    if not isCompatible then
        FrameworkBridge.ShowNotification(('~r~Este tipo de vehículo (%s) no puede guardarse en este garaje (%s)'):format(vehicleType, garageVehicleType))
        return
    end
    
    -- Añadir tipo de vehículo a las props
    props._vehicleType = vehicleType
    
    -- Añadir fuel, engine, body a las props para el servidor
    props.fuelLevel = fuel
    props.engineHealth = engine
    props.bodyHealth = body
    
    FrameworkBridge.TriggerCallback('kr_garages:server:StoreVehicle', function(success, message)
        if success then
            FrameworkBridge.ShowNotification('~g~Vehículo guardado exitosamente')
            SetEntityAsMissionEntity(veh, true, true)
            
            -- Solicitar control del vehículo antes de eliminarlo
            local timeout = 0
            while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                NetworkRequestControlOfEntity(veh)
                Wait(50)
                timeout = timeout + 1
            end
            
            DeleteVehicle(veh)
            
            -- Remover de tracking
            if spawnedVehicles[plate] then
                spawnedVehicles[plate] = nil
            end
            
            SetNuiFocus(false, false)
            FrameworkBridge.ShowNotification('~g~Vehículo guardado')
        else
            FrameworkBridge.ShowNotification('~r~' .. message)
        end
    end, plate, currentGarage.id, props)
end

-- ============================================
-- EXPORTS
-- ============================================

exports('StoreVehicle', StoreVehicle)

-- Export para garajes privados
exports('StoreVehicleInPrivateGarage', function(garage)
    currentGarage = garage
    StoreVehicle()
end)

-- Registrar también como evento para compatibilidad
RegisterNetEvent('kr_garages:client:StoreVehicle', function()
    StoreVehicle()
end)

-- Evento para borrar vehículo después de guardarlo rápidamente
RegisterNetEvent('kr_garages:client:VehicleStored')
AddEventHandler('kr_garages:client:VehicleStored', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    
    if veh ~= 0 then
        TaskLeaveVehicle(ped, veh, 0)
        Wait(1500)
        FrameworkBridge.DeleteVehicle(veh)
    end
end)
