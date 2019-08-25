//=============================
// As seen on MH-RuinsOfHarobed
//=============================

class LCLiandriMinigun expands LCMinigun;

var bool bGraphicsInitialized;
var class<TournamentWeapon> OrgClass; //Original class, this must be set!

simulated event Spawned()
{
	if ( !bGraphicsInitialized )
		InitGraphics();
}

simulated event PostNetBeginPlay()
{
	Super.PostNetBeginPlay();
	if ( !bGraphicsInitialized )
		InitGraphics();
}

simulated function InitGraphics()
{
	//Attempt to predict in case of replication failure
	if ( (OrgClass == none) && (Role == ROLE_SimulatedProxy) )
	{
		Role = ROLE_AutonomousProxy;
		SetPropertyText("OrgClass","LMinigun");
		Role = ROLE_SimulatedProxy;
	}

	if ( OrgClass == none )
	{
		Log("Original class not loaded! (LiandriMinigun)");
		return;
	}
	else
		default.bGraphicsInitialized = true;
	bGraphicsInitialized = true;
	default.FireSound = OrgClass.default.FireSound;
	FireSound = default.FireSound;
	default.AltFireSound = OrgClass.default.AltFireSound;
	AltFireSound = default.AltFireSound;
	default.AmmoName = OrgClass.default.AmmoName;
	AmmoName = default.AmmoName;
	default.MultiSkins[1] = OrgClass.default.MultiSkins[1];
	MultiSkins[1] = default.MultiSkins[1];
	
	default.PlayerViewMesh = OrgClass.default.PlayerViewMesh;
	PlayerViewMesh = default.PlayerViewMesh;
	
	if ( Role == ROLE_Authority )
	{
		Spawn(class'LCLiandriMiniLoader').TCL = OrgClass;
	}
}


function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local int rndDam;
	local Actor Effect;

	if ( PlayerPawn(Owner) != None )
		PlayerPawn(Owner).ShakeView(ShakeTime, ShakeMag, ShakeVert);
  	if (Other == Level) 
	{
		Effect = Spawn( class'FV_spexp', Owner,, HitLocation + HitNormal * 9, Rotator(HitNormal));
		class'LCStatics'.static.SetHiddenEffect( Effect, Owner, LCChan);
	}
	else if ( (Other!=self) && (Other!=Owner) && (Other != None) ) 
	{
		if ( Other.IsA('ScriptedPawn') && (FRand() < 0.2) )
			Pawn(Other).WarnTarget(Pawn(Owner), 500, X);
		rndDam = 35 + Rand(6);
		if ( FRand() < 0.2 )
			X *= 2;
		Other.TakeDamage(rndDam, Pawn(Owner), HitLocation, rndDam*500.0*X, 'shot');
	}
}

simulated function SimTraceFire( float Accuracy )
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local Actor Other;
	local int ExtraFlags;

	if ( Owner == None )
		return;
	GetAxes( class'LCStatics'.static.PlayerRot( Pawn(Owner)), X,Y,Z);

	StartTrace = GetStartTrace( ExtraFlags, X,Y,Z);  //CALCDRAWOFFSET MIGHT SCREW UP THINGS
	EndTrace = StartTrace
		+ X * GetRange( ExtraFlags)
		+ Accuracy * (FRand() - 0.5 ) * Y * 1000
		+ Accuracy * (FRand() - 0.5 ) * Z * 1000;
	Other = class'LCStatics'.static.ffTraceShot( HitLocation, HitNormal, EndTrace, StartTrace, Pawn(Owner));
	if ( Other == Level )
		Spawn( class'FV_spexp',,, HitLocation + HitNormal * 9, Rotator(HitNormal));
}


defaultproperties
{
     MaxTargetRange=8128.000000
     PickupAmmoCount=100
     shakemag=135.000000
     shakevert=8.000000
     AIRating=0.750000
     PickupMessage="You picked up the Liandri Minigun"
     ItemName="Liandri Minigun"
     LightEffect=LE_NonIncidence
     LightBrightness=250
     LightHue=28
     LightSaturation=32
     LightRadius=6
}
