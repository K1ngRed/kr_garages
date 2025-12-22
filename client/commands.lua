-- client/commands.lua

-- Esperar a que FrameworkBridge esté disponible
while not FrameworkBridge do
    Wait(0)
end

-- ============================================
-- Comando /garagesadmin
-- Abre el panel de administración de garajes privados
-- Permite crear, editar, eliminar y gestionar garajes privados
-- Solo disponible para administradores
-- ============================================
RegisterCommand('garagesadmin', function()
    -- Verificar permisos en el servidor
    FrameworkBridge.TriggerCallback('kr_garages:server:CheckAdminPermission', function(isAdmin)
        if not isAdmin then
            FrameworkBridge.ShowNotification('~r~No tienes permisos para usar este comando')
            return
        end
        
        FrameworkBridge.TriggerCallback('kr_garages:server:GetPrivateGarages', function(garages)
            SendNUIMessage({
                action = 'openPrivateGarages',
                garages = garages or {},
                locale = Config.Locale or 'es'
            })
            SetNuiFocus(true, true)
        end)
    end)
end, false, {
    help = 'Abrir panel de administración de garajes privados (Admin)'
})

-- ============================================
-- Comando /recuperarvehs
-- Recupera vehículos que están marcados como "fuera del garaje"
-- pero que no existen físicamente en el mundo (perdidos/bugueados)
-- Los vehículos recuperados aparecerán como destruidos y
-- necesitarán ser reparados antes de usarse
-- ============================================
RegisterCommand('recuperarvehs', function()
    TriggerServerEvent('kr_garages:server:RecoverLostVehicles')
end, false, {
    help = 'Recuperar vehículos perdidos o bugueados que no aparecen en el mundo'
})

-- ============================================
-- Comando /cerrargaraje
-- Comando de emergencia para cerrar la interfaz del garaje
-- Usar si la UI se congela o no responde
-- Libera el cursor y cierra todos los menús del garaje
-- ============================================
RegisterCommand('cerrargaraje', function()
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'forceClose'
    })
end, false, {
    help = 'Cerrar la interfaz del garaje si está congelada (Emergencia)'
})

-- ============================================
-- Comando /gpublicoadmin
-- Abre el panel de administración de garajes públicos
-- Permite crear, editar, eliminar y gestionar garajes públicos
-- Los garajes públicos se guardan en la base de datos
-- Solo disponible para administradores
-- ============================================
RegisterCommand('gpublicoadmin', function()
    -- Verificar permisos en el servidor
    FrameworkBridge.TriggerCallback('kr_garages:server:CheckAdminPermission', function(isAdmin)
        if not isAdmin then
            FrameworkBridge.ShowNotification('~r~No tienes permisos para usar este comando')
            return
        end
        
        -- Obtener lista de garajes públicos del servidor (incluye DB + config)
        FrameworkBridge.TriggerCallback('kr_garages:server:GetPublicGaragesAdmin', function(publicGarages)
            SendNUIMessage({
                action = 'openPublicGaragesAdmin',
                garages = publicGarages or {},
                locale = Config.Locale or 'es'
            })
            SetNuiFocus(true, true)
        end)
    end)
end, false, {
    help = 'Abrir panel de administración de garajes públicos (Admin)'
})

-- ============================================
-- SUGERENCIAS DE COMANDOS (aparecen debajo al escribir)
-- ============================================

TriggerEvent('chat:addSuggestion', '/darauto', 'Asignar vehículo a un jugador (Admin)', {
    { name = 'ID', help = 'ID del jugador que recibirá el vehículo' },
    { name = 'modelo', help = 'Nombre del vehículo (ej: adder, buzzard, dinghy)' },
    { name = 'placa', help = 'Placa personalizada o ENTER para generar automática' }
})

TriggerEvent('chat:addSuggestion', '/garagesadmin', 'Abrir panel de garajes privados (Admin)', {})
TriggerEvent('chat:addSuggestion', '/gpublicoadmin', 'Abrir panel de garajes públicos (Admin)', {})
TriggerEvent('chat:addSuggestion', '/recuperarvehs', 'Recuperar vehículos perdidos o bugueados', {})
TriggerEvent('chat:addSuggestion', '/cerrargaraje', 'Cerrar interfaz del garaje (Emergencia)', {})
TriggerEvent('chat:addSuggestion', '/confiscar', 'Confiscar vehículo cercano (Policía)', {})
TriggerEvent('chat:addSuggestion', '/verimpound', 'Ver vehículos en el depósito (Policía/Admin)', {})
