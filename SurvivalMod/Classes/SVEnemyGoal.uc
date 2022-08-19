
class SVEnemyGoal extends SwatAICommon.SwatWeaponGoal
    implements Engine.IInterestedPawnDied;

var public SwatEnemy Enemy;
var public Actor Target;
var public float EndTime;
var private LevelInfo Level;
var private AI_Goal Goal;
var private EnemyCommanderAction EnemyCmd;


overloaded function construct() {
    assert(false);
}

overloaded function construct(SwatEnemy Enemy, Actor Target) {
    self.Goal = None;
    self.Target = Target;
    self.Enemy = Enemy;
    self.Level = Enemy.Level;
    self.EnemyCmd = Enemy.GetEnemyCommanderAction();
    Level.RegisterNotifyPawnDied(self);
    log("EnemyGoal "$Enemy$" Create "$Target);
}

function Cleanup() {
    Level.UnregisterNotifyPawnDied(self);
    if (Goal == None) { // Avoid double delete issue
        return;
    }
    log("EnemyGoal "$Enemy$" Cleanup "$Goal);
    Goal.unPostGoal(EnemyCmd);
    Goal.Release();
    Goal = None;
}

function OnOtherPawnDied(Pawn DeadPawn) {
    self.Cleanup();
}

function bool IsDone() {
    return Level.TimeSeconds >= EndTime;
}

function Investigate() {
    EndTime = Enemy.Level.TimeSeconds + 30;
    EnemyCmd.CreateInvestigateGoal(Target.Location);
    log("EnemyGoal "$Enemy$" Investigate "$Target);
}

function AimAround(float MaxTime) {
    if (Goal != None) {
        return;
    }
    EndTime = Enemy.Level.TimeSeconds + MaxTime;
    Goal = new class'AimAroundGoal'(EnemyCmd.movementResource(), 40);
    Goal.bRemoveGoalOfSameType = true;
    Goal.AddRef();
    Goal.postGoal(EnemyCmd);
    log("EnemyGoal "$Enemy$" AimAround "$Target);
}

function CoverThreat(float MaxTime, bool AllowShoot, bool AllowCrouch) {
    local int Threat;
    if (Goal != None) {
        return;
    }
    EndTime = Level.TimeSeconds + 2;
    Threat = Rand(4) + int(Enemy.GetCurrentState() > EnemyState_Unaware);

    if (Enemy.GetPrimaryWeapon() == None) {
        Goal = new class'RotateTowardRotationGoal'(
            EnemyCmd.movementResource(), 50, rotator(Target.Location - Enemy.Location));
    } else {
        if (AllowShoot && Enemy.CanHit(Target) && Threat > 2) {
            Goal = new class'AttackTargetGoal'(EnemyCmd.weaponResource(), 70, Target);
            EndTime = Level.TimeSeconds + RandRange(2, 4);

        } else if (Rand(4) == 0) {
            Goal = new class'BarricadeGoal'(EnemyCmd.weaponResource(), Target.Location, true, false);
            EndTime = Level.TimeSeconds + RandRange(MaxTime/2, MaxTime);

        } else {
            Goal = new class'AimAtTargetGoal'(EnemyCmd.weaponResource(), 60, Target);
            EndTime = Level.TimeSeconds + RandRange(MaxTime/5, MaxTime);

            if (AllowCrouch && Rand(2) == 0) {
                Enemy.ShouldCrouch(true);
            }
        }
    }
    Goal.bRemoveGoalOfSameType = true;
    Goal.AddRef();
    Goal.postGoal(EnemyCmd);
    log("EnemyGoal "$Enemy$" CoverThreat "$Goal);
}


