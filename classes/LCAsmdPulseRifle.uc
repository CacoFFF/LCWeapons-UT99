//=============================================================================
// LCAsmdPulseRifle.
//=============================================================================
class LCAsmdPulseRifle expands TournamentWeapon;

var float Angle, Count;
var() sound DownSound;
var() int HitDamage;

var bool bGraphicsInitialized;
var bool bTeamColor;
var class<TournamentWeapon> OrgClass;
var class<ShockBeam> GlobalBeam;
var class<ShockBeam> HiddenBeam;
var class<Effects> GlobalExplosion;
var class<Effects> HiddenExplosion;


var XC_CompensatorChannel LCChan;
var bool bSimulating;
var float ClientSleepAgain; //Because ACE is flawed!!!!!!!!!!!!!!

//My client effect spawner is flawed, so limit the amount of simshots we can pull
var float LastShot;

replication
{
	reliable if ( Role == ROLE_Authority )
		FixOffset;
	reliable if ( Role == ROLE_Authority )
		bTeamColor;
}

function inventory SpawnCopy( pawn Other )
{
	return Class'LCStatics'.static.SpawnCopy(Other,self);
}
function GiveTo( pawn Other )
{
	Class'LCStatics'.static.GiveTo(Other,self);
	if ( bTeamColor )
		SetStaticSkins();
}

function SetSwitchPriority(pawn Other)
{
	Class'LCStatics'.static.SetSwitchPriority( Other, self, 'AsmdPulseRifle');
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
		SetPropertyText("OrgClass","ASMDPulseRifle");
		Role = ROLE_SimulatedProxy;
	}

	if ( OrgClass == none )
	{
		Log("Original class still fails!");
		return;
	}
	else
		default.bGraphicsInitialized = true;
	default.FireSound = OrgClass.default.FireSound;
	FireSound = default.FireSound;
	default.AltFireSound = OrgClass.default.AltFireSound;
	AltFireSound = default.AltFireSound;
	default.AmmoName = OrgClass.default.AmmoName;
	AmmoName = default.AmmoName;
	default.MultiSkins[2] = OrgClass.default.MultiSkins[2];
	default.MultiSkins[1] = OrgClass.default.MultiSkins[1];
	MultiSkins[2] = default.MultiSkins[2];
	MultiSkins[1] = default.MultiSkins[1];
	//Adjust hitdamage later
	if ( Role == ROLE_Authority )
	{
		Spawn(class'LCAsmdPulseLoader').TCL = OrgClass;
	}
}



////////////////////////////////
//All of the unlagged code here
simulated event KillCredit( Actor Other)
{
	if ( XC_CompensatorChannel(Other) != none )
		LCChan = XC_CompensatorChannel(Other);
	else if ( LCMutator(Other) != none )
	{
		if ( LCMutator(Other).bTeamShock )
			bTeamColor = true;
	}
}
simulated function PlayPostSelect()
{
	if ( Level.NetMode == NM_Client )
		bCanClientFire = True;
	if ( bTeamColor )
		SetStaticSkins();
	Super.PlayPostSelect();
}
simulated function bool IsLC()
{
	return (LCChan != none) && LCChan.bUseLC && (LCChan.Owner == Owner);
}
simulated function FixOffset (float Y)
{
	FireOffset.Y=Y;
}

function TraceFire( float Accuracy )
{
	if ( !IsLC() )
	{
		Super.TraceFire( Accuracy);
		return;
	}
	ServerTraceFire( Accuracy);
}


function ServerTraceFire( float Accuracy)
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local actor Other, aActor;
	local Pawn PawnOwner;

	PawnOwner = Pawn(Owner);

	GetAxes(PawnOwner.ViewRotation,X,Y,Z);
	Owner.MakeNoise(PawnOwner.SoundDampening);
	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z; 
	AdjustedAim = PawnOwner.AdjustAim(1000000, StartTrace, 2*AimError, False, False);	
	EndTrace = StartTrace + Accuracy * (FRand() - 0.5 )* Y * 1000
		+ Accuracy * (FRand() - 0.5 ) * Z * 1000;
	X = vector(AdjustedAim);
	EndTrace += (10000 * X); 

	LCChan.LCActor.ffUnlagPositions( LCChan.LCComp, StartTrace, rotator(EndTrace-StartTrace) );
	ForEach PawnOwner.TraceActors( class'Actor', aActor, HitLocation, HitNormal, EndTrace, StartTrace)
	{
		if ( Class'LCStatics'.static.TraceStopper( aActor) )
		{	Other = aActor;
			break;
		}
		if ( !aActor.bProjTarget && !aActor.bBlockActors )
			continue;
		if ( Class'LCStatics'.static.CompensatedType(aActor) )
			continue;
		if ( aActor.bIsPawn && !Pawn(aActor).AdjustHitLocation(HitLocation, EndTrace - StartTrace) )
			continue; //We can't hit this Pawn due to special collision rules
		Other = aActor;
		break;
	}
	Other = Class'LCStatics'.static.CompensatedHitActor( Other, HitLocation);
	bSimulating = true;
	ProcessTraceHit(Other, HitLocation, HitNormal, X,Y,Z);
	bSimulating = false;
	LCChan.LCActor.ffRevertPositions();
}

simulated function SimTraceFire()
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local actor Other, aActor;
	local Pawn PawnOwner;

	PawnOwner = Pawn(Owner);
	if ( (PawnOwner == none) || (Level.TimeSeconds - LastShot < 0.09) )
		return;
	GetAxes( class'LCStatics'.static.PlayerRot( PawnOwner), X,Y,Z);
	LastShot = Level.TimeSeconds;
	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z; 
	EndTrace = StartTrace + (10000 * X); 
	ForEach PawnOwner.TraceActors( class'Actor', aActor, HitLocation, HitNormal, EndTrace, StartTrace)
	{
		if ( Class'LCStatics'.static.TraceStopper( aActor) )
		{	Other = aActor;
			break;
		}
		if ( !aActor.bProjTarget && !aActor.bBlockActors )
			continue;
		if ( aActor.IsA('Pawn') && !Pawn(aActor).AdjustHitLocation(HitLocation, EndTrace - StartTrace) )
			continue;
		Other = aActor;
		break;
	}
	SimProcessTraceHit(Other, HitLocation, HitNormal, X,Y,Z);
}

simulated function SimProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local int i;
	local PlayerPawn PlayerOwner;

	if (Other==None)
	{
		HitNormal = -X;
		HitLocation = Owner.Location + X*10000.0;
	}
	PlayerOwner = PlayerPawn(Owner);
	if ( PlayerOwner != None )
		PlayerOwner.ClientInstantFlash( -0.4, vect(450, 190, 650));
	SpawnEffect(HitLocation, Owner.Location + CalcDrawOffset() + (FireOffset.X + 20) * X + FireOffset.Y * Y + FireOffset.Z * Z);
	if ( ShockProj(Other)==None )
		Spawn(GlobalExplosion,,, HitLocation+HitNormal*8,rotator(HitNormal));
}

//OBFEND
////////////////////////////////////////

auto state Pickup
{
	ignores AnimEnd;

	// Landed on ground.
	simulated function Landed(Vector HitNormal)
	{
		local rotator newRot;

		newRot = Rotation;
		newRot.pitch = 0;
		SetRotation(newRot);
		if ( Role == ROLE_Authority )
		{
			bSimFall = false;
			SetTimer(2.0, false);
		}
	}
}

simulated event RenderOverlays( canvas Canvas )
{
	MultiSkins[1] = none;
	Texture'Ammoled'.NotifyActor = Self;
	Super.RenderOverlays(Canvas);
	Texture'Ammoled'.NotifyActor = None;
	MultiSkins[1] = Default.MultiSkins[1];
}

simulated function AnimEnd()
{
	if ( (Level.NetMode == NM_Client) && (Mesh != PickupViewMesh) )
	{
		if ( AnimSequence == 'SpinDown' )
			AnimSequence = 'Idle';
		PlayIdleAnim();
	}
}
// set which hand is holding weapon
function setHand(float Hand)
{
	if ( Hand == 2 )
	{
		FireOffset.Y = 0;
		bHideWeapon = true;
		return;
	}
	else
		bHideWeapon = false;
	PlayerViewOffset = Default.PlayerViewOffset * 100;
	if ( Hand == 1 )
	{
		FireOffset.Y = Default.FireOffset.Y;
		Mesh = mesh(DynamicLoadObject("Botpack.PulseGunL", class'Mesh'));
	}
	else
	{
		FireOffset.Y = -1 * Default.FireOffset.Y;
		Mesh = mesh'PulseGunR';
	}
	FixOffset(FireOffset.Y);
}

// return delta to combat style
function float SuggestAttackStyle()
{
	local float EnemyDist;

	EnemyDist = VSize(Pawn(Owner).Enemy.Location - Owner.Location);
	if ( EnemyDist < 1000 )
		return 0.4;
	else
		return 0;
}

function float RateSelf( out int bUseAltMode )
{
	local Pawn P;

	if ( AmmoType.AmmoAmount <=0 )
		return -2;

	P = Pawn(Owner);
	if ( (P.Enemy == None) || (Owner.IsA('Bot') && Bot(Owner).bQuickFire) )
	{
		bUseAltMode = 0;
		return AIRating;
	}

	if ( P.Enemy.IsA('StationaryPawn') )
	{
		bUseAltMode = 0;
		return (AIRating + 0.4);
	}
	else
		bUseAltMode = int( 700 > VSize(P.Enemy.Location - Owner.Location) );

	AIRating *= FMin(Pawn(Owner).DamageScaling, 1.5);
	return AIRating;
}

simulated function PlayFiring()
{
	FlashCount++;
	AmbientSound = FireSound;
	SoundVolume = Pawn(Owner).SoundDampening*255;
	LoopAnim( 'shootLOOP', 1 + 0.5 * FireAdjust, 0.0);
	bWarnTarget = (FRand() < 0.2);
	if ( bTeamColor )
		SetStaticSkins();
	if ( Level.NetMode == NM_Client && IsLC() )
		SimTraceFire();
}

simulated function PlayAltFiring()
{
	
	FlashCount++;
	AmbientSound = AltFireSound;
	SoundVolume = Pawn(Owner).SoundDampening*255;
	LoopAnim( 'shootLOOP', 1 + 0.5 * FireAdjust, 0.0);
	bWarnTarget = (FRand() < 0.2);
}

function AltFire( float Value )
{
	if ( AmmoType == None )
	{
		// ammocheck
		GiveAmmo(Pawn(Owner));
	}
	if (AmmoType.UseAmmo(1))
	{
		GotoState('AltFiring');
		bCanClientFire = true;
		bPointing=True;
		Pawn(Owner).PlayRecoil(FiringSpeed);
		ClientAltFire(value);
		ProjectileFire(AltProjectileClass, AltProjectileSpeed, bAltWarnTarget);
	}
}

simulated event RenderTexture(ScriptedTexture Tex)
{
	local Color C;
	local string Temp;

	if ( AmmoType == none )
		return;
	
	Temp = String(AmmoType.AmmoAmount);
	while(Len(Temp) < 3) Temp = "0"$Temp;

	Tex.DrawTile( 30, 100, (Min(AmmoType.AmmoAmount,AmmoType.Default.AmmoAmount)*196)/AmmoType.Default.AmmoAmount, 10, 0, 0, 1, 1, Texture'AmmoCountBar', False );

	if(AmmoType.AmmoAmount < 10)
	{
		C.R = 255;
		C.G = 0;
		C.B = 0;	
	}
	else
	{
		C.R = 0;
		C.G = 0;
		C.B = 255;
	}

	Tex.DrawColoredText( 56, 14, Temp, Font'LEDFont', C );	
}


///////////////////////////////////////////////////////
state NormalFire
{
	ignores AnimEnd;

	function Projectile ProjectileFire(class<projectile> ProjClass, float ProjSpeed, bool bWarn)
	{
		local Vector Start, X,Y,Z;

		Owner.MakeNoise(Pawn(Owner).SoundDampening);
		GetAxes(Pawn(owner).ViewRotation,X,Y,Z);
		Start = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z; 
		AdjustedAim = pawn(owner).AdjustAim(ProjSpeed, Start, AimError, True, bWarn);	
		Start = Start - Sin(Angle)*Y*4 + (Cos(Angle)*4 - 10.78)*Z;
		Angle += 1.8;
		return Spawn(ProjClass,,, Start,AdjustedAim);	
	}

	function Tick( float DeltaTime )
	{
		if (Owner==None) 
			GotoState('Pickup');
	}

	function BeginState()
	{
		Super.BeginState();
		Angle = 0;
		AmbientGlow = 200;
	}

	function EndState()
	{
		PlaySpinDown();
		AmbientSound = None;
		AmbientGlow = 0;	
		OldFlashCount = FlashCount;	
		Super.EndState();
	}

Begin:
	Sleep(0.18);
	Finish();
}

simulated function PlaySpinDown()
{
	if ( (Mesh != PickupViewMesh) && (Owner != None) )
	{
		PlayAnim('Spindown', 1.0, 0.0);
		Owner.PlayOwnedSound(DownSound, SLOT_None,1.0*Pawn(Owner).SoundDampening);
	}
}	

simulated state ClientFiring
{
	simulated function Tick( float DeltaTime )
	{
		if ( (Pawn(Owner) != None) && (Pawn(Owner).bFire != 0) )
			AmbientSound = FireSound;
		else
			AmbientSound = None;
		if ((ClientSleepAgain -= DeltaTime) <= 0 ) //ACE IS BUGGED, SO I HAVE TO HANDLE THIS HERE
			AnimEnd();
	}

	simulated function AnimEnd()
	{
		if ( (AmmoType != None) && (AmmoType.AmmoAmount <= 0) )
		{
			PlaySpinDown();
			GotoState('');
		}
		else if ( !bCanClientFire )
			GotoState('');
		else if ( Pawn(Owner) == None )
		{
			PlaySpinDown();
			GotoState('');
		}
		else if ( Pawn(Owner).bFire != 0 )
			Global.ClientFire(0);
		else if ( Pawn(Owner).bAltFire != 0 )
			Global.ClientAltFire(0);
		else
		{
			PlaySpinDown();
			GotoState('');
		}
	}
Begin:
	ClientSleepAgain = 0.18;
//	Sleep(0.18);
}

///////////////////////////////////////////////////////////////
simulated state ClientAltFiring
{
	simulated function AnimEnd()
	{
		if ( AmmoType.AmmoAmount <= 0 )
		{
			PlayIdleAnim();
			GotoState('');
		}
		else if ( !bCanClientFire )
			GotoState('');
		else if ( Pawn(Owner) == None )
		{
			PlayIdleAnim();
			GotoState('');
		}
		else if ( Pawn(Owner).bAltFire != 0 )
			LoopAnim( 'shootLOOP', 1 + 0.5 * FireAdjust, 0.0);
		else if ( Pawn(Owner).bFire != 0 )
			Global.ClientFire(0);
		else
		{
			PlayIdleAnim();
			GotoState('');
		}
	}
Begin:
	Sleep(0.18);
	AnimEnd();
}

state AltFiring
{
	ignores AnimEnd;

	function Projectile ProjectileFire(class<projectile> ProjClass, float ProjSpeed, bool bWarn)
	{
		local Vector Start, X,Y,Z;

		Owner.MakeNoise(Pawn(Owner).SoundDampening);
		GetAxes(Pawn(owner).ViewRotation,X,Y,Z);
		Start = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z; 
		AdjustedAim = pawn(owner).AdjustAim(ProjSpeed, Start, AimError, True, bWarn);	
		Start = Start - Sin(Angle)*Y*4 + (Cos(Angle)*4 - 10.78)*Z;
		Angle += 1.8;
		return Spawn(ProjClass,,, Start,AdjustedAim);	
	}

	function Tick( float DeltaTime )
	{
		if (Owner==None) 
			GotoState('Pickup');
	}

	function BeginState()
	{
		Super.BeginState();
		Angle = 0;
		AmbientGlow = 200;
	}

	function EndState()
	{
		PlaySpinDown();
		AmbientSound = None;
		AmbientGlow = 0;	
		OldFlashCount = FlashCount;	
		Super.EndState();
	}

Begin:
	Sleep(0.18);
	Finish();
}

state Idle
{
Begin:
	bPointing=False;
	if ( (AmmoType != None) && (AmmoType.AmmoAmount<=0) ) 
		Pawn(Owner).SwitchToBestWeapon();  //Goto Weapon that has Ammo
	if ( Pawn(Owner).bFire!=0 ) Fire(0.0);
	if ( Pawn(Owner).bAltFire!=0 ) AltFire(0.0);	

	Disable('AnimEnd');
	PlayIdleAnim();
}

///////////////////////////////////////////////////////////
simulated function PlayIdleAnim()
{
	if ( Mesh == PickupViewMesh )
		return;

	if ( (AnimSequence == 'BoltLoop') || (AnimSequence == 'BoltStart') )
		PlayAnim('BoltEnd');		
	else if ( AnimSequence != 'SpinDown' )
		TweenAnim('Idle', 0.1);
}

simulated function TweenDown()
{
	if ( IsAnimating() && (AnimSequence != '') && (GetAnimGroup(AnimSequence) == 'Select') )
		TweenAnim( AnimSequence, AnimFrame * 0.4 );
	else
		TweenAnim('Down', 0.26);
}

function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local Effects Explosion;

	if (Other==None)
	{
		HitNormal = -X;
		HitLocation = Owner.Location + X*10000.0;
	}

	if ( PlayerPawn(Owner) != None )
		PlayerPawn(Owner).ClientInstantFlash( -0.4, vect(450, 190, 650));
	SpawnEffect(HitLocation, Owner.Location + CalcDrawOffset() + (FireOffset.X + 20) * X + FireOffset.Y * Y + FireOffset.Z * Z);

	if ( ShockProj(Other) != None )
	{ 
		AmmoType.UseAmmo(2);
		ShockProj(Other).SuperExplosion();
	}
	else
	{
		if ( bSimulating && LCChan.LCActor.bNeedsHiddenEffects )
			Explosion = Spawn(HiddenExplosion,Owner,, HitLocation+HitNormal*8,rotator(HitNormal));
		else
		{
			Explosion = Spawn(GlobalExplosion,Owner,, HitLocation+HitNormal*8,rotator(HitNormal));
			if ( bSimulating )
				Explosion.SetPropertyText("bNotRelevantToOwner","1");
		}
		EditExplosion( Explosion);
	}

	if ( (Other != self) && (Other != Owner) && (Other != None) ) 
		Other.TakeDamage(HitDamage, Pawn(Owner), HitLocation, 60000.0*X, MyDamageType);
}

simulated function SpawnEffect(vector HitLocation, vector SmokeLocation)
{
	local ShockBeam Smoke,shock;
	local Vector DVector;
	local int NumPoints;
	local rotator SmokeRotation;

	DVector = HitLocation - SmokeLocation;
	NumPoints = VSize(DVector)/135.0;
	if ( NumPoints < 1 )
		return;
	SmokeRotation = rotator(DVector);
	SmokeRotation.roll = Rand(65535);
	
	if ( bSimulating && (Level.NetMode != NM_Client) && LCChan.LCActor.bNeedsHiddenEffects )
		Smoke = Spawn(HiddenBeam,Owner,,SmokeLocation,SmokeRotation);
	else
	{
		Smoke = Spawn(GlobalBeam,Owner,,SmokeLocation,SmokeRotation);
		if ( bSimulating )
			Smoke.SetPropertyText("bNotRelevantToOwner","1");
	}
	Smoke.MoveAmount = DVector/NumPoints;
	Smoke.NumPuffs = NumPoints - 1;	
	EditBeam( Smoke);
}

//Used in subclasses
simulated function EditBeam( ShockBeam Beam)
{
	if ( bTeamColor )
		Beam.Texture = Class'FVTeamShock'.default.BeamTex[ Class'LCStatics'.static.FVTeam( Pawn(Owner)) ];
}

simulated function EditExplosion( Effects Explo)
{
	if ( bTeamColor )
		Explo.Skin = Class'FVTeamShock'.default.ExploSkin[ Class'LCStatics'.static.FVTeam( Pawn(Owner)) ];
}

//Allow overriding in special cases
simulated function SetStaticSkins()
{
	Class'FVTeamShock'.static.AsmdPR_SetStaticProj( self);
}


defaultproperties
{
	GlobalBeam=class'FV_AdaptiveBeam'
	HiddenBeam=class'FV_LCAdaptiveBeam'
	GlobalExplosion=class'Botpack.ut_RingExplosion5'
	HiddenExplosion=class'LCRingExplosion5'

     DownSound=Sound'Botpack.PulseGun.PulseDown'
     hitdamage=50
     PickupAmmoCount=199
     bInstantHit=True
     bRapidFire=True
     FireOffset=(X=16.000000,Y=-14.000000,Z=-8.000000)
     ProjectileClass=None
     AltProjectileClass=Class'Botpack.ShockProj'
     MyDamageType=jolted
     AltDamageType=jolted
     shakemag=135.000000
     shakevert=8.000000
     AIRating=0.700000
     RefireRate=0.950000
     AltRefireRate=0.990000
     SelectSound=Sound'Botpack.PulseGun.PulsePickup'
     DeathMessage="%o was torn to pieces by %k's %w."
     NameColor=(R=128,G=0,B=128)
     FlashLength=0.020000
     AutoSwitchPriority=5
     InventoryGroup=5
     PickupMessage="You got the ASMD Pulse Rifle"
     ItemName="Pulse Gun"
     PlayerViewOffset=(X=1.500000,Z=-2.000000)
     PlayerViewMesh=LodMesh'Botpack.PulseGunR'
     PickupViewMesh=LodMesh'Botpack.PulsePickup'
     ThirdPersonMesh=LodMesh'Botpack.PulseGun3rd'
     ThirdPersonScale=0.400000
     StatusIcon=Texture'Botpack.Icons.UsePulse'
     bMuzzleFlashParticles=True
     MuzzleFlashStyle=STY_Translucent
     MuzzleFlashMesh=LodMesh'Botpack.muzzPF3'
     MuzzleFlashScale=0.400000
     MuzzleFlashTexture=Texture'Botpack.Skins.MuzzyPulse'
     PickupSound=Sound'UnrealShare.Pickups.WeaponPickup'
     Icon=Texture'Botpack.Icons.UsePulse'
     Mesh=LodMesh'Botpack.PulsePickup'
     bNoSmooth=False
}
