local activeEffects = {}
local nextEffectId  = 1

local function HasPermission(src)
    return Bridge.HasPermission(src, Config.Permission)
end

local function GetAllEffects()
    local list = {}
    for _, fx in pairs(activeEffects) do list[#list+1] = fx end
    return list
end

local function RemoveEffect(effectId)
    if not activeEffects[effectId] then return end
    activeEffects[effectId] = nil
    TriggerClientEvent('gu-particlestudio:client:removeEffect', -1, effectId)
    if Config.Debug then print('[DEBUG][ParticleStudio] RemoveEffect id=' .. effectId) end
end

local function StartDurationTimer(effectId, durationSeconds)
    if not durationSeconds or durationSeconds <= 0 then return end
    local expiry = os.time() + math.floor(durationSeconds)
    activeEffects[effectId].durationExpiry = expiry
    CreateThread(function()
        Wait(math.floor(durationSeconds * 1000))
        if activeEffects[effectId] and activeEffects[effectId].durationExpiry == expiry then
            RemoveEffect(effectId)
        end
    end)
end

local function ValidateFxData(data)
    if type(data) ~= 'table'           then return false end
    if type(data.dict) ~= 'string'     then return false end
    if type(data.effect) ~= 'string'   then return false end
    if data.type ~= 'Looped' and data.type ~= 'NonLooped' then return false end
    if type(data.coords) ~= 'table'    then return false end
    if type(data.coords.x) ~= 'number' then return false end
    return true
end

local function SanitizeFxData(data, base)
    base = base or {}
    return {
        dict     = tostring(data.dict   or base.dict   or ''),
        effect   = tostring(data.effect or base.effect or ''),
        type     = (data.type == 'Looped' or data.type == 'NonLooped') and data.type or (base.type or 'Looped'),
        coords   = {
            x = tonumber(data.coords and data.coords.x) or (base.coords and base.coords.x) or 0.0,
            y = tonumber(data.coords and data.coords.y) or (base.coords and base.coords.y) or 0.0,
            z = tonumber(data.coords and data.coords.z) or (base.coords and base.coords.z) or 0.0,
        },
        scale    = math.max(0.1, math.min(10.0, tonumber(data.scale)    or base.scale    or 1.0)),
        rx       = math.max(-360, math.min(360, tonumber(data.rx)       or base.rx       or 0.0)),
        ry       = math.max(-360, math.min(360, tonumber(data.ry)       or base.ry       or 0.0)),
        rz       = math.max(-360, math.min(360, tonumber(data.rz)       or base.rz       or 0.0)),
        duration = math.max(0, math.min(3600, math.floor(tonumber(data.duration) or base.duration or 0))),
    }
end

RegisterNetEvent('gu-particlestudio:server:sync:request')
AddEventHandler('gu-particlestudio:server:sync:request', function()
    TriggerClientEvent('gu-particlestudio:client:sync:receive', source, GetAllEffects())
end)

RegisterNetEvent('gu-particlestudio:server:openStudio')
AddEventHandler('gu-particlestudio:server:openStudio', function()
    local src = source
    if not HasPermission(src) then
        Notify(L('studio.no_permission'), 4000, 'error', src)
        return
    end
    TriggerClientEvent('gu-particlestudio:client:openMenu', src)
end)

RegisterNetEvent('gu-particlestudio:server:effects:place')
AddEventHandler('gu-particlestudio:server:effects:place', function(data)
    local src = source
    if not HasPermission(src) then return end
    if not ValidateFxData(data) then return end

    local id       = nextEffectId
    nextEffectId   = nextEffectId + 1
    local fx       = SanitizeFxData(data)
    fx.id          = id
    fx.durationExpiry = nil

    activeEffects[id] = fx
    TriggerClientEvent('gu-particlestudio:client:spawnEffect', -1, fx)
    StartDurationTimer(id, fx.duration)

    if Config.Debug then print('[DEBUG][ParticleStudio] Place id=' .. id .. ' dict=' .. fx.dict) end
end)

RegisterNetEvent('gu-particlestudio:server:effects:move')
AddEventHandler('gu-particlestudio:server:effects:move', function(effectId, newData)
    local src = source
    if not HasPermission(src) then return end

    effectId = tonumber(effectId)
    if not effectId or not activeEffects[effectId] then return end
    if not ValidateFxData(newData) then return end

    local fx = SanitizeFxData(newData, activeEffects[effectId])
    fx.id    = effectId
    fx.durationExpiry = nil

    activeEffects[effectId] = fx
    TriggerClientEvent('gu-particlestudio:client:updateEffect', -1, fx)
    StartDurationTimer(effectId, fx.duration)
end)

RegisterNetEvent('gu-particlestudio:server:effects:edit')
AddEventHandler('gu-particlestudio:server:effects:edit', function(effectId, newData)
    local src = source
    if not HasPermission(src) then return end

    effectId = tonumber(effectId)
    if not effectId or not activeEffects[effectId] then return end

    local base = activeEffects[effectId]
    local fx = {
        id       = effectId,
        dict     = base.dict,
        effect   = base.effect,
        type     = base.type,
        coords   = base.coords,
        scale    = math.max(0.1, math.min(10.0, tonumber(newData.scale)    or base.scale)),
        rx       = math.max(-360, math.min(360, tonumber(newData.rx)       or base.rx)),
        ry       = math.max(-360, math.min(360, tonumber(newData.ry)       or base.ry)),
        rz       = math.max(-360, math.min(360, tonumber(newData.rz)       or base.rz)),
        duration = math.max(0, math.min(3600, math.floor(tonumber(newData.duration) or base.duration))),
        durationExpiry = nil,
    }

    activeEffects[effectId] = fx
    TriggerClientEvent('gu-particlestudio:client:updateEffect', -1, fx)
    StartDurationTimer(effectId, fx.duration)
end)

RegisterNetEvent('gu-particlestudio:server:effects:remove')
AddEventHandler('gu-particlestudio:server:effects:remove', function(effectId)
    local src = source
    if not HasPermission(src) then return end
    effectId = tonumber(effectId)
    if not effectId then return end
    RemoveEffect(effectId)
end)

RegisterNetEvent('gu-particlestudio:server:effects:clearAll')
AddEventHandler('gu-particlestudio:server:effects:clearAll', function()
    local src = source
    if not HasPermission(src) then return end
    activeEffects = {}
    nextEffectId  = 1
    TriggerClientEvent('gu-particlestudio:client:clearAll', -1)
    if Config.Debug then print('[DEBUG][ParticleStudio] ClearAll by src=' .. tostring(src)) end
end)
