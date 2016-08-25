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

	if ( PlayerPawn(Owner) != None )
		PlayerPawn(Owner).ShakeView(ShakeTime, ShakeMag, ShakeVert);
  	if (Other == Level) 
	{
		if ( IsLC() )
			Spawn(class'LC_spexp',Owner,, HitLocation+HitNormal*9, Rotator(HitNormal)).SetPropertyText("bNotRelevantToOwner","1");
		else
			Spawn(class'LC_spexp',,, HitLocation+HitNormal*9, Rotator(HitNormal));
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
	local actor Other, aActor;

	if ( Owner == none )
		return;
	GetAxes( class'LCStatics'.static.PlayerRot( Pawn(Owner)), X,Y,Z);

	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.Y * Y + FireOffset.Z * Z;  //CALCDRAWOFFSET MIGHT SCREW UP THINGS
	EndTrace = StartTrace + Accuracy * (FRand() - 0.5 )* Y * 1000 + Accuracy * (FRand() - 0.5 ) * Z * 1000;
	EndTrace += (10000 * X); 
	ForEach Owner.TraceActors( class'Actor', aActor, HitLocation, HitNormal, EndTrace, StartTrace)
	{
		if ( Class'LCStatics'.static.TraceStopper( aActor) )
		{	Other = aActor;
			break;
		}
		if ( (!aActor.bProjTarget && !aActor.bBlockActors) || (aActor == Owner) )
			continue;
		if ( aActor.IsA('Pawn') && !Pawn(aActor).AdjustHitLocation(HitLocation, EndTrace - StartTrace) )
			continue;
		Other = aActor;
		break;
	}

	if (Other == Level) 
		Spawn(class'LC_spexp',,, HitLocation+HitNormal*9, Rotator(HitNormal));
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
