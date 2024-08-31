local app_name = ...

local G = {}
G.appName = app_name

local BEAT_INTERVAL     = 200               -- 10ms ticks

G.beatNext = 0
G.beatId = 0

G.telemetryActive = false


local function init()
    -- get BEAT sensor, bail if not found
    local fi = getFieldInfo("BEAT")
    if fi == nil then
        log("no telemetry sensor found")
        return false
    end
    G.beatId = fi.id
    
    -- init good
    return true
end

function G.log(s)
    print(G.app_name .. ": " .. s)
end

function G.isTelemetryActive()
    -- time to recalc?
    local now = getTime()
    if G.beatNext < now then
        G.beatNext = now + BEAT_INTERVAL

        G.telemetryActive = getValue(G.beatId) ~= 0
    end

    return G.telemetryActive
end

return init() and G or nil