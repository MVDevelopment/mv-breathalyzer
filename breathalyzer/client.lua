local bac = nil
local display = false
local breathalyzerProp = nil

function SetDisplay(bool)
    display = bool
    SetNuiFocus(bool, bool)
    SendNUIMessage({
        type = "ui",
        status = bool,
    })
    -- Ако затваряме дисплея, премахваме пропа БЕЗ да спираме анимацията
    if not bool then
        RemoveBreathalyzerProp(false)
    end
end

function CreateBreathalyzerProp()
    -- Премахване на съществуващ проп ако има такъв БЕЗ да спираме анимацията
    RemoveBreathalyzerProp(false)
    
    local playerPed = GetPlayerPed(PlayerId())
    local coords = GetEntityCoords(playerPed)
    
    -- Заявка за модела
    local propModel = GetHashKey("prop_cs_breathalyzer")
    RequestModel(propModel)
    while not HasModelLoaded(propModel) do
        Citizen.Wait(100)
    end
    
    -- Създаване на проп
    breathalyzerProp = CreateObject(propModel, coords.x, coords.y, coords.z, true, true, true)
    
    -- Изчакване пропът да се зареди
    while not DoesEntityExist(breathalyzerProp) do
        Citizen.Wait(1)
    end
    
    -- Задаване като mission entity
    SetEntityAsMissionEntity(breathalyzerProp, true, true)
    
    -- Прикачване на пропа към дясната ръка
    local boneIndex = GetPedBoneIndex(playerPed, 28422) -- RH_Hand
    AttachEntityToEntity(breathalyzerProp, playerPed, boneIndex, 0.08, 0.03, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    print("Дрегерът е създаден и прикачен към кост: " .. boneIndex)
end

function RemoveBreathalyzerProp(clearTasks)
    -- Премахване на пропа с по-агресивен подход
    if breathalyzerProp then
        if DoesEntityExist(breathalyzerProp) then
            DetachEntity(breathalyzerProp, true, true)
            SetEntityAsMissionEntity(breathalyzerProp, true, true)
            DeleteObject(breathalyzerProp)
            DeleteEntity(breathalyzerProp)
        end
        breathalyzerProp = nil
        print("Дрегерът е премахнат")
    end
    
    -- Допълнително почистване - премахване на всички обекти от този тип около играча
    local playerPed = GetPlayerPed(PlayerId())
    local playerCoords = GetEntityCoords(playerPed)
    local objects = GetGamePool('CObject')
    for i = 1, #objects do
        local obj = objects[i]
        if DoesEntityExist(obj) then
            local objModel = GetEntityModel(obj)
            if objModel == GetHashKey("prop_cs_breathalyzer") then
                local objCoords = GetEntityCoords(obj)
                local distance = #(playerCoords - objCoords)
                if distance < 2.0 then
                    DetachEntity(obj, true, true)
                    SetEntityAsMissionEntity(obj, true, true)
                    DeleteObject(obj)
                    DeleteEntity(obj)
                    print("Намерен и премахнат дрегер близо до играча")
                end
            end
        end
    end
    -- Спиране на анимацията само ако е зададено
    if clearTasks then
        ClearPedTasks(PlayerPedId())
        ClearPedSecondaryTask(PlayerPedId())
        ClearPedTasksImmediately(PlayerPedId())
        print("Анимацията е спряна и всички задачи са изчистени")
        -- Още един опит за премахване на пропа след малко закъснение
        Citizen.SetTimeout(500, function()
            if breathalyzerProp and DoesEntityExist(breathalyzerProp) then
                DetachEntity(breathalyzerProp, true, true)
                SetEntityAsMissionEntity(breathalyzerProp, true, true)
                DeleteObject(breathalyzerProp)
                DeleteEntity(breathalyzerProp)
                breathalyzerProp = nil
                print("Дрегерът е форсирано премахнат след закъснение")
            end
        end)
    end
end

RegisterNUICallback("exit", function(data)
    SetDisplay(false)
    SendNUIMessage({
        type = "data",
        bac = '0.00',
        textColor = '--color-black'
    })
    RemoveBreathalyzerProp(true) -- Спираме и анимацията при затваряне
end)

RegisterNUICallback("startBac", function(data)
    local target = GetClosestPlayerRadius(2.0)
	if target == nil then Notify("~r~Няма човек наблизо!") return; end
	-- if target == nil then target = 1 end -- debugging
    TriggerServerEvent('breathalyzer.server:doBacTest', GetPlayerServerId(target))
    Notify('Заявка за проба за алкохол бе изпратена до ~y~' .. GetPlayerName(target))
end)

Citizen.CreateThread(function()
    while display do
        Citizen.Wait(0)
        -- https://runtime.fivem.net/doc/natives/#_0xFE99B66D079CF6BC
        --[[ 
            inputGroup -- integer , 
	        control --integer , 
            disable -- boolean 
        ]]
        DisableControlAction(0, 1, display) -- LookLeftRight
        DisableControlAction(0, 2, display) -- LookUpDown
        DisableControlAction(0, 142, display) -- MeleeAttackAlternate
        DisableControlAction(0, 18, display) -- Enter
        DisableControlAction(0, 322, display) -- ESC
        DisableControlAction(0, 106, display) -- VehicleMouseControlOverride
    end
end)

RegisterCommand("dreger", function(source, args)
    SetDisplay(true)
end)

-- Команда за ръчно премахване на пропа (за тестване)
RegisterCommand("cleardeger", function(source, args)
    RemoveBreathalyzerProp(true)
    print("Ръчно премахване на дрегера")
end)

RegisterNetEvent('breathalyzer.client:requestBac')
AddEventHandler('breathalyzer.client:requestBac', function(leo,target)
    local accepted = nil
    Notify("~y~" .. GetPlayerName(GetPlayerFromServerId(leo)) .. "~w~ желае да извърши проба за алкохол.")
    Notify("Приеми [~g~Y~w~] Откажи [~r~N~w~]")

    Citizen.CreateThread(function()
        while accepted == nil do
            Citizen.Wait(0)
            if IsControlJustReleased(1, 246) then
                accepted = true
                TriggerServerEvent('breathalyzer.server:acceptedBac', leo, target)
                local result = KeyboardInput('Лимит за алкохол в кръвта (0.05):', 4)
                if result then
                    bac = tonumber(result)
                    TriggerServerEvent('breathalyzer.server:returnBac', bac, leo)
                end
            end
            if IsControlJustReleased(1, 249) then
                accepted = false
                TriggerServerEvent('breathalyzer.server:refusedBac', leo, target)
            end
        end
    end)
end)

RegisterNetEvent('breathalyzer.client:displayBac')
AddEventHandler('breathalyzer.client:displayBac', function(bac, color)
    SendNUIMessage({
        type = "data",
        bac = bac,
        textColor = color
    })
    -- Премахване на пропа след показване на резултата СЪС спиране на анимацията
    Citizen.SetTimeout(3000, function()
        RemoveBreathalyzerProp(true)
    end)
end)

RegisterNetEvent('breathalyzer.client:bacRefused')
AddEventHandler('breathalyzer.client:bacRefused', function(target)
    SetDisplay(false)
    SendNUIMessage({
        type = "data",
        bac = '0.00',
        textColor = '--color-black'
    })
    Notify("~y~" .. GetPlayerName(GetPlayerFromServerId(target)) .. " ~w~Бе ~r~Отказана~w~ Проба за алкохол!")
    RemoveBreathalyzerProp(true) -- Спираме и анимацията при отказ
end)

RegisterNetEvent('breathalyzer.client:acceptedBac')
AddEventHandler('breathalyzer.client:acceptedBac', function(target)
    Notify("Тестване ~y~" .. GetPlayerName(GetPlayerFromServerId(target)) .. "'s ~w~промили за алкохол в кръвта...")
    Wait(100)
    CreateBreathalyzerProp()
    TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 5.5, 'dreger', 0.7)
    TaskPlayAnim(GetPlayerPed(PlayerId()), "weapons@first_person@aim_rng@generic@projectile@shared@core", "idlerng_med", 1.0, -1, 9000, 50, 0, false, false, false);
    
    -- Резервен таймер за премахване на пропа (в случай че нещо не се изпълни правилно)
    Citizen.SetTimeout(15000, function()
        RemoveBreathalyzerProp(true)
        print("Резервен таймер - дрегерът е премахнат")
    end)
end)

-- Премахване на дрегера при смяна на скин (ESX, QBCore и др.)
AddEventHandler('skinchanger:modelLoaded', function()
    RemoveBreathalyzerProp(true)
end)
AddEventHandler('qb-clothing:client:loadPlayerClothing', function()
    RemoveBreathalyzerProp(true)
end)
AddEventHandler('qb-clothing:client:loadOutfit', function()
    RemoveBreathalyzerProp(true)
end)
AddEventHandler('esx_skin:resetFirstSpawn', function()
    RemoveBreathalyzerProp(true)
end)

-- Cleanup при напускане на ресурса
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    RemoveBreathalyzerProp(true) -- Спираме и анимацията при затваряне на ресурса
end)