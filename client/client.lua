CreateThread(function()
    while not DoesEntityExist(PlayerPedId()) do Wait(500) end
    TriggerServerEvent('gu-particlestudio:server:sync:request')
end)

RegisterNetEvent('gu-particlestudio:client:sync:receive')
AddEventHandler('gu-particlestudio:client:sync:receive', function(effects)
    if not effects then return end
    for _, fx in ipairs(effects) do
        SetServerEffect(fx.id, fx)
        SpawnEffect(fx)
    end
    if Config.Debug then
        print('[DEBUG][ParticleStudio] Sync: ' .. #effects .. ' effect(s) loaded.')
    end
end)

RegisterCommand(Config.Command, function()
    TriggerServerEvent('gu-particlestudio:server:openStudio')
end, false)

RegisterNetEvent('gu-particlestudio:client:spawnEffect')
AddEventHandler('gu-particlestudio:client:spawnEffect', function(fxData)
    SetServerEffect(fxData.id, fxData)
    SpawnEffect(fxData)
    if Config.Debug then print('[DEBUG][ParticleStudio] spawnEffect id=' .. tostring(fxData.id)) end
end)

RegisterNetEvent('gu-particlestudio:client:updateEffect')
AddEventHandler('gu-particlestudio:client:updateEffect', function(fxData)
    SetServerEffect(fxData.id, fxData)
    StopLocalEffect(fxData.id)
    SpawnEffect(fxData)
    if Config.Debug then print('[DEBUG][ParticleStudio] updateEffect id=' .. tostring(fxData.id)) end
end)

RegisterNetEvent('gu-particlestudio:client:removeEffect')
AddEventHandler('gu-particlestudio:client:removeEffect', function(effectId)
    RemoveServerEffect(effectId)
    StopLocalEffect(effectId)
    if Config.Debug then print('[DEBUG][ParticleStudio] removeEffect id=' .. tostring(effectId)) end
end)

RegisterNetEvent('gu-particlestudio:client:clearAll')
AddEventHandler('gu-particlestudio:client:clearAll', function()
    ClearServerEffects()
    StopAllLocalEffects()
end)

RegisterNetEvent('gu-particlestudio:client:openMenu')
AddEventHandler('gu-particlestudio:client:openMenu', function()
    OpenMainMenu()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    StopAllLocalEffects()
    ClearServerEffects()
end)
