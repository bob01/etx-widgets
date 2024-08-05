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
-- ver: 0.7.5

local app_name = "ePowerbar"

local AUDIO_PATH = "/SOUNDS/en/"

local battCritical = 20
local battLowMargin = 10

local cellFull = 4.16

local CELL_DETECTION_TIME = 10
local VFLT_SAMPLES_DEFAULT = 150
local VFLT_INTERVAL_DEFAULT = 10

local GV_CEL = 3

local _options = {
    { "VoltSensor"            , SOURCE, 0 }, -- default to 'A1'
    { "PcntSensor"            , SOURCE, 0 },
    { "MahSensor"             , SOURCE, 0 },
    { "Reserve"               , VALUE, 20, 0, 1000 },   -- reserve (or filter samples if calc percentage)
    { "Cells"                 , VALUE, 0, 0, 14 },      -- cell detection time (or interval if calc perceentage)
}

-- Data gathered from commercial lipo sensors
local _lipoPercentListSplit = {
    { { 3.000,  0 }, { 3.093,  1 }, { 3.196,  2 }, { 3.301,  3 }, { 3.401,  4 }, { 3.477,  5 }, { 3.544,  6 }, { 3.601,  7 }, { 3.637,  8 }, { 3.664,  9 }, { 3.679, 10 }, { 3.683, 11 }, { 3.689, 12 }, { 3.692, 13 } },
    { { 3.705, 14 }, { 3.710, 15 }, { 3.713, 16 }, { 3.715, 17 }, { 3.720, 18 }, { 3.731, 19 }, { 3.735, 20 }, { 3.744, 21 }, { 3.753, 22 }, { 3.756, 23 }, { 3.758, 24 }, { 3.762, 25 }, { 3.767, 26 } },
    { { 3.774, 27 }, { 3.780, 28 }, { 3.783, 29 }, { 3.786, 30 }, { 3.789, 31 }, { 3.794, 32 }, { 3.797, 33 }, { 3.800, 34 }, { 3.802, 35 }, { 3.805, 36 }, { 3.808, 37 }, { 3.811, 38 }, { 3.815, 39 } },
    { { 3.818, 40 }, { 3.822, 41 }, { 3.825, 42 }, { 3.829, 43 }, { 3.833, 44 }, { 3.836, 45 }, { 3.840, 46 }, { 3.843, 47 }, { 3.847, 48 }, { 3.850, 49 }, { 3.854, 50 }, { 3.857, 51 }, { 3.860, 52 } },
    { { 3.863, 53 }, { 3.866, 54 }, { 3.870, 55 }, { 3.874, 56 }, { 3.879, 57 }, { 3.888, 58 }, { 3.893, 59 }, { 3.897, 60 }, { 3.902, 61 }, { 3.906, 62 }, { 3.911, 63 }, { 3.918, 64 } },
    { { 3.923, 65 }, { 3.928, 66 }, { 3.939, 67 }, { 3.943, 68 }, { 3.949, 69 }, { 3.955, 70 }, { 3.961, 71 }, { 3.968, 72 }, { 3.974, 73 }, { 3.981, 74 }, { 3.987, 75 }, { 3.994, 76 } },
    { { 4.001, 77 }, { 4.007, 78 }, { 4.014, 79 }, { 4.021, 80 }, { 4.029, 81 }, { 4.036, 82 }, { 4.044, 83 }, { 4.052, 84 }, { 4.062, 85 }, { 4.074, 86 }, { 4.085, 87 }, { 4.095, 88 } },
    { { 4.105, 89 }, { 4.111, 90 }, { 4.116, 91 }, { 4.120, 92 }, { 4.125, 93 }, { 4.129, 94 }, { 4.135, 95 }, { 4.145, 96 }, { 4.176, 97 }, { 4.179, 98 }, { 4.193, 99 }, { 4.200, 100 } },
}

-- from: https://electric-scooter.guide/guides/electric-scooter-battery-voltage-chart/
local _liionPercentListSplit = {
    { { 2.800,  0 }, { 2.840,  1 }, { 2.880,  2 }, { 2.920,  3 }, { 2.960,  4 } },
    { { 3.000,  5 }, { 3.040,  6 }, { 3.080,  7 }, { 3.096,  8 }, { 3.112,  9 } },
    { { 3.128, 10 }, { 3.144, 11 }, { 3.160, 12 }, { 3.176, 13 }, { 3.192, 14 } },
    { { 3.208, 15 }, { 3.224, 16 }, { 3.240, 17 }, { 3.256, 18 }, { 3.272, 19 } },
    { { 3.288, 20 }, { 3.304, 21 }, { 3.320, 22 }, { 3.336, 23 }, { 3.352, 24 } },
    { { 3.368, 25 }, { 3.384, 26 }, { 3.400, 27 }, { 3.416, 28 }, { 3.432, 29 } },
    { { 3.448, 30 }, { 3.464, 31 }, { 3.480, 32 }, { 3.496, 33 }, { 3.504, 34 } },
    { { 3.512, 35 }, { 3.520, 36 }, { 3.528, 37 }, { 3.536, 38 }, { 3.544, 39 } },
    { { 3.552, 40 }, { 3.560, 41 }, { 3.568, 42 }, { 3.576, 43 }, { 3.584, 44 } },
    { { 3.592, 45 }, { 3.600, 46 }, { 3.608, 47 }, { 3.616, 48 }, { 3.624, 49 } },
    { { 3.632, 50 }, { 3.640, 51 }, { 3.648, 52 }, { 3.656, 53 }, { 3.664, 54 } },
    { { 3.672, 55 }, { 3.680, 56 }, { 3.688, 57 }, { 3.696, 58 }, { 3.704, 59 } },
    { { 3.712, 60 }, { 3.720, 61 }, { 3.728, 62 }, { 3.736, 63 }, { 3.744, 64 } },
    { { 3.752, 65 }, { 3.760, 66 }, { 3.768, 67 }, { 3.776, 68 }, { 3.784, 69 } },
    { { 3.792, 70 }, { 3.800, 71 }, { 3.810, 72 }, { 3.820, 73 }, { 3.830, 74 } },
    { { 3.840, 75 }, { 3.850, 76 }, { 3.860, 77 }, { 3.870, 78 }, { 3.880, 79 } },
    { { 3.890, 80 }, { 3.900, 81 }, { 3.910, 82 }, { 3.920, 83 }, { 3.930, 84 } },
    { { 3.940, 85 }, { 3.950, 86 }, { 3.960, 87 }, { 3.970, 88 }, { 3.980, 89 } },
    { { 3.990, 90 }, { 4.000, 91 }, { 4.010, 92 }, { 4.030, 93 }, { 4.050, 94 } },
    { { 4.070, 95 }, { 4.090, 96 } },
    { { 4.10, 100}, { 4.15,100 }, { 4.20, 100} },
}

local defaultSensor = "RxBt" -- RxBt / A1 / A3/ VFAS / Batt

--------------------------------------------------------------
local function log(s)
    -- print("BattAnalog: " .. s)
end
--------------------------------------------------------------

local function update(wgt, options)
    if (wgt == nil) then
        return
    end

    wgt.options = options
    wgt.periodic1 = wgt.tools.periodicInit()
    wgt.low_batt_blink = 0

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

    -- use default if user did not set, So widget is operational on "select widget"
    if wgt.options.VoltSensor == 0 then
        wgt.options.VoltSensor = defaultSensor
    end

    wgt.options.source_name = ""
    if (type(wgt.options.VoltSensor) == "number") then
        local source_name = getSourceName(wgt.options.VoltSensor)
        if (source_name ~= nil) then
            if string.byte(string.sub(source_name, 1, 1)) > 127 then
                source_name = string.sub(source_name, 2, -1) -- ???? why?
            end
            if string.byte(string.sub(source_name, 1, 1)) > 127 then
                source_name = string.sub(source_name, 2, -1) -- ???? why?
            end
            log(string.format("source_name: %s", source_name))
            wgt.options.source_name = source_name
        end
    else
        wgt.options.source_name = wgt.options.VoltSensor
    end

    wgt.useSensorP = wgt.options.PcntSensor ~= 0
    wgt.useSensorM = wgt.options.MahSensor ~= 0

    if wgt.useSensorP then
        -- using telemetry for battery %
        if wgt.options.Reserve < 50 then
            wgt.vReserve = wgt.options.Reserve
            battCritical = wgt.vReserve > 0 and wgt.vReserve or 20
        else
            wgt.vReserve = 0
            battCritical = 20
        end
    else
        -- estimating battery %
        if wgt.options.Cells ~= 0 then
            wgt.vfltInterval = wgt.options.Cells
        else
            wgt.vfltInterval = VFLT_INTERVAL_DEFAULT
        end

        if wgt.options.Reserve ~= 0 then
            wgt.vfltSamples = wgt.options.Reserve
        else
            wgt.vfltSamples = VFLT_SAMPLES_DEFAULT
        end
        wgt.vReserve = 0
    end

    -- wgt.options.Show_Total_Voltage = wgt.options.Show_Total_Voltage % 2 -- modulo due to bug that cause the value to be other than 0|1

    -- log(string.format("wgt.options.Lithium_Ion: %s", wgt.options.Lithium_Ion))

    -- reset vflt
    wgt.vflt = {}
    wgt.vflti = 0
    wgt.vfltNextUpdate = 0
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

        telemResetCount = 0,
        telemResetLowestMinRSSI = 101,
        no_telem_blink = 0,
        isDataAvailable = 0,
        vMax = 0,
        vMin = 0,
        vTotalLive = 0,
        vPercent = 0,
        vReserve = 20,
        vMah = 0,
        cellCount = 1,
        cell_detected = false,
        low_batt_blink = 0,
        vCellLive = 0,
        mainValue = 0,
        secondaryValue = 0,

        battNextPlay = 0,
        battPercentPlayed = 100,

        vflt = {},
        vflti = 0,
        vfltSamples = 0,
        vfltInterval = 0, 
        vfltNextUpdate = 0,

        useSensorP = false,
        useSensorM = false,

        cellDetectionTime = CELL_DETECTION_TIME,
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

-- smoothen vPercent, sample every 1/10s, collect last N seconds
local function getFilteredvPercent(wgt)
    local count = #wgt.vflt
    if count == 0 then
        return 0
    end

    local sum = 0
    for i=1, count do
        sum = sum + wgt.vflt[i]
    end
    return math.ceil(sum / count)
end

local function updateFilteredvPercent(wgt, vPercent)
    if vPercent > 0 and getTime() > wgt.vfltNextUpdate then
        wgt.vflt[wgt.vflti + 1] = vPercent
        wgt.vflti = (wgt.vflti + 1) % wgt.vfltSamples

        wgt.vfltNextUpdate = getTime() + wgt.vfltInterval
    end

    return getFilteredvPercent(wgt)
end

-- clear old telemetry data upon reset event
local function onTelemetryResetEvent(wgt)
    log("telemetry reset event detected.")
    wgt.telemResetCount = wgt.telemResetCount + 1

    wgt.battPercentPlayed = 100
    wgt.battNextPlay = 0

    wgt.vflt = {}
    wgt.vflti = 0
    wgt.vfltNextUpdate = 0

    wgt.vTotalLive = 0
    wgt.vCellLive = 0
    wgt.vMin = 99
    wgt.vMax = 0
    wgt.cellCount = 1
    wgt.cell_detected = false
    wgt.low_batt_blink = 0
    wgt.periodic1 = wgt.tools.periodicInit()
    --wgt.tools.periodicStart(wgt.periodic1, CELL_DETECTION_TIME * 1000)
end

--- This function return the percentage remaining in a single Lipo cel
local function getCellPercent(wgt, cellValue)
    if cellValue == nil then
        return 0
    end

    -- in case somehow voltage is higher, don't return nil
    if (cellValue > 4.2) then
        return 100
    end

    local _percentListSplit = _lipoPercentListSplit
    --if wgt.options.Lithium_Ion == 1 then
    --    _percentListSplit = _liionPercentListSplit
    --end

    for i1, v1 in ipairs(_percentListSplit) do
        --log(string.format("sub-list#: %s, head:%f, length: %d, last: %.3f", i1,v1[1][1], #v1, v1[#v1][1]))
        --is the cellVal < last-value-on-sub-list? (first-val:v1[1], last-val:v1[#v1])
        if (cellValue <= v1[#v1][1]) then
            -- cellVal is in this sub-list, find the exact value
            --log("this is the list")
            for i2, v2 in ipairs(v1) do
                --log(string.format("cell#: %s, %.3f--> %d%%", i2,v2[1], v2[2]))
                if v2[1] >= cellValue then
                    result = v2[2]
                    --log(string.format("result: %d%%", result))
                    --cpuProfilerAdd(wgt, 'cell-perc', t4);
                    return result
                end
            end
        end
    end

    --for i, v in ipairs(_percentListSplit) do
    --  if v[1] >= cellValue then
    --    result = v[2]
    --    break
    --  end
    --end
    return result
end

-- Only invoke this function once.
local function calcCellCount(wgt, singleVoltage)
    if singleVoltage     < 4.3  then return 1
    elseif singleVoltage < 8.6  then return 2
    elseif singleVoltage < 12.9 then return 3
    elseif singleVoltage < 17.2 then return 4
    elseif singleVoltage < 21.5 then return 5
    elseif singleVoltage < 25.8 then return 6
    elseif singleVoltage < 30.1 then return 7
    elseif singleVoltage < 34.4 then return 8
    elseif singleVoltage < 38.7 then return 9
    elseif singleVoltage < 43.0 then return 10
    elseif singleVoltage < 47.3 then return 11
    elseif singleVoltage < 51.6 then return 12
    elseif singleVoltage < 60.2 then return 14
    end

    log("no match found" .. singleVoltage)
    return 1
end


--- This function returns a table with cels values
local function calculateBatteryData(wgt)

    local v = getValue(wgt.options.VoltSensor)
    local fieldinfo = getFieldInfo(wgt.options.VoltSensor)
    log("wgt.options.VoltSensor: " .. wgt.options.VoltSensor)

    if type(v) == "table" then
        -- multi cell values using FLVSS liPo Voltage Sensor
        if (#v > 1) then
            wgt.isDataAvailable = false
            local txt = "FLVSS liPo Voltage Sensor, not supported"
            log(txt)
            return
        end
    elseif v ~= nil and v >= 1 then
        -- single cell or VFAS lipo sensor
        if fieldinfo then
            -- log(wgt.options.source_name .. ", value: " .. fieldinfo.name .. "=" .. v)
        else
            log("only one cell using Ax lipo sensor")
        end
    else
        -- no telemetry available
        wgt.isDataAvailable = false
        if fieldinfo then
            log("no telemetry data: " .. fieldinfo['name'] .. "=??")
        else
            log("no telemetry data")
        end
        return
    end

    if (wgt.cell_detected == true) then
        log("permanent cellCount: " .. wgt.cellCount)
    else
        local newCellCount = calcCellCount(wgt, v)
        if (wgt.tools.periodicHasPassed(wgt.periodic1)) then
            wgt.cell_detected = true
            wgt.periodic1 = wgt.tools.periodicInit()
            wgt.cellCount = newCellCount
            if (v / newCellCount) >= cellFull then
                wgt.low_batt_blink = 0
            else
                playAudio("batlow")
                playNumber(v * 10, 1, PREC1)
            end
        else
            local duration_passed = wgt.tools.periodicGetElapsedTime(wgt.periodic1)
            --log(string.format("detecting cells: %ss, %d/%d msec", newCellCount, duration_passed, wgt.tools.getDurationMili(wgt.periodic1)))

            -- this is necessary for simu where cell-count can change
            if newCellCount ~= wgt.cellCount then
                wgt.vMin = 99
                wgt.vMax = 0
            end
            wgt.cellCount = newCellCount

            wgt.low_batt_blink = BLINK
        end
    end

    -- calc highest of all cells
    if v > wgt.vMax then
        wgt.vMax = v
    end

    wgt.vTotalLive = v
    wgt.vCellLive = wgt.vTotalLive / wgt.cellCount

    if wgt.useSensorP then
        local pcnt = getValue(wgt.options.PcntSensor)
        if pcnt < wgt.vReserve then
            wgt.vPercent = pcnt - wgt.vReserve
        else
            local usable = 100 - wgt.vReserve
            wgt.vPercent = (pcnt - wgt.vReserve) / usable * 100
        end
    else
        wgt.vPercent = updateFilteredvPercent(wgt, getCellPercent(wgt, wgt.vCellLive))
    end

    if wgt.useSensorM then
        wgt.vMah = getValue(wgt.options.MahSensor)
    end

    -- log("wgt.vCellLive: ".. wgt.vCellLive)
    -- log("wgt.vPercent: ".. wgt.vPercent)

    -- mainValue
    --if wgt.options.Show_Total_Voltage == 0 then
        wgt.mainValue = wgt.vCellLive
        wgt.secondaryValue = wgt.vTotalLive
    --[[
    elseif wgt.options.Show_Total_Voltage == 1 then
        wgt.mainValue = wgt.vTotalLive
        wgt.secondaryValue = wgt.vCellLive
    else
        wgt.mainValue = "-1"
        wgt.secondaryValue = "-2"
    end
    --]]

    --- calc lowest main voltage
    if wgt.mainValue < wgt.vMin and wgt.mainValue > 1 then
        -- min 1v to consider a valid reading
        wgt.vMin = wgt.mainValue
    end

    wgt.isDataAvailable = true
    -- if need detection and not detecting, start detection
    if not wgt.cell_detected and wgt.tools.getDurationMili(wgt.periodic1) == -1 then
        wgt.tools.periodicStart(wgt.periodic1, wgt.cellDetectionTime * 1000)
    end

end


-- color for battery
-- This function returns green at 100%, red bellow 30% and graduate in between
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

    -- else
    --    g = math.floor(0xdf * percent / 100)
    --    r = 0xdf - g
    --    return lcd.RGB(r, g, 0)
    end
end

local function drawBattery(wgt, myBatt)
    -- fill batt
    local fill_color = getPercentColor(wgt)
    local pcntY = math.floor(wgt.vPercent / 100 * (myBatt.h - myBatt.cath_h))
    local rectY = wgt.zone.y + myBatt.y + myBatt.h - pcntY
    lcd.drawFilledRectangle(wgt.zone.x + myBatt.x, rectY, myBatt.w, pcntY, fill_color)
    lcd.drawLine(wgt.zone.x + myBatt.x, rectY, wgt.zone.x + myBatt.x + myBatt.w - 1, rectY, SOLID, wgt.cell_color)

    -- draw battery segments
    lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.cath_h, myBatt.w, myBatt.h - myBatt.cath_h, wgt.cell_color, 2)
end

--- Zone size: 70x39 top bar
local function refreshZoneTiny(wgt)
    local myString = string.format("%2.2fV", wgt.mainValue)

    -- write text
    lcd.drawText(wgt.zone.x + wgt.zone.w - 25, wgt.zone.y + 5, wgt.vPercent .. "%", RIGHT + SMLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(wgt.zone.x + wgt.zone.w - 25, wgt.zone.y + 20, myString, RIGHT + SMLSIZE + wgt.text_color + wgt.no_telem_blink)

    -- draw battery
    local batt_color = wgt.text_color
    lcd.drawRectangle(wgt.zone.x + 50, wgt.zone.y + 9, 16, 25, batt_color, 2)
    lcd.drawFilledRectangle(wgt.zone.x + 50 + 4, wgt.zone.y + 7, 6, 3, batt_color)
    local rect_h = math.floor(25 * wgt.vPercent / 100)
    lcd.drawFilledRectangle(wgt.zone.x + 50, wgt.zone.y + 9 + 25 - rect_h, 16, rect_h, batt_color + wgt.no_telem_blink)
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
    -- power bar
    local volts
    if wgt.cell_detected then
        -- cell count available
        volts = string.format("%.1f v / %.2f v (%.0fs)", wgt.vTotalLive, wgt.vCellLive, wgt.cellCount);
    else
        -- cell count not available
        volts = string.format("%.1f v / %.2f v (?s)", wgt.vTotalLive, wgt.vCellLive);
    end
    lcd.drawText(myBatt.x + 8, myBatt.y + 4, volts, BOLD + LEFT  + wgt.text_color + wgt.no_telem_blink + wgt.low_batt_blink)

    if wgt.useSensorM then
        local mah = string.format("%.0f mah", wgt.vMah)
        lcd.drawText(myBatt.x + 8, myBatt.y + myBatt.h / 2, mah, BOLD + LEFT  + wgt.text_color + wgt.no_telem_blink)
    end

    local percent = string.format("%.0f%%", wgt.vPercent)
    lcd.drawText(myBatt.x + myBatt.w - 4, myBatt.y + myBatt.h / 2, percent, BOLD + VCENTER + RIGHT + MIDSIZE + wgt.text_color + wgt.no_telem_blink + wgt.low_batt_blink)
end

--- Zone size: 180x70 1/4th  (with sliders/trim)
--- Zone size: 225x98 1/4th  (no sliders/trim)
local function refreshZoneMedium(wgt)
    local myBatt = { ["x"] = 0 +  wgt.border_l, ["y"] = 0, ["w"] = 50, ["h"] = wgt.zone.h - wgt.border_b, ["segments_w"] = 15, ["color"] = WHITE, ["cath_w"] = 26, ["cath_h"] = 10, ["segments_h"] = 16 }

    -- draw values
    lcd.drawText(wgt.zone.x + myBatt.w + 10 +  wgt.border_l, wgt.zone.y, string.format("%.1f V", wgt.vTotalLive), DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(wgt.zone.x + myBatt.w + 12 +  wgt.border_l, wgt.zone.y + 30, string.format("%2.0f %%", wgt.vPercent), MIDSIZE + wgt.text_color + wgt.no_telem_blink)
    
    local volts
    if wgt.cell_detected then
        -- cell count available
        volts = string.format("%.2f v (%.0fs)", wgt.vCellLive, wgt.cellCount);
    else
        -- cell count not available
        volts = string.format("%.2f v (?s)", wgt.vCellLive);
    end
    lcd.drawText(wgt.zone.x + wgt.zone.w - 5 - wgt.border_r, wgt.zone.y + wgt.zone.h - 38, volts, RIGHT + wgt.text_color + wgt.no_telem_blink)

    if wgt.useSensorM then
        local mah = string.format("%.0f mah", wgt.vMah)
        lcd.drawText(wgt.zone.x + wgt.zone.w - 5 - wgt.border_r, wgt.zone.y + wgt.zone.h - 20, mah, RIGHT + wgt.text_color + wgt.no_telem_blink)
    end

    drawBattery(wgt, myBatt)
end

--- Zone size: 192x152 1/2
local function refreshZoneLarge(wgt)
    local myBatt = { ["x"] = 0, ["y"] = 0, ["w"] = 76, ["h"] = wgt.zone.h, ["segments_h"] = 30, ["color"] = WHITE, ["cath_w"] = 30, ["cath_h"] = 10 }

    lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + 10, string.format("%.1f V", wgt.vTotalLive), RIGHT + DBLSIZE + wgt.text_color)
    lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + 40, string.format("%2.0f %%", wgt.vPercent), RIGHT + DBLSIZE + wgt.text_color)
    
    local volts
    if wgt.cell_detected then
        -- cell count available
        volts = string.format("%.2f v (%.0fs)", wgt.vCellLive, wgt.cellCount);
    else
        -- cell count not available
        volts = string.format("%.2f v (?s)", wgt.vCellLive);
    end
    lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + wgt.zone.h - 38, volts, RIGHT + BOLD + wgt.text_color + wgt.no_telem_blink)

    if wgt.useSensorM then
        local mah = string.format("%.0f mah", wgt.vMah)
        lcd.drawText(wgt.zone.x + wgt.zone.w, wgt.zone.y + wgt.zone.h - 20, mah, RIGHT + BOLD + wgt.text_color + wgt.no_telem_blink)
    end

    drawBattery(wgt, myBatt)

end

--- Zone size: 390x172 1/1
--- Zone size: 460x252 1/1 (no sliders/trim/topbar)
local function refreshZoneXLarge(wgt)
    local x = wgt.zone.x
    local w = wgt.zone.w
    local y = wgt.zone.y
    local h = wgt.zone.h

    local myBatt = { ["x"] = 10, ["y"] = 0, ["w"] = 80, ["h"] = h, ["segments_h"] = 30, ["color"] = WHITE, ["cath_w"] = 30, ["cath_h"] = 10 }

    -- draw right text section
    --lcd.drawText(x + w, y + myBatt.y + 0, string.format("%2.2f V    %2.0f%%", wgt.mainValue, wgt.vPercent), RIGHT + XXLSIZE + wgt.text_color + wgt.no_telem_blink)
    --lcd.drawText(x + w, y + myBatt.y +  0, string.format("%2.2f V", wgt.mainValue), RIGHT + XXLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + 150, y + myBatt.y + 0, string.format("%2.2f V", wgt.mainValue), XXLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + 150, y + myBatt.y + 70, wgt.options.source_name, DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + w, y + myBatt.y + 80, string.format("%2.0f%%", wgt.vPercent), RIGHT + DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + w, y + h - 60, string.format("%2.2fV    %dS", wgt.secondaryValue, wgt.cellCount), RIGHT + DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + w, y + h - 30, string.format("min %2.2fV", wgt.vMin), RIGHT + DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    drawBattery(wgt, myBatt)
    return
end

--- Zone size: 460x252 - app mode (full screen)
local function refreshAppMode(wgt, event, touchState)
    if (touchState and touchState.tapCount == 2) or (event and event == EVT_VIRTUAL_EXIT) then
        lcd.exitFullScreen()
    end

    local x = 0
    local y = 0
    local w = LCD_W
    local h = LCD_H - 20

    local myBatt = { ["x"] = 10, ["y"] = 10, ["w"] = 90, ["h"] = h, ["segments_h"] = 30, ["color"] = WHITE, ["cath_w"] = 30, ["cath_h"] = 10 }

    if (event ~= nil) then
        log("event: " .. event)
    end

    -- draw right text section
    --lcd.drawText(x + w - 20, y + myBatt.y + 0, string.format("%2.2f V    %2.0f%%", wgt.mainValue, wgt.vPercent), RIGHT + XXLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + 180, y + 0, wgt.options.source_name, DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + 180, y + 30, string.format("%2.2f V", wgt.mainValue), XXLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + 180, y + 90, string.format("%2.0f %%", wgt.vPercent), XXLSIZE + wgt.text_color + wgt.no_telem_blink)

    lcd.drawText(x + w - 20, y + h - 90, string.format("%2.2fV", wgt.secondaryValue), RIGHT + DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + w - 20, y + h - 60, string.format("%dS", wgt.cellCount), RIGHT + DBLSIZE + wgt.text_color + wgt.no_telem_blink)
    lcd.drawText(x + w - 20, y + h - 30, string.format("min %2.2fV", wgt.vMin), RIGHT + DBLSIZE + wgt.text_color + wgt.no_telem_blink)

    drawBattery(wgt, myBatt)
    return
end

-- This function allow recording of lowest cells when widget is in background
local function background(wgt)
    if (wgt == nil) then return end

    wgt.tools.detectResetEvent(wgt, onTelemetryResetEvent)

    calculateBatteryData(wgt)

    -- voice alerts
    if wgt.isDataAvailable then
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

        local critical = wgt.vReserve == 0 and battCritical or 0

        -- silence routine bat% reports if not using sensorP
        if not wgt.useSensorP and battva > critical + battLowMargin then
            wgt.battPercentPlayed = battva
        end

        -- time to report?
        if (wgt.battPercentPlayed ~= battva or battva <= 0) and getTime() > wgt.battNextPlay then

            -- urgent?
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

    -- check if GV:4(Cel) cell count changed
    if wgt.options.Cells == 0 then
        local gvCel = model.getGlobalVariable(GV_CEL, 0)
        if gvCel ~= 0 and gvCel ~= wgt.cellCount then
            -- use new GV cell count
            wgt.cellCount = gvCel
            wgt.cell_detected = (gvCel ~= 0)
        end
    end
end

local function refresh(wgt, event, touchState)

    if (wgt == nil)         then return end
    if type(wgt) ~= "table" then return end
    if (wgt.options == nil) then return end
    if (wgt.zone == nil)    then return end
    --if (wgt.options.Show_Total_Voltage == nil) then return end

    background(wgt)

    if wgt.isDataAvailable then
        -- wgt.no_telem_blink = 0
        wgt.text_color = BLACK
        wgt.cell_color = BLACK
    else
        -- wgt.no_telem_blink = INVERS + BLINK
        wgt.text_color = COLOR_THEME_DISABLED
        wgt.cell_color = COLOR_THEME_DISABLED
    end

    if (event ~= nil) then
        refreshAppMode(wgt, event, touchState)
        return
    end

    -- if     wgt.zone.w > 380 and wgt.zone.h > 165 then refreshZoneXLarge(wgt)
    -- else
    if wgt.zone.w > 180 and wgt.zone.h > 145 then refreshZoneLarge(wgt)
    elseif wgt.zone.w > 170 and wgt.zone.h >  80 then refreshZoneMedium(wgt)
    elseif wgt.zone.w > 150 and wgt.zone.h >  28 then refreshZoneSmall(wgt)
    elseif wgt.zone.w >  65 and wgt.zone.h >  35 then refreshZoneTiny(wgt)
    end

end

return { name = app_name, options = _options, create = create, update = update, background = background, refresh = refresh }
