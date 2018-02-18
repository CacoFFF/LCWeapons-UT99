class LCImpactHammer expands ImpactHammer;

var XC_CompensatorChannel LCChan;
var XC_ImpactEvents ImpactEvents;
var bool bFireRelease;
var rotator BufferedDir;

replication
{
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
	Class'LCStatics'.static.SetSwitchPriority( Other, self, 'ImpactHammer');
}

////////////////////////////////
//All of the unlagged code here
simulated event KillCredit( actor Other)
{
	if ( XC_CompensatorChannel(Other) != none )
		LCChan = XC_CompensatorChannel(Other);
	if ( (Level.NetMode == NM_Client) && (ImpactEvents == none) )
		ForEach AllActors (class'XC_ImpactEvents', ImpactEvents)
			break;
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






state Firing
{
	function AltFire(float F) 
	{
	}

	function Tick( float DeltaTime )
	{
		local PlayerPawn P;
		local Rotator EnemyRot;
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
			{
				LCChan.LCActor.ffUnlagPositions( LCChan.LCComp, StartTrace, rotator(EndTrace-StartTrace) );
				HitActor = class'LCStatics'.static.LCTrace( HitLocation, HitNormal, EndTrace, StartTrace, P);
				LCChan.LCActor.ffRevertPositions();
			}
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
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X, Y, Z;
	local actor Other;

	if ( Owner == none )
		return;
	GetAxes(Pawn(owner).ViewRotation, X, Y, Z);
	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.Y * Y + FireOffset.Z * Z; 
	EndTrace = StartTrace + 120.0 * X; 

	Other = Class'LCStatics'.static.ffTraceShot(HitLocation,HitNormal,EndTrace,StartTrace,Pawn(Owner) );
	ProcessTraceHit(Other, HitLocation, HitNormal, X, Y, Z);
}

function TraceFire(float accuracy)
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X, Y, Z;
	local Pawn PawnOwner;
	local Actor Other;

	PawnOwner = Pawn(Owner);
	if ( PawnOwner == none )
		return;
	Owner.MakeNoise(PawnOwner.SoundDampening);
	GetAxes(PawnOwner.ViewRotation, X, Y, Z);
	BufferedDir = PawnOwner.ViewRotation;
	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.Y * Y + FireOffset.Z * Z; 
	AdjustedAim = PawnOwner.AdjustAim(1000000, StartTrace, AimError, False, False);	
	EndTrace = StartTrace + 120.0 * vector(AdjustedAim); 

	if ( IsLC() )
	{
		LCChan.LCActor.ffUnlagPositions( LCChan.LCComp, StartTrace, rotator(EndTrace-StartTrace) );
		Other = class'LCStatics'.static.LCTrace( HitLocation, HitNormal, EndTrace, StartTrace, PawnOwner);
		LCChan.LCActor.ffRevertPositions();
	}
	else
		Other = PawnOwner.TraceShot(HitLocation, HitNormal, EndTrace, StartTrace);
	ProcessTraceHit(Other, HitLocation, HitNormal, vector(AdjustedAim), Y, Z);
}


simulated function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local bool bSpecialEff;

	if ( (Other == None) || (Other == Owner) || (Other == self) || (Owner == None))
		return;

	bSpecialEff = IsLC() && (Level.NetMode != NM_Client); //Spawn for LC clients

	ChargeSize = FMin(ChargeSize, 1.5);
	if ( (Other == Level) || Other.IsA('Mover') )
	{
		ChargeSize = FMax(ChargeSize, 1.0);
		if ( VSize(HitLocation - Owner.Location) < 80 )
		{
			if ( bSpecialEff )	Spawn(class'ImpactMark',,, HitLocation+HitNormal, Rotator(HitNormal));
			else				Spawn(class'LCImpactMark',Owner,, HitLocation+HitNormal, Rotator(HitNormal));
		}
		if ( Level.NetMode == NM_Client )
			PlayerHitVel( -69000.0 * ChargeSize * X);
		else
			Owner.TakeDamage(36.0, Pawn(Owner), HitLocation, -69000.0 * ChargeSize * X, MyDamageType);
	}
	if ( Other != Level )
	{
		if ( Other.bIsPawn && (VSize(HitLocation - Owner.Location) > 90) )
			return;
		Other.TakeDamage(60.0 * ChargeSize, Pawn(Owner), HitLocation, 66000.0 * ChargeSize * X, MyDamageType);
		if ( !Other.bIsPawn && !Other.IsA('Carcass') )
			spawn(class'UT_SpriteSmokePuff',,,HitLocation+HitNormal*9);
	}
}

simulated function PlayerHitVel( vector Momentum)
{
	if ( ImpactEvents == none )
		ImpactEvents = Spawn(class'XC_ImpactEvents');

	if (Owner.Physics == PHYS_Walking)
		momentum.Z = FMax(momentum.Z, 0.4 * VSize(momentum));
	momentum = momentum * 0.6 / Owner.Mass;

	ImpactEvents.AddNewPush( momentum);
	Owner.Velocity += momentum;
	if ( Owner.Physics == PHYS_Walking )
		Owner.SetPhysics( PHYS_Falling);
}
