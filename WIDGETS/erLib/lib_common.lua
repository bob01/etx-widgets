local app_name = ...

local G = {}
G.app_name = app_name

local BEAT_INTERVAL     = 200               -- 10ms ticks

G.beatNext = 0
G.beatId = 0

G.telemetryActive = false


local function init()
    -- get BEAT sensor, bail if not found
    local fi = getFieldInfo("BEAT")
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