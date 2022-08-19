/*
 ****************************************
 * SWAT 4 COOP Survival Mod by Induktio *
 ****************************************
 */

class SVMod extends SwatGame.SwatMutator
    implements IInterested_GameEvent_PawnDied,
               IInterested_GameEvent_PawnIncapacitated,
               IInterested_GameEvent_PawnArrested,
               IInterested_GameEvent_PawnDamaged,
               IInterestedInDoorOpening;

const VERSION = "1.4";
const MAX_ITER = 400;

var config bool Enabled;
var config bool CheckNoise;
var config bool ForcePenalties;
var config bool StoryArchetypes;
var config bool SkipBanner;
var config int RandomDoors;
var config int AmountMin;
var config int AmountExtra;
var config int WaveSpawns;
var config int EnemySkill;
var config float EnemyMinMorale;
var config float EnemyMaxMorale;
var config float WaveTrigger;
var config float WaveSize;
var config float MinDistance;
var config array<string> Archetypes;

var protected int WavesLeft;
var protected int SpawnTimer;
var protected int TotalSuspects;
var protected array<EnemySpawner> AllSpawns;
var protected array<Actor> AllPoints;
var protected array<SwatDoor> AllDoorWays;
var protected array<string> LevelArchetypes;
var protected array<SwatDoor> DoorSensors;
var protected array<SwatMPStartPoint> StartPoints;
var protected SVGoalBase GoalBase;
var protected GameEventsContainer GameEvents;
var protected Procedure_KillSuspects ProcKill;
var protected Procedure_ArrestIncapacitatedSuspects ProcIncap;
var protected Procedure_ArrestUnIncapacitatedSuspects ProcArrest;

defaultproperties
{
    Enabled = True
    CheckNoise = True
    ForcePenalties = True
    StoryArchetypes = False
    SkipBanner = False
    RandomDoors = 25
    AmountMin = 10
    AmountExtra = 10
    WaveSpawns = 0
    EnemySkill = -1;
    EnemyMinMorale = -1;
    EnemyMaxMorale = -1;
}


function PreBeginPlay() {
    Super.PreBeginPlay();

   if (Level.NetMode == NM_ListenServer || Level.NetMode == NM_DedicatedServer) {
       if (Level.Game != None && SwatGameInfo(Level.Game) != None && Level.IsCOOPServer) {
            if (self.Enabled && self.Archetypes.Length > 0) {
                return;
            }
       }
    }
    log("SurvivalMod is unable to start: NetMode=" $ Level.NetMode $ " Level=" $ Level.Game);
    self.Destroy();
}

function UnRegisterGameEventsHook() {
    while (DoorSensors.Length > 0) {
        DoorSensors[0].UnRegisterInterestedInDoorOpening(self);
        DoorSensors.Remove(0, 1);
    }
    GameEvents.PawnDied.UnRegister(self);
    GameEvents.PawnIncapacitated.UnRegister(self);
    GameEvents.PawnArrested.UnRegister(self);
    GameEvents.PawnDamaged.UnRegister(self);
    GoalBase.ClearAllGoals();
}

event Destroyed() {
    log("SurvivalMod is about to be closed");
    Super.Destroyed();
}

function PostBeginPlay() {
    local int i, j, num, minimum;
    local string type;
    local bool usable;
    local EnemySpawner Spawner;
    local SwatDoor Door;
    local SwatRepo Repo;
    local Procedure Proc;
    local SwatMPStartPoint StartPoint;
    local Actor Target;
    local PathNode Node;
    local Roster Roster;

    Super.PostBeginPlay();
    self.WavesLeft = self.WaveSpawns;
    self.SpawnTimer = 0;
    self.TotalSuspects = 0;

    GameEvents = SwatGameInfo(Level.Game).GameEvents;
    GameEvents.PawnDied.Register(self);
    GameEvents.PawnIncapacitated.Register(self);
    GameEvents.PawnArrested.Register(self);
    GameEvents.PawnDamaged.Register(self);

    log("SurvivalMod v" $ VERSION $ " by Induktio has been loaded");
    log("SurvivalMod Archetypes=" $ self.Archetypes.Length $ " Minimum=" $ self.AmountMin $ " Extra=" $ self.AmountExtra
        $ " RandomDoors=" $ self.RandomDoors $ " MinDistance=" $ self.MinDistance $ " WaveSpawns=" $ self.WaveSpawns
        $ " WaveTrigger=" $ self.WaveTrigger $ " WaveSize=" $ self.WaveSize);

    i = 0;
    foreach SwatGameInfo(Level.Game).AllActors(class'EnemySpawner', Spawner) {
        if (Spawner.IsA('EnemySpawner') && !Spawner.Disabled) {
            if (Spawner.HasSpawned) {
                self.TotalSuspects++;
            }
            Spawner.SpawnAnInvestigator = true;
            AllSpawns[i] = Spawner;
            i++;
        }
    }

    for (i = 0; self.StoryArchetypes && i < SpawningManager(Level.SpawningManager).Rosters.Length; ++i) {
        Roster = SpawningManager(Level.SpawningManager).Rosters[i];
        if (Roster.ArchetypeClass != class'SwatGame.EnemyArchetype'
        || Roster.Count.Min < 2 || Roster.Count.Max < 2) {
            continue;
        }
        for (j = 0; j < Roster.Archetypes.Length; ++j) {
            log("ARCH "$ Roster.Archetypes[j].Chance);
            log("ARCH "$ Roster.Archetypes[j].Archetype);
            LevelArchetypes[ LevelArchetypes.Length ] = string(Roster.Archetypes[j].Archetype);
        }
    }

    i = 0;
    foreach SwatGameInfo(Level.Game).AllActors(class'SwatMPStartPoint', StartPoint) {
        StartPoints[i] = StartPoint;
        i++;
    }
    i = 0;
    num = 0;
    foreach SwatGameInfo(Level.Game).AllActors(class'PathNode', Node) {
        if (!Node.IsA('StackupPoint') && !PointsNear(StartPoints, Node, false, self.MinDistance)) {
            usable = (Node.IsA('ClearPoint') || Node.IsA('FleePoint'));
            if (usable || (!usable && PointsNear(AllSpawns, Node, true))) { 
                AllPoints[i] = Node;
                i++;
            }
        }
        num++;
    }
    log("SurvivalMod NewPoints="$ i $ " SkippedPoints=" $ num-i);
    
    Repo = SwatRepo(Level.GetRepo());
    for (i = 0; i < Repo.Procedures.Procedures.Length; i++) {
        Proc = Repo.Procedures.Procedures[i];
        if (Procedure_KillSuspects(Proc) != None) {
            ProcKill = Procedure_KillSuspects(Proc);
            log("SurvivalMod ProcKill " $ ProcKill $ " " $ ProcKill.TotalEnemies);
        } else if (Procedure_ArrestIncapacitatedSuspects(Proc) != None) {
            ProcIncap = Procedure_ArrestIncapacitatedSuspects(Proc);
            log("SurvivalMod ProcIncap " $ ProcIncap $ " " $ ProcIncap.TotalEnemies);
        } else if (Procedure_ArrestUnIncapacitatedSuspects(Proc) != None) {
            ProcArrest = Procedure_ArrestUnIncapacitatedSuspects(Proc);
            log("SurvivalMod ProcArrest " $ ProcArrest $ " " $ ProcArrest.TotalEnemies);
        }
    }
    
    num = 0;
    minimum = 0;
    if (self.TotalSuspects < self.AmountMin) {
        minimum = self.AmountMin - self.TotalSuspects;
    }
    
    for (i = 0; num < minimum + self.AmountExtra && i < MAX_ITER; i++) {
        if (self.LevelArchetypes.Length > 0) {
            type = self.LevelArchetypes[ Rand(self.LevelArchetypes.Length) ];
        } else {
            type = self.Archetypes[ Rand(self.Archetypes.Length) ];
        }
        if (i % 2 == 0 && AllPoints.Length >= 4) {
            Target = AllPoints[ Rand(AllPoints.Length) ];
            usable = (!PointsNear(StartPoints, Target, true) || i >= MAX_ITER/2);
            if (usable && PointSpawn(name(type), Target) != None) {
                log("SurvivalMod added " $ type $ " at " $ Target);
                self.TotalSuspects++;
                num++;
            }
        } else {
            Spawner = AllSpawns[ Rand(AllSpawns.Length) ];
            usable = ((Spawner.MissionSpawn == MissionSpawn_Any && Spawner.StartPointDependent == StartPoint_Any)
                || i >= MAX_ITER/2);
            
            if (!Spawner.HasSpawned && usable && Spawner.SpawnArchetype(name(type), false) != None) {
                log("SurvivalMod added " $ type $ " at " $ Spawner);
                self.TotalSuspects++;
                num++;
            }
        }
    }
    log("SurvivalMod TotalSuspects=" $ self.TotalSuspects $ " NewSuspects=" $ num);

    foreach SwatGameInfo(Level.Game).AllActors(class'SwatDoor', Door) {
        if (Door != None && !Door.bIsMissionExit) {
            AllDoorWays[ AllDoorWays.Length ] = Door;
        }
        if (Door == None || Door.bIsMissionExit || Door.IsBroken() || Door.IsEmptyDoorway()) {
            continue;
        }
        if (self.RandomDoors > 0) {
            if (Rand(100) < self.RandomDoors) {
                if (Rand(2) == 0) {
                    log("SurvivalMod Door " $ Door $ " -> OpenLeft");
                    Door.SetPositionForMove(DoorPosition_OpenLeft, MR_Interacted);
                    Door.OnUnlocked();
                } else {
                    log("SurvivalMod Door " $ Door $ " -> OpenRight");
                    Door.SetPositionForMove(DoorPosition_OpenRight, MR_Interacted);
                    Door.OnUnlocked();
                }
            } else {
                log("SurvivalMod Door " $ Door $ " -> NoChange");
            }
            Door.Moved(true);
        }
        if (self.CheckNoise) {
            Door.RegisterInterestedInDoorOpening(self);
            DoorSensors[ DoorSensors.Length ] = Door;
        }
    }
    self.GoalBase = new class'SVGoalBase'(Level);
    self.SetTimer(1.0, true);
}

protected function bool PointsNear(array<Actor> Points, Actor Target, bool dotrace, optional float mindist) {
    local int i;
    local float distance;

    for (i=0; i < Points.Length; i++) {
        if (dotrace) {
            if (FastTrace(Points[i].Location, Target.Location)) {
                return true;
            }
        } else {
            distance = VSize2D(Points[i].Location - Target.Location);
            if (distance < mindist) {
                return true;
            }
        }
    }
    return false;
}

protected function bool PlayersNear(array<PlayerController> Players, Actor Target) {
    local bool near;
    local int i;
    for (i = 0; i < Players.Length; i++) {
        near = Players[i].Pawn.LineOfSightTo(Target);
        if (near) return true;
    }
    return false;
}

protected function bool PlayersInRange(vector Point, float range) {
    local PlayerController Player;
    foreach DynamicActors(class'PlayerController', Player) {
        if (class'Pawn'.static.checkConscious(Player.Pawn)
        && VSize(Point - Player.Pawn.Location) < range) {
            return true;
        }
    }
    return false;
}

protected function Actor PointSpawn(name ArchetypeName, Actor Point) {
    local EnemyArchetype Archetype;
    local class<Actor> ClassToSpawn;
    local Actor Spawned;

    Archetype = new(None, string(ArchetypeName), 0) class'EnemyArchetype';
    if (Archetype == None) {
        return None;
    }
    Archetype.Initialize(Level);
    if (self.EnemySkill >= 0) {
        switch (self.EnemySkill) {
            case 0: Archetype.Skill[0].Skill = EnemySkill_Low; break;
            case 1: Archetype.Skill[0].Skill = EnemySkill_Medium; break;
            case 2: Archetype.Skill[0].Skill = EnemySkill_High; break;
            default: Archetype.Skill[0].Skill = EnemySkill_High;
        }
        Archetype.Skill[0].Chance = 100;
        while (Archetype.Skill.Length > 1) {
            Archetype.Skill.Remove(1, 1);
        }
    }
    if (self.EnemyMinMorale >= 0) {
        Archetype.Morale.Min = self.EnemyMinMorale;
    }
    if (self.EnemyMaxMorale >= 0) {
        Archetype.Morale.Max = self.EnemyMaxMorale;
    }

    ClassToSpawn = Archetype.PickClass();
    Spawned = Spawn(ClassToSpawn,,, Point.Location);
    if (Spawned == None) {
        return None;
    }
    Archetype.InitializeSpawned(IUseArchetype(Spawned), None);
    return Spawned;
}

event Timer() {
    local int i, num;
    local EnemySpawner Spawner;
    local string type;
    local array<PlayerController> Players;
    local PlayerController Player;
    local SwatRepo Repo;
    local Actor Point, Spawned;

    Repo = SwatRepo(Level.GetRepo());
    if (Repo.GuiConfig.CurrentMission.IsMissionCompleted()) {
        self.Destroy();
    }
    if (Repo.GuiConfig.SwatGameState != GAMESTATE_MidGame) {
        return;
    }
    if (!self.SkipBanner) {
        Level.Game.Broadcast(None, "[c=ffffff][b]Survival Mod v"$ VERSION $"[\\b] is loaded.", 'Caption');
        self.SkipBanner = True;
    }
    GoalBase.UpdateState();

    if (self.SpawnTimer > 0) {
        self.SpawnTimer--;
        if (self.SpawnTimer <= 0) {
            num = 0;
            i = 0;
            Level.Game.Broadcast(None, '', 'SuspectsRespawnEvent');
            foreach DynamicActors(class'PlayerController', Player) {
                if (class'Pawn'.static.checkConscious(Player.Pawn)) {
                    Players[i] = Player;
                    i++;
                }
            }
            for (i = 0; num < self.TotalSuspects * self.WaveSize && i < MAX_ITER; i++) {
                if (self.LevelArchetypes.Length > 0) {
                    type = self.LevelArchetypes[ Rand(self.LevelArchetypes.Length) ];
                } else {
                    type = self.Archetypes[ Rand(self.Archetypes.Length) ];
                }
                Spawned = None;
                
                if (i % 2 == 0 && AllPoints.Length >= 4) {
                    Point = AllPoints[ Rand(AllPoints.Length) ];
                    if (!self.PlayersNear(Players, Point)) {
                        Spawned = PointSpawn(name(type), Point);
                    }
                } else {
                    Spawner = AllSpawns[ Rand(AllSpawns.Length) ];
                    Point = Spawner;
                    if (!self.PlayersNear(Players, Spawner) || i >= MAX_ITER/2) {
                        Spawned = Spawner.SpawnArchetype(name(type), false);
                    }
                }
                if (Spawned != None) {
                    log("SurvivalMod wave added " $ type $ " at " $ Point);
                    num++;
                }
            }
            ProcKill.TotalEnemies=0;
            ProcIncap.TotalEnemies=0;
            ProcArrest.TotalEnemies=0;
            ProcKill.OnGameStarted();
            ProcIncap.OnGameStarted();
            ProcArrest.OnGameStarted();
            log("SurvivalMod wave spawned " $ num $ " suspects");
            
            self.WavesLeft--;
            if (self.WavesLeft > 1) {
                Level.Game.Broadcast(None, "[c=ff0000]The suspects still have " $ self.WavesLeft
                    $ " waves of reinforcements available.", 'Caption');
            } else if (self.WavesLeft == 1) {
                Level.Game.Broadcast(None,
                    "[c=ff0000]The suspects still have one wave of reinforcements available.", 'Caption');
            } else if (self.WavesLeft == 0) {
                Level.Game.Broadcast(None,
                    "[c=00ff00]Good! The suspects have run out of reinforcements.", 'Caption');
            }
        }
    }
}

protected function CheckWaveSpawn() {
    local int alive;
    local SwatEnemy Enemy;

    if (self.WavesLeft <= 0 || self.SpawnTimer > 0) {
        return;
    }
    alive = 0;
    foreach DynamicActors(class'SwatEnemy', Enemy) {
        if (Enemy.IsConscious() && !Enemy.IsArrested()) {
            alive++;
        }
    }
    if (alive < self.TotalSuspects * self.WaveTrigger) {
        self.SpawnTimer = 10;
        Level.Game.Broadcast(None, '', 'TenSecWarning');
    }
}

protected function bool IsAliveIdle(SwatEnemy Enemy) {
    return Enemy.IsConscious() && !Enemy.IsArrested()
        && Enemy.HasUsableWeapon() && !Enemy.IsA('SwatUndercover')
        && (Enemy.GetCurrentState() != EnemyState_Aware
        || Enemy.GetEnemyCommanderAction().GetCurrentEnemy() == None);
}

protected function InvestigateNoise(Actor Source, float MaxRange) {
    local int i, Eid, Doors;
    local float Time, NoiseRange, ClosestRange, DoorRange;
    local SwatEnemy Enemy;
    local Door ClosestDoor;
    local SwatMPStartPoint StartPoint;

    if (!self.CheckNoise) {
        return;
    }
    Eid = 0;
    Time = Level.TimeSeconds;

    foreach DynamicActors(class'SwatEnemy', Enemy) {
        if (IsAliveIdle(Enemy) && !Enemy.CanHit(Source) 
        && Time - GoalBase.GetTime(Eid) > 30.0) {
            NoiseRange = VSize(Enemy.Location - Source.Location);
            if (NoiseRange > RandRange(MaxRange/4, MaxRange)) {
                continue;
            }
            ClosestRange = 1200;
            Doors = 0;
            for (i = 0; i < AllDoorWays.Length; i++) {
                if (AllDoorWays[i].RightInternalRoomName == Enemy.GetRoomName()
                || AllDoorWays[i].LeftInternalRoomName == Enemy.GetRoomName()) {
                    DoorRange = VSize2D(AllDoorWays[i].Location - Source.Location);
                    Doors++;
                    if (DoorRange < ClosestRange) {
                        ClosestDoor = AllDoorWays[i];
                        ClosestRange = DoorRange;
                    }
                }
            }
            if (GoalBase.AllowMove(Eid) && Rand(4) == 0) {
                StartPoint = StartPoints[ Rand(StartPoints.Length) ];
                if (StartPoint != None && NoiseRange > 600 && Rand(2) == 0)  {
                    GoalBase.AddInvestigate(Enemy, StartPoint);
                } else {
                    GoalBase.AddInvestigate(Enemy, Source);
                }
            } else if (ClosestDoor != None && ClosestRange < RandRange(0, 1000)
            && ClosestRange < VSize2D(Enemy.Location - Source.Location)) {
                if (Doors > 1) {
                    GoalBase.AddCoverThreat(Enemy, ClosestDoor, 30, false, NoiseRange > 300);
                } else {
                    GoalBase.AddCoverThreat(Enemy, ClosestDoor, 60, false, NoiseRange > 200);
                }
            } else {
                GoalBase.AddAimAround(Enemy, Source, 30);
            }
            GoalBase.SetTime(Eid, Time);
        }
        Eid++;
    }
}

function NotifyDoorOpening(SwatDoor Door) {
    local int Eid;
    local float Time;
    local SwatEnemy Enemy;

    if (!PlayersInRange(Door.Location, 200.0)) {
        return;
    }
    Time = Level.TimeSeconds;
    Eid = 0;
    foreach DynamicActors(class'SwatEnemy', Enemy) {
        if (IsAliveIdle(Enemy) && Time - GoalBase.GetTime(Eid) > 8.0
        && VSize(Door.Location - Enemy.Location) < 800.0
        && (Enemy.CanHit(Door) || !GoalBase.HasActiveGoals(Enemy))
        && (Enemy.GetRoomName() == Door.LeftInternalRoomName
        || Enemy.GetRoomName() == Door.RightInternalRoomName)) {
            GoalBase.AddCoverThreat(Enemy, Door, 30, true, false);
            GoalBase.SetTime(Eid, Time);
        }
        Eid++;
    }
}

function OnPawnDied(Pawn Target, Actor Source, bool WasAThreat) {
    if (Target.IsA('SwatEnemy')) {
        CheckWaveSpawn();
        if (Source.IsA('NetPlayerCoop')) {
            InvestigateNoise(Source, 1600);
        }
    }
}

function OnPawnIncapacitated(Pawn Target, Actor Source, bool WasAThreat) {
    if (Target.IsA('SwatEnemy')) {
        CheckWaveSpawn();
        if (Source.IsA('NetPlayerCoop')) {
            InvestigateNoise(Source, 1600);
        }
    }
}

function OnPawnArrested(Pawn Target, Pawn Source) {
    if (Target.IsA('SwatEnemy')) {
        CheckWaveSpawn();
        if (Source.IsA('NetPlayerCoop')) {
            InvestigateNoise(Source, 1000);
        }
    }
}

function OnPawnDamaged(Pawn Target, Actor Source) {
    // This removes use of force penalties only when suspects have not surrendered
    if (!self.ForcePenalties && Target.IsA('SwatEnemy')) {
        SwatEnemy(Target).BecomeAThreat();
    }
}

