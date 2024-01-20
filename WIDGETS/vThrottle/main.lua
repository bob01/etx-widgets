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
-- Author: Robert Gayle (bob00@rogers.com)
-- Date: 2024
-- ver: 0.1.0

local app_name = "vThrottle"

local AUDIO_PATH = "/SOUNDS/en/"

local _options = {
    { "EscPWM"            , SOURCE, 0 },
    { "FlightMode"        , SOURCE, 0 },
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
        throttle = ""
    }

    -- imports
    wgt.ToolsClass = loadScript("/WIDGETS/" .. app_name .. "/lib_widget_tools.lua", "tcd")
    wgt.tools = wgt.ToolsClass(app_name)

    update(wgt, options)
    return wgt
end

--- Zone size: 160x32 1/8th
local function refreshZoneSmall(wgt)
    local cell = { ["x"] = 5, ["y"] = 4, ["w"] = wgt.zone.w - 4, ["h"] = wgt.zone.h - 8 }

    -- draw
    local rx = cell.x + cell.w - 6

    lcd.drawText(cell.x, cell.y, CHAR_TELEMETRY .. "Throttle", LEFT + wgt.text_color)

    if(wgt.isDataAvailable) then
        lcd.drawText(rx, cell.y, wgt.fmode, RIGHT + wgt.text_color)
    end

    local _,vh = lcd.sizeText(wgt.throttle, BOLD + MIDSIZE)
    lcd.drawText(rx, cell.y + wgt.zone.h - vh, wgt.throttle, BOLD + RIGHT + MIDSIZE + wgt.text_color)
end

-- This function allow recording of lowest cells when widget is in background
local function background(wgt)

    -- assume telemetry not available
    wgt.isDataAvailable = false

    if wgt.options.FlightMode ~= 0 then
        local fm = getValue(wgt.options.FlightMode)
        wgt.isDataAvailable = type(fm) == "string"

        if(wgt.isDataAvailable) then
            if string.find(fm, "*") ~= nil then
                if wgt.options.EscPWM ~= 0 then
                    local thro = getValue(wgt.options.EscPWM)
                    wgt.throttle = string.format("%d%%", thro)
                else
                    wgt.throttle = "--"
                end
            else
                wgt.throttle = "Safe"
            end
            wgt.fmode = fm
        else
            wgt.throttle = "Safe"
            wgt.fmode = ""
        end
    end

    -- local val = nil
    -- -- if(wgt.options.EscPWM ~= 0) then
    --     val = getValue(wgt.options.FlightMode)
    -- -- end
    -- log("val: " .. val)
    
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
