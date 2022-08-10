
SWAT 4 Survival Mod
===================

Features
--------
Survival Mod can make any standard or custom maps in COOP more challenging by spawning more suspects
at the round start or in multiple waves during gameplay. Normally Quick Mission Maker would limit
the number of suspects on the map to the available spawn points. However, this mod is able
to overcome that limit by using FleePoints or Door ClearPoints as spawning points if other places
are already used. This way even the smallest maps can support nearly unlimited amount of suspects.

Suspect archetypes can be selected from any choices specified in EnemyArchetypes.ini and
they are chosen randomly when spawning extra suspects. Note that this mod doesn't affect
the suspects or civilians spawned on the maps by default, it can only spawn additional suspects.
Currently this mod is only implemented as a server side mod, single player mode is not supported.

As an optional feature, the mod can also open some doors randomly on the map.
This brings much more variety to the gameplay as normally almost all of the doors are closed.


Installation
------------
1. Extract SurvivalMod.u to SWAT4\Content(Expansion)\System
2. Open SWAT4\Content(Expansion)\SWAT4(X)DedicatedServer.ini
3. Alternatively edit SWAT4(X).ini to run the mod in COOP mode without a dedicated server.
4. Enter this example configuration in the file:

```
[Engine.GameEngine]
ServerActors=SurvivalMod.Main

[SurvivalMod.Main]
; Allow starting Survival Mod (True/False)
Enabled=True
; Choose how often to open doors randomly at the round start.
; Values allowed: 0-100, 0 = disable this feature.
RandomDoors=25
; After spawning the normal suspects, add more until at least this count is reached.
AmountMin=15
; After previous step, add this many suspects regardless of the existing count.
AmountExtra=10
; Skip spawn points that are this close to player spawns (default is usually good).
MinDistance=300.0
; Spawn this many waves of new suspects when the trigger is reached (zero or more).
WaveSpawns=1
; Spawn a new wave when less than this proportion of the initial suspects are active.
; Floating point value allowed, zero to one. 0.5 = half of the initial count.
WaveTrigger=0.5
; Spawn wave size compared to the initial suspect count.
; Floating point value allowed, more than zero.
WaveSize=0.5

; Choose any archetypes from EnemyArchetypes.ini.
; One or more must be specified and will be chosen randomly.
Archetypes=Red_Thief_Armor
Archetypes=Hotel_Bomber
Archetypes=Custom_Terrorists
Archetypes=Custom_Terrorist_GasMask

; These archetypes are for TSS expansion only.
Archetypes=Office_Farmer
Archetypes=Office_Farmer_GasMask
Archetypes=HalfwayHouse_Robber
Archetypes=HalfwayHouse_Robber_SAW
```


Changelog
---------

### v1.1
* Before spawning the next wave, a new "10 seconds" warning is displayed near the middle of the screen.
* After a wave is spawned, the mod will display how many waves are still remaining, if any.
* RandomDoors config variable is changed from a bool value to an integer setting to choose how often doors are randomly opened. Allowed values: 0-100.

### v1.0
* First release


Known bugs
----------
* Picking up evidence from the additional spawned suspects is sometimes glitched. These guns will remain visible on the map and cannot be collected.


License
-------
Redistribution and use in source and binary forms, with or without modification, are permitted provided
that you link to [the source repository](https://github.com/induktio/swat4-survival-mod)
or mention the original author in a similar way.

