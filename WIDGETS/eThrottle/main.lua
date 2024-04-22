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
-- ver: 0.5.9

local app_name = "eThrottle"

local AUDIO_PATH = "/SOUNDS/en/"

local _options = {
    { "ThrottleSensor"    , SOURCE, 0 },
    { "FlightModeSensor"  , SOURCE, 0 },
    { "EscStatus"         , SOURCE, 0 },
    { "Status"            , BOOL, 1 },
    { "Voice"             , BOOL, 1 },
}

local LEVEL_TRACE       = 0
local LEVEL_INFO        = 1
local LEVEL_WARN        = 2
local LEVEL_ERROR       = 3

local escStatusColors = {
    [LEVEL_TRACE] = GREY,
    [LEVEL_INFO]  = BLACK,
    [LEVEL_WARN]  = BOLD + SHADOWED + YELLOW,
    [LEVEL_ERROR] = BOLD + SHADOWED + RED,
}

--------------------------------------------------------------

local function log(s)
    print("vThrottle: " .. s)
end

--------------------------------------------------------------

local LIST_SIZE = 10
local LOG_MAX = 128
local YGE_SPN_IGNORE_MAX = 32

local escstatus_text = nil
local escstatus_level = LEVEL_INFO

local log = {}
local events = 0
local ygeSpnEvents = 0
local bootEpoch = getDateTime()
local bootTime = getTime()

--------------------------------------------------------------
-- YGE status

local STATE_MASK                = 0x0F      -- status bit mask
local STATE_DISARMED            = 0x00      -- Motor stopped
local STATE_POWER_CUT           = 0x01      -- Power cut maybe Overvoltage
local STATE_FAST_START          = 0x02      -- "Bailout" State
local STATE_STARTING            = 0x08      -- "Starting"
local STATE_WINDMILLING         = 0x0C      -- still rotating no power drive can be named "Idle"
local STATE_RUNNING_NORM        = 0x0E      -- normal "Running"

local EVENT_MASK                = 0x70      -- event bit mask
local WARN_DEVICE_MASK          = 0xC0      -- device ID bit mask (note WARN_SETPOINT_NOISE = 0xC0)
local WARN_DEVICE_ESC           = 0x00      -- warning indicators are for ESC
local WARN_DEVICE_BEC           = 0x80      -- warning indicators are for BEC
local WARN_OK                   = 0x00      -- Overvoltage if Motor Status == STATE_POWER_CUT
local WARN_UNDERVOLTAGE         = 0x10      -- Fail if Motor Status < STATE_STARTING
local WARN_OVERTEMP             = 0x20      -- Fail if Motor Status == STATE_POWER_CUT
local WARN_OVERAMP              = 0x40      -- Fail if Motor Status == STATE_POWER_CUT
local WARN_SETPOINT_NOISE       = 0xC0      -- note this is special case (can never have OVERAMP w/ BEC hence reuse)

local ygeState = {
    [STATE_DISARMED]            = "OK",
    [STATE_POWER_CUT]           = "Shutdown",
    [STATE_FAST_START]          = "Bailout",
    [STATE_STARTING]            = "Starting",
    [STATE_WINDMILLING]         = "Idle",
    [STATE_RUNNING_NORM]        = "Running",
}

local ygeEvent = {
    [WARN_UNDERVOLTAGE]         = "Under Voltage",
    [WARN_OVERTEMP]             = "Over Temp",
    [WARN_OVERAMP]              = "Current Limit",
}

local function ygeGetStatus(code, changed)
    local text, level
    local scode = bit32.band(code, 0xFF)
    local dev = bit32.band(scode, WARN_DEVICE_MASK)
    local state = bit32.band(scode, STATE_MASK)
    if dev == WARN_SETPOINT_NOISE then
        -- special case
        text = "ESC Setpoint Noise"
        if changed then
            ygeSpnEvents = ygeSpnEvents + 1
        end
        level = (state == STATE_POWER_CUT and LEVEL_ERROR) or 
                (ygeSpnEvents < YGE_SPN_IGNORE_MAX and LEVEL_TRACE) or 
                LEVEL_WARN
    else
        -- device part
        if dev == WARN_DEVICE_BEC then
            text = "BEC "
        else
            text = "ESC "
        end

        -- state text
        local stateText = ygeState[state] or string.format("Code x%02X", state)

        -- event part
        local event = bit32.band(scode, EVENT_MASK)
        if event == WARN_OK then
            -- special case
            if state == STATE_POWER_CUT then
                text = text.."Over Voltage"
                level = LEVEL_ERROR
            else
                text = text..stateText
                level = LEVEL_INFO
            end
        else
            -- event
            text = text..(ygeEvent[event] or "** unexpected **")
            if event == WARN_UNDERVOLTAGE then
                level = state < STATE_STARTING and LEVEL_ERROR or LEVEL_WARN
            else
                level = state == STATE_POWER_CUT and LEVEL_ERROR or LEVEL_WARN
            end
        end
    end
    text = (level == LEVEL_ERROR) and string.upper(text) or text
    return { text = text, level = level }
end

local function ygeResetStatus()
    escstatus_text = nil
    escstatus_level = LEVEL_INFO

    log = {}
    events = 0
    ygeSpnEvents = 0
end

--------------------------------------------------------------


local function update(wgt, options)
    if (wgt == nil) then
        return
    end

    wgt.options = options

    wgt.fmode = ""
    wgt.throttle = ""
    wgt.escGetStatus = ygeGetStatus
    wgt.escResetStatus = ygeResetStatus
end

local function create(zone, options)
    local wgt = {
        zone = zone,
        options = options,

        text_color = 0,
        escstatus_color = 0,

        isDataAvailable = false,

        fmode = "",
        throttle = "",
        escGetStatus = nil,

        connected = false,
        armed = false,

        epoch = (bootEpoch.hour * 3600 + bootEpoch.min * 60 + bootEpoch.sec) * 10
    }

    -- imports
    wgt.libGUI = loadGUI()
    wgt.gui = wgt.libGUI.newGUI()
    wgt.vslider = nil

    update(wgt, options)
    return wgt
end

-- audio support
local function playAudio(f)
    playFile(AUDIO_PATH .. f .. ".wav")
end

-- get log event
local function logGetEv(idx)
    if idx <= events - LOG_MAX then
        return nil
    end
    return log[((idx - 1) % LOG_MAX) + 1]
end

-- log status change, return true if new event logged
local function logPutEv(wgt, scode)
    if events > 0 and bit32.band(logGetEv(events), 0xFF) == bit32.band(scode, 0xFF) then
        return false
    end

    local t, _ = math.modf((getTime() - bootTime) / 10)
    local ev = bit32.bor(bit32.lshift(t, 16), bit32.band(scode, 0xFF))
    log[(events % LOG_MAX) + 1] = ev
    events = events + 1
    return true
end

-- format log time
local function getEvTime(wgt, evt)
    local t = wgt.epoch + evt
    local dsec = t % 10
    t = math.floor(t / 10)

    local sec = t % 60
    t = math.floor(t / 60)
 
    local min = t % 60
    t = math.floor(t / 60)

    return { hour = t, min = min, sec = sec, dsec = dsec }
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

    if escstatus_text then
        _,vh = lcd.sizeText(escstatus_text, wgt.escstatus_color)
        lcd.drawText(cell.x + 6, cell.y + wgt.zone.h - vh - 8, escstatus_text, LEFT + wgt.escstatus_color)
    end
end

--- Zone size: 460x252 - app mode (full screen)
local function refreshAppMode(wgt, event, touchState)
    if event and event == EVT_VIRTUAL_EXIT then
        lcd.exitFullScreen()
        return
    end

    local cell = { ["x"] = 0, ["y"] = 0, ["w"] = LCD_W, ["h"] = LCD_H }
    local list_y = 40

    local scroll = 1
    if events > LIST_SIZE then
        local max = #log - LIST_SIZE + 1
        if not wgt.vslider then
            -- create scrollbar
            local mvy = 20
            wgt.vslider = wgt.gui.verticalSlider(cell.w - 32, list_y + mvy, cell.h - list_y - 2 * mvy, max, 1, max, 1, nil)
        else
            -- update scrollbar max
            scroll = wgt.vslider.max -  wgt.vslider.value + 1
            wgt.vslider.max = max
            wgt.vslider.value = wgt.vslider.max - scroll + 1
        end
    end

    local mx = 8
    local y = 12
    lcd.drawFilledRectangle(cell.x, cell.y, cell.w, 40, COLOR_THEME_SECONDARY1)
    lcd.drawText(cell.x + mx, y, string.format("%d ESC message%s", events, events == 1 and "" or "s"), COLOR_THEME_PRIMARY2 + BOLD)

    mx = mx + 4
    y = list_y
    lcd.drawRectangle(cell.x, y, cell.w, cell.h, BLACK, 1)

    y = y + 10
    for i = 1, math.min(#log, LIST_SIZE) do
        local ev = logGetEv(events - (i - 1) - (scroll - 1))
        local evt = getEvTime(wgt, bit32.rshift(ev, 16))
        local time = string.format("%02d:%02d:%02d.%01d ", evt.hour, evt.min, evt.sec, evt.dsec)
        lcd.drawText(cell.x + mx, y, time, BLACK)
        local dx,dy = lcd.sizeText(time, BLACK)

        local status = wgt.escGetStatus(bit32.band(ev, 0x00FF), false)
        local color = escStatusColors[status.level]
        lcd.drawText(cell.x + mx + dx, y, status.text, bit32.bor(color, BOLD))
        y = y + dy
    end

    if wgt.vslider then
        wgt.gui.run(event, touchState)
    end
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
-- wgt.isDataAvailable = getValue(wgt.options.ThrottleSensor) == 40     -- <<== for testing only
-- fm = "Normal *"
    end

    -- connected?
    if wgt.isDataAvailable then
        -- connected
        if not wgt.connected then
            -- reset status / log
            wgt.escResetStatus()
            wgt.connected = true
        end

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

        -- ESC statuc (YGE only ATM)
        if wgt.options.EscStatus ~=0 then
            local scode = getValue(wgt.options.EscStatus)
            local changed = logPutEv(wgt, scode)
            local status = wgt.escGetStatus(scode, changed)
            if status.level >= escstatus_level then
                escstatus_text = status.text
                escstatus_level = status.level
                wgt.escstatus_color = escStatusColors[status.level]
            end
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
        wgt.connected = false

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
    else
        wgt.text_color = COLOR_THEME_DISABLED
        if escstatus_level == LEVEL_INFO then
            wgt.escstatus_color = COLOR_THEME_DISABLED
        end
    end


    if (event ~= nil) then
        refreshAppMode(wgt, event, touchState)
    else
        refreshZoneSmall(wgt)
    end
end

return { name = app_name, options = _options, create = create, update = update, background = background, refresh = refresh }
