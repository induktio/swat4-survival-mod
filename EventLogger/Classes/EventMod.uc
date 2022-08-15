/*
 ****************************************
 * SWAT 4 COOP Event Logger by Induktio *
 ****************************************
 */

class EventMod extends SwatGame.SwatMutator
    implements IInterested_GameEvent_MissionStarted,
               IInterested_GameEvent_MissionEnded,
               IInterested_GameEvent_BombDisabled,
               IInterested_GameEvent_PawnDied,
               IInterested_GameEvent_PawnIncapacitated,
               IInterested_GameEvent_PawnArrested;

var private SwatGameInfo Game;
var private float StartTime;

public function PreBeginPlay() {
    Super.PreBeginPlay();
    
    if (Level.NetMode == NM_ListenServer || Level.NetMode == NM_DedicatedServer) {
        if (Level.Game != None && SwatGameInfo(Level.Game) != None && Level.IsCOOPServer) {
            return;
        }
    }
    self.Destroy();
}

public function PostBeginPlay() {
    Super.PostBeginPlay();
    self.Game = SwatGameInfo(Level.Game);
    self.Game.GameEvents.MissionStarted.Register(self);
    self.Game.GameEvents.MissionEnded.Register(self);
    self.Game.GameEvents.BombDisabled.Register(self);
    self.Game.GameEvents.PawnDied.Register(self);
    self.Game.GameEvents.PawnIncapacitated.Register(self);
    self.Game.GameEvents.PawnArrested.Register(self);
    log("COOP Event Logger by Induktio has been loaded");
}

function UnRegisterGameEventsHook() {
    self.Game.GameEvents.MissionStarted.UnRegister(self);
    self.Game.GameEvents.MissionEnded.UnRegister(self);
    self.Game.GameEvents.BombDisabled.UnRegister(self);
    self.Game.GameEvents.PawnDied.UnRegister(self);
    self.Game.GameEvents.PawnIncapacitated.UnRegister(self);
    self.Game.GameEvents.PawnArrested.UnRegister(self);
}

function OnMissionStarted() {
    self.StartTime = Level.TimeSeconds;
}

function OnMissionEnded() {
    local float spent;
    local int minutes, seconds;
    self.UnRegisterGameEventsHook();
    
    spent = Level.TimeSeconds-self.StartTime;
    minutes = int(spent / 60);
    seconds = int(spent % 60);
    
    Level.Game.Broadcast(None, 
        "[c=ffffff][b]Mission time:[\\b] " $ minutes $ " minutes, " $ seconds $ " seconds.", 'Caption');
    self.SetTimer(900.0, true);
}

event Timer() {
    SwatRepo(Level.GetRepo()).NetSwitchLevels(true);
}

function string Format(string f, optional coerce string p1, optional coerce string p2, optional coerce string p3) {
    return class'GUI'.static.FormatTextString(f, p1, p2, p3);
}

function Display(name type, optional string player, optional string weapon) {
    local string msg;

    switch (type) {
        case 'EnemyTeamKill':
            msg = Format("[c=ff0000][b]A suspect[\\b] killed [b]a suspect[\\b]!");
            break;
        case 'EnemyHostageKill':
            msg = Format("[c=ff0000][b]A suspect[\\b] killed [b]a hostage[\\b]!");
            break;
        case 'EnemyHostageIncap':
            msg = Format("[c=ff0000][b]A suspect[\\b] incapacitated [b]a hostage[\\b]!");
            break;
        case 'EnemyPlayerKill':
            msg = Format("[c=ff0000][b]%1[\\b] is down!", player);
            break;
        case 'PlayerEnemyKill':
            msg = Format("[c=0000ff][b]%1[\\b] neutralized [b]a suspect[\\b] with a %2!", player, weapon);
            break;
        case 'PlayerEnemyKillInvalid':
            msg = Format("[c=0000ff][b]%1[\\b] neutralized [b]a suspect[\\b] with a %2 (unauthorized)!", player, weapon);
            break;
        case 'PlayerEnemyIncap':
            msg = Format("[c=0000ff][b]%1[\\b] incapacitated [b]a suspect[\\b] with a %2!", player, weapon);
            break;
        case 'PlayerEnemyIncapInvalid':
            msg = Format("[c=0000ff][b]%1[\\b] incapacitated [b]a suspect[\\b] with a %2 (unauthorized)!", player, weapon);
            break;
        case 'PlayerHostageKill':
            msg = Format("[c=ff0000][b]%1[\\b] killed [b]a hostage[\\b] with a %2!", player, weapon);
            break;
        case 'PlayerHostageIncap':
            msg = Format("[c=ff0000][b]%1[\\b] incapacitated [b]a hostage[\\b] with a %2!", player, weapon);
            break;
        case 'PlayerEnemyArrest':
            msg = Format("[c=0000ff][b]%1[\\b] arrested [b]a suspect[\\b]!", player);
            break;
        case 'PlayerHostageArrest':
            msg = Format("[c=0000ff][b]%1[\\b] arrested [b]a hostage[\\b]!", player);
            break;
        case 'PlayerBombDefused':
            msg = Format("[c=0000ff][b]%1[\\b] defused [b]a bomb[\\b]!", player);
            break;
        default:
            return;
    }
    Level.Game.Broadcast(None, msg, 'Caption');
}

function string GetWeapon(NetPlayer player) {
    if (player.GetActiveItem().IsA('Detonator')) {
        return "C2 Charge";
    } else {
        return player.GetActiveItem().GetFriendlyName();
    }
}

function OnPawnDied(Pawn Target, Actor Source, bool WasAThreat) {
    local string weapon;

    if (Source.IsA('SwatEnemy')) {
        if (Target.IsA('SwatEnemy')) {
            Display('EnemyTeamKill');
        } else if (Target.IsA('SwatHostage'))  {
            Display('EnemyHostageKill');
        } else {
            Display('EnemyPlayerKill', Target.GetHumanReadableName());
        }
    } else if (Source.IsA('NetPlayerCoop')) {
        weapon = GetWeapon(NetPlayer(Source));
        
        if (Target.IsA('SwatEnemy')) {
            if (WasAThreat) {
                Display('PlayerEnemyKill', Source.GetHumanReadableName(), weapon);
            } else {
                Display('PlayerEnemyKillInvalid', Source.GetHumanReadableName(), weapon);
            }
        } else if (Target.IsA('SwatHostage'))  {
            Display('PlayerHostageKill', Source.GetHumanReadableName(), weapon);
        }
    }
}

function OnPawnIncapacitated(Pawn Target, Actor Source, bool WasAThreat) {
    local string weapon;

    if (Source.IsA('SwatEnemy')) {
        if (Target.IsA('SwatEnemy')) {
            Display('EnemyTeamKill');
        } else if (Target.IsA('SwatHostage'))  {
            Display('EnemyHostageIncap');
        } else {
            Display('EnemyPlayerKill', Target.GetHumanReadableName());
        }
    } else if (Source.IsA('NetPlayerCoop')) {
        weapon = GetWeapon(NetPlayer(Source));
        
        if (Target.IsA('SwatEnemy')) {
            if (WasAThreat) {
                Display('PlayerEnemyIncap', Source.GetHumanReadableName(), weapon);
            } else {
                Display('PlayerEnemyIncapInvalid', Source.GetHumanReadableName(), weapon);
            }
        } else if (Target.IsA('SwatHostage'))  {
            Display('PlayerHostageIncap', Source.GetHumanReadableName(), weapon);
        }
    }
}

function OnPawnArrested(Pawn Target, Pawn Source) {

    if (Target.IsA('SwatEnemy')) {
        Display('PlayerEnemyArrest', Source.GetHumanReadableName());
    } else if (Target.IsA('SwatHostage')) {
        Display('PlayerHostageArrest', Source.GetHumanReadableName());
    }
}

function OnBombDisabled(BombBase Bomb, Pawn Source) {
    Display('PlayerBombDefused', Source.GetHumanReadableName());
}


