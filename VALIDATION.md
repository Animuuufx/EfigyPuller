# Validation — 2026-09-13

## Verified

- 23 behavioral checks passed using Lua 5.4 via Lupa. Coverage includes 50 m inclusive/just-outside boundaries, height, nearest-first requests, request limits, cooldowns, collected/invalid/other-world objects, local-player selection, no-player state, world changes, queue backpressure, API failure and recovery, per-object errors, disabled mode, and configuration bounds.
- Located the owner's actual `Palworld.exe` launcher and `Pal/Binaries/Win64/Palworld-Win64-Shipping.exe`.
- Found `PalLevelObjectRelic`, `bPickedInClient`, `IsLocalPlayerController`, and `RequestObtainLevelObject_ToServer` names in the installed shipping executable. This does not prove function signatures.
- Inspected the installed UE4SS log and helper module. The active loader is `Pal/Binaries/Win64/ue4ss`, version **3.0.1 Beta #0**, revision **2281fa31**. The old `Mods/NativeMods/UE4SS` log is from August and was not used as the installation target.
- Installed only the new `EfigyPuller` mod directory and its `enabled.txt`; existing loader binaries/settings were preserved.
- Launched the installed `Palworld.exe`. Both launcher and shipping-game processes started.
- The live UE4SS log confirmed at **15:36:35**: `[EfigyPuller] Loaded v0.1.0: auto-collect within 50.0 meters, scanning every 500 ms.` No EfigyPuller errors appeared during the observed title-screen startup.

## Still requires gameplay verification

- Successful collection and inventory reward inside 50 m in an actual world.
- No collection just outside the radius, including above/below an effigy.
- Collection persistence after saving, exiting, and re-entering the world.
- Multiplayer acceptance, mounted movement, and other game/UE4SS versions.

Startup validation and simulated tests do not establish these gameplay results. The mod is an initial v0.1.0 build pending that verification.
