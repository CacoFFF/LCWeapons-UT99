// Instagib version

class LCSuperShockRifle expands LCShockRifle;

/*
function AltFire( float Value )
{
	Fire(Value);
}
*/


defaultproperties
{
	ffRefireTimer=1.13
	FireAnimRate=0.4
	AltFireAnimRate=0.4
	bCombo=False
	bInstantFlash=False
	bAltInstantHit=True
	AltProjectileClass=None
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
