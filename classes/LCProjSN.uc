//************************
// Projectiles being hittable by LC subengine
//************************
class LCProjSN expands SpawnNotify;

var XC_LagCompensation Mutator;

event Actor SpawnNotification( actor A)
{
	if ( !A.bNetTemporary && A.bProjTarget && (A.CollisionHeight > 0) && (A.CollisionRadius > 0) )
		Mutator.AddGenericPos( A).bPingHandicap = true;
	return A;
}


defaultproperties
{
	ActorClass=class'Projectile'
	RemoteRole=ROLE_None
}