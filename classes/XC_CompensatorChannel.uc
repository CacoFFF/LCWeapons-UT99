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
var float pwChain;
var float ProjAdv;

var float CounterHiFi;

var Weapon CurWeapon, CurPendingWeapon;
var float PendingWeaponAnimAdjust;
var float PendingWeaponCountdown;
var float OldFireOffsetY;
var vector OldPosition;
var rotator OldView;
var float OldTimeStamp;
var int CurrentSWJumpPad;
var int ClientPredictCap;

var bool bClientPendingWeapon;
var bool bUseLC; //Mirror: bCarriedItem
var bool bSimAmmo;
//If LC is globally disabled, this actor won't exist
var bool bDelayedFire;
var bool bDelayedAltFire;
var bool bLogTick;
var bool bJustSwitched;
var bool bHitProcDone; //One proc per Tick
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
	var private vector ffHit, ffOff, StartTrace;
	var private float ffAccuracy;
	var byte Imprecise;
	var bool bPlayerValidated;
	var bool bAccuracyValidated;
	var bool bRangeValidated;
	var bool bBoxValidated;
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
		ForceLC, ClientSetPendingWeapon, ClientSetFireOffsetY, ReceiveSWJumpPad, LockSWJumpPads, 
		ClientChangeLC, ClientChangePCap, ClientChangeHiFi;
	reliable if ( Role < ROLE_Authority )
		SetLC, ffSendHit, RequestSWJumpPads, RequestPCap;
}

static final operator(22) Actor | ( Actor A, Actor B)
{
	if ( A != None )
		return A;
	return B;
}

//Saves hit info, processes after movement physics occurs, do simplest of checks
//This function never arrives earlier than corresponding ServerMove
//But another later ServerMove may arrive after this one
function ffSendHit
(
	Actor ffOther,
	Weapon Weap,
	float ffTime,
	vector ffHit,
	vector HitOffset,
	vector StartTrace,
	int CmpRot,
	int ShootFlags,
	optional float ffAccuracy
)
{
	local int LCMode;
	HitOffset /= 10;
	
	//Filter against Actor channel redirection (easy mode: do not target actors that are impossible to hit from clients)
	if ( (ffOther != None) && (ffOther.bNetTemporary || !ffOther.bCollideActors) )
		return;
		
	
	//Filter against incorrect parameters
	if ( ffISaved > 8 || !bUseLC 
		|| (Weap == none) || (CurWeapon != Weap) || Weap.IsInState('DownWeapon')
		|| !class'LCStatics'.static.IsLCWeapon(Weap,LCMode) || (LCMode != 1) )
		return;

	//Filter against weapon based crashes

	if ( !LCComp.ffClassifyShot(ffTime) ) //Time classification failure
		return;

	SavedShots[ffISaved].ffOther = ffOther;
	SavedShots[ffISaved].Weap = Weap;
	SavedShots[ffISaved].ffTime = ffTime;
	SavedShots[ffISaved].ffHit = ffHit;
	SavedShots[ffISaved].ffOff = HitOffset;
	SavedShots[ffISaved].StartTrace = StartTrace;
	SavedShots[ffISaved].CmpRot = CmpRot;
	SavedShots[ffISaved].ShootFlags = ShootFlags;
	SavedShots[ffISaved].ffAccuracy = ffAccuracy;
	SavedShots[ffISaved].bPlayerValidated = false;
	SavedShots[ffISaved].bAccuracyValidated = false;
	SavedShots[ffISaved].bRangeValidated = false;
	SavedShots[ffISaved].bBoxValidated = false;
	SavedShots[ffISaved].bRegisteredFire = false;
	SavedShots[ffISaved].Imprecise = byte(LCComp.ImpreciseTimer > 0);
	SavedShots[ffISaved].MaxTimeStamp = Level.TimeSeconds + Level.TimeDilation * 0.3;
	SavedShots[ffISaved].Error = "";
	ffISaved++;
	
	ProcessHitList();
}

function ProcessHitList()
{
	local int i;
	local ShotData EmptyData;
	
	if ( (PlayerPawn(Owner) == None) || bHitProcDone )
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
		continue;
		
	REMOVE_FROM_LIST:
		if ( SavedShots[i].Error != "" )
			RejectShot(SavedShots[i].Error);
		if ( i != --ffISaved )
			SavedShots[i] = SavedShots[ffISaved];
		SavedShots[ffISaved] = EmptyData;
	}
	bHitProcDone = true;
}


function bool ProcessHit( out ShotData Data)
{
	local XC_PosList PosList;
	local XC_LagCompensator TargetComp;
	local vector X, Y, Z, HitNormal, EndTrace;
	local float Range, CalcPing;
	local int ExtraFlags;

	Data.Error = "";
	
	//Validate weapon before processing (at all times)
	if ( !LCComp.ValidateWeapon( Data.Weap, Data.Imprecise) )
		return false;
		
	//Validate the player's view and shoot position, must be done only once
	if ( !Data.bPlayerValidated )
	{
		if ( !LCComp.ValidatePlayerView( Data.ffTime, Data.StartTrace, Data.CmpRot, Data.Imprecise, Data.Error) )
			return false;
		Data.bPlayerValidated = true;
	}
	//Validate weapon range
	if ( !Data.bRangeValidated )
	{
		if ( !LCComp.ValidateWeaponRange( Data.Weap, Data.ShootFlags, Data.StartTrace, Data.ffHit, Data.CmpRot, Data.Imprecise, Data.Error) )
			return false;
		Data.bRangeValidated = true;
	}
	//Validate the shoot dir and weapon optional aim accuracy
	if ( !Data.bAccuracyValidated )
	{
		if ( !LCComp.ValidateAccuracy( Data.Weap, Data.CmpRot, Data.StartTrace, Data.ffHit, Data.ffAccuracy, Data.ShootFlags, Data.Imprecise, Data.Error) )
			return false;
		Data.bAccuracyValidated = true;
	}
	
	//Setup target compensator
	if ( Pawn(Data.ffOther) != None )
	{
		if  ( (Pawn(Data.ffOther).PlayerReplicationInfo != None) )
		{
			TargetComp = LCActor.ffFindCompFor( Pawn(Data.ffOther));
//			if ( (TargetComp == None) && Pawn(Data.ffOther).bIsPlayer ) //Players MUST have a compensator, monsters and others not (for now)
//				Data.ffOther = None;
			if ( TargetComp != None )
			{
				TargetComp.CheckPosList();
				PosList = TargetComp.PosList;
			}

		}
	
	}
	
	//Validate actor Box
	if ( !Data.bBoxValidated )
	{
		if ( !LCComp.ValidateCylinder( PosList|Data.ffOther, Data.ffOff, Data.ffHit-Data.StartTrace, Data.Imprecise, Data.Error) )
			return false;
		// Pawns need to validate crouch state, and override hit offset
//		if ( (Pawn(Data.ffOther) != None) && !LCComp.ValidatePawnHit( Pawn(Data.ffOther), Data.ffOff, Data.ffHit - Data.StartTrace, Data.Imprecise, Data.Error) )
//			return false;
		Data.bBoxValidated = true;
	}


	if ( !Data.bRegisteredFire )
	{
		LCComp.ffCurRegTimer = float(Data.Weap.GetPropertyText("ffRefireTimer")); //Register this timer as current shoot timer
		if ( (LCComp.ImpreciseTimer <= 0) && (Data.Imprecise > 0) ) //Player skipped a security check
			LCComp.ImpreciseTimer = LCComp.ffCurRegTimer * 4;
		LCComp.ffRefireTimer += LCComp.ffCurRegTimer; //Register this new shot in the refire protection
		Data.bRegisteredFire = true;
	}

	if ( TargetComp != None )
		Data.ffOther = LCComp.ffCheckHit( TargetComp, Data.ffHit, Data.ffOff, class'LCStatics'.static.DecompressRotator(Data.CmpRot), Data.Error );

	if ( Data.Imprecise >= 2 )
	{
		Data.Error = "IMPRECISE="$Data.Imprecise;
		return false;
	}
	
	CalcPing = LCComp.GetLatency();
	if ( (Data.ffOther == none) || !Class'LCStatics'.static.RelevantHitActor(Data.ffOther, PlayerPawn(Owner), CalcPing - ProjAdv) ) //Shot missed, get another target
	{
		//Override start position if we're finding a new target
		ExtraFlags = Data.ShootFlags;
		GetAxes( Pawn(Owner).ViewRotation, X, Y, Z);
		Data.StartTrace = class'LCStatics'.static.GetStartTrace( Data.Weap, ExtraFlags, X, Y, Z);
		Range = class'LCStatics'.static.GetRange( Data.Weap, ExtraFlags);
		EndTrace = Data.StartTrace + X * Range;
		if ( Data.ffAccuracy != 0 )
			EndTrace += class'LCStatics'.static.StaticAimError( Y, Z, Data.ffAccuracy, Data.ShootFlags >>> 16);
		Data.ffOther = class'LCStatics'.static.ffIrrelevantShot( Data.ffHit, HitNormal, EndTrace, Data.StartTrace, PlayerPawn(Owner), CalcPing - ProjAdv );
		Data.Weap.ProcessTraceHit( Data.ffOther, Data.ffHit, HitNormal, X, Y, Z);
		return true;
	}
	Data.ffHit = Data.ffOther.Location + Data.ffOff;
	GetAxes( rotator(Data.ffHit - Data.StartTrace), X, Y, Z);
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
			ClientSettings.SaveConfig();
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
		bCarriedItem = bUseLC;
		if ( ClientWeaponUpdate(DeltaTime) )
			bJustSwitched = true;
			
		if ( bJustSwitched && (TournamentWeapon(CurWeapon) != None) )
		{
			//If Client weapon is about to become idle, enable ClientFire locally
			if ( CurWeapon.IsInState('ClientActive') && CurWeapon.IsAnimating() 
			&& (CurWeapon.AnimFrame + CurWeapon.AnimRate * DeltaTime >= CurWeapon.AnimLast) )
				TournamentWeapon(CurWeapon).bCanClientFire = true;
			
			bJustSwitched = !(CurWeapon.bWeaponUp || TournamentWeapon(CurWeapon).bCanClientFire);
		}

		if ( bLogTick )
		{
			Log("Channel tick at "$Level.TimeSeconds);
			bLogTick = false;
		}
		ClientWeaponFire();
		ProcessHiFi( DeltaTime);
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
		if ( PlayerPawn(Owner) == None || Owner.bDeleteMe )
		{
			Destroy();
			return;
		}
		
		bCarriedItem = bUseLC;
		ProcessHitList();
		bHitProcDone = false;
		
		if ( LCActor.bWeaponAnim )
			cAdv = LCComp.GetEngineLatency();

		if ( !LCActor.bUsePrediction || (ClientPredictCap == 0) )
			ProjAdv = 0;
		else if ( ClientPredictCap > 0 )
			ProjAdv = (fMin(LCComp.LastPing, float(ClientPredictCap) / Level.TimeDilation) / 1000.f) * Level.TimeDilation;
		else
			ProjAdv = (fMin(LCComp.LastPing, LCActor.MaxPredictNonLC / Level.TimeDilation) / 1000.f) * Level.TimeDilation;

		CheckPendingWeapon( DeltaTime);
		CheckFireOffsetY(); //Offset checking before weapon update delays offset update by one frame (good!)
		WeaponUpdate();
		OldPosition = Owner.Location;
		OldView = PlayerPawn(Owner).ViewRotation;
		OldTimeStamp = PlayerPawn(Owner).CurrentTimeStamp;
	}
	
	function WeaponUpdate()
	{
		if ( Pawn(Owner).Weapon != CurWeapon )
		{
			if ( CurWeapon != none )
				CurWeapon.SetPropertyText("LCChan","None");
			CurWeapon = Pawn(Owner).Weapon;
			if ( CurWeapon != none )
				CurWeapon.KillCredit( self);
			OldFireOffsetY = -1337; //'Reset'
		}
	}
	
	function CheckPendingWeapon( float DeltaTime)
	{
		if ( ((PendingWeaponCountdown-=DeltaTime) <= 0) && (CurPendingWeapon != Pawn(Owner).PendingWeapon) )
		{
			CurPendingWeapon = Pawn(Owner).PendingWeapon;
			ClientSetPendingWeapon( CurPendingWeapon);
			PendingWeaponCountDown = 0.2 * Level.TimeDilation; //max 5 updates per second
		}
	}
	
	function CheckFireOffsetY()
	{
		if ( (CurWeapon != None) && (CurWeapon.FireOffset.Y != OldFireOffsetY) )
		{
			ClientSetFireOffsetY( CurWeapon, CurWeapon.FireOffset.Y);
			OldFireOffsetY = CurWeapon.FireOffset.Y;
		}
	}
	
Begin:
	While ( Owner != none && !Owner.bDeleteMe )
	{
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

/****************** Weapon Firing
 *
 * ClientWeaponFire   - ZP: Asks weapon if it wants to handle fire, otherwise we do it.
 * LCTraceShot        - LC: Weapon wants to hit target using old positions.
*/
simulated function ClientWeaponFire()
{
	local int LCMode;

	if ( (bDelayedFire || bDelayedAltFire) && class'LCStatics'.static.IsLCWeapon(CurWeapon,LCMode)
	  && !class'LCStatics'.static.HandleLCFire( CurWeapon, bDelayedFire, bDelayedAltFire) )
	{
		//LC
		if ( LCMode == 0 )
		{
		}
		//ZP
		else if ( LCMode == 1 )
			class'LCStatics'.static.ClientTraceFire( CurWeapon, self);
	}
	bDelayedFire = false;
	bDelayedAltFire = false;
	assert(class'Texture'.default.MacroTexture == None);
}


simulated function Actor LCTraceShot( out vector HitLocation, out vector HitNormal, vector EndTrace, vector StartTrace, int LCMode)
{
	local Actor HitActor;
	local vector TraceHitLocation;

	HitActor = None;
	if ( LCMode == 0 ) //LC sub-engine doesn't need to wait for end of tick
	{
		if ( Level.NetMode != NM_Client )
		{
			LCActor.ffUnlagPositions( LCComp, StartTrace, rotator(EndTrace-StartTrace) );
			HitActor = class'LCStatics'.static.LCTrace( HitLocation, HitNormal, EndTrace, StartTrace, Pawn(Owner) );
			LCActor.ffRevertPositions();
		}
		else
			HitActor = Class'LCStatics'.static.ClientTraceShot( TraceHitLocation, HitLocation, HitNormal, EndTrace, StartTrace, Pawn(Owner));
	}
	return HitActor;
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

/****************** High Fidelity Mode control
 *
 * ChangeHiFi       - Client sent a mutate command to server to change HiFi.
 * ClientChangePCap - Server informs client of requested pCap change.
 * ProcessHiFi      - Main proc, ensures 60hz client movement update and change in firing states.
*/
function ChangeHiFi( bool bEnable)
{
	ClientChangeHiFi( bEnable);
}
simulated function ClientChangeHiFi( bool bEnable)
{
	if ( ClientSettings != None )
	{
		ClientSettings.bHighFidelityMode = bEnable;
		ClientSettings.SaveConfig();
	}
}

simulated function ProcessHiFi( float DeltaTime)
{
	local float AnimTime;
	
	//Force update if weapon is about to re-fire
	if ( CurWeapon != None && !CurWeapon.bRapidFire && CurWeapon.IsAnimating() )
	{
		AnimTime = class'LCStatics'.static.AnimationTimeRemaining( CurWeapon);
		if ( CurWeapon.bTicked != bTicked ) //If weapon hasn't ticked, we need to check TWO frames ahead
			AnimTime -= DeltaTime;
		if ( (AnimTime > 0) && (AnimTime <= DeltaTime) ) 
			LocalPlayer.ClientUpdateTime = 5;
	}

	//High fidelity mode forces up to 120 updates per second on client (as opposed to max 90)
	if ( ClientSettings != None && ClientSettings.bHighFidelityMode )
	{
		CounterHiFi = fClamp( CounterHiFi + DeltaTime/Level.TimeDilation, -0.1, 0.1);
		if ( LocalPlayer.PendingMove == None )
			CounterHiFi -= 1.0 / 120.0;
		if ( CounterHiFi >= 0 )
			LocalPlayer.ClientUpdateTime = 5;
	}
	
}


/****************** Client Weapon control
 *
 * ClientSetFireOffsetY   - Fix left/center/right fire offset on client.
 * ClientSetPendingWeapon - Set PendingWeapon on client if LocalPlayer isn't a TournamentPlayer
 * ClientWeaponUpdate     - Client detects effective Weapon/PendingWeapon change locally
 * AdvanceWeaponAnim      - Push forward weapon switch animations by 'lag' time
*/

simulated function ClientSetFireOffsetY( Weapon Other, float NewFireOffsetY)
{
	if ( Other != None )
		Other.FireOffset.Y = NewFireOffsetY;
}

simulated function ClientSetPendingWeapon( Weapon Other)
{
	if ( Other == none || Other.bDeleteMe || CurWeapon == Other || CurWeapon == none )
		return;
	LocalPlayer.PendingWeapon = Other; //TournamentPlayer.ClientPending is set by the weapon (replicated via server)
	if ( TournamentPlayer(LocalPlayer) != None )
		TournamentPlayer(LocalPlayer).ClientPending = Other;
}

simulated function bool ClientWeaponUpdate( float DeltaTime)
{
	local ENetRole OldRole;
	local bool bTournamentWeaponSwitch;
	
	if ( TournamentPlayer(LocalPlayer) != None )
	{
		if ( TournamentPlayer(LocalPlayer).ClientPending == CurWeapon )
			TournamentPlayer(LocalPlayer).ClientPending = None;
		LocalPlayer.PendingWeapon = TournamentPlayer(LocalPlayer).ClientPending;
	}
	
	if ( LocalPlayer.PendingWeapon != None )
	{
		if ( !bClientPendingWeapon && CurWeapon.IsInState('ClientDown') && CurWeapon.IsAnimating() )
		{
			PendingWeaponAnimAdjust = cAdv;
			if ( PendingWeaponAnimAdjust > 0 )
				AdvanceWeaponAnim( CurWeapon);
			bClientPendingWeapon = true; //Set to true when has PendingWeapon and old weapon going down
		}
	}
	
	if ( LocalPlayer.Weapon != CurWeapon )
	{
		CurWeapon = LocalPlayer.Weapon;
		if ( CurWeapon != none )
		{
			CurWeapon.KillCredit( self);
			if ( PendingWeaponAnimAdjust > 0 )
				AdvanceWeaponAnim( CurWeapon);
			PendingWeaponAnimAdjust = 0;
			
			//Fix player view before server replicates it (this can fix FireOffset!!!)
			if ( CurWeapon.PlayerViewOffset == CurWeapon.default.PlayerViewOffset )
			{
				OldRole = CurWeapon.Role;
				CurWeapon.Role = ROLE_AutonomousProxy;
				CurWeapon.SetHand( LocalPlayer.Handedness);
				CurWeapon.Role = OldRole;
			}
		}
		bClientPendingWeapon = false;
		bTournamentWeaponSwitch = (TournamentWeapon(CurWeapon) != none);
	}
	
	if ( (TournamentWeapon(CurWeapon) != None) && (ShockRifle(CurWeapon) != None) ) //Only shock...
	{
		TournamentWeapon(CurWeapon).bForceFire = false;
		TournamentWeapon(CurWeapon).bForceAltFire = false;
	}
	
	return bTournamentWeaponSwitch;
}

simulated function AdvanceWeaponAnim( Weapon Other)
{
	local float AnimTime;
	
	if ( (Other == None) || !Other.IsAnimating() )
		return;

	PendingWeaponAnimAdjust = fMax( PendingWeaponAnimAdjust, 0);

	//Skip tween
	if ( Other.AnimFrame < 0 ) 
	{
		AnimTime = -Other.AnimFrame / Other.TweenRate;
		//Force finish tween if bigger adjustment is needed
		if ( AnimTime < PendingWeaponAnimAdjust ) 
		{
			Other.AnimFrame = 0;
			PendingWeaponAnimAdjust -= AnimTime;
		}
		else
		{
			Other.AnimFrame += PendingWeaponAnimAdjust * Other.TweenRate;
			PendingWeaponAnimAdjust = 0;
			return;
		}
	}
	
	//Skip anim
	if ( Other.AnimFrame < Other.AnimLast )
	{
		AnimTime = (Other.AnimLast - Other.AnimFrame) / Other.AnimRate;
		//Force finish animation if bigger adjustment is needed
		if ( AnimTime < PendingWeaponAnimAdjust ) 
		{
			Other.AnimFrame = Other.AnimLast;
			PendingWeaponAnimAdjust -= AnimTime;
			if ( !Other.bAnimLoop )
			{
				Other.AnimRate = 0;
				Other.bAnimFinished = true;
			}
			if ( TournamentWeapon(Other) != None )
				TournamentWeapon(Other).bCanClientFire = Other.IsInState('ClientActive');
			Other.AnimEnd();
		}
		else
		{
			Other.AnimFrame += PendingWeaponAnimAdjust * Other.AnimRate;
			PendingWeaponAnimAdjust = 0;
		}
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
		PlayerPawn(Owner).ClientMessage( "[LC]"@Reason);
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