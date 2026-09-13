# Validation — 2026-09-13

Target: Palworld **1.0.4.102642** (version displayed by the running game), using the owner's existing **UE4SS 3.0.1 Beta #0 / 2281fa31** in `Pal/Binaries/Win64/ue4ss`.

## v0.1.1 checks

- 26 behavioral checks pass under Lua 5.4. These exercise the radius boundary and height, request limits and cooldown, local-player selection, world changes, invalid/collected actors, scheduling, unavailable APIs, network component availability, and cached discovery frequency.
- A read-only probe of the running game found the pickup function on `PalNetworkPlayerComponent`.
- Generated `CXXHeaderDump/Pal.hpp` using the installed UE4SS. It confirms the signature `RequestObtainLevelObject_ToServer(APalLevelObjectObtainable* TargetObject)`, the `PalPlayerController.Transmitter.Player` route, and `PalLevelObjectObtainable.bPickedInClient`.
- Replaced global actor scans with `GameplayStatics.GetAllActorsOfClass` every two seconds, and cached the local controller. Distance checks use the cached effigy list every 500 ms.
- Installed the corrected mod into the existing loader without replacing loader binaries or settings.

## Initial v0.1.0 failure

The first build loaded, but did not collect: its expected `PalPlayerState` pickup API was unavailable in this game version. The user also reported lag. The build was replaced with a one-shot read-only diagnostic, then corrected. Startup success and passing simulated tests did not establish gameplay compatibility.

## Gameplay status

Corrected-build pickup, smoothness, and save persistence are pending in-world verification. Multiplayer and other game/UE4SS versions remain unverified. A `Pickup confirmed by game` log records a collected actor flag after requesting pickup; inventory reward and persistence should still be checked in-game.
