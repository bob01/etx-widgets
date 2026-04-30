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

-- Common
-- Author: Rob Gayle (bob00@rogers.com)
-- Date: 2026
-- ver: 0.9.0.03220

local app_name = ...

local G = {}
G.app_name = app_name

local BEAT_INTERVAL     = 200               -- 10ms ticks

G.beatNext = 0
G.beatId = 0

G.telemetryActive = false


local function init()
    -- get BEAT sensor, bail if not found
    local fi = getFieldInfo("BEAT") or getFieldInfo("1RSS")
    G.beatId = fi ~= nil and fi.id or 0
    
    return G, G.beatId ~= 0
end

function G.log(s)
    print(G.app_name .. ": " .. s)
end

function G.isTelemetryActive()
    if G.beatId ~= 0 then
        local now = getTime()
        if G.beatNext < now then
            G.beatNext = now + BEAT_INTERVAL

            G.telemetryActive = getValue(G.beatId) ~= 0
        end
    end

    return G.telemetryActive
end

return init()