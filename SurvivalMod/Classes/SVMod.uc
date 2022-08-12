/*
 ****************************************
 * SWAT 4 COOP Survival Mod by Induktio *
 ****************************************
 */

class SVMod extends SwatGame.SwatMutator
    implements IInterested_GameEvent_PawnDied,
               IInterested_GameEvent_PawnIncapacitated,
               IInterested_GameEvent_PawnArrested,
               IInterested_GameEvent_PawnDamaged;

const VERSION = "1.2";
const MAX_ITER = 200;

var config bool Enabled;
var config bool CheckNoise;
var config bool ForcePenalties;
var config int RandomDoors;
var config int AmountMin;
var config int AmountExtra;
var config int WaveSpawns;
var config float WaveTrigger;
var config float WaveSize;
var config float MinDistance;
var config array<string> Archetypes;

var protected int WavesLeft;
var protected int SpawnTimer;
var protected int TotalSuspects;
var protected array<EnemySpawner> AllSpawns;
var protected array<Actor> AllPoints;
var protected array<float> GoalUpdateTime;
var protected Procedure_KillSuspects ProcKill;
var protected Procedure_ArrestIncapacitatedSuspects ProcIncap;
var protected Procedure_ArrestUnIncapacitatedSuspects ProcArrest;
var protected SwatGameInfo Game;

defaultproperties
{
    Enabled = True
    CheckNoise = True
    ForcePenalties = True
    RandomDoors = 25
    AmountMin = 10
    AmountExtra = 10
    WaveSpawns = 0
}


public function PreBeginPlay() {
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
    self.Game.GameEvents.PawnDied.UnRegister(self);
    self.Game.GameEvents.PawnIncapacitated.UnRegister(self);
    self.Game.GameEvents.PawnArrested.UnRegister(self);
    self.Game.GameEvents.PawnDamaged.UnRegister(self);
}

event Destroyed() {
    log("SurvivalMod is about to be closed");
    Super.Destroyed();
}

public function PostBeginPlay() {
    local int i, num, minimum;
    local string type;
    local bool usable;
    local EnemySpawner Spawner;
    local NavigationPoint Iter;
    local SwatDoor Door;
    local SwatRepo Repo;
    local Procedure Proc;
    local array<SwatMPStartPoint> StartPoints;
    local SwatMPStartPoint StartPoint;
    local Actor Target;
    local PathNode Node;

    Super.PostBeginPlay();
    self.WavesLeft = self.WaveSpawns;
    self.SpawnTimer = 0;
    self.TotalSuspects = 0;

    self.Game = SwatGameInfo(Level.Game);
    self.Game.GameEvents.PawnDied.Register(self);
    self.Game.GameEvents.PawnIncapacitated.Register(self);
    self.Game.GameEvents.PawnArrested.Register(self);
    self.Game.GameEvents.PawnDamaged.Register(self);

    log("SurvivalMod v" $ class'SVMod'.const.VERSION $ " by Induktio has been loaded");
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
    
    for (i = 0; num < minimum + self.AmountExtra && i < class'SVMod'.const.MAX_ITER; i++) {
        type = self.Archetypes[ Rand(self.Archetypes.Length) ];
        if (i % 2 == 0 && AllPoints.Length >= 4) {
            Target = AllPoints[ Rand(AllPoints.Length) ];
            usable = (!PointsNear(StartPoints, Target, true) || i >= class'SVMod'.const.MAX_ITER/2);
            if (usable && PointSpawn(name(type), Target) != None) {
                log("SurvivalMod added " $ type $ " at " $ Target);
                self.TotalSuspects++;
                num++;
            }
        } else {
            Spawner = AllSpawns[ Rand(AllSpawns.Length) ];
            usable = ((Spawner.MissionSpawn == MissionSpawn_Any && Spawner.StartPointDependent == StartPoint_Any)
                || i >= class'SVMod'.const.MAX_ITER/2);
            
            if (!Spawner.HasSpawned && usable && Spawner.SpawnArchetype(name(type), false) != None) {
                log("SurvivalMod added " $ type $ " at " $ Spawner);
                self.TotalSuspects++;
                num++;
            }
        }
    }
    log("SurvivalMod TotalSuspects=" $ self.TotalSuspects $ " NewSuspects=" $ num);
    
    if (self.RandomDoors > 0) {
        for(Iter = Level.navigationPointList; Iter != None; Iter = Iter.nextNavigationPoint) {
            Door = SwatDoor(Iter);

            if (Door != None && Door.bIsAntiPortal) {
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
        }
    }
    if (self.WaveSpawns > 0) {
        self.SetTimer(1.0, true);
    }
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
        near = Players[i].LineOfSightTo(Target);
        if (near) return true;
    }
    return false;
}

protected function Actor PointSpawn(name ArchetypeName, Actor Point) {
    local Archetype Archetype;
    local class<Actor> ClassToSpawn;
    local Actor Spawned;

    Archetype = new(None, string(ArchetypeName), 0) class'EnemyArchetype';
    if (Archetype == None) {
        return None;
    }
    Archetype.Initialize(Level);
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
    if (self.ForcePenalties && !self.CheckNoise && self.WavesLeft == 0) {
        self.Destroy();
    }

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
            for (i = 0; num < self.TotalSuspects * self.WaveSize && i < class'SVMod'.const.MAX_ITER; i++) {
                type = self.Archetypes[ Rand(self.Archetypes.Length) ];
                Spawned = None;
                
                if (i % 2 == 0 && AllPoints.Length >= 4) {
                    Point = AllPoints[ Rand(AllPoints.Length) ];
                    if (!self.PlayersNear(Players, Point)) {
                        Spawned = PointSpawn(name(type), Point);
                    }
                } else {
                    Spawner = AllSpawns[ Rand(AllSpawns.Length) ];
                    Point = Spawner;
                    if (!self.PlayersNear(Players, Spawner) || i >= class'SVMod'.const.MAX_ITER/2) {
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
            if (self.WavesLeft > 0) {
                Level.Game.Broadcast(None, "[c=ff0000]The suspects still have " $ self.WavesLeft
                    $ " waves of reinforcements available.", 'Caption');
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

protected function InvestigateNoise(Actor Source) {
    local int i;
    local float time;
    local SwatEnemy Enemy;
    local EnemyCommanderAction EnemyCmd;
    if (!self.CheckNoise) {
        return;
    }
    i = 0;
    time = Level.TimeSeconds;

    foreach DynamicActors(class'SwatEnemy', Enemy) {
        if ((GoalUpdateTime[i] == 0 || time - GoalUpdateTime[i] > 60.0)
        && Enemy.IsConscious() && !Enemy.IsArrested() && Rand(8) == 0) {
            EnemyCmd = Enemy.GetEnemyCommanderAction();
            EnemyCmd.CreateInvestigateGoal(Source.Location);
            GoalUpdateTime[i] = time;
        }
        i++;
    }
}

function OnPawnDied(Pawn Target, Actor Source, bool WasAThreat) {
    if (Target.IsA('SwatEnemy')) {
        CheckWaveSpawn();
        if (Source.IsA('NetPlayerCoop')) {
            InvestigateNoise(Source);
        }
    }
}

function OnPawnIncapacitated(Pawn Target, Actor Source, bool WasAThreat) {
    if (Target.IsA('SwatEnemy')) {
        CheckWaveSpawn();
        if (Source.IsA('NetPlayerCoop')) {
            InvestigateNoise(Source);
        }
    }
}

function OnPawnArrested(Pawn Target, Pawn Source) {
    if (Target.IsA('SwatEnemy')) {
        CheckWaveSpawn();
    }
}

function OnPawnDamaged(Pawn Target, Actor Source) {
    // This removes use of force penalties only when suspects have not surrendered
    if (!self.ForcePenalties && Target.IsA('SwatEnemy')) {
        SwatEnemy(Target).BecomeAThreat();
    }
}

