--[[
    server/vehicles.lua
    GetVehicles, StoreVehicle, SpawnVehicle
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Lógica principal de garajes - base de datos y spawning
--]]

-- Cache de vehículos en mundo
playerNearbyVehicles = playerNearbyVehicles or {}
playerWorldVehicles = playerWorldVehicles or {}

function VehicleIsNearby(identifier, plate)
    return playerNearbyVehicles[identifier] and playerNearbyVehicles[identifier][plate] or false
end

function VehicleExistsInWorld(identifier, plate)
    return playerWorldVehicles[identifier] and playerWorldVehicles[identifier][plate] or false
end

-- Cliente confirma spawn
RegisterNetEvent('kr_garages:server:VehicleSpawnedNearby', function(plate)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    local identifier = GetPlayerIdentifier(xPlayer)
    
    if not plate or type(plate) ~= 'string' then return end
    
    if not playerNearbyVehicles[identifier] then
        playerNearbyVehicles[identifier] = {}
    end
    playerNearbyVehicles[identifier][plate] = true
    
    if not playerWorldVehicles[identifier] then
        playerWorldVehicles[identifier] = {}
    end
    playerWorldVehicles[identifier][plate] = true
end)

-- GetVehicles callback
FrameworkBridge.RegisterCallback('kr_garages:server:GetVehicles', function(source, cb, garageId)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb({}) end
    local identifier = GetPlayerIdentifier(xPlayer)

    -- Primero obtener los vehículos incautados del jugador
    MySQL.query('SELECT plate, impound_id, fee FROM kr_impound WHERE owner = ?', {identifier}, function(impoundedRows)
        local impoundedVehicles = {}
        for _, imp in ipairs(impoundedRows or {}) do
            -- Obtener nombre del impound
            local impoundName = imp.impound_id
            for _, impoundConfig in ipairs(Config.Impounds or {}) do
                if impoundConfig.id == imp.impound_id then
                    impoundName = impoundConfig.name
                    break
                end
            end
            impoundedVehicles[imp.plate] = {
                impoundId = imp.impound_id,
                impoundName = impoundName,
                fee = imp.fee
            }
        end

        local function processVehicles(garageType)
            MySQL.query('SELECT plate, vehicle, fuel, engine, body, in_garage, garage_id FROM owned_vehicles WHERE owner = ?', {
                identifier
            }, function(rows)
                local list = {}
                for _, r in ipairs(rows or {}) do
                    local props = {}
                    if type(r.vehicle) == 'string' and #r.vehicle > 2 then
                        local ok, data = pcall(json.decode, r.vehicle)
                        if ok and type(data) == 'table' then props = data end
                    end
                
                local vehClass = props.class or props.vehClass or props.vehicleClass
                local vehType = GetVehicleTypeByClass(vehClass)
                
                local modelName = nil
                local modelLabel = nil
                
                if props.modelName and type(props.modelName) == 'string' and props.modelName ~= '' then
                    modelName = props.modelName
                    modelLabel = props.modelLabel or GenerateVehicleLabel(modelName)
                end
                
                if not modelName and props.model and type(props.model) == 'string' and props.model ~= '' then
                    modelName = props.model:lower()
                    modelLabel = GenerateVehicleLabel(modelName)
                    
                    if VehicleData then
                        local vInfo = VehicleData.GetByName(modelName)
                        if vInfo then
                            vehType = vInfo.type
                            modelLabel = vInfo.label
                        end
                    end
                end
                
                if not modelName and props.model and type(props.model) == 'number' then
                    if VehicleData then
                        local vInfo = VehicleData.GetByHash(props.model)
                        if vInfo then
                            modelName = vInfo.name
                            modelLabel = vInfo.label
                            vehType = vInfo.type
                        else
                            local friendlyName = GetVehicleModelName(props.model)
                            modelName = friendlyName:lower():gsub("%s+", "")
                            modelLabel = friendlyName
                        end
                    else
                        local friendlyName = GetVehicleModelName(props.model)
                        modelName = friendlyName:lower():gsub("%s+", "")
                        modelLabel = friendlyName
                    end
                end
                
                if not modelName or modelName == '' then
                    modelName = 'vehicle'
                    modelLabel = 'Vehicle'
                end
                
                props.modelName = modelName
                props.modelLabel = modelLabel
                
                if not vehType then
                    vehType = 'car'
                end
                
                props._vehicleType = vehType
                
                -- Filtrar por tipo de garaje
                local includeVehicle = false
                
                if not garageType or garageType == '' or garageType == 'car' then
                    if not vehType or vehType == 'car' then
                        includeVehicle = true
                    end
                elseif garageType == 'air' then
                    if vehType == 'air' then
                        includeVehicle = true
                    end
                elseif garageType == 'boat' then
                    if vehType == 'boat' then
                        includeVehicle = true
                    end
                else
                    if vehType == garageType then
                        includeVehicle = true
                    end
                end
                
                if includeVehicle then
                    local vehicleGarageId = r.garage_id
                    local requestedGarageId = garageId
                    local isInCurrentGarage = false
                    
                    local noGarageAssigned = (vehicleGarageId == nil or vehicleGarageId == '' or vehicleGarageId == 'NULL' or vehicleGarageId == 'central_garage')
                    
                    if noGarageAssigned then
                        isInCurrentGarage = true
                    elseif type(requestedGarageId) == 'number' then
                        local expectedKey = ('private_%s'):format(requestedGarageId)
                        local legacyKey = tostring(requestedGarageId)
                        local vehGarageStr = tostring(vehicleGarageId)
                        isInCurrentGarage = (vehGarageStr == expectedKey) or (vehGarageStr == legacyKey)
                    else
                        local vehGarageStr = tostring(vehicleGarageId)
                        local reqGarageStr = tostring(requestedGarageId)
                        isInCurrentGarage = (vehGarageStr == reqGarageStr)
                    end
                    
                    local garageName = nil
                    if not isInCurrentGarage then
                        if Config and Config.Garages then
                            for _, g in ipairs(Config.Garages) do
                                if g.id == tostring(vehicleGarageId) or g.id == vehicleGarageId then
                                    garageName = g.name
                                    break
                                end
                            end
                        end
                        
                        if not garageName then
                            local garageIdNum = tonumber(vehicleGarageId)
                            if garageIdNum then
                                local pgResult = MySQL.query.await('SELECT name FROM private_garages WHERE id = ?', { garageIdNum })
                                if pgResult and pgResult[1] and pgResult[1].name then
                                    garageName = pgResult[1].name
                                end
                            end
                        end
                    end
                    
                    local engineHealth = (r.engine ~= nil) and tonumber(r.engine) or 1000
                    local bodyHealth = (r.body ~= nil) and tonumber(r.body) or 1000
                    local fuelValue = (r.fuel ~= nil) and tonumber(r.fuel) or 100
                    local inGarage = (r.in_garage == 1 or r.in_garage == true)
                    
                    local isDestroyed = (engineHealth <= 0 and bodyHealth <= 0)
                    local isNearby = false
                    local isAbandoned = false
                    local existsInWorldDetected = false
                    
                    if not inGarage and not isDestroyed then
                        isNearby = VehicleIsNearby(identifier, r.plate)
                        existsInWorldDetected = VehicleExistsInWorld(identifier, r.plate)
                        
                        if isNearby then
                            isAbandoned = false
                        elseif existsInWorldDetected then
                            isAbandoned = true
                        else
                            isAbandoned = true
                            isNearby = false
                        end
                    end
                    
                    local repairCost = 0
                    local hasDamage = (engineHealth < 1000 or bodyHealth < 1000 or fuelValue < 100)
                    
                    if Config.RepairSystem and Config.RepairSystem.Enabled then
                        if isDestroyed then
                            repairCost = Config.RepairSystem.MaxRepairCost or 2000
                        elseif isAbandoned then
                            repairCost = Config.RepairSystem.MaxRepairCost or 2000
                        elseif hasDamage then
                            local engineDamage = math.max(0, 100 - (engineHealth / 10))
                            local bodyDamage = math.max(0, 100 - (bodyHealth / 10))
                            local fuelDamage = math.max(0, 100 - fuelValue)
                            local totalDamage = (engineDamage + bodyDamage + fuelDamage) / 3
                            repairCost = (Config.RepairSystem.RepairPrice or 100) + (totalDamage * (Config.RepairSystem.PricePerDamage or 15))
                            repairCost = math.min(repairCost, Config.RepairSystem.MaxRepairCost or 2000)
                        end
                    end
                    
                    -- Verificar si el vehículo está incautado
                    local impoundInfo = impoundedVehicles[r.plate]
                    local isImpounded = impoundInfo ~= nil
                    
                    list[#list+1] = {
                        plate = r.plate,
                        props = props,
                        fuel  = fuelValue,
                        engine = engineHealth,
                        body   = bodyHealth,
                        inGarage = r.in_garage,
                        garageId = r.garage_id,
                        isInCurrentGarage = isInCurrentGarage,
                        garageLocationName = garageName,
                        isDestroyed = isDestroyed,
                        isNearby = isNearby,
                        isAbandoned = isAbandoned,
                        existsInWorld = not inGarage,
                        repairCost = math.floor(repairCost),
                        recoverCost = isAbandoned and math.floor(repairCost) or 0,
                        -- Estado de incautación
                        isImpounded = isImpounded,
                        impoundId = impoundInfo and impoundInfo.impoundId or nil,
                        impoundName = impoundInfo and impoundInfo.impoundName or nil,
                        impoundFee = impoundInfo and impoundInfo.fee or nil
                    }
                end
            end
            
            cb(list)
            end)
        end

        if type(garageId) == 'number' then
            GetPrivateGarageType(garageId, function(gType)
                if not gType then
                    return cb({})
                end
                processVehicles(gType)
            end)
        else
            local garageType = 'car'
            if Config and Config.Garages then
                for _, g in ipairs(Config.Garages) do
                    if g.id == garageId then
                        garageType = g.vehicleType or g.type or 'car'
                        break
                    end
                end
            end
            processVehicles(garageType)
        end
    end)
end)

-- ============================================
-- STORE VEHICLE
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:StoreVehicle', function(source, cb, plate, garageId, props)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, 'Jugador inválido') end
    local identifier = GetPlayerIdentifier(xPlayer)
    local gkey = GetGarageKey(garageId)
    
    if not plate or type(plate) ~= 'string' then return cb(false, 'Placa inválida') end
    if #plate > 12 then return cb(false, 'Placa demasiado larga') end

    MySQL.query('SELECT in_garage FROM owned_vehicles WHERE plate = ? AND owner = ?', {
        plate, identifier
    }, function(checkRows)
        if not checkRows or not checkRows[1] then
            return cb(false, 'Vehículo no encontrado')
        end
        
        if checkRows[1].in_garage == 1 then
            return cb(false, 'Este vehículo ya está guardado en el garaje')
        end
        
        local vtype = (type(props) == 'table' and props._vehicleType) or nil
        local fuel = (type(props) == 'table' and props.fuelLevel) or 100
        local engine = (type(props) == 'table' and props.engineHealth) or 1000
        local body = (type(props) == 'table' and props.bodyHealth) or 1000
        
        if type(props) == 'table' then
            local modelHash = props.modelHash or nil
            local modelName = props.modelName or (type(props.model) == 'string' and props.model) or nil
            local vehicleClass = props.class or props.vehicleClass or 0
            
            if modelHash and modelName and VehicleData and VehicleData.RegisterVehicle then
                VehicleData.RegisterVehicle(modelHash, modelName, vehicleClass)
            end
        end
        
        local function _doUpdate()
            MySQL.update([[
                UPDATE owned_vehicles
                   SET garage_id = ?, fuel = ?, engine = ?, body = ?, vehicle = ?, in_garage = 1
                 WHERE plate = ? AND owner = ?
            ]], { gkey, fuel, engine, body, json.encode(props or {}), plate, identifier }, function(affected)
                cb(affected and affected > 0, affected and nil or 'No se guardó')
            end)
        end

        if type(garageId) == 'number' then
            if vtype then
                GetPrivateGarageType(garageId, function(gt)
                    if gt and not IsVehicleTypeCompatible(vtype, gt) then
                        return cb(false, ('Tipo no permitido. Garaje: %s, Vehículo: %s'):format(gt, vtype))
                    end
                    _doUpdate()
                end)
            else
                _doUpdate()
            end
        else
            if vtype and Config and Config.Garages then
                local garageType = nil
                for _, g in ipairs(Config.Garages) do
                    if g.id == garageId then
                        garageType = g.vehicleType or g.type
                        break
                    end
                end
                
                if garageType and not IsVehicleTypeCompatible(vtype, garageType) then
                    return cb(false, ('Este garaje solo acepta vehículos tipo %s'):format(garageType))
                end
            end
            _doUpdate()
        end
    end)
end)

-- ============================================
-- STORE VEHICLE QUICK (E press)
-- ============================================

RegisterNetEvent('kr_garages:server:StoreVehicleQuick', function(plate, garageId, vehicleProps)
    local source = source
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return end
    local identifier = GetPlayerIdentifier(xPlayer)
    local gkey = GetGarageKey(garageId)
    
    if not plate or type(plate) ~= 'string' then 
        FrameworkBridge.ShowNotification(source, '~r~Placa inválida')
        return 
    end
    if #plate > 12 then 
        TriggerClientEvent('esx:showNotification', source, '~r~Placa demasiado larga')
        return 
    end
    
    MySQL.query('SELECT in_garage, garage_id FROM owned_vehicles WHERE plate = ? AND owner = ?', {
        plate, identifier
    }, function(checkRows)
        if not checkRows or not checkRows[1] then
            TriggerClientEvent('esx:showNotification', source, '~r~Este vehículo no te pertenece')
            return
        end
        
        if checkRows[1].in_garage == 1 then
            TriggerClientEvent('esx:showNotification', source, '~r~Este vehículo ya está guardado')
            return
        end
        
        local vtype = (type(vehicleProps) == 'table' and vehicleProps._vehicleType) or nil
        
        local function _doQuickUpdate()
            local fuel = (type(vehicleProps) == 'table' and vehicleProps.fuelLevel) or 100
            local engine = (type(vehicleProps) == 'table' and vehicleProps.engineHealth) or 1000
            local body = (type(vehicleProps) == 'table' and vehicleProps.bodyHealth) or 1000
            
            MySQL.update([[
                UPDATE owned_vehicles
                   SET garage_id = ?, fuel = ?, engine = ?, body = ?, in_garage = 1
                 WHERE plate = ? AND owner = ?
            ]], { gkey, fuel, engine, body, plate, identifier }, function(affected)
                if affected and affected > 0 then
                    local garageName = 'el garaje'
                    if Config and Config.Garages then
                        for _, g in ipairs(Config.Garages) do
                            if g.id == garageId then
                                garageName = g.name
                                break
                            end
                        end
                    end
                    
                    TriggerClientEvent('esx:showNotification', source, '~g~Vehículo guardado en ' .. garageName)
                    TriggerClientEvent('kr_garages:client:VehicleStored', source)
                else
                    TriggerClientEvent('esx:showNotification', source, '~r~No se pudo guardar el vehículo')
                end
            end)
        end
        
        if type(garageId) == 'number' then
            if vtype then
                GetPrivateGarageType(garageId, function(gt)
                    if gt and not IsVehicleTypeCompatible(vtype, gt) then
                        TriggerClientEvent('esx:showNotification', source, ('~r~Tipo no permitido. Garaje: %s, Vehículo: %s'):format(gt, vtype))
                        return
                    end
                    _doQuickUpdate()
                end)
            else
                _doQuickUpdate()
            end
        else
            if vtype and Config and Config.Garages then
                local garageType = nil
                for _, g in ipairs(Config.Garages) do
                    if g.id == garageId then
                        garageType = g.vehicleType or g.type
                        break
                    end
                end
                
                if garageType and not IsVehicleTypeCompatible(vtype, garageType) then
                    TriggerClientEvent('esx:showNotification', source, ('~r~Este garaje solo acepta vehículos tipo %s'):format(garageType))
                    return
                end
            end
            _doQuickUpdate()
        end
    end)
end)

-- ============================================
-- SPAWN VEHICLE
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:SpawnVehicle', function(source, cb, plate, garageId)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, nil, 'Jugador inválido') end
    local identifier = GetPlayerIdentifier(xPlayer)
    if not plate or type(plate) ~= 'string' then return cb(false, nil, 'Placa inválida') end
    if #plate > 12 then return cb(false, nil, 'Placa demasiado larga') end

    MySQL.query('SELECT vehicle, plate, fuel, engine, body, in_garage, garage_id FROM owned_vehicles WHERE plate = ? AND owner = ?', {
        plate, identifier
    }, function(rows)
        if not rows or not rows[1] then return cb(false, nil, 'Vehículo no encontrado') end
        local row = rows[1]
        
        if row.in_garage == 0 then
            return cb(false, nil, 'Este vehículo ya está fuera del garaje')
        end
        
        local vehicleGarageId = row.garage_id
        local requestedGarageId = garageId
        local isInRequestedGarage = false
        
        local noGarageAssigned = (vehicleGarageId == nil or vehicleGarageId == '' or vehicleGarageId == 'NULL' or vehicleGarageId == 'central_garage')
        
        if noGarageAssigned then
            isInRequestedGarage = true
        elseif type(requestedGarageId) == 'number' then
            local expectedKey = ('private_%s'):format(requestedGarageId)
            local legacyKey = tostring(requestedGarageId)
            local vehGarageStr = tostring(vehicleGarageId)
            isInRequestedGarage = (vehGarageStr == expectedKey) or (vehGarageStr == legacyKey)
        else
            local vehGarageStr = tostring(vehicleGarageId)
            local reqGarageStr = tostring(requestedGarageId)
            isInRequestedGarage = (vehGarageStr == reqGarageStr)
        end
        
        if not isInRequestedGarage then
            return cb(false, nil, 'Este vehículo está en otro garaje. Debes transferirlo primero antes de poder usarlo.')
        end
        
        local props = {}
        if type(row.vehicle) == 'string' and #row.vehicle > 2 then
            local ok, data = pcall(json.decode, row.vehicle)
            if ok and type(data) == 'table' then props = data end
        end
        
        local model = nil
        
        if props.model and type(props.model) == 'string' and props.model ~= '' then
            model = string.lower(props.model)
        elseif props.modelName and type(props.modelName) == 'string' and props.modelName ~= '' then
            model = string.lower(props.modelName)
        elseif props.model and type(props.model) == 'number' then
            if VehicleData and VehicleData.GetByHash then
                local vehicleInfo = VehicleData.GetByHash(props.model)
                if vehicleInfo then
                    model = vehicleInfo.name
                end
            end
        end
        
        if not model or model == '' then
            local possibleModelSources = {
                props.modelLabel,
                props.vehicleModel,
                props.name,
                props.vehicle
            }
            
            for i, src in ipairs(possibleModelSources) do
                if src and type(src) == 'string' and src ~= '' then
                    model = string.lower(src:gsub("%s+", ""))
                    break
                end
            end
        end
        
        if not model or model == '' then
            if props.model and type(props.model) == 'number' then
                model = props.model
                print(('[kr_garages] WARNING: Using hash %s for spawn (no name found)'):format(tostring(props.model)))
            elseif props.modelHash and type(props.modelHash) == 'number' then
                model = props.modelHash
                print(('[kr_garages] WARNING: Using modelHash %s for spawn (no name found)'):format(tostring(props.modelHash)))
            else
                print(('[kr_garages] ERROR: Cannot determine vehicle model. Props: %s'):format(json.encode(props)))
                return cb(false, nil, 'No se pudo determinar el modelo del vehículo. Contacta a un admin.')
            end
        end
        
        props.model = model
        props.modelName = model
        
        MySQL.update('UPDATE owned_vehicles SET in_garage = 0 WHERE plate = ? AND owner = ?', 
            { plate, identifier }, 
            function(affectedRows)
                if not affectedRows or affectedRows == 0 then
                    return cb(false, nil, 'Error al marcar vehículo como fuera del garaje')
                end
                
                local coords, heading = vector3(0.0, 0.0, 72.0), 0.0

                local vehicleData = {
                    model = model,
                    vehicle = model,
                    props = props,
                    plate = row.plate,
                    fuel = row.fuel or 100,
                    engine = row.engine or 1000,
                    body = row.body or 1000
                }

                if type(garageId) == 'number' then
                    MySQL.query('SELECT spawn_x, spawn_y, spawn_z, spawn_h FROM private_garages WHERE id = ?', { garageId }, function(grows)
                        if grows and grows[1] then
                            vehicleData.coords = vector3(grows[1].spawn_x or 0.0, grows[1].spawn_y or 0.0, grows[1].spawn_z or 72.0)
                            vehicleData.heading = grows[1].spawn_h or 0.0
                        end
                        cb(true, vehicleData)
                    end)
                else
                    vehicleData.coords = coords
                    vehicleData.heading = heading
                    cb(true, vehicleData)
                end
            end
        )
    end)
end)
