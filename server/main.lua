--[[
    ari_garage — Server
    Version: 1.15.4-ari
--]]

local VEHICLE_STATE = {
    OUT = 0,
    STORED = 1,
    IMPOUNDED = 2,
}

CreateThread(function()
    local resourceName = GetCurrentResourceName()
    local version = GetResourceMetadata(resourceName, 'version', 0) or '1.15.4-ari'
    local author = GetResourceMetadata(resourceName, 'author', 0) or 'Ari'

    Wait(500)
    print('^5╔══════════════════════════════════════════════════╗^0')
    print('^5║               ^4🚗  ARI GARAGE  🚗               ^5║^0')
    print('^5╠══════════════════════════════════════════════════╣^0')
    print('^5║  ^2> Recurso:   ^0' .. string.format('%-31s', resourceName) .. '^5║^0')
    print('^5║  ^2> Versión:   ^0' .. string.format('%-31s', version) .. '^5║^0')
    print('^5║  ^2> Autora:    ^0' .. string.format('%-31s', author) .. '^5║^0')
    print('^5║  ^2> Sistema:   ^5GARAGE + IMPOUND LISTO         ^5║^0')
    print('^5╠══════════════════════════════════════════════════╣^0')
    print('^5║         ^3Todo en orden, Ari. A rodar.          ^5║^0')
    print('^5╚══════════════════════════════════════════════════╝^0')
end)

local function getPlayerFromSource(source)
    local xPlayer = ESX and ESX.Player and ESX.Player(source)
    if not xPlayer then
        return nil
    end

    return xPlayer, xPlayer.getIdentifier()
end

local function getPlayerJobData(xPlayer)
    if not xPlayer then return nil, -1 end
    local job = xPlayer.getJob and xPlayer.getJob() or xPlayer.job
    if not job then
        return nil, -1
    end

    local grade = job.grade
    if type(grade) ~= 'number' then
        grade = tonumber(job.grade_level or job.grade_name or 0) or 0
    end

    return job.name, grade
end

local function isJobAllowedForImpound(xPlayer, impound)
    if not impound or not impound.AllowedJobs then
        return true
    end

    local playerJob, playerGrade = getPlayerJobData(xPlayer)
    if not playerJob then
        return false
    end

    for i = 1, #impound.AllowedJobs do
        local allowedJob = impound.AllowedJobs[i]
        if playerJob == allowedJob then
            if impound.AllowedGrades and impound.AllowedGrades[allowedJob] then
                return playerGrade >= impound.AllowedGrades[allowedJob]
            end

            return true
        end
    end

    return false
end

-- ── Single source of truth for impound release pricing ────────────────────
local function calculateReleaseCost(impound, props)
    if not impound then
        return 0
    end

    local baseCost = impound.Cost or 0
    local amount

    if not props or (Config.ImpoundDamageMult or 1.0) <= 1.0 then
        amount = baseCost
    else
        local engineHealth = math.min(props.engineHealth or 1000, 1000)
        local damageRatio = math.max(0.0, 1.0 - (engineHealth / 1000))
        local mult = 1.0 + (damageRatio * (Config.ImpoundDamageMult - 1.0))
        amount = math.floor(baseCost * mult)
    end

    local cfg = Config.ImpoundMenuOnly
    if cfg and cfg.ReleaseFeeOverride ~= nil then
        return math.max(0, math.floor(tonumber(cfg.ReleaseFeeOverride) or 0))
    end

    local feeMul = cfg and tonumber(cfg.ReleaseFeeMultiplier) or 1.0
    if not feeMul or feeMul ~= feeMul then
        feeMul = 1.0
    end

    return math.max(0, math.floor(amount * feeMul))
end

local function computeReleaseData(xPlayer, impound, props)
    local allowed = isJobAllowedForImpound(xPlayer, impound)

    if not allowed then
        return { allowed = false, amount = 0, isFree = false, reason = 'not_allowed' }
    end

    local finalCost = calculateReleaseCost(impound, props)

    if impound and impound.FreeRelease then
        finalCost = 0
    end

    return {
        allowed = true,
        amount = math.max(0, finalCost),
        isFree = finalCost <= 0,
        reason = nil,
    }
end

local function decodeVehicleRows(rows, impoundFallback, xPlayer)
    rows = rows or {}
    local vehicles = {}

    for i = 1, #rows do
        local props = rows[i].vehicle and json.decode(rows[i].vehicle) or nil
        if props then
            local stored = tonumber(rows[i].stored) or 0
            local impCfg = nil

            if stored == 2 then
                if rows[i].pound and Config.Impounds[rows[i].pound] then
                    impCfg = Config.Impounds[rows[i].pound]
                else
                    impCfg = impoundFallback
                end
            end

            local releaseCost, releaseFree = 0, false
            if impCfg and xPlayer then
                local rd = computeReleaseData(xPlayer, impCfg, props)
                if rd.allowed then
                    releaseCost = rd.amount
                    releaseFree = rd.isFree == true
                end
            elseif impCfg then
                releaseCost = calculateReleaseCost(impCfg, props)
            end

            vehicles[#vehicles + 1] = {
                vehicle = props,
                plate = rows[i].plate,
                releaseCost = releaseCost,
                releaseFree = releaseFree,
                pound = rows[i].pound,
                parking = rows[i].parking,
                stored = rows[i].stored,
            }
        end
    end

    return vehicles
end

local function canAffordImpound(xPlayer, amount)
    if amount <= 0 or not xPlayer then return true end

    local method = Config.PaymentMethod or 'cash'

    if method == 'bank' then
        return xPlayer.getAccount('bank').money >= amount
    elseif method == 'any' then
        return (xPlayer.getMoney() + xPlayer.getAccount('bank').money) >= amount
    end

    return xPlayer.getMoney() >= amount
end

local function deductImpoundPayment(xPlayer, amount)
    if amount <= 0 then return true end
    if not xPlayer then return false end

    local method = Config.PaymentMethod or 'cash'

    if method == 'bank' then
        if xPlayer.getAccount('bank').money < amount then
            return false
        end
        xPlayer.removeAccountMoney('bank', amount, 'Impound Fee')
        return true
    elseif method == 'any' then
        local cash = xPlayer.getMoney()
        local bank = xPlayer.getAccount('bank').money

        if cash >= amount then
            xPlayer.removeMoney(amount, 'Impound Fee')
            return true
        end

        if (cash + bank) < amount then
            return false
        end

        if cash > 0 then
            xPlayer.removeMoney(cash, 'Impound Fee (cash)')
        end
        xPlayer.removeAccountMoney('bank', amount - cash, 'Impound Fee (bank)')
        return true
    end

    if xPlayer.getMoney() < amount then
        return false
    end
    xPlayer.removeMoney(amount, 'Impound Fee')
    return true
end

local function updateVehicleState(identifier, plate, state, parking, impound, vehicleProps)
    return MySQL.update.await(
        [[
            UPDATE owned_vehicles
            SET `stored` = ?, `parking` = ?, `pound` = ?, `vehicle` = ?
            WHERE `plate` = ? AND `owner` = ?
        ]],
        {
            state,
            parking,
            impound,
            json.encode(vehicleProps),
            plate,
            identifier,
        }
    )
end

local function getOwnedVehicleByPlate(identifier, plate)
    return MySQL.single.await(
        'SELECT `plate`, `vehicle`, `stored`, `parking`, `pound` FROM owned_vehicles WHERE `owner` = ? AND `plate` = ? LIMIT 1',
        { identifier, plate }
    )
end

--- Resuelve fila en owned_vehicles aunque `props.plate` no coincida exactamente con la columna `plate`.
local function getOwnedVehicleForPlayer(identifier, data)
    if not data or not data.vehicleProps then
        return nil
    end

    local propsPlate = data.vehicleProps.plate
    local rowPlate = data.plate
    if propsPlate and propsPlate ~= '' then
        local row = getOwnedVehicleByPlate(identifier, propsPlate)
        if row then
            return row
        end
    end
    if rowPlate and rowPlate ~= '' and rowPlate ~= propsPlate then
        local row = getOwnedVehicleByPlate(identifier, rowPlate)
        if row then
            return row
        end
    end

    local cand = propsPlate or rowPlate
    if not cand or cand == '' then
        return nil
    end

    return MySQL.single.await(
        [[
            SELECT `plate`, `vehicle`, `stored`, `parking`, `pound`
            FROM `owned_vehicles`
            WHERE `owner` = ? AND UPPER(REPLACE(REPLACE(`plate`, ' ', ''), '-', '')) = UPPER(REPLACE(REPLACE(?, ' ', ''), '-', ''))
            LIMIT 1
        ]],
        { identifier, cand }
    )
end

local function getOwnedVehicleByPlateAnyOwner(plate)
    return MySQL.single.await(
        'SELECT `owner`, `plate`, `vehicle`, `stored`, `parking`, `pound` FROM owned_vehicles WHERE `plate` = ? LIMIT 1',
        { plate }
    )
end

local function spawnOwnedVehicle(source, spawn, data)
    if not data or not data.vehicleProps or not data.spawnPoint then return end

    ESX.OneSync.SpawnVehicle(data.vehicleProps.model, spawn, data.spawnPoint.heading, data.vehicleProps, function(netId)
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        Wait(300)

        if vehicle and vehicle ~= 0 then
            TaskWarpPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
        end
    end)
end

RegisterServerEvent('ari_garage:updateOwnedVehicle')
AddEventHandler('ari_garage:updateOwnedVehicle', function(stored, parking, impound, data, spawn)
    local source = source
    local xPlayer, identifier = getPlayerFromSource(source)
    if not xPlayer or not data or not data.vehicleProps then
        return
    end

    local ownedVehicle = getOwnedVehicleForPlayer(identifier, data)
    if not ownedVehicle then
        xPlayer.showNotification(TranslateCap('not_owning_veh'))
        return
    end

    -- Matrícula canónica de BD (el JSON a veces trae plate distinto o vacío)
    data.vehicleProps.plate = ownedVehicle.plate
    if not data.vehicleProps.model then
        local decoded = ownedVehicle.vehicle and json.decode(ownedVehicle.vehicle) or nil
        if decoded and decoded.model then
            data.vehicleProps.model = decoded.model
        end
    end

    local state = stored and VEHICLE_STATE.STORED or VEHICLE_STATE.OUT
    local updated = updateVehicleState(identifier, ownedVehicle.plate, state, parking, impound, data.vehicleProps)
    if updated < 1 then
        return
    end

    if state == VEHICLE_STATE.STORED then
        -- Auto-impound on empty fuel (Config.ImpoundOnEmpty)
        if Config.ImpoundOnEmpty
            and impound == nil
            and data.vehicleProps.fuelLevel ~= nil
            and data.vehicleProps.fuelLevel <= 0
        then
            local fallbackImpound = next(Config.Impounds or {})
            if fallbackImpound then
                updateVehicleState(identifier, data.vehicleProps.plate, VEHICLE_STATE.IMPOUNDED, nil, fallbackImpound, data.vehicleProps)
                xPlayer.showNotification(TranslateCap('veh_impounded'))
                return
            end
        end

        xPlayer.showNotification(TranslateCap('veh_stored'))
        return
    end

    spawnOwnedVehicle(source, spawn, data)
end)

RegisterServerEvent('ari_garage:setImpound')
AddEventHandler('ari_garage:setImpound', function(impoundName, vehicleProps)
    local source = source
    local xPlayer, identifier = getPlayerFromSource(source)
    if not xPlayer or not vehicleProps or not vehicleProps.plate then
        return
    end

    local impound = Config.Impounds[impoundName]
    if not impound then
        return
    end

    local ownedVehicle = getOwnedVehicleByPlateAnyOwner(vehicleProps.plate)
    if not ownedVehicle then
        xPlayer.showNotification(TranslateCap('not_owning_veh'))
        return
    end

    local updated = updateVehicleState(ownedVehicle.owner, vehicleProps.plate, VEHICLE_STATE.IMPOUNDED, nil, impoundName, vehicleProps)
    if updated < 1 then
        return
    end

    xPlayer.showNotification(TranslateCap('veh_impounded'))

    -- Notify the actual owner (we already have it from getOwnedVehicleByPlateAnyOwner — no extra SELECT needed)
    if not Config.NotifyOnImpound or ownedVehicle.owner == identifier then
        return
    end

    local targetPlayer = ESX.GetPlayerFromIdentifier(ownedVehicle.owner)
    if targetPlayer and targetPlayer.source ~= source then
        targetPlayer.showNotification(TranslateCap('veh_impounded'))
    end
end)

ESX.RegisterServerCallback('ari_garage:getVehiclesInParking', function(source, cb, parking)
    local xPlayer, identifier = getPlayerFromSource(source)
    if not xPlayer then
        return cb({})
    end

    -- Todos los garajes comunicados: muestra TODOS los vehículos almacenados (stored = 1)
    -- Sin importar en qué parking fueron guardados originalmente.
    local result = MySQL.query.await(
        [[
            SELECT `plate`, `vehicle`, `stored`, `parking`, `pound`
            FROM owned_vehicles
            WHERE `owner` = ? AND `stored` = ?
            ORDER BY `plate` ASC
        ]],
        { identifier, VEHICLE_STATE.STORED }
    )

    cb(decodeVehicleRows(result, nil, nil))
end)

ESX.RegisterServerCallback('ari_garage:getVehiclesImpounded', function(source, cb, garageKey)
    local xPlayer, identifier = getPlayerFromSource(source)
    if not xPlayer then
        return cb({})
    end

    local result = MySQL.query.await(
        [[
            SELECT `plate`, `vehicle`, `stored`, `parking`, `pound`
            FROM owned_vehicles
            WHERE `owner` = ? AND `stored` IN (?, ?)
            ORDER BY `stored` DESC, `plate` ASC
        ]],
        { identifier, VEHICLE_STATE.OUT, VEHICLE_STATE.IMPOUNDED }
    )

    local fallbackImpound = nil
    if garageKey and Config.Garages[garageKey] and Config.Garages[garageKey].ImpoundedName then
        local iname = Config.Garages[garageKey].ImpoundedName
        fallbackImpound = Config.Impounds[iname]
    end

    cb(decodeVehicleRows(result, fallbackImpound, xPlayer))
end)

ESX.RegisterServerCallback('ari_garage:getVehiclesInPound', function(source, cb, impoundName)
    local xPlayer, identifier = getPlayerFromSource(source)
    if not xPlayer then
        return cb({ allowed = false, vehicles = {} })
    end

    local impound = Config.Impounds[impoundName]
    if not impound then
        return cb({ allowed = false, vehicles = {} })
    end

    if not isJobAllowedForImpound(xPlayer, impound) then
        return cb({
            allowed = false,
            vehicles = {},
            reason = 'not_allowed',
        })
    end

    local result = MySQL.query.await(
        [[
            SELECT `plate`, `vehicle`, `stored`, `parking`, `pound`
            FROM owned_vehicles
            WHERE `owner` = ? AND `stored` = ? AND `pound` = ?
            ORDER BY `plate` ASC
        ]],
        { identifier, VEHICLE_STATE.IMPOUNDED, impoundName }
    )

    local vehicles = decodeVehicleRows(result, impound, xPlayer)
    local applyFreeRelease = impound.FreeRelease == true and isJobAllowedForImpound(xPlayer, impound)
    if applyFreeRelease then
        for i = 1, #vehicles do
            vehicles[i].releaseCost = 0
            vehicles[i].releaseFree = true
        end
    end

    cb({
        allowed = true,
        vehicles = vehicles,
        cost = impound.Cost or 0,
        freeRelease = applyFreeRelease,
    })
end)

ESX.RegisterServerCallback('ari_garage:checkVehicleOwner', function(source, cb, plate)
    local xPlayer, identifier = getPlayerFromSource(source)
    if not xPlayer then
        return cb(false)
    end

    local ownedVehicle = getOwnedVehicleByPlate(identifier, plate)
    cb(ownedVehicle ~= nil)
end)

ESX.RegisterServerCallback('ari_garage:checkMoney', function(source, cb, amount, impoundName, vehicleProps)
    local xPlayer = ESX.Player(source)
    if not xPlayer then
        return cb({ allowed = false, amount = amount or 0, isFree = false, hasMoney = false })
    end

    if impoundName and Config.Impounds[impoundName] then
        local releaseData = computeReleaseData(xPlayer, Config.Impounds[impoundName], vehicleProps or {})
        if not releaseData.allowed then
            releaseData.hasMoney = false
            return cb(releaseData)
        end

        releaseData.hasMoney = canAffordImpound(xPlayer, releaseData.amount)
        return cb(releaseData)
    end

    cb({
        allowed = true,
        amount = amount or 0,
        isFree = (amount or 0) <= 0,
        hasMoney = canAffordImpound(xPlayer, amount or 0),
    })
end)

RegisterServerEvent('ari_garage:payPound')
AddEventHandler('ari_garage:payPound', function(amount, impoundName, vehicleProps)
    local source = source
    local xPlayer = ESX.Player(source)
    if not xPlayer then
        return
    end

    local finalAmount = amount or 0
    if impoundName and Config.Impounds[impoundName] then
        local releaseData = computeReleaseData(xPlayer, Config.Impounds[impoundName], vehicleProps or {})
        if not releaseData.allowed then
            xPlayer.showNotification(TranslateCap('not_allowed'))
            return
        end

        finalAmount = releaseData.amount
    end

    if not deductImpoundPayment(xPlayer, finalAmount) then
        xPlayer.showNotification(TranslateCap('missing_money'))
        return
    end

    if finalAmount > 0 then
        xPlayer.showNotification(TranslateCap('pay_Impound_bill', finalAmount))
    else
        xPlayer.showNotification(TranslateCap('veh_Impound_released'))
    end
end)
