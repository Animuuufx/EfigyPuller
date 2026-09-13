-- Run from the repository root with Lua 5.4.
local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end
local function fixture(options)
    local f = { requests = {}, queue = {}, relics = {}, controllers = {}, logs = {}, finds = {} }
    local world = { IsValid = function() return true end, GetAddress = function() return 1 end }
    function f.actor(name, x, y, z)
        return {
            name = name, position = {X=x or 0, Y=y or 0, Z=z or 0}, world = world,
            alive = true, bPickedInClient = false,
            IsValid = function(self) return self.alive end,
            IsA = function() return true end,
            GetWorld = function(self) return self.world end,
            GetFullName = function(self) return self.name end,
            GetAddress = function(self) return self.name end,
            K2_GetActorLocation = function(self) return self.position end,
        }
    end
    f.pawn = f.actor("pawn")
    f.state = f.actor("state")
    f.state.RequestObtainLevelObject_ToServer = function(_, relic)
        f.requests[#f.requests+1] = relic.name
    end
    f.controller = f.actor("controller")
    f.controller.Pawn = f.pawn
    f.controller.PlayerState = f.state
    f.controller.IsLocalPlayerController = function() return true end
    f.controllers = {f.controller}
    local env = setmetatable({
        require = function() return options or {} end,
        print = function(s) f.logs[#f.logs+1] = s end,
        FindAllOf = function(class)
            f.finds[#f.finds+1] = class
            if class == "PalPlayerController" then return f.controllers end
            assert(class == "PalLevelObjectRelic", "Must only scan effigies")
            return f.relics
        end,
        StaticFindObject = function() if f.missingAPI then return nil end; return world end,
        ExecuteInGameThread = function(fn) f.queue[#f.queue+1] = fn end,
        LoopAsync = function(ms, fn) f.interval, f.loop = ms, fn end,
    }, {__index = _G})
    assert(loadfile("EfigyPuller/Scripts/main.lua", "t", env))()
    function f.flush()
        local q = f.queue; f.queue = {}
        for _, fn in ipairs(q) do fn() end
    end
    function f.step() f.loop(); f.flush() end
    return f
end

local f = fixture()
f.relics = {f.actor("inside",4999), f.actor("boundary",5000), f.actor("outside",5000.01),
    f.actor("verticalOutside",0,0,5001), f.actor("diagonal",3000,4000), f.actor("verticalBoundary",0,0,5000)}
f.step()
check(#f.requests == 4, "Inclusive 50 m sphere must include four effigies")
check(f.requests[1] == "inside", "Nearest first")
check(f.interval == 500, "Default scan interval")
for _=1,9 do f.step() end
check(#f.requests == 4, "No repeat before cooldown")
f.step()
check(#f.requests == 8, "Retry after five seconds")

f = fixture()
local picked, invalid, other = f.actor("picked"), f.actor("invalid"), f.actor("other")
picked.bPickedInClient = true; invalid.alive = false
other.world = {IsValid=function() return true end, GetAddress=function() return 2 end}
f.relics = {picked,invalid,other}; f.step()
check(#f.requests == 0, "Ignore collected, destroyed and other-world actors")
f.relics = {f.actor("good")}; f.controllers = {}; f.step()
check(#f.requests == 0, "No player means no collection")
local remote = f.actor("remote")
remote.IsLocalPlayerController = function() return false end
f.controllers = {remote,f.controller}; f.step()
check(#f.requests == 1, "Select local controller, never a remote player")

f = fixture()
for i=1,12 do f.relics[i] = f.actor("r"..i,i*10) end
f.step(); check(#f.requests == 8, "Bounded batch")
f.step(); check(#f.requests == 12, "Remaining actors progress while earlier requests cool down")
f.relics[1].bPickedInClient = true
for _=1,10 do f.step() end
local firstCount = 0
for _,name in ipairs(f.requests) do if name == "r1" then firstCount=firstCount+1 end end
check(firstCount == 1, "Acknowledged collection never repeats")

f = fixture(); f.relics={f.actor("r")}
f.loop(); f.loop(); f.loop()
check(#f.queue == 1 and #f.requests == 0, "No engine access before game-thread callback; queue bounded")
check(#f.finds == 0, "No scans on asynchronous thread")
f.flush(); check(#f.requests == 1, "Queued scan executes")
f.pawn.world = {IsValid=function() return true end, GetAddress=function() return 3 end}
f.relics[1].world = f.pawn.world
f.step(); check(#f.requests == 2, "World change resets stale cooldown")

f = fixture(); f.relics={f.actor("r")}; f.missingAPI=true; f.step(); f.step()
check(#f.requests == 0, "Missing pickup API fails closed")
check(#f.logs == 2, "Errors logged only once")
f.missingAPI=false; f.step(); check(#f.requests == 1, "Recovers after API becomes available")

f = fixture(); local broken=f.actor("broken")
broken.K2_GetActorLocation=function() error("unloaded") end
f.relics={broken,f.actor("good")}; f.step()
check(#f.requests == 1, "Bad actor does not block good actors")
f.controller.IsLocalPlayerController=function() error("transition") end
f.step(); f.controller.IsLocalPlayerController=function() return true end
f.relics={f.actor("new")}; f.step()
check(#f.requests == 2, "Scan error releases pending flag")

f = fixture({Enabled=false}); check(f.loop == nil, "Disabled mod schedules nothing")
f = fixture({RadiusMeters=10}); f.relics={f.actor("in",1000),f.actor("out",1001)}; f.step()
check(#f.requests == 1, "Custom radius")
f = fixture({RadiusMeters=0/0,ScanIntervalMs="bad",MaxRequestsPerScan=-1})
f.relics={f.actor("a",4999),f.actor("b",10)}; f.step()
check(f.interval == 500 and #f.requests == 1, "Malformed settings fall back or clamp")
print(string.format("PASS: %d behavioral checks",passed))
