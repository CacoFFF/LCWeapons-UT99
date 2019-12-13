class LCImpactHammer expands ImpactHammer;

var XC_CompensatorChannel LCChan;
var int LCMode;

var bool bFireRelease;
var rotator BufferedDir;
var int ShootFlags;

//ExtraFlags:
// 0=primary manual
// 1=primary auto
// 2=alt


////////////////////////////////
//All of the unlagged code here
simulated event KillCredit( actor Other)
{
	if ( XC_CompensatorChannel(Other) != none )
		LCChan = XC_CompensatorChannel(Other);
}

simulated function PlayPostSelect()
{
	if ( Level.NetMode == NM_Client )
		bCanClientFire = True;
	Super.PlayPostSelect();
}


simulated function PlayAltFiring()
{
	if ( Owner != None )
	{
		Super.PlayAltFiring();
		if ( Level.NetMode == NM_Client )
		{
			ShootFlags = 2;
			SimTraceFire();
		}
	}
}


function Fire( float Value )
{
	bPointing = True;
	bCanClientFire = true;
	ClientFire(Value);
	Pawn(Owner).PlayRecoil(FiringSpeed);
	ShootFlags = 0;
	GoToState('Firing');
}
function AltFire( float Value )
{
	bPointing = True;
	bCanClientFire = true;
	ClientAltFire(value);
	Pawn(Owner).PlayRecoil(FiringSpeed);
	ShootFlags = 2;
	GoToState('AltFiring');
	TraceFire(0);
}




state Firing
{
	function AltFire(float F) 
	{
	}

	function Tick( float DeltaTime )
	{
		local PlayerPawn P;
		local vector HitLocation, HitNormal, StartTrace, EndTrace, X, Y, Z;
		local Actor HitActor;

		P = PlayerPawn(Owner);
		if ( P == none )
		{
			Super.Tick( DeltaTime);
			return;
		}

		if ( bChangeWeapon )
			GotoState('DownWeapon');

		if( P.bFire==0 ) 
		{
			TraceFire(0);
			PlayFiring();
			GoToState('FireBlast');
			return;
		}

		ChargeSize += 0.75 * DeltaTime;
		Count += DeltaTime;
		if ( Count > 0.2 )
		{
			Count = 0;
			Owner.MakeNoise(1.0);
		}
		if (ChargeSize > 1) 
		{
			GetAxes(P.ViewRotation, X, Y, Z);
			StartTrace = P.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z; 
			EndTrace = StartTrace + 60 * X;  //25 ON LOCAL GAMES??

			if ( IsLC() )
				HitActor = LCChan.LCTraceShot(HitLocation,HitNormal,EndTrace,StartTrace,LCMode);
			else
				HitActor = Trace(HitLocation, HitNormal, EndTrace, StartTrace, true);


			if ( (HitActor != None) && (HitActor.DrawType == DT_Mesh) )
			{
				GetAxes( BufferedDir, X, Y, Z); //HA!
				ProcessTraceHit(HitActor, HitLocation, HitNormal, X, Y, Z);
				PlayFiring();
				GoToState('FireBlast');
			}
		}
	}
}

state ClientFiring
{
	simulated event BeginState()
	{
		ShootFlags = 0;
		bFireRelease = false;
	}
	simulated function AnimEnd()
	{
		AmbientSound = TensionSound;
		SoundVolume = 255*Pawn(Owner).SoundDampening;		
		LoopAnim('Shake', 0.9);
		Disable('AnimEnd');
	}
	simulated event Tick( float DeltaTime)
	{
		local PlayerPawn P;

		if ( !IsLC() )
			return;

		P = PlayerPawn( Owner);

		ChargeSize += 0.75 * DeltaTime;
		if( (P != none) && (P.bFire==0) && !bFireRelease )
		{
			bFireRelease = true;
			SimTraceFire();
//			PlayFiring();
//			GoToState('FireBlast');
//			return;
		}
	}
}

simulated function SimTraceFire()
{
	local vector HitLocation, AdjustedHitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local Actor Other;

	if ( Pawn(Owner) == none )
		return;
	GetAxes( Pawn(Owner).ViewRotation, X,Y,Z);
	StartTrace = GetStartTrace( ShootFlags, X,Y,Z) ;
	EndTrace = StartTrace + GetRange( ShootFlags) * X; 

	Other = Class'LCStatics'.static.ClientTraceShot(HitLocation,AdjustedHitLocation,HitNormal,EndTrace,StartTrace,Pawn(Owner) );
	ProcessTraceHit( Other, HitLocation, HitNormal, X,Y,Z);
}

function TraceFire( float Accuracy)
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X, Y, Z;
	local Pawn PawnOwner;
	local Actor Other;

	PawnOwner = Pawn(Owner);
	if ( PawnOwner == none )
		return;

	Owner.MakeNoise( PawnOwner.SoundDampening);
	GetAxes( PawnOwner.ViewRotation, X,Y,Z);
	BufferedDir = PawnOwner.ViewRotation;
	StartTrace = GetStartTrace( ShootFlags, X,Y,Z); 
	AdjustedAim = PawnOwner.AdjustAim( 1000000, StartTrace, AimError, False, False);	
	EndTrace = StartTrace + GetRange( ShootFlags) * vector(AdjustedAim); 

	if ( IsLC() )
		Other = LCChan.LCTraceShot(HitLocation,HitNormal,EndTrace,StartTrace,LCMode);
	else
		Other = PawnOwner.TraceShot(HitLocation, HitNormal, EndTrace, StartTrace);
	ProcessTraceHit(Other, HitLocation, HitNormal, vector(AdjustedAim), Y, Z);
}

simulated function AffectProjectiles( vector X, vector Y, vector Z)
{
	local Projectile P;
	local float NewSpeed;
	local vector NewVelocity;
	local int AffectedCount;
	
	ForEach VisibleCollidingActors( class'Projectile', P, 550, Owner.Location)
		if ( ((P.Physics == PHYS_Projectile) || (P.Physics == PHYS_Falling))
			&& (Normal(P.Location - Owner.Location) Dot X) > 0.9 )
		{
			AffectedCount++;
			
			NewSpeed = VSize( P.Velocity);
			if ( P.Velocity Dot Y > 0 )
				NewVelocity = NewSpeed * Normal( P.Velocity + (750 - VSize(P.Location - Owner.Location)) * Y);
			else	
				NewVelocity = NewSpeed * Normal( P.Velocity - (750 - VSize(P.Location - Owner.Location)) * Y);
			
			if ( Level.NetMode == NM_Client )
			{
				//IMPLEMENT DELAYED AFFECTOR
			}
			else
			{
				P.Speed = NewSpeed;
				P.Velocity = NewVelocity;
			}
		}
		
	if ( AffectedCount > 0 )
		Spawn( class'LCImpactAffector').Setup( Pawn(Owner), X, Y);
}


simulated function ProcessTraceHit( Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local Actor Effect;
	local float Scale;
	local bool bLevelHit;
	local vector StartTrace;

	if ( (Other == None) || (Other == Owner) || (Other == self) || (Owner == None))
		return;

	bLevelHit = (Other == Level) || Other.IsA('Mover');
	StartTrace = GetStartTrace( ShootFlags, X,Y,Z);
	
	if ( ShootFlags == 2 ) //Alt fire
	{
		AffectProjectiles( X,Y,Z);
		Scale = VSize( StartTrace - HitLocation) / GetRange(ShootFlags);
		if ( bLevelHit )
			Owner.TakeDamage( 24.0 * Scale, Pawn(Owner), HitLocation, -40000.0 * X * Scale, MyDamageType);
		else
			Other.TakeDamage( 20 * Scale, Pawn(Owner), HitLocation, 30000.0 * X * Scale, MyDamageType);
	}
	else //Normal fire
	{
		ChargeSize = FMin(ChargeSize, 1.5);
		if ( bLevelHit )
		{
			ChargeSize = FMax(ChargeSize, 1.0);
			if ( VSize( HitLocation - StartTrace) < 80 )
				Effect = Spawn( class'FV_ImpactMark',,, HitLocation+HitNormal, rotator(HitNormal));
			if ( Level.NetMode == NM_Client )
				PlayerHitVel( -69000.0 * ChargeSize * X);
			else
				Owner.TakeDamage( 36.0, Pawn(Owner), HitLocation, -69000.0 * ChargeSize * X, MyDamageType);
		}
		else
			Other.TakeDamage( 60.0 * ChargeSize, Pawn(Owner), HitLocation, 66000.0 * ChargeSize * X, MyDamageType);
	}

	//Common effect spawner
	if ( !bLevelHit && !Other.bIsPawn && !Other.IsA('Carcass') )
		Effect = Spawn(class'FV_SpriteSmokePuff',,,HitLocation+HitNormal*9);
	class'LCStatics'.static.SetHiddenEffect( Effect, Owner, LCChan);
}

simulated function PlayerHitVel( vector Momentum)
{
	local ECM_ImpactPush Push;

	if (Owner.Physics == PHYS_Walking)
		Momentum.Z = FMax(Momentum.Z, 0.4 * VSize(Momentum));
	Momentum = Momentum * 0.6 / Owner.Mass;

	Push = Spawn( class'ECM_ImpactPush');
	if ( Push != None )
		Push.SetupPush( Momentum);
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
	Class'LCStatics'.static.SetSwitchPriority( Other, self, 'ImpactHammer');
}
simulated function float GetRange( out int ExtraFlags)
{
	switch ( ExtraFlags )
	{
		case 0:  return 120; //Fire
		case 1:  return 60;  //Auto Fire
		case 2:  return 180; //Alt Fire
		default: return 0;
	}
}
simulated function vector GetStartTrace( out int ExtraFlags, vector X, vector Y, vector Z)
{
	local vector StartTrace;
	
	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.Y * Y + FireOffset.Z * Z;
	if ( ExtraFlags == 1 || ExtraFlags == 2 )
		StartTrace += FireOffset.X * X;
	return StartTrace;
}
simulated function bool IsLC()
{
	return (LCChan != none) && LCChan.bUseLC && (LCChan.Owner == Owner);
}
simulated function float GetAimError()
{
	return 0;
}
simulated function bool HandleLCFire( bool bFire, bool bAltFire)
{
	return true; //Don't let LCChan hitscan fire
}

