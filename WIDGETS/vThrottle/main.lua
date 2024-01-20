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
    lcd.drawText(cell.x, cell.y, CHAR_TELEMETRY .. "Throttle", LEFT  + wgt.text_color)

    local val = string.format("%.0f%%", 0)
    local _,vh = lcd.sizeText(val, BOLD + MIDSIZE)
    lcd.drawText(cell.x + cell.w - 6, cell.y + cell.h - vh, val, BOLD + RIGHT + MIDSIZE + wgt.text_color)

    -- -- write text
    -- if wgt.useSensorP then
    --     -- power bar
    --     local volts = string.format("%.1f v", wgt.vTotalLive);
    --     lcd.drawText(cell.x + 8, cell.y + 4, volts, BOLD + LEFT  + wgt.text_color + wgt.no_telem_blink + wgt.low_batt_blink)

    --     if wgt.useSensorM then
    --         local mah = string.format("%.0f mah", wgt.vMah)
    --         lcd.drawText(cell.x + 8, cell.y + cell.h / 2, mah, BOLD + LEFT  + wgt.text_color + wgt.no_telem_blink)
    --     end

    --     local percent = string.format("%.0f%%", wgt.vPercent)
    --     lcd.drawText(cell.x + cell.w - 4, cell.y + cell.h / 2, percent, BOLD + VCENTER + RIGHT + MIDSIZE + wgt.text_color + wgt.no_telem_blink + wgt.low_batt_blink)
    -- else
    --     -- standard
    --     local topLine = string.format(" %2.2f V     %2.0f %%", wgt.mainValue, wgt.vPercent)
    --     lcd.drawText(cell.x + 15, cell.y + 1, topLine, MIDSIZE + wgt.text_color + wgt.no_telem_blink)
    -- end
end

-- This function allow recording of lowest cells when widget is in background
local function background(wgt)

    local val = nil
    -- if(wgt.options.EscPWM ~= 0) then
        val = getValue(wgt.options.EscPWM)
    -- end
    log("val: " .. val)
    
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
