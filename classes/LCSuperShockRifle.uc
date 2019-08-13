// Instagib version

class LCSuperShockRifle expands LCShockRifle;

var bool bLocaleInitialized;

simulated event Spawned()
{
	if ( !bLocaleInitialized )
		InitLocale();
}

function Fire( float Value )
{
	if (AmmoType.AmmoAmount > 0 )
	{
		GotoState('NormalFire');
		bCanClientFire = true;
		bPointing=True;
		ClientFire(value);
		AmmoType.UseAmmo(1);
		if ( bRapidFire || (FiringSpeed > 0) )
			Pawn(Owner).PlayRecoil(FiringSpeed);
		if ( bInstantHit )
			TraceFire(0.0);
		else
			ProjectileFire(ProjectileClass, ProjectileSpeed, bWarnTarget);
	}
}

function AltFire( float Value )
{
	if (AmmoType.AmmoAmount > 0 )
	{
		GotoState('NormalFire');
		bCanClientFire = true;
		bPointing=True;
		ClientFire(value);
		AmmoType.UseAmmo(1);
		if ( bRapidFire || (FiringSpeed > 0) )
			Pawn(Owner).PlayRecoil(FiringSpeed);
		if ( bInstantHit )
			TraceFire(0.0);
		else
			ProjectileFire(ProjectileClass, ProjectileSpeed, bWarnTarget);
	}
}

simulated function InitLocale()
{
	default.bLocaleInitialized = true;
	default.PickupMessage = class'SuperShockRifle'.default.PickupMessage;
	PickupMessage = default.PickupMessage;
	default.DeathMessage = class'SuperShockRifle'.default.DeathMessage;
	DeathMessage = default.DeathMessage;
	default.ItemName = class'SuperShockRifle'.default.ItemName;
	ItemName = default.ItemName;
	
}

simulated function PlayAltFiring()
{
	PlayFiring();
}


defaultproperties
{
	ffRefireTimer=1.13
	FireAnimRate=0.4
	AltFireAnimRate=0.4
	bCombo=False
	bInstantFlash=False
	BeamPrototype=class'SuperShockBeam'
	ExplosionClass=class'LCSuperRing2'
	bNoAmmoDeplete=True
	HitDamage=1000
	InstFog=(X=800.000000,Z=0.000000)
	AmmoName=Class'Botpack.SuperShockCore'
	aimerror=650.000000
	DeathMessage="%k electrified %o with the %w."
	PickupMessage="You got the enhanced Shock Rifle."
	ItemName="Enhanced Shock Rifle"
	PlayerViewMesh=LodMesh'botpack.sshockm'
	ThirdPersonMesh=LodMesh'botpack.SASMD2hand'
}
