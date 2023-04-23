local spawnedPeds = {}
local localDisplayVehicle = nil

function DeleteSpawnedPed(index)
    if spawnedPeds[index] and DoesEntityExist(spawnedPeds[index]) then 
        DeleteEntity(spawnedPeds[index])
    end
    spawnedPeds[index] = nil
end

function EnsureSpawnedPed(index)
    local ped = spawnedPeds[index]
    if ped and DoesEntityExist(ped) then return ped end
    local location = Locations[index].locations.interact
    if not location.ped then return end
    local ped = CreateNPC(location.ped, location.coords.x, location.coords.y, location.coords.z, location.heading, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, location.heading)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    spawnedPeds[index] = ped
    return ped
end

function MarkerEvent(index, locationType)
    if locationType == "interact" then
        ShowInteractText(_L("marker_interact"))
    elseif locationType == "spawn" then
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if DoesEntityExist(vehicle) then
            ShowInteractText(_L("marker_return"))
        end
    end
    return IsControlJustPressed(1, 51)
end

function DeleteLocalDisplay()
    if localDisplayVehicle and DoesEntityExist(localDisplayVehicle.vehicle) then 
        DeleteEntity(localDisplayVehicle.vehicle)
    end
    localDisplayVehicle = nil
end

function SpawnLocalDisplay(index, vehicleIndex)
    DeleteLocalDisplay()
    localDisplayVehicle = {index = vehicleIndex, vehicle = nil }
    local location = Locations[index]
    local spawn = Locations[index].locations.spawn
    local vehicleCfg = location.vehicles[vehicleIndex]
    local vehicle = CreateVeh(vehicleCfg.model, spawn.coords.x, spawn.coords.y, spawn.coords.z, spawn.heading, false, true)
    if vehicleIndex ~= localDisplayVehicle?.index then 
        DeleteEntity(vehicle)
        return
    end
    SetEntityCollision(vehicle, false, false)
    SetVehicleDoorsLocked(vehicle, 2)
    FreezeEntityPosition(vehicle, true)
    localDisplayVehicle = {index = vehicleIndex, vehicle = vehicle }
    return vehicle
end

function RentVehicle(index, vehicleIndex)
    local props = (localDisplayVehicle and GetVehicleProperties(localDisplayVehicle.vehicle) or nil)
    DeleteLocalDisplay()
    ServerCallback("pickle_rental:rentVehicle", function(success, plate)
        if success then 
            local location = Locations[index]
            local vehicleCfg = location.vehicles[vehicleIndex]
            local spawn = location.locations.spawn
            local vehicle = CreateVeh(vehicleCfg.model, spawn.coords.x, spawn.coords.y, spawn.coords.z, spawn.heading, true, false)
            if props then 
                props.plate = plate
                SetVehicleProperties(vehicle, props)
            else
                local props = {plate = plate}
                SetVehicleProperties(vehicle, props)
            end
            TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
            exports['LegacyFuel']:SetFuel(veh, 100.0)
            SetVehicleFixed(veh)
            TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
            TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
            SetVehicleEngineOn(veh, true, true)
            SetTimeout(100, function()
                TriggerServerEvent("pickle_rental:registerRental", VehToNet(vehicle))
            end)
        end
    end, index, vehicleIndex)
end

function RentalMenu(index)
    activeMenu = index
    local location = Locations[index]
    local options = {}
    for i=1, #location.vehicles do 
        if CanAccessGroup(location.vehicles[i].groups) then 
            options[#options + 1] = {label = location.vehicles[i].label, description = _L("menu_price", location.vehicles[i].price), index = i}
        end
    end
    if #options < 1 then 
        ShowNotification(_L("menu_no_vehicles"))
        activeMenu = nil
        return 
    end
    lib.registerMenu({
        id = 'pickle_rental:rentalMenu',
        title = location.title,
        position = 'top-right',
        onSelected = function(selected, secondary, args)
            local option = options[selected]
            SpawnLocalDisplay(index, option.index)
        end,
        onClose = function(keyPressed)
            DeleteLocalDisplay()
            activeMenu = nil
        end,
        options = options
    }, function(selected, scrollIndex, args)
        local option = options[selected]
        activeMenu = nil
        RentVehicle(index, option.index)
    end)

    lib.showMenu('pickle_rental:rentalMenu')
end

function ReturnRental(index, vehicle)
    ServerCallback("pickle_rental:returnVehicle", function(success) 
        if success and spawnedPeds[index] then 
            local ped = PlayerPedId()
            local coords = GetOffsetFromEntityInWorldCoords(spawnedPeds[index], 0.0, 0.75, 0.0)
            SetEntityCoords(ped, coords.x, coords.y, coords.z - 1.0)
            SetEntityHeading(ped, GetEntityHeading(spawnedPeds[index]) + 180.0)
        end
    end, index, VehToNet(vehicle))
end

function InteractMarker(index, locationType)
    if locationType == "interact" then
        RentalMenu(index)
    elseif locationType == "spawn" then
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if DoesEntityExist(vehicle) then
            ReturnRental(index, vehicle)
        end
    end
end

CreateThread(function()
    for i=1, #Locations do 
        local location = Locations[i]
        if location.blip then 
            local blip = location.blip
            blip.location = location.locations.interact.coords
            CreateBlip(blip)
        end
    end
    while true do
        local wait = 1000
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        for i=1, #Locations do 
            local location = Locations[i]
            for k,v in pairs(location.locations) do 
                local coords = v.coords
                local dist = #(pcoords-coords)
                if dist < Config.RenderDistance then
                    wait = 0
                    local spawnedPed
                    local insideVehicle = DoesEntityExist(GetVehiclePedIsIn(ped, false))
                    if k == "interact" then 
                        spawnedPed = EnsureSpawnedPed(i)
                    end
                    if (k == "spawn" and insideVehicle) or (k == "interact" and not spawnedPed) then 
                        DrawMarker(2, coords.x, coords.y, coords.z + (v.offsetZ or 0), 0, 0, 0, 0, 0, 0, 0.25, 0.25, 0.25, 255, 255, 255, 127, false, true)
                    end
                    if dist < (v.radius or 1.5) and MarkerEvent(i, k) then 
                        InteractMarker(i, k)
                    end
                elseif k == "interact" then
                    DeleteSpawnedPed(i)
                end
                if activeMenu == i and k == "interact" and dist > 1.5 then 
                    lib.hideMenu(true)
                end
            end
        end
        Wait(wait)
    end
end)

AddEventHandler("onResourceStop", function(name) 
    if name ~= GetCurrentResourceName() then return end
    for k,v in pairs(spawnedPeds) do 
        DeleteEntity(v)
    end
end)
