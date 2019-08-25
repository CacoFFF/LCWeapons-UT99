class FV_ImpactMark expands ImpactMark;

var bool bIsLC;

replication
{
	reliable if ( bNetOwner && (Role==ROLE_Authority) )
		bIsLC;
}

simulated event PostNetBeginPlay()
{
	if ( bIsLC && (Owner != None) && (Owner.Role == ROLE_AutonomousProxy) )
	{
		bHidden = true;
		LightType = LT_None;
		LifeSpan = 0.001;
		Disable('Tick');
	}
}
