class FV_SpriteBallExplosion expands UT_SpriteBallExplosion;

var bool bIsLC;

replication
{
	reliable if ( bNetOwner && (Role==ROLE_Authority) )
		bIsLC;
}

//Processed by authoritative client or server
function PostBeginPlay()
{
	Super.PostBeginPlay();		
}

//Processed by remote client
simulated function PostNetBeginPlay()
{
	if ( bIsLC && (Owner != None) && (Owner.Role == ROLE_AutonomousProxy) )
	{
		bHidden = true;
		LightType = LT_None;
		LifeSpan = 0.001;
		SetPhysics( PHYS_None);
		return;
	}
	
	if ( !Level.bDropDetail )
		Texture = SpriteAnim[Rand(3)];	

	if ( Level.bHighDetailMode && !Level.bDropDetail ) 
		SetTimer( 0.05 + FRand() * 0.04, false);
	else
		LightRadius = 6;
}

simulated Function Timer()
{
	local FV_SpriteBallChild Child;

	if ( !Level.bDropDetail )
	{
		if ( FRand() < 0.4 + (MissCount - 1.5 * ExpCount) * 0.25 )
		{
			ExpCount++;
			Child = Spawn( class'FV_SpriteBallChild', Owner, '', Location + (Vect(0,0,1) * FRand() * RandRange(10,20)) );
			if ( bIsLC )
			{
				Child.bIsLC = true;
				Child.SetPropertyText("bNotRelevantToOwner","1");
			}
		}
		else
			MissCount++;
		if ( (ExpCount < 3) && (LifeSpan > 0.45) ) 
			SetTimer(0.05+FRand()*0.05,False);
	}
}

//Actor requires owner (temporarily)
//If LCWeapons wants to then hide the effect, set the owner again.
function MakeSound()
{
	PlayOwnedSound( EffectSound1,,12.0,,2200);
	SetOwner( None);
}
