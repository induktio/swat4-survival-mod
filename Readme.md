
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
It is also possible to change the game to enforce less use of force penalties while playing the mod.


Installation
------------
1. Extract SurvivalMod.u to SWAT4\Content(Expansion)\System
2. Open SWAT4\Content(Expansion)\SWAT4(X)DedicatedServer.ini
3. Alternatively edit SWAT4(X).ini to run the mod in COOP mode without a dedicated server.
4. Enter this example configuration in the file:

```
[Engine.GameEngine]
ServerActors=SurvivalMod.SVMod

[SurvivalMod.SVMod]
; Allow starting Survival Mod (True/False).
Enabled=True

; Enforce unauthorized use of force penalties during gameplay (True/False).
; If the suspects drop their weapons, use of force is penalized in any case.
ForcePenalties=True

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

; Set skill value for all archetypes spawned by the mod (0=low, 1=medium, 2=high).
; Comment out to use default values.
;EnemySkill=2

; Set minimum morale value for all archetypes spawned by the mod. Floating point value allowed.
; Comment out to use default values.
;EnemyMinMorale=2.0

; Set maximum morale value for all archetypes spawned by the mod. Floating point value allowed.
; Comment out to use default values.
;EnemyMaxMorale=3.0

; Try to spawn similar archetypes as specified by the default mission (True/False).
; If no suitable archetypes are found from the level, the mod uses custom archetypes.
StoryArchetypes=False

; Choose any archetypes from EnemyArchetypes.ini.
; One or more must be specified and will be chosen randomly.
Archetypes=Red_Thief_Armor
Archetypes=Hotel_Bomber
Archetypes=Jewel_FreedomNow_GasMask

; These archetypes are for TSS expansion only.
Archetypes=Office_Farmer
Archetypes=Office_Farmer_GasMask
Archetypes=HalfwayHouse_Robber
Archetypes=HalfwayHouse_Robber_SAW
```


Event Logger
------------
As an optional feature, the mod includes the Event Logger module for COOP that displays gameplay
events such as kills, arrests, bomb defusals and similar in the message area. After a round ends,
the elapsed time is also displayed during the score screen.

This module can be used separately from Survival Mod, and it is not dependent on the config used
by Survival Mod in any way. To install Event Logger, enter these lines in SWAT4(X)DedicatedServer.ini.

```
[Engine.GameEngine]
ServerActors=EventLogger.EventMod
```


Changelog
---------
### v1.3
* Suspect awareness is increased and they are much more likely to watch nearby doors as they are opened.
* Add new config options: StoryArchetypes, EnemySkill, EnemyMinMorale, EnemyMaxMorale. By default these are disabled.
* Small adjustments to Event Logger messages.

### v1.2
* Add new config option ForcePenalties to choose if the game should enforce unauthorized use of force penalties.
* Whenever one of the suspects is neutralized, the others are now much more likely to move to the location to investigate noise.
* The module name used by the mod is changed to SurvivalMod.SVMod. This must be updated in the config file.
* Event Logger module for COOP is now included with the mod as an optional feature.

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

