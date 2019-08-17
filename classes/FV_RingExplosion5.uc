class FV_RingExplosion5 expands UT_RingExplosion5;

var bool bIsLC;

replication
{
	reliable if ( bNetOwner && (Role==ROLE_Authority) )
		bIsLC;
}

//Run normally on server/LC simulation
event PostBeginPlay()
{
	Super.PostBeginPlay();
}

//Run on net client
simulated event PostNetBeginPlay()
{
	//Kill if owned client
	if ( bIsLC && (Owner != None) && (Owner.Role == ROLE_AutonomousProxy) )
	{
		bHidden = true;
		LifeSpan = 0.001;
		return;
	}
	PlayAnim( 'Explo', 0.35, 0.0);
	SpawnEffects();
}

simulated function SpawnEffects()
{
	Spawn(class'ShockExplo').RemoteRole = ROLE_None;
}

simulated function SpawnExtraEffects()
{
	Spawn(class'EnergyImpact').RemoteRole = ROLE_None;
	bExtraEffectsSpawned = true;
}

