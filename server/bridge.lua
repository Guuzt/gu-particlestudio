Bridge = {}

local _framework
local _rsgCore

local function DetectFramework()
    if GetResourceState('rsg-core')  ~= 'missing' then return 'rsg'  end
    if GetResourceState('vorp_core') ~= 'missing' then return 'vorp' end
    return 'standalone'
end

function Bridge.GetFramework()
    if not _framework then
        _framework = DetectFramework()
        if Config.Debug then
            print('[DEBUG][ParticleStudio] Framework detected: ' .. _framework)
        end
    end
    return _framework
end

function Bridge.HasPermission(source, group)
    local fw = Bridge.GetFramework()

    if fw == 'rsg' then
        _rsgCore = _rsgCore or exports['rsg-core']:GetCoreObject()
        return _rsgCore.Functions.HasPermission(source, group)
    elseif fw == 'vorp' then
        local user = exports.vorp_core:GetCore().getUser(source)
        if not user then return false end
        local char = user.getUsedCharacter
        return char ~= nil and char.group == group
    end

    return IsPlayerAceAllowed(tostring(source), group)
end
