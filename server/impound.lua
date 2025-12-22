--[[
    server/impound.lua
    Lógica del servidor para depósito vehicular
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Este archivo maneja base de datos y validaciones de seguridad
--]]

-- Cache de jobs autorizados
local IMPOUND_JOBS_CACHE = {}
for _, job in ipairs(Config.ImpoundJobs or {'police'}) do
    IMPOUND_JOBS_CACHE[job] = true
end

local function CanImpoundVehicles(xPlayer)
    if not xPlayer then return false end
    local jobName = FrameworkBridge.GetJobName(xPlayer)
    return IMPOUND_JOBS_CACHE[jobName] == true
end

local function GetImpoundById(impoundId)
    for _, impound in ipairs(Config.Impounds or {}) do
        if impound.id == impoundId then
            return impound
        end
    end
    return nil
end

-- Callbacks
FrameworkBridge.RegisterCallback('kr_garages:canImpound', function(source, cb)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    cb(CanImpoundVehicles(xPlayer))
end)

FrameworkBridge.RegisterCallback('kr_garages:getVehicleByPlate', function(source, cb, plate)
    if not plate or plate == '' then
        cb(nil)
        return
    end
    
    MySQL.single('SELECT * FROM owned_vehicles WHERE plate = ?', {plate}, function(vehicle)
        if vehicle then
            cb({
                plate = vehicle.plate,
                owner = vehicle.owner,
                model = vehicle.vehicle and json.decode(vehicle.vehicle).model or nil,
                vehicle = vehicle.vehicle
            })
        else
            cb(nil)
        end
    end)
end)

FrameworkBridge.RegisterCallback('kr_garages:getImpoundLocations', function(source, cb)
    local locations = {}
    for _, impound in ipairs(Config.Impounds or {}) do
        table.insert(locations, {
            id = impound.id,
            name = impound.name
        })
    end
    cb(locations)
end)

FrameworkBridge.RegisterCallback('kr_garages:getImpoundReasons', function(source, cb)
    cb(Config.ImpoundReasons or {})
end)

FrameworkBridge.RegisterCallback('kr_garages:getImpoundSettings', function(source, cb)
    cb(Config.ImpoundSettings or {})
end)

-- Callback para obtener vehículos confiscados del jugador (para NUI)
FrameworkBridge.RegisterCallback('kr_garages:server:GetPlayerImpoundedVehicles', function(source, cb)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then
        cb({})
        return
    end
    
    local identifier = FrameworkBridge.GetIdentifier(xPlayer)
    
    -- LEFT JOIN con users para obtener firstname y lastname
    MySQL.query([[
        SELECT kr.*, u.firstname, u.lastname 
        FROM kr_impound kr 
        LEFT JOIN users u ON kr.owner = u.identifier 
        WHERE kr.owner = ?
    ]], {identifier}, function(results)
        local vehicles = {}
        for _, v in ipairs(results or {}) do
            local impoundName = v.impound_id
            for _, imp in ipairs(Config.Impounds or {}) do
                if imp.id == v.impound_id then
                    impoundName = imp.name
                    break
                end
            end
            
            -- Decodificar vehicle props para obtener el modelo
            local props = {}
            if v.vehicle and type(v.vehicle) == 'string' and #v.vehicle > 2 then
                local ok, decoded = pcall(json.decode, v.vehicle)
                if ok and type(decoded) == 'table' then
                    props = decoded
                end
            end
            
            -- Obtener modelo del vehículo usando la misma lógica que GetVehicles
            local modelName = nil
            local modelLabel = nil
            
            -- Primero intentar con modelName guardado en props
            if props.modelName and type(props.modelName) == 'string' and props.modelName ~= '' then
                modelName = props.modelName
                modelLabel = props.modelLabel or modelName:upper()
            end
            
            -- Si no, intentar con model como string
            if not modelName and props.model and type(props.model) == 'string' and props.model ~= '' then
                modelName = props.model:lower()
                modelLabel = modelName:upper()
                
                if VehicleData then
                    local vInfo = VehicleData.GetByName(modelName)
                    if vInfo then
                        modelLabel = vInfo.label
                    end
                end
            end
            
            -- Si model es un número (hash), buscar en VehicleData
            if not modelName and props.model and type(props.model) == 'number' then
                if VehicleData then
                    local vInfo = VehicleData.GetByHash(props.model)
                    if vInfo then
                        modelName = vInfo.name
                        modelLabel = vInfo.label
                    end
                end
                
                -- Fallback: usar el campo model de kr_impound
                if not modelName and v.model then
                    local modelStr = tostring(v.model)
                    -- Si no es solo números, usarlo
                    if not modelStr:match('^%-?%d+$') then
                        modelName = modelStr:lower()
                        modelLabel = modelStr:upper()
                    end
                end
            end
            
            -- Último fallback
            if not modelName or modelName == '' then
                modelName = 'vehicle'
                modelLabel = 'Vehiculo'
            end
            
            -- Nombre del dueño (firstname + lastname)
            local ownerName = 'Desconocido'
            if v.firstname and v.lastname then
                ownerName = v.firstname .. ' ' .. v.lastname
            elseif v.firstname then
                ownerName = v.firstname
            end
            
            table.insert(vehicles, {
                id = v.id,
                plate = v.plate,
                model = modelName,  -- Nombre del modelo para imagen
                modelName = modelName,
                label = modelLabel, -- Label legible para mostrar
                ownerName = ownerName,
                impoundId = v.impound_id,
                impoundName = impoundName,
                fee = v.fee,
                reason = v.reason,
                impoundedAt = v.impounded_at
            })
        end
        cb(vehicles)
    end)
end)

-- ============================================
-- CONFISCAR VEHÍCULO
-- ============================================

RegisterNetEvent('kr_garages:server:ImpoundVehicle')
AddEventHandler('kr_garages:server:ImpoundVehicle', function(data)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    if not CanImpoundVehicles(xPlayer) then
        FrameworkBridge.ShowNotification(src, 'No tienes permisos para confiscar vehículos')
        return
    end
    
    local plate = data.plate
    local impoundId = data.impoundId or 'impound_a'
    local fee = tonumber(data.fee) or (Config.ImpoundSettings and Config.ImpoundSettings.DefaultFee) or 500
    local reason = data.reason or 'Sin razón especificada'
    local vehicleProps = data.vehicleProps
    local netId = data.netId
    
    local minFee = (Config.ImpoundSettings and Config.ImpoundSettings.MinFee) or 100
    local maxFee = (Config.ImpoundSettings and Config.ImpoundSettings.MaxFee) or 10000
    fee = math.max(minFee, math.min(maxFee, fee))
    
    local impound = GetImpoundById(impoundId)
    if not impound then
        FrameworkBridge.ShowNotification(src, 'Ubicación de impound no válida')
        return
    end
    
    MySQL.single('SELECT * FROM owned_vehicles WHERE plate = ?', {plate}, function(vehicle)
        if not vehicle then
            FrameworkBridge.ShowNotification(src, 'Vehículo no encontrado en la base de datos')
            return
        end
        
        local owner = vehicle.owner
        
        -- Usar vehicleProps del cliente si está disponible (tiene las propiedades actuales del vehículo)
        -- Si no, usar el vehicle de la base de datos
        local vehicleData = nil
        local modelName = nil
        
        if vehicleProps and type(vehicleProps) == 'table' then
            -- Las propiedades vienen del cliente con el estado actual del vehículo
            vehicleData = json.encode(vehicleProps)
            modelName = vehicleProps.modelName or vehicleProps.model
            
            -- Si modelName es un número (hash), intentar convertir
            if type(modelName) == 'number' then
                if VehicleData then
                    local vInfo = VehicleData.GetByHash(modelName)
                    if vInfo then
                        modelName = vInfo.name
                    end
                end
            end
        else
            vehicleData = vehicle.vehicle
            -- Intentar extraer el modelo de los datos existentes
            if type(vehicleData) == 'string' and vehicleData ~= '' then
                local ok, decoded = pcall(json.decode, vehicleData)
                if ok and decoded then
                    modelName = decoded.modelName or decoded.model
                end
            end
        end
        
        -- Asegurarnos de que modelName sea un string
        if type(modelName) == 'number' then
            modelName = tostring(modelName)
        elseif type(modelName) ~= 'string' or modelName == '' then
            modelName = 'vehicle'
        end
        
        local officerName = FrameworkBridge.GetPlayerName(xPlayer)
        local officerId = FrameworkBridge.GetIdentifier(xPlayer)
        
        MySQL.scalar('SELECT id FROM kr_impound WHERE plate = ?', {plate}, function(existingId)
            if existingId then
                FrameworkBridge.ShowNotification(src, 'Este vehículo ya está en el corralón')
                return
            end
            
            MySQL.insert('INSERT INTO kr_impound (owner, plate, vehicle, model, impound_id, fee, reason, impounded_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
                owner,
                plate,
                type(vehicleData) == 'string' and vehicleData or json.encode(vehicleData or {}),
                modelName,
                impoundId,
                fee,
                reason,
                officerId
            }, function(insertId)
                if insertId then
                    -- NO eliminar de owned_vehicles, solo marcar como no guardado
                    -- El vehículo seguirá apareciendo en garajes con estado "impounded"
                    MySQL.update('UPDATE owned_vehicles SET stored = 0, in_garage = 0 WHERE plate = ?', {plate}, function()
                        LogVehicleTransfer(plate, owner, 'IMPOUND', vehicle.parking or 'unknown', impoundId, 'impound')
                        
                        print(('[kr_garages] IMPOUND: %s confiscó vehículo %s - Razón: %s - Tarifa: $%d'):format(
                            officerName, plate, reason, fee
                        ))
                        
                        FrameworkBridge.ShowNotification(src, ('Vehículo %s confiscado exitosamente'):format(plate))
                        TriggerClientEvent('kr_garages:client:ImpoundSuccess', src, plate)
                        
                        if Config.ImpoundSettings and Config.ImpoundSettings.NotifyOwner then
                            local ownerPlayer = FrameworkBridge.GetPlayerByIdentifier(owner)
                            if ownerPlayer then
                                local ownerSrc = Framework.IsQB() and ownerPlayer.PlayerData.source or ownerPlayer.source
                                if ownerSrc then
                                    FrameworkBridge.ShowNotification(ownerSrc, ('Tu vehículo (%s) ha sido confiscado. Razón: %s. Tarifa: $%d'):format(plate, reason, fee))
                                end
                            end
                        end
                        
                        if netId then
                            TriggerClientEvent('kr_garages:client:DeleteImpoundedVehicle', -1, netId)
                        end
                    end)
                else
                    FrameworkBridge.ShowNotification(src, 'Error al confiscar el vehículo')
                end
            end)
        end)
    end)
end)

-- ============================================
-- OBTENER VEHÍCULOS EN IMPOUND
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:getMyImpoundedVehicles', function(source, cb)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then
        cb({})
        return
    end
    
    local identifier = FrameworkBridge.GetIdentifier(xPlayer)
    
    MySQL.query('SELECT * FROM kr_impound WHERE owner = ?', {identifier}, function(results)
        local vehicles = {}
        for _, v in ipairs(results or {}) do
            local impoundName = v.impound_id
            for _, imp in ipairs(Config.Impounds or {}) do
                if imp.id == v.impound_id then
                    impoundName = imp.name
                    break
                end
            end
            
            local model = v.model
            if not model and v.vehicle then
                local ok, decoded = pcall(json.decode, v.vehicle)
                if ok and decoded then
                    model = decoded.model or decoded.hash
                end
            end
            
            table.insert(vehicles, {
                id = v.id,
                plate = v.plate,
                model = model,
                impoundId = v.impound_id,
                impoundName = impoundName,
                fee = v.fee,
                reason = v.reason,
                impoundedAt = v.impounded_at
            })
        end
        cb(vehicles)
    end)
end)

FrameworkBridge.RegisterCallback('kr_garages:getAllImpoundedVehicles', function(source, cb, impoundId)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then
        cb({}, false)
        return
    end
    
    local isAdmin = IsPlayerAdmin(xPlayer)
    local canImpound = CanImpoundVehicles(xPlayer)
    
    if not isAdmin and not canImpound then
        cb({}, false)
        return
    end
    
    -- Determinar si es admin completo (para mostrar botón de eliminar)
    local isFullAdmin = isAdmin
    
    local query = [[
        SELECT kr.*, u.firstname, u.lastname 
        FROM kr_impound kr 
        LEFT JOIN users u ON kr.owner = u.identifier
    ]]
    local params = {}
    
    if impoundId and impoundId ~= '' then
        query = query .. ' WHERE kr.impound_id = ?'
        params = {impoundId}
    end
    
    query = query .. ' ORDER BY kr.impounded_at DESC'
    
    MySQL.query(query, params, function(results)
        local vehicles = {}
        for _, v in ipairs(results or {}) do
            local impoundName = v.impound_id
            for _, imp in ipairs(Config.Impounds or {}) do
                if imp.id == v.impound_id then
                    impoundName = imp.name
                    break
                end
            end
            
            -- Obtener modelo del vehículo
            local modelName = nil
            local modelLabel = nil
            
            -- Primero intentar desde v.model (campo de kr_impound)
            if v.model and type(v.model) == 'string' and v.model ~= '' then
                local modelStr = v.model
                if not modelStr:match('^%-?%d+$') then
                    modelName = modelStr:lower()
                    modelLabel = modelStr:upper()
                end
            end
            
            -- Si no, intentar desde vehicle props
            if not modelName and v.vehicle then
                local ok, decoded = pcall(json.decode, v.vehicle)
                if ok and decoded then
                    if decoded.modelName and type(decoded.modelName) == 'string' and decoded.modelName ~= '' then
                        modelName = decoded.modelName:lower()
                        modelLabel = decoded.modelLabel or modelName:upper()
                    elseif decoded.model and type(decoded.model) == 'string' and decoded.model ~= '' then
                        modelName = decoded.model:lower()
                        modelLabel = modelName:upper()
                    end
                end
            end
            
            -- Fallback
            if not modelName or modelName == '' then
                modelName = 'vehicle'
                modelLabel = 'Vehiculo'
            end
            
            -- Nombre del dueño (firstname + lastname)
            local ownerName = 'Desconocido'
            if v.firstname and v.lastname then
                ownerName = v.firstname .. ' ' .. v.lastname
            elseif v.firstname then
                ownerName = v.firstname
            end
            
            table.insert(vehicles, {
                id = v.id,
                plate = v.plate,
                owner = v.owner,
                ownerName = ownerName,
                model = modelName,
                modelName = modelName,
                label = modelLabel,
                impoundId = v.impound_id,
                impoundName = impoundName,
                fee = v.fee,
                reason = v.reason,
                impoundedBy = v.impounded_by,
                impoundedAt = v.impounded_at
            })
        end
        cb(vehicles, isFullAdmin)
    end)
end)

-- ============================================
-- LIBERAR VEHÍCULO DEL IMPOUND
-- ============================================

RegisterNetEvent('kr_garages:server:ReleaseFromImpound')
AddEventHandler('kr_garages:server:ReleaseFromImpound', function(data)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    local impoundRecordId = data.id
    local currentImpoundId = data.currentImpoundId  -- Impound donde está el jugador
    local identifier = FrameworkBridge.GetIdentifier(xPlayer)
    
    MySQL.single('SELECT * FROM kr_impound WHERE id = ?', {impoundRecordId}, function(record)
        if not record then
            FrameworkBridge.ShowNotification(src, 'Vehículo no encontrado en el corralón')
            return
        end
        
        if record.owner ~= identifier then
            FrameworkBridge.ShowNotification(src, 'Este vehículo no te pertenece')
            return
        end
        
        local fee = record.fee or 0
        local currentMoney = FrameworkBridge.GetMoney(xPlayer)
        local currentBank = FrameworkBridge.GetBankMoney(xPlayer)
        
        if currentMoney < fee and currentBank < fee then
            FrameworkBridge.ShowNotification(src, ('No tienes suficiente dinero. Necesitas $%d'):format(fee))
            return
        end
        
        local paid = false
        if currentMoney >= fee then
            FrameworkBridge.RemoveMoney(xPlayer, fee)
            paid = true
        elseif currentBank >= fee then
            FrameworkBridge.RemoveBankMoney(xPlayer, fee)
            paid = true
        end
        
        if not paid then
            FrameworkBridge.ShowNotification(src, 'Error al procesar el pago')
            return
        end
        
        -- Usar el impound actual (donde está el jugador) para el spawn point
        local impound = GetImpoundById(currentImpoundId) or GetImpoundById(record.impound_id)
        local spawnPoint = nil
        if impound and impound.spawnPoints and #impound.spawnPoints > 0 then
            spawnPoint = impound.spawnPoints[math.random(1, #impound.spawnPoints)]
        end
        
        -- Si aún no hay spawn point, buscar en cualquier impound configurado
        if not spawnPoint then
            for _, imp in ipairs(Config.Impounds or {}) do
                if imp.spawnPoints and #imp.spawnPoints > 0 then
                    spawnPoint = imp.spawnPoints[1]
                    break
                end
            end
        end
        
        -- Eliminar de kr_impound y actualizar owned_vehicles (ya existe, no insertar)
        MySQL.update('DELETE FROM kr_impound WHERE id = ?', {impoundRecordId}, function()
            -- Actualizar el vehículo en owned_vehicles
            MySQL.update('UPDATE owned_vehicles SET stored = 0, in_garage = 0 WHERE plate = ?', {record.plate}, function()
                LogVehicleTransfer(record.plate, 'IMPOUND', identifier, record.impound_id, 'central_garage', 'impound_release')
                
                print(('[kr_garages] IMPOUND RELEASE: %s recuperó vehículo %s - Pagó: $%d'):format(
                    FrameworkBridge.GetPlayerName(xPlayer), record.plate, fee
                ))
                
                FrameworkBridge.ShowNotification(src, ('Vehículo %s recuperado. Pagaste $%d'):format(record.plate, fee))
                
                -- Obtener modelo del vehículo de múltiples fuentes
                local model = nil
                local vehicleProps = nil
                
                -- 1. Intentar desde record.vehicle (kr_impound)
                if record.vehicle and type(record.vehicle) == 'string' and #record.vehicle > 2 then
                    local ok, decoded = pcall(json.decode, record.vehicle)
                    if ok and type(decoded) == 'table' then
                        vehicleProps = decoded
                        model = decoded.model or decoded.hash
                    end
                end
                
                -- 2. Si no hay modelo, intentar desde record.model
                if not model and record.model then
                    local modelStr = tostring(record.model)
                    if not modelStr:match('^%-?%d+$') and modelStr ~= '' and modelStr ~= 'nil' then
                        model = modelStr
                    elseif tonumber(record.model) then
                        model = tonumber(record.model)
                    end
                end
                
                -- 3. Si aún no hay modelo, buscar en owned_vehicles
                if not model then
                    local ownedVeh = MySQL.single.await('SELECT vehicle FROM owned_vehicles WHERE plate = ?', {record.plate})
                    if ownedVeh and ownedVeh.vehicle then
                        local ok, decoded = pcall(json.decode, ownedVeh.vehicle)
                        if ok and type(decoded) == 'table' then
                            vehicleProps = decoded
                            model = decoded.model or decoded.hash
                        end
                    end
                end
                
                -- Siempre spawnear el vehículo
                if spawnPoint then
                    TriggerClientEvent('kr_garages:client:ImpoundVehicleReleased', src, {
                        plate = record.plate,
                        vehicle = vehicleProps or record.vehicle,
                        model = model
                    }, {
                        x = spawnPoint.x,
                        y = spawnPoint.y,
                        z = spawnPoint.z,
                        w = spawnPoint.w or spawnPoint.heading or 0.0
                    })
                else
                    -- Fallback: spawnear cerca del jugador
                    TriggerClientEvent('kr_garages:client:SpawnVehicleNearPlayer', src, {
                        plate = record.plate,
                        vehicle = vehicleProps or record.vehicle,
                        model = model
                    })
                end
            end)
        end)
    end)
end)

-- ============================================
-- LIBERAR VEHÍCULO SIN CARGO (ADMIN)
-- ============================================

RegisterNetEvent('kr_garages:server:AdminReleaseFromImpound')
AddEventHandler('kr_garages:server:AdminReleaseFromImpound', function(data)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    local isAdmin = IsPlayerAdmin(xPlayer)
    local canImpound = CanImpoundVehicles(xPlayer)
    
    if not isAdmin and not canImpound then
        FrameworkBridge.ShowNotification(src, 'No tienes permisos para liberar vehículos')
        return
    end
    
    local impoundRecordId = data.id
    local targetGarage = data.garage or 'central_garage'
    
    MySQL.single('SELECT * FROM kr_impound WHERE id = ?', {impoundRecordId}, function(record)
        if not record then
            FrameworkBridge.ShowNotification(src, 'Vehículo no encontrado')
            return
        end
        
        local adminName = FrameworkBridge.GetPlayerName(xPlayer)
        
        -- Eliminar de kr_impound y actualizar owned_vehicles (ya existe)
        MySQL.update('DELETE FROM kr_impound WHERE id = ?', {impoundRecordId}, function()
            MySQL.update('UPDATE owned_vehicles SET stored = 1, in_garage = 1, garage_id = ? WHERE plate = ?', {targetGarage, record.plate}, function()
                LogVehicleTransfer(record.plate, 'IMPOUND', record.owner, record.impound_id, targetGarage, 'admin_release')
                
                print(('[kr_garages] ADMIN IMPOUND RELEASE: %s liberó vehículo %s sin cargo'):format(adminName, record.plate))
                
                FrameworkBridge.ShowNotification(src, ('Vehículo %s liberado al garaje'):format(record.plate))
                
                local ownerPlayer = FrameworkBridge.GetPlayerByIdentifier(record.owner)
                if ownerPlayer then
                    local ownerSrc = Framework.IsQB() and ownerPlayer.PlayerData.source or ownerPlayer.source
                    if ownerSrc then
                        FrameworkBridge.ShowNotification(ownerSrc, ('Tu vehículo (%s) ha sido liberado del corralón'):format(record.plate))
                    end
                end
            end)
        end)
    end)
end)

-- ============================================
-- LIBERAR VEHÍCULO SIN CARGO (POLICÍA)
-- ============================================

RegisterNetEvent('kr_garages:server:PoliceReleaseFromImpound')
AddEventHandler('kr_garages:server:PoliceReleaseFromImpound', function(data)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    local isAdmin = IsPlayerAdmin(xPlayer)
    local canImpound = CanImpoundVehicles(xPlayer)
    
    if not isAdmin and not canImpound then
        FrameworkBridge.ShowNotification(src, 'No tienes permisos para liberar vehículos')
        return
    end
    
    local impoundRecordId = data.id
    local targetGarage = data.garage or 'central_garage'
    
    MySQL.single('SELECT * FROM kr_impound WHERE id = ?', {impoundRecordId}, function(record)
        if not record then
            FrameworkBridge.ShowNotification(src, 'Vehículo no encontrado')
            return
        end
        
        local officerName = FrameworkBridge.GetPlayerName(xPlayer)
        
        -- Eliminar de kr_impound y actualizar owned_vehicles
        MySQL.update('DELETE FROM kr_impound WHERE id = ?', {impoundRecordId}, function()
            MySQL.update('UPDATE owned_vehicles SET stored = 1, in_garage = 1, garage_id = ? WHERE plate = ?', {targetGarage, record.plate}, function()
                LogVehicleTransfer(record.plate, 'IMPOUND', record.owner, record.impound_id, targetGarage, 'police_release')
                
                print(('[kr_garages] POLICE IMPOUND RELEASE: %s liberó vehículo %s sin cargo'):format(officerName, record.plate))
                
                FrameworkBridge.ShowNotification(src, ('Vehículo %s liberado al garaje del dueño'):format(record.plate))
                
                -- Notificar al dueño si está conectado
                local ownerPlayer = FrameworkBridge.GetPlayerByIdentifier(record.owner)
                if ownerPlayer then
                    local ownerSrc = Framework.IsQB() and ownerPlayer.PlayerData.source or ownerPlayer.source
                    if ownerSrc then
                        FrameworkBridge.ShowNotification(ownerSrc, ('Tu vehículo (%s) ha sido liberado del corralón'):format(record.plate))
                    end
                end
            end)
        end)
    end)
end)

-- ============================================
-- ELIMINAR VEHÍCULO DEL SISTEMA (ADMIN-ONLY)
-- ============================================

RegisterNetEvent('kr_garages:server:DeleteFromImpound')
AddEventHandler('kr_garages:server:DeleteFromImpound', function(data)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    -- SOLO ADMINS pueden eliminar vehículos del sistema
    local isAdmin = IsPlayerAdmin(xPlayer)
    
    if not isAdmin then
        FrameworkBridge.ShowNotification(src, 'Solo administradores pueden eliminar vehículos del sistema')
        return
    end
    
    local impoundRecordId = data.id
    
    MySQL.single('SELECT * FROM kr_impound WHERE id = ?', {impoundRecordId}, function(record)
        if not record then
            FrameworkBridge.ShowNotification(src, 'Vehículo no encontrado')
            return
        end
        
        local adminName = FrameworkBridge.GetPlayerName(xPlayer)
        local plate = record.plate
        
        -- Eliminar de kr_impound
        MySQL.update('DELETE FROM kr_impound WHERE id = ?', {impoundRecordId}, function()
            -- Eliminar de owned_vehicles (eliminar permanentemente)
            MySQL.update('DELETE FROM owned_vehicles WHERE plate = ?', {plate}, function()
                print(('[kr_garages] ADMIN DELETE: %s eliminó permanentemente vehículo %s del sistema'):format(adminName, plate))
                
                FrameworkBridge.ShowNotification(src, ('Vehículo %s eliminado permanentemente del sistema'):format(plate))
            end)
        end)
    end)
end)

-- ============================================
-- COMANDOS DE IMPOUND
-- ============================================

RegisterCommand('confiscar', function(source, args, rawCommand)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    if not CanImpoundVehicles(xPlayer) then
        FrameworkBridge.ShowNotification(src, 'No tienes permisos para usar este comando')
        return
    end
    
    TriggerClientEvent('kr_garages:client:OpenImpoundMenu', src)
end, false)

RegisterCommand('verimpound', function(source, args, rawCommand)
    local src = source
    local xPlayer = FrameworkBridge.GetPlayer(src)
    if not xPlayer then return end
    
    local isAdmin = IsPlayerAdmin(xPlayer)
    local canImpound = CanImpoundVehicles(xPlayer)
    
    if not isAdmin and not canImpound then
        FrameworkBridge.ShowNotification(src, 'No tienes permisos para usar este comando')
        return
    end
    
    TriggerClientEvent('kr_garages:client:OpenImpoundAdmin', src)
end, false)
