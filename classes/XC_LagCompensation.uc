//=============================================================================
// XC_LagCompensation.
// 128 player markers, 32 generic ones
// Made by Higor
//=============================================================================
class XC_LagCompensation expands Mutator
	config(LCWeapons);

const LCS = class'LCStatics';

var XC_LagCompensator ffCompList;
var XC_GenericPosList ActiveGen, InactiveGen, DummyGen;
var int iCombo; //Combo tracker count
var float ffMaxLatency;
var string Pkg;
var int ffCurId;

var GameEngine XCGE;

var byte GlobalPos;
var byte GenericPos;
var bool bUpdateGeneric;
var bool bNoBinds;
var bool bNeedsHiddenEffects;

var(Debug) float PingMult, PingAdd;
var Pawn LinkedPawn;

var() config bool bKickers; //Requires restart
var() config bool bSWJumpPads;
var() config bool bPendingWeapon;
var() config bool bWeaponAnim;
var() config bool bSimulateAmmo;
var() config bool bUsePrediction;
var() config bool bEnableMHhack;
var() config bool bTIWFire;
var() config float MaxPredictNonLC;

var Teleporter swPads[63];

//XC_GameEngine interface
native(1718) final function bool AddToPackageMap( optional string PkgName);

event PreBeginPlay()
{
	local ScriptedPawn Monster;
	local Kicker K;
	local Teleporter T; 
	local int i;

	if ( LCS.static.DetectXCGE( self) )
		SetPropertyText("XCGE", XLevel.GetPropertyText("Engine"));
	DummyGen = Spawn(class'XC_GenericPosList');
	DummyGen.Master = self;
	DummyGen.GotoState('Dummy');
	Spawn(class'LCProjSN').Mutator = self;
	bNoBinds = LCS.default.bXCGE; //This Game Engine is about to correct GetWeapon!!!
	if ( LCS.default.XCGE_Version >= 11 )
		AddToPackageMap();
	if ( Level.Game.IsA('Monsterhunt') && bEnableMHhack )
	{
		Spawn(class'LCMonsterSN').Mutator = self;
		ForEach AllActors (class'ScriptedPawn', Monster)
			AddGenericPos( Monster);
	}

	if ( bKickers )
		ForEach AllActors (class'Kicker', K)
		{
			if ( K.GetPropertyText("NoLC") != "" )
				continue;
			if ( (K.KickedClasses == 'Actor') || (K.KickedClasses == 'Pawn') || (K.KickedClasses == 'PlayerPawn') || (K.KickedClasses == 'Projectile') )
				Spawn(class'LCKicker').ServerSetup( K);
		}
	if ( bSWJumpPads )
		ForEach AllActors (class'Teleporter', T)
		{
			if ( T.IsA('swJumpPad') )
			{
				swPads[i++] = T;
				if ( i >= (ArrayCount(swPads)-1) ) //Last slot always free for speed reasons and code simplicity
					break;
			}
		}
}


//Mimicking ZP because ppl gets used to stuff
function Mutate (string MutateString, PlayerPawn Sender)
{
	local int PPredict;
	local XC_LagCompensator LCComp;
	local string Param;
	
	if ( Sender != none )
	{
		if ( MutateString ~= "GetPrediction")
		{
			PPredict = -1;
			Sender.ClientMessage("The server is using a"@int(MaxPredictNonLC)@"MS prediction cap");
			LCComp = ffFindCompFor(Sender);
			if ( LCComp != none && LCComp.CompChannel != none )
				PPredict = LCComp.CompChannel.ClientPredictCap;
			if ( PPredict == 0 )
				Sender.ClientMessage( "Your client is overriding prediction: 0 = DISABLED");
			else if ( PPredict > 0 )
				Sender.ClientMessage( "Your client is overriding prediction cap: "$PPredict$" MS");
		}
		else if ( Left(MutateString, 11) ~= "Prediction " )
		{
			LCComp = ffFindCompFor(Sender);
			Param = Mid( MutateString, 11);
			if ( LCComp != none && LCComp.CompChannel != none )
			{
				if ( Param ~= "default" )
					LCComp.CompChannel.ChangePCap( -1);
				else if ( Param ~= "disable" )
					LCComp.CompChannel.ChangePCap( 0);
				else
					LCComp.CompChannel.ChangePCap( int(Param) );
				Sender.ClientMessage( "New Prediction cap value: "$LCComp.CompChannel.ClientPredictCap );
			}	
		}
		else if ( Left(MutateString, 10) ~= "Prediction" )
		{
			Sender.ClientMessage( "Use MUTATE PREDICTION VALUE to control the prediction cap");
			Sender.ClientMessage( "> Add a numeric value (in ms), 0 disables prediction");
			Sender.ClientMessage( "> Add DEFAULT value to let server control prediction cap");
		}
	}
	Super.Mutate(MutateString,Sender);
}

event Tick( private float ffDelta)
{
	bNeedsHiddenEffects = (LCS.default.XCGE_Version < 17) || (XCGE == none) || !bool(XCGE.GetPropertyText("bUseNewRelevancy"));
	GlobalPos = (GlobalPos + 1) % 128; //Every tick
	bUpdateGeneric = ((GlobalPos % 4) == 0);
	if ( bUpdateGeneric )
		GenericPos = (GenericPos + 1) % 32; //Every 4 ticks
}


function ffCollidePlayers( private bool ffEnable)
{
	local private XC_LagCompensator ffTmp;
	
	if ( !ffEnable )
	{	For ( ffTmp=ffCompList ; ffTmp!=none ; ffTmp=ffTmp.ffCompNext )
		{
			ffTmp.ffGetCollision();
			ffTmp.ffNoCollision();
		}
	}
	else
		For ( ffTmp=ffCompList ; ffTmp!=none ; ffTmp=ffTmp.ffCompNext )
			ffTmp.ffSetCollision();
}

function bool ffInsertNewPlayer( private pawn ffOther)
{
	local private XC_LagCompensator ffTmp;
	
	if ( ffOther == none )
		return false;
	ffTmp = Spawn( class'XC_LagCompensator', ffOther);
	ffTmp.ffOwner = ffOther;
	ffTmp.ffCompNext = ffCompList;
	ffCompList = ffTmp;
	ffTmp.ffMaster = self;
	ffTmp.PosList = Spawn(class'XC_PlayerPosList', ffOther);
	ffTmp.PosList.Master = self;
	ffTmp.PosList.ffOwner = ffTmp;

	//Register individual ZP controller channel on this playerpawn
	if ( (PlayerPawn(ffOther) != none) && (NetConnection(PlayerPawn(ffOther).Player) != none) )
	{
		ffTmp.CompChannel = Spawn(class'XC_CompensatorChannel');
		ffTmp.CompChannel.bNoBinds = bNoBinds;
		ffTmp.CompChannel.bSimAmmo = bSimulateAmmo;
		ffTmp.CompChannel.AddPlayer( PlayerPawn(ffOther), self);
	}
}

function XC_LagCompensator ffFindCompFor( private pawn ffOther)
{
	local private XC_LagCompensator ffTmp;
	
	For ( ffTmp=ffCompList ; ffTmp!=none ; ffTmp=ffTmp.ffCompNext )
		if ( ffTmp.ffOwner == ffOther )
			return ffTmp;
	return none;
}

function XC_LagCompensator ffGetLC( private pawn ffOther)
{
	local private XC_LagCompensator ffTmp;

	For ( ffTmp=ffCompList ; ffTmp!=none ; ffTmp=ffTmp.ffCompNext )
		if ( ffTmp.ffOwner == ffOther )
			return ffTmp;
	return none;
}

function bool ffUnlagPositions( private XC_LagCompensator ffOther, vector ShootStart, rotator ShootDir)
{
	local private float ffPing, ffPawnPing, ffDelta;
	local XC_PlayerPosList PosList;
	local XC_GenericPosList GenPos;
	local private vector ffPos;
	local private XC_LagCompensator nani2;
	local byte Slot;
	local vector X,Y,Z;
	local float ShootTimeStamp;

	if ( ffOther == none )
		return false;

	ffPing = float(ffOther.ffLastPing) / 1000.0;
	ffPing = ffPing * PingMult + PingAdd; //Debug
	ShootTimeStamp = Level.TimeSeconds - ffPing * Level.TimeDilation;
	ffPawnPing = ffPing; //Special ping for pawns, does not get reduced by element advancer
	if ( ffOther.CompChannel != none )
		ffPing -= ffOther.CompChannel.ProjAdv; //Projectiles are indeed seen ahead on clients
	nani2 = ffCompList;
	while ( nani2 != none ) //This iterator shouldn't exist anymore
	{
		PosList = nani2.PosList;
		if ( PosList != none )
		{
			Slot = PosList.FindTopSlot( ffPawnPing);
			ffDelta = PosList.AlphaSlots( Slot, ffPawnPing);
			break;
		}
		nani2 = nani2.ffCompNext;
	}
	GetAxes( ShootDir,X,Y,Z);
	while ( nani2 != none )
	{
		if ( (nani2 == ffOther) || nani2.ffNoHit )
			Goto NEXT_LOOP;

		PosList = nani2.PosList;
		if ( !PosList.IsHittable( Slot, ShootTimeStamp) )
			Goto NEXT_LOOP;
		if ( PosList.HasTeleported(Slot))	ffPos = PosList.GetLoc( Slot);
		else								ffPos = PosList.AlphaLoc( Slot, ffDelta);

		if ( !PosList.CanHit( ShootStart, ffPos, X, Y, Z) )
			Goto NEXT_LOOP;

		if ( PosList.HasDucked(Slot))
		{
			ffPos.Z -= PosList.ffOwner.CollisionHeight * 0.4;
			nani2.SetCollisionSize( nani2.ffOwner.CollisionRadius, nani2.ffOwner.CollisionHeight * 0.6);
		}
		else if ( nani2.CollisionHeight != nani2.ffOwner.CollisionHeight )
			nani2.SetCollisionSize( nani2.ffOwner.CollisionRadius, nani2.ffOwner.CollisionHeight);
		nani2.SetLocation( ffPos);
		nani2.SetCollision( true, false, false);
		nani2.bProjTarget = true;

		NEXT_LOOP:
		nani2 = nani2.ffCompNext;
	}
	
	//GENERIC LOOPER NOW!
	if ( ActiveGen != none )
	{
		Slot = DummyGen.FindTopSlot( ffPing);
		ffDelta = DummyGen.AlphaSlots( Slot, ffPing);
		For ( GenPos=ActiveGen; GenPos!=none ; GenPos=GenPos.NextG )
		{
			if ( GenPos.HasTeleported(Slot))	ffPos = GenPos.GetLoc( Slot);
			else								ffPos = GenPos.AlphaLoc( Slot, ffDelta);

			if ( !GenPos.CanHit( ShootStart, ffPos, X, Y, Z) )
				continue;
			if ( GenPos.bPingHandicap )
				GenPos.SetCollisionSize( GenPos.Compensated.CollisionRadius + ffPing * 2, GenPos.Compensated.CollisionHeight + ffPing * 2);
			else
				GenPos.SetCollisionSize( GenPos.Compensated.CollisionRadius, GenPos.Compensated.CollisionHeight);
			GenPos.SetLocation( ffPos);
			GenPos.SetCollision( true, false, false);
			GenPos.bProjTarget = true;
		}
	}
	
	return true;
}

function ffRevertPositions()
{
	local private XC_LagCompensator ffTmp;
	local XC_GenericPosList GenPos;

	For ( ffTmp = ffCompList ; ffTmp!=none ; ffTmp=ffTmp.ffCompNext )
		if ( ffTmp.bProjTarget )
		{
			ffTmp.bProjTarget = false;
			ffTmp.SetCollision(false,false,false);
		}
	For ( GenPos = ActiveGen ; GenPos!=none ; GenPos=GenPos.NextG )
		if ( GenPos.bProjTarget )
		{
			GenPos.bProjTarget = false;
			GenPos.SetCollision(false,false,false);
		}
}


function bool ffUnlagSPosition( private XC_LagCompensator ffOther, float ffPing)
{
	local private float ffDelta;
	local XC_PlayerPosList PosList;
	local private vector ffPos;
	local private XC_LagCompensator nani2;
	local byte Slot;

	if ( ffOther == none )
		return false;

	PosList = ffOther.PosList;
	Slot = PosList.FindTopSlot( ffPing);
	ffDelta = PosList.AlphaSlots( Slot, ffPing);
	if ( PosList.HasTeleported(Slot))	ffPos = PosList.GetLoc( Slot);
	else								ffPos = PosList.AlphaLoc( Slot, ffDelta);
	if ( PosList.HasDucked(Slot))
	{
		ffPos.Z -= ffOther.ffOwner.CollisionHeight * 0.4;
		ffOther.SetCollisionSize( ffOther.ffOwner.CollisionRadius, ffOther.ffOwner.CollisionHeight * 0.6);
	}
	else if ( ffOther.CollisionHeight != ffOther.ffOwner.CollisionHeight )
		ffOther.SetCollisionSize( ffOther.ffOwner.CollisionRadius, ffOther.ffOwner.CollisionHeight);
	ffOther.SetLocation( ffPos);
	ffOther.bHidden = false;
	return true;
}

function float ffMaxLag()
{
	return ffMaxLatency * 0.001 * Level.TimeDilation; //Scale up if game is faster, we'll be operating using just ffDelta on other calculation phases
}
//OBFEND

//Fast validation checks
function bool FastValidate( XC_CompensatorChannel LCChan, Actor Other, int HashID, Weapon aWeap, int CmpRot, vector PLoc, vector Start, vector End, out byte Imprecise, float Accuracy, int Flags)
{
	local vector aVec;
	local pawn P;
	local rotator FixedRot;
	local float fDist;

	P = Pawn(LCChan.Owner);
	if ( P.Health < 0 )
		return false;
	if ( Accuracy != 0 )
	{
		if ( string(Accuracy) != aWeap.GetPropertyText("ffAimError") ) //Weapon aim error mismatch
		{
			LCChan.RejectShot("Aim error mismatch:"@Accuracy@"vs"@aWeap.GetPropertyText("ffAimError"));
			return false;
		}
	}
	if ( Accuracy > 0 )
	{
		fDist = 10000;
		if ( (Flags & 4) > 0 )			fDist += 10000;
		if ( (Flags & 8) > 0 )			fDist += 20000;
		aVec = ValidateEnd( Accuracy, fDist ,Flags >>> 16, class'LCStatics'.static.DecompressRotator(CmpRot));
	}
	else
		aVec = Vector(class'LCStatics'.static.DecompressRotator(CmpRot));
	if ( (VSize(End-Start) > 30) && (VSize( aVec - Normal(End-Start)) > 0.05) )
	{
		if ( (Imprecise > 0) || (VSize( aVec - Normal(End-Start)) > 0.20) )
		{
			LCChan.RejectShot( "DIRECTION DIFF IS :"$ VSize( aVec - Normal(End-Start)));
			return false;
		}
		else Imprecise++;	
	}
	if ( Accuracy > 0 )
		aVec = Vector(class'LCStatics'.static.DecompressRotator(CmpRot));
	if ( (VSize( aVec - Vector(P.ViewRotation)) > 0.07) && (VSize( aVec - Vector(LCChan.OldView)) > 0.07) )
	{
		FixedRot = rotator(vector(P.ViewRotation) + vector(LCChan.OldView));
		if ( VSize( aVec - Vector(FixedRot)) < 0.07 )
		{}
		else if ( (Imprecise > 0) || (VSize( aVec - Vector(FixedRot)) > 0.22) )
		{
			LCChan.RejectShot( "VROTATION DIFFERENCE IS: "$ VSize( aVec - Vector(P.ViewRotation)));
			return false;
		}
		else Imprecise++;
	}
	aVec.X = VSize(P.Location - P.OldLocation); //Tick loc difference, helps low Rate servers
	if ( P.Base != none )
		aVec.X += VSize(P.Base.Velocity) * 0.10;
	if ( P.Physics == PHYS_Walking )
		aVec.X += 20 + VSize(P.Velocity) * 0.05;
	if ( VSize(WeaponStartTrace(aWeap) - Start) > (50 + aVec.X + VSize(P.Velocity) * 0.20) )
	{
		if ( (Imprecise > 0) || (VSize(WeaponStartTrace(aWeap) - Start) > (75 + aVec.X * 1.1 + VSize(P.Velocity) * 0.32)) )
		{
			LCChan.RejectShot( "START DIFF = "$int(VSize(WeaponStartTrace(aWeap) - Start)) );
			return false;
		}
		else Imprecise++;
	}
	if ( VSize( PLoc - P.Location) > (45 + aVec.X + VSize(P.Velocity) * 0.15) )
	{
		if ( (Imprecise > 0) || (VSize( PLoc - P.Location) > (60 + aVec.X * 1.1 + VSize(P.Velocity) * 0.28)) )
		{
			LCChan.RejectShot( "LOCATION DIFF = "$int(VSize( PLoc - P.Location)) );
			return false;
		}
		else Imprecise++;
	}
	return true;
}

function vector ValidateEnd( float Accuracy, float MaxDist, int Seed, rotator Dir)
{
	local vector X,Y,Z;

	GetAxes( Dir, X,Y,Z);
	return Normal(X * MaxDist + class'LCStatics'.static.StaticAimError( Y, Z, Accuracy, Seed));
}


function vector WeaponStartTrace( Weapon W)
{
	local vector X,Y,Z;
	GetAxes( Pawn(W.Owner).ViewRotation, X, Y, Z);
	return W.Owner.Location + W.CalcDrawOffset() + W.FireOffset.Y * Y + W.FireOffset.Z * Z; 
}

function ScoreKill(Pawn Killer, Pawn Other)
{
	local XC_LagCompensator LCComp;
	
	if ( Other.PlayerReplicationInfo != None )
	{
		LCComp = ffFindCompFor( Other);
		if ( LCComp != None && LCComp.PosList != None )
			LCComp.PosList.LastDeathTimeStamp = Level.TimeSeconds;
	}
	
	if ( NextMutator != None )
		NextMutator.ScoreKill(Killer, Other);
}

function bool IsRelevant(Actor Other, out byte bSuperRelevant)
{
	local bool bResult;

	//bIsPawn is done for speed reasons
	if ( Other.bIsPawn && Other.IsA('ScriptedPawn') )
	{
		AddGenericPos( Other);
		return true;
	}

	// allow mutators to remove actors
	if ( bResult && (NextMutator != None) )
		bResult = NextMutator.IsRelevant(Other, bSuperRelevant);

	return bResult;
}

function bool HandleEndGame()
{
	SaveConfig();
	if ( NextMutator != None )
		return NextMutator.HandleEndGame();
	return false;
}

function XC_GenericPosList AddGenericPos( actor Other)
{
	local XC_GenericPosList Tmp;

	if ( InactiveGen != none )
	{
		Tmp = InactiveGen;
		InactiveGen = Tmp.NextG;
	}
	else
	{
		Tmp = Spawn(class'XC_GenericPosList');
		Tmp.Master = self;
	}
	Tmp.NextG = ActiveGen;
	if ( ActiveGen != none )
		ActiveGen.PrevG = Tmp;
	ActiveGen = Tmp;
	Tmp.Compensated = Other;
	Tmp.GotoState('Active','Begin');
	return Tmp;
}

defaultproperties
{
	bGameRelevant=True
	ffMaxLatency=650
	MaxPredictNonLC=150
	RemoteRole=ROLE_None
	PingMult=1
	bKickers=True
	bSWJumpPads=True
	bPendingWeapon=True
	bWeaponAnim=True
	bSimulateAmmo=True
	bUsePrediction=True
	bEnableMHhack=True
}
