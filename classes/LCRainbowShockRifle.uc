class LCRainbowShockRifle expands LCShockRifle;

var int BeamColor;
var class<ShockBeam> RainbowPrototypes[7];
var class<ShockWave> RainbowExplosions[7];
var class<Effects> TmpEffect;

simulated event Spawned()
{
	if ( default.BeamColor == 0 )
		InitializeGraphics();
}


//Beam is edited after hitscan code, so color index should be modified for next shot
simulated function EditBeam( ShockBeam Beam)
{
	if ( default.BeamColor == 0 )
		InitializeGraphics();
	bTeamColor = false;

	if ( (BeamColor < 1) || (BeamColor > 7) )
		BeamColor = 1;
	BeamPrototype = RainbowPrototypes[ BeamColor - 1];
	Super.EditBeam( Beam);
}

//Explosion is spawned after the beam, so beam color should be modified here
simulated function SpawnExplosion( vector HitLocation, vector HitNormal)
{
	if ( (BeamColor < 1) || (BeamColor > 7) )
		BeamColor = 1;
	ExplosionClass = RainbowExplosions[ BeamColor - 1];
	Super.SpawnExplosion( HitLocation, HitNormal);
	BeamColor++;
}


simulated function float GetRange( out int ExtraFlags)
{
	if ( ExtraFlags != 0 )
		BeamColor = ExtraFlags;
	else
		ExtraFlags = BeamColor;
	return 10000;
}


simulated function InitializeGraphics()
{
	local ENetRole OldRole;
	local int i;
	
	default.BeamColor = 1;
	OldRole = Role;
	Role = ROLE_Authority;
	LoadBeamPrototype( 0, "MJD.GreenBeam");
	LoadBeamPrototype( 1, "MJD.CyanBeam");
	LoadBeamPrototype( 2, "MJD.BlueBeam");
	LoadBeamPrototype( 3, "MJD.PinkBeam");
	LoadBeamPrototype( 4, "MJD.RedBeam");
	LoadBeamPrototype( 5, "MJD.OrangeBeam");
	LoadBeamPrototype( 6, "MJD.YellowBeam");
	LoadExplosion( 0, "MJD.GreenShockWave");
	LoadExplosion( 1, "MJD.CyanShockWave");
	LoadExplosion( 2, "MJD.BlueShockWave");
	LoadExplosion( 3, "MJD.PinkShockWave");
	LoadExplosion( 4, "MJD.RedShockWave");
	LoadExplosion( 5, "MJD.OrangeShockWave");
	LoadExplosion( 6, "MJD.YellowShockWave");
	Role = OldRole;
	
	for ( i=0 ; i<7 ; i++ )
	{
		default.RainbowPrototypes[i] = RainbowPrototypes[i];
		default.RainbowExplosions[i] = RainbowExplosions[i];
	}
}

simulated function LoadBeamPrototype( int i, string ProtoClass)
{
	SetPropertyText( "TmpEffect", GetItemName(ProtoClass) );
	if ( class<ShockBeam>(TmpEffect) != None )
		RainbowPrototypes[i] = class<ShockBeam>(TmpEffect);
	else
		RainbowPrototypes[i] = class<ShockBeam>( DynamicLoadObject(ProtoClass,class'Class'));
}

simulated function LoadExplosion( int i, string ProtoClass)
{
	SetPropertyText( "TmpEffect", GetItemName(ProtoClass) );
	if ( class<ShockWave>(TmpEffect) != None )
		RainbowExplosions[i] = class<ShockWave>(TmpEffect);
	else
		RainbowExplosions[i] = class<ShockWave>( DynamicLoadObject(ProtoClass,class'Class'));
}


defaultproperties
{
	FireAnimRate=1
	AltFireAnimRate=3
	bAltInstantHit=True
	AltProjectileClass=None
}
