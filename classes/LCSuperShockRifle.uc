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

simulated function PlayFiring()
{
	PlayOwnedSound(FireSound, SLOT_None, Pawn(Owner).SoundDampening*4.0);
	LoopAnim('Fire1', 0.20 + 0.20 * FireAdjust,0.05);
	if ( IsLC() && (Level.NetMode == NM_Client) )
		LCChan.bDelayedFire = true;
}

simulated function PlayAltFiring()
{
	PlayFiring();
}

simulated function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local bool bSpecialEff;

	bSpecialEff = IsLC() && (Level.NetMode != NM_Client); //Spawn for LC clients

	if (Other==None)
	{
		HitNormal = -X;
		HitLocation = Owner.Location + X*10000.0;
	}

	SpawnEffect(HitLocation, Owner.Location + CalcDrawOffset() + (FireOffset.X + 20) * X + FireOffset.Y * Y + FireOffset.Z * Z);

	if ( bSpecialEff )		Spawn(class'zp_SuperShockRing',Owner,, HitLocation+HitNormal*8,rotator(HitNormal));
	else		Spawn(class'ut_SuperRing2',Owner,, HitLocation+HitNormal*8,rotator(HitNormal));

	if ( (Other != self) && (Other != Owner) && (Other != None) ) 
		Other.TakeDamage(HitDamage, Pawn(Owner), HitLocation, 60000.0*X, MyDamageType);
}

simulated function SpawnEffect(vector HitLocation, vector SmokeLocation)
{
	local SuperShockBeam Smoke,shock;
	local Vector DVector;
	local int NumPoints;
	local rotator SmokeRotation;

	DVector = HitLocation - SmokeLocation;
	NumPoints = VSize(DVector)/135.0;
	if ( NumPoints < 1 )
		return;
	SmokeRotation = rotator(DVector);
	SmokeRotation.roll = Rand(65535);

	if ( IsLC() && (Level.NetMode != NM_Client) )
		Smoke = Spawn(class'zp_SuperShockBeam',Owner,,SmokeLocation,SmokeRotation);
	else
		Smoke = Spawn(class'SuperShockBeam',Owner,,SmokeLocation,SmokeRotation);
	Smoke.MoveAmount = DVector/NumPoints;
	Smoke.NumPuffs = NumPoints - 1;	
}

defaultproperties
{
     ffRefireTimer=1.1
     hitdamage=1000
     InstFog=(X=800.000000,Z=0.000000)
     AmmoName=Class'botpack.SuperShockCore'
     aimerror=650.000000
     DeathMessage="%k electrified %o with the %w."
     PickupMessage="You got the enhanced Shock Rifle."
     ItemName="Enhanced Shock Rifle"
     PlayerViewMesh=LodMesh'botpack.sshockm'
     ThirdPersonMesh=LodMesh'botpack.SASMD2hand'
}
