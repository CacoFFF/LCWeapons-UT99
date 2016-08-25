//*************************************************
//**** ZP Shock Rifle variation
//**** Made by Higor
//*************************************************

class LCShockRifle expands ShockRifle;


var XC_CompensatorChannel LCChan;
var bool bSimulatingEffect;
var bool bNoAmmoDeplete;
var bool bTeamColor;
var float ffRefireTimer; //This will enforce security checks

var class<ShockBeam> GlobalBeam;
var class<ShockBeam> HiddenBeam;
var class<Effects> GlobalExplosion;
var class<Effects> HiddenExplosion;

replication
{
	reliable if ( Role == ROLE_Authority )
		FixOffset;
	reliable if ( Role == ROLE_Authority )
		bTeamColor;
}

function Inventory SpawnCopy( pawn Other )
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
	Class'LCStatics'.static.SetSwitchPriority( Other, self, 'ShockRifle');
}

simulated event KillCredit( actor Other)
{
	if ( XC_CompensatorChannel(Other) != none )
	{
		LCChan = XC_CompensatorChannel(Other);
		if ( LCChan.bDelayedFire )
			ffTraceFire();
		else if ( LCChan.bDelayedAltFire && (AltProjectileClass != none) )
			ffSimProj(AltProjectileClass, AltProjectileClass.Default.Speed);

	}
	else if ( LCMutator(Other) != none )
	{
		if ( LCMutator(Other).bTeamShock && (Class == class'LCShockRifle') )
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
	if ( bNoAmmoDeplete && AmmoType != none )
		AmmoType.AmmoAmount = AmmoType.MaxAmmo;
	return (LCChan != none) && LCChan.bUseLC && (LCChan.Owner == Owner);
}

simulated function PlayFiring()
{
	Super.PlayFiring();
	if ( IsLC() && (Level.NetMode == NM_Client) )
		LCChan.bDelayedFire = true;
	if ( bTeamColor )
		SetStaticSkins();
}

simulated function PlayAltFiring()
{
	Super.PlayAltFiring();
	if ( IsLC() && (Level.NetMode == NM_Client) )
		LCChan.bDelayedAltFire = true;
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
	{
		if ( ffOther == none )
			LCChan.ffSendHit( ffOther, self, -1, Level.TimeSeconds, ffHitLocation, vect(0,0,0), ffRot, ffStartTrace, class'LCStatics'.static.CompressRotator(ffRot), 3);
		else
			LCChan.ffSendHit( ffOther, self, -1, Level.TimeSeconds, ffHitLocation, ffHitLocation - ffOther.Location, ffRot, ffStartTrace, class'LCStatics'.static.CompressRotator(ffRot), 3);
	}
}

simulated function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local bool bSpecialEff;
	local Effects Explosion;

	bSpecialEff = IsLC() && (Level.NetMode != NM_Client); //Spawn for LC clients

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
		if ( bSpecialEff && LCChan.LCActor.bNeedsHiddenEffects )
			Explosion = Spawn(HiddenExplosion,Owner,, HitLocation+HitNormal*8,rotator(HitNormal));
		else
		{
			Explosion = Spawn(GlobalExplosion,Owner,, HitLocation+HitNormal*8,rotator(HitNormal));
			Explosion.SetPropertyText("bNotRelevantToOwner",string(bSpecialEff));
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
	local bool bIsLC;

	DVector = HitLocation - SmokeLocation;
	NumPoints = VSize(DVector)/135.0;
	if ( NumPoints < 1 )
		return;
	SmokeRotation = rotator(DVector);
	SmokeRotation.roll = Rand(65535);
	
	bIsLC = IsLC();
	if ( bIsLC && (Level.NetMode != NM_Client) && LCChan.LCActor.bNeedsHiddenEffects )
		Smoke = Spawn( HiddenBeam,Owner,,SmokeLocation,SmokeRotation);
	else
	{
		Smoke = Spawn( GlobalBeam,Owner,,SmokeLocation,SmokeRotation);
		Smoke.SetPropertyText("bNotRelevantToOwner",string(bIsLC));
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
	Class'FVTeamShock'.static.SetStaticSkins( self);
}


defaultproperties
{
	ffRefireTimer=0.734
	GlobalBeam=class'FV_AdaptiveBeam'
	HiddenBeam=class'FV_LCAdaptiveBeam'
	GlobalExplosion=class'Botpack.ut_RingExplosion5'
	HiddenExplosion=class'LCRingExplosion5'
}
