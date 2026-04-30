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

-- RotorFlight aware bitmap
-- Author: Rob Gayle (bob00@rogers.com)
-- Date: 2026
-- ver: 0.9.0.04070

local app_name = "eBitmap"

local ALIGN_LEFT    = 0
local ALIGN_CENTER  = 1
local ALIGN_RIGHT   = 2

local imageDir = "/images/"

local _options = {
    { "Color"                 , COLOR, COLOR_THEME_PRIMARY1 },
    { "Size"                  , TEXT_SIZE, 0 },
    { "Shadow"                , BOOL, 0 },
    { "Align"                 , ALIGNMENT, ALIGN_RIGHT },
}

local function translate(text)
    local translations = {
        Color       = "Text color",
        Size        = "Text size",
        Shadow      = "Shadow",
        Align       = "Text alignment",
    }
    return translations[text]
end

local function loadBitmapFile(name, ext)
    local path = imageDir .. name .. ext
    local bmp = (fstat(path) and Bitmap.open(path)) or nil
    if bmp then
        local bw, bh = Bitmap.getSize(bmp)
        bmp = bw == 0 and bh == 0 and nil or bmp
    end
    return bmp
end

local function loadBitmap(name)
    return loadBitmapFile(name, "") or
        loadBitmapFile(name, ".png") or
        loadBitmapFile(name, ".bmp") or
        loadBitmapFile(name, ".jpg") or
        loadBitmapFile(name, ".jpeg") or
        nil
end

local function update(widget, options)
    if (widget == nil) then
        return
    end

    widget.options = options

    -- reload common libraries
    local commonClass = loadScript("/WIDGETS/eLib/lib_common.lua", "tcd")
    widget.common = commonClass(app_name)
end

local function create(zone, options)
    local widget = {
        zone = zone,
        options = options,

        connected = false,
        text_color = COLOR_THEME_PRIMARY1,

        modelName = nil,
        craftBitmapName = nil,
        craftBitmap = nil,
        modelBitmapName = nil,
        modelBitmap = nil,

        cellCount = 0,
    }

    update(widget, options)
    return widget
end

--- paint
local function paint(widget)
    -- canvas dimensions
    local box_width, box_height = widget.zone.w, widget.zone.h
    local box_left, box_top = 0, 0
    local margin = 8
    local bmargin = 4
    local sepr = 2

    -- text
    local textShadowed = widget.options.Shadow == 0 and 0 or SHADOWED
    local text = widget.modelName or "---"
    local textFlags = (widget.options.Size << 8) + textShadowed + widget.text_color
    local text_w, text_h = lcd.sizeText(text, textFlags)

    -- bitmap
    local bmp = widget.craftBitmap or widget.modelBitmap
    if bmp then
        local bw, bh = Bitmap.getSize(bmp)
        local cw, ch = box_width - bmargin * 2, box_height - margin - sepr - text_h
        local scalew = cw / bw
        local scaleh = ch / bh
        local scale, ofx, ofy
        -- use smaller scale and center image
        if scalew < scaleh then
            scale = scalew
            ofx = 0
            ofy = (ch - bh * scale) / 2
        else
            scale = scaleh
            ofy = 0
            ofx = (cw - bw * scale) / 2
        end
        lcd.drawBitmap(bmp, box_left + ofx + bmargin, box_top + ofy + text_h + margin + sepr, scale * 100)
    end

    -- title
    local tx
    local textAlignment = widget.options.Align
    if textAlignment == ALIGN_LEFT then
        tx = box_left + margin * 2 + bmargin
    elseif textAlignment == ALIGN_CENTER then
        tx = box_left + box_width / 2 - text_w / 2
    else
        tx = box_left + box_width - text_w - margin * 2 - bmargin
    end
    lcd.drawText(tx, box_top + margin, text, textFlags)
end

local function background(widget)
    if (widget == nil) then
        return
    end

    -- telemetry status
    widget.connected = widget.common.isTelemetryActive()

    -- get model info
    local mi = model.getInfo()
    local modelName = mi.name
    if widget.modelName ~= modelName then
        -- name
        widget.modelName = modelName
    end

    local craftBitmapName = modelName
    local cellCount = _G.ePowerbarCellCount or 0
    if widget.craftBitmapName ~= craftBitmapName or widget.cellCount ~= cellCount then
        -- bitmap name & cell count
        widget.craftBitmapName = craftBitmapName
        widget.cellCount = cellCount

        -- load bitmap
        widget.craftBitmap = cellCount ~= 0 and loadBitmap(craftBitmapName.."-"..cellCount.."S") or loadBitmap(craftBitmapName)
    end

    local modelBitmapName = mi.bitmap
    if widget.modelBitmapName ~= modelBitmapName then
        -- bitmap name
        widget.modelBitmapName = modelBitmapName

        -- load bitmap
        widget.modelBitmap = loadBitmap(modelBitmapName)
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
