//************************************************************
// By Higor
// This channel was made to prevent unwanted function calls
// Keeps the log cleaner
//************************************************************
class XC_CompensatorChannel expands Info;

var XC_LagCompensation LCActor;
var XC_LagCompensator LCComp;
var XC_ElementAdvancer LCAdv;
var PlayerPawn LocalPlayer;
var float ffRefireTimer; //This will enforce security checks
var float cAdv;
var float pwAdjust;
var float pwChain;
var float ProjAdv;
var Weapon CurWeapon, PendingWeapon;
var vector OldPosition;
var rotator OldView;
var float OldTimeStamp;
var int CurrentSWJumpPad;
var int ClientPredictCap;

var bool bUseLC;
var bool bSimAmmo;
//If LC is globally disabled, this actor won't exist
var bool bDelayedFire;
var bool bDelayedAltFire;
var bool bLogTick;
var bool bJustSwitched;
var bool bFakeSwitch;
var bool bAlreadyProcessed; //Queue following shots
var bool bSWChecked;
var bool bNoBinds;

var XC_ClientSettings ClientSettings;


// Shoot flags
// 1 - Use PlayerCalcView
// 2 - Use ZP origin and dir instead of real origin and dir
// 4 - Add range (+10k)
// 8 - Add range (+20k)
// Last 16 bytes = random seed for aim error


struct ShotData
{
	var private Actor ffOther;
	var private Weapon Weap;
	var private int CmpRot, ShootFlags;
	var private float ffTime;
	var private vector ffHit, ffOff, ffStartTrace;
	var private float ffAccuracy;
	var byte Imprecise;
	var bool bPlayerValidated;
	var bool bAccuracyValidated;
	var bool bRangeValidated;
	var bool bRegisteredFire;
	var float MaxTimeStamp;
	var string Error;
};
var private ShotData SavedShots[8];
var private int ffISaved;

replication
{
	reliable if ( bNetInitial && Role == ROLE_Authority ) //Useful when XC_GameEngine or UTPure is running
		bNoBinds;
	reliable if ( Role == ROLE_Authority )
		bUseLC, bSimAmmo, cAdv, ProjAdv, bSWChecked, ClientPredictCap;
	reliable if ( Role == ROLE_Authority )
		ForceLC, ClientChangeLC, SetPendingW, ReceiveSWJumpPad, LockSWJumpPads, ClientChangePCap;
	reliable if ( Role < ROLE_Authority )
		SetLC, ffSendHit, RequestSWJumpPads, RequestPCap;
}

//Saves hit info, processes after movement physics occurs, do simplest of checks
//This function never arrives earlier than corresponding ServerMove
//But another later ServerMove may arrive after this one
function ffSendHit( Actor ffOther, Weapon Weap, float ffTime, vector ffHit, vector ffOff, vector ffStartTrace, int CmpRot, int ShootFlags, optional float ffAccuracy)
{
	if ( ffISaved > 8 || !bUseLC 
		|| (Weap == none) || (CurWeapon != Weap) || Weap.IsInState('DownWeapon') )
		return;
	if ( !LCComp.ffClassifyShot(ffTime) ) //Time classification failure
		return;
		
	//HACKALICIOUS, FORCE WEAPON ANIMATION TO UPDATE FIRING SPEED IN NYA RIFLE
	if ( !Weap.IsAnimating() || (!Weap.bAnimLoop && Weap.AnimFrame >= AnimLast) )
		Weap.PlayFiring();
		
	SavedShots[ffISaved].ffOther = ffOther;
	SavedShots[ffISaved].Weap = Weap;
	SavedShots[ffISaved].ffTime = ffTime;
	SavedShots[ffISaved].ffHit = ffHit;
	SavedShots[ffISaved].ffOff = ffOff;
	SavedShots[ffISaved].ffStartTrace = ffStartTrace;
	SavedShots[ffISaved].CmpRot = CmpRot;
	SavedShots[ffISaved].ShootFlags = ShootFlags;
	SavedShots[ffISaved].ffAccuracy = ffAccuracy;
	SavedShots[ffISaved].bPlayerValidated = false;
	SavedShots[ffISaved].bAccuracyValidated = false;
	SavedShots[ffISaved].bRangeValidated = false;
	SavedShots[ffISaved].bRegisteredFire = false;
	SavedShots[ffISaved].Imprecise = byte(LCComp.ImpreciseTimer > 0);
	SavedShots[ffISaved].MaxTimeStamp = Level.TimeSeconds + Level.TimeDilation * 0.25;
	ffISaved++;
	
	if ( !bAlreadyProcessed )
	{
		ProcessHitList();
		bAlreadyProcessed = true;
	}
}

function ProcessHitList()
{
	local int i;
	local ShotData EmptyData;
	
	if ( PlayerPawn(Owner) == None )
		return;
	
	if ( Pawn(Owner).Weapon != None )
		Pawn(Owner).Weapon.KillCredit(self);

	while ( i < ffISaved )
	{
		if ( Level.TimeSeconds > SavedShots[i].MaxTimeStamp )
			Goto REMOVE_FROM_LIST;

		//Wait until player sends a good position update
		if ( SavedShots[i].ffTime <= PlayerPawn(Owner).CurrentTimeStamp )
		{
			if ( ProcessHit(SavedShots[i]) || (SavedShots[i].Imprecise >= 20) ) 
				Goto REMOVE_FROM_LIST;
		}
		i++;
	REMOVE_FROM_LIST:
		if ( SavedShots[i].Error != "" )
			RejectShot("Shot rejected: "@SavedShots[i].Error);
		if ( i != --ffISaved )
			SavedShots[i] = SavedShots[ffISaved];
		SavedShots[ffISaved] = EmptyData;
	}
	bAlreadyProcessed = false;
}


function bool ProcessHit( out ShotData Data)
{
	local XC_LagCompensator ffLC;
	local vector X, Y, Z, EndTrace;
	local float Range, CalcPing;
	local int ExtraFlags;

	Data.Error = "";
	
	//Validate weapon before processing (at all times)
	if ( !LCComp.ValidateWeapon( Data.Weap, Data.Imprecise) )
		return false;

	//Validate the player's view and shoot position, must be done only once
	if ( !Data.bPlayerValidated )
	{
		if ( !LCComp.ValidatePlayerView( Data.ffTime, Data.ffStartTrace, Data.CmpRot, Data.Imprecise, Data.Error) )
			return false;
		Data.bPlayerValidated = true;
	}
	//Validate weapon range
	if ( !Data.bRangeValidated )
	{
		if ( !LCComp.ValidateWeaponRange( Data.Weap, Data.ShootFlags, Data.ffStartTrace, Data.ffHit, Data.CmpRot, Data.Imprecise, Data.Error) )
			return false;
		Data.bRangeValidated = true;
	}
	//Validate the shoot dir and weapon optional aim accuracy
	if ( !Data.bAccuracyValidated )
	{
		if ( !LCComp.ValidateAccuracy( Data.Weap, Data.CmpRot, Data.ffStartTrace, Data.ffHit, Data.ffAccuracy, Data.ShootFlags, Data.Imprecise, Data.Error) )
			return false;
		Data.bAccuracyValidated = true;
	}


	if ( !Data.bRegisteredFire )
	{
		LCComp.ffCurRegTimer = float(Data.Weap.GetPropertyText("ffRefireTimer")); //Register this timer as current shoot timer
		if ( (LCComp.ImpreciseTimer <= 0) && (Data.Imprecise > 0) ) //Player skipped a security check
			LCComp.ImpreciseTimer = LCComp.ffCurRegTimer * 4;
		LCComp.ffRefireTimer += LCComp.ffCurRegTimer; //Register this new shot in the refire protection
		Data.bRegisteredFire = true;
	}

	//Actors with PlayerReplicationInfo 
	if  ( (Pawn(Data.ffOther) != None) && (Pawn(Data.ffOther).PlayerReplicationInfo != None) )
	{
		ffLC = LCActor.ffFindCompFor( Pawn(Data.ffOther));
		if ( ffLC != None )
			Data.ffOther = LCComp.ffCheckHit( ffLC, Data.ffHit, Data.ffOff, class'LCStatics'.static.DecompressRotator(Data.CmpRot) );
		else if ( Pawn(Data.ffOther).bIsPlayer ) //Players MUST have a compensator, monsters and others not
			Data.ffOther = None;
	}

	if ( Data.Imprecise >= 2 )
	{
		Data.Error = "IMPRECISE="$Data.Imprecise;
		return false;
	}
	
	CalcPing = float(LCComp.ffLastPing) / 1000.0;
	if ( (Data.ffOther == none) || !Class'LCStatics'.static.RelevantHitActor(Data.ffOther, PlayerPawn(Owner), CalcPing - ProjAdv) ) //Shot missed, get another target
	{
		//Override start position if we're finding a new target
		ExtraFlags = Data.ShootFlags;
		GetAxes( Pawn(Owner).ViewRotation, X, Y, Z);
		Data.ffStartTrace = class'LCStatics'.static.GetStartTrace( Data.Weap, ExtraFlags, X, Y, Z);
		Range = class'LCStatics'.static.GetRange( Data.Weap, ExtraFlags);
		EndTrace = Data.ffStartTrace + X * Range;
		if ( Data.ffAccuracy != 0 )
			EndTrace += class'LCStatics'.static.StaticAimError( Y, Z, Data.ffAccuracy, Data.ShootFlags >>> 16);
		Data.ffOther = Class'LCStatics'.static.ffIrrelevantShot( Data.ffHit, Data.ffOff, EndTrace, Data.ffStartTrace, PlayerPawn(Owner), CalcPing - ProjAdv );
		Data.Weap.ProcessTraceHit( Data.ffOther, Data.ffHit, Data.ffOff, X, Y, Z);
		return true;
	}
	Data.ffHit = Data.ffOther.Location + Data.ffOff;
	GetAxes( rotator(Data.ffHit - Data.ffStartTrace), X, Y, Z);
	Data.Weap.ProcessTraceHit( Data.ffOther, Data.ffHit, -X, X, Y, Z);
	return true;
}

function ClientFire( optional bool bAlt);

simulated event PostNetBeginPlay()
{
	if ( PlayerPawn(Owner) != none && ViewPort(PlayerPawn(Owner).Player) != none ) 
	{
		LocalPlayer = PlayerPawn(Owner);
		GotoState('ClientOp');
	}
	else
		GotoState('ClientNone');
}

simulated state ClientNone
{
Begin:
	Sleep(1.0);
	if ( PlayerPawn(Owner) != none && ViewPort(PlayerPawn(Owner).Player) != none ) 
	{
		LocalPlayer = PlayerPawn(Owner);
		GotoState('ClientOp');
	}
	else
		Goto('Begin');
}

simulated state ClientOp
{
	simulated event BeginState()
	{
		local Teleporter T;
		local ENetRole OldRole;
		local Object TmpOuter;

		//Fix ACE kick on preloaded swJumpPads
		ForEach AllActors (class'Teleporter', T)
			if ( T.IsA('swJumpPad') )
			{
				OldRole = T.Role;
				T.Role = ROLE_AutonomousProxy;
				T.SetPropertyText("bTraceGround","0");
				T.Role = OldRole;
			}
			
		if ( ClientSettings == None )
		{
			TmpOuter = new( self, 'LCWeapons') class'Object';
			ClientSettings = new( TmpOuter, 'Client') class'XC_ClientSettings';
		}
	}
	simulated function bool AboutToFinishFire( float DeltaTime)
	{
		local float TopFrame;
		if ( CurWeapon != None
			&& !CurWeapon.bRapidFire
			&& CurWeapon.IsAnimating() )
		{
			if ( CurWeapon.AnimLast == 0 ) 
				TopFrame = 1;
			else
				TopFrame = Abs(CurWeapon.AnimLast);
			//*2 because weapon hasn't ticked, and we need to advance TWO frames instead of ONE
			return (CurWeapon.AnimFrame < TopFrame) && (CurWeapon.AnimFrame + CurWeapon.AnimRate * DeltaTime * 2 >= TopFrame); 
		}
	}
	simulated function ClientFire( optional bool bAlt)
	{
		if ( !bAlt ) bDelayedFire = true;
		else         bDelayedAltFire = true;

		LocalPlayer.ClientUpdateTime = 5; //FORCE
	}
	simulated event Tick( float DeltaTime)
	{
		if ( LocalPlayer.Weapon != CurWeapon )
		{
			CurWeapon = LocalPlayer.Weapon;
			if ( CurWeapon != none )
			{
				CurWeapon.KillCredit( self);
				if ( CurWeapon.IsAnimating() )
				{
					if ( !bFakeSwitch )
						CurWeapon.AnimFrame = fMin( CurWeapon.AnimFrame + cAdv, 0.99);
					else if ( pwChain > 0 )
						CurWeapon.AnimFrame = fMin( CurWeapon.AnimFrame + pwChain, 0.99);
					pwChain = 0;
				}
			}
			bJustSwitched = (TournamentWeapon(CurWeapon) != none);
		}
		if ( bLogTick )
		{
			Log("Channel tick at "$Level.TimeSeconds);
			bLogTick = false;
		}
		if ( bDelayedFire && LCAdv == none ) //No advancer, fire here
		{
			CurWeapon.KillCredit( self);
			bDelayedFire = false;
		}
		if ( bDelayedAltFire && LCAdv == none ) //No advancer, alt-fire here
		{
			CurWeapon.KillCredit( self);
			bDelayedAltFire = false;
		}
		if ( AboutToFinishFire(DeltaTime) ) //FORCE UPDATE
		{
			LocalPlayer.ClientUpdateTime = 5; 
		}
		if ( bJustSwitched && TournamentWeapon(CurWeapon).bCanClientFire )
		{
			bJustSwitched = false;
			if ( LocalPlayer.bFire > 0 )
				CurWeapon.ClientFire(0);
			else if ( LocalPlayer.bAltFire > 0 )
				CurWeapon.ClientAltFire(0);
			else
				bJustSwitched = true;
		}
		if ( pwAdjust > 0 ) //Pending weapon mechanics
			ClientPendingAdjust( DeltaTime);
	}
Begin:
	Spawn(class'LCBindScanner').bNoBinds = bNoBinds;
	Sleep( 1); //Just in case
	if ( LocalPlayer.IsA('bbPlayer') )
		Sleep(2.5); //UTPure is about to fuck up my hud, let's wait a bit
	while ( LocalPlayer.myHUD == none )
		Sleep(0.2);
	LCAdv = Spawn(class'XC_ElementAdvancer').Setup( self);
	Spawn(class'XC_CProjSN').Setup( self, LCAdv);
	Spawn(class'XC_CPawnSN').Setup( self, LCAdv);
	Spawn(class'XC_CEffectsSN').Setup( self, LCAdv);
	if ( LocalPlayer.IsA('bbPlayer') )
		Spawn(class'LCWeaponHUD').LocalPlayer = LocalPlayer;
FindClient:
	RequestPCap( ClientSettings.ForcePredictionCap);
	Sleep(0.3); //Safer
	CheckSWJumpPads();
AdjustClient:
	if ( ClientSettings.bUseLagCompensation != bUseLC ) //This will work on high packet loss environments
		SetLC( ClientSettings.bUseLagCompensation);
	if ( ClientPredictCap != ClientSettings.ForcePredictionCap)
	{
		if ( FRand() < 0.1 ) //If server fails to replicate this, reset to 0 and restart again to cleanup replication with Packet loss
			RequestPCap( 0);
		else
			RequestPCap( ClientSettings.ForcePredictionCap);
	}
	Sleep(0.5);
	Goto('AdjustClient');
}

function AddPlayer( PlayerPawn Other, XC_LagCompensation Master)
{
	if ( (Other != none) && (NetConnection(Other.Player) != none) && (Master != none) )
	{
		SetOwner( Other);
		LCActor = Master;
		LCComp = LCActor.ffFindCompFor( Other);
		GotoState('ServerOp');
	}
	else
		Destroy();
}

state ServerOp
{
	event Tick( float DeltaTime)
	{
		local int i;
		
		ProcessHitList();
		if ( LCActor.bWeaponAnim )
			cAdv = (float(LCComp.ffLastPing) / 1000) * Level.TimeDilation;

		if ( !LCActor.bUsePrediction || (ClientPredictCap == 0) )
			ProjAdv = 0;
		else if ( ClientPredictCap > 0 )
			ProjAdv = (fMin(LCComp.ffLastPing, float(ClientPredictCap) / Level.TimeDilation) / 1000.f) * Level.TimeDilation;
		else
			ProjAdv = (fMin(LCComp.ffLastPing, LCActor.MaxPredictNonLC / Level.TimeDilation) / 1000.f) * Level.TimeDilation;

		if ( PlayerPawn(Owner) != none )
		{
			OldPosition = Owner.Location;
			OldView = PlayerPawn(Owner).ViewRotation;
			OldTimeStamp = PlayerPawn(Owner).CurrentTimeStamp;
		}
	}
Begin:
	While ( Owner != none && !Owner.bDeleteMe )
	{
		if ( Pawn(Owner).Weapon != CurWeapon )
		{
			if ( CurWeapon != none )
				CurWeapon.SetPropertyText("LCChan","None");
			CurWeapon = Pawn(Owner).Weapon;
			if ( CurWeapon != none )
				CurWeapon.KillCredit( self);
		}
		if ( LCActor.bPendingWeapon )
		{
			if ( (Pawn(Owner).PendingWeapon != none) && (PendingWeapon == none || PendingWeapon != Pawn(Owner).PendingWeapon) )
			{
				PendingWeapon = Pawn(Owner).PendingWeapon;
				SetPendingW( PendingWeapon);
			}
		}
		Sleep(0.0);
		
		if ( bSWChecked && (LCActor.swPads[CurrentSWJumpPad] != none) && (FRand() < 0.2) )
		{
			ReceiveSWJumpPad( LCActor.swPads[CurrentSWJumpPad].class, LCActor.swPads[CurrentSWJumpPad].URL, LCActor.swPads[CurrentSWJumpPad].Tag,
					float(LCActor.swPads[CurrentSWJumpPad].GetPropertyText("JumpAngle")), byte(LCActor.swPads[CurrentSWJumpPad].GetPropertyText("TeamNumber")),
					LCActor.swPads[CurrentSWJumpPad].Location, LCActor.swPads[CurrentSWJumpPad].CollisionRadius, LCActor.swPads[CurrentSWJumpPad].CollisionHeight);
			CurrentSWJumpPad++;
			if ( LCActor.swPads[CurrentSWJumpPad] == none )
				LockSWJumpPads( LCActor.swPads[0].class );
		}
	}
	Destroy();
}

event SetInitialState()
{
	bScriptInitialized = true;
}

event Destroyed()
{
	if ( (CurWeapon != none) && !CurWeapon.bDeleteMe )
		CurWeapon.SetPropertyText("LCChan","None");
}


/****************** LC State control
 *
 * SetLC          - Client internally forces LC state (loading config)
 * ForceLC        - Server wants to override LC state on client (useful if client is wrong)
 * ClientChangeLC - Client wants to change config using a Mutate command (causes SetLC after a while)
*/
function SetLC( bool bEnable)
{
	if ( bUseLC == bEnable )
		ForceLC( bEnable);
	bUseLC = bEnable;
}
simulated function ForceLC( bool bEnable)
{
	bUseLC = bEnable;
}
simulated function ClientChangeLC( bool bEnable)
{
	if ( ClientSettings != None )
	{
		ClientSettings.bUseLagCompensation = bEnable;
		ClientSettings.SaveConfig();
	}
}

/****************** Prediction cap control
 *
 * ChangePCap       - Client sent a mutate command to server to change pCap.
 * ClientChangePCap - Server informs client of requested pCap change.
 * RequestPCap      - Server wants to know client's pCap
*/
function ChangePCap( int NewPCap)
{
	ClientPredictCap = NewPCap;
	ClientChangePCap( NewPCap);
}
function RequestPCap( int NewPCap)
{
	ClientPredictCap = NewPCap;
}
simulated function ClientChangePCap( int NewPCap)
{
	ClientPredictCap = NewPCap;
	if ( ClientSettings != None )
	{
		ClientSettings.ForcePredictionCap = NewPCap;
		ClientSettings.SaveConfig();
	}
}




simulated function SetPendingW( weapon Other)
{
	if ( Other == none || Other.bDeleteMe || CurWeapon == Other || CurWeapon == none )
		return;
	LocalPlayer.PendingWeapon = Other;
	PendingWeapon = Other;
	pwAdjust = 2 + cAdv;
	if ( CurWeapon.IsInState('ClientDown') )
	{
		if ( CurWeapon.AnimFrame + cAdv >= 1 )
		{
			pwChain = CurWeapon.AnimFrame + cAdv - 1;
			CurWeapon.AnimFrame = 0.99;
		}
		else
			CurWeapon.AnimFrame = fMin( CurWeapon.AnimFrame + cAdv, 0.99);
		bFakeSwitch = true;
	}
}

simulated function ClientPendingAdjust( float DeltaTime)
{
	if ( PendingWeapon == LocalPlayer.Weapon )
		LocalPlayer.PendingWeapon = none;
	if ( (pwAdjust -= DeltaTime) <= 0 ) //Reset
	{
		bFakeSwitch = false;
		pwAdjust = 0;
		PendingWeapon = none;
		LocalPlayer.PendingWeapon = none;
	}
}

simulated function CheckSWJumpPads()
{
	local Teleporter T;

	if ( bSWChecked )
		return;

	ForEach AllActors (class'Teleporter', T)
	{
		if ( T.IsA('swJumpPad') && T.bNoDelete ) //HACK ALREADY APPLIED, ADD MARKERS INSTEAD
		{
			bSWChecked = true;
		}
	}

	if ( !bSWChecked )
		RequestSWJumpPads();
}

function RequestSWJumpPads()
{
	if ( bSWChecked )
		return;
	bSWChecked = true;
}

simulated function ReceiveSWJumpPad( class<Teleporter> PadClass, string NewURL, name NewTag, float NewAngle, byte NewTeam, vector NewLoc, float CRadius, float CHeight)
{
	local Teleporter T;
	if ( PadClass == none )
		return;
	T = Spawn( PadClass, none, NewTag, NewLoc);
	T.URL = NewURL;
	T.Role = ROLE_Authority;
	T.SetCollisionSize( CRadius, CHeight);
	T.SetPropertyText("JumpAngle", string(NewAngle) );
	T.SetPropertyText("JumpSound", "none");
//	if ( NewTeam != 255 )
//	{
//		T.SetPropertyText("JumpAngle", string(NewTeam) );
//		T.SetPropertyText("bTeamOnly", "1" );
//	}
	if ( NewURL != "" )
		Spawn(class'LC_SWJump', LocalPlayer, 'LC_SWJump', NewLoc).Setup( T, LocalPlayer);
}

//Allow clients to load these with the maps for next map switch
simulated function LockSWJumpPads( class<Teleporter> PadClass)
{
	if ( PadClass != none )
	{
		LocalPlayer.GetEntryLevel().ConsoleCommand("set "$PadClass$" bNoDelete 1");
//		PadClass.default.bNoDelete = true;
	}
}

function RejectShot( coerce string Reason)
{
	Log( "LC Shot rejected: "$Reason,'LagCompensator');
	if ( PlayerPawn(Owner) != none )
		PlayerPawn(Owner).ClientMessage( Reason);
}

defaultproperties
{
    bGameRelevant=True
    bHidden=True
    NetPriority=1.1
    NetUpdateFrequency=20
    RemoteRole=ROLE_SimulatedProxy
    bUseLC=True
	ClientPredictCap=-1
}