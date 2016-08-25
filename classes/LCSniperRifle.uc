//*************************************************
//**** ZP Sniper Rifle variation
//**** Made by Higor
//*************************************************

class LCSniperRifle expands SniperRifle;


var XC_CompensatorChannel LCChan;
var bool bSimulatingEffect;
var float ffRefireTimer; //This will enforce security checks
var float ffAimError; //If random seed != 0, do AimError serverside
var int NormalDamage, HeadshotDamage;

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
	Class'LCStatics'.static.SetSwitchPriority( Other, self, 'SniperRifle');
}

simulated event KillCredit( actor Other)
{
	if ( XC_CompensatorChannel(Other) != none )
	{
		LCChan = XC_CompensatorChannel(Other);
		if ( LCChan.bDelayedFire )
		{
			LCChan.bDelayedFire = false;
			ffTraceFire();
		}
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

simulated function PlayFiring()
{
	Super.PlayFiring();
	if ( IsLC() && (Level.NetMode == NM_Client) )
		LCChan.bDelayedFire = true;
}

//Modded for long range trace
function TraceFire( float Accuracy )
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local actor Other;
	local Pawn PawnOwner;

	if ( IsLC() )
		return;
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


simulated function ffTraceFire( optional float Accuracy)
{
	local private PlayerPawn ffP;
	local private vector X,Y,Z, ffHitLocation, ffHitNormal, ffStartTrace, ffEndTrace;
	local private actor ffOther;
	local private rotator ffRot;
	local int Seed;

	ffP = PlayerPawn(Owner);
	if ( ffP == none )	return;

	ffRot = class'LCStatics'.static.PlayerRot( ffP);
	GetAxes( ffRot, X,Y,Z );
	
	ffStartTrace = ffP.Location + ffP.Eyeheight * vect(0,0,1); 
	ffEndTrace = ffStartTrace + 40000 * X; 
	if ( Accuracy > 0 )
	{
		Seed = Rand( MaxInt) & 65535;
		ffEndTrace += class'LCStatics'.static.StaticAimError( Y, Z, Accuracy, Seed);
		Seed = Seed << 16;
	}
	ffOther = Class'LCStatics'.static.ffTraceShot(ffHitLocation,ffHitNormal,ffEndTrace,ffStartTrace,ffP);
	ProcessTraceHit( ffOther, ffHitLocation, ffHitNormal, X, Y, Z);
	if ( (Pawn(ffOther) != none) && (Pawn(ffOther).PlayerReplicationInfo != none ) )
		LCChan.ffSendHit( none, self, class'LCStatics'.static.ffPCode(Pawn(ffOther)), Level.TimeSeconds, ffHitLocation, ffHitLocation - ffOther.Location, ffRot, ffStartTrace, class'LCStatics'.static.CompressRotator(ffRot), 12 | Seed, Accuracy);
	else
		LCChan.ffSendHit( ffOther, self, -1, Level.TimeSeconds, ffHitLocation, ffHitLocation - ffOther.Location, ffRot, ffStartTrace, class'LCStatics'.static.CompressRotator(ffRot), 12 | Seed, Accuracy);
}

simulated function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local UT_Shellcase s;
	local bool bSpecialEff;

	bSpecialEff = IsLC() && (Level.NetMode != NM_Client); //Spawn for LC clients

	if ( bSpecialEff )
		s = Spawn(class'zp_ShellCase',Owner, '', Owner.Location + CalcDrawOffset() + 30 * X + (2.8 * FireOffset.Y+5.0) * Y - Z * 1);
	else
		s = Spawn(class'UT_ShellCase',, '', Owner.Location + CalcDrawOffset() + 30 * X + (2.8 * FireOffset.Y+5.0) * Y - Z * 1);

	if ( s != None ) 
	{
		s.DrawScale = 2.0;
		s.Eject(((FRand()*0.3+0.4)*X + (FRand()*0.2+0.2)*Y + (FRand()*0.3+1.0) * Z)*160);              
	}
	if (Other == Level) 
	{
		if ( bSpecialEff )		Spawn(class'zp_HeavyWallHitEffect',Owner,, HitLocation+HitNormal, Rotator(HitNormal));
		else		Spawn(class'UT_HeavyWallHitEffect',,, HitLocation+HitNormal, Rotator(HitNormal));
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
			if ( bSpecialEff )			spawn(class'zp_SpriteSmokePuff',Owner,,HitLocation+HitNormal*9);	
			else			spawn(class'UT_SpriteSmokePuff',,,HitLocation+HitNormal*9);	
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

defaultproperties
{
	ffRefireTimer=0.649
	NormalDamage=45
	HeadshotDamage=100
}