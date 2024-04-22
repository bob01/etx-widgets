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

-- Dispay configured BEC voltage source
-- Designed for top bar
-- Author: Rob Gayle (bob00@rogers.com)
-- Date: 2024
-- ver: 0.1.0

local app_name = "eBecMeter"

local _options = {
    { "Color"           , COLOR, WHITE },
    { "Shadow"          , BOOL, 1 },
    { "Align_label"     , ALIGNMENT, LEFT },
    { "Align_value"     , ALIGNMENT, RIGHT },
}

--------------------------------------------------------------

local LS_BEC_MONITOR_INDEX          = 11

local TELE_ADC_SENSOR_INDEX     = 12
local TELE_ESC_SENSOR_INDEX     = 19


local function update(wgt, options)
    if (wgt == nil) then
        return
    end

    wgt.options = options

    if not wgt.vmeterAdcSensor then
        wgt.vmeterAdcSensor = model.getSensor(TELE_ADC_SENSOR_INDEX)
    end
    if not wgt.vmeterEscSensor then
        wgt.vmeterEscSensor = model.getSensor(TELE_ESC_SENSOR_INDEX)
    end

    wgt.value = 0
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,
    }

    update(wgt, options)
    return wgt
end

local function drawTextAligned(x, y, w, value, flags)
    if bit32.band(flags, CENTER) == CENTER then
        -- flags = bit32.band(flags, bit32.bnot(CENTER))
        x = x + w / 2
    elseif bit32.band(flags, RIGHT) == RIGHT then
        x = x + w
    end
    lcd.drawText(x, y, value, flags)
end

--- Zone size: top bar
local function refreshZoneTiny(wgt)
    local cell = { ["x"] = 0, ["y"] = 0, ["w"] = wgt.zone.w - 0, ["h"] = wgt.zone.h - 0 }

    -- draw
    local rx = cell.x + cell.w - 2
    local shadowed = wgt.options.Shadow and SHADOWED or 0

    if wgt.sensor then
        drawTextAligned(cell.x, cell.y, cell.w, CHAR_TELEMETRY .. wgt.sensor.name, wgt.options.Align_label + shadowed + wgt.text_color)

        local value = string.format("%0.2f", wgt.value)
        local flags = PREC2 + MIDSIZE + wgt.options.Align_value + shadowed + wgt.text_color
        local _,vh = lcd.sizeText(value, flags)
        drawTextAligned(cell.x, cell.y + wgt.zone.h - vh + 4, cell.w, value, flags)
    else
        lcd.drawText(cell.x, cell.y, CHAR_TELEMETRY .. "???", wgt.options.Align_label + shadowed + wgt.text_color)
    end
end

-- This function allow recording of lowest cells when widget is in background
local function background(wgt)
    -- data available
    wgt.isDataAvailable = type(getValue("FM")) == "string"

    -- sensor
    wgt.sensor = nil
    if wgt.vmeterAdcSensor and wgt.vmeterEscSensor then
        local lswitch = model.getLogicalSwitch(LS_BEC_MONITOR_INDEX)
        wgt.sensor = lswitch.v1 == getSourceIndex(CHAR_TELEMETRY..wgt.vmeterAdcSensor.name) and wgt.vmeterAdcSensor or wgt.vmeterEscSensor
    end

    -- value
    wgt.value = wgt.sensor and getValue(wgt.sensor.name) or 0
end

local function refresh(wgt, event, touchState)

    if (wgt == nil)         then return end
    if type(wgt) ~= "table" then return end
    if (wgt.options == nil) then return end
    if (wgt.zone == nil)    then return end

    background(wgt)

    if wgt.isDataAvailable then
        wgt.text_color = wgt.options.Color
    else
        wgt.text_color = COLOR_THEME_DISABLED
    end

    refreshZoneTiny(wgt)
end

return { name = app_name, options = _options, create = create, update = update, background = background, refresh = refresh }
