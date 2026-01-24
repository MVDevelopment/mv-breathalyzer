RegisterServerEvent('breathalyzer.server:doBacTest')
AddEventHandler('breathalyzer.server:doBacTest', function(target)
    TriggerClientEvent('breathalyzer.client:requestBac', target, source, target)
end)

RegisterServerEvent('breathalyzer.server:returnBac')
AddEventHandler('breathalyzer.server:returnBac', function(bac, leo)
    local color = 'black'
    if bac > 0.08 then
        color = '--color-red'
    end
    TriggerClientEvent('breathalyzer.client:displayBac', leo, bac, color)
end)

RegisterServerEvent('breathalyzer.server:refusedBac')
AddEventHandler('breathalyzer.server:refusedBac', function(leo, target)
    TriggerClientEvent('breathalyzer.client:bacRefused', leo, target)
end)

RegisterServerEvent('breathalyzer.server:acceptedBac')
AddEventHandler('breathalyzer.server:acceptedBac', function(leo, target)
    TriggerClientEvent('breathalyzer.client:acceptedBac', leo, target)
end)