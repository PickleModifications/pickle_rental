RentalVehicles = {}
local rentalVehicleQueue = {}

function GetRandomCharacter(typeOf)
	return (typeOf == "letter" and string.char(math.random(65,  90)) or string.char(math.random(48,  57)))
end

function GeneratePlate()
    local plate = ""
    local format = Config.Rental.plateFormat
    local array = {}
    format:gsub(".", function(char) table.insert(array, char) end)
    for i=1, #array do 
        if array[i] == "_" then
            plate = plate .. GetRandomCharacter("letter")
        elseif array[i] == "." then
            plate = plate .. GetRandomCharacter("number")
        else
            plate = plate .. array[i]
        end
    end
    return plate
end

function RentalThread(net_id)
    CreateThread(function()
        while RentalVehicles[net_id] and RentalVehicles[net_id].timeLeft > 0 do 
            RentalVehicles[net_id].timeLeft = RentalVehicles[net_id].timeLeft - 1
            Wait(60000)
        end
    end)
end

function Max(number, max)
    if number > max then return number end
    if number < 0 then return 0 end
    return number
end

RegisterCallback("pickle_rental:rentVehicle", function(source, cb, index, vehicleIndex)
    if rentalVehicleQueue[source] then return cb(false) end
    local location = Locations[index]
    local vehicleCfg = location.vehicles[vehicleIndex]
    local spawn = location.locations.spawn
    local count = Search(source, "money")
    if count - vehicleCfg.price < 0 then 
        ShowNotification(source, _L("spawn_not_afford", -(count - vehicleCfg.price)))
        return cb(false)
    end
    RemoveItem(source, "money", vehicleCfg.price)
    rentalVehicleQueue[source] = {index = index, vehicleIndex = vehicleIndex}
    cb(true, GeneratePlate())
end)

RegisterCallback("pickle_rental:returnVehicle", function(source, cb, index, net_id)
    local source = source
    if not RentalVehicles[net_id] or RentalVehicles[net_id].source ~= source then 
        ShowNotification(source, _L("return_not_own"))
        return cb(false)
    end
    local entity = NetworkGetEntityFromNetworkId(net_id)
    if not DoesEntityExist(entity) then 
        ShowNotification(source, _L("return_not_exist"))
        RentalVehicles[net_id] = nil
        return cb(false)
    end
    local rental = RentalVehicles[net_id]
    local deposit = math.floor(rental.deposit * Max(rental.timeLeft / Config.Rental.time, 1))
    deposit = math.floor(deposit * Max(GetVehicleBodyHealth(entity) / rental.health, 1))
    deposit = (deposit > 0 and deposit or 0)
    RentalVehicles[net_id] = nil
    AddItem(source, "money", deposit)
    ShowNotification(source, _L("return_success", deposit))
    DeleteEntity(entity)
    cb(true)
end)

RegisterNetEvent("pickle_rental:registerRental", function(net_id)
    local source = source
    if not rentalVehicleQueue[source] then return end
    local queue = rentalVehicleQueue[source]
    local location = Locations[queue.index]
    local vehicleCfg = location.vehicles[queue.vehicleIndex]
    local entity = NetworkGetEntityFromNetworkId(net_id)
    rentalVehicleQueue[source] = nil
    if not entity or GetEntityModel(entity) ~= vehicleCfg.model then
        ShowNotification(source, _L("spawn_failed", vehicleCfg.price))
        AddItem(source, "money", vehicleCfg.price)
        return
    end
    ShowNotification(source, _L("spawn_success", vehicleCfg.price))
    RentalVehicles[net_id] = {
        source = source,
        index = queue.index,
        deposit = vehicleCfg.price,
        vehicleIndex = queue.vehicleIndex,
        timeLeft = Config.Rental.time,
        health = GetVehicleBodyHealth(entity)
    }
    RentalThread(net_id)
end)