--[[
    server/callbacks.lua
    Callbacks de permisos y jugadores
--]]

-- Check admin
FrameworkBridge.RegisterCallback('kr_garages:server:CheckAdminPermission', function(source, cb)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    cb(IsPlayerAdmin(xPlayer))
end)

-- Lista de jugadores
FrameworkBridge.RegisterCallback('kr_garages:server:GetNearbyPlayers', function(source, cb)
    local xPlayer = FrameworkBridge.GetPlayer(source)
    if not xPlayer then return cb({}) end

    local players = {}
    for _, playerId in ipairs(FrameworkBridge.GetPlayers()) do
        local targetPlayer = FrameworkBridge.GetPlayer(playerId)
        if targetPlayer then
            table.insert(players, {
                id = playerId,
                source = playerId,
                name = FrameworkBridge.GetPlayerName(targetPlayer),
                identifier = FrameworkBridge.GetIdentifier(targetPlayer)
            })
        end
    end

    cb(players)
end)

-- Lista de garajes públicos
FrameworkBridge.RegisterCallback('kr_garages:server:GetPublicGarages', function(source, cb)
    GetPublicGaragesFromCache(function(garages)
        local publicGarages = {}
        for i = 1, #garages do
            local g = garages[i]
            publicGarages[i] = {
                id = g.id,
                name = g.name or g.id,
                type = g.type or 'car'
            }
        end
        cb(publicGarages)
    end)
end)

-- Lista de garajes públicos para el panel admin (usa cache)
FrameworkBridge.RegisterCallback('kr_garages:server:GetPublicGaragesAdmin', function(source, cb)
    GetPublicGaragesFromCache(cb)
end)

-- Callback para que el cliente obtenga los garajes públicos
FrameworkBridge.RegisterCallback('kr_garages:server:GetPublicGaragesForClient', function(source, cb)
    GetPublicGaragesFromCache(cb)
end)
