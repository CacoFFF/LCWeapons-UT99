//************************
// Projectiles being hittable by LC subengine
//************************
class LCProjSN expands SpawnNotify;

var XC_LagCompensation Mutator;

event Actor SpawnNotification( Actor A)
{
	local XC_PosList PosList;
	if ( !A.bNetTemporary && A.bProjTarget && (A.CollisionHeight > 0) && (A.CollisionRadius > 0) )
	{
		PosList = Mutator.SetupPosList( A);
		PosList.bPingHandicap = true;
		if ( (Projectile(A).Damage != 0) && (A.bNetTemporary || A.RemoteRole == ROLE_SimulatedProxy) ) 
			PosList.bClientAdvance = true;
	}
	return A;
}


defaultproperties
{
	ActorClass=class'Projectile'
	RemoteRole=ROLE_None
}