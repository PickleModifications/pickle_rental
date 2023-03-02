function ModelRequest(modelHash)
    if not IsModelInCdimage(modelHash) then return end
    RequestModel(modelHash)
    local loaded
    for i=1, 100 do 
        if HasModelLoaded(modelHash) then
            loaded = true 
            break
        end
        Wait(100)
    end
    return loaded
end

function CreateVeh(modelHash, ...)
    if not ModelRequest(modelHash) then 
        print("Couldn't load model: " .. modelHash)
        return 
    end
    local veh = CreateVehicle(modelHash, ...)
    SetModelAsNoLongerNeeded(modelHash)
    GiveKeys(veh)
    return veh
end

function CreateNPC(modelHash, ...)
    if not ModelRequest(modelHash) then 
        print("Couldn't load model: " .. modelHash)
        return 
    end
    local ped = CreatePed(26, modelHash, ...)
    SetModelAsNoLongerNeeded(modelHash)
    return ped
end

function CreateProp(modelHash, ...)
    if not ModelRequest(modelHash) then 
        print("Couldn't load model: " .. modelHash)
        return 
    end
    local obj = CreateObject(modelHash, ...)
    SetModelAsNoLongerNeeded(modelHash)
    return obj
end

function CreateBlip(data)
    local x,y,z = table.unpack(data.location)
    local blip = AddBlipForCoord(x, y, z)
    SetBlipSprite(blip, data.id)
    SetBlipDisplay(blip, data.display)
    SetBlipScale(blip, data.scale)
    SetBlipColour(blip, data.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(data.label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local interactTick = 0
local interactCheck = false
local interactText = nil

function ShowInteractText(text)
    local timer = GetGameTimer()
    interactTick = timer
    if interactText == nil or interactText ~= text then 
        interactText = text
        lib.showTextUI(text)
    end
    if interactCheck then return end
    interactCheck = true
    CreateThread(function()
        Wait(150)
        local timer = GetGameTimer()
        interactCheck = false
        if timer ~= interactTick then 
            lib.hideTextUI()
            interactText = nil
            interactTick = 0
        end
    end)
end