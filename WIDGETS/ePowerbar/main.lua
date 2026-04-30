--[[
#########################################################################
#                                                                       #
# Telemetry Widget script for FrSky Horus/RadioMaster TX16s             #
# Copyright "Rob 'bob00' Gayle"                                         #
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
-- Based on  Lipo battery from single analog source by Offer Shmuely
-- Author: Rob Gayle (bob00@rogers.com)
-- Date: 2026
-- ver: 0.9.0.04290

local app_name = "ePowerbar"

local AUDIO_PATH = "/SOUNDS/en/"

local ALERTLEVEL_NONE       = 0
local ALERTLEVEL_LOW        = 1
local ALERTLEVEL_CRITICAL   = 2

local BAR_COLOR_OK          = lcd.RGB(0x00, 0xff, 0x00)
local BAR_COLOR_WARN        = lcd.RGB(0xf8, 0xc0, 0x00) -- lcd.RGB(0xff, 0xff, 0)
local BAR_COLOR_LOW         = lcd.RGB(0xff, 0xff, 0x00)
local BAR_COLOR_CRITICAL    = lcd.RGB(0xff, 0x00, 0x00)
local BAR_COLOR_CHECK       = lcd.RGB(0xb8, 0xb8, 0xb8)
local BAR_COLOR_BACKGROUND  = lcd.RGB(0xc8, 0xc8, 0xc8)
local BAR_COLOR_LINE        = lcd.RGB(160, 160, 160)

local STARTUP_DELAY_DEFAULT = 400
local VOLTTIMER_DISABLED = -1

local defaultVoltSensor = CHAR_TELEMETRY.."Vbat"
local defaultPcntSensor = CHAR_TELEMETRY.."Bat%"
local defaultMahSensor = CHAR_TELEMETRY.."Capa"
local defaultCellSensor = CHAR_TELEMETRY.."Cel#"

local _options = {
    { "VoltSensor"            , SOURCE, getSourceIndex(defaultVoltSensor) },
    { "mAhSensor"             , SOURCE, getSourceIndex(defaultMahSensor) },
    { "FuelSensor"            , SOURCE, getSourceIndex(defaultPcntSensor) },
    { "LipoCapacity"          , VALUE, 0, 0, 24000 },
    { "CellSensor"            , SOURCE, getSourceIndex(defaultCellSensor) },
    { "Cells"                 , VALUE, 0, 0, 16 },    -- cell detection time (or interval if calc perceentage)
    { "Reserve"               , VALUE, 20, 0, 40 },   -- reserve
    { "Mute"                  , CHOICE, 1 , { "None", "Voltage alerts", "Voltage and fuel alerts" } },
    { "Vibrate"               , BOOL, 1 },
    { "Alerts"                , SOURCE, 0 },
    { "CellFull"              , VALUE, 412, 0, 480 },
    { "CellLow"               , VALUE, 345, 0, 440 },
    { "CellCritical"          , VALUE, 330, 0, 440 },
    { "StartupDelay"          , VALUE, STARTUP_DELAY_DEFAULT / 100, 1, 20 },
}

local function translate(text)
    local translations = {
        VoltSensor      = "Voltage (v) sensor",
        mAhSensor       = "Consumption (mAh) sensor",
        FuelSensor      = "Fuel (%) sensor",
        LipoCapacity    = "  ...or lipo capacity (mAh)",
        CellSensor      = "Cell count sensor",
        Cells           = "  ...or cell count",
        Reserve         = "Reserve capacity (%)",
        Mute            = "Mute (voice and vibration)",
        Vibrate         = "Vibrate on critical alerts",
        Alerts          = "Voltage alert switch",
        CellFull        = "Full cell voltage (cv)",
        CellLow         = "Low cell voltage (cv)",
        CellCritical    = "Critical cell voltage (cv)",
        StartupDelay    = "Startup delay (s)",
    }
    return translations[text]
end

--------------------------------------------------------------
local function log(s)
    -- print("BattAnalog: " .. s)
end
--------------------------------------------------------------

local function getSensorFieldInfo(widget, name)
    local fi = getFieldInfo(name)
    if fi == nil then
        widget.common.log("Required sensor '"..name.."' missing")
    end
    return fi
end

local function update(widget, options)
    if (widget == nil) then
        return
    end

    widget.options = options

    widget.vReserve = widget.options.Reserve

    -- reload common libraries
    local commonClass = loadScript("/WIDGETS/eLib/lib_common.lua", "tcd")
    widget.common = commonClass(app_name)

    local fi = getSensorFieldInfo(widget, widget.options.VoltSensor)
    widget.sensorVoltId = fi and fi.id or 0

    fi = getSensorFieldInfo(widget, widget.options.mAhSensor)
    widget.sensorMahId = fi and fi.id or 0

    fi = getSensorFieldInfo(widget, widget.options.FuelSensor)
    widget.sensorPcntId = fi and fi.id or 0

    fi = getSensorFieldInfo(widget, widget.options.CellSensor)
    widget.sensorCellsId = fi and fi.id or 0

    fi = getSensorFieldInfo(widget, widget.options.Alerts)
    widget.sourceAlertsId = fi and fi.id or 0

    widget.alertCellCitical = widget.options.CellCritical
    widget.alertCellLow = widget.options.CellLow

    widget.startupDelay = widget.options.StartupDelay and widget.options.StartupDelay > 0 and widget.options.StartupDelay * 100 or STARTUP_DELAY_DEFAULT

    -- trigger retest
    widget.cellCount = nil
end

local function create(zone, options)
    local widget = {
        zone = zone,
        options = options,
        counter = 0,

        text_color = 0,
        cell_color = 0,
        border_l = 5,
        border_r = 10,
        border_t = 0,
        border_b = 10,

        active = false,
        fuel = 0,
        vReserve = 20,
        vLow = 10,
        mah = 0,
        cellCount = nil,
        barColor = BAR_COLOR_OK,
        voltTimer = VOLTTIMER_DISABLED,
        cellFullCheckProgress = 0,
        startupDelay = STARTUP_DELAY_DEFAULT,

        -- alerts
        alertPending = 0,
        alertSampleDuration = 50,
        alertLevel = ALERTLEVEL_NONE,
        alertNext = 0,
        alertRepeatInterval = 500,

        cellv = 0,
        volts = 0,

        -- audio state
        lastCapa = 100,
        nextCapa = 0,

        -- methods
        getCritical = function (widget)
            return widget.vReserve > 0 and 0 or 20
        end,

        getCellFull = function (widget)
            return widget.options.CellFull > 0 and (widget.options.CellFull / 100) or 0
        end,
    }

    update(widget, options)
    return widget
end

-- audio support
local function playAudio(file)
    playFile(AUDIO_PATH .. file .. ".wav")
end

local function playVibe(widget)
    if widget.options.Vibrate == 1 then
        playHaptic(100, 0, PLAY_NOW)
    end
end

-- color for gauge
local function getBarColor(widget)
    local critical = widget:getCritical()
    if widget.voltTimer ~= VOLTTIMER_DISABLED then
        -- in cell check
        return BAR_COLOR_CHECK
    elseif widget.fuel <= critical then
        -- red
        return BAR_COLOR_CRITICAL
    elseif widget.fuel <= critical + 20 then
        -- yellow
        return BAR_COLOR_LOW
    else
        -- green
        return widget.barColor
    end
end

--- paint
local function paint(widget)
    local cx, cy, cw, ch = 4, 4, widget.zone.w - 8, widget.zone.h - 8
    local mx, my = 8, 6

    -- background
    local color = BAR_COLOR_BACKGROUND
    lcd.drawFilledRectangle(cx, cy, cw, ch, color)

    -- bar
    if widget.fuel and widget.volts and widget.volts > 0 then
        local fill
        if widget.voltTimer == VOLTTIMER_DISABLED then
            fill = widget.fuel > 0 and widget.fuel <= 100 and widget.fuel or 100
        else
            fill = widget.cellFullCheckProgress < 100 and widget.cellFullCheckProgress or 100
        end

        local bar_width = math.floor((((cw - 2) / 100) * fill) + 2)
        color = getBarColor(widget)
        lcd.drawFilledRectangle(cx, cy, bar_width, ch, color)

        color = BAR_COLOR_LINE
        lcd.drawLine(cx + bar_width, cy, cx + bar_width, cy + ch, SOLID, color)
    end

    -- outline
    lcd.drawRectangle(cx, cy, cw + 1, ch, widget.text_color)

    -- bar
    local volts
    if widget.cellCount and widget.cellCount > 0 then
        -- cell count available
        volts = string.format("%.1f v / %.2f v (%.0fs)", widget.volts, widget.cellv, widget.cellCount);
    else
        -- cell count not available
        volts = string.format("%.1f v / %.2f v (?s)", widget.volts, widget.cellv);
    end
    lcd.drawText(cx + mx, cy + my, volts, BOLD + LEFT  + widget.text_color)

    if widget.sensorMahId ~= 0 then
        local mah = string.format("%.0f mah", widget.mah)
        local textFlags = BOLD + widget.text_color
        local _, th = lcd.sizeText(mah, textFlags)
        lcd.drawText(cx + mx, cy + ch - th - my, mah, LEFT  + textFlags)
    end

    local percent = widget.voltTimer == VOLTTIMER_DISABLED and widget.volts ~= 0 and string.format("%.0f%%", widget.fuel) or "-- "
    lcd.drawText(cx + cw - 4, cy + ch / 2, percent, BOLD + VCENTER + RIGHT + MIDSIZE + widget.text_color)
end

local function cellsFromVolts(widget, volts)
    -- for 1 to 4 and 6 cells only
    for cells = 1, 6 do
        if cells ~= 5 then
            -- skip 5 cell
            if volts >= 3.3 * cells and volts <= 4.35 * cells then
                -- likely cell count
                return cells
            end
        end
    end
    -- unknown
    return 0
end

--- battery calcs
local function calculateBatteryData(widget)
    -- cells
    local cells = 0
    if widget.sensorCellsId ~= 0 then
        -- use sensor cell count
        cells = getValue(widget.sensorCellsId)
    elseif widget.options.Cells > 0 then
        -- use configured cell count
        cells = widget.options.Cells
    elseif widget.options.Cells == 0 then
        -- try to figure out from voltage
        local volts = getValue(widget.sensorVoltId)
        cells = cellsFromVolts(widget, volts)
    end
    if widget.cellCount ~= cells then
        widget.cellCount = cells
        _G.ePowerbarCellCount = cells
    end
    local vdiv = widget.cellCount and widget.cellCount > 0 and widget.cellCount or 1

    -- voltage
    local cellFull = widget:getCellFull()
    local volts = widget.cellCount and widget.cellCount > 0 and getValue(widget.sensorVoltId) or 0
    if volts and volts ~= widget.volts then
        -- arm cell check if full check enabled and voltage appearing or moving away from 0
        if cellFull > 0 and volts > 0 and (widget.volts == nil or widget.volts == 0) then
            widget.voltTimer = getTime() + widget.startupDelay
            widget.cellFullCheckProgress = 0
        end

        widget.cellv = volts / vdiv
        widget.volts = volts
    end

    -- check for initial voltage check
    local now = getTime()
    if widget.voltTimer ~= VOLTTIMER_DISABLED then
        if widget.voltTimer < now then
            widget.voltTimer = VOLTTIMER_DISABLED

            -- warn if battery low or cell count unknown
            if widget.cellCount == 0 then
                -- cell count unknown
                widget.barColor = BAR_COLOR_CHECK
            elseif (volts / vdiv) >= cellFull then
                -- ok
                widget.barColor = BAR_COLOR_OK
            else
                -- warn
                playAudio("batlow")
                playNumber(volts * 10, 1, PREC1)
                widget.barColor = BAR_COLOR_WARN
            end
        else
            local progress = 100 - ((widget.voltTimer - now) * 100 / widget.startupDelay)
            if widget.cellFullCheckProgress ~= progress then
                widget.cellFullCheckProgress = progress
            end
        end
    end

    -- mah
    if widget.sensorMahId ~= 0 then
        widget.mah = getValue(widget.sensorMahId)
    end

    -- fuel
    local fuel = nil
    if widget.sensorPcntId ~= 0 then
        -- use sensor
        fuel = getValue(widget.sensorPcntId)
    else
        local capacity = widget.options.LipoCapacity
        if widget.mah and capacity > 0 then
            -- calculate using capacity
            fuel = (capacity - widget.mah) * 100 / capacity
        end
    end

    if fuel then
        if fuel < widget.vReserve then
            widget.fuel = fuel - widget.vReserve
        else
            local usable = 100 - widget.vReserve
            widget.fuel = (fuel - widget.vReserve) / usable * 100
        end
    end
end

-- call fuel consumption on the 10's (singles when critical)
local function crankFuelCalls(widget)
    -- bail if muted
    if widget.options.Mute > 2 then
        return
    end

    -- voice alerts
    local fuel = widget.fuel

    local critical = widget:getCritical()

    -- what do we have to report?
    local capa = 0
    if fuel > critical + widget.vLow then
        capa = math.ceil(fuel / 10) * 10
    else
        capa = fuel
    end

    -- time to report?
    if (widget.lastCapa ~= capa or capa <= 0) and getTime() > widget.nextCapa then
        -- skip initial report
        if widget.nextCapa ~= 0 then
            -- urgent?
            if capa > critical + widget.vLow then
                playAudio("battry")
            elseif capa > critical then
                playAudio("batlow")
            else
                playAudio("batcrt")
                playVibe(widget)
            end

            -- play % if >= 0
            if capa >= 0 then
                playNumber(capa, UNIT_PERCENT)
            end
        end

        -- schedule next
        widget.lastCapa = capa
        widget.nextCapa = getTime() + 500
    end
end

local function crankVoltageAlerts(widget)
    -- bail if muted
    if widget.options.Mute > 1 then
        return
    end

    -- bail if not in alert condition
    if getValue(widget.sourceAlertsId) <= 0 then
        return
    end

    -- bail if in delay
    local now = getTime()
    if now < widget.alertNext then
        return
    end
    
    -- we will be working w/ per cell voltage (x100 for 2 place decimal prec)
    local prec = 100
    local cellv = math.floor(widget.cellv * prec)

    local alertLevel = (cellv <= widget.alertCellCitical and ALERTLEVEL_CRITICAL) or (cellv <= widget.alertCellLow and ALERTLEVEL_LOW) or ALERTLEVEL_NONE

    if widget.alertPending ~= 0 then
        -- in alert state
        if alertLevel == ALERTLEVEL_NONE then
            -- exit alert state alert condition cleared while pending
            widget.alertPending = 0
            return
        elseif alertLevel < widget.alertLevel then
            -- reduce alert level if less critical level seen while pending
            widget.alertLevel = alertLevel
        end

        -- trigger if delay elapsed
        if now >= widget.alertPending then
            -- alert
            local locale = "en"
            local haptic = false
            if alertLevel == ALERTLEVEL_LOW then
                playAudio("batlow")
            elseif alertLevel == ALERTLEVEL_CRITICAL then
                playAudio("batcrt")
                haptic = true
            end
            -- report total voltage until https://github.com/FrSkyRC/ETHOS-Feedback-Community/issues/3491
            -- (was https://github.com/FrSkyRC/ETHOS-Feedback-Community/issues/4708)
            playNumber(widget.volts * 10, UNIT_VOLTS, PREC1)

            if haptic then
                playVibe(widget)
            end

            -- start delay
            widget.alertNext = now + widget.alertRepeatInterval

            -- exit alert state
            widget.alertPending = 0
            return
        end
    elseif alertLevel > ALERTLEVEL_NONE then
        -- enter alert state
        widget.alertLevel = alertLevel
        widget.alertPending = now + widget.alertSampleDuration
    end
end

-- process sensors, pre-render and announce
local function background(widget)
    if (widget == nil) then
        return
    end

    -- assume no telemetry if required sensors missing
    if widget.sensorVoltId == 0 then
        widget.active = false
    else
        local active = widget.common.isTelemetryActive()
        if active ~= widget.active then
            widget.active = active

            if active then
                -- skip initial report
                widget.nextCapa = 0
                -- restart voltage check timer on telemetry connection
                widget.voltTimer = getTime() + widget.startupDelay
            end
        end
    end

    -- bail if no telemetry
    if not widget.active then
        return
    end

    calculateBatteryData(widget)

    -- quiet if mute or during startup delay
    if widget.voltTimer == VOLTTIMER_DISABLED then
        -- fuel calls
        crankFuelCalls(widget)

        -- low/critical voltage alerts
        crankVoltageAlerts(widget)
    end
end

local function refresh(widget, event, touchState)
    if (widget == nil)         then return end
    if type(widget) ~= "table" then return end
    if (widget.options == nil) then return end
    if (widget.zone == nil)    then return end

    background(widget)

    if widget.active then
        widget.text_color = BLACK
        widget.cell_color = BLACK
    else
        widget.text_color = COLOR_THEME_DISABLED
        widget.cell_color = COLOR_THEME_DISABLED
    end

    paint(widget)

    if (event ~= nil) then
        if (touchState and touchState.tapCount == 2) or (event and event == EVT_VIRTUAL_EXIT) then
            lcd.exitFullScreen()
        end
    end
end

return { name = app_name, options = _options, create = create, update = update, background = background, refresh = refresh, translate = translate }
