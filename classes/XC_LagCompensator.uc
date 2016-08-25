//=============================================================================
// XC_LagCompensator.
// Made by Higor
//=============================================================================
class XC_LagCompensator expands Info;

//OBFSTART

var XC_LagCompensation ffMaster;
var XC_LagCompensator ffCompNext;
var XC_CompensatorChannel CompChannel;
var pawn ffOwner;
var XC_PlayerPosList PosList;
var bool ffNoHit; //Fast access
var int ffDelaying; //We're delaying hits in order to fix our time formula
var Weapon ffWeapon;
var float ffCTimer; //Timer our last shot was fired
var float ffCTimeStamp; //Timestamp the server is keeping
var float ffDelayCount;
var int ffLastPing;
var float ffLastTimeSeconds;
var float ffRefireTimer; //If above shoot * 2, do not fire
var float ffCurRegTimer; //Current registered timer
var float ImpreciseTimer; //Give the player an opportunity to miss security checks once in a while

var private bool ffCollideActors, ffBlockActors, ffBlockPlayers, ffProjTarget;
var int ffMyShit;

struct XC_PlayerPos
{
	var() vector Location;
	var() float ExtraDist;
};


event PreBeginPlay() //Prevent destruction
{
}

event Tick( private float ffDelta)
{
	local private float ffTmp;

	//Get rid of this compensator
	if ( (ffOwner == none) || ffOwner.bDeleteMe )
	{
		Destroy();
		return;
	}

	if ( (PlayerPawn(ffOwner) != none) && FRand() < 0.4 )
		ffLastPing = int(PlayerPawn(ffOwner).ConsoleCommand("GETPING"));

	if ( Level.TimeSeconds - ffLastTimeSeconds > 0.5 * Level.TimeDilation ) //Frame took over 0.5 second!!! (game was paused)
		ffCorrectTimes( ffDelta);

	ffLastTimeSeconds = Level.TimeSeconds;

	//Dead
	if ( ffOwner.Health <= 0 )
	{
		ffNoHit = true;
		ffWeapon = none;
		ffResetTimeStamp();
		return;
	}
	ImpreciseTimer = fMax( 0, ImpreciseTimer - ffDelta);

	//Weapon check
	if ( ffOwner.Weapon != ffWeapon )
	{
		ffWeapon = ffOwner.Weapon;
		ffResetTimeStamp();
	}

	//Client needs correction, shots aren't processed in the mean time
	if ( ffCTimeStamp != 0 )
	{
		if ( ffDelaying != 0 )
		{
			ffCTimeStamp += ffDelta * float(ffDelaying);
			if ( ffDelaying < 0 )
			{
				ffCTimeStamp -= ffDelta * 0.5; //Delaying backwards is done faster, client had a lockup
				ffDelayCount -= ffDelta * 0.5;
			}
			if ( (ffDelayCount -= ffDelta) <= 0 )
				ffDelaying = 0;
		}
		if ( ffRefireTimer > ffCurRegTimer * 1.4 + 0.2 * Level.TimeDilation)
			ffRefireTimer -= ffDelta * 0.7; //Punish those who use FWS
		else
			ffRefireTimer -= ffDelta;
		ffRefireTimer = fMax( 0, ffRefireTimer);
		ffCTimeStamp += ffDelta; //No error, we're keeping this shit sincronized
		ffCTimer += ffDelta / Level.TimeDilation;
	}

	ffNoHit = false;
}

function ffCorrectTimes( private float ffDelta)
{
	local private float ffTmp;

	ffTmp = Level.TimeSeconds - ffLastTimeSeconds;
	ffTmp -= ffDelta;
	PosList.CorrectTimeStamp( ffTmp);
	ffResetTimeStamp();
}

//Allow or deny hit
function bool ffClassifyShot( private float ffClientTimeS)
{
	local private float ffTmp;

//	Log("Recorded Timer: "$ffCTimeStamp$", Shot timer: "$ffClientTimeS);

	if ( ffDelaying != 0 ) //We're delaying sped up shots, so don't fire
	{
		Log("CLIENT SHOT DENIED, ALLOWING IN "$ffDelayCount,'LagCompensator');
		return false;
	}
	if ( ffCTimeStamp == 0 )
		ffCTimeStamp = ffClientTimeS;
	if ( ffRefireTimer > ffCurRegTimer + 0.2 * Level.TimeDilation )
	{
		Log("Refire timer is too high: "$ffRefireTimer, 'LagCompensator');
		return false;
	}
	//Too much difference between 1 shot and other
	ffTmp = ffClientTimeS - ffCTimeStamp;
	if ( ffTmp > (0.5 * Level.TimeDilation) ) //Client is too ahead
	{
		ffDelaying = 1; //Delay the ffCTimeStamp forward
		ffDelayCount = ffTmp;
		Log("CLIENT TIMING IS TOO AHEAD "$ffTmp, 'LagCompensator');
		return false;
	}
	else if ( abs(ffTmp) > (0.5 * Level.TimeDilation) ) //Client is too behind
	{
		ffDelaying = -1; //Delay the ffCTimeStamp backwards
		ffDelayCount = -ffTmp; //Because ffTmp is negative
		Log("CLIENT TIMING IS TOO BEHIND "$ffTmp, 'LagCompensator');
		return false;
	}
	return true;
}

function Pawn ffCheckHit( private int ffID, private vector ffHit, private vector ffOff, private rotator ffView)
{
	local private XC_LagCompensator ffOther;
	local private float ffPing, ffBox;
	local private XC_PlayerPos ffFirst, ffLast;
	local private vector ffProj;
	local private float ffTmp;
	local bool bImageDropping;
	local byte Slot;

	ffOther = ffMaster.ffCompList;
	While ( ffOther != none )
	{
		if ( Class'LCStatics'.static.ffPCode(ffOther.ffOwner) == ffID )
			break;
		ffOther = ffOther.ffCompNext;
	}
	if ( ffOther == none )
		return none;
		
	if ( !FastTrace( ffHit, ffOwner.Location + vect(0,0,1) * ffOwner.BaseEyeHeight) )  //Amplify!!!
		return none;

	ffPing = float(ffLastPing) / 1000.0;
//	ffError = 0.019 + ffPing * 0.11; //If we have 200 ping, error is of 41; a base of 19 is added for server tickrate unreliability
// Old error, may be reused later

	ffHit -= ffOff;

	ffBox = VSize( vect(1,0,0) * ffOther.ffOwner.CollisionHeight + vect(0,1,0) * ffOther.ffOwner.CollisionRadius);
	ffBox *= 1.2; //Main tweak
	ffBox += VSize( ffOther.ffOwner.Location - ffOther.ffOwner.OldLocation ); //Moving? Increase box size
	if ( VSize(ffOther.ffOwner.Velocity) > 600 )
		ffBox *= 1 + (VSize(ffOther.ffOwner.Velocity) - 600) / 1500; //if velocity is 2500 (terminal), error is multiplied by almost 3 (super booster hit ensured)

	//Find the 2 slotted locs we're using
	Slot = ffOther.PosList.FindTopSlot( ffPing);
	ffFirst = ConvertPSlot( ffOther.PosList, Slot);
	ffLast = ConvertPSlot( ffOther.PosList, (Slot-1)%128);
	
	//Let's see if the line's doing something!
	if ( ffOther.PosList.HasDucked( Slot) )
	{
		ffPing = ffOther.ffOwner.BaseEyeHeight;
		ffOther.ffOwner.BaseEyeHeight = 0;
		ffOff = Class'LCStatics'.static.CylinderEntrance( ffOff, vector(ffView), ffOther.ffOwner.CollisionRadius, ffOther.ffOwner.CollisionHeight );
		ffOff += ffOther.ffOwner.Location;
		if ( !ffOther.ffOwner.AdjustHitLocation( ffOff, vector(ffView)) )
		{
			ffOther.ffOwner.BaseEyeHeight = ffPing;
			return none; //Show went through
		}
		ffOther.ffOwner.BaseEyeHeight = ffPing;
	}

	if ( VSize( ffFirst.Location - ffHit) > (ffBox * 2 + ffFirst.ExtraDist + ffLast.ExtraDist) )	//Aim error is huge
	{
		if ( !ImageDropping(ffOther.ffOwner, (ffFirst.Location - ffHit) * 0.5) ) //Target is image dropping, analyse after
		{
			Log("Fail on pass 1: "$VSize( ffFirst.Location - ffHit)$" is the failed size", 'LagCompensator');
			return none;
		}
	}

	//Check if both segments are in the same point
	ffTmp = FixMathDist( ffFirst.Location, ffLast.Location );
	if ( ffTmp < 3 )
	{
		if ( (VSize( ffFirst.Location - ffHit) < ffBox) || ImageDropping(ffOther.ffOwner, ffFirst.Location - ffHit) ) //Single box
			return ffOther.ffOwner;
		Log("Fail on pass 2.5: "$ffBox$" is the ffBox size, "$ VSize( ffFirst.Location - ffHit) $" is the point distance", 'LagCompensator');
	}
	//Get orthogonal projection from hit location in our segment
	ffProj = ffFirst.Location + Normal( ffLast.Location - ffFirst.Location ) * ((( ffLast.Location - ffFirst.Location ) dot ( ffHit - ffFirst.Location )) / ffTmp);
	if ( VSize(ffProj - ffHit) < ffBox * 1.2) //120% box, simulation on low TR servers is horrible
		return ffOther.ffOwner;
	Log("Fail on pass 3: "$ffBox$" is the ffBox size, "$VSize(ffProj - ffHit)$" is the projection distance", 'LagCompensator');
	//Math problem, do full log here
	if ( string(VSize(ffProj - ffHit)) == "-1.#IND00" )
	{
		return ffOther.ffOwner; //Fuck it
		Log("MATH PROBLEM!"@ ffProj @ "is projection",'LagCompensator');
		Log("MATH PROBLEM!"@ ffHit @ "is HIT",'LagCompenstor');
		Log("MATH PROBLEM!"@ ffFirst.Location @ "is Start loc",'LagCompensator');
		Log("MATH PROBLEM!"@ ffLast.Location @ "is End loc",'LagCompensator');
	}
	return none;
}

function ffResetTimeStamp()
{
	ffDelaying = 0;
	ffDelayCount = 0;
	ffCTimeStamp = 0;
	ffCurRegTimer = 0;
	ffRefireTimer = 0;
	ImpreciseTimer = 0;
}

function XC_PlayerPos ConvertPSlot( XC_PlayerPosList List, int Slot)
{
	local XC_PlayerPos Pos;
	
	Pos.Location = List.GetLoc( Slot);
	Pos.ExtraDist = List.GetEDist(Slot);
	return Pos;
}


function ffGetCollision()
{
	ffCollideActors = ffOwner.bCollideActors;
	ffBlockActors = ffOwner.bBlockActors;
	ffBlockPlayers = ffOwner.bBlockPlayers;
	ffProjTarget = ffOwner.bProjTarget;
}

function ffSetCollision()
{
	ffOwner.SetCollision( ffCollideActors, ffBlockActors, ffBlockPlayers);
	ffOwner.bProjTarget = ffProjTarget;
}

function ffNoCollision()
{
	ffOwner.SetCollision( false, false, false);
	ffOwner.bProjTarget = false;
}

event Destroyed()
{
	local private XC_LagCompensator ffTmp;

	if ( PosList != none )
		PosList.Destroy();

	if ( ffMaster.ffCompList == self )
		ffMaster.ffCompList = ffCompNext;
	else
	{
		For ( ffTmp=ffMaster.ffCompList ; ffTmp!=none ; ffTmp=ffTmp.ffCompNext )
			if ( ffTmp.ffCompNext == self )
			{
				ffTmp.ffCompNext = ffCompNext;
				ffCompNext = none;
				SetOwner(none); //Graceful destruction
				break;
			}
	}
}
//OBFEND

function bool ImageDropping( Pawn Other, vector HitDir)
{
	if ( (HitDir.Z < 40) || (Other.Velocity != vect(0,0,0)) || (Other.Physics != PHYS_Walking) )
		return false; //Minimum threshold
	return Normal(HitDir).Z > 0.75; //40º angle fall	
}

//Attempt to fix math errors with substracting vectors in V451
function float FixMathDist( vector A, vector B)
{
	local int i;
	i = A.X;
	i -= int(B.X);
	A.X = i;
	i = A.Y;
	i -= int(B.Y);
	A.Y = i;
	i = A.Z;
	i -= int(B.Z);
	A.Z = i;
	return VSize( A);
}

defaultproperties
{
    bGameRelevant=True
	RemoteRole=ROLE_None
	bCollideWhenPlacing=False
}
