ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Vehicle fetch
ESX.RegisterServerCallback('eden_garage:getVehicles', function(source, cb)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local vehicules = {}

    MySQL.Async.fetchAll("SELECT * FROM owned_vehicles WHERE owner = @identifier AND type = @type", {
		['@identifier'] = xPlayer.getIdentifier(),
		['@type'] = 'car'
	}, function(data) 
        for _, v in pairs(data) do
            local vehicle = json.decode(v.vehicle)

            table.insert(vehicules, {
                vehicle = vehicle,
                stored = v.stored,
				inpounded = v.inpounded,
                plate = v.plate
            })
        end

        cb(vehicules)
    end)
end)

-- Store & update vehicle properties
ESX.RegisterServerCallback('eden_garage:stockv', function(source, cb, vehicleProps)
    local isFound = false
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local vehicules = getPlayerVehicles(xPlayer.getIdentifier())
    local plate = vehicleProps.plate

    for _, v in pairs(vehicules) do
        if (plate == plate) then
            local vehprop = json.encode(vehicleProps)

            MySQL.Sync.execute('UPDATE owned_vehicles SET vehicle = @vehprop WHERE plate = @plate', {
                ['@vehprop'] = vehprop,
                ['@plate'] = plate
            })

            isFound = true
            break
        end
    end

    cb(isFound)
end)

RegisterServerEvent('eden_garage:deletevehicle_sv')
AddEventHandler('eden_garage:deletevehicle_sv', function(vehicle)
	TriggerClientEvent('eden_garage:deletevehicle_cl', -1, vehicle)
end)

-- Change state of vehicle
RegisterServerEvent('eden_garage:modifystate')
AddEventHandler('eden_garage:modifystate', function(vehicle, stored, inpounded)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local vehicules = getPlayerVehicles(xPlayer.getIdentifier())
    local plate = vehicle.plate
	local stored = stored
	local inpounded = inpounded

    if plate ~= nil then
        plate = plate:gsub('^%s*(.-)%s*$', '%1')
    end

    for _, v in pairs(vehicules) do
        if v.plate == plate then
            MySQL.Sync.execute('UPDATE owned_vehicles SET stored = @stored, inpounded = @inpounded WHERE plate = @plate', {
                ['@stored'] = stored,
				['@inpounded'] = inpounded,
                ['@plate'] = plate
            })
            break
        end
    end
end)

-- Function to recover plates deprecated and removed.
-- Get list of vehicles already out
ESX.RegisterServerCallback('eden_garage:getOutVehicles', function(source, cb)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local vehicules = {}

    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @identifier AND stored = false AND inpounded = false', {
        ['@identifier'] = xPlayer.getIdentifier()
    }, function(data)
        for _, v in pairs(data) do
            local vehicle = json.decode(v.vehicle)
            table.insert(vehicules, vehicle)
        end

        cb(vehicules)
    end)
end)

-- Check player has funds
ESX.RegisterServerCallback('eden_garage:checkMoney', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer.get('money') >= Config.Price then
        cb(true)
    else
        cb(false)
    end
end)

-- Withdraw money
RegisterServerEvent('eden_garage:pay')
AddEventHandler('eden_garage:pay', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.removeMoney(Config.Price)
    TriggerClientEvent('esx:showNotification', source, _U('you_paid', Config.Price))
end)

-- Find player vehicles
function getPlayerVehicles(identifier)
    local vehicles = {}

    local data = MySQL.Sync.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @identifier', {
        ['@identifier'] = identifier
    })

    for _, v in pairs(data) do
        local vehicle = json.decode(v.vehicle)

        table.insert(vehicles, {
            id = v.id,
            plate = v.plate
        })
    end

    return vehicles
end

-- Debug
RegisterServerEvent('eden_garage:debug')
AddEventHandler('eden_garage:debug', function(var)
    print(to_string(var))
end)

function table_print(tt, indent, done)
    done = done or {}
    indent = indent or 0

    if type(tt) == 'table' then
        local sb = {}

        for key, value in pairs(tt) do
            table.insert(sb, string.rep(' ', indent)) -- indent it

            if type(value) == 'table' and not done[value] then
                done[value] = true
                table.insert(sb, '{\n')
                table.insert(sb, table_print(value, indent + 2, done))
                table.insert(sb, string.rep(' ', indent)) -- indent it
                table.insert(sb, '}\n')
            elseif 'number' == type(key) then
                table.insert(sb, string.format('\'%s\'\n', tostring(value)))
            else
                table.insert(sb, string.format('%s = \'%s\'\n', tostring(key), tostring(value)))
            end
        end

        return table.concat(sb)
    else
        return tt .. '\n'
    end
end

function to_string(tbl)
    if 'nil' == type(tbl) then
        return tostring(nil)
    elseif 'table' == type(tbl) then
        return table_print(tbl)
    elseif 'string' == type(tbl) then
        return tbl
    else
        return tostring(tbl)
    end
end

-- Return all vehicles to garage (state update) on server restart
MySQL.ready(function ()
    MySQL.Sync.execute("UPDATE owned_vehicles SET stored = true WHERE stored = false AND inpounded = false", {})
end)

-- Pay vehicle repair cost
RegisterServerEvent('eden_garage:payhealth')
AddEventHandler('eden_garage:payhealth', function(price)
    local xPlayer = ESX.GetPlayerFromId(source)

    if price > 0 then
        xPlayer.removeMoney(price)
        TriggerClientEvent('esx:showNotification', source, _U('you_paid', price))
    end
end)

-- Log to the console
RegisterServerEvent('eden_garage:logging')
AddEventHandler('eden_garage:logging', function(logging)
    RconPrint(logging)
end)
