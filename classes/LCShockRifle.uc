//*************************************************
//**** ZP Shock Rifle variation
//**** Made by Higor
//*************************************************

class LCShockRifle expands ShockRifle;


var XC_CompensatorChannel LCChan;
var bool bLoaderSetup;
var bool bSimulatingEffect;
var bool bNoAmmoDeplete;
var bool bTeamColor;
var bool bCombo;
var bool bInstantFlash;
var float ffRefireTimer; //This will enforce security checks

var float FireAnimRate;
var float AltFireAnimRate;
var class<Effects> BeamPrototype;
var class<Effects> ExplosionClass;

replication
{
	reliable if ( Role == ROLE_Authority )
		bTeamColor;
}


simulated event KillCredit( Actor Other)
{
	if ( XC_CompensatorChannel(Other) != none )
	{
		LCChan = XC_CompensatorChannel(Other);
		if ( LCChan.bDelayedFire )
			class'LCStatics'.static.ClientTraceFire( self, LCChan);
		else if ( LCChan.bDelayedAltFire && (AltProjectileClass != none) )
		{
			if ( bAltInstantHit )
				class'LCStatics'.static.ClientTraceFire( self, LCChan);
			else if ( AltProjectileClass != None )
				ffSimProj(AltProjectileClass, AltProjectileClass.Default.Speed);
		}
	}
	else if ( LCMutator(Other) != none )
	{
		if ( LCMutator(Other).bTeamShock && (Class == class'LCShockRifle') )
			bTeamColor = true;
	}
}

function AltFire( float Value )
{
	if ( bAltInstantHit )
		Super(TournamentWeapon).AltFire( Value);
	else
		Super.AltFire( Value);
}


simulated function PlayPostSelect()
{
	if ( Level.NetMode == NM_Client )
		bCanClientFire = True;
	if ( bTeamColor )
		SetStaticSkins();
	Super.PlayPostSelect();
}

simulated event RenderOverlays( canvas Canvas )
{
	if ( bTeamColor )
	{
		MultiSkins[1] = none;
		Super.RenderOverlays(Canvas);
		MultiSkins[1] = MultiSkins[7];
	}
	else
		Super.RenderOverlays(Canvas);
}



simulated function PlayFiring()
{
	PlayOwnedSound( FireSound, SLOT_None, Pawn(Owner).SoundDampening*4.0);
	if ( HasAnim('Fire1') )
	{
		LoopAnim('Fire1', FireAnimRate * (0.5 + 0.5 * FireAdjust), 0.05);
		ffRefireTimer = 1.0 / AnimRate;
	}
	if ( IsLC() && (Level.NetMode == NM_Client) )
		LCChan.ClientFire();;
	if ( bTeamColor )
		SetStaticSkins();
}

simulated function PlayAltFiring()
{
	local name FireAnim;
	
	PlayOwnedSound( AltFireSound, SLOT_None, Pawn(Owner).SoundDampening*4.0);
	if ( bAltInstantHit ) FireAnim = 'Fire1';
	else                  FireAnim = 'Fire2';
	if ( HasAnim( FireAnim) )
	{
		LoopAnim( FireAnim, AltFireAnimRate * (0.5 + 0.5 * FireAdjust), 0.05);
		ffRefireTimer = 1.0 / AnimRate;
	}
	if ( IsLC() && (Level.NetMode == NM_Client) )
		LCChan.ClientFire(true);
}


state ClientFiring
{
	simulated function bool ClientFire(float Value)
	{
		return false;
	}

	simulated function bool ClientAltFire(float Value)
	{
		return false;
	}
}


function Projectile ProjectileFire( class<Projectile> ProjClass, float ProjSpeed, bool bWarn)
{
	local Projectile P;
	
	P = Super.ProjectileFire( ProjClass, ProjSpeed, bWarn);
	if ( (P != None) && (class'LCStatics'.default.XCGE_Version > 0) )
		P.SetPropertyText("bSuperClassRelevancy","1");
	return P;	
}

simulated function Projectile ffSimProj( class<projectile> ProjClass, float ProjSpeed)
{
	local Vector Start, X,Y,Z;
	local private PlayerPawn ffP;
	local private rotator ffRot;
	local XC_ProjSimulator Simulator;

	if ( LCChan.ProjAdv <= 0 )
		return None;
	
	ffP = PlayerPawn(Owner);
	if ( ffP == None )
		return None;
	ffRot = class'LCStatics'.static.PlayerRot( ffP);
	GetAxes( ffRot, X,Y,Z );
	Start = ffP.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z; 

//	if ( ffP != None )
//		ffP.ClientInstantFlash( -0.4, vect(450, 190, 650));
	Simulator = Spawn( class'XC_ProjSimulator',,, Start, ffRot );
	Simulator.SetupProj( ProjClass);
	return Simulator;
}

function TraceFire( float Accuracy )
{
	local Actor Other;
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X, Y, Z;
	local int ExtraFlags;
	
	if ( IsLC() )
		return;

	Owner.MakeNoise( Pawn(Owner).SoundDampening);
	GetAxes( Pawn(Owner).ViewRotation, X,Y,Z);
	StartTrace = GetStartTrace( ExtraFlags, X,Y,Z); 
	EndTrace = StartTrace 
		+ Accuracy * (FRand() - 0.5 ) * Y * 1000
		+ Accuracy * (FRand() - 0.5 ) * Z * 1000 ;

	if ( bBotSpecialMove && (Tracked != None)
		&& (((Owner.Acceleration == vect(0,0,0)) && (VSize(Owner.Velocity) < 40)) ||
			(Normal(Owner.Velocity) Dot Normal(Tracked.Velocity) > 0.95)) )
		EndTrace += GetRange( ExtraFlags) * Normal(Tracked.Location - StartTrace);
	else
	{
		AdjustedAim = Pawn(Owner).AdjustAim( 1000000, StartTrace, 2.75*AimError, False, False);	
		EndTrace += (GetRange( ExtraFlags) * vector(AdjustedAim)); 
	}

	Tracked = None;
	bBotSpecialMove = false;

	Other = Pawn(Owner).TraceShot(HitLocation,HitNormal,EndTrace,StartTrace);
	ProcessTraceHit(Other, HitLocation, HitNormal, vector(AdjustedAim),Y,Z);
}

simulated function ProcessTraceHit( Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	if (Other==None)
	{
		HitNormal = -X;
		HitLocation = Owner.Location + X*10000.0;
	}

	if ( bInstantFlash && (PlayerPawn(Owner) != None) )
		PlayerPawn(Owner).ClientInstantFlash( -0.4, vect(450, 190, 650));
	SpawnEffect(HitLocation, Owner.Location + CalcDrawOffset() + (FireOffset.X + 20) * X + FireOffset.Y * Y + FireOffset.Z * Z);

	if ( (ShockProj(Other) != None) && bCombo )
	{ 
		AmmoType.UseAmmo(2);
		ShockProj(Other).SuperExplosion();
	}
	else
		SpawnExplosion( HitLocation, HitNormal);

	if ( (Other != self) && (Other != Owner) && (Other != None) ) 
		Other.TakeDamage(HitDamage, Pawn(Owner), HitLocation, 60000.0*X, MyDamageType);
}

/** 
 * Visual effects
 *
 * Used in subclasses for minor modifications
*/

//Override whole function if we're using a significantly different beam
simulated function SpawnEffect( vector HitLocation, vector SmokeLocation)
{
	local Vector DVector;
	local int NumPoints;
	local rotator SmokeRotation;
	local ShockBeam Beam;
	
	DVector = HitLocation - SmokeLocation;
	NumPoints = VSize(DVector)/135.0;
	if ( NumPoints < 1 )
		return;
	SmokeRotation = rotator(DVector);
	SmokeRotation.Roll = Rand(65535);
	
	Beam = Spawn( class'FV_AdaptiveBeam',,, SmokeLocation, SmokeRotation);
	Beam.MoveAmount = DVector/NumPoints;
	Beam.NumPuffs = NumPoints - 1;	
	class'LCStatics'.static.SetHiddenEffect( Beam, Owner, LCChan);
	EditBeam( Beam);
}

simulated function SpawnExplosion( vector HitLocation, vector HitNormal)
{
	local Effects Explosion;

	Explosion = Spawn( ExplosionClass,,, HitLocation+HitNormal*8,rotator(HitNormal));
	class'LCStatics'.static.SetHiddenEffect( Explosion, Owner, LCChan);
	EditExplosion( Explosion);
}

simulated function EditBeam( ShockBeam Beam)
{
	if ( (BeamPrototype != None) && (FV_AdaptiveBeam(Beam) != None) )
		FV_AdaptiveBeam(Beam).AdaptFrom( BeamPrototype);
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
	Class'FVTeamShock'.static.SetStaticSkins( self);
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
	if ( bTeamColor )
		SetStaticSkins();
}
function SetSwitchPriority( Pawn Other)
{
	Class'LCStatics'.static.SetSwitchPriority( Other, self, 'ShockRifle');
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
	if ( bNoAmmoDeplete && AmmoType != none )
		AmmoType.AmmoAmount = AmmoType.MaxAmmo;
	return (LCChan != none) && LCChan.bUseLC && (LCChan.Owner == Owner);
}




defaultproperties
{
	ffRefireTimer=0.734
	FireAnimRate=0.6
	AltFireAnimRate=0.8
	ExplosionClass=class'FV_RingExplosion5'
	bCombo=True
	bInstantFlash=True
}
