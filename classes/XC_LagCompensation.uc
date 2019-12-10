//=============================================================================
// XC_LagCompensation.
// 128 player markers, 32 generic ones
// Made by Higor
//=============================================================================
class XC_LagCompensation expands Mutator
	config(LCWeapons);

const LCS = class'LCStatics';

var XC_LagCompensator ffCompList;
var XC_GenericPosList ActiveGen, InactiveGen;
var int iCombo; //Combo tracker count
var float ffMaxLatency;
var string Pkg;
var int ffCurId;
var float LastTimeSeconds;

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

event Tick( float DeltaTime)
{
	local float TimeOffset;
	local XC_PosList PosList;
	local XC_LagCompensator LCComp;

	bNeedsHiddenEffects = (LCS.default.XCGE_Version < 17) || (XCGE == none) || !bool(XCGE.GetPropertyText("bUseNewRelevancy"));
	GlobalPos = (GlobalPos + 1) & 0x7F; //Every tick
	bUpdateGeneric = ((GlobalPos % 4) == 0);
	if ( bUpdateGeneric )
		GenericPos = (GenericPos + 1) & 0x1F; //Every 4 ticks
	
	if ( Level.TimeSeconds - LastTimeSeconds > 0.25 * Level.TimeDilation ) //Frame took over 0.25 second!!! (game was paused/server frame drop)
	{
		TimeOffset = (Level.TimeSeconds - LastTimeSeconds) - DeltaTime;
		ForEach AllActors( class'XC_PosList', PosList) //Corrects generic ones as well
			PosList.CorrectTimeStamp( TimeOffset );
		For ( LCComp=ffCompList ; LCComp!=None ; LCComp=LCComp.ffCompNext )
			LCComp.ResetTimeStamp();
	}
	LastTimeSeconds = Level.TimeSeconds;
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

function bool ffInsertNewPlayer( Pawn NewPlayer)
{
	local private XC_LagCompensator ffTmp;
	
	if ( NewPlayer == none )
		return false;
	ffTmp = Spawn( class'XC_LagCompensator', NewPlayer);
	ffTmp.ffOwner = NewPlayer;
	ffTmp.ffCompNext = ffCompList;
	ffCompList = ffTmp;
	ffTmp.ffMaster = self;
	ffTmp.PosList = Spawn(class'XC_PlayerPosList', NewPlayer);
	ffTmp.PosList.Mutator = self;
	ffTmp.PosList.ffOwner = ffTmp;
	ffTmp.PosList.SetOwner(NewPlayer);

	//Register individual ZP controller channel on this playerpawn
	if ( (PlayerPawn(NewPlayer) != none) && (NetConnection(PlayerPawn(NewPlayer).Player) != none) )
	{
		ffTmp.CompChannel = Spawn(class'XC_CompensatorChannel');
		ffTmp.CompChannel.bNoBinds = bNoBinds;
		ffTmp.CompChannel.bSimAmmo = bSimulateAmmo;
		ffTmp.CompChannel.AddPlayer( PlayerPawn(NewPlayer), self);
	}
}

final function XC_LagCompensator ffFindCompFor( private pawn ffOther)
{
	local private XC_LagCompensator ffTmp;
	
	For ( ffTmp=ffCompList ; ffTmp!=none ; ffTmp=ffTmp.ffCompNext )
		if ( ffTmp.ffOwner == ffOther )
			return ffTmp;
	return none;
}

final function XC_LagCompensator ffFindCompForId( private int Id)
{
	local private XC_LagCompensator ffTmp;
	
	For ( ffTmp=ffCompList ; ffTmp!=none ; ffTmp=ffTmp.ffCompNext )
		if ( ffTmp.ffOwner.PlayerReplicationInfo.PlayerId == Id )
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
		Slot = ActiveGen.FindTopSlot( ffPing);
		ffDelta = ActiveGen.AlphaSlots( Slot, ffPing);
		For ( GenPos=ActiveGen; GenPos!=none ; GenPos=GenPos.NextG )
		{
			if ( GenPos.HasTeleported(Slot))	ffPos = GenPos.GetLoc( Slot);
			else								ffPos = GenPos.AlphaLoc( Slot, ffDelta);

			if ( !GenPos.CanHit( ShootStart, ffPos, X, Y, Z) )
				continue;
			if ( GenPos.bPingHandicap )
				GenPos.SetCollisionSize( GenPos.Owner.CollisionRadius + ffPing * 2, GenPos.Owner.CollisionHeight + ffPing * 2);
			else
				GenPos.SetCollisionSize( GenPos.Owner.CollisionRadius, GenPos.Owner.CollisionHeight);
			GenPos.SetLocation( ffPos);
			GenPos.SetCollision( true, false, false);
			GenPos.bProjTarget = true;
		}
	}
	
	return true;
}

//TODO: USE DYNAMIC ACTORS WITH TAG (PLUS REMOVE TAG AFTER DONE)
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


function vector WeaponStartTrace( Weapon W)
{
	local vector X,Y,Z;
	GetAxes( Pawn(W.Owner).ViewRotation, X, Y, Z);
	return W.Owner.Location + W.CalcDrawOffset() + W.FireOffset.Y * Y + W.FireOffset.Z * Z; 
}

function ScoreKill( Pawn Killer, Pawn Other)
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

function bool IsRelevant( Actor Other, out byte bSuperRelevant)
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

function XC_GenericPosList AddGenericPos( Actor Other)
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
		Tmp.Mutator = self;
	}
	Tmp.NextG = ActiveGen;
	if ( ActiveGen != none )
		ActiveGen.PrevG = Tmp;
	ActiveGen = Tmp;
	Tmp.SetOwner(Other);
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
	bWeaponAnim=True
	bSimulateAmmo=True
	bUsePrediction=True
	bEnableMHhack=True
}
