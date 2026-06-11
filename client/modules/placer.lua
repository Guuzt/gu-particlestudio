local isPlacing      = false
local movingId       = nil
local pendingFx      = {}
local previewHandle  = nil
local lastNLFire     = 0
local lastScrollTime = 0
local lastRotTime    = 0

local placingRx = 0.0
local placingRy = 0.0
local placingRz = 0.0

local placerPhase  = 1
local lockedCoords = nil
local heightOffset = 0.0

local freeCamActive = false
local freeCamHandle = nil
local freeCamPos    = vector3(0, 0, 0)
local freeCamRot    = vector3(0, 0, 0)

local _promptGroup   = nil
local _promptPrimary = nil
local _promptSecond  = nil

local _hudStatus = ''
local _hudHint   = ''

function IsInPlacementMode()
    return isPlacing
end

local function StartFreeCam()
    if freeCamActive then return end
    freeCamPos    = GetFinalRenderedCamCoord()
    freeCamRot    = GetFinalRenderedCamRot(2)
    freeCamHandle = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(freeCamHandle, freeCamPos.x, freeCamPos.y, freeCamPos.z)
    SetCamRot(freeCamHandle,   freeCamRot.x, freeCamRot.y, freeCamRot.z, 2)
    SetCamFov(freeCamHandle,   GetFinalRenderedCamFov())
    RenderScriptCams(true, false, 0, true, false, 0)
    freeCamActive = true
end

local function StopFreeCam()
    if not freeCamActive then return end
    RenderScriptCams(false, false, 0, true, false, 0)
    if freeCamHandle then
        DestroyCam(freeCamHandle, false)
        freeCamHandle = nil
    end
    freeCamActive = false
end

local function UpdateFreeCam()
    if not freeCamActive or not freeCamHandle then return end

    DisableControlAction(0, joaat('INPUT_MOVE_LR'), true)
    DisableControlAction(0, joaat('INPUT_MOVE_UD'), true)
    DisableControlAction(0, joaat('INPUT_LOOK_LR'), true)
    DisableControlAction(0, joaat('INPUT_LOOK_UD'), true)
    DisableControlAction(0, joaat('INPUT_SPRINT'),  true)
    DisableControlAction(0, joaat('INPUT_JUMP'),    true)

    local lookH = GetDisabledControlNormal(0, joaat('INPUT_LOOK_LR'))
    local lookV = GetDisabledControlNormal(0, joaat('INPUT_LOOK_UD'))
    freeCamRot = vector3(
        math.max(-89.0, math.min(89.0, freeCamRot.x - lookV * 5.0)),
        0.0,
        (freeCamRot.z - lookH * 5.0) % 360.0
    )

    local rx  = math.rad(freeCamRot.x)
    local rz  = math.rad(freeCamRot.z)
    local fwd = vector3(
        -math.sin(rz) * math.abs(math.cos(rx)),
         math.cos(rz) * math.abs(math.cos(rx)),
         math.sin(rx)
    )
    local rgt = vector3(math.cos(rz), math.sin(rz), 0.0)

    local mX  = GetDisabledControlNormal(0, joaat('INPUT_MOVE_LR'))
    local mY  = GetDisabledControlNormal(0, joaat('INPUT_MOVE_UD'))
    local spd = Config.FreeCamSpeed or 0.3
    freeCamPos = freeCamPos + fwd * (-mY * spd) + rgt * (mX * spd)

    if IsDisabledControlPressed(0, joaat(Config.Keys.MoveUp)) then
        freeCamPos = vector3(freeCamPos.x, freeCamPos.y, freeCamPos.z + spd)
    elseif IsDisabledControlPressed(0, joaat(Config.Keys.MoveDown)) then
        freeCamPos = vector3(freeCamPos.x, freeCamPos.y, freeCamPos.z - spd)
    end

    if placerPhase == 1 then
        local step = (Config.HeightStep or 0.1) * 2
        if IsDisabledControlPressed(0, joaat(Config.Keys.ScrollUp)) then
            freeCamPos = vector3(freeCamPos.x, freeCamPos.y, freeCamPos.z + step)
        elseif IsDisabledControlPressed(0, joaat(Config.Keys.ScrollDown)) then
            freeCamPos = vector3(freeCamPos.x, freeCamPos.y, freeCamPos.z - step)
        end
    end

    SetCamCoord(freeCamHandle, freeCamPos.x, freeCamPos.y, freeCamPos.z)
    SetCamRot(freeCamHandle,   freeCamRot.x, freeCamRot.y, freeCamRot.z, 2)
end

local function DeletePlacementPrompts()
    if _promptPrimary then PromptDelete(_promptPrimary); _promptPrimary = nil end
    if _promptSecond  then PromptDelete(_promptSecond);  _promptSecond  = nil end
    _promptGroup = nil
end

local function CreatePlacementPrompts(phase)
    DeletePlacementPrompts()
    _promptGroup = GetRandomIntInRange(0, 0xFFFFFF)

    local function makePrompt(control, label)
        local p = PromptRegisterBegin()
        PromptSetControlAction(p, joaat(control))
        PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', label))
        PromptSetEnabled(p, true)
        PromptSetVisible(p, true)
        PromptSetGroup(p, _promptGroup, 0)
        PromptRegisterEnd(p)
        return p
    end

    if phase == 1 then
        _promptPrimary = makePrompt(Config.Keys.Enter,  L('studio.prompt.lock'))
        _promptSecond  = makePrompt(Config.Keys.Cancel, L('studio.prompt.cancel'))
    else
        _promptPrimary = makePrompt(Config.Keys.Enter,  L('studio.prompt.confirm'))
        _promptSecond  = makePrompt(Config.Keys.Cancel, L('studio.prompt.back'))
    end
end

local function DrawPlacementHUD()
    local statusText, hintText, promptTitle

    if placerPhase == 1 then
        if freeCamActive then
            statusText  = string.format(L('studio.hud.cam'), placingRz, placingRx)
            hintText    = L('studio.hud.cam_hint')
            promptTitle = 'Particle Studio'
        else
            statusText  = string.format(L('studio.hud.phase1'), placingRz, placingRx)
            hintText    = L('studio.hud.phase1_hint')
            promptTitle = 'Particle Studio'
        end
    else
        statusText  = string.format(L('studio.hud.phase2'), heightOffset, placingRz, placingRx)
        hintText    = L('studio.hud.phase2_hint')
        promptTitle = string.format('Particle Studio  %+.2fm', heightOffset)
    end

    if statusText ~= _hudStatus or hintText ~= _hudHint then
        _hudStatus = statusText
        _hudHint   = hintText
        SendNUIMessage({ action = 'placerHud', status = statusText, hint = hintText })
    end

    if _promptGroup then
        PromptSetActiveGroupThisFrame(
            _promptGroup,
            CreateVarString(10, 'LITERAL_STRING', promptTitle)
        )
    end
end

function EnterPlacementMode(effectData, moveId)
    if isPlacing then return end

    pendingFx      = effectData
    movingId       = moveId
    heightOffset   = 0.0
    lastNLFire     = 0
    lastScrollTime = 0
    lastRotTime    = 0
    placerPhase    = 1
    lockedCoords   = nil
    _hudStatus     = ''
    _hudHint       = ''

    placingRx = effectData.rx or 0.0
    placingRy = effectData.ry or 0.0
    placingRz = effectData.rz or 0.0

    isPlacing = true
    CloseMenu()
    CreatePlacementPrompts(1)
    Notify(L('studio.placement.start'), 3000, 'info')

    CreateThread(function()
        while isPlacing do
            Wait(0)

            UpdateFreeCam()

            DisableControlAction(0, joaat(Config.Keys.ScrollUp),    true)
            DisableControlAction(0, joaat(Config.Keys.ScrollDown),  true)
            DisableControlAction(0, joaat(Config.Keys.RotateLeft),  true)
            DisableControlAction(0, joaat(Config.Keys.RotateRight), true)
            DisableControlAction(0, joaat(Config.Keys.RotateUp),    true)
            DisableControlAction(0, joaat(Config.Keys.RotateDown),  true)

            if placerPhase == 2 then
                DisableControlAction(0, joaat(Config.Keys.MoveUp),   true)
                DisableControlAction(0, joaat(Config.Keys.MoveDown), true)
            end

            DrawPlacementHUD()

            if IsControlJustReleased(0, joaat(Config.Keys.FreeCam)) then
                if freeCamActive then StopFreeCam() else StartFreeCam() end
            end

            local previewPos
            if placerPhase == 1 then
                local _, hitCoords = RayCastCamera(Config.PlacementDistance)
                if hitCoords then
                    previewPos = vector3(hitCoords.x, hitCoords.y, hitCoords.z)
                end
            else
                if lockedCoords then
                    previewPos = vector3(
                        lockedCoords.x,
                        lockedCoords.y,
                        lockedCoords.z + heightOffset
                    )
                end
            end

            if previewPos then
                if pendingFx.type == 'Looped' then
                    if previewHandle and DoesParticleFxLoopedExist(previewHandle) then
                        SetParticleFxLoopedOffsets(
                            previewHandle,
                            previewPos.x, previewPos.y, previewPos.z,
                            placingRx, placingRy, placingRz
                        )
                    else
                        previewHandle = LoadAndCreateFx(
                            'Looped',
                            pendingFx.dict, pendingFx.effect,
                            previewPos, pendingFx.scale,
                            placingRx, placingRy, placingRz
                        )
                    end
                else
                    local now = GetGameTimer()
                    if now - lastNLFire >= Config.PreviewNonLoopedInterval then
                        LoadAndCreateFx(
                            'NonLooped',
                            pendingFx.dict, pendingFx.effect,
                            previewPos, pendingFx.scale,
                            placingRx, placingRy, placingRz
                        )
                        lastNLFire = now
                    end
                end
            end

            local t = GetGameTimer()
            if t - lastRotTime >= 80 then
                if IsDisabledControlPressed(0, joaat(Config.Keys.RotateLeft)) then
                    placingRz   = (placingRz - Config.RotationStep) % 360
                    lastRotTime = t
                elseif IsDisabledControlPressed(0, joaat(Config.Keys.RotateRight)) then
                    placingRz   = (placingRz + Config.RotationStep) % 360
                    lastRotTime = t
                elseif IsDisabledControlPressed(0, joaat(Config.Keys.RotateUp)) then
                    placingRx   = math.max(-180.0, placingRx - Config.RotationStep)
                    lastRotTime = t
                elseif IsDisabledControlPressed(0, joaat(Config.Keys.RotateDown)) then
                    placingRx   = math.min( 180.0, placingRx + Config.RotationStep)
                    lastRotTime = t
                end
            end

            if placerPhase == 2 and t - lastScrollTime >= 50 then
                local heightUp = IsDisabledControlPressed(0, joaat(Config.Keys.ScrollUp))
                    or (not freeCamActive and IsDisabledControlPressed(0, joaat(Config.Keys.MoveUp)))
                local heightDown = IsDisabledControlPressed(0, joaat(Config.Keys.ScrollDown))
                    or (not freeCamActive and IsDisabledControlPressed(0, joaat(Config.Keys.MoveDown)))

                if heightUp then
                    heightOffset   = heightOffset + Config.HeightStep
                    lastScrollTime = t
                elseif heightDown then
                    heightOffset   = heightOffset - Config.HeightStep
                    lastScrollTime = t
                end
            end

            if IsControlJustReleased(0, joaat(Config.Keys.Enter)) then
                if placerPhase == 1 then
                    local _, hitCoords = RayCastCamera(Config.PlacementDistance)
                    if hitCoords then
                        lockedCoords = vector3(hitCoords.x, hitCoords.y, hitCoords.z)
                        heightOffset = 0.0
                        placerPhase  = 2
                        CreatePlacementPrompts(2)
                        Notify(L('studio.placement.locked'), 2000, 'info')
                    end
                else
                    if lockedCoords then
                        local finalPos = vector3(
                            lockedCoords.x,
                            lockedCoords.y,
                            lockedCoords.z + heightOffset
                        )
                        StopFreeCam()
                        ConfirmPlacement(finalPos)
                    end
                end
            end

            if IsControlJustReleased(0, joaat(Config.Keys.Cancel)) then
                if placerPhase == 2 then
                    placerPhase  = 1
                    lockedCoords = nil
                    heightOffset = 0.0
                    CreatePlacementPrompts(1)
                else
                    StopFreeCam()
                    CancelPlacement()
                end
            end
        end
    end)
end

function ConfirmPlacement(coords)
    CleanupPreview()
    DeletePlacementPrompts()
    SendNUIMessage({ action = 'hideHud' })
    isPlacing = false

    local data = {
        dict     = pendingFx.dict,
        effect   = pendingFx.effect,
        type     = pendingFx.type,
        coords   = { x = coords.x, y = coords.y, z = coords.z },
        scale    = pendingFx.scale,
        rx       = placingRx,
        ry       = placingRy,
        rz       = placingRz,
        duration = pendingFx.duration or 0,
    }

    if movingId then
        TriggerServerEvent('gu-particlestudio:server:effects:move', movingId, data)
        movingId = nil
    else
        TriggerServerEvent('gu-particlestudio:server:effects:place', data)
    end
end

function CancelPlacement()
    CleanupPreview()
    DeletePlacementPrompts()
    SendNUIMessage({ action = 'hideHud' })
    isPlacing = false
    movingId  = nil
    Notify(L('studio.placement.cancelled'), 3000, 'error')
end

function CleanupPreview()
    if previewHandle then
        if DoesParticleFxLoopedExist(previewHandle) then
            StopParticleFxLooped(previewHandle, true)
        end
        previewHandle = nil
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    StopFreeCam()
    if isPlacing then CancelPlacement() end
end)
