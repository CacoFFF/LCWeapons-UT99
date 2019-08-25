//=============================================================================
// LCSiegeInstaGibRifle.
//=============================================================================
class LCSiegeInstaGibRifle expands TournamentWeapon;

var() int HitDamage;
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
			class'LCStatics'.static.ClientTraceFire( self, LCChan);
	}
}
simulated function PlayPostSelect()
{
	if ( Level.NetMode == NM_Client )
		bCanClientFire = True;
	Super.PlayPostSelect();
}


function AltFire( float Value )
{
	Fire( Value);
}

function TraceFire( float Accuracy )
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local Actor Other;
	local int ExtraFlags;

	if ( IsLC() )
		return;

	Owner.MakeNoise(Pawn(Owner).SoundDampening);
	GetAxes(Pawn(owner).ViewRotation,X,Y,Z);
	StartTrace = GetStartTrace( ExtraFlags, X,Y,Z); 
	AdjustedAim = Pawn(owner).AdjustAim( 1000000, StartTrace, 2.75*AimError, False, False);
	X = vector(AdjustedAim);
	EndTrace = StartTrace 
		+ X * GetRange( ExtraFlags)
		+ Accuracy * (FRand() - 0.5 ) * Y * 1000
		+ Accuracy * (FRand() - 0.5 ) * Z * 1000 ;


	Other = Pawn(Owner).TraceShot(HitLocation,HitNormal,EndTrace,StartTrace);
	ProcessTraceHit(Other, HitLocation, HitNormal, X,Y,Z);
}

simulated function PlayFiring()
{
	PlayOwnedSound(FireSound, SLOT_None, Pawn(Owner).SoundDampening*4.0);
	LoopAnim('Fire1', 0.20 + 0.20 * FireAdjust,0.05);
	if ( IsLC() && (Level.NetMode == NM_Client) )
		LCChan.ClientFire();
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
	Super.Finish();
}

///////////////////////////////////////////////////////

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

//***********************************************************************
// LCWeapons common interfaces
//***********************************************************************
function Inventory SpawnCopy( Pawn Other)
{
	return Class'LCStatics'.static.SpawnCopy( Other, self);
}
function GiveTo( Pawn Other)
{
	Class'LCStatics'.static.GiveTo( Other, self);
}
function SetSwitchPriority( Pawn Other)
{
	Class'LCStatics'.static.SetSwitchPriority( Other, self, 'SiegeInstagibRifle');
}
simulated function float GetRange( out int ExtraFlags)
{
	return 10000;
}
simulated function vector GetStartTrace( out int ExtraFlags, vector X, vector Y, vector Z)
{
	return Owner.Location + CalcDrawOffset() + FireOffset.Y * Y + FireOffset.Z * Z;
}
simulated function bool IsLC()
{
	return (LCChan != none) && LCChan.bUseLC && (LCChan.Owner == Owner);
}
function SetHand( float hand)
{
	Super.SetHand(hand);
	FixOffset( FireOffset.Y);
}
simulated function FixOffset( float Y)
{
	FireOffset.Y=Y;
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