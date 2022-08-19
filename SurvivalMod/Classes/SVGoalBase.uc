
class SVGoalBase extends Core.Object;

var protected array<int> AllowMoveOrders;
var protected array<float> Updated;
var protected array<SVEnemyGoal> ActiveGoals;
var protected LevelInfo Level;


overloaded function construct() {
    assert(false);
}

overloaded function construct(LevelInfo Level) {
    self.Level = Level;
}

function ClearAllGoals() {
    while (ActiveGoals.Length > 0) {
        ActiveGoals[0].Cleanup();
        ActiveGoals.Remove(0, 1);
    }
}

function UpdateState() {
    local int i;
    i = 0;
    while (i < ActiveGoals.Length) {
        if (ActiveGoals[i].IsDone()) {
            ActiveGoals[i].Cleanup();
            ActiveGoals.Remove(i, 1);
            continue;
        }
        i++;
    }
}

function float GetTime(int i) {
    if (Updated.Length <= i || Updated[i] == 0) {
        Updated[i] = -60;
        AllowMoveOrders[i] = Rand(2);
    }
    return Updated[i];
}

function SetTime(int i, float time) {
    Updated[i] = time;
}

function bool HasActiveGoals(SwatEnemy Enemy) {
    local int i;
    for (i = 0; i < ActiveGoals.Length; i++) {
        if (ActiveGoals[i].Enemy == Enemy && ActiveGoals[i].EndTime > Level.TimeSeconds) {
            return True;
        }
    }
    return False;
}

function bool AllowMove(int i) {
    return AllowMoveOrders[i] > 0;
}

function AddInvestigate(SwatEnemy Enemy, Actor Target) {
    local int i;
    i = ActiveGoals.Length;
    ActiveGoals[i] = new class'SVEnemyGoal'(Enemy, Target);
    ActiveGoals[i].Investigate();
}

function AddAimAround(SwatEnemy Enemy, Actor Target, float MaxTime) {
    local int i;
    i = ActiveGoals.Length;
    ActiveGoals[i] = new class'SVEnemyGoal'(Enemy, Target);
    ActiveGoals[i].AimAround(MaxTime);
}

function AddCoverThreat(SwatEnemy Enemy, Actor Target, float MaxTime, bool AllowShoot, bool AllowCrouch) {
    local int i;
    i = ActiveGoals.Length;
    ActiveGoals[i] = new class'SVEnemyGoal'(Enemy, Target);
    ActiveGoals[i].CoverThreat(MaxTime, AllowShoot, AllowCrouch);
}

