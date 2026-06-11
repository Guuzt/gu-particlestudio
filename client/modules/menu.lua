local _effectSettings    = {}
local _cachedConfigMenus = {}
local _cachedTypeMenus   = {}
local _cachedSearchMenu  = nil
local _recentEffects     = {}
local _dictMenuRefs      = {}
local _lastBrowsed       = nil
local MAX_RECENTS        = 8

local function EffectKey(fxType, dict, effectName)
    return fxType .. '::' .. dict .. '::' .. effectName
end

local function GetOrCreateSettings(key)
    if not _effectSettings[key] then
        _effectSettings[key] = {
            scale    = Config.DefaultScale    or 1.0,
            rx       = 0.0,
            ry       = 0.0,
            rz       = 0.0,
            duration = Config.DefaultDuration or 0,
        }
    end
    return _effectSettings[key]
end

local function AddToRecents(key)
    for i = #_recentEffects, 1, -1 do
        if _recentEffects[i] == key then table.remove(_recentEffects, i) end
    end
    table.insert(_recentEffects, 1, key)
    while #_recentEffects > MAX_RECENTS do table.remove(_recentEffects) end

    local parts = {}
    for part in key:gmatch('[^:]+') do parts[#parts+1] = part end
    if #parts == 3 then
        local fxType, dictName = parts[1], parts[2]
        local ref = _dictMenuRefs[fxType .. '::' .. dictName]
        if ref then
            _lastBrowsed = { fxType = fxType, dictName = dictName, menuRef = ref }
        end
    end
end

local function ExportEffects()
    local effects = GetServerEffects()
    if not next(effects) then
        Notify(L('studio.no_effects'), 3000, 'error')
        return
    end
    local lines = { '-- Particle Studio Export' }
    lines[#lines+1] = 'local savedEffects = {'
    for id, fx in pairs(effects) do
        lines[#lines+1] = string.format(
            "    { id=%d, dict='%s', effect='%s', type='%s',"
            .." coords=vector3(%.4f, %.4f, %.4f),"
            .." scale=%.2f, rx=%.1f, ry=%.1f, rz=%.1f, duration=%d },",
            id, fx.dict, fx.effect, fx.type,
            fx.coords.x, fx.coords.y, fx.coords.z,
            fx.scale, fx.rx, fx.ry, fx.rz, fx.duration
        )
    end
    lines[#lines+1] = '}'
    print(table.concat(lines, '\n'))
    Notify(L('studio.exported'), 4000, 'success')
end

local function BuildEffectConfigMenu(dict, effectName, fxType, settings)
    local key = EffectKey(fxType, dict, effectName)

    return {
        title   = effectName,
        subtext = dict .. '  |  ' .. fxType,
        elements = {
            {
                type      = 'slider',
                label     = L('studio.edit.scale'),
                min       = 1, max = 100,
                value     = math.max(1, math.min(100, math.floor(settings.scale * 10))),
                factor    = 0.1,
                onChanged = function(v) settings.scale = v / 10.0 end,
            },
            {
                type      = 'slider',
                label     = L('studio.edit.rot_x'),
                min       = -180, max = 180,
                value     = math.floor(settings.rx),
                onChanged = function(v) settings.rx = v * 1.0 end,
            },
            {
                type      = 'slider',
                label     = L('studio.edit.rot_y'),
                min       = -180, max = 180,
                value     = math.floor(settings.ry),
                onChanged = function(v) settings.ry = v * 1.0 end,
            },
            {
                type      = 'slider',
                label     = L('studio.edit.rot_z'),
                min       = -180, max = 180,
                value     = math.floor(settings.rz),
                onChanged = function(v) settings.rz = v * 1.0 end,
            },
            {
                type      = 'input',
                label     = L('studio.edit.duration'),
                min       = 0, max = 3600,
                value     = settings.duration,
                onChanged = function(v) settings.duration = math.max(0, math.floor(tonumber(v) or 0)) end,
            },
            {
                label  = L('studio.menu.place'),
                action = function()
                    AddToRecents(key)
                    CloseMenu()
                    EnterPlacementMode({
                        dict     = dict,
                        effect   = effectName,
                        type     = fxType,
                        scale    = settings.scale,
                        rx       = settings.rx,
                        ry       = settings.ry,
                        rz       = settings.rz,
                        duration = settings.duration,
                    }, nil)
                end,
            },
        },
    }
end

local function GetOrBuildConfigMenu(fxType, dict, effectName)
    local key = EffectKey(fxType, dict, effectName)
    if not _cachedConfigMenus[key] then
        local settings = GetOrCreateSettings(key)
        _cachedConfigMenus[key] = BuildEffectConfigMenu(dict, effectName, fxType, settings)
    end
    return _cachedConfigMenus[key]
end

local function GetOrBuildTypeMenu(fxType)
    if _cachedTypeMenus[fxType] then return _cachedTypeMenus[fxType] end

    local assetsTable = (fxType == 'Looped') and ptfx_assets_looped or ptfx_assets_non_looped
    if not assetsTable then return nil end

    local sortedDicts = {}
    for dictName in pairs(assetsTable) do sortedDicts[#sortedDicts+1] = dictName end
    table.sort(sortedDicts)

    local dictElements = {}
    for _, dictName in ipairs(sortedDicts) do
        local effects        = assetsTable[dictName]
        local effectElements = {}

        for _, effectName in ipairs(effects) do
            effectElements[#effectElements+1] = {
                label   = effectName,
                submenu = GetOrBuildConfigMenu(fxType, dictName, effectName),
            }
        end

        local dictSubmenu = {
            title      = dictName,
            subtext    = fxType,
            searchable = true,
            elements   = effectElements,
        }

        _dictMenuRefs[fxType .. '::' .. dictName] = dictSubmenu

        dictElements[#dictElements+1] = {
            label   = dictName,
            desc    = #effects .. 'x',
            submenu = dictSubmenu,
        }
    end

    _cachedTypeMenus[fxType] = {
        title      = fxType,
        subtext    = L('studio.menu.type_choose'),
        searchable = true,
        elements   = dictElements,
    }
    return _cachedTypeMenus[fxType]
end

local function GetOrBuildSearchMenu()
    if _cachedSearchMenu then return _cachedSearchMenu end

    local allEffects = {}

    local function addAll(assetsTable, fxType)
        if not assetsTable then return end
        for dictName, effects in pairs(assetsTable) do
            for _, effectName in ipairs(effects) do
                allEffects[#allEffects+1] = {
                    label   = effectName .. '   [' .. dictName .. ']',
                    desc    = fxType,
                    submenu = GetOrBuildConfigMenu(fxType, dictName, effectName),
                }
            end
        end
    end

    addAll(ptfx_assets_looped,     'Looped')
    addAll(ptfx_assets_non_looped, 'NonLooped')
    table.sort(allEffects, function(a, b) return a.label < b.label end)

    _cachedSearchMenu = {
        title      = L('studio.menu.search'),
        subtext    = #allEffects .. ' ' .. L('studio.menu.search_count'),
        searchable = true,
        elements   = allEffects,
    }
    return _cachedSearchMenu
end

local function BuildRecentsMenu()
    local elements = {}
    for _, key in ipairs(_recentEffects) do
        local parts = {}
        for part in key:gmatch('[^:]+') do parts[#parts+1] = part end
        if #parts == 3 then
            local fxType, dictName, effectName = parts[1], parts[2], parts[3]
            elements[#elements+1] = {
                label   = effectName,
                desc    = fxType .. '  |  ' .. dictName,
                submenu = GetOrBuildConfigMenu(fxType, dictName, effectName),
            }
        end
    end
    return {
        title    = L('studio.menu.recents'),
        subtext  = L('studio.menu.recents_desc'),
        elements = elements,
    }
end

local function BuildBrowseMenu()
    local elements = {}

    if _lastBrowsed then
        elements[#elements+1] = {
            label   = string.format(L('studio.menu.continue'), _lastBrowsed.dictName),
            desc    = _lastBrowsed.fxType,
            submenu = _lastBrowsed.menuRef,
        }
    end

    elements[#elements+1] = {
        label   = L('studio.menu.search'),
        desc    = L('studio.menu.search_desc'),
        submenu = GetOrBuildSearchMenu(),
    }

    if #_recentEffects > 0 then
        elements[#elements+1] = {
            label  = L('studio.menu.recents'),
            desc   = L('studio.menu.recents_desc'),
            action = function() OpenSubMenu(BuildRecentsMenu()) end,
        }
    end

    elements[#elements+1] = {
        label   = L('studio.menu.looped'),
        submenu = GetOrBuildTypeMenu('Looped'),
    }
    elements[#elements+1] = {
        label   = L('studio.menu.nonlooped'),
        submenu = GetOrBuildTypeMenu('NonLooped'),
    }

    return {
        title    = L('studio.menu.browse'),
        subtext  = L('studio.menu.browse_desc'),
        elements = elements,
    }
end

local function BuildEffectEditMenu(fx)
    local temp = {
        scale    = fx.scale,
        rx       = fx.rx,
        ry       = fx.ry,
        rz       = fx.rz,
        duration = fx.duration,
    }

    return {
        title   = '#' .. fx.id .. '  ' .. fx.effect,
        subtext = fx.dict .. '  |  ' .. fx.type,
        elements = {
            {
                label  = L('studio.edit.move'),
                desc   = L('studio.edit.move_desc'),
                action = function()
                    CloseMenu()
                    EnterPlacementMode({
                        dict     = fx.dict,
                        effect   = fx.effect,
                        type     = fx.type,
                        scale    = fx.scale,
                        rx       = fx.rx,
                        ry       = fx.ry,
                        rz       = fx.rz,
                        duration = fx.duration,
                    }, fx.id)
                end,
            },
            {
                type      = 'slider',
                label     = L('studio.edit.scale'),
                min       = 1, max = 100,
                value     = math.max(1, math.min(100, math.floor(fx.scale * 10))),
                factor    = 0.1,
                onChanged = function(v) temp.scale = v / 10.0 end,
            },
            {
                type      = 'slider',
                label     = L('studio.edit.rot_x'),
                min       = -180, max = 180,
                value     = math.floor(fx.rx),
                onChanged = function(v) temp.rx = v * 1.0 end,
            },
            {
                type      = 'slider',
                label     = L('studio.edit.rot_y'),
                min       = -180, max = 180,
                value     = math.floor(fx.ry),
                onChanged = function(v) temp.ry = v * 1.0 end,
            },
            {
                type      = 'slider',
                label     = L('studio.edit.rot_z'),
                min       = -180, max = 180,
                value     = math.floor(fx.rz),
                onChanged = function(v) temp.rz = v * 1.0 end,
            },
            {
                type      = 'input',
                label     = L('studio.edit.duration'),
                min       = 0, max = 3600,
                value     = fx.duration,
                onChanged = function(v) temp.duration = math.max(0, math.floor(tonumber(v) or 0)) end,
            },
            {
                label  = L('studio.edit.apply'),
                action = function()
                    TriggerServerEvent('gu-particlestudio:server:effects:edit', fx.id, temp)
                    Notify(L('studio.edited'), 3000, 'success')
                end,
            },
            {
                label  = L('studio.edit.delete'),
                action = function()
                    TriggerServerEvent('gu-particlestudio:server:effects:remove', fx.id)
                    Notify(L('studio.removed'), 3000, 'success')
                    CloseMenu()
                end,
            },
        },
    }
end

local function BuildActiveEffectsMenu()
    local effects = GetServerEffects()

    local ids = {}
    for id in pairs(effects) do ids[#ids+1] = id end
    table.sort(ids)

    local elements = {}
    for _, id in ipairs(ids) do
        local fx = effects[id]
        elements[#elements+1] = {
            label  = '#' .. id .. '  ' .. fx.effect,
            desc   = fx.dict .. '  |  ' .. fx.type .. '  |  x' .. string.format('%.1f', fx.scale),
            action = function() OpenSubMenu(BuildEffectEditMenu(fx)) end,
        }
    end

    return {
        title      = L('studio.menu.active'),
        subtext    = L('studio.menu.active_desc'),
        searchable = true,
        elements   = elements,
    }
end

function OpenMainMenu()
    local elements = {}

    if _lastBrowsed then
        elements[#elements+1] = {
            label   = string.format(L('studio.menu.continue'), _lastBrowsed.dictName),
            desc    = _lastBrowsed.fxType,
            submenu = _lastBrowsed.menuRef,
        }
    end

    elements[#elements+1] = {
        label  = L('studio.menu.browse'),
        desc   = L('studio.menu.browse_desc'),
        action = function() OpenSubMenu(BuildBrowseMenu()) end,
    }
    elements[#elements+1] = {
        label  = L('studio.menu.active'),
        desc   = L('studio.menu.active_desc'),
        action = function()
            if not next(GetServerEffects()) then
                Notify(L('studio.no_effects'), 3000, 'error')
                return
            end
            OpenSubMenu(BuildActiveEffectsMenu())
        end,
    }
    elements[#elements+1] = {
        label = L('studio.menu.clear'),
        desc  = L('studio.menu.clear_desc'),
        submenu = {
            title    = L('studio.menu.clear'),
            subtext  = L('studio.menu.clear_confirm'),
            elements = {
                {
                    label  = L('studio.prompt.confirm'),
                    action = function()
                        TriggerServerEvent('gu-particlestudio:server:effects:clearAll')
                        Notify(L('studio.cleared'), 3000, 'success')
                        CloseMenu()
                    end,
                },
                {
                    label  = L('studio.prompt.back'),
                    action = function() GoBack() end,
                },
            },
        },
    }
    elements[#elements+1] = {
        label  = L('studio.menu.export'),
        desc   = L('studio.menu.export_desc'),
        action = ExportEffects,
    }

    OpenMenu({
        title    = L('studio.menu.title'),
        elements = elements,
    })
end
