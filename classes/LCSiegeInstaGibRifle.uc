//=============================================================================
// LCSiegeInstaGibRifle.
//=============================================================================
class LCSiegeInstaGibRifle expands TournamentWeapon;

var() int HitDamage;
var Projectile Tracked;
var bool bBotSpecialMove;
var float TapTime;

var XC_CompensatorChannel LCChan;
var float ffRefireTimer; //This will enforce security checks

var bool bGraphicsInitialized;
var class<TournamentWeapon> OrgClass;


replication
{
	reliable if ( Role == ROLE_Authority )
		FixOffset;
}

function inventory SpawnCopy( pawn Other )
{
	return Class'LCStatics'.static.SpawnCopy(Other,self);
}
function GiveTo( pawn Other )
{
	Class'LCStatics'.static.GiveTo(Other,self);
}

function SetSwitchPriority(pawn Other)
{
	Class'LCStatics'.static.SetSwitchPriority( Other, self, 'SiegeInstagibRifle');
}

simulated event Spawned()
{
	if ( !bGraphicsInitialized )
		InitGraphics();
}

simulated function InitGraphics()
{
	//Attempt to predict in case of replication failure
	if ( (OrgClass == none) && (Role == ROLE_SimulatedProxy) )
	{
		Role = ROLE_AutonomousProxy;
		SetPropertyText("OrgClass","SiegeInstagibRifle");
		Role = ROLE_SimulatedProxy;
	}

	if ( OrgClass == none )
	{
		Log("Original not loaded! (SiegeInstagibRifle)");
		return;
	}
	else
		default.bGraphicsInitialized = true;
	default.FireSound = OrgClass.default.FireSound;
	FireSound = default.FireSound;
	default.AmmoName = OrgClass.default.AmmoName;
	AmmoName = default.AmmoName;
	default.Icon = OrgClass.default.Icon;
	Icon = default.Icon;
	default.StatusIcon = OrgClass.default.StatusIcon;
	StatusIcon = default.StatusIcon;
	default.MultiSkins[1] = OrgClass.default.MultiSkins[1];
	MultiSkins[1] = default.MultiSkins[1];
	//Adjust hitdamage later
	if ( Role == ROLE_Authority )
		Spawn(class'LCSiegeIGLoader').TCL = OrgClass;
}

simulated event KillCredit( actor Other)
{
	if ( XC_CompensatorChannel(Other) != none )
	{
		LCChan = XC_CompensatorChannel(Other);
		if ( LCChan.bDelayedFire )
			ffTraceFire();
	}
}
simulated function PlayPostSelect()
{
	if ( Level.NetMode == NM_Client )
		bCanClientFire = True;
	Super.PlayPostSelect();
}
function SetHand (float hand)
{
	Super.SetHand(hand);
	FixOffset(FireOffset.Y);
}
simulated function FixOffset (float Y)
{
	FireOffset.Y=Y;
}

simulated function bool IsLC()
{
	return (LCChan != none) && LCChan.bUseLC && (LCChan.Owner == Owner);
}

simulated function ffTraceFire()
{
	local private PlayerPawn ffP;
	local private vector X,Y,Z, ffHitLocation, ffHitNormal, ffStartTrace, ffEndTrace;
	local private actor ffOther;
	local private rotator ffRot;

	ffP = PlayerPawn(Owner);
	if ( ffP == none )	return;
	ffRot = class'LCStatics'.static.PlayerRot( ffP);
	GetAxes( ffRot, X,Y,Z );
	
	ffStartTrace = ffP.Location + CalcDrawOffset() + FireOffset.Y * Y + FireOffset.Z * Z; 
	ffEndTrace = ffStartTrace + 10000 * X; 

	ffOther = Class'LCStatics'.static.ffTraceShot(ffHitLocation,ffHitNormal,ffEndTrace,ffStartTrace,ffP);
	ProcessTraceHit( ffOther, ffHitLocation, ffHitNormal, X, Y, Z);
	if ( (Pawn(ffOther) != none) && (Pawn(ffOther).PlayerReplicationInfo != none ) )
		LCChan.ffSendHit( none, self, class'LCStatics'.static.ffPCode(Pawn(ffOther)), Level.TimeSeconds, ffHitLocation, ffHitLocation - ffOther.Location, ffRot, ffStartTrace, class'LCStatics'.static.CompressRotator(ffRot), 3);
	else
		LCChan.ffSendHit( ffOther, self, -1, Level.TimeSeconds, ffHitLocation, ffHitLocation - ffOther.Location, ffRot, ffStartTrace, class'LCStatics'.static.CompressRotator(ffRot), 3);
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

function TraceFire( float Accuracy )
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local actor Other;

	if ( IsLC() )
		return;

	Owner.MakeNoise(Pawn(Owner).SoundDampening);
	GetAxes(Pawn(owner).ViewRotation,X,Y,Z);
	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.Y * Y + FireOffset.Z * Z; 
	EndTrace = StartTrace + Accuracy * (FRand() - 0.5 )* Y * 1000
		+ Accuracy * (FRand() - 0.5 ) * Z * 1000 ;

	if ( bBotSpecialMove && (Tracked != None)
		&& (((Owner.Acceleration == vect(0,0,0)) && (VSize(Owner.Velocity) < 40)) ||
			(Normal(Owner.Velocity) Dot Normal(Tracked.Velocity) > 0.95)) )
		EndTrace += 10000 * Normal(Tracked.Location - StartTrace);
	else
	{
		AdjustedAim = pawn(owner).AdjustAim(1000000, StartTrace, 2.75*AimError, False, False);	
		EndTrace += (10000 * vector(AdjustedAim)); 
	}

	Tracked = None;
	bBotSpecialMove = false;

	Other = Pawn(Owner).TraceShot(HitLocation,HitNormal,EndTrace,StartTrace);
	ProcessTraceHit(Other, HitLocation, HitNormal, vector(AdjustedAim),Y,Z);
}

simulated function PlayFiring()
{
	PlayOwnedSound(FireSound, SLOT_None, Pawn(Owner).SoundDampening*4.0);
	LoopAnim('Fire1', 0.20 + 0.20 * FireAdjust,0.05);
	if ( IsLC() && (Level.NetMode == NM_Client) )
		LCChan.bDelayedFire = true;
}

function float RateSelf( out int bUseAltMode )
{
	local Pawn P;
	local bool bNovice;

	if ( AmmoType.AmmoAmount <=0 )
		return -2;

	P = Pawn(Owner);

	bUseAltMode = 0;
	return AIRating;
}

function Timer()
{
	local actor targ;
	local float bestAim, bestDist;
	local vector FireDir;
	local Pawn P;

	bestAim = 0.95;
	P = Pawn(Owner);
	if ( P == None )
	{
		GotoState('');
		return;
	}
	FireDir = vector(P.ViewRotation);
	targ = P.PickTarget(bestAim, bestDist, FireDir, Owner.Location);
	if ( Pawn(targ) != None )
	{
		bPointing = true;
		Pawn(targ).WarnTarget(P, 300, FireDir);
		SetTimer(1 + 4 * FRand(), false);
	}
	else 
	{
		SetTimer(0.5 + 2 * FRand(), false);
		if ( (P.bFire == 0) && (P.bAltFire == 0) )
			bPointing = false;
	}
}	

function Finish()
{
	if ( (Pawn(Owner).bFire!=0) && (FRand() < 0.6) )
		Timer();
	if ( !bChangeWeapon && (Tracked != None) && !Tracked.bDeleteMe && (Owner != None) 
		&& (Owner.IsA('Bot')) && (Pawn(Owner).Enemy != None) && (FRand() < 0.3 + 0.35 * Pawn(Owner).skill)
		&& (AmmoType.AmmoAmount > 0) ) 
	{
		if ( (Owner.Acceleration == vect(0,0,0)) ||
			(Abs(Normal(Owner.Velocity) dot Normal(Tracked.Velocity)) > 0.95) )
		{
			bBotSpecialMove = true;
			GotoState('ComboMove');
			return;
		}
	}

	bBotSpecialMove = false;
	Tracked = None;
	Super.Finish();
}

///////////////////////////////////////////////////////

function Projectile ProjectileFire(class<projectile> ProjClass, float ProjSpeed, bool bWarn)
{
	local Vector Start, X,Y,Z;
	local PlayerPawn PlayerOwner;

	Owner.MakeNoise(Pawn(Owner).SoundDampening);
	GetAxes(Pawn(owner).ViewRotation,X,Y,Z);
	Start = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z; 
	AdjustedAim = pawn(owner).AdjustAim(ProjSpeed, Start, AimError, True, bWarn);	

	PlayerOwner = PlayerPawn(Owner);
	if ( PlayerOwner != None )
		PlayerOwner.ClientInstantFlash( -0.4, vect(450, 190, 650));
	Tracked = Spawn(ProjClass,,, Start,AdjustedAim);
	if ( Level.Game.IsA('DeathMatchPlus') && DeathmatchPlus(Level.Game).bNoviceMode )
		Tracked = None; //no combo move
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

	if ( bSpecialEff )		Spawn(class'LCKoalasSuperRing2',Owner,, HitLocation+HitNormal*8,rotator(HitNormal));
	else		Spawn(class'LCKoalasSuperRing',Owner,, HitLocation+HitNormal*8,rotator(HitNormal));

	if ( (Other != self) && (Other != Owner) && (Other != None) ) 
		Other.TakeDamage(HitDamage, Pawn(Owner), HitLocation, 60000.0*X, MyDamageType);
}

simulated function SpawnEffect(vector HitLocation, vector SmokeLocation)
{
	local LCKoalasShockBeam Smoke,shock;
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
		Smoke = Spawn(class'LCKoalasShockBeam2',Owner,,SmokeLocation,SmokeRotation);
	else
		Smoke = Spawn(class'LCKoalasShockBeam',Owner,,SmokeLocation,SmokeRotation);
	Smoke.MoveAmount = DVector/NumPoints;
	Smoke.NumPuffs = NumPoints - 1;	
}
simulated function PlayAltFiring()
{
	PlayFiring();
//	PlayOwnedSound(FireSound, SLOT_None, Pawn(Owner).SoundDampening*4.0);
//	LoopAnim('Fire1', 0.20 + 0.20 * FireAdjust,0.05);
}

simulated function PlayIdleAnim()
{
	if ( Mesh != PickupViewMesh )
		LoopAnim('Still',0.04,0.3);
}
state Idle
{

	function BeginState()
	{
		bPointing = false;
		SetTimer(0.5 + 2 * FRand(), false);
		Super.BeginState();
		if (Pawn(Owner).bFire!=0) Fire(0.0);
		if (Pawn(Owner).bAltFire!=0) AltFire(0.0);		
	}

	function EndState()
	{
		SetTimer(0.0, false);
		Super.EndState();
	}
}

state ClientFiring
{
	simulated function bool ClientFire(float Value)
	{
		if ( Level.TimeSeconds - TapTime < 0.2 )
			return false;
		bForceFire = bForceFire || ( bCanClientFire && (Pawn(Owner) != None) && (AmmoType.AmmoAmount > 0) );
		return bForceFire;
	}

	simulated function bool ClientAltFire(float Value)
	{
		if ( Level.TimeSeconds - TapTime < 0.2 )
			return false;
		bForceAltFire = bForceAltFire || ( bCanClientFire && (Pawn(Owner) != None) && (AmmoType.AmmoAmount > 0) );
		return bForceAltFire;
	}

	simulated function AnimEnd()
	{
		local bool bForce, bForceAlt;

		bForce = bForceFire;
		bForceAlt = bForceAltFire;
		bForceFire = false;
		bForceAltFire = false;

		if ( bCanClientFire && (PlayerPawn(Owner) != None) && (AmmoType.AmmoAmount > 0) )
		{
			if ( bForce || (Pawn(Owner).bFire != 0) )
			{
				Global.ClientFire(0);
				return;
			}
			else if ( bForceAlt || (Pawn(Owner).bAltFire != 0) )
			{
				Global.ClientAltFire(0);
				return;
			}
		}			
		Super.AnimEnd();
	}

	simulated function EndState()
	{
		bForceFire = false;
		bForceAltFire = false;
	}

	simulated function BeginState()
	{
		TapTime = Level.TimeSeconds;
		bForceFire = false;
		bForceAltFire = false;
	}
}


defaultproperties
{
     ffRefireTimer=1.1
     hitdamage=300
     WeaponDescription="Classification: Energy Rifle"
     InstFlash=-0.400000
     InstFog=(X=800.000000)
     PickupAmmoCount=50
     bInstantHit=True
     bAltWarnTarget=True
     bSplashDamage=True
     FiringSpeed=2.000000
     FireOffset=(X=10.000000,Y=-5.000000,Z=-8.000000)
     MyDamageType=jolted
     aimerror=650.000000
     AIRating=0.630000
     AltRefireRate=0.700000
     AltFireSound=Sound'UnrealShare.ASMD.TazerAltFire'
     SelectSound=Sound'UnrealShare.ASMD.TazerSelect'
     DeathMessage="%k electrified %o with the %w."
     NameColor=(R=128,G=0)
     AutoSwitchPriority=4
     InventoryGroup=4
     PickupMessage="You got the Siege Enhanced Shock Rifle."
     ItemName="Siege Enhanced Shock Rifle"
     PlayerViewOffset=(X=4.400000,Y=-1.700000,Z=-1.600000)
     PlayerViewMesh=LodMesh'Botpack.sshockm'
     PlayerViewScale=2.000000
     BobDamping=0.975000
     PickupViewMesh=LodMesh'Botpack.ASMD2pick'
     ThirdPersonMesh=LodMesh'Botpack.SASMD2hand'
     PickupSound=Sound'UnrealShare.Pickups.WeaponPickup'
     Mesh=LodMesh'Botpack.ASMD2pick'
     bNoSmooth=False
     CollisionRadius=34.000000
     CollisionHeight=8.000000
     Mass=50.000000
}