class FV_ShockExplo expands ShockExplo;

var bool bIsLC;

replication
{
	reliable if ( bNetOwner && (Role==ROLE_Authority) )
		bIsLC;
}

//Remove on LC owners
simulated event PostNetBeginPlay()
{
	if ( bIsLC && (Owner != None) && (Owner.Role == ROLE_AutonomousProxy) )
	{
		bOwnerNoSee = true;
		LightType = LT_None;
		LifeSpan = 0.001;
	}
}
