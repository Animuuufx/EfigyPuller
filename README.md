# EfigyPuller v0.3.0 — auto collect nearby Lifmunk Effigies

An install-ready **UE4SS Lua mod** for Palworld. Automatically sends the
game's ordinary effigy pickup request when a **loaded** Lifmunk Effigy enters
the configured radius around the **local player**.

### Configuration

Edit `EfigyPuller/Scripts/config.lua` **while Palworld is closed**:

```lua
return {
    Enabled = true,
    RadiusMeters = 200,           -- Default only; any positive number
    CheckIntervalMs = 1000,       -- Cheap cached-distance checks
    MovementThresholdMeters = 1,  -- Skip checks when not moving
    RetrySeconds = 5,
    MaxRequestsPerCheck = 8,      -- Prevent server/network bursts
    Debug = false,
}
```

**There is no maximum radius imposed by this mod.** Use 100, 200, 1000,
5000 meters, or another positive value. The game must first stream the
effigy into memory, and its server must permit the pickup request. A 5000 m
radius cannot collect actors outside the game's loading distance.

### Performance

- One initial `GameplayStatics.GetAllActorsOfClass` seed per world.
- `NotifyOnNewObject` tracks new Lifmunk Effigies as they stream in.
- **No recurring actor-discovery scans** if event registration succeeds.
- The cached list receives a cheap 3D distance check at most once per
  `CheckIntervalMs` (default 1000 ms). With no movement and no new effigies
  or pending retries, even that work is skipped.
- Only nearby uncollected effigies cause pickup RPCs. The request limit
  prevents excessive network bursts; it is not a continuous polling rate.
- If the engine hook is unavailable, only then is a slow 30 s fallback
  discovery performed.

### Installation

Close Palworld. Extract `EfigyPuller` into your active UE4SS Mods folder,
usually:

```text
Palworld/Pal/Binaries/Win64/ue4ss/Mods/EfigyPuller/
  enabled.txt
  Scripts/main.lua
  Scripts/config.lua
```

If UE4SS lists a different `Loading mods from:` folder in `UE4SS.log`,
use that folder instead. Do not install a second copy of UE4SS.

### Notes

- Uses the engine's normal
  `PalNetworkPlayerComponent:RequestObtainLevelObject_ToServer` RPC.
- Does **not** create rewards, skip server permissions, collect notes,
  or move effigies physically toward the character.
- Multiplayer server acceptance and large-radius pickup **are not
  yet verified in-game**.
- Debug in `config.lua` shows discovery and request messages in
  `UE4SS.log`.
- If your UE4SS setup already has a conflicting old copy of EfigyPuller,
  remove it first.

### Development and testing

Run `lua tests/test_runtime.lua` against Lua 5.4 to exercise the mock
game-world scenarios. Static/offline tests do not establish live Palworld
compatibility.

License: GPL-3.0, as selected by the existing project.
