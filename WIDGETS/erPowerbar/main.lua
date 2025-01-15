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


-- This widget display a graphical representation of a Lipo/Li-ion (not other types) battery level,
-- it will automatically detect the cell amount of the battery.
-- it will take a lipo/li-ion voltage that received as a single value (as opposed to multi cell values send while using FLVSS liPo Voltage Sensor)
-- common sources are:
--   * Transmitter Battery
--   * FrSky VFAS
--   * A1/A2 analog voltage
--   * mini quad flight controller
--   * radio-master 168
--   * OMP m2 heli

]]

-- Based on...
-- Widget to display the levels of Lipo battery from single analog source
-- Author : Offer Shmuely
-- Date: 2021-2023
-- ver: 0.5

-- Voice alerts added, kill the blink, brighter battery colors + line
-- Added consumption "power bar"
-- friendlier UI, new name (vPowerBar), specify cell count option, reserve, haptic critical
-- Author: Rob Gayle (bob00@rogers.com)
-- Date: 2024
-- ver: 0.8.2

local app_name = "erPowerbar"

local AUDIO_PATH = "/SOUNDS/en/"

local battCritical = 20
local battLowMargin = 10

local cellFull = 4.16

local CELL_DETECTION_TIME = 1000
local VOLTTIMER_DISABLED = -1

local GV_CEL = 3

local defaultVoltSensor = "Vbat"
local defaultPcntSensor = "Bat%"
local defaultMahSensor = "Capa"

local _options = {
    { "VoltSensor"            , SOURCE, 0 },
    { "PcntSensor"            , SOURCE, 0 },
    { "MahSensor"             , SOURCE, 0 },
    { "Reserve"               , VALUE, 20, 0, 1000 },   -- reserve (or filter samples if calc percentage)
    { "Cells"                 , VALUE, 0, 0, 14 },      -- cell detection time (or interval if calc perceentage)
}

--------------------------------------------------------------
local function log(s)
    -- print("BattAnalog: " .. s)
end
--------------------------------------------------------------

local function getSensorFieldInfo(wgt, name)
    local fi = getFieldInfo(name)
    if fi == nil then
        wgt.common.log("Required sensor '"..name.."' missing")
    end
    return fi
end

local function update(wgt, options)
    if (wgt == nil) then
        return
    end

    wgt.options = options

    wgt.vReserve = wgt.options.Reserve
    battCritical = wgt.vReserve > 0 and wgt.vReserve or 20

    -- reload common libraries
    local commonClass = loadScript("/WIDGETS/erLib/lib_common.lua", "tcd")
    wgt.common = commonClass(app_name)

    if wgt.options.VoltSensor == 0 then
        wgt.options.VoltSensor = defaultVoltSensor
    end

    if wgt.options.PcntSensor == 0 then
        wgt.options.PcntSensor = defaultPcntSensor
    end

    if wgt.options.MahSensor == 0 then
        wgt.options.MahSensor = defaultMahSensor
    end

    local fi = getSensorFieldInfo(wgt, wgt.options.VoltSensor)
    wgt.sensorVoltId = fi and fi.id or 0

    fi = getSensorFieldInfo(wgt, wgt.options.MahSensor)
    wgt.sensorMahId = fi and fi.id or 0

    fi = getSensorFieldInfo(wgt, wgt.options.PcntSensor)
    wgt.sensorPcntId = fi and fi.id or 0

    fi = getSensorFieldInfo(wgt, "Cel#")
    wgt.sensorCellsId = fi and fi.id or 0

    -- cell count
    if wgt.options.Cells == 0 then
        local gvCel = model.getGlobalVariable(GV_CEL, 0)
        if gvCel == 0 then
            -- auto cell detection
            wgt.cellCount = 1
            wgt.cell_detected = false
        else
            -- use GV cell count
            wgt.cellCount = gvCel
            wgt.cell_detected = true
        end
    else
        -- use cell settings
        wgt.cellCount = wgt.options.Cells
        wgt.cell_detected = true
    end
    wgt.low_batt_blink = BLINK
    wgt.voltTimer = VOLTTIMER_DISABLED
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,
        counter = 0,

        text_color = 0,
        cell_color = 0,
        border_l = 5,
        border_r = 10,
        border_t = 0,
        border_b = 10,

        isTelemetryActive = 0,
        vPercent = 0,
        vReserve = 20,
        vMah = 0,
        cellCount = 1,
        cell_detected = false,
        low_batt_blink = 0,
        voltTimer = VOLTTIMER_DISABLED,
        mainValue = 0,
        secondaryValue = 0,

        battNextPlay = 0,
        battPercentPlayed = 100,
    }

    update(wgt, options)
    return wgt
end

-- audio support
local function playAudio(f)
    playFile(AUDIO_PATH .. f .. ".wav")
end

-- Only invoke this function once.
local function calcCellCount(voltage)
    if voltage     < 4.3  then return 1
    elseif voltage < 8.6  then return 2
    elseif voltage < 12.9 then return 3
    elseif voltage < 17.2 then return 4
    elseif voltage < 21.5 then return 5
    elseif voltage < 25.8 then return 6
    elseif voltage < 30.1 then return 7
    elseif voltage < 34.4 then return 8
    elseif voltage < 38.7 then return 9
    elseif voltage < 43.0 then return 10
    elseif voltage < 47.3 then return 11
    elseif voltage < 51.6 then return 12
    elseif voltage < 60.2 then return 14
    end

    return 1
end

--- This function returns a table with cels values
local function calculateBatteryData(wgt)
    -- get voltage
    local v = getValue(wgt.sensorVoltId)

    -- cell count detection, wait for telemetry to report
    if not wgt.cell_detected and wgt.sensorCellsId ~= 0 then
        local cells = getValue(wgt.sensorCellsId)
        if cells ~= 0 then
            wgt.cellCount = cells
            wgt.cell_detected = true
            wgt.voltTimer = getTime() + CELL_DETECTION_TIME
        end
    end

    -- check for initial voltage check
    if wgt.voltTimer ~= VOLTTIMER_DISABLED and wgt.voltTimer < getTime() then
        wgt.voltTimer = VOLTTIMER_DISABLED

        -- finalize cell count
        wgt.cellCount = wgt.cellCount ~= 0 and wgt.cellCount or calcCellCount(v)

        -- warn if battery low
        if (v / wgt.cellCount) >= cellFull then
            wgt.low_batt_blink = 0
        else
            playAudio("batlow")
            playNumber(v * 10, 1, PREC1)
        end
    end

    -- check if GV:4(Cel) cell count changed
    if wgt.options.Cells == 0 then
        local gvCel = model.getGlobalVariable(GV_CEL, 0)
        if gvCel ~= 0 and gvCel ~= wgt.cellCount then
            -- use new GV cell count
            wgt.cellCount = gvCel
            wgt.cell_detected = true
        end
    end

    -- battery voltage
    wgt.mainValue = v / wgt.cellCount
    wgt.secondaryValue = v

    -- battery percentage
    if wgt.sensorPcntId ~= 0 then
        local pcnt = getValue(wgt.sensorPcntId)
        if pcnt < wgt.vReserve then
            wgt.vPercent = pcnt - wgt.vReserve
        else
            local usable = 100 - wgt.vReserve
            wgt.vPercent = (pcnt - wgt.vReserve) / usable * 100
        end
    else
        wgt.vPercent = 0
    end

    -- battery mah
    if wgt.sensorMahId ~= 0 then
        wgt.vMah = getValue(wgt.sensorMahId)
    end
end


-- color for gauge
local function getPercentColor(wgt)
    local critical = wgt.vReserve == 0 and battCritical or 0
    if wgt.vPercent <= critical then
        -- red
        return lcd.RGB(0xff, 0, 0)
    elseif wgt.vPercent <= critical + 20 then
        -- yellow
        return lcd.RGB(0xff, 0xff, 0)
    else
        -- green
        return lcd.RGB(0, 0xff, 0)
    end
end

--- Zone size: 160x32 1/8th
local function refreshZoneSmall(wgt)
    local myBatt = { ["x"] = 4, ["y"] = 4, ["w"] = wgt.zone.w - 8, ["h"] = wgt.zone.h - 8, ["segments_w"] = 25, ["color"] = WHITE, ["cath_w"] = 6, ["cath_h"] = 20 }

    -- fill battery
    local fill_color = getPercentColor(wgt)
    lcd.drawGauge(myBatt.x, myBatt.y, myBatt.w, myBatt.h, wgt.vPercent, 100, fill_color)

    -- draw battery
    lcd.drawRectangle(myBatt.x, myBatt.y, myBatt.w + 1, myBatt.h, wgt.text_color, 2)

    -- write text
    local low_batt_blink = wgt.isTelemetryActive and wgt.low_batt_blink or 0

    -- power bar
    local volts
    if wgt.cell_detected then
        -- cell count available
        volts = string.format("%.1f v / %.2f v (%.0fs)", wgt.secondaryValue, wgt.mainValue, wgt.cellCount);
    else
        -- cell count not available
        volts = string.format("%.1f v / %.2f v (?s)", wgt.secondaryValue, wgt.mainValue);
    end
    lcd.drawText(myBatt.x + 8, myBatt.y + 4, volts, BOLD + LEFT  + wgt.text_color + low_batt_blink)

    if wgt.sensorMahId ~= 0 then
        local mah = string.format("%.0f mah", wgt.vMah)
        lcd.drawText(myBatt.x + 8, myBatt.y + myBatt.h / 2, mah, BOLD + LEFT  + wgt.text_color)
    end

    local percent = string.format("%.0f%%", wgt.vPercent)
    lcd.drawText(myBatt.x + myBatt.w - 4, myBatt.y + myBatt.h / 2, percent, BOLD + VCENTER + RIGHT + MIDSIZE + wgt.text_color + low_batt_blink)
end

-- This function allow recording of lowest cells when widget is in background
local function background(wgt)
    if (wgt == nil) then
        return
    end

    -- assume no telemetry if required sensors missing
    if wgt.sensorVoltId == 0 or wgt.sensorPcntId == 0 then
        wgt.isTelemetryActive = false
    else
        local telemetryActive = wgt.common.isTelemetryActive()
        if telemetryActive ~= wgt.isTelemetryActive then
            wgt.isTelemetryActive = telemetryActive
            if wgt.isTelemetryActive then
                -- restart voltage check timer on telemetry connection
                wgt.low_batt_blink = BLINK
                wgt.voltTimer = getTime() + CELL_DETECTION_TIME
            end
        end
    end

    -- bail if no telemetry
    if not wgt.isTelemetryActive then
        return
    end

    calculateBatteryData(wgt)

    -- voice alerts
    local fvpcnt = wgt.vPercent

    -- what do we have to report?
    local battva = 0
    if fvpcnt > battCritical then
        battva = math.ceil(fvpcnt / 10) * 10
    else
        battva = fvpcnt
    end

    -- silence until cell_detected
    if not wgt.cell_detected then
        wgt.battPercentPlayed = battva
    end

    -- time to report?
    if (wgt.battPercentPlayed ~= battva or battva <= 0) and getTime() > wgt.battNextPlay then

        -- urgent?
        local critical = wgt.vReserve == 0 and battCritical or 0
        if battva > critical + battLowMargin then
            playAudio("battry")
        elseif battva > critical then
            playAudio("batlow")
        else
            playAudio("batcrt")
            playHaptic(100, 0, PLAY_NOW)
        end

        -- play % if >= 0
        if battva >= 0 then
            playNumber(battva, 13)
        end

        wgt.battPercentPlayed = battva
        wgt.battNextPlay = getTime() + 500
    end
end

local function refresh(wgt, event, touchState)
    if (wgt == nil)         then return end
    if type(wgt) ~= "table" then return end
    if (wgt.options == nil) then return end
    if (wgt.zone == nil)    then return end
    --if (wgt.options.Show_Total_Voltage == nil) then return end

    background(wgt)

    if wgt.isTelemetryActive then
        wgt.text_color = BLACK
        wgt.cell_color = BLACK
    else
        wgt.text_color = COLOR_THEME_DISABLED
        wgt.cell_color = COLOR_THEME_DISABLED
    end

    refreshZoneSmall(wgt)

    if (event ~= nil) then
        if (touchState and touchState.tapCount == 2) or (event and event == EVT_VIRTUAL_EXIT) then
            lcd.exitFullScreen()
        end
    end
end

return { name = app_name, options = _options, create = create, update = update, background = background, refresh = refresh }
