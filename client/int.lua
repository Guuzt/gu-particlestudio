local _activeHandles = {}
local _serverEffects = {}

function SetServerEffect(id, data)   _serverEffects[id] = data   end
function RemoveServerEffect(id)      _serverEffects[id] = nil    end
function ClearServerEffects()        _serverEffects     = {}     end
function GetServerEffects()          return _serverEffects       end

function RayCastCamera(distance)
    local camCoord = GetFinalRenderedCamCoord()
    local camRot   = GetFinalRenderedCamRot(2)

    local radX = math.rad(camRot.x)
    local radZ = math.rad(camRot.z)

    local dir = {
        x = -math.sin(radZ) * math.abs(math.cos(radX)),
        y =  math.cos(radZ) * math.abs(math.cos(radX)),
        z =  math.sin(radX),
    }

    local dest = vector3(
        camCoord.x + dir.x * distance,
        camCoord.y + dir.y * distance,
        camCoord.z + dir.z * distance
    )

    local _, hit, hitCoords, _, entity = GetShapeTestResult(
        StartShapeTestRay(
            camCoord.x, camCoord.y, camCoord.z,
            dest.x, dest.y, dest.z,
            -1, PlayerPedId(), 0
        )
    )

    local finalCoords = (hit == 1) and hitCoords or dest
    return hit == 1, finalCoords, entity
end

function LoadAndCreateFx(fxType, dict, effect, coords, scale, rx, ry, rz)
    local hashKey = GetHashKey(dict)
    RequestNamedPtfxAsset(hashKey)
    while not HasNamedPtfxAssetLoaded(hashKey) do Wait(5) end
    UseParticleFxAsset(dict)

    local handle
    if fxType == 'Looped' then
        handle = StartParticleFxLoopedAtCoord(
            effect,
            coords.x, coords.y, coords.z,
            rx or 0.0, ry or 0.0, rz or 0.0,
            scale or 1.0,
            false, false, false, true
        )
    else
        handle = StartParticleFxNonLoopedAtCoord(
            effect,
            coords.x, coords.y, coords.z,
            rx or 0.0, ry or 0.0, rz or 0.0,
            scale or 1.0,
            false, false, false, true
        )
    end
    return handle
end

function SpawnEffect(fxData)
    if _activeHandles[fxData.id] then
        StopLocalEffect(fxData.id)
    end

    local coords = vector3(fxData.coords.x, fxData.coords.y, fxData.coords.z)

    if fxData.type == 'Looped' then
        local handle = LoadAndCreateFx(
            'Looped', fxData.dict, fxData.effect,
            coords, fxData.scale,
            fxData.rx, fxData.ry, fxData.rz
        )
        if handle then
            SetParticleFxLoopedOffsets(
                handle,
                coords.x, coords.y, coords.z,
                fxData.rx or 0.0, fxData.ry or 0.0, fxData.rz or 0.0
            )
            _activeHandles[fxData.id] = { handle = handle, fxType = 'Looped' }
        end
    else
        local entry = { handle = nil, fxType = 'NonLooped', stop = false }
        _activeHandles[fxData.id] = entry

        local dict       = fxData.dict
        local effect     = fxData.effect
        local scale      = fxData.scale
        local rx, ry, rz = fxData.rx or 0.0, fxData.ry or 0.0, fxData.rz or 0.0

        CreateThread(function()
            local hashKey = GetHashKey(dict)
            RequestNamedPtfxAsset(hashKey)
            while not HasNamedPtfxAssetLoaded(hashKey) do Wait(5) end
            UseParticleFxAsset(dict)

            while not entry.stop do
                entry.handle = StartParticleFxNonLoopedAtCoord(
                    effect,
                    coords.x, coords.y, coords.z,
                    rx, ry, rz,
                    scale or 1.0,
                    false, false, false, true
                )
                Wait(Config.NonLoopedInterval)
            end
        end)
    end

    if Config.Debug then
        print('[DEBUG][ParticleStudio] SpawnEffect id=' .. tostring(fxData.id) .. ' type=' .. tostring(fxData.type))
    end
end

function StopLocalEffect(effectId)
    local entry = _activeHandles[effectId]
    if not entry then return end

    if entry.fxType == 'Looped' then
        if entry.handle and DoesParticleFxLoopedExist(entry.handle) then
            StopParticleFxLooped(entry.handle, true)
        end
    else
        entry.stop = true
    end

    _activeHandles[effectId] = nil
end

function StopAllLocalEffects()
    for id, entry in pairs(_activeHandles) do
        if entry.fxType == 'Looped' then
            if entry.handle and DoesParticleFxLoopedExist(entry.handle) then
                StopParticleFxLooped(entry.handle, true)
            end
        else
            entry.stop = true
        end
    end
    _activeHandles = {}
end
