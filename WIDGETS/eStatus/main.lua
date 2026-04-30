--[[
#########################################################################
#                                                                       #
# License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               #
# Copyright "Rob 'bob00' Gayle"                                         #
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
-- Date: 2026
-- ver: 0.9.0.03250

local app_name = "eStatus"

local AUDIO_PATH = "/SOUNDS/en/"

local _options = {
    { "ArmFlags"              , SOURCE, getSourceIndex(CHAR_TELEMETRY.."ARM") },
    { "ArmDisable"            , SOURCE, getSourceIndex(CHAR_TELEMETRY.."ARMD") },
    { "GovFlags"              , SOURCE, getSourceIndex(CHAR_TELEMETRY.."Gov") },
    { "Throttle"              , SOURCE, getSourceIndex(CHAR_TELEMETRY.."Thr") },
    { "EscModel"              , SOURCE, getSourceIndex(CHAR_TELEMETRY.."Esc#") },
    { "EscStatus"             , SOURCE, getSourceIndex(CHAR_TELEMETRY.."EscF") },
    { "Mute"                  , BOOL, 0 },

    { "Color"                 , COLOR, COLOR_THEME_PRIMARY1 },
}

local function translate(text)
    local translations = {
        ArmFlags    = "Arming flags",
        ArmDisable  = "Arming disable flags",
        GovFlags    = "Governor state",
        Throttle    = "ESC or GOV throttle",
        EscModel    = "ESC model ID",
        EscStatus   = "ESC status",
        Mute        = "Mute (voice and vibration)",
        Color       = "Text color",
    }
    return translations[text]
end

local FM_MODE_FM        = 0
local FM_MODE_GOV       = 1

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
local escGetStatus = nil
local escResetStatus = nil

local log = {}
local events = 0
local ygeSpnEvents = 0
local bootEpoch = getDateTime()
local bootTime = getTime()

--------------------------------------------------------------
-- ESC signatures

local ESC_SIG_NONE              = 0x00
local ESC_SIG_BLHELI32          = 0xC8
local ESC_SIG_HW4               = 0x9B
local ESC_SIG_KON               = 0x4B
local ESC_SIG_OMP               = 0xD0
local ESC_SIG_ZTW               = 0xDD
local ESC_SIG_APD               = 0xA0
local ESC_SIG_PL5               = 0xFD
local ESC_SIG_TRIB              = 0x53
local ESC_SIG_OPENYGE           = 0xA5
local ESC_SIG_FLY               = 0x73
local ESC_SIG_RESTART           = 0xFF

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
    if scode == 0 then
        text = "YGE ESC OK"
        level = LEVEL_INFO
    elseif dev == WARN_SETPOINT_NOISE then
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
-- Scorpion status


-- * Scorpion Telemetry
-- *    - Serial protocol is 38400,8N1
-- *    - Frame rate running:10Hz idle:1Hz
-- *    - Little-Endian fields
-- *    - CRC16-CCITT
-- *    - Error Code bits:
-- *         0:  N/A
-- *         1:  BEC voltage error
-- *         2:  Temperature error
-- *         3:  Consumption error
-- *         4:  Input voltage error
-- *         5:  Current error
-- *         6:  N/A
-- *         7:  Throttle error

 local function tribGetStatus(code, changed)
    local text = "Scorpion ESC OK"
    local level = LEVEL_INFO
    -- just report highest order bit
    for bit = 0, 7 do
        if bit32.band(code, bit32.lshift(1, bit)) ~= 0 then
            local fault = nil
            if bit == 1 then
                fault = "BEC Voltage"
            elseif bit == 2 then
                fault = "ESC Temperature"
            elseif bit == 3 then
                fault = "ESC Consumption"
            elseif bit == 4 then
                fault = "ESC Voltage"
            elseif bit == 5 then
                fault = "ESC Current"
            -- elseif bit == 7 then
            --     fault = "ESC Throttle Error"
            end
            if fault then
                text = fault
                level = LEVEL_ERROR
            end
        end
    end
    return { text = text, level = level }
end

--------------------------------------------------------------
-- HW5 status

-- *    - Fault code bits:
-- *         0:  Motor locked protection
-- *         1:  Over-temp protection
-- *         2:  Input throttle error at startup
-- *         3:  Throttle signal lost
-- *         4:  Over-current error
-- *         5:  Low-voltage error
-- *         6:  Input-voltage error
-- *         7:  Motor connection error

local function pl5GetStatus(code, changed)
   local text = "HobbyWing ESC OK"
   local level = LEVEL_INFO
   -- just report highest order bit
   for bit = 0, 7 do
       if bit32.band(code, bit32.lshift(1, bit)) ~= 0 then
           local fault = nil
           if bit == 0 then
               fault = "ESC Motor Locked"
            elseif bit == 1 then
                fault = "ESC Over Temp"
            elseif bit == 2 then
                fault = "ESC Throttle Error"
            elseif bit == 3 then
                fault = "ESC Throttle Signal"
            elseif bit == 4 then
                fault = "ESC Over Current"
            elseif bit == 5 then
                fault = "ESC Low Voltage"
            elseif bit == 6 then
                fault = "ESC Input Voltage"
            elseif bit == 7 then
                fault = "ESC Motor Connection"
            end
            if fault then
                text = fault
                level = LEVEL_ERROR
            end
       end
   end
   return { text = text, level = level }
end

--------------------------------------------------------------
-- FLY telemetry

-- * FLYROTOR status
-- *    0x80 Fan Status 
-- *    0x40 Reserved 
-- *    0x20 Reserved 
-- *    0x10 Throttle Signal 
-- *    0x08 Short Circuit Protection 
-- *    0x04 Overcurrent Protection 
-- *    0x02 Low Voltage Protection 
-- *    0x01 Temperature Protection

local function flyGetStatus(code, changed)
   local text = "FLYROTOR ESC OK"
   local level = LEVEL_INFO
   -- just report highest order bit (most severe)
--    if code ~= 0 then
--         text = string.format("code (%02X)", code)
--         level = LEVEL_WARN
--    end
   for bit = 0, 7 do
       if (code & (1 << bit)) ~= 0 then
            if bit == 0 then
                text = "ESC Over Temp"
                level = LEVEL_ERROR
                break
            elseif bit == 1 then
                text = "ESC Low Voltage"
                level = LEVEL_ERROR
                break
            elseif bit == 2 then
                text = "ESC Overcurrent"
                level = LEVEL_ERROR
                break
            elseif bit == 3 then
                text = "ESC Short Circuit"
                level = LEVEL_ERROR
                break
            elseif bit == 4 then
                text = "ESC Throttle Signal"
                level = LEVEL_WARN
                break
            elseif bit == 7 then
                text = "ESC Fan Status"
                level = LEVEL_INFO
                break
            end
       end
   end
   return { text = text, level = level }
end

--------------------------------------------------------------
-- OMP telemetry

-- * Status Code bits:
-- *    0:  Short-circuit protection
-- *    1:  Motor connection error
-- *    2:  Throttle signal lost
-- *    3:  Throttle signal >0 on startup error
-- *    4:  Low voltage protection
-- *    5:  Temperature protection
-- *    6:  Startup protection
-- *    7:  Current protection
-- *    8:  Throttle signal error
-- *   12:  Battery voltage error

local function ompGetStatus(code, changed)
   local text = "OMP ESC OK"
   local level = LEVEL_INFO
   -- just report highest order bit (most severe)
--    if code ~= 0 then
--         text = string.format("code (%02X)", code)
--         level = LEVEL_WARN
--    end
   for bit = 0, 12 do
       if (code & (1 << bit)) ~= 0 then
            if bit == 0 then
                text = "ESC Short Circuit"
                level = LEVEL_ERROR
                break
            elseif bit == 1 then
                text = "ESC Motor Connection"
                level = LEVEL_ERROR
                break
            elseif bit == 2 then
                text = "ESC Throttle Lost"
                level = LEVEL_WARN
                break
            elseif bit == 3 then
                text = "ESC Throttle Startup"
                level = LEVEL_ERROR
                break
            elseif bit == 4 then
                text = "ESC Low Voltage"
                level = LEVEL_ERROR
                break
            elseif bit == 5 then
                text = "ESC Over Temp"
                level = LEVEL_ERROR
                break
            elseif bit == 6 then
                text = "ESC Startup"
                level = LEVEL_ERROR
                break
            elseif bit == 7 then
                text = "ESC Overcurrent"
                level = LEVEL_ERROR
                break
            elseif bit == 8 then
                text = "ESC Throttle Signal"
                level = LEVEL_WARN
                break
            elseif bit == 12 then
                text = "ESC Battery Voltage"
                level = LEVEL_ERROR
                break
            end
       end
   end
   return { text = text, level = level }
end

--------------------------------------------------------------
-- BLHeli_32 telemetry

local function blheli32GetStatus(code, changed)
   local text = "BLHeli_32 ESC OK"
   local level = LEVEL_INFO

    if code ~= 0 then
        text = string.format("ESC status code (%04X)", code)
    end

   return { text = text, level = level }
end

--------------------------------------------------------------
-- unknown ESC

local function unkGetStatus(code, changed)
    local text = escstatus_text
    local level = LEVEL_INFO

    if code ~= 0 then
        text = string.format("ESC status code (%04X)", code)
    end

    return { text = text, level = level }
 end

--------------------------------------------------------------

local function resetStatus()
   escstatus_text = nil
   escstatus_level = LEVEL_INFO

   log = {}
   events = 0
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

    widget.fmode = ""
    widget.throttle = ""

    escStatusColors[LEVEL_INFO] = widget.options.Color

    -- reload common libraries
    local commonClass = loadScript("/WIDGETS/eLib/lib_common.lua", "tcd")
    widget.common = commonClass(app_name)

    -- get sensors
    local fi = getSensorFieldInfo(widget, widget.options.ArmFlags)
    widget.sensorArmId = fi and fi.id or 0

    fi = getSensorFieldInfo(widget, widget.options.ArmDisable)
    widget.sensorArmDisabledId = fi and fi.id or 0

    fi = getSensorFieldInfo(widget, widget.options.Throttle)
    widget.sensorThrId = fi and fi.id or 0

    fi = getSensorFieldInfo(widget, widget.options.GovFlags)
    widget.sensorGovId = fi and fi.id or 0

    fi = getSensorFieldInfo(widget, widget.options.EscModel)
    widget.sensorEscSigId = fi and fi.id or 0

    fi = getSensorFieldInfo(widget, widget.options.EscStatus)
    widget.sensorEscFlagsId = fi and fi.id or 0
    
    widget.sig = ESC_SIG_NONE
end

local function create(zone, options)
    local widget = {
        zone = zone,
        options = options,

        scode = 0,
        text_color = 0,
        escstatus_color = 0,

        isDataAvailable = false,

        fmode = "",
        throttle = "",

        connected = false,
        armed = false,

        epoch = (bootEpoch.hour * 3600 + bootEpoch.min * 60 + bootEpoch.sec) * 10
    }

    -- imports
    widget.libGUI = loadGUI()
    widget.gui = widget.libGUI.newGUI()
    widget.vslider = nil

    update(widget, options)
    return widget
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
local function logPutEv(widget, scode)
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
local function getEvTime(widget, evt)
    local t = widget.epoch + evt
    local dsec = t % 10
    t = math.floor(t / 10)

    local sec = t % 60
    t = math.floor(t / 60)
 
    local min = t % 60
    t = math.floor(t / 60)

    return { hour = t, min = min, sec = sec, dsec = dsec }
end

--- Zone size: 160x32 1/8th
local function refreshZoneSmall(widget)
    local cell = { ["x"] = 5, ["y"] = 4, ["w"] = widget.zone.w - 4, ["h"] = widget.zone.h - 8 }

    -- draw
    local rx = cell.x + cell.w - 6

    lcd.drawText(cell.x, cell.y, CHAR_TELEMETRY .. "Throttle", LEFT + widget.text_color)

    if widget.isDataAvailable then
        local flags = RIGHT + widget.text_color
        if string.len(widget.fmode) > 14 then
            flags = flags + SMLSIZE
        end
        lcd.drawText(rx, cell.y, widget.fmode, flags)
    end

    local _,vh = lcd.sizeText(widget.throttle, BOLD + MIDSIZE)
    lcd.drawText(rx, cell.y + widget.zone.h - vh, widget.throttle, BOLD + RIGHT + MIDSIZE + widget.text_color)

    local text
    local color
    if widget.sig == ESC_SIG_RESTART then
        text = "RESTART ESC"
        color = escStatusColors[LEVEL_ERROR] + BLINK
    else
        text = escstatus_text
        color = widget.escstatus_color
        color = BLACK
    end
    if text then
        _,vh = lcd.sizeText(text, color)
        lcd.drawText(cell.x + 6, cell.y + widget.zone.h - vh - 8, text, LEFT + color)
    end
end

--- Zone size: 460x252 - app mode (full screen)
local function refreshAppMode(widget, event, touchState)
    if event and event == EVT_VIRTUAL_EXIT then
        lcd.exitFullScreen()
        return
    end

    local cell = { ["x"] = 0, ["y"] = 0, ["w"] = LCD_W, ["h"] = LCD_H }
    local list_y = 40

    local scroll = 1
    if events > LIST_SIZE then
        local max = #log - LIST_SIZE + 1
        if not widget.vslider then
            -- create scrollbar
            local mvy = 20
            widget.vslider = widget.gui.verticalSlider(cell.w - 32, list_y + mvy, cell.h - list_y - 2 * mvy, max, 1, max, 1, nil)
        else
            -- update scrollbar max
            scroll = widget.vslider.max -  widget.vslider.value + 1
            widget.vslider.max = max
            widget.vslider.value = widget.vslider.max - scroll + 1
        end
    end

    local mx = 8
    local y = 12
    lcd.drawFilledRectangle(cell.x, cell.y, cell.w, 40, COLOR_THEME_SECONDARY1)
    lcd.drawText(cell.x + mx, y, string.format("%d ESC message%s", events, events == 1 and "" or "s"), COLOR_THEME_PRIMARY2 + BOLD)

    mx = mx + 4
    y = list_y
    lcd.drawRectangle(cell.x, y, cell.w, cell.h, BLACK, 1)

    if escGetStatus then
        y = y + 10
        for i = 1, math.min(#log, LIST_SIZE) do
            local ev = logGetEv(events - (i - 1) - (scroll - 1))
            local evt = getEvTime(widget, bit32.rshift(ev, 16))
            local time = string.format("%02d:%02d:%02d.%01d ", evt.hour, evt.min, evt.sec, evt.dsec)
            lcd.drawText(cell.x + mx, y, time, BLACK)
            local dx,dy = lcd.sizeText(time, BLACK)

            local status = escGetStatus(bit32.band(ev, 0x00FF), false)
            local color = escStatusColors[status.level]
            lcd.drawText(cell.x + mx + dx, y, status.text, bit32.bor(color, BOLD))
            y = y + dy
        end

        if widget.vslider then
            widget.gui.run(event, touchState)
        end     
    end
end

local govStates = {
    "OFF",
    "IDLE",
    "SPOOLUP",
    "RECOVERY",
    "ACTIVE",
    "THR-OFF",
    "LOST-HS",
    "AUTOROT",
    "BAILOUT",
}

local armDisabledDescs = {
    "NOGYRO",
    "FAILSAFE",
    "RXLOSS",
    "BADRX",
    "BOXFAILSAFE",
    "RUNAWAY",
    "CRASH",
    "THROTTLE",
    "ANGLE",
    "BOOTGRACE",
    "NOPREARM",
    "LOAD",
    "CALIB",
    "CLI",
    "CMS",
    "BST",
    "MSP",
    "PARALYZE",
    "GPS",
    "RESCUE_SW",
    "RPMFILTER",
    "REBOOT_REQD",
    "DSHOT_BBANG",
    "NO_ACC_CAL",
    "MOTOR_PROTO",
    "ARMSWITCH",
}

local function background(widget)

    -- assume telemetry not available
    widget.isDataAvailable = widget.common.isTelemetryActive()

    -- connected?
    if widget.isDataAvailable then
        -- connected
        if not widget.connected then
            -- reset status / log
            if escResetStatus then
                escResetStatus()
            end
            -- forget ESC
            escGetStatus = nil
            escResetStatus = nil
            widget.connected = true
        end

        -- armed?
        local armed
        local rfArmSensor
        if widget.sensorArmId ~= 0 then
            local val = getValue(widget.sensorArmId)
            rfArmSensor = (bit32.band(val, 0x01) == 0x01)
            armed = rfArmSensor or val == 1024
        else
            armed = false
            rfArmSensor = false
        end

        if armed then
            -- armed, get ESC throttle if configured
            if widget.sensorThrId ~= 0 then
                local thro = getValue(widget.sensorThrId)
                if not rfArmSensor then
                    -- convert -1024 / 1024 throttle range to %
                    thro = (thro + 1024) * 100 / 2048
                end
                widget.throttle = string.format("%d%%", thro)
            else
                widget.throttle = "--"
            end
        else
            -- not armed
            widget.throttle = "Safe"
        end

        -- GOV status
        local govStatus
        if widget.sensorGovId ~= 0 and widget.sensorArmDisabledId ~= 0 then
            local gs = getValue(widget.sensorGovId)
            local adf = getValue(widget.sensorArmDisabledId)

            if not armed then
                if adf ~= 0 then
                    govStatus = "";
                    -- find a better message
                    for i = 1, #armDisabledDescs do
                        local bit = i - 1
                        if bit32.band(adf, bit32.lshift(1, bit)) ~= 0 then
                            local desc = armDisabledDescs[bit + 1]
                            local len = string.len(govStatus)
                            if len + string.len(desc) + 1 > 18 then
                                govStatus = govStatus.." +"
                                break
                            end
                            govStatus = govStatus..(len > 0 and " " or "")..desc
                        end
                    end
                    govStatus = "* "..govStatus
                else
                    govStatus = "DISARMED";
                end
            else
                local idx = gs + 1
                if idx <= #govStates then
                    govStatus = govStates[idx]
                else
                    govStatus = "UNKNOWN("..gs..")"
                end
            end
        else
            govStatus = "--"
        end
        widget.fmode = govStatus

        -- ESC sig
        if widget.sensorEscSigId ~= 0 and widget.sensorEscFlagsId ~= 0 then
            widget.sig = getValue(widget.sensorEscSigId)
            if not escGetStatus then
                if widget.sig == ESC_SIG_OPENYGE then
                    escGetStatus = ygeGetStatus
                    escResetStatus = ygeResetStatus
                elseif widget.sig == ESC_SIG_TRIB then
                    escGetStatus = tribGetStatus
                    escResetStatus = resetStatus
                elseif widget.sig == ESC_SIG_PL5 then
                    escGetStatus = pl5GetStatus
                    escResetStatus = resetStatus
                elseif widget.sig == ESC_SIG_FLY then
                    escGetStatus = flyGetStatus
                    escResetStatus = resetStatus
                elseif widget.sig == ESC_SIG_OMP then
                    escGetStatus = ompGetStatus
                    escResetStatus = resetStatus
                elseif widget.sig == ESC_SIG_BLHELI32 then
                    escGetStatus = blheli32GetStatus
                    escResetStatus = resetStatus
                elseif widget.sig ~= ESC_SIG_NONE then
                    escstatus_text = "Unrecognized ESC"..string.format(" (%02X)", widget.sig)
                    escGetStatus = unkGetStatus
                end
                escstatus_level = LEVEL_INFO
            end
        end

        -- ESC flags
        if escGetStatus then
            local flags = getValue(widget.sensorEscFlagsId)
            local changed = logPutEv(widget, flags)
            local status = escGetStatus(flags, changed)
            if status.level >= escstatus_level then
                escstatus_text = status.text
                escstatus_level = status.level
                widget.escstatus_color = escStatusColors[status.level]
            end
        end

        -- announce if armed state changed
        if widget.options.Mute == 0 and widget.armed ~= armed then
            if armed then
                playAudio("armed")
            else
                playAudio("disarm")
            end
            widget.armed = armed
        end
    else
        -- not connected
        widget.throttle = "**"
        widget.fmode = ""
        widget.connected = false

        -- reset last armed
        widget.armed = false
    end
end

local function refresh(widget, event, touchState)

    if (widget == nil)         then return end
    if type(widget) ~= "table" then return end
    if (widget.options == nil) then return end
    if (widget.zone == nil)    then return end

    background(widget)

    if widget.isDataAvailable then
        widget.text_color = widget.options.Color
    else
        widget.text_color = COLOR_THEME_DISABLED
        if escstatus_level == LEVEL_INFO then
            widget.escstatus_color = COLOR_THEME_DISABLED
        end
    end

    if (event ~= nil) then
        refreshAppMode(widget, event, touchState)
    else
        refreshZoneSmall(widget)
    end
end

return { name = app_name, options = _options, create = create, update = update, background = background, refresh = refresh, translate = translate }
