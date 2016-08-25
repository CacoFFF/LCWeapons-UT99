//************************************************************
// By Higor
// This channel was made to prevent unwanted function calls
// Keeps the log cleaner
//************************************************************
class XC_CompensatorChannel expands Info
	config(LCWeapons);

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
var rotator OldView;
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

var() config bool bUseLagCompensation;
var() config int ForcePredictionCap;

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
	var private int ffID, CmpRot, ShootFlags;
	var private float ffTime;
	var private vector ffHit, ffOff, ffStartTrace;
	var private rotator ffView;
	var private float ffAccuracy;
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
		ffForceLC, ClientChangeLC, SetPendingW, ReceiveSWJumpPad, LockSWJumpPads, ClientChangePCap;
	reliable if ( Role < ROLE_Authority )
		ffSetLC, ffSendHit, RequestSWJumpPads, RequestPCap;
}

//Saves hit info, processes after movement physics occurs, do simplest of checks
function ffSendHit( Actor ffOther, Weapon Weap, int ffID, float ffTime, vector ffHit, vector ffOff, rotator ffView, vector ffStartTrace, int CmpRot, int ShootFlags, optional float ffAccuracy)
{
	if ( ffISaved > 8 || (Weap == none) || (CurWeapon != Weap) )
		return;
	if ( ffOther != none && ffID != -1 ) //Process this here
		return;
	if ( Weap.IsInState('DownWeapon') )
	{
		Log("DOWNWEAPON State", 'LagCompensator');
		return;
	}
	if ( int(ffAccuracy != 0) + int((ShootFlags >>> 16) == 0) != 1 )
	{
		Log("Accuracy("$ffAccuracy$") and ShootFlags("$ShootFlags$") inconsistency",'LagCompensator');
		return;
	}
	if ( !LCComp.ffClassifyShot(ffTime) ) //Time classification failure
		return;


	if ( !bAlreadyProcessed )
	{
		bAlreadyProcessed = true;
		if ( !ProcessHit( ffOther, Weap, ffID, ffTime, ffHit, ffOff, ffView, ffStartTrace, CmpRot, ShootFlags, ffAccuracy) )
			Goto TO_QUEUE;
		return;
	}
	TO_QUEUE: //Give this shot another opportunity to process at the end of the frame
	Log("Shot delayed to end of frame",'LagCompensator');
	SavedShots[ffISaved].ffOther = ffOther;
	SavedShots[ffISaved].Weap = Weap;
	SavedShots[ffISaved].ffID = ffID;
	SavedShots[ffISaved].ffTime = ffTime;
	SavedShots[ffISaved].ffHit = ffHit;
	SavedShots[ffISaved].ffOff = ffOff;
	SavedShots[ffISaved].ffView = ffView;
	SavedShots[ffISaved].ffStartTrace = ffStartTrace;
	SavedShots[ffISaved].CmpRot = CmpRot;
	SavedShots[ffISaved].ShootFlags = ShootFlags;
	SavedShots[ffISaved].ffAccuracy = ffAccuracy;
	ffISaved++;
}

function bool ProcessHit( Actor ffOther, Weapon Weap, int ffID, float ffTime, vector ffHit, vector ffOff, rotator ffView, vector ffStartTrace, int CmpRot, int ShootFlags, float ffAccuracy)
{
	local XC_LagCompensator ffLC;
	local vector X, Y, Z, EndTrace;
	local float Range, CalcPing;
	local byte Imprecise;
	local int Seed;

	if ( Weap == none || Weap.bDeleteMe || Pawn(Owner).Weapon != Weap ) //Fixes a weapon toss exploit that allows teamkilling
		return false;
	
	Imprecise = byte(LCComp.ImpreciseTimer > 0);
	if ( ffAccuracy != 0 )
		Seed = ShootFlags >>> 16;
	if ( !bUseLC || !LCActor.FastValidate( self, ffOther, ffID, Weap, CmpRot, Owner.Location, ffStartTrace, ffHit, Imprecise, ffAccuracy, ShootFlags) ) //NEEDS FIXING!
		return false;

	LCComp.ffCurRegTimer = float(Weap.GetPropertyText("ffRefireTimer")); //Register this timer as current shoot timer
	if ( (LCComp.ImpreciseTimer <= 0) && (Imprecise > 0) ) //Player skipped a security check
		LCComp.ImpreciseTimer = LCComp.ffCurRegTimer * 4;
	LCComp.ffRefireTimer += LCComp.ffCurRegTimer; //Register this new shot in the refire protection

	if  ( ffID != -1 )
		ffOther = LCComp.ffCheckHit( ffID, ffHit, ffOff, ffView);

	CalcPing = float(LCComp.ffLastPing) / 1000.0;
	if ( (ffOther == none) || !Class'LCStatics'.static.RelevantHitActor(ffOther, PlayerPawn(Owner), CalcPing - ProjAdv) ) //Shot missed, get another target
	{
		if ( (ShootFlags & 2) == 0 )
		{
			GetAxes( Pawn(Owner).ViewRotation, X, Y, Z);
			if ( (ShootFlags & 1) == 0 )
				ffStartTrace = Owner.Location + Pawn(Owner).BaseEyeheight * vect(0,0,1);
			else
				ffStartTrace = Owner.Location + Weap.CalcDrawOffset() + Weap.FireOffset.Y * Y + Weap.FireOffset.Z * Z;
		}
		else
			GetAxes( rotator(ffHit - ffStartTrace), X, Y, Z);
		Range = 10000;
		if ( (ShootFlags & 4) > 0 )			Range += 10000;
		if ( (ShootFlags & 8) > 0 )			Range += 20000;
		EndTrace = ffStartTrace + X * Range;
		if ( Seed > 0 )
			EndTrace += class'LCStatics'.static.StaticAimError( Y, Z, ffAccuracy, Seed);
		ffOther = Class'LCStatics'.static.ffIrrelevantShot( ffHit, ffOff, EndTrace, ffStartTrace, Pawn(Owner), CalcPing - ProjAdv );
		Weap.ProcessTraceHit( ffOther, ffHit, ffOff, X, Y, Z);
		return true;
	}
	ffHit = ffOther.Location + ffOff;
	GetAxes( rotator(ffHit - ffStartTrace), X, Y, Z);
	Weap.ProcessTraceHit( ffOther, ffHit, -X, X, Y, Z);
	return true;
}

function ffSetLC( bool bEnable)
{
	if ( bUseLC == bEnable )
		ffForceLC( bEnable);
	bUseLC = bEnable;
}

simulated event PostNetBeginPlay()
{
	if ( PlayerPawn(Owner) != none && ViewPort(PlayerPawn(Owner).Player) != none ) 
		LocalPlayer = PlayerPawn(Owner);
	else
	{
		GotoState('ClientNone');
		return;
	}


	GotoState('ClientOp');
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

		//Fix ACE kick on preloaded swJumpPads
		ForEach AllActors (class'Teleporter', T)
			if ( T.IsA('swJumpPad') )
			{
				OldRole = T.Role;
				T.Role = ROLE_AutonomousProxy;
				T.SetPropertyText("bTraceGround","0");
				T.Role = OldRole;
			}
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
	if ( LocalPlayer.IsA('bbPlayer') )
		Spawn(class'LCWeaponHUD').LocalPlayer = LocalPlayer;
FindClient:
	RequestPCap( ForcePredictionCap);
	Sleep(0.3); //Safer
	CheckSWJumpPads();
AdjustClient:
	if ( bUseLagCompensation != bUseLC ) //This will work on high packet loss environments
		ffSetLC( bUseLagCompensation);
	if ( ClientPredictCap != ForcePredictionCap)
	{
		if ( FRand() < 0.1 ) //If server fails to replicate this, reset to 0 and restart again to cleanup replication with Packet loss
			RequestPCap( 0);
		else
			RequestPCap( ForcePredictionCap);
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
		LCComp = LCActor.ffGetLC( Other);
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
		While ( i < ffISaved )
		{
			CurWeapon.Tick(0);
			ProcessHit( SavedShots[i].ffOther, SavedShots[i].Weap, SavedShots[i].ffID, SavedShots[i].ffTime, SavedShots[i].ffHit, SavedShots[i].ffOff, SavedShots[i].ffView, SavedShots[i].ffStartTrace, SavedShots[i].CmpRot, SavedShots[i].ShootFlags, SavedShots[i].ffAccuracy);
			SavedShots[i].ffOther = none;
			SavedShots[i].ffID = -1;
			SavedShots[i].Weap = none;
			i++;
		}
		ffISaved = 0;
		bAlreadyProcessed = false;
		if ( LCActor.bWeaponAnim )
			cAdv = (float(LCComp.ffLastPing) / 1000) * Level.TimeDilation;

		if ( !LCActor.bUsePrediction || (ClientPredictCap == 0) )
			ProjAdv = 0;
		else if ( ClientPredictCap > 0 )
			ProjAdv = (fMin(LCComp.ffLastPing, float(ClientPredictCap) / Level.TimeDilation) / 1000.f) * Level.TimeDilation;
		else
			ProjAdv = (fMin(LCComp.ffLastPing, LCActor.MaxPredictNonLC / Level.TimeDilation) / 1000.f) * Level.TimeDilation;

		if ( Owner != none )
			OldView = Pawn(Owner).ViewRotation;
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

simulated function ffForceLC( bool bEnable)
{
	bUseLC = bEnable;
}

simulated function ClientChangeLC( bool bEnable)
{
	bUseLagCompensation = bEnable;
	SaveConfig();
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

function ChangePCap( int NewPCap)
{
	ClientPredictCap = NewPCap;
	ClientChangePCap( NewPCap);
}

simulated function ClientChangePCap( int NewPCap)
{
	ClientPredictCap = NewPCap;
	ForcePredictionCap = NewPCap;
	if ( LocalPlayer != none && ViewPort(LocalPlayer.Player) != none )
		SaveConfig();
}

function RequestSWJumpPads()
{
	if ( bSWChecked )
		return;
	bSWChecked = true;
}

function RequestPCap( int NewPCap)
{
	ClientPredictCap = NewPCap;
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

defaultproperties
{
    bGameRelevant=True
    bHidden=True
    NetPriority=1.1
    NetUpdateFrequency=20
    RemoteRole=ROLE_SimulatedProxy
    bUseLC=True
    bUseLagCompensation=True
	ForcePredictionCap=-1
	ClientPredictCap=-1
}