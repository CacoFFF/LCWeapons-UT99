//==================================================================================
// LCMinigun
//==================================================================================
class LCMinigun2 extends minigun2;

var XC_CompensatorChannel LCChan;
var int LCMode;

var bool bBulletNow;
var bool bSpawnTracers;
var bool bTIW;

var float SlowSleep;
var float FastSleep;
var float SlowTIW; //Goes to SlowSleep if bTIW
var float FastTIW; //Goes to FastSleep if bTIW
var float SlowAccuracy;
var float FastAccuracy;
var float TIWCounter;

var int BaseDamage;
var int RandomDamage;

var vector LastStartTrace;


replication
{
	reliable if ( bNetOwner && Role == ROLE_Authority )
		SlowSleep, FastSleep;
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


simulated function TraceFire( float Accuracy )
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local Actor Other;
	local int ExtraFlags;

	if ( Owner == none )
		return;

	Owner.MakeNoise(Pawn(Owner).SoundDampening);
	GetAxes( class'LCStatics'.static.PlayerRot(Pawn(Owner)), X,Y,Z);
	StartTrace = GetStartTrace( ExtraFlags, X,Y,Z); 
	AdjustedAim = Pawn(Owner).AdjustAim( 1000000, StartTrace, 2.75*AimError, False, False);	
	X = vector(AdjustedAim);
	EndTrace = StartTrace
		+ X * GetRange( ExtraFlags)
		+ Accuracy * (FRand() - 0.5 ) * Y * 1000
		+ Accuracy * (FRand() - 0.5 ) * Z * 1000;
	if ( IsLC() )
		Other = LCChan.LCTraceShot(HitLocation,HitNormal,EndTrace,StartTrace,LCMode);
	else
		Other = Pawn(Owner).TraceShot(HitLocation,HitNormal,EndTrace,StartTrace);
	ProcessTraceHit(Other, HitLocation, HitNormal, vector(AdjustedAim),Y,Z);
}

simulated function ProcessTraceHit( Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local int rndDam;
	local Actor Effect;
	
	if ( bSpawnTracers && (Count++ == 4) )
	{
		Count = 0;
		if ( VSize(HitLocation - LastStartTrace) > 250 )
		{
			Effect = Spawn( class'FV_MTracer',,, LastStartTrace + 96 * X, rotator(HitLocation-LastStartTrace));
			if ( LCChan != None )
				LCChan.SetHiddenEffect( Effect, Owner);
			Effect = None;
		}
	}
	
	if ( Other == Level )
		Effect = Spawn( class'FV_LightWallHitEffect',,, HitLocation+HitNormal, Rotator(HitNormal));
	else if ( (Other!=self) && (Other!=Owner) && (Other != None) ) 
	{
		if ( !Other.bIsPawn && !Other.IsA('Carcass') )
			Effect = Spawn( class'FV_SpriteSmokePuff',,, HitLocation+HitNormal*9);
		else
			Other.PlaySound( Sound'ChunkHit',, 4.0,,100);

		if ( Other.IsA('Bot') && (FRand() < 0.2) )
			Pawn(Other).WarnTarget( Pawn(Owner), 500, X);

		rndDam = BaseDamage + Rand(RandomDamage);
		if ( NoMomentum() ) //v469 lockdown switch
			X = vect(0,0,0);
		else if ( FRand() < 0.2 )
			X *= 2.5;
		else if ( (Pawn(Other) != None) && Pawn(Other).bIsPlayer )
			X = vect(0,0,0); //Lockdown prevention on players
		Other.TakeDamage( rndDam, Pawn(Owner), HitLocation, rndDam*500.0*X, MyDamageType);
	}
	if ( LCChan != None )
		LCChan.SetHiddenEffect( Effect, Owner);
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

state ClientFinish
{
	simulated function bool ClientFire(float Value)
	{
		return false;
	}

	simulated function bool ClientAltFire(float Value)
	{
		return false;
	}
}


//Doing this because ACE has bugs
simulated event RenderOverlays( Canvas Canvas )
{
	Super.RenderOverlays(Canvas);
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
	TraceFire( ShotAccuracy);
	if ( LCChan.bSimAmmo && (AmmoType != none && AmmoType.AmmoAmount > 0) )
		AmmoType.AmmoAmount--;
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
		local Pawn Shooter;
		
		Shooter = Pawn(Owner);
		if ( Shooter == None ) 
		{
			AmbientSound = None;
			GotoState('Pickup');
			return;
		}

		if ( (Shooter.PlayerReplicationInfo != None) && Shooter.PlayerReplicationInfo.bFeigningDeath )
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
		local Pawn Shooter;
		
		Shooter = Pawn(Owner);
		if ( Shooter == None ) 
		{
			AmbientSound = None;
			GotoState('Pickup');
			return;
		}			

		if ( bFiredShot && ((Shooter.bAltFire==0) || bOutOfAmmo) ) 
		{
			GoToState('FinishFire');
			return;
		}

		if ( (Shooter.PlayerReplicationInfo != None) && Shooter.PlayerReplicationInfo.bFeigningDeath )
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



//***********************************************************************
// LCWeapons common interfaces
//***********************************************************************
function Inventory SpawnCopy( Pawn Other )
{
	return Class'LCStatics'.static.SpawnCopy( Other, self);
}
function GiveTo( Pawn Other )
{
	Class'LCStatics'.static.GiveTo(Other,self);
}
function SetSwitchPriority( Pawn Other)
{
	Class'LCStatics'.static.SetSwitchPriority( Other, self, 'minigun2');
}
simulated function float GetRange( out int ExtraFlags)
{
	return 10000;
}
simulated function vector GetStartTrace( out int ExtraFlags, vector X, vector Y, vector Z)
{
	LastStartTrace = Owner.Location + CalcDrawOffset() + FireOffset.Y * Y + FireOffset.Z * Z;
	return LastStartTrace;
}
simulated function bool IsLC()
{
	return (LCChan != none) && LCChan.bUseLC && (LCChan.Owner == Owner);
}
simulated function float GetAimError()
{
	return ShotAccuracy;
}
simulated function bool HandleLCFire( bool bFire, bool bAltFire)
{
	return true; //Don't let LCChan hitscan fire
}

simulated function bool NoMomentum()
{
	if ( Level.Game != None )
		return Level.Game.GetPropertyText("NoLockdown") == "1";
	return false;
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
	BaseDamage=9
	RandomDamage=6
}
