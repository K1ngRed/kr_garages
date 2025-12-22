--[[
    framework/init.lua
    Detección de framework y utilidades compartidas
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Soporte para ESX y QB-Core
--]]

Framework = {}

function Framework.GetFramework()
    local name = Config and Config.Framework or 'esx'
    if name == 'qb' or name == 'qbcore' then
        return 'qb'
    end
    return 'esx'
end

function Framework.IsESX()
    return Framework.GetFramework() == 'esx'
end

function Framework.IsQB()
    return Framework.GetFramework() == 'qb'
end

function Framework.GetName()
    return Config and Config.Framework or 'esx'
end

-- Utilidades compartidas (solo cliente)
if not IsDuplicityVersion() then
    function Framework.GetVehicleLabel(model)
        if type(model) == 'string' then
            return GetDisplayNameFromVehicleModel(GetHashKey(model))
        end
        return GetDisplayNameFromVehicleModel(model)
    end
end

function Framework.Trim(str)
    if not str then return '' end
    return (string.gsub(str, '^%s*(.-)%s*$', '%1'))
end

function Framework.GetTables()
    return {
        Users = Framework.IsQB() and 'players' or 'users',
        Vehicles = Framework.IsQB() and 'player_vehicles' or 'owned_vehicles',
        OwnerColumn = Framework.IsQB() and 'citizenid' or 'owner',
        IdentifierColumn = Framework.IsQB() and 'citizenid' or 'identifier'
    }
end

-- Log de inicio (solo servidor)
if IsDuplicityVersion() then
    CreateThread(function()
        Wait(100)
        if Config then
            print('^2[kr_garages]^7 Framework: ^3' .. Framework.GetName() .. '^7')
        end
    end)
end
