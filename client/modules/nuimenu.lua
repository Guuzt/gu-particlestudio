local menuStack   = {}
local currentMenu = nil
local menuOpen    = false

local function Serialize(menuDef)
    local items = {}
    for i, element in ipairs(menuDef.elements) do
        items[i] = {
            label  = element.label,
            desc   = element.desc,
            type   = element.type or (element.submenu and 'submenu') or 'button',
            min    = element.min,
            max    = element.max,
            value  = element.value,
            factor = element.factor,
        }
    end
    return {
        title             = menuDef.title or '',
        subtext           = menuDef.subtext or '',
        searchable        = menuDef.searchable or false,
        searchPlaceholder = L('studio.menu.search_hint'),
        emptyText         = L('studio.menu.no_results'),
        canGoBack         = #menuStack > 0,
        elements          = items,
    }
end

local function Render()
    SendNUIMessage({ action = 'openMenu', menu = Serialize(currentMenu) })
end

function OpenMenu(menuDef)
    menuStack   = {}
    currentMenu = menuDef
    menuOpen    = true
    SetNuiFocus(true, true)
    Render()
end

function OpenSubMenu(menuDef)
    if currentMenu then
        menuStack[#menuStack+1] = currentMenu
    end
    currentMenu = menuDef
    menuOpen    = true
    SetNuiFocus(true, true)
    Render()
end

function GoBack()
    if #menuStack == 0 then
        CloseMenu()
        return
    end
    currentMenu = table.remove(menuStack)
    Render()
end

function CloseMenu()
    if not menuOpen then return end
    menuStack   = {}
    currentMenu = nil
    menuOpen    = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMenu' })
end

function IsMenuOpen()
    return menuOpen
end

RegisterNUICallback('menuSelect', function(data, cb)
    cb('ok')
    local element = currentMenu and currentMenu.elements[data.index]
    if not element then return end
    if element.submenu then
        OpenSubMenu(element.submenu)
    elseif element.action then
        element.action()
    end
end)

RegisterNUICallback('menuChange', function(data, cb)
    cb('ok')
    local element = currentMenu and currentMenu.elements[data.index]
    if not element then return end
    element.value = data.value
    if element.onChanged then
        element.onChanged(data.value)
    end
end)

RegisterNUICallback('menuBack', function(_, cb)
    cb('ok')
    GoBack()
end)

RegisterNUICallback('menuClose', function(_, cb)
    cb('ok')
    CloseMenu()
end)

RegisterNetEvent('gu-particlestudio:client:notify')
AddEventHandler('gu-particlestudio:client:notify', function(message, timer, ntype)
    SendNUIMessage({ action = 'notify', message = message, ntype = ntype or 'info', timer = timer or 5000 })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    SetNuiFocus(false, false)
end)
