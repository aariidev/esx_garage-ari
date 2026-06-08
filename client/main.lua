--[[
    ari_garage — Client
    Version: 1.15.4-ari
--]]

local LastMarker, LastPart = nil, nil
local thisGarage, thisPound = nil, nil
local nearMarker, menuIsShowed = false, false
local HasAlreadyEnteredMarker = false
local currentVehicles, currentImpoundedVehicles = {}, {}
local lastOpenContext = nil -- { kind = 'garage'|'impound', key = string, ref = table }
local OpenGarageMenu, OpenImpoundMenu -- forward declarations
local next = next

local function ImpoundMapBlipsEnabled()
    local c = Config.ImpoundMenuOnly
    return c and c.ShowMapBlips == true
end

local function ImpoundWorldAccessEnabled()
    local c = Config.ImpoundMenuOnly
    return c and c.ShowWorldMarkers == true
end

local function PlayUISound()
    if Config.UI.Sound.Enabled then
        PlaySoundFrontend(-1, Config.UI.Sound.Name, Config.UI.Sound.Set, true)
    end
end

local function IsJobAllowed(allowedJobs, allowedGrades)
    if not allowedJobs then
        return true
    end

    local playerJob = ESX.PlayerData.job
    if not playerJob then
        return false
    end

    local playerGrade = tonumber(playerJob.grade) or 0
    for i = 1, #allowedJobs do
        local jobName = allowedJobs[i]
        if playerJob.name == jobName then
            if allowedGrades and allowedGrades[jobName] then
                return playerGrade >= allowedGrades[jobName]
            end

            return true
        end
    end

    return false
end

local function ResetMenuState()
    currentVehicles = {}
    currentImpoundedVehicles = {}
end

local function BuildVehicleType(model)
    if not model then
        return 'car'
    end

    local class = GetVehicleClassFromName(model)

    if class == 8 or class == 13 then
        return 'bike'
    elseif class == 14 then
        return 'boat'
    elseif class == 15 or class == 16 then
        return 'air'
    end

    return 'car'
end

local function VehicleMatchesFilter(vehicleProps, filterName)
    if not filterName or filterName == 'all' then
        return true
    end

    return BuildVehicleType(vehicleProps.model) == filterName
end

local function MapVehicleForUI(entry, overrideState)
    local props = entry.vehicle or entry.props or {}
    if entry.plate and (not props.plate or props.plate == '') then
        props.plate = entry.plate
    end
    local displayName = props.model and GetDisplayNameFromVehicleModel(props.model) or 'CARNOTFOUND'
    local stored = tonumber(entry.stored)
    local stateName = overrideState
        or (stored == 2 and 'impounded' or (stored == 1 and 'stored' or 'out'))

    return {
        model = displayName ~= 'CARNOTFOUND' and displayName or (props.modelName or 'Unknown'),
        plate = entry.plate,
        props = props,
        state = stateName,
        pound = entry.pound,
        parking = entry.parking,
        releaseCost = entry.releaseCost or 0,
        releaseFree = entry.releaseFree == true,
    }
end

local function safeTC(key)
    local str = TranslateCap(key)
    return str or key or ''
end

local function BuildLocales()
    return {
        action = safeTC('veh_exit'),
        veh_model = safeTC('veh_model'),
        veh_plate = safeTC('veh_plate'),
        veh_condition = safeTC('veh_condition'),
        veh_action = safeTC('veh_action'),
        impound_action = safeTC('impound_action'),
        locate_impound = safeTC('locate_impound'),
        no_veh_parking = safeTC('no_veh_parking'),
        no_veh_impounded = safeTC('no_veh_impounded'),
        pay_impound = safeTC('pay_impound'),
        fuel = safeTC('fuel') or 'Fuel',
        state_label = safeTC('veh_state'),
        state_garage = safeTC('state_garage'),
        state_impound = safeTC('state_impound'),
        state_out = safeTC('state_out'),
        release_cost = safeTC('release_cost'),
        free_release = safeTC('free_release'),
        no_results = safeTC('no_results'),
        out_action = safeTC('out_action'),
        scroll_hint = safeTC('scroll_hint'),
    }
end

local function BuildGaragePayload(garageKey, garage, vehicles, impoundedVehicles)
    local impound = garage.ImpoundedName and Config.Impounds[garage.ImpoundedName] or nil
    local spawnPoint = {
        x = garage.SpawnPoint.x,
        y = garage.SpawnPoint.y,
        z = garage.SpawnPoint.z,
        heading = garage.SpawnPoint.heading,
    }

    local poundSpawnPoint = nil
    if impound then
        poundSpawnPoint = { x = impound.GetOutPoint.x, y = impound.GetOutPoint.y }
    end

    return {
        action = 'show',
        menuType = 'garage',
        garageLabel = garage.Label or garageKey,
        vehiclesList = json.encode(vehicles),
        vehiclesImpoundedList = next(impoundedVehicles) and json.encode(impoundedVehicles) or nil,
        poundName = garage.ImpoundedName,
        poundSpawnPoint = poundSpawnPoint,
        spawnPoint = spawnPoint,
        accentColor = Config.UI.AccentColor,
        animateCards = Config.UI.AnimateCards,
        showFuel = Config.UI.ShowFuelGauge,
        locales = BuildLocales(),
    }
end

local function BuildImpoundPayload(poundKey, pound, vehicles, meta)
    return {
        action = 'show',
        menuType = 'impound',
        garageLabel = pound.Label or poundKey,
        vehiclesList = json.encode(vehicles),
        spawnPoint = {
            x = pound.SpawnPoint.x,
            y = pound.SpawnPoint.y,
            z = pound.SpawnPoint.z,
            heading = pound.SpawnPoint.heading,
        },
        poundName = poundKey,
        poundCost = meta.cost or pound.Cost,
        freeRelease = meta.freeRelease == true,
        accentColor = Config.UI.AccentColor,
        animateCards = Config.UI.AnimateCards,
        showFuel = Config.UI.ShowFuelGauge,
        locales = BuildLocales(),
    }
end

RegisterNetEvent('ari_garage:closemenu')
AddEventHandler('ari_garage:closemenu', function()
    menuIsShowed = false
    lastOpenContext = nil
    ResetMenuState()

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    SendNUIMessage({ action = 'hide' })

    Citizen.SetTimeout(50, function()
        if not menuIsShowed and thisGarage then
            ESX.TextUI(TranslateCap('access_parking'))
        end

        if not menuIsShowed and thisPound then
            ESX.TextUI(TranslateCap('access_Impound'))
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(0)
        if menuIsShowed then
            if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 177) then
                TriggerEvent('ari_garage:closemenu')
            end

            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
        end
    end
end)

RegisterNUICallback('escape', function(_, cb)
    TriggerEvent('ari_garage:closemenu')
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    if lastOpenContext then
        if lastOpenContext.kind == 'garage' and lastOpenContext.ref then
            OpenGarageMenu(lastOpenContext.key, lastOpenContext.ref)
        elseif lastOpenContext.kind == 'impound' and lastOpenContext.ref then
            OpenImpoundMenu(lastOpenContext.key, lastOpenContext.ref)
        end
    end
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    -- Capturar antes de closemenu: closemenu borra lastOpenContext; en algunos frames thisGarage puede quedar nil.
    local garageSnapshot = thisGarage
    local poundSnapshot = thisPound
    local openCtx = lastOpenContext
    if not garageSnapshot and openCtx and openCtx.kind == 'garage' and openCtx.ref then
        garageSnapshot = openCtx.ref
    end

    local spawnCoords = vector3(data.spawnPoint.x, data.spawnPoint.y, data.spawnPoint.z)
    TriggerEvent('ari_garage:closemenu')

    if not ESX.Game.IsSpawnPointClear(spawnCoords, 2.5) then
        ESX.ShowNotification(TranslateCap('veh_block'), 'error')
        return cb('ok')
    end

    if data.plate and data.vehicleProps then
        data.vehicleProps.plate = data.vehicleProps.plate or data.plate
    end

    local payImpound = data.requireImpoundPay == true
        or data.requireImpoundPay == 'true'
        or data.requireImpoundPay == 1

    if garageSnapshot and payImpound then
        thisGarage = nil
        local poundKey = data.impoundPound
        if not poundKey or poundKey == '' then
            poundKey = data.poundName
        end

        ESX.TriggerServerCallback('ari_garage:checkMoney', function(result)
            if not result or result.allowed == false then
                ESX.ShowNotification(TranslateCap('not_allowed'), 'error')
                return
            end

            if result.hasMoney == false then
                ESX.ShowNotification(TranslateCap('missing_money'))
                return
            end

            TriggerServerEvent('ari_garage:payPound', result.amount, poundKey, data.vehicleProps)
            TriggerServerEvent('ari_garage:updateOwnedVehicle', false, nil, nil, data, spawnCoords)
        end, data.exitVehicleCost, poundKey, data.vehicleProps)

        return cb('ok')
    end

    if garageSnapshot then
        thisGarage = nil
        TriggerServerEvent('ari_garage:updateOwnedVehicle', false, nil, nil, data, spawnCoords)
        ESX.ShowNotification(TranslateCap('veh_released'))
        return cb('ok')
    end

    if poundSnapshot then
        ESX.TriggerServerCallback('ari_garage:checkMoney', function(result)
            if not result or result.allowed == false then
                ESX.ShowNotification(TranslateCap('not_allowed'), 'error')
                return
            end

            if result.hasMoney == false then
                ESX.ShowNotification(TranslateCap('missing_money'))
                return
            end

            TriggerServerEvent('ari_garage:payPound', result.amount, data.poundName, data.vehicleProps)
            thisPound = nil
            TriggerServerEvent('ari_garage:updateOwnedVehicle', false, nil, nil, data, spawnCoords)
        end, data.exitVehicleCost, data.poundName, data.vehicleProps)
    end

    cb('ok')
end)

RegisterNUICallback('impound', function(data, cb)
    TriggerEvent('ari_garage:closemenu')

    if data.mode == 'track' then
        if data.poundSpawnPoint then
            SetNewWaypoint(data.poundSpawnPoint.x, data.poundSpawnPoint.y)
        end

        cb('ok')
        return
    end

    TriggerServerEvent('ari_garage:setImpound', data.poundName, data.vehicleProps)
    if data.poundSpawnPoint then
        SetNewWaypoint(data.poundSpawnPoint.x, data.poundSpawnPoint.y)
    end
    cb('ok')
end)

CreateThread(function()
    for _, garage in pairs(Config.Garages) do
        local defaultBlip = Config.GarageBlip
        local blip = AddBlipForCoord(garage.EntryPoint.x, garage.EntryPoint.y, garage.EntryPoint.z)
        SetBlipSprite(blip, garage.Sprite or defaultBlip.Sprite)
        SetBlipDisplay(blip, defaultBlip.Display)
        SetBlipScale(blip, garage.Scale or defaultBlip.Scale)
        SetBlipColour(blip, garage.Colour or defaultBlip.Colour)
        SetBlipAsShortRange(blip, defaultBlip.ShortRange)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(garage.Label or TranslateCap('parking_blip_name'))
        EndTextCommandSetBlipName(blip)
    end

    for _, impound in pairs(Config.Impounds) do
        if ImpoundMapBlipsEnabled() then
            local defaultBlip = Config.ImpoundBlip
            local blip = AddBlipForCoord(impound.GetOutPoint.x, impound.GetOutPoint.y, impound.GetOutPoint.z)
            SetBlipSprite(blip, impound.Sprite or defaultBlip.Sprite)
            SetBlipDisplay(blip, defaultBlip.Display)
            SetBlipScale(blip, impound.Scale or defaultBlip.Scale)
            SetBlipColour(blip, impound.Colour or defaultBlip.Colour)
            SetBlipAsShortRange(blip, defaultBlip.ShortRange)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(impound.Label or TranslateCap('Impound_blip_name'))
            EndTextCommandSetBlipName(blip)
        end
    end
end)

AddEventHandler('ari_garage:hasEnteredMarker', function(name, part)
    if part == 'EntryPoint' then
        local isInVehicle = IsPedInAnyVehicle(ESX.PlayerData.ped, false)
        thisGarage = Config.Garages[name]
        thisPound = nil
        ESX.TextUI(isInVehicle and TranslateCap('park_veh') or TranslateCap('access_parking'))
    elseif part == 'GetOutPoint' then
        thisPound = Config.Impounds[name]
        thisGarage = nil
        ESX.TextUI(TranslateCap('access_Impound'))
    end
end)

AddEventHandler('ari_garage:hasExitedMarker', function()
    thisGarage = nil
    thisPound = nil
    ESX.HideUI()
    TriggerEvent('ari_garage:closemenu')
end)

CreateThread(function()
    while true do
        local sleep = 500
        local playerPed = ESX.PlayerData.ped
        local coords = GetEntityCoords(playerPed)

        for _, garage in pairs(Config.Garages) do
            local entryPoint = garage.EntryPoint
            if #(coords - vector3(entryPoint.x, entryPoint.y, entryPoint.z)) < Config.DrawDistance then
                local marker = Config.Markers.EntryPoint
                DrawMarker(marker.Type, entryPoint.x, entryPoint.y, entryPoint.z,
                    0.0, 0.0, 0.0, 0, 0.0, 0.0,
                    marker.Size.x, marker.Size.y, marker.Size.z,
                    marker.Color.r, marker.Color.g, marker.Color.b,
                    marker.Alpha, false, true, 2, marker.Bob, false, false, false)
                sleep = 0
                break
            end
        end

        if ImpoundWorldAccessEnabled() then
            for _, impound in pairs(Config.Impounds) do
                local getOutPoint = impound.GetOutPoint
                if #(coords - vector3(getOutPoint.x, getOutPoint.y, getOutPoint.z)) < Config.DrawDistance then
                    local marker = Config.Markers.GetOutPoint
                    DrawMarker(marker.Type, getOutPoint.x, getOutPoint.y, getOutPoint.z,
                        0.0, 0.0, 0.0, 0, 0.0, 0.0,
                        marker.Size.x, marker.Size.y, marker.Size.z,
                        marker.Color.r, marker.Color.g, marker.Color.b,
                        marker.Alpha, false, true, 2, marker.Bob, false, false, false)
                    sleep = 0
                    break
                end
            end
        end

        nearMarker = (sleep == 0)
        Wait(sleep)
    end
end)

OpenGarageMenu = function(garageKey, garage)
    ESX.TriggerServerCallback('ari_garage:getVehiclesInParking', function(vehicles)
        ESX.TriggerServerCallback('ari_garage:getVehiclesImpounded', function(impoundedVehicles)
            ResetMenuState()

            for i = 1, #vehicles do
                if VehicleMatchesFilter(vehicles[i].vehicle, garage.VehicleFilter) then
                    currentVehicles[#currentVehicles + 1] = MapVehicleForUI(vehicles[i], 'stored')
                end
            end

            for i = 1, #impoundedVehicles do
                if VehicleMatchesFilter(impoundedVehicles[i].vehicle, garage.VehicleFilter) then
                    currentImpoundedVehicles[#currentImpoundedVehicles + 1] = MapVehicleForUI(impoundedVehicles[i])
                end
            end

            menuIsShowed = true
            lastOpenContext = { kind = 'garage', key = garageKey, ref = garage }
            PlayUISound()

            SendNUIMessage(BuildGaragePayload(garageKey, garage, currentVehicles, currentImpoundedVehicles))
            SetNuiFocus(true, true)
            ESX.HideUI()
        end, garageKey)
    end, garageKey)
end

OpenImpoundMenu = function(poundKey, pound)
    ESX.TriggerServerCallback('ari_garage:getVehiclesInPound', function(response)
        if not response or response.allowed == false then
            ESX.ShowNotification(TranslateCap('not_allowed'), 'error')
            return
        end

        local vehicles = response.vehicles or {}
        if not next(vehicles) then
            ESX.ShowNotification(TranslateCap('no_veh_Impound'))
            return
        end

        ResetMenuState()

        for i = 1, #vehicles do
            currentVehicles[#currentVehicles + 1] = MapVehicleForUI(vehicles[i], 'impounded')
        end

        menuIsShowed = true
        lastOpenContext = { kind = 'impound', key = poundKey, ref = pound }
        PlayUISound()

        SendNUIMessage(BuildImpoundPayload(poundKey, pound, currentVehicles, response))
        SetNuiFocus(true, true)
        ESX.HideUI()
    end, poundKey)
end

CreateThread(function()
    while true do
        if nearMarker then
            local playerPed = ESX.PlayerData.ped
            local coords = GetEntityCoords(playerPed)
            local isInMarker = false
            local currentMarker = nil
            local currentPart = nil

            for garageKey, garage in pairs(Config.Garages) do
                local entryPoint = garage.EntryPoint
                if #(coords - vector3(entryPoint.x, entryPoint.y, entryPoint.z)) < Config.Markers.EntryPoint.Size.x then
                    isInMarker = true
                    currentMarker = garageKey
                    currentPart = 'EntryPoint'

                    local isInVehicle = IsPedInAnyVehicle(playerPed, false)
                    if not isInVehicle then
                        if IsControlJustReleased(0, 38) and not menuIsShowed then
                            if not IsJobAllowed(garage.AllowedJobs, garage.AllowedGrades) then
                                ESX.ShowNotification(TranslateCap('not_allowed'), 'error')
                            else
                                OpenGarageMenu(garageKey, garage)
                            end
                        end
                    elseif IsControlJustReleased(0, 38) then
                        local vehicle = GetVehiclePedIsIn(playerPed, false)
                        local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)

                        ESX.TriggerServerCallback('ari_garage:checkVehicleOwner', function(owner)
                            if not owner then
                                ESX.ShowNotification(TranslateCap('not_owning_veh'), 'error')
                                return
                            end

                            ESX.Game.DeleteVehicle(vehicle)
                            TriggerServerEvent('ari_garage:updateOwnedVehicle', true, garageKey, nil, { vehicleProps = vehicleProps })
                        end, vehicleProps.plate)
                    end

                    break
                end
            end

            if ImpoundWorldAccessEnabled() then
                for impoundKey, impound in pairs(Config.Impounds) do
                    local getOutPoint = impound.GetOutPoint
                    if #(coords - vector3(getOutPoint.x, getOutPoint.y, getOutPoint.z)) < 2.0 then
                        isInMarker = true
                        currentMarker = impoundKey
                        currentPart = 'GetOutPoint'

                        if IsControlJustReleased(0, 38) and not menuIsShowed then
                            OpenImpoundMenu(impoundKey, impound)
                        end

                        break
                    end
                end
            end

            if isInMarker and (not HasAlreadyEnteredMarker or LastMarker ~= currentMarker or LastPart ~= currentPart) then
                if LastMarker ~= currentMarker or LastPart ~= currentPart then
                    TriggerEvent('ari_garage:hasExitedMarker')
                end

                HasAlreadyEnteredMarker = true
                LastMarker = currentMarker
                LastPart = currentPart
                TriggerEvent('ari_garage:hasEnteredMarker', currentMarker, currentPart)
            end

            if not isInMarker and HasAlreadyEnteredMarker then
                HasAlreadyEnteredMarker = false
                TriggerEvent('ari_garage:hasExitedMarker')
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)
