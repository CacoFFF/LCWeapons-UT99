//=============================================================================
// XC_LagCompensator.
// Made by Higor
//=============================================================================
class XC_LagCompensator expands Info;

const LCS = class'LCStatics';

var XC_LagCompensation Mutator;
var XC_LagCompensator ffCompNext;
var XC_CompensatorChannel CompChannel;
var Pawn ffOwner;
var XC_PosList PosList;
var bool ffNoHit; //Fast access
var int ffDelaying; //We're delaying hits in order to fix our time formula
var Weapon ffWeapon;
var float ffCTimer; //Timer our last shot was fired
var float ffCTimeStamp; //Timestamp the server is keeping
var float ffDelayCount;
var int ffLastPing;
var float ffRefireTimer; //If above shoot * 2, do not fire
var float ffCurRegTimer; //Current registered timer
var float ImpreciseTimer; //Give the player an opportunity to miss security checks once in a while

var private bool ffCollideActors, ffBlockActors, ffBlockPlayers, ffProjTarget;


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

	//Dead
	if ( ffOwner.Health <= 0 )
	{
		ffNoHit = true;
		ffWeapon = none;
		ResetTimeStamp();
		return;
	}
	ImpreciseTimer = fMax( 0, ImpreciseTimer - ffDelta);

	//Weapon check
	if ( ffOwner.Weapon != ffWeapon )
	{
		ffWeapon = ffOwner.Weapon;
		ResetTimeStamp();
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



function bool ValidateWeapon( Weapon Weapon, out byte Imprecise)
{
	if ( Weapon == none || Weapon.bDeleteMe || ffOwner.Weapon != Weapon //Fixes a weapon toss exploit that allows teamkilling
	|| Weapon.GetPropertyText("LCChan") == "" ) //Do not crash server 
	{
		Imprecise = 20;
		return false;
	}

	return true;
}

function bool ValidateCylinder( Actor Other, vector HitOffset, vector TraceDir, out byte Imprecise, out string Error)
{
	local int i;
	local float Radius, Height;

	if ( (Other == None) || (Other == Level) || (Other.Brush != None) || Other.IsA('StaticMeshActor') ) //Levels, Movers and StaticMesh (future) are always valid boxes
		return true;

	Radius = Other.CollisionRadius;
	Height = Other.CollisionHeight;
	if ( XC_PosList(Other) != None )
	{
		//TODO: GET REALCROUCH STATUS
		Other = Other.Owner;
		Radius = Other.CollisionRadius;
		Height = Other.CollisionHeight;
	}
	TraceDir = Normal(TraceDir);
	Radius += 1; //Account for rounding errors in HitOffset and TraceDir
	Height += 1;
	if ( (LCS.static.HSize(HitOffset) <= Radius) && (Abs(HitOffset.Z) <= Height) )
		return true;
	Imprecise = 20;
	Error = "Hit Offset outside of target cylinder ["$int(LCS.static.HSize(HitOffset))$","$int(Abs(HitOffset.Z))$"]/["$int(Radius)$","$int(Height)$"]";
	return false;
}

/*
function bool ValidatePawnHit( Pawn Other, out vector HitOffset, vector TraceDir, float EyeHeight, out byte Imprecise, out string Error)
{
	local vector HitLocation;
	
	HitLocation = Other.Location + HitOffset;
	if ( !LCS.static.AdjustHitLocationMod( Other, HitLocation, TraceDir, EyeHeight)
}
*/

function bool ValidatePlayerView( float ClientTimeStamp, vector StartTrace, int CmpRot, out byte Imprecise, out string Error)
{
	local rotator ClientView, ServerView;
	local float alpha, lag, maxdelta;
	local vector PlayerPos, X, Y, Z;
	local PlayerPawn Player;
	local bool bApproximateView;
	
	Player = PlayerPawn(ffOwner);
	PlayerPos = Player.Location;
	ClientView = LCS.static.DecompressRotator( CmpRot);
	ServerView = Player.ViewRotation;
	if ( ClientTimeStamp > Player.CurrentTimeStamp ) //Wait
		return false;

	//Anything past this stage should be full reject
	Imprecise += 20;
	if ( ClientTimeStamp < Player.CurrentTimeStamp )
	{
		bApproximateView = true;
		alpha = (ClientTimeStamp-CompChannel.OldTimeStamp)/(Player.CurrentTimeStamp-CompChannel.OldTimeStamp);
		ServerView = LCS.static.AlphaRotation( ServerView, CompChannel.OldView, alpha );
		PlayerPos = CompChannel.OldPosition + (Player.Location - CompChannel.OldPosition) * alpha;
	}
	
	//Validate view
	if ( bApproximateView )
	{
		if ( LCS.static.CompareRotation( ServerView, ClientView) ) //Perfect match (stationary view)
		{}
		else if ( (ServerView.Pitch == 0) && (ServerView.Yaw == 0) && (ServerView.Roll == 0) ) //v469 is doing weird things here
		{}
		else if ( LCS.static.ContainsRotator( ClientView, Player.ViewRotation, CompChannel.OldView, 0.5) ) //Contained in move area
			Imprecise++;
		else if ( (ServerView.Pitch != 0) && (ServerView.Yaw != 0) && (ServerView.Roll != 0) )
		{
			Error = "ROTATION INCONSISTENCY"@ServerView@ClientView;
			return false;
		}
	}
	else if ( !LCS.static.CompareRotation( ServerView, ClientView) )
	{
		Error = "ROTATION MISMATCH"@ServerView@ClientView;
		return false;
	}

	//Validate shot starting position
	lag = float(ffLastPing) * Level.TimeDilation * 0.001;
	maxdelta = 20 + lag * 35 + VSize(Player.Velocity) * 0.10;
	if ( Player.Base != None )
	{
		PlayerPos -= Player.Base.Velocity * (lag * 0.5); //Adjust to base
		maxdelta += VSize(Player.Base.Velocity) * 0.10 * (1 + lag * 2);
	}
	if ( Player.DodgeDir == DODGE_Active )
		maxdelta += Player.GroundSpeed * lag;
	if ( Player.Weapon != None )
	{
		if ( LCSniperRifle(Player.Weapon) != None )
			PlayerPos.Z += Player.EyeHeight;
		else
		{
			GetAxes( ClientView, X, Y, Z);
			PlayerPos += Player.Weapon.CalcDrawOffset() + Player.Weapon.FireOffset.Y * Y + Player.Weapon.FireOffset.Z * Z; 
		}
	}
	alpha = VSize( PlayerPos - StartTrace);
	if ( alpha > maxdelta*2 ) //Diff too big
	{
		Error = "LOCATION DIFF = "$alpha@"vs"@(maxdelta*2);
		return false;
	}
	if ( alpha > maxdelta )
		Imprecise++;
		
	Imprecise -= 20; //Undo reject
	return true;
}

function bool ValidateAccuracy( Weapon Weapon, int CmpRot, vector Start, vector End, float Accuracy, int Flags, out byte Imprecise, out string Error)
{
	local rotator View;
	local vector X, Y, Z;

	if ( Accuracy != LCS.static.GetAimError(Weapon) ) //Weapon aim error mismatch
	{
		Error = "Aim error mismatch:"@Accuracy@"vs"@LCS.static.GetAimError(Weapon);
		return false; //Delay
	}
	
	View = LCS.static.DecompressRotator( CmpRot);
	GetAxes( View, X,Y,Z);
	if ( Accuracy != 0 ) //Need to reprocess end point
	{	
		X = Normal( X * LCS.static.GetRange( Weapon, Flags) 
			+ LCS.static.StaticAimError( Y, Z, Accuracy, Flags >>> 16) );
	}

	if ( (VSize(End-Start) > 30) && (VSize( X - Normal(End-Start)) > 0.05) )
	{
		if ( (Imprecise > 0) || (VSize( X - Normal(End-Start)) > 0.20) )
		{
			Imprecise = 20;
			Error = "DIRECTION DIFF IS :"$ VSize( X - Normal(End-Start));
			return false; //Reject
		}
		Imprecise++;	
	}
	return true;
}

function bool ValidateWeaponRange( Weapon Weapon, int ExtraFlags, vector StartTrace, vector HitLocation, int CmpRot, out byte Imprecise, out string Error)
{
	local rotator PlayerView;
	local vector X, Y, Z;
	local float Range;
	local int NewExtraFlags;
	local float YDist;
	
	NewExtraFlags = ExtraFlags;
	Range      = LCS.static.GetRange( Weapon, NewExtraFlags);
	PlayerView = LCS.static.DecompressRotator( CmpRot);
	GetAxes( PlayerView, X, Y, Z);
	YDist = ((HitLocation - StartTrace) dot X) - 1;
	
	if ( NewExtraFlags != ExtraFlags )
	{
		Imprecise = 20;
		Error = "Bad range flags: ("$ExtraFlags$"/"$NewExtraFlags$")";
		return false;
	}
	
	if ( YDist <= Range )
		return true;
		
	Imprecise += 1;
	if ( YDist <= (Range * 0.01) )
		return true;
		
	Imprecise = 20;
	Error = "Bad weapon range: ("$int(YDist)$"/"$int(Range)$")";
	return false;
}


//Allow or deny hit
function bool ffClassifyShot( private float ffClientTimeS)
{
	local private float ffTmp;

//	Log("Recorded Timer: "$ffCTimeStamp$", Shot timer: "$ffClientTimeS);

	if ( ffDelaying != 0 ) //We're delaying sped up shots, so don't fire
	{
		CompChannel.RejectShot("DENIED, ALLOWING IN "$ffDelayCount);
		return false;
	}
	if ( ffCTimeStamp == 0 )
		ffCTimeStamp = ffClientTimeS;
	if ( ffRefireTimer > ffCurRegTimer + 0.2 * Level.TimeDilation )
	{
		CompChannel.RejectShot("Refire timer is too high: "$ffRefireTimer);
		return false;
	}
	//Too much difference between 1 shot and other
	ffTmp = ffClientTimeS - ffCTimeStamp;
	if ( ffTmp > (0.5 * Level.TimeDilation) ) //Client is too ahead
	{
		ffDelaying = 1; //Delay the ffCTimeStamp forward
		ffDelayCount = ffTmp;
		CompChannel.RejectShot("CLIENT TIMING IS TOO AHEAD "$ffTmp);
		return false;
	}
	else if ( abs(ffTmp) > (0.5 * Level.TimeDilation) ) //Client is too behind
	{
		ffDelaying = -1; //Delay the ffCTimeStamp backwards
		ffDelayCount = -ffTmp; //Because ffTmp is negative
		CompChannel.RejectShot("CLIENT TIMING IS TOO BEHIND "$ffTmp);
		return false;
	}
	return true;
}

function Pawn ffCheckHit( XC_LagCompensator ffOther, vector HitLocation, out vector HitOffset, private rotator ffView, out string Error)
{
	local private float ffBox;
	local private vector ffProj;
	local vector RealPosition, ClientPosition, PositionDiff, RealVelocity;
	local Pawn Other;
	local int Index, IndexNext;
	local bool bPassAdjustHitLocation;

	Assert( ffOther != None );
	Other = ffOther.ffOwner;
	Assert( Other != None );
		
	if ( !FastTrace( HitLocation, ffOwner.Location + vect(0,0,1) * ffOwner.BaseEyeHeight) )  //Amplify!!!
	{
		Error = "Visibility check failed";
		return none;
	}

	//Obtain position slots
	Mutator.Marker[0] = Mutator.GetOldPositionIndex( GetLatency() );
	Index = Mutator.Marker[0].Index;
	IndexNext = Mutator.Marker[0].IndexNext;
	ClientPosition = HitLocation - HitOffset;
	RealPosition = ffOther.PosList.GetOldPosition( Index, IndexNext, Mutator.Marker[0].Alpha );
	RealVelocity = ffOther.PosList.GetVelocity( Index, IndexNext );
	PositionDiff = RealPosition - ClientPosition;

	ffBox = VSize( ffOther.PosList.GetExtent(Mutator.Marker[0].Index) );
	ffBox *= 1.2; //Main tweak
	ffBox += VSize( RealVelocity * Mutator.PositionStep ); //Moving? Increase box size
	if ( VSize(RealVelocity) > 600 )
		ffBox *= 1 + (VSize(RealVelocity) - 600) / 1500; //if velocity is 2500 (terminal), error is multiplied by almost 3 (super booster hit ensured)
	
	//Apply AdjustHitLocation validation (try passing in multiple ways)
	if ( HitOffset.Z > 0 ) //Adjust downward to make up for rounding
		HitOffset.Z -= 0.1;
	HitOffset += Other.Location;
	bPassAdjustHitLocation = LCS.static.AdjustHitLocationMod( Other, HitOffset, vector(ffView), ffOther.PosList.EyeHeight[Index]);
	if ( !bPassAdjustHitLocation && (IndexNext >= 0) ) //Fail, try passing with next slot
		bPassAdjustHitLocation = LCS.static.AdjustHitLocationMod( Other, HitOffset, vector(ffView), ffOther.PosList.EyeHeight[IndexNext]);
	if ( !bPassAdjustHitLocation && (IndexNext < 0) ) //Fail, try passing with current player state
		bPassAdjustHitLocation = LCS.static.AdjustHitLocationMod( Other, HitOffset, vector(ffView));
	if ( !bPassAdjustHitLocation )
	{
		HitOffset -= Other.Location;
		Error = "Ducking player inconsistency";
		return None; //Shot went through
	}
	HitOffset -= Other.Location;

	
	if ( VSize(PositionDiff) > (ffBox * 2 + VSize(RealVelocity) * 0.4) )	//Aim error is huge
	{
		if ( !ImageDropping(Other, PositionDiff * 0.5) ) //Target is image dropping, analyse after
		{
			Log("Fail on pass 1: "$VSize(PositionDiff)$" is the failed size", 'LagCompensator');
			return none;
		}
	}

	if ( VSize(RealVelocity) < 20 )
	{
		//Check if stationary Target is in position
		if ( (VSize(PositionDiff) < ffBox) || ImageDropping(Other,PositionDiff) ) //Single box
			return Other;
		Log("Fail on pass 3: "$ffBox$" is the ffBox size, "$ VSize(PositionDiff) $" is the point distance", 'LagCompensator');
	}
	else
	{
		//Check if moving target is near the movement line
		RealVelocity = Normal(RealVelocity); //We only need the direction now
		ffProj = RealPosition + RealVelocity * (RealVelocity dot (ClientPosition-RealPosition));
		if ( VSize(ffProj - ClientPosition) < ffBox * 1.2 + 10) //120% box (plus 10), simulation on low TR servers is horrible
			return Other;
		//Math problem
		if ( LCS.static.Badfloat( VSize(ffProj-ClientPosition)) )
			return Other;
	}
	
	Error = "Failed to pass";
	return none;
}

function float GetLatency()
{
	return float(ffLastPing) / 1000.0;
}

function ResetTimeStamp()
{
	ffDelaying = 0;
	ffDelayCount = 0;
	ffCTimeStamp = 0;
	ffCurRegTimer = 0;
	ffRefireTimer = 0;
	ImpreciseTimer = 0;
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

	if ( Mutator.ffCompList == self )
		Mutator.ffCompList = ffCompNext;
	else
	{
		For ( ffTmp=Mutator.ffCompList ; ffTmp!=none ; ffTmp=ffTmp.ffCompNext )
			if ( ffTmp.ffCompNext == self )
			{
				ffTmp.ffCompNext = ffCompNext;
				ffCompNext = none;
				SetOwner(none); //Graceful destruction
				break;
			}
	}
}

function bool ImageDropping( Pawn Other, vector HitDir)
{
	if ( (HitDir.Z < 40) || (Other.Velocity != vect(0,0,0)) || (Other.Physics != PHYS_Walking) )
		return false; //Minimum threshold
	return Normal(HitDir).Z > 0.75; //40º angle fall	
}



defaultproperties
{
    bGameRelevant=True
	RemoteRole=ROLE_None
	bCollideWhenPlacing=False
}
