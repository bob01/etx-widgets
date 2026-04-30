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

-- Enhanced value widget
-- Author: Rob Gayle (bob00@rogers.com)
-- Date: 2026
-- ver: 0.9.0.04220

local app_name = "eValue"

local ALIGN_LEFT    = 0
local ALIGN_CENTER  = 1
local ALIGN_RIGHT   = 2

local _options = {
    { "Source"                , SOURCE, 0 },
    { "Color"                 , COLOR, COLOR_THEME_PRIMARY1 },
    { "Shadow"                , BOOL, 0 },
    { "AlignLabel"            , ALIGNMENT, ALIGN_LEFT },
    { "AlignValue"            , ALIGNMENT, ALIGN_RIGHT },
    { "Unit"                  , BOOL, 1 },
    { "Min"                   , BOOL, 0 },
    { "Max"                   , BOOL, 0 },
}

local function translate(text)
    local translations = {
        source          = "Source",
        Color           = "Color",
        Shadow          = "Shadow",
        AlignLabel      = "Align label",
        AlignValue      = "Align value",
        Unit            = "Show unit",
        Min             = "Show minimum",
        Max             = "Show maximum",
    }
    return translations[text]
end

local units = {
    "V",
    "A",
    "mA",
    "kts",
    "m/s",
    "f/s",
    "km/h",
    "mph",
    "m",
    "f",
    "°C",
    "°F",
    "%",
    "mAh",
    "W",
    "mW",
    "dB",
    "rpm",
    "g",
    "°",
    "rad",
    "ml",
    "fOz",
    "ml/m",
    "Hz",
    "mS",
    "uS",
    "km"
}

local function unitToString(unitId)
    if unitId == nil then
        return nil
    elseif (unitId > 0 and unitId <= #units) then
        return units[unitId]
    else
        return nil
    end
end

local function update(widget, options)
    if (widget == nil) then
        return
    end

    widget.options = options

    -- reload common libraries
    local commonClass = loadScript("/WIDGETS/eLib/lib_common.lua", "tcd")
    widget.common = commonClass(app_name)

    local fi = getFieldInfo(options.Source)
    widget.sourceId = fi and fi.id or 0
    if widget.sourceId ~= 0 then
        widget.text_label = fi.name
        widget.text_unit = options.Unit ~= 0 and unitToString(fi.unit) or nil

        local name = fi.name
        fi = options.Min ~= 0 and getFieldInfo(name .. "-") or nil
        widget.minId = fi and fi.id or 0
        fi = options.Max ~= 0 and getFieldInfo(name .. "+") or nil
        widget.maxId = fi and fi.id or 0
    else
        widget.minId = 0
        widget.maxId = 0
    end

    widget.text_value = nil
    widget.text_minmax = nil
end

local function create(zone, options)
    local widget = {
        zone = zone,
        options = options,

        connected = false,
        text_color = COLOR_THEME_PRIMARY1,

        sourceId = 0,
        minId = 0,
        maxId = 0,

        text_label = nil,
        text_unit = nil,
        text_value = nil,
        text_minmax = nil,
    }

    update(widget, options)
    return widget
end

local function align(width, margin, text_width, alignment)
    if alignment == ALIGN_LEFT then
        return margin
    elseif alignment == ALIGN_CENTER then
        return width / 2 - text_width / 2
    else
        return width - text_width - margin
    end
end

--- paint
local function paint(widget)
    local cw, ch = widget.zone.w, widget.zone.h
    local cx, cy = 0, 0
    local mx, my = 5, 4

    local shadowed = widget.options.Shadow == 0 and 0 or SHADOWED

    -- label
    if widget.text_label then
        local text = widget.text_label
        local alignment = widget.options.AlignLabel
        local textFlags = widget.text_color + shadowed
        local tw, _ = lcd.sizeText(text, textFlags)
        local dx = align(cw, mx, tw, alignment)
        lcd.drawText(cx + dx, cy + my, CHAR_TELEMETRY .. text, textFlags)
    end

    -- value
    if widget.text_value then
        local text = widget.text_value
        local alignment = widget.options.AlignValue
        local textFlags = widget.text_color + shadowed + MIDSIZE + BOLD
        local tw, _ = lcd.sizeText(text, textFlags)
        local dx = align(cw, mx, tw, alignment)
        lcd.drawText(cx + dx, cy + ch / 2, text, VCENTER + textFlags)
    end

    -- min/max
    if widget.text_minmax then
        local text = widget.text_minmax
        local alignment = widget.options.AlignValue
        local textFlags = widget.text_color + shadowed
        local tw, th = lcd.sizeText(text, textFlags)
        local dx = align(cw, mx, tw, alignment)
        lcd.drawText(cx + dx, cy + ch - th - my, text, textFlags)
    end
end

local function background(widget)
    if (widget == nil) then
        return
    end

    -- telemetry status
    widget.connected = widget.common.isTelemetryActive()

    if widget.sourceId ~= 0 then
        widget.text_value = getValue(widget.sourceId) .. (widget.text_unit or "")

        if widget.minId ~= 0 and widget.maxId ~= 0 then
            widget.text_minmax = "min " .. getValue(widget.minId) .. " / max " .. getValue(widget.maxId) .. (widget.text_unit or "")
        elseif widget.minId ~= 0 then
            widget.text_minmax = "min " .. getValue(widget.minId) .. (widget.text_unit or "")
        elseif widget.maxId ~= 0 then
            widget.text_minmax = "max " .. getValue(widget.maxId) .. (widget.text_unit or "")
        else
            widget.text_minmax = nil
        end
    end
end

local function refresh(widget, event, touchState)

    if (widget == nil)         then return end
    if type(widget) ~= "table" then return end
    if (widget.options == nil) then return end
    if (widget.zone == nil)    then return end

    background(widget)

    if widget.connected then
        widget.text_color = widget.options.Color
    else
        widget.text_color = COLOR_THEME_DISABLED
    end

    paint(widget)

    if (event ~= nil) then
        if (touchState and touchState.tapCount == 2) or (event and event == EVT_VIRTUAL_EXIT) then
            lcd.exitFullScreen()
        end
    end
end

return { name = app_name, options = _options, create = create, update = update, background = background, refresh = refresh, translate = translate }
