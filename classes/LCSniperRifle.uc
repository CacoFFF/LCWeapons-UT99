//*************************************************
//**** ZP Sniper Rifle variation
//**** Made by Higor
//*************************************************

class LCSniperRifle expands SniperRifle;


var XC_CompensatorChannel LCChan;
var float ffRefireTimer; //This will enforce security checks
var float ffAimError; //If random seed != 0, do AimError serverside
var float FireAnimRate;
var int NormalDamage, HeadshotDamage;
var Texture Crosshair;
var Texture FirstPersonSkins[4];

replication
{
	reliable if ( Role == ROLE_Authority )
		FixOffset;
}



simulated function ModifyFireRate();

simulated event KillCredit( actor Other)
{
	if ( XC_CompensatorChannel(Other) != none )
	{
		LCChan = XC_CompensatorChannel(Other);
		if ( LCChan.bDelayedFire )
			class'LCStatics'.static.ClientTraceFire( self, LCChan, ffAimError);
	}
}

simulated event RenderOverlays( canvas Canvas )
{
	local int i;
	For ( i=0 ; i<4 ; i++ )
		if ( FirstPersonSkins[i] != None )
			MultiSkins[i] = FirstPersonSkins[i];
	Super.RenderOverlays(Canvas);
	For ( i=0 ; i<4 ; i++ )
		if ( FirstPersonSkins[i] != None )
			MultiSkins[i] = default.MultiSkins[i];
}

simulated function PlayPostSelect()
{
	if ( Level.NetMode == NM_Client )
		bCanClientFire = True;
	Super.PlayPostSelect();
}


function SetHand( float hand)
{
	Super.SetHand(hand);
	FixOffset(FireOffset.Y);
}

simulated function FixOffset( float Y)
{
	FireOffset.Y=Y;
}

simulated function bool IsLC()
{
	return (LCChan != none) && LCChan.bUseLC && (LCChan.Owner == Owner);
}

simulated function PlayFiring()
{
	ModifyFireRate();
	PlayOwnedSound(FireSound, SLOT_None, Pawn(Owner).SoundDampening*3.0);
	if ( FireAnimRate >= 2 )
		PlayAnim( FireAnims[4], FireAnimRate * (0.5 + 0.5 * FireAdjust), 0.05);
	else
		PlayAnim( FireAnims[Rand(5)], FireAnimRate * (0.5 + 0.5 * FireAdjust), 0.05);
	ffRefireTimer = class'LCStatics'.static.AnimationTime( self);
	
	if ( (PlayerPawn(Owner) != None) && (PlayerPawn(Owner).DesiredFOV == PlayerPawn(Owner).DefaultFOV) )
		bMuzzleFlash++;
	
	if ( IsLC() && (Level.NetMode == NM_Client) )
		LCChan.ClientFire();
}

//Modded for long range trace
function TraceFire( float Accuracy )
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local Actor Other;
	local Pawn PawnOwner;

	if ( IsLC() )
		return;
	if ( Accuracy == 0 )
		Accuracy = ffAimError;
	PawnOwner = Pawn(Owner);

	Owner.MakeNoise(PawnOwner.SoundDampening);
	GetAxes(PawnOwner.ViewRotation,X,Y,Z);
	StartTrace = Owner.Location + PawnOwner.Eyeheight * vect(0,0,1); 
	AdjustedAim = PawnOwner.AdjustAim(1000000, StartTrace, 2*AimError, False, False);	
	X = vector(AdjustedAim);
	EndTrace = StartTrace + 40000 * X; 
	//Careful, take into account our trace is 40k units instead of 10k so scale up/down down all aim error and accuracy on subclasses
	if ( Accuracy > 0 )
		EndTrace += Accuracy * (FRand() - 0.5 )* Y * 1000 + Accuracy * (FRand() - 0.5 ) * Z * 1000;
	Other = PawnOwner.TraceShot(HitLocation,HitNormal,EndTrace,StartTrace);
	ProcessTraceHit(Other, HitLocation, HitNormal, X,Y,Z);
}


simulated function ProcessTraceHit( Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local UT_Shellcase s;
	local Actor HitEffect;
	local bool bSpecialEff;

	bSpecialEff = IsLC() && (Level.NetMode != NM_Client); //Spawn for LC clients

	s = Spawn(class'FV_ShellCase',,, Owner.Location + CalcDrawOffset() + 30 * X + (2.8 * FireOffset.Y+5.0) * Y - Z * 1);
	if ( s != None ) 
	{
		s.DrawScale = 2.0;
		s.Eject(((FRand()*0.3+0.4)*X + (FRand()*0.2+0.2)*Y + (FRand()*0.3+1.0) * Z)*160); 
		class'LCStatics'.static.SetHiddenEffect( s, Owner, LCChan);
	}
	if ( Other == Level ) 
	{
		HitEffect = Spawn( class'FV_HeavyWallHitEffect',,, HitLocation+HitNormal, Rotator(HitNormal));
		class'LCStatics'.static.SetHiddenEffect( HitEffect, Owner, LCChan);
	}
	else if ( (Other != self) && (Other != Owner) && (Other != None) ) 
	{
		if ( Other.bIsPawn )
			Other.PlaySound(Sound 'ChunkHit',, 4.0,,100);
		if ( Level.NetMode != NM_Client )
		{
			if ( Other.bIsPawn && (HitLocation.Z - Other.Location.Z > HeadshotHeight(Pawn(Other)) ) 
				&& (instigator.IsA('PlayerPawn') || (instigator.IsA('Bot') && !Bot(Instigator).bNovice)) )
				Other.TakeDamage(HeadshotDamage, Pawn(Owner), HitLocation, 35000 * X, AltDamageType);
			else
				Other.TakeDamage(NormalDamage,  Pawn(Owner), HitLocation, 30000.0*X, MyDamageType);	
		}
		else if ( Other.bIsPawn && class'LCStatics'.static.RelevantHitActor( Other, PlayerPawn(Owner)) && (Pawn(Other).PlayerReplicationInfo == none || Pawn(Other).PlayerReplicationInfo.Team != Pawn(Owner).PlayerReplicationInfo.Team) )
		{
			Other.PlaySound(Sound'ChunkHit',,4.00,,100.00);
			Spawn(Class'UT_BloodHit',None,,HitLocation + 0.20 * Other.CollisionRadius * HitNormal, rotator(HitNormal));
		}
		if ( !Other.bIsPawn && !Other.IsA('Carcass') )
		{
			HitEffect = Spawn( class'FV_SpriteSmokePuff',,, HitLocation+HitNormal*9);
			class'LCStatics'.static.SetHiddenEffect( HitEffect, Owner, LCChan);
		}
	}
}

//Screw this shit
static function float HeadshotHeight( Pawn Other)
{
	local float Result;
	
	Result = Other.CollisionHeight * 0.62;
	if ( Other.BaseEyeHeight < Other.default.BaseEyeHeight )
		Result *= fMax( 0.2, Other.BaseEyeHeight / Other.default.BaseEyeHeight);
	
	return Result;
}

simulated function bool FiringAnimation()
{
	local int i;
	For ( i=0 ; i<5 ; i++ )
		if ( AnimSequence == FireAnims[i] )
			return true;
	return false;
}

//***********************************************************************
//Fix Idle's fire override causing misordered PlayFiring/TraceFire events
//***********************************************************************
state Idle
{
	function Fire( float Value )
	{
		if ( Owner.IsA('Bot') )
		{
			// simulate bot using zoom
			if ( Bot(Owner).bSniping && (FRand() < 0.65) )
				AimError = AimError/FClamp(StillTime, 1.0, 8.0);
			else if ( VSize(Owner.Location - OwnerLocation) < 6 )
				AimError = AimError/FClamp(0.5 * StillTime, 1.0, 3.0);
			else
				StillTime = 0;
		}			
		Global.Fire( Value);
		AimError = Default.AimError;
	}
	
Begin:
	bPointing=False;
	if ( AmmoType.AmmoAmount <= 0 ) 
		Pawn(Owner).SwitchToBestWeapon();  //Goto Weapon that has Ammo
	if ( Pawn(Owner).bFire!=0 ) Fire(0.0);
	Disable('AnimEnd');
	PlayIdleAnim();
}


//***********************************************************************
// LCWeapons common interfaces
//***********************************************************************
function Inventory SpawnCopy( Pawn Other )
{
	return Class'LCStatics'.static.SpawnCopy( Other, self);
}
function GiveTo( Pawn Other )
{
	Class'LCStatics'.static.GiveTo( Other, self);
}
function SetSwitchPriority( Pawn Other)
{
	Class'LCStatics'.static.SetSwitchPriority( Other, self, 'SniperRifle');
}
simulated function float GetRange( out int ExtraFlags)
{
	return 40000;
}
simulated function vector GetStartTrace( out int ExtraFlags, vector X, vector Y, vector Z)
{
	return Owner.Location + Pawn(Owner).Eyeheight * vect(0,0,1);
}



defaultproperties
{
	ffRefireTimer=0.65
	FireAnimRate=1.0
	NormalDamage=45
	HeadshotDamage=100
}