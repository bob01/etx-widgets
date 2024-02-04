--[[
#########################################################################
#                                                                       #
# Telemetry Widget script for FrSky Horus/RadioMaster TX16s             #
# Copyright "Offer Shmuely"                                             #
#                                                                       #
# License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
#                                                                       #
# This program is free software; you can redistribute it and/or modify  #
# it under the terms of the GNU General Public License version 2 as     #
# published by the Free Software Foundation.                            #
#                                                                       #
# This program is distributed in the hope that it will be useful        #
# but WITHOUT ANY WARRANTY; without even the implied warranty of        #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
# GNU General Public License for more details.                          #
#                                                                       #
#########################################################################

]]

-- Throttle and arm state display for RotorFlight
-- Designed for 1/8 cell
-- Author: Rob Gayle (bob00@rogers.com)
-- Date: 2024
-- ver: 0.4.0

local app_name = "vThrottle"

local AUDIO_PATH = "/SOUNDS/en/"

local _options = {
    { "ThrottleSensor"    , SOURCE, 0 },
    { "FlightModeSensor"  , SOURCE, 0 },
    { "Status"            , BOOL, 1 },
    { "Voice"             , BOOL, 1 },
}

local defaultSensor = "RxBt" -- RxBt / A1 / A3/ VFAS / Batt

--------------------------------------------------------------
local function log(s)
    print("vThrottle: " .. s)
end
--------------------------------------------------------------

local function update(wgt, options)
    if (wgt == nil) then
        return
    end

    wgt.options = options
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,

        text_color = 0,
        cell_color = 0,

        isDataAvailable = false,

        fmode = "",
        throttle = "",

        armed = false,
    }

    -- imports
    wgt.ToolsClass = loadScript("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "tcd")
    wgt.tools = wgt.ToolsClass(app_name)

    update(wgt, options)
    return wgt
end

-- audio support
local function playAudio(f)
    playFile(AUDIO_PATH .. f .. ".wav")
end

--- Zone size: 160x32 1/8th
local function refreshZoneSmall(wgt)
    local cell = { ["x"] = 5, ["y"] = 4, ["w"] = wgt.zone.w - 4, ["h"] = wgt.zone.h - 8 }

    -- draw
    local rx = cell.x + cell.w - 6

    lcd.drawText(cell.x, cell.y, CHAR_TELEMETRY .. "Throttle", LEFT + wgt.text_color)

    if wgt.isDataAvailable then
        if wgt.options.Status == 1 then
            lcd.drawText(rx, cell.y, wgt.fmode, RIGHT + wgt.text_color)
        end
    end

    local _,vh = lcd.sizeText(wgt.throttle, BOLD + MIDSIZE)
    lcd.drawText(rx, cell.y + wgt.zone.h - vh, wgt.throttle, BOLD + RIGHT + MIDSIZE + wgt.text_color)
end

-- This function allow recording of lowest cells when widget is in background
local function background(wgt)

    -- assume telemetry not available
    wgt.isDataAvailable = false

    -- configured?
    local fm
    if wgt.options.FlightModeSensor ~= 0 then
        -- configured, try to fetch telemetry value - will be 0 (number) if not connected
        fm = getValue(wgt.options.FlightModeSensor)
        wgt.isDataAvailable = type(fm) == "string"
    end

    -- connected?
    if wgt.isDataAvailable then
        -- connected
        -- armed?
        local armed = string.find(fm, "*") ~= nil
        if armed then
            -- armed, get ESC throttle if configured
            if wgt.options.ThrottleSensor ~= 0 then
                local thro = getValue(wgt.options.ThrottleSensor)
                wgt.throttle = string.format("%d%%", thro)
            else
                wgt.throttle = "--"
            end

        else
            -- not armed
            wgt.throttle = "Safe"
        end

        -- keep value for display
        wgt.fmode = fm

        -- announce if armed state changed
        if wgt.armed ~= armed and wgt.options.Voice == 1 then
            if armed then
                playAudio("armed")
            else
                playAudio("disarm")
            end
            wgt.armed = armed
        end

    else
        -- not connected
        wgt.throttle = "**"
        wgt.fmode = ""

        -- reset last armed
        wgt.armed = false
    end
end

local function refresh(wgt, event, touchState)

    if (wgt == nil)         then return end
    if type(wgt) ~= "table" then return end
    if (wgt.options == nil) then return end
    if (wgt.zone == nil)    then return end

    background(wgt)

    if wgt.isDataAvailable then
        wgt.text_color = BLACK
        wgt.cell_color = BLACK
    else
        wgt.text_color = GREY
        wgt.cell_color = GREY
    end

    refreshZoneSmall(wgt)

end

return { name = app_name, options = _options, create = create, update = update, background = nil, refresh = refresh }
