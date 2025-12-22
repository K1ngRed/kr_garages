--[[
    framework/server.lua
    Bridge de framework para servidor
    
    NO MODIFICAR SI NO SABES LO QUE ESTAS HACIENDO
    Abstracción ESX/QB-Core - cambiar esto rompe todo
--]]

local Core = nil

FrameworkBridge = {}

-- Esperar Config
while not Config do Wait(50) end

-- Inicializar Core
if Framework.IsQB() then
    Core = exports['qb-core']:GetCoreObject()
else
    Core = exports['es_extended']:getSharedObject()
end

-- Player Management
function FrameworkBridge.GetPlayer(source)
    return Framework.IsQB() and Core.Functions.GetPlayer(source) or Core.GetPlayerFromId(source)
end

function FrameworkBridge.GetPlayerByIdentifier(identifier)
    if Framework.IsQB() then
        return Core.Functions.GetPlayerByCitizenId(identifier)
    else
        return Core.GetPlayerFromIdentifier(identifier)
    end
end

function FrameworkBridge.GetPlayers()
    return Framework.IsQB() and Core.Functions.GetPlayers() or Core.GetPlayers()
end

function FrameworkBridge.GetPlayerName(xPlayer)
    if not xPlayer then return 'Unknown' end
    if Framework.IsQB() then
        local charinfo = xPlayer.PlayerData.charinfo
        return charinfo.firstname .. ' ' .. charinfo.lastname
    else
        return xPlayer.getName()
    end
end

function FrameworkBridge.GetIdentifier(xPlayer)
    if not xPlayer then return nil end
    return Framework.IsQB() and xPlayer.PlayerData.citizenid or xPlayer.identifier
end

function FrameworkBridge.GetJobName(xPlayer)
    if not xPlayer then return nil end
    return Framework.IsQB() and xPlayer.PlayerData.job.name or xPlayer.job.name
end

function FrameworkBridge.GetJobGrade(xPlayer)
    if not xPlayer then return 0 end
    if Framework.IsQB() then
        return xPlayer.PlayerData.job.grade.level
    else
        return xPlayer.job.grade
    end
end

function FrameworkBridge.GetGroup(xPlayer)
    if Framework.IsQB() then
        return xPlayer.PlayerData.job.name
    else
        return xPlayer.getGroup()
    end
end

-- Money
function FrameworkBridge.GetMoney(xPlayer)
    return Framework.IsQB() and xPlayer.Functions.GetMoney('cash') or xPlayer.getMoney()
end

function FrameworkBridge.GetBankMoney(xPlayer)
    if Framework.IsQB() then
        return xPlayer.Functions.GetMoney('bank')
    else
        return xPlayer.getAccount('bank').money
    end
end

function FrameworkBridge.AddMoney(xPlayer, amount)
    if Framework.IsQB() then
        return xPlayer.Functions.AddMoney('cash', amount)
    else
        xPlayer.addMoney(amount)
        return true
    end
end

function FrameworkBridge.AddBankMoney(xPlayer, amount)
    if Framework.IsQB() then
        return xPlayer.Functions.AddMoney('bank', amount)
    else
        xPlayer.addAccountMoney('bank', amount)
        return true
    end
end

function FrameworkBridge.RemoveMoney(xPlayer, amount)
    if Framework.IsQB() then
        return xPlayer.Functions.RemoveMoney('cash', amount)
    else
        xPlayer.removeMoney(amount)
        return true
    end
end

function FrameworkBridge.RemoveBankMoney(xPlayer, amount)
    if Framework.IsQB() then
        return xPlayer.Functions.RemoveMoney('bank', amount)
    else
        xPlayer.removeAccountMoney('bank', amount)
        return true
    end
end

function FrameworkBridge.ShowNotification(source, message)
    if Framework.IsQB() then
        TriggerClientEvent('QBCore:Notify', source, message, 'primary', 5000)
    else
        TriggerClientEvent('esx:showNotification', source, message)
    end
end

function FrameworkBridge.RegisterCallback(name, cb)
    if Framework.IsQB() then
        Core.Functions.CreateCallback(name, cb)
    else
        Core.RegisterServerCallback(name, cb)
    end
end

exports('GetFrameworkBridge', function()
    return FrameworkBridge
end)
