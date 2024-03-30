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
-- ver: 0.5.0

local app_name = "vThrottle"

local AUDIO_PATH = "/SOUNDS/en/"

local _options = {
    { "ThrottleSensor"    , SOURCE, 0 },
    { "FlightModeSensor"  , SOURCE, 0 },
    { "EscStatus"         , SOURCE, 0 },
    { "Status"            , BOOL, 1 },
    { "Voice"             , BOOL, 1 },
}

local defaultSensor = "RxBt" -- RxBt / A1 / A3/ VFAS / Batt

local LEVEL_INFO        = 1
local LEVEL_WARN        = 2
local LEVEL_ERROR       = 3

local escStatusColors = {
    [LEVEL_INFO]  = BLACK,
    [LEVEL_WARN]  = BOLD + SHADOWED + YELLOW,
    [LEVEL_ERROR] = BOLD + SHADOWED + RED,
}

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
        escstatus_color = 0,

        isDataAvailable = false,

        fmode = "",
        throttle = "",
        escstatus_text = nil,
        escstatus_level = LEVEL_INFO,

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

    if wgt.escstatus_text then
        _,vh = lcd.sizeText(wgt.escstatus_text, wgt.escstatus_color)
        lcd.drawText(cell.x + 6, cell.y + wgt.zone.h - vh - 8, wgt.escstatus_text, LEFT + wgt.escstatus_color)
    end
end

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

local escState = {
    [STATE_DISARMED]            = "OK",
    [STATE_POWER_CUT]           = "Shutdown",
    [STATE_FAST_START]          = "Bailout",
    [STATE_STARTING]            = "Starting",
    [STATE_WINDMILLING]         = "Idle",
    [STATE_RUNNING_NORM]        = "Running",
}

local escEvent = {
    [WARN_UNDERVOLTAGE]         = "Under Voltage",
    [WARN_OVERTEMP]             = "Over Temp",
    [WARN_OVERAMP]              = "Over Current",
}

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
-- wgt.isDataAvailable = true     -- <<== for testing only
-- fm = "Normal *"
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

        -- ESC statuc (YGE only ATM)
        if wgt.options.EscStatus then
            local scode = bit32.band(getValue(wgt.options.EscStatus), 0xFF)
            local escstatus_text
            local escstatus_level
            local dev = bit32.band(scode, WARN_DEVICE_MASK)
            if dev == WARN_SETPOINT_NOISE then
                -- special case
                escstatus_text = "ESC Setpoint Noise"
                escstatus_level = LEVEL_ERROR
            else
                -- device part
                if dev == WARN_DEVICE_BEC then
                    escstatus_text = "BEC "
                else
                    escstatus_text = "ESC "
                end

                -- state text
                local state = bit32.band(scode, STATE_MASK)
                local stateText = escState[state] or string.format("Code x%02X", state)

                -- event part
                local event = bit32.band(scode, EVENT_MASK)
                if event == WARN_OK then
                    -- special case
                    if state == STATE_POWER_CUT then
                        escstatus_text = escstatus_text.."Over Voltage"
                        escstatus_level = LEVEL_ERROR
                    else
                        escstatus_text = escstatus_text..stateText
                        escstatus_level = LEVEL_INFO
                    end
                else
                    -- event
                    escstatus_text = escstatus_text..(escEvent[event] or "** unexpected **")
                    if event == WARN_UNDERVOLTAGE then
                        escstatus_level = state < STATE_STARTING and LEVEL_ERROR or LEVEL_WARN
                    else
                        escstatus_level = state == STATE_POWER_CUT and  LEVEL_ERROR or LEVEL_WARN
                    end
                end
            end
            if escstatus_level >= wgt.escstatus_level then
                wgt.escstatus_text = (escstatus_level == LEVEL_ERROR) and string.upper(escstatus_text) or escstatus_text
                wgt.escstatus_level = escstatus_level
                wgt.escstatus_color = escStatusColors[escstatus_level]
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
        if wgt.escstatus_level == LEVEL_INFO then
            wgt.escstatus_color = GREY
        end
    end

    refreshZoneSmall(wgt)
end

return { name = app_name, options = _options, create = create, update = update, background = nil, refresh = refresh }
