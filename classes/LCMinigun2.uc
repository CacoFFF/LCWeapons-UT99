//==================================================================================
// LCMinigun
//==================================================================================
class LCMinigun2 extends minigun2;

//OBFSTART
var XC_CompensatorChannel LCChan;
var bool bBulletNow;
var bool bSpawnTracers;
var bool bTIW;
var bool bInstantUnwind;

var float SlowSleep;
var float FastSleep;
var float SlowTIW; //Goes to SlowSleep if bTIW
var float FastTIW; //Goes to FastSleep if bTIW
var float SlowAccuracy;
var float FastAccuracy;
var float TIWCounter;

replication
{
	reliable if ( bNetOwner && Role == ROLE_Authority )
		SlowSleep, FastSleep;
		
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
	Class'LCStatics'.static.SetSwitchPriority( Other, self, 'minigun2');
}

////////////////////////////////
//All of the unlagged code here
simulated event KillCredit( actor Other)
{
	if ( XC_CompensatorChannel(Other) != none )
		LCChan = XC_CompensatorChannel(Other);
	else if ( LCMutator(Other) != none )
		bTIW = LCMutator(Other).bTIWFire;
}
simulated function PlayPostSelect()
{
	if ( Level.NetMode == NM_Client )
		bCanClientFire = True;
	Super.PlayPostSelect();
}
simulated function bool IsLC()
{
	return (LCChan != none) && LCChan.bUseLC && (LCChan.Owner == Owner);
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


//Serverside tracer
function TraceFire( float Accuracy )
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z, AimDir;
	local actor Other, aActor;
	local bool bIsLC;

	if ( Owner == none )
		return;

	Owner.MakeNoise(Pawn(Owner).SoundDampening);
	GetAxes(Pawn(owner).ViewRotation,X,Y,Z);
	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.Y * Y + FireOffset.Z * Z; 
	AdjustedAim = pawn(owner).AdjustAim(1000000, StartTrace, 2.75*AimError, False, False);	
	EndTrace = StartTrace + Accuracy * (FRand() - 0.5 )* Y * 1000 + Accuracy * (FRand() - 0.5 ) * Z * 1000;
	AimDir = vector(AdjustedAim);
	EndTrace += (10000 * AimDir);

	bIsLC = IsLC();
	
	if ( bIsLC )
	{
		LCChan.LCActor.ffUnlagPositions( LCChan.LCComp, StartTrace, rotator(EndTrace-StartTrace) );
		ForEach Owner.TraceActors( class'Actor', aActor, HitLocation, HitNormal, EndTrace, StartTrace)
		{
			if ( Class'LCStatics'.static.TraceStopper( aActor) )
			{
				Other = aActor;
				break;
			}
			if ( (!aActor.bProjTarget && !aActor.bBlockActors) || Class'LCStatics'.static.CompensatedType(aActor) )
				continue;
			if ( aActor.bIsPawn && !Pawn(aActor).AdjustHitLocation(HitLocation, EndTrace - StartTrace) )
				continue; //We can't hit this Pawn due to special collision rules
	
			Other = aActor;
			break;
		}
		Other = Class'LCStatics'.static.CompensatedHitActor( Other, HitLocation);
		LCChan.LCActor.ffRevertPositions();
	}
	else
		Other = Pawn(Owner).TraceShot(HitLocation,HitNormal,EndTrace,StartTrace);

	if ( bSpawnTracers )
	{
		Count++;
		if ( Count == 4 )
		{
			Count = 0;
			if ( VSize(HitLocation - StartTrace) > 250 )
			{
				if ( bIsLC && LCChan.LCActor.bNeedsHiddenEffects )
					Spawn(class'LCMTracer',Owner,, StartTrace + 96 * AimDir,rotator(EndTrace - StartTrace));
				else
					Spawn(class'MTracer',Owner,, StartTrace + 96 * AimDir,rotator(EndTrace - StartTrace)).SetPropertyText("bNotRelevantToOwner", string(bIsLC));
			}
		}
	}
	ProcessTraceHit(Other, HitLocation, HitNormal, vector(AdjustedAim),Y,Z);
}

function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local int rndDam;
	local bool bIsLC;

	bIsLC = IsLC();
	if (Other == Level) 
	{
		if ( bIsLC && LCChan.LCActor.bNeedsHiddenEffects )
			Spawn(class'LCLightWallHitEffect',Owner,, HitLocation+HitNormal, Rotator(HitNormal));
		else
			Spawn(class'UT_LightWallHitEffect',Owner,, HitLocation+HitNormal, Rotator(HitNormal)).SetPropertyText("bNotRelevantToOwner", string(bIsLC));
	}
	else if ( (Other!=self) && (Other!=Owner) && (Other != None) ) 
	{
		if ( !Other.bIsPawn && !Other.IsA('Carcass') )
			Spawn(class'UT_SpriteSmokePuff',Owner,,HitLocation+HitNormal*9).SetPropertyText("bNotRelevantToOwner", string(bIsLC));
		else
			Other.PlaySound(Sound 'ChunkHit',, 4.0,,100);

		if ( Other.IsA('Bot') && (FRand() < 0.2) )
			Pawn(Other).WarnTarget(Pawn(Owner), 500, X);
		rndDam = 9 + Rand(6);
		if ( FRand() < 0.2 )
			X *= 2.5;
		else
			X = vect(0,0,0); //Lockdown prevention
		Other.TakeDamage(rndDam, Pawn(Owner), HitLocation, rndDam*500.0*X, MyDamageType);
	}
}


simulated state ClientFiring
{
Begin:
	ShotAccuracy = SlowAccuracy;
	Sleep( SlowSleep);
	bBulletNow = true;
	Goto('Begin');
}

simulated state ClientAltFiring
{
	simulated event Tick( float DeltaTime)
	{
		local bool bOldB;
		bOldB = bBulletNow;
		Global.Tick( DeltaTime);
		if ( bOldB && (Pawn(Owner) != none) && (Pawn(Owner).bAltFire == 0) )
		{
			PlayUnwind();
			GotoState('');
		}
	}
Begin:
	ShotAccuracy = SlowAccuracy;
	Sleep( SlowSleep);
	bBulletNow = true;
	if ( AnimSequence == 'Shoot2' )
		Goto('FastShoot');
	Goto('Begin');
FastShoot:
	ShotAccuracy = FastAccuracy;
	Sleep( FastSleep);
	bBulletNow = true;
	Goto('FastShoot');
}

//Doing this because ACE has bugs, problem is, tick happens 1 frame after bBulletNow is set!!!
simulated event Tick( float DeltaTime)
{
	Super.Tick(DeltaTime);
	if ( bBulletNow && (Level.NetMode == NM_Client) )
	{
		SimGenerateBullet();
		bBulletNow = false;
	}
}

simulated function SimGenerateBullet()
{
	if ( !IsLC() )
		return;
	bFiredShot = true;
	SimTraceFire( ShotAccuracy);
	if ( LCChan.bSimAmmo && (AmmoType != none && AmmoType.AmmoAmount > 0) )
		AmmoType.AmmoAmount--;
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
	if ( bSpawnTracers )
	{
		Count++;
		if ( Count == 4 )
		{
			Count = 0;
			if ( VSize(HitLocation - StartTrace) > 250 )
				Spawn(class'MTracer',,, StartTrace + 96 * X,rotator(EndTrace - StartTrace));
		}
	}
	if (Other == Level) 
		Spawn(class'UT_LightWallHitEffect',Owner,, HitLocation+HitNormal, Rotator(HitNormal));
}


state NormalFire
{
	function BeginState()
	{
		if ( bTIW )
		{
			SlowSleep = SlowTIW;
			TIWCounter = SlowTIW;
		}	
		Super.BeginState();
	}	
	function Tick( float DeltaTime )
	{
		if (Owner==None) 
		{
			AmbientSound = None;
			return;
		}

		if ( Pawn(owner).PlayerReplicationInfo.bFeigningDeath )
		{
			GotoState('FinishFire');
			return;
		}
		
		//TIW firing is handled here
		if ( bTIW && (TIWCounter -= DeltaTime) <= 0 )
		{
			TIWCounter += SlowTIW;
			if ( TIWCounter < 0 )
				TIWCounter *= 0.2; //Tickrate too low, don't spam fire
			GenerateBullet();
		}

	}
Begin:
	ShotAccuracy = SlowAccuracy;
	if ( bTIW )
		Stop;
Refire:
	Sleep( SlowSleep);
	GenerateBullet();
	Goto('Refire');
}

state AltFiring
{
	function BeginState()
	{
		if ( bTIW )
		{
			SlowSleep = SlowTIW;
			TIWCounter = SlowTIW;
		}	
		ShotAccuracy = SlowAccuracy;
		Super.BeginState();
	}	
	function Tick( float DeltaTime )
	{
		if (Pawn(Owner)==None) 
		{
			AmbientSound = None;
			GotoState('Pickup');
			return;
		}			

		if ( bFiredShot && ((Pawn(Owner).bAltFire==0) || bOutOfAmmo) ) 
		{
			GoToState('FinishFire');
			return;
		}

		if ( (Pawn(Owner).Weapon != none) && Pawn(Owner).PlayerReplicationInfo.bFeigningDeath )
		{
			GotoState('FinishFire');
			return;
		}
		
		//TIW firing is handled here
		if ( bTIW && (TIWCounter -= DeltaTime) <= 0 )
		{
			GenerateBullet();
			if ( AnimSequence == 'Shoot2' )
			{
				TIWCounter += FastTIW;
				ShotAccuracy = FastAccuracy;
			}
			else
				TIWCounter += SlowTIW;
			if ( TIWCounter < 0 )
				TIWCounter *= 0.2; //Tickrate too low, don't spam fire
		}
	}
Begin:
	ShotAccuracy = SlowAccuracy;
	if ( bTIW )
		Stop;
SlowShoot:
	Sleep( SlowSleep);
	GenerateBullet();
	if ( AnimSequence == 'Shoot2' )
		Goto('FastShoot');
	Goto('SlowShoot');
FastShoot:
	ShotAccuracy = FastAccuracy;
	Sleep( FastSleep);
	GenerateBullet();
	Goto('FastShoot');
}


defaultproperties
{
	bSpawnTracers=True
	SlowSleep=0.13
	FastSleep=0.08
	SlowTIW=0.15
	FastTIW=0.10
	SlowAccuracy=0.2
	FastAccuracy=0.75
}
