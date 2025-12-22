-- server/garages_crud.lua

-- Esperar a que FrameworkBridge esté disponible
while not FrameworkBridge do
    Wait(100)
end

-- ============================================
-- GET PRIVATE GARAGES
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:GetPrivateGarages', function(source, cb)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then 
        cb({})
        return 
    end
    
    local identifier = xPlayer.identifier
    
    -- Verificar si el jugador es admin
    local isAdmin = false
    if Config and Config.AdminGroups then
        for _, group in ipairs(Config.AdminGroups) do
            if xPlayer.getGroup() == group then
                isAdmin = true
                break
            end
        end
    end
    
    -- Si es admin, obtener TODOS los garajes privados
    -- Si no, solo los garajes donde tiene acceso
    local query = ''
    local params = {}
    
    if isAdmin then
        query = 'SELECT * FROM private_garages ORDER BY id DESC'
        params = {}
    else
        query = [[
            SELECT DISTINCT pg.* 
            FROM private_garages pg
            LEFT JOIN private_garage_owners pgo ON pg.id = pgo.garage_id
            WHERE pg.owner = ? OR pgo.identifier = ?
            ORDER BY pg.id DESC
        ]]
        params = {identifier, identifier}
    end
    
    MySQL.query(query, params, function(result)
        if not result then
            cb({})
            return
        end
        
        -- Procesar coordenadas JSON
        local garages = {}
        for _, garage in ipairs(result) do
            local coords = {x = 0, y = 0, z = 0}
            
            if garage.coords then
                local success, decoded = pcall(json.decode, garage.coords)
                if success and decoded then
                    coords = decoded
                end
            end
            
            -- Determinar si el usuario es dueño o solo miembro
            local isOwner = (garage.owner == identifier)
            
            table.insert(garages, {
                id = garage.id,
                name = garage.name,
                owner = garage.owner,
                isOwner = isOwner,
                canEdit = isOwner or isAdmin, -- Los admins pueden editar todos los garajes
                type = garage.type or 'car',
                x = coords.x,
                y = coords.y,
                z = coords.z,
                coords = coords,
                heading = garage.heading or 0,
                radius = garage.radius or 10
            })
        end
        
        cb(garages)
    end)
end)

-- ============================================
-- CREATE PRIVATE GARAGE
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:CreatePrivateGarage', function(source, cb, data)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, nil, 'Error al obtener jugador') end
    
    -- Validar datos
    if not data or not data.name or not data.x or not data.y or not data.z then
        return cb(false, nil, 'Datos inválidos')
    end
    
    local identifier = xPlayer.identifier
    
    -- Insertar garaje con coordenadas de spawn
    MySQL.insert('INSERT INTO private_garages (name, owner, coords, heading, radius, type, spawn_x, spawn_y, spawn_z, spawn_h) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.name,
        identifier,
        json.encode({x = data.x, y = data.y, z = data.z}),
        data.heading or 0.0,
        data.radius or 10,
        data.type or 'car',
        data.x,
        data.y,
        data.z,
        data.heading or 0.0
    }, function(insertId)
        if insertId then
            -- Insertar propietarios adicionales si los hay
            if data.owners and type(data.owners) == 'table' then
                for _, owner in ipairs(data.owners) do
                    if owner.identifier and owner.identifier ~= identifier then
                        MySQL.insert('INSERT INTO private_garage_owners (garage_id, identifier, access_level) VALUES (?, ?, ?)', {
                            insertId,
                            owner.identifier,
                            'member'
                        })
                    end
                end
            end

            cb(true, insertId, 'Garaje creado correctamente')
        else
            cb(false, nil, 'Error en la base de datos')
        end
    end)
end)

-- ============================================
-- UPDATE PRIVATE GARAGE
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:UpdatePrivateGarage', function(source, cb, data)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, 'Error al obtener jugador') end
    
    if not data or not data.id then
        return cb(false, 'ID inválido')
    end
    
    local identifier = xPlayer.identifier
    
    -- Verificar si el jugador es admin
    local isAdmin = false
    if Config and Config.AdminGroups then
        for _, group in ipairs(Config.AdminGroups) do
            if xPlayer.getGroup() == group then
                isAdmin = true
                break
            end
        end
    end
    
    -- Si es admin, puede editar cualquier garaje
    -- Si no, solo puede editar garajes donde es dueño
    local query = ''
    local params = {}
    
    if isAdmin then
        query = 'SELECT * FROM private_garages WHERE id = ?'
        params = {data.id}
    else
        query = 'SELECT * FROM private_garages WHERE id = ? AND owner = ?'
        params = {data.id, identifier}
    end
    
    MySQL.query(query, params, function(result)
        if not result[1] then
            return cb(false, 'No eres el dueño de este garaje')
        end
        
        -- Actualizar garaje
        local updates = {}
        local values = {}
        
        if data.name then
            table.insert(updates, 'name = ?')
            table.insert(values, data.name)
        end
        
        if data.type then
            table.insert(updates, 'type = ?')
            table.insert(values, data.type)
        end
        
        if data.radius then
            table.insert(updates, 'radius = ?')
            table.insert(values, data.radius)
        end
        
        if #updates == 0 then
            return cb(false, 'No hay datos para actualizar')
        end
        
        table.insert(values, data.id)
        
        local query = 'UPDATE private_garages SET ' .. table.concat(updates, ', ') .. ' WHERE id = ?'
        
        MySQL.update(query, values, function(affectedRows)
            if affectedRows > 0 then
                -- Disparar evento al cliente para actualizar el cache
                TriggerClientEvent('kr_garages:client:PrivateGarageUpdated', source, {
                    id = data.id,
                    name = data.name,
                    type = data.type,
                    radius = data.radius
                })
                
                cb(true, 'Garaje actualizado')
            else
                cb(false, 'Error al actualizar')
            end
        end)
    end)
end)

-- ============================================
-- DELETE PRIVATE GARAGE
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:DeletePrivateGarage', function(source, cb, garageId)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, 'Error al obtener jugador') end
    
    if not garageId then
        return cb(false, 'ID inválido')
    end
    
    local identifier = xPlayer.identifier
    
    -- Verificar si el jugador es admin
    local isAdmin = false
    if Config and Config.AdminGroups then
        for _, group in ipairs(Config.AdminGroups) do
            if xPlayer.getGroup() == group then
                isAdmin = true
                break
            end
        end
    end
    
    -- Si es admin, puede eliminar cualquier garaje
    -- Si no, solo puede eliminar garajes donde es dueño
    local query = ''
    local params = {}
    
    if isAdmin then
        query = 'SELECT * FROM private_garages WHERE id = ?'
        params = {garageId}
    else
        query = 'SELECT * FROM private_garages WHERE id = ? AND owner = ?'
        params = {garageId, identifier}
    end
    
    MySQL.query(query, params, function(result)
        if not result[1] then
            return cb(false, isAdmin and 'Garaje no encontrado' or 'No eres el dueño de este garaje')
        end
        
        -- Eliminar propietarios asociados
        MySQL.update('DELETE FROM private_garage_owners WHERE garage_id = ?', {
            garageId
        }, function()
            -- Eliminar garaje
            MySQL.update('DELETE FROM private_garages WHERE id = ?', {
                garageId
            }, function(affectedRows)
                if affectedRows > 0 then
                    -- Mover vehículos al garaje central
                    MySQL.update('UPDATE owned_vehicles SET garage_id = ? WHERE garage_id = ?', {
                        'central_garage',
                        'private_' .. garageId
                    })
                    
                    -- Notificar a TODOS los clientes que el garaje fue eliminado
                    TriggerClientEvent('kr_garages:client:PrivateGarageDeleted', -1, garageId)
                    
                    cb(true, 'Garaje eliminado')
                else
                    cb(false, 'Error al eliminar')
                end
            end)
        end)
    end)
end)

-- ============================================
-- GET GARAGE OWNERS
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:GetGarageOwners', function(source, cb, garageId)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb({}) end
    
    MySQL.query([[
        SELECT pgo.*, u.firstname, u.lastname 
        FROM private_garage_owners pgo
        LEFT JOIN users u ON pgo.identifier = u.identifier
        WHERE pgo.garage_id = ?
    ]], {
        garageId
    }, function(result)
        cb(result or {})
    end)
end)

-- ============================================
-- ADD GARAGE OWNER
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:AddGarageOwner', function(source, cb, garageId, targetIdentifier)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, 'Error') end
    
    -- Verificar que sea el dueño
    MySQL.query('SELECT * FROM private_garages WHERE id = ? AND owner = ?', {
        garageId,
        xPlayer.identifier
    }, function(result)
        if not result[1] then
            return cb(false, 'No eres el dueño')
        end
        
        -- Verificar que no esté ya agregado
        MySQL.query('SELECT * FROM private_garage_owners WHERE garage_id = ? AND identifier = ?', {
            garageId,
            targetIdentifier
        }, function(existing)
            if existing[1] then
                return cb(false, 'Este jugador ya tiene acceso')
            end
            
            -- Agregar propietario
            MySQL.insert('INSERT INTO private_garage_owners (garage_id, identifier, access_level) VALUES (?, ?, ?)', {
                garageId,
                targetIdentifier,
                'member'
            }, function(insertId)
                if insertId then
                    -- Notificar al jugador objetivo para recargar sus garajes privados
                    local targetSource
                    for _, playerId in ipairs(FrameworkBridge.GetPlayers()) do
                        local xTarget = FrameworkBridge.GetPlayer(playerId)
                        if xTarget and FrameworkBridge.GetIdentifier(xTarget) == targetIdentifier then
                            targetSource = playerId
                            break
                        end
                    end

                    if targetSource then
                        TriggerClientEvent('kr_garages:client:ReloadPrivateGarages', targetSource)
                    end

                    cb(true, 'Propietario agregado')
                else
                    cb(false, 'Error en la base de datos')
                end
            end)
        end)
    end)
end)

-- ============================================
-- REMOVE GARAGE OWNER
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:RemoveGarageOwner', function(source, cb, garageId, targetIdentifier)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, 'Error') end
    
    MySQL.query('SELECT * FROM private_garages WHERE id = ? AND owner = ?', {
        garageId,
        xPlayer.identifier
    }, function(result)
        if not result[1] then
            return cb(false, 'No eres el dueño')
        end
        
        MySQL.update('DELETE FROM private_garage_owners WHERE garage_id = ? AND identifier = ?', {
            garageId,
            targetIdentifier
        }, function(affectedRows)
            if affectedRows > 0 then
                -- Notificar al jugador removido para recargar sus garajes
                local targetSource
                for _, playerId in ipairs(FrameworkBridge.GetPlayers()) do
                    local xTarget = FrameworkBridge.GetPlayer(playerId)
                    if xTarget and FrameworkBridge.GetIdentifier(xTarget) == targetIdentifier then
                        targetSource = playerId
                        break
                    end
                end

                if targetSource then
                    TriggerClientEvent('kr_garages:client:ReloadPrivateGarages', targetSource)
                end
                
                cb(true, 'Propietario removido')
            else
                cb(false, 'Error al remover')
            end
        end)
    end)
end)

-- ============================================
-- GET ONLINE PLAYERS FOR SHARING
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:GetOnlinePlayers', function(source, cb)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb({}) end
    
    local myIdentifier = FrameworkBridge.GetIdentifier(xPlayer)
    local players = {}
    for _, playerId in ipairs(FrameworkBridge.GetPlayers()) do
        local xTarget = FrameworkBridge.GetPlayer(playerId)
        if xTarget then
            local targetIdentifier = FrameworkBridge.GetIdentifier(xTarget)
            if targetIdentifier ~= myIdentifier then
                table.insert(players, {
                    id = playerId,
                    name = FrameworkBridge.GetPlayerName(xTarget),
                    identifier = targetIdentifier
                })
            end
        end
    end
    
    cb(players)
end)

-- ============================================
-- GET GARAGE ACCESS LIST (MEMBERS)
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:GetGarageMembers', function(source, cb, garageId)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, 'Error', {}) end
    
    local identifier = xPlayer.identifier
    
    -- Verificar si es admin (optimizado)
    local isAdmin = false
    if Config and Config.AdminGroups then
        local playerGroup = xPlayer.getGroup()
        for _, group in ipairs(Config.AdminGroups) do
            if playerGroup == group then
                isAdmin = true
                break
            end
        end
    end
    
    -- Verificar que sea el dueño o admin
    MySQL.query('SELECT * FROM private_garages WHERE id = ?', {
        garageId
    }, function(garageResult)
        if not garageResult[1] then
            return cb(false, 'Garaje no encontrado', {})
        end
        
        -- Solo el dueño o admin pueden ver los miembros
        if garageResult[1].owner ~= identifier and not isAdmin then
            return cb(false, 'No tienes permisos para ver los miembros de este garaje', {})
        end
        
        -- Obtener lista de miembros
        MySQL.query([[
            SELECT pgo.identifier, pgo.access_level, pgo.added_at, u.firstname, u.lastname 
            FROM private_garage_owners pgo
            LEFT JOIN users u ON pgo.identifier = u.identifier
            WHERE pgo.garage_id = ?
            ORDER BY pgo.added_at DESC
        ]], {
            garageId
        }, function(members)
            cb(true, nil, members or {})
        end)
    end)
end)

-- ============================================
-- ADD GARAGE MEMBER (SHARE ACCESS)
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:AddGarageMember', function(source, cb, garageId, targetIdentifier)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, 'Error') end
    
    local identifier = xPlayer.identifier
    
    -- Verificar que el target no sea vacío
    if not targetIdentifier or targetIdentifier == '' then
        return cb(false, 'Identificador inválido')
    end
    
    -- Verificar que sea el dueño
    MySQL.query('SELECT * FROM private_garages WHERE id = ? AND owner = ?', {
        garageId,
        identifier
    }, function(garageResult)
        if not garageResult[1] then
            return cb(false, 'No eres el dueño del garaje')
        end
        
        local garageName = garageResult[1].name or 'Garaje'
        
        -- Verificar que el target no sea el mismo dueño
        if targetIdentifier == identifier then
            return cb(false, 'No puedes agregarte a ti mismo')
        end
        
        -- Verificar que el jugador existe en la base de datos
        MySQL.query('SELECT identifier FROM users WHERE identifier = ? LIMIT 1', {
            targetIdentifier
        }, function(userResult)
            if not userResult[1] then
                return cb(false, 'El jugador no existe en la base de datos')
            end
            
            -- Verificar que no esté ya agregado
            MySQL.query('SELECT * FROM private_garage_owners WHERE garage_id = ? AND identifier = ?', {
                garageId,
                targetIdentifier
            }, function(existing)
                if existing[1] then
                    return cb(false, 'Este jugador ya tiene acceso al garaje')
                end
                
                -- Verificar límite de 5 usuarios
                MySQL.query('SELECT COUNT(*) as total FROM private_garage_owners WHERE garage_id = ?', {
                    garageId
                }, function(countResult)
                    local currentCount = countResult[1] and countResult[1].total or 0
                    
                    if currentCount >= 5 then
                        return cb(false, 'Has alcanzado el límite máximo de 5 usuarios compartidos')
                    end
                    
                    -- Agregar miembro
                    MySQL.insert('INSERT INTO private_garage_owners (garage_id, identifier, access_level) VALUES (?, ?, ?)', {
                        garageId,
                        targetIdentifier,
                        'member'
                    }, function(insertId)
                        if insertId then
                            -- Notificar al jugador agregado para recargar sus garajes
                            local targetSource
                            for _, playerId in ipairs(FrameworkBridge.GetPlayers()) do
                                local xTarget = FrameworkBridge.GetPlayer(playerId)
                                if xTarget and FrameworkBridge.GetIdentifier(xTarget) == targetIdentifier then
                                    targetSource = playerId
                                    break
                                end
                            end

                            if targetSource then
                                TriggerClientEvent('kr_garages:client:ReloadPrivateGarages', targetSource)
                                TriggerClientEvent('esx:showNotification', targetSource, ('~g~Te han dado acceso al garaje: ~w~%s'):format(garageName))
                            end
                            
                            cb(true, 'Acceso compartido exitosamente')
                        else
                            cb(false, 'Error en la base de datos')
                        end
                    end)
                end)
            end)
        end)
    end)
end)

-- ============================================
-- REMOVE GARAGE MEMBER
-- ============================================

FrameworkBridge.RegisterCallback('kr_garages:server:RemoveGarageMember', function(source, cb, garageId, targetIdentifier)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb(false, 'Error') end
    
    -- Verificar que sea el dueño
    MySQL.query('SELECT * FROM private_garages WHERE id = ? AND owner = ?', {
        garageId,
        xPlayer.identifier
    }, function(garageResult)
        if not garageResult[1] then
            return cb(false, 'No eres el dueño del garaje')
        end
        
        local garageName = garageResult[1].name or 'Garaje'
        
        MySQL.update('DELETE FROM private_garage_owners WHERE garage_id = ? AND identifier = ?', {
            garageId,
            targetIdentifier
        }, function(affectedRows)
            if affectedRows > 0 then
                -- Notificar al jugador removido
                local targetSource
                for _, playerId in ipairs(FrameworkBridge.GetPlayers()) do
                    local xTarget = FrameworkBridge.GetPlayer(playerId)
                    if xTarget and FrameworkBridge.GetIdentifier(xTarget) == targetIdentifier then
                        targetSource = playerId
                        break
                    end
                end

                if targetSource then
                    TriggerClientEvent('kr_garages:client:ReloadPrivateGarages', targetSource)
                    TriggerClientEvent('esx:showNotification', targetSource, ('~y~Tu acceso al garaje ~w~%s~y~ ha sido revocado'):format(garageName))
                end
                
                cb(true, 'Miembro removido exitosamente')
            else
                cb(false, 'Error al remover miembro')
            end
        end)
    end)
end)
