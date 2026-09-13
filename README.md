# EfigyPuller

A Palworld UE4SS Lua mod that **automatically collects loaded effigies within 50 meters** of your character, including vertical distance. No keypress is needed. It uses the game's normal pickup request, so the game handles rewards and collected flags.

This implements automatic collection, not a flying-object animation. Only `PalLevelObjectRelic` actors are targeted; notes, chests, and dropped items are excluded. Scans run every 500 ms on the game thread, with at most eight pickup requests per scan and a five-second retry delay per effigy.

## Install

1. Close Palworld. Use your existing working UE4SS installation.
2. Copy the `EfigyPuller` folder into that loader's `Mods` folder. It must contain `EfigyPuller/Scripts/main.lua` and `EfigyPuller/enabled.txt`.
3. Start Palworld and enter a world. Approach an uncollected effigy within 50 m.

For a conventional loader, the destination is `Palworld/Pal/Binaries/Win64/ue4ss/Mods/EfigyPuller`. A native loader may instead use `Palworld/Mods/NativeMods/UE4SS/Mods/EfigyPuller`. Check the latest `UE4SS.log` for **Loading mods from** and use only that directory. Do not install a second UE4SS copy for this mod.

The included `enabled.txt` enables the mod without changing other mods. If you already have an explicit `EfigyPuller : 0` in `mods.txt`, change it to `EfigyPuller : 1`.

## Configuration

Edit `EfigyPuller/Scripts/config.lua` while the game is closed:

| Setting | Default | Meaning |
| --- | --- | --- |
| Enabled | true | Turn collection on/off |
| RadiusMeters | 50 | 3D pickup radius (1–500 m) |
| ScanIntervalMs | 500 | Scan interval (100–10000 ms) |
| RetrySeconds | 5 | Delay before retrying an unconfirmed pickup |
| MaxRequestsPerScan | 8 | Limit pickup traffic per scan |
| Debug | false | Log individual pickup requests |

Only loaded effigies can be collected. The local player receives pickup requests. On multiplayer servers, the server decides whether requests succeed; remote server compatibility is unverified. Dedicated-server operation without a local player is not supported.

## Validation and troubleshooting

Built against the names present in the owner's installed `Palworld-Win64-Shipping.exe` and existing UE4SS v3.0.1 Beta, revision `2281fa31`. Executable string checks confirm names, not runtime signatures or successful collection. See `VALIDATION.md` for actual test status.

In `UE4SS.log`, look for `[EfigyPuller] Loaded v0.1.0`. Enable `Debug` to see pickup requests. A request log is not proof of a reward: verify the inventory count increases, the effigy disappears, and it remains collected after leaving and reloading the world. If the game API changes, errors are logged once per category to avoid flooding the log.

To uninstall, close the game and remove only the `EfigyPuller` folder. Effigies already collected stay collected.

## Development

Run `lua tests/test_runtime.lua` from the repository root using Lua 5.4. The tests simulate UE4SS and verify the range boundary, player selection, filtering, request throttling, world changes, and scheduling. They cannot establish actual game compatibility.

Reference APIs: [UE4SS FindAllOf](https://docs.ue4ss.com/lua-api/global-functions/findallof.html), [ExecuteInGameThread](https://docs.ue4ss.com/lua-api/global-functions/executeingamethread.html), and [Palworld reflected declarations](https://gist.github.com/DRayX/1839565378bc7fb7c92232e25a131d8a).

License: GPL-3.0, as selected by this repository's existing LICENSE.
