//************************
// Projectiles being hittable by LC subengine
//************************
class LCProjSN expands SpawnNotify;

var XC_LagCompensation Mutator;

event Actor SpawnNotification( Actor A)
{
	local XC_PosList PosList;
	
	// TODO: Delay spawn until AFTER SpawnNotification
	if ( A.Class == class'RocketMk2' )
		A = ReplaceRocket( RocketMk2(A) );

	if ( !A.bNetTemporary && A.bProjTarget && (A.CollisionHeight > 0) && (A.CollisionRadius > 0) )
	{
		PosList = Mutator.SetupPosList( A);
		PosList.bPingHandicap = true;
		if ( (Projectile(A).Damage != 0) && (A.bNetTemporary || A.RemoteRole == ROLE_SimulatedProxy) ) 
			PosList.bClientAdvance = true;
	}
	return A;
}

function LCRocketMk2 ReplaceRocket( RocketMk2 R)
{
	local LCRocketMk2 NewRocket;
	
	// TODO: Guided Rocket
	NewRocket = Spawn( class'LCRocketMk2', R.Owner, R.Tag, R.Location, R.Rotation);
	NewRocket.Velocity = R.Velocity;
	NewRocket.Speed = R.Speed;
	NewRocket.Mesh = R.Mesh;
	NewRocket.Instigator = R.Instigator;
	R.Destroy();
	
	return NewRocket;
}


defaultproperties
{
	ActorClass=class'Projectile'
	RemoteRole=ROLE_None
}