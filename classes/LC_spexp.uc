//=============================================================================
// spexp.
// Liandri Minigun explosion effect
//=============================================================================
class LC_spexp expands UT_SpriteBallExplosion;

simulated Function Timer()
{
}

simulated function PostBeginPlay()
{
	MakeSound();
	if ( !Level.bDropDetail )
		Texture = SpriteAnim[Rand(3)];	
	if ( (Level.NetMode!=NM_DedicatedServer) && Level.bHighDetailMode && !Level.bDropDetail ) 
	{
	}
	else
		LightRadius = 6;
	Super(AnimSpriteEffect).PostBeginPlay();		
}

simulated function MakeSound()
{
	PlayOwnedSound(EffectSound1,,12.0,,2200);
}

simulated event PostNetBeginPlay()
{
	bOwnerNoSee = True;
	if ( (Role==Default.RemoteRole) && (Owner != none) && (Owner.Role == ROLE_AutonomousProxy) )
		Destroy();
}


defaultproperties
{
     DrawScale=0.150000
     LightRadius=4
//     bOwnerNoSee=True
}
