# KR Garages - Documentación Completa

> Sistema de garajes avanzado para FiveM  
> Desarrollado con cariño y muchas horas de debugging

![FiveM](https://img.shields.io/badge/FiveM-Ready-orange)
![Lua](https://img.shields.io/badge/Lua-5.4-blue)
![ESX](https://img.shields.io/badge/ESX-Compatible-green)
![QB](https://img.shields.io/badge/QB--Core-Compatible-purple)

---

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Requisitos y Dependencias](#requisitos-y-dependencias)
3. [Instalación Paso a Paso](#instalación-paso-a-paso)
4. [Configuración Detallada](#configuración-detallada)
5. [Estructura de la Base de Datos](#estructura-de-la-base-de-datos)
6. [Comandos Disponibles](#comandos-disponibles)
7. [Sistema de Impound](#sistema-de-impound)
8. [API y Exports](#api-y-exports)
9. [Eventos del Sistema](#eventos-del-sistema)
10. [Internacionalización](#internacionalización)
11. [Preguntas Frecuentes](#preguntas-frecuentes)
12. [Solución de Problemas](#solución-de-problemas)
13. [Arquitectura del Sistema](#arquitectura-del-sistema)
14. [Changelog](#changelog)

---

## Introducción

**KR Garages** es un sistema de garajes para FiveM que cumple con lo que necesitas: guardar vehículos, sacarlos, confiscarlos y poco más. La mayoría de sistemas de garajes hacen exactamente lo mismo, seamos honestos.

### ¿Qué tiene este sistema?

Las funciones típicas que encontrarás en cualquier script de garajes decente:

- **Soporte ESX y QB-Core**: Como casi todos los scripts modernos
- **Guardar propiedades del vehículo**: Colores, tuning, combustible... lo normal
- **Sistema de impound**: Para que la policía confisque vehículos
- **Interfaz NUI**: Una UI en HTML/CSS/JS para ver tus vehículos

### Lo que sí es diferente

Si hay algo que no he visto mucho en otros scripts es esto:

**Gestión de garajes públicos desde el juego**: En lugar de tener que editar el `config.lua` cada vez que quieres añadir un garaje, puedes crearlos directamente desde el juego con `/gpublicoadmin`. Los garajes se guardan en la base de datos, no en archivos. Esto significa que puedes crear, mover o eliminar garajes sin reiniciar el servidor ni tocar código.

También tiene un panel para gestionar **garajes privados** (los que van vinculados a casas o propiedades) de la misma manera.

---

## Características del Sistema

Aquí está la lista real de lo que hace el script. Sin exagerar ni vender humo.

### Garajes

- **Garajes públicos**: Los típicos garajes donde cualquiera puede guardar/sacar sus vehículos
- **Garajes de trabajo (job)**: Garajes exclusivos para ciertos trabajos (policía, EMS, mecánico, etc.)
- **Garajes privados**: Vinculados a propiedades o jugadores específicos
- **Gestión desde el juego**: Crear, editar y eliminar garajes sin tocar archivos (se guardan en BD)
- **Blips en el mapa**: Cada garaje puede tener su icono en el minimapa

### Vehículos

- **Guardar propiedades**: Color, tuning, extras, neones, daño, suciedad... lo estándar
- **Combustible**: Compatible con ox_fuel, LegacyFuel y otros sistemas de fuel
- **Tracking de daño**: El sistema guarda el estado del motor/carrocería mientras conduces
- **Prevención de duplicados**: Un vehículo no puede estar spawneado dos veces
- **Detección de abandono**: Vehículos abandonados pueden volver automáticamente al garaje
- **Recuperar vehículos bugueados**: Comando `/recuperarvehs` para vehículos que desaparecen

### Sistema de Impound (Depósito)

- **Confiscar vehículos**: La policía (o jobs configurados) puede mandar vehículos al impound
- **Razones predefinidas**: Lista de razones comunes para elegir (o escribir una personalizada)
- **Multas configurables**: Precio base + precio por tiempo, con máximo configurable
- **NPC en el impound**: Ped con animación para interactuar
- **Notificación al dueño**: Avisa cuando te confiscan un vehículo

### Reparación

- **Reparar desde garaje**: Pagar para reparar vehículos dañados sin tener que sacarlos
- **Costo por daño**: El precio depende de cuánto daño tenga el vehículo
- **Recuperar vehículos lejanos**: Si tu coche está lejos, puedes pagara para "traerlo" al garaje

### Transferencia

- **Mover entre garajes**: Llevar un vehículo de un garaje a otro sin tener que conducir
- **Transferir a jugador**: Dar/vender un vehículo a otro jugador (cambia el owner)

### Compatibilidad con Trabajos

- **Vehículos de policía**: Detecta vehículos policiales (por prefijo de placa) y los bloquea en garajes normales
- **Vehículos EMS**: Lo mismo para ambulancias

### Interfaz

- **NUI moderna**: HTML/CSS/JS sin frameworks pesados
- **Carga asíncrona**: La UI se abre primero, los datos cargan después
- **9 idiomas**: es, en, pt, ru, fr, de, pl, it, tr
- **ox_target / qb-target**: Interacción 3D con los garajes/NPCs

### Administración

- **Panel de garajes públicos**: `/gpublicoadmin`
- **Panel de garajes privados**: `/garagesadmin`
- **Dar vehículos**: `/darauto [id] [modelo] [placa]` con detección automática de tipo
- **Ver impound**: `/verimpound` para ver todos los vehículos confiscados

---

## Requisitos y Dependencias

### Obligatorias

Antes de instalar, asegúrate de tener estos recursos funcionando:

| Recurso | Versión Mínima | Descripción |
|---------|----------------|-------------|
| `oxmysql` | 2.0+ | Para las consultas a la base de datos |
| `ox_lib` | 3.0+ | Librería de utilidades (notificaciones, callbacks, etc.) |
| `ox_target` o `qb-target` | Última | Para las interacciones 3D |
| `ESX` o `QB-Core` | Última | El framework de tu servidor |

### Opcionales (pero recomendadas)

Estos recursos no son obligatorios, pero si los tienes instalados el sistema los usará:

- **ox_fuel / LegacyFuel / cdn-fuel**: Para guardar y restaurar el combustible
- **Cualquier sistema de llaves**: El sistema detecta si el jugador tiene las llaves

### Sobre las versiones

He probado esto con las últimas versiones de todo a fecha de enero 2025. Si usas versiones muy antiguas de ESX o QB-Core, podrían haber incompatibilidades. Te recomiendo actualizar.

---

## Instalación Paso a Paso

### Paso 1: Descargar y Ubicar

1. Descarga el recurso y extráelo
2. Colócalo en tu carpeta de resources. Yo lo tengo en `resources/[ox]/kr_garages` pero puedes ponerlo donde quieras
3. El nombre de la carpeta DEBE ser `kr_garages` (sin mayúsculas raras)

### Paso 2: Base de Datos

Ejecuta el archivo `sql/setup.sql` en tu base de datos. Este archivo:

- Crea las tablas necesarias si no existen
- NO borra datos existentes (usa `IF NOT EXISTS`)
- Añade índices para mejor rendimiento

```sql
-- Puedes ejecutarlo directamente en HeidiSQL, phpMyAdmin, o desde consola
source sql/setup.sql;
```

**IMPORTANTE**: Si vienes de otro sistema de garajes, tus vehículos en `owned_vehicles` deberían seguir funcionando. Este sistema lee esa tabla estándar.

### Paso 3: Configurar el server.cfg

Añade esta línea en tu `server.cfg`:

```cfg
ensure kr_garages
```

**El orden importa**: `kr_garages` debe iniciarse DESPUÉS de:
- oxmysql
- ox_lib
- ox_target (o qb-target)
- Tu framework (es_extended o qb-core)

Ejemplo de orden correcto:
```cfg
ensure oxmysql
ensure ox_lib
ensure es_extended
ensure ox_target
ensure kr_garages
```

### Paso 4: Primera Ejecución

1. Inicia el servidor
2. Revisa la consola por errores
3. Si todo va bien, deberías ver: `[kr_garages] Iniciado correctamente`

Si ves errores, salta a la sección de [Solución de Problemas](#solución-de-problemas).

---

## Configuración Detallada

El archivo `config.lua` es donde ajustas todo el comportamiento del sistema. Voy a explicar cada opción:

### Framework y Target

```lua
Config = {}
Config.Framework = 'auto'  -- 'auto', 'esx' o 'qb'
Config.TargetSystem = 'ox_target'  -- 'ox_target' o 'qb-target'
```

**Config.Framework**: Déjalo en 'auto' y el sistema detectará si usas ESX o QB-Core. Solo cámbialo si tienes algún problema con la detección automática.

**Config.TargetSystem**: El sistema de interacciones 3D que uses. Si tienes ox_target, déjalo así. Si usas qb-target, cámbialo.

### Configuración de Impound

```lua
Config.ImpoundEnabled = true
Config.ImpoundPrice = 500  -- Precio base para recuperar
Config.ImpoundPricePerMinute = 10  -- Precio adicional por minuto
Config.ImpoundMaxPrice = 5000  -- Precio máximo
```

La fórmula de precio es:
```
precio_final = min(ImpoundPrice + (minutos * ImpoundPricePerMinute), ImpoundMaxPrice)
```

Por ejemplo, si un vehículo lleva 30 minutos en el impound:
```
500 + (30 * 10) = 800
```

### Opciones de Vehículos

```lua
Config.SaveVehicleProperties = true  -- Guardar color, mods, etc.
Config.SaveFuel = true  -- Guardar nivel de combustible
Config.SaveDamage = true  -- Guardar daño del vehículo
Config.PreventDuplicateSpawns = true  -- Evitar duplicados
```

**SaveVehicleProperties**: SIEMPRE déjalo en true. Esta es la magia del sistema. Guarda absolutamente todo del vehículo.

**PreventDuplicateSpawns**: Evita que un jugador saque el mismo vehículo dos veces. Muy útil para prevenir duplicación.

### Ubicaciones de Garajes Públicos

```lua
Config.PublicGarages = {
    {
        name = "Garaje Central",
        coords = vector3(-350.0, -880.0, 31.0),
        heading = 0.0,
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8
        },
        spawnPoints = {
            vector4(-350.0, -885.0, 31.0, 270.0),
            vector4(-353.0, -885.0, 31.0, 270.0),
        }
    },
}
```

**coords**: Donde aparece el marcador/target para acceder al garaje

**heading**: Rotación del marcador (0-360 grados)

**blip**: Configuración del icono en el mapa. Puedes ver todos los sprites en [docs.fivem.net](https://docs.fivem.net/docs/game-references/blips/)

**spawnPoints**: Lista de puntos donde pueden aparecer los vehículos. El sistema elige automáticamente uno libre. IMPORTANTE: Usa vector4 (con heading) para que el vehículo aparezca mirando en la dirección correcta.

### Permisos y Jobs

```lua
Config.ImpoundJob = 'police'  -- Job que puede confiscar vehículos
Config.MechanicJob = 'mechanic'  -- Job que puede reparar gratis

Config.AdminGroups = {
    'admin',
    'superadmin',
    'god'
}
```

Puedes añadir múltiples jobs separándolos por comas:
```lua
Config.ImpoundJob = {'police', 'sheriff', 'sasp'}
```

---

## Estructura de la Base de Datos

El sistema usa varias tablas. Aquí te explico cada una:

### Tabla: public_garages

Almacena la configuración de garajes públicos creados desde el juego.

```sql
CREATE TABLE IF NOT EXISTS public_garages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    coords JSON NOT NULL,
    heading FLOAT DEFAULT 0.0,
    blip_sprite INT DEFAULT 357,
    blip_color INT DEFAULT 3,
    spawn_points JSON,
    created_by VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Tabla: private_garages

Garajes privados que pertenecen a jugadores (normalmente vinculados a propiedades).

```sql
CREATE TABLE IF NOT EXISTS private_garages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    owner VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    coords JSON NOT NULL,
    heading FLOAT DEFAULT 0.0,
    spawn_points JSON,
    capacity INT DEFAULT 5,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_owner (owner)
);
```

### Tabla: kr_impound

Vehículos confiscados y su información.

```sql
CREATE TABLE IF NOT EXISTS kr_impound (
    id INT AUTO_INCREMENT PRIMARY KEY,
    plate VARCHAR(20) NOT NULL,
    vehicle_data JSON NOT NULL,
    owner VARCHAR(50) NOT NULL,
    impound_reason VARCHAR(255),
    impounded_by VARCHAR(50),
    impound_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    retrieved BOOLEAN DEFAULT FALSE,
    retrieved_date TIMESTAMP NULL,
    fine_amount INT DEFAULT 0,
    
    INDEX idx_plate (plate),
    INDEX idx_owner (owner),
    INDEX idx_retrieved (retrieved)
);
```

### Tabla: owned_vehicles

Esta tabla normalmente ya existe en tu servidor (es estándar de ESX/QB). El sistema la lee pero no la modifica directamente.

```sql
-- Estructura esperada (puede variar según tu framework)
CREATE TABLE IF NOT EXISTS owned_vehicles (
    plate VARCHAR(20) PRIMARY KEY,
    owner VARCHAR(50) NOT NULL,
    vehicle JSON NOT NULL,
    stored BOOLEAN DEFAULT TRUE,
    garage VARCHAR(50) DEFAULT 'default',
    
    INDEX idx_owner (owner)
);
```

---

## Comandos Disponibles

### Comandos de Usuario

| Comando | Descripción |
|---------|-------------|
| `/recuperarvehs` | Recupera vehículos perdidos o bugueados que están marcados como "fuera" pero no existen en el mundo. Los vehículos aparecerán como destruidos y necesitarán reparación |
| `/cerrargaraje` | Comando de emergencia para cerrar la interfaz del garaje si se congela o no responde |

### Comandos de Policía/Impound

Estos comandos requieren tener el job configurado en `Config.ImpoundJob` (por defecto: police).

| Comando | Descripción |
|---------|-------------|
| `/confiscar` | Abre el menú de confiscación para enviar vehículos cercanos al impound |
| `/verimpound` | Ver todos los vehículos en el impound (también disponible para admins) |

### Comandos de Administrador

Estos comandos requieren que estés en un grupo de admin configurado en `Config.AdminGroups`.

| Comando | Descripción | Ejemplo |
|---------|-------------|---------|
| `/darauto [ID] [modelo] [placa]` | Da un vehículo a un jugador. La placa es opcional (se genera automática si no se especifica) | `/darauto 1 adder` o `/darauto 1 adder MIPLATE1` |
| `/garagesadmin` | Abre el panel de administración de garajes privados. Permite crear, editar y eliminar garajes privados vinculados a jugadores | `/garagesadmin` |
| `/gpublicoadmin` | Abre el panel de administración de garajes públicos. Permite crear, editar y eliminar garajes públicos que se guardan en la base de datos | `/gpublicoadmin` |

### Notas sobre los comandos

**Sobre `/darauto`**: El sistema detecta automáticamente el tipo de vehículo (terrestre, aéreo, acuático) y lo asigna al garaje correcto. Por ejemplo, si das un `buzzard`, aparecerá en garajes de helicópteros.

**Sobre `/recuperarvehs`**: Muy útil cuando un jugador reporta que su vehículo no aparece. El sistema busca vehículos que están marcados como "spawneados" pero que no existen físicamente.

**Sobre los paneles de admin**: En lugar de comandos individuales para crear/editar/eliminar garajes, el sistema usa paneles visuales que son mucho más cómodos de usar

---

## Sistema de Impound

El sistema de impound (confiscación) es bastante completo. Aquí te explico cómo funciona:

### Para Policías (o job configurado)

1. **Confiscar un vehículo**: Acércate al vehículo, usa el target y selecciona "Confiscar vehículo"
2. **Introducir motivo**: Aparecerá un input para escribir el motivo (opcional pero recomendado)
3. **El vehículo desaparece**: Se guarda en la base de datos con todas sus propiedades

### Para Jugadores

1. **Ir al impound**: Busca el blip de impound en el mapa
2. **Ver vehículos confiscados**: Abre el menú y verás tus vehículos con el motivo y precio
3. **Pagar multa**: Selecciona el vehículo y paga la multa
4. **Recuperar**: El vehículo aparece en el spawn point del impound

### Cálculo de Multas

```lua
-- Ejemplo de configuración
Config.ImpoundPrice = 500  -- Base
Config.ImpoundPricePerMinute = 10  -- Por minuto
Config.ImpoundMaxPrice = 5000  -- Máximo

-- Si el vehículo lleva 2 horas (120 minutos):
-- 500 + (120 * 10) = 1700

-- Si lleva 10 horas (600 minutos):
-- 500 + (600 * 10) = 6500, pero el máximo es 5000
-- Entonces paga: 5000
```

### Ubicación del Impound

Configura la ubicación en `config.lua`:

```lua
Config.ImpoundLocation = {
    coords = vector3(409.0, -1623.0, 29.0),
    heading = 230.0,
    blip = {
        sprite = 524,
        color = 1,
        scale = 0.9,
        label = "Impound"
    },
    spawnPoints = {
        vector4(405.0, -1620.0, 29.0, 230.0),
        vector4(401.0, -1617.0, 29.0, 230.0),
    }
}
```

---

## API y Exports

El sistema expone varios exports que puedes usar desde otros recursos.

### Client Exports

```lua
-- Abrir el menú de un garaje específico
exports['kr_garages']:openGarage(garageId)

-- Cerrar el menú actual
exports['kr_garages']:closeGarage()

-- Obtener lista de vehículos del jugador
local vehicles = exports['kr_garages']:getPlayerVehicles()

-- Verificar si un vehículo está guardado
local isStored = exports['kr_garages']:isVehicleStored(plate)

-- Guardar el vehículo actual
exports['kr_garages']:storeCurrentVehicle()

-- Rastrear un vehículo (muestra blip)
exports['kr_garages']:trackVehicle(plate)
```

### Server Exports

```lua
-- Obtener todos los vehículos de un jugador
local vehicles = exports['kr_garages']:getPlayerVehicles(identifier)

-- Dar un vehículo a un jugador
exports['kr_garages']:giveVehicle(identifier, model, plate, props)

-- Eliminar un vehículo
exports['kr_garages']:removeVehicle(plate)

-- Enviar vehículo al impound
exports['kr_garages']:impoundVehicle(plate, reason, officerId)

-- Liberar del impound
exports['kr_garages']:releaseFromImpound(plate)

-- Obtener info de un vehículo
local info = exports['kr_garages']:getVehicleInfo(plate)

-- Reparar un vehículo (en base de datos)
exports['kr_garages']:repairVehicle(plate)
```

### Ejemplos de Uso

**Integración con sistema de casas:**
```lua
-- Cuando un jugador compra una casa, crear garaje privado
RegisterNetEvent('housing:purchased')
AddEventHandler('housing:purchased', function(houseId, coords)
    exports['kr_garages']:createPrivateGarage(source, {
        name = "Garaje Casa #" .. houseId,
        coords = coords,
        capacity = 3
    })
end)
```

**Integración con policía:**
```lua
-- Confiscar vehículo desde otro script
RegisterCommand('confiscar', function(source)
    local ped = GetPlayerPed(source)
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle and vehicle ~= 0 then
        local plate = GetVehicleNumberPlateText(vehicle)
        exports['kr_garages']:impoundVehicle(plate, "Confiscado por policía", source)
        DeleteEntity(vehicle)
    end
end)
```

---

## Eventos del Sistema

### Eventos del Cliente

```lua
-- Cuando se abre el menú de garaje
AddEventHandler('kr_garages:client:garageOpened', function(garageId)
    print("Garaje abierto:", garageId)
end)

-- Cuando se cierra el menú
AddEventHandler('kr_garages:client:garageClosed', function()
    print("Garaje cerrado")
end)

-- Cuando se saca un vehículo
AddEventHandler('kr_garages:client:vehicleSpawned', function(plate, vehicle)
    print("Vehículo spawneado:", plate)
end)

-- Cuando se guarda un vehículo
AddEventHandler('kr_garages:client:vehicleStored', function(plate)
    print("Vehículo guardado:", plate)
end)
```

### Eventos del Servidor

```lua
-- Cuando un vehículo es confiscado
AddEventHandler('kr_garages:server:vehicleImpounded', function(plate, reason, officer)
    print("Vehículo confiscado:", plate, "Razón:", reason)
end)

-- Cuando un vehículo es recuperado del impound
AddEventHandler('kr_garages:server:vehicleRetrieved', function(plate, owner)
    print("Vehículo recuperado:", plate, "Por:", owner)
end)

-- Cuando se crea un garaje
AddEventHandler('kr_garages:server:garageCreated', function(garageId, name)
    print("Nuevo garaje creado:", name)
end)
```

---

## Internacionalización

El sistema soporta múltiples idiomas. Los archivos de traducción están en `html/locales/`.

### Idiomas Disponibles

- 🇪🇸 Español (es.json)
- 🇺🇸 Inglés (en.json)
- 🇩🇪 Alemán (de.json)
- 🇫🇷 Francés (fr.json)
- 🇮🇹 Italiano (it.json)
- 🇵🇱 Polaco (pl.json)
- 🇵🇹 Portugués (pt.json)
- 🇷🇺 Ruso (ru.json)
- 🇹🇷 Turco (tr.json)

### Cambiar el Idioma

En `config.lua`:
```lua
Config.Locale = 'es'  -- Código del idioma
```

### Añadir un Nuevo Idioma

1. Copia `html/locales/en.json` y renómbralo (ej: `jp.json`)
2. Traduce todos los textos
3. Cambia `Config.Locale` al código de tu idioma

Ejemplo de estructura del archivo de locale:
```json
{
    "title": "Mis Vehículos",
    "loading": "Cargando...",
    "no_vehicles": "No tienes vehículos",
    "spawn": "Sacar",
    "store": "Guardar",
    "repair": "Reparar",
    "impound": "Confiscar",
    "transfer": "Transferir",
    "track": "Rastrear",
    "close": "Cerrar"
}
```

---

## Preguntas Frecuentes

### ¿Por qué los vehículos pierden las modificaciones?

Esto NO debería pasar con este sistema. Si te pasa, verifica:
1. Que `Config.SaveVehicleProperties = true`
2. Que la columna `vehicle` en `owned_vehicles` sea de tipo JSON o LONGTEXT
3. Revisa la consola F8 por errores al guardar

### ¿Puedo usar esto con mi sistema de concesionario?

Sí. Cualquier vehículo que esté en la tabla `owned_vehicles` con el identifier correcto aparecerá en el garaje. Solo asegúrate de que tu concesionario guarde los vehículos en esa tabla.

### ¿Cómo añado más spawn points a un garaje?

En el config.lua, cada garaje tiene un array `spawnPoints`. Simplemente añade más vector4:

```lua
spawnPoints = {
    vector4(-350.0, -885.0, 31.0, 270.0),  -- Punto 1
    vector4(-353.0, -885.0, 31.0, 270.0),  -- Punto 2
    vector4(-356.0, -885.0, 31.0, 270.0),  -- Punto 3 (nuevo)
}
```

### ¿El sistema soporta diferentes tipos de garajes? (coches, motos, barcos)

Sí, puedes configurar el tipo de vehículos que acepta cada garaje:

```lua
{
    name = "Muelle",
    type = "boat",  -- Solo barcos
    coords = vector3(...),
    ...
}
```

Tipos disponibles: `car`, `motorcycle`, `boat`, `aircraft`, `all`

### ¿Cómo funcionan los garajes privados?

Los garajes privados están vinculados a un identifier (jugador). Normalmente se crean automáticamente cuando alguien compra una propiedad, pero puedes crearlos manualmente:

```lua
-- En el servidor
exports['kr_garages']:createPrivateGarage(identifier, {
    name = "Mi Garaje",
    coords = vector3(x, y, z),
    capacity = 5
})
```

### ¿Puedo tener múltiples impounds?

Sí. Configura un array en lugar de un solo objeto:

```lua
Config.ImpoundLocations = {
    {
        id = "impound_city",
        name = "Impound Ciudad",
        coords = vector3(...),
        ...
    },
    {
        id = "impound_county",
        name = "Impound Condado",
        coords = vector3(...),
        ...
    }
}
```

---

## Solución de Problemas

### Error: "oxmysql not found"

**Problema**: No tienes oxmysql instalado o no está iniciando antes que kr_garages.

**Solución**: 
1. Descarga oxmysql de [GitHub](https://github.com/overextended/oxmysql)
2. Asegúrate de que `ensure oxmysql` esté ANTES de `ensure kr_garages` en server.cfg

### Error: "Framework not detected"

**Problema**: El sistema no puede detectar ESX ni QB-Core.

**Solución**:
1. Verifica que tu framework inicie antes que kr_garages
2. Si usas un fork modificado, prueba configurar manualmente:
```lua
Config.Framework = 'esx'  -- o 'qb'
```

### Los vehículos no aparecen en la lista

**Causas posibles**:
1. El identifier no coincide (ESX usa `steam:xxx`, QB usa `license:xxx`)
2. Los vehículos tienen `stored = 0` en la base de datos
3. El garage no corresponde

**Diagnóstico**: Ejecuta esta query:
```sql
SELECT * FROM owned_vehicles WHERE owner = 'TU_IDENTIFIER';
```

### La UI no abre

**Verificar**:
1. Abre F8 y busca errores de JavaScript
2. Verifica que los archivos de `html/` existan
3. Prueba recargar el recurso: `refresh` y luego `ensure kr_garages`

### Error: "Target system not found"

**Problema**: No tienes ox_target ni qb-target, o no están iniciando correctamente.

**Solución**:
1. Instala ox_target o qb-target
2. Configura el correcto en `Config.TargetSystem`
3. Verifica el orden de inicio

### Los vehículos aparecen bajo tierra

**Problema**: Las coordenadas de spawn no tienen la altura correcta.

**Solución**: Usa las coordenadas exactas del suelo. Puedes obtenerlas con:
```lua
/coords  -- Si tienes algún script de coords
```
O en F8:
```lua
print(GetEntityCoords(PlayerPedId()))
```

### El combustible no se guarda

**Verificar**:
1. Que tengas un sistema de combustible compatible
2. Que `Config.SaveFuel = true`
3. Sistemas compatibles: ox_fuel, LegacyFuel, cdn-fuel

---

## Arquitectura del Sistema

Para los que quieren entender cómo funciona todo por dentro.

### Estructura de Carpetas

```
kr_garages/
├── client/                 # Código del cliente
│   ├── core.lua           # Inicialización y funciones principales
│   ├── garage_menu.lua    # Lógica del menú de garaje
│   ├── impound.lua        # Sistema de impound (cliente)
│   ├── spawn.lua          # Spawneo de vehículos
│   ├── store.lua          # Guardado de vehículos
│   ├── tracking.lua       # Sistema de rastreo
│   ├── nui_callbacks.lua  # Comunicación con la UI
│   └── utils.lua          # Funciones de utilidad
│
├── server/                 # Código del servidor
│   ├── core.lua           # Inicialización del servidor
│   ├── callbacks.lua      # Callbacks para el cliente
│   ├── vehicles.lua       # CRUD de vehículos
│   ├── impound.lua        # Sistema de impound (servidor)
│   ├── repair.lua         # Sistema de reparación
│   ├── transfer.lua       # Transferencia de vehículos
│   └── admin.lua          # Comandos de administrador
│
├── framework/              # Capa de abstracción
│   ├── init.lua           # Detección de framework
│   ├── client.lua         # Funciones del framework (cliente)
│   └── server.lua         # Funciones del framework (servidor)
│
├── shared/                 # Código compartido
│   └── vehicle_data.lua   # Datos de vehículos
│
├── html/                   # Interfaz de usuario
│   ├── index.html         # Estructura HTML
│   ├── style.css          # Estilos
│   ├── script.js          # Lógica de la UI
│   └── locales/           # Archivos de idiomas
│
├── config.lua             # Configuración
├── fxmanifest.lua         # Manifiesto del recurso
└── sql/                   # Scripts de base de datos
    └── setup.sql          # Instalación
```

### Flujo de Datos

```
[Jugador] --> [ox_target] --> [client/core.lua]
                                    |
                                    v
                            [client/nui_callbacks.lua]
                                    |
                                    v
                            [html/script.js] <--> [html/index.html]
                                    |
                                    v
                            [server/callbacks.lua]
                                    |
                                    v
                            [server/vehicles.lua]
                                    |
                                    v
                            [oxmysql] --> [Base de Datos]
```

### Patrón Framework Bridge

El directorio `framework/` contiene una capa de abstracción que permite que el mismo código funcione en ESX y QB-Core. Es un patrón que he visto en muchos recursos y funciona muy bien.

```lua
-- framework/init.lua detecta el framework
if GetResourceState('es_extended') == 'started' then
    Framework = 'esx'
elseif GetResourceState('qb-core') == 'started' then
    Framework = 'qb'
end

-- Luego los demás archivos usan funciones genéricas
-- framework/server.lua
function FrameworkBridge.GetPlayerFromId(source)
    if Framework == 'esx' then
        return ESX.GetPlayerFromId(source)
    else
        return QBCore.Functions.GetPlayer(source)
    end
end
```

### Guardado de Propiedades de Vehículos

Esta es la parte más crítica del sistema. Cuando guardas un vehículo:

1. **Cliente**: `spawn.lua` llama a las natives de GTA para obtener TODAS las propiedades
2. **Serialización**: Se convierte a JSON
3. **Servidor**: Se guarda en la base de datos
4. **Restauración**: Al sacar el vehículo, se aplican todas las propiedades

```lua
-- Propiedades que se guardan (simplificado)
local props = {
    model = GetEntityModel(vehicle),
    plate = GetVehicleNumberPlateText(vehicle),
    color1 = GetVehicleColours(vehicle),
    color2 = ...,
    mods = {},
    extras = {},
    neonColor = {...},
    tyreSmokeColor = {...},
    windowTint = ...,
    dirt = ...,
    bodyHealth = ...,
    engineHealth = ...,
    fuel = ...,
    -- ... y muchas más
}
```

---

## Changelog

### v2.0.0 (Actual)
- Reescritura completa del sistema
- Soporte dual ESX/QB-Core
- Nueva interfaz moderna con carga asíncrona
- Sistema de impound completo
- Preservación total de propiedades de vehículos
- Sistema de rastreo de vehículos
- Internacionalización (9 idiomas)
- API de exports completa
- Corrección de duplicación de vehículos
- Corrección de pérdida de modificaciones

### v1.5.0
- Añadido sistema de transferencia
- Añadido sistema de reparación
- Corrección de bugs menores

### v1.0.0
- Lanzamiento inicial

---

## Créditos y Licencia

Desarrollado para la comunidad de FiveM.

**Dependencias utilizadas:**
- ox_lib - Overextended
- oxmysql - Overextended
- ox_target - Overextended

**Licencia**: Este recurso es de uso libre. Puedes modificarlo y redistribuirlo, pero agradecería que mantengas los créditos originales.

---

> ¿Encontraste un bug? Abre un issue en GitHub o contáctame por Discord.
> 
> ¿Tienes una sugerencia? Siempre estoy abierto a ideas para mejorar el sistema.

---

*Última actualización: Enero 2025*

