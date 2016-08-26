//=============================================================================
// Enforcer
// * Revised by 7DS'Lust
// * Lag Compensation with random seed generation by Higor
// Meh, no random seed for now
//=============================================================================
class LCEnforcer extends Enforcer;

var float AccuracyScale;

var XC_CompensatorChannel LCChan;
var bool bBulletNow;

//0 is normal effect, 1 is hidden effect
var class<UT_Shellcase> ShellCaseClass[2];
var class<Actor> SingleWallHitClass[2]; //For Single enforcer
var class<Actor> DoubleWallHitClass[2]; //For Double enforcer
var class<Actor> SmokeHitClass[2];

replication
{
	reliable if ( Role == ROLE_Authority )
		FixOffset;
}

function inventory SpawnCopy( pawn Other )
{
	return class'LCStatics'.static.SpawnCopy(Other,self);
}
function GiveTo( pawn Other )
{
	Class'LCStatics'.static.GiveTo(Other,self);
}

function SetSwitchPriority(pawn Other)
{
	local int i;

	Class'LCStatics'.static.SetSwitchPriority( Other, self, 'Enforcer');
	if ( PlayerPawn(Other) != None )
	{
		for ( i=0; i<50; i++)
			if ( PlayerPawn(Other).WeaponPriority[i] == 'doubleenforcer' )
			{
				DoubleSwitchPriority = i;
				return;
			}
	}	
}

////////////////////////////////
//All of the unlagged code here
simulated event KillCredit( actor Other)
{
	 if ( XC_CompensatorChannel(Other) != none )
	{
		LCChan = XC_CompensatorChannel(Other);
		if ( LCEnforcer(SlaveEnforcer) != none )
			LCEnforcer(SlaveEnforcer).LCChan = LCChan;
	}
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

simulated function PlayFiring()
{
	Super.PlayFiring();
	if ( IsLC() && (Level.NetMode == NM_Client) )
		SimTraceFire( 0.2);
}

simulated function PlayRepeatFiring()
{
	Super.PlayRepeatFiring();
	if ( IsLC() && (Level.NetMode == NM_Client) )
	{
		if ( bFirstFire )
			AltAccuracy = 0.4;
		else
			AltAccuracy = fMin(AltAccuracy + 0.5, 3);
		SimTraceFire( AltAccuracy);
	}
}

simulated function SimTraceFire(float Accuracy)
{
	local vector RealOffset;
    local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local actor Other, aActor;
	local Pawn PawnOwner;
	local private rotator ffRot;

	PawnOwner = Pawn(Owner);
	if ( PawnOwner == none )	return;

	RealOffset = FireOffset;
	FireOffset *= 0.35;
	if ( (SlaveEnforcer != None) || bIsSlave )		Accuracy = FClamp(3*Accuracy,0.75,3);
	else if ( Owner.IsA('Bot') && !Bot(Owner).bNovice )		Accuracy = FMax(Accuracy, 0.45);
	Accuracy *= AccuracyScale;

	ffRot = class'LCStatics'.static.PlayerRot( PawnOwner);
	
	GetAxes(ffRot,X,Y,Z);
	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z; 
	EndTrace = StartTrace + Accuracy * (FRand() - 0.5 )* Y * 1000   + Accuracy * (FRand() - 0.5 ) * Z * 1000;
	EndTrace += (10000 * X); 
	Other = Class'LCStatics'.static.ffTraceShot(HitLocation,HitNormal,EndTrace,StartTrace, PawnOwner);
	ProcessTraceHit(Other, HitLocation, HitNormal, X,Y,Z);
	FireOffset = RealOffset;
}

function TraceFire(float Accuracy)
{
	local vector RealOffset;
    local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local actor Other, aActor;
	local Pawn PawnOwner;

	PawnOwner = Pawn(Owner);
	if ( PawnOwner == none )	return;

	RealOffset = FireOffset;
	FireOffset *= 0.35;
	if ( (SlaveEnforcer != None) || bIsSlave )
		Accuracy = FClamp(3*Accuracy,0.75,3);
	else if ( Owner.IsA('Bot') && !Bot(Owner).bNovice )
		Accuracy = FMax(Accuracy, 0.45);
    Accuracy *= AccuracyScale;

	Owner.MakeNoise(PawnOwner.SoundDampening);
	GetAxes(PawnOwner.ViewRotation,X,Y,Z);
	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z; 
	AdjustedAim = PawnOwner.AdjustAim(1000000, StartTrace, 2*AimError, False, False);	
	EndTrace = StartTrace + Accuracy * (FRand() - 0.5 )* Y * 1000   + Accuracy * (FRand() - 0.5 ) * Z * 1000;
	X = vector(AdjustedAim);
	EndTrace += (10000 * X); 
	if ( !IsLC() )
		Other = PawnOwner.TraceShot(HitLocation,HitNormal,EndTrace,StartTrace);
	else
	{
		LCChan.LCActor.ffUnlagPositions( LCChan.LCComp, StartTrace, rotator(EndTrace-StartTrace) );
		ForEach Owner.TraceActors( class'Actor', aActor, HitLocation, HitNormal, EndTrace, StartTrace)
		{
			if ( Class'LCStatics'.static.TraceStopper( aActor) )
			{	Other = aActor;
				break;
			}
			if ( !aActor.bProjTarget && !aActor.bBlockActors )				continue;
			if ( Class'LCStatics'.static.CompensatedType(aActor) )
				continue;
			if ( aActor.bIsPawn && !Pawn(aActor).AdjustHitLocation(HitLocation, EndTrace - StartTrace) )
				continue; //We can't hit this Pawn due to special collision rules
			Other = aActor;
			break;
		}
		Other = Class'LCStatics'.static.CompensatedHitActor( Other, HitLocation);
		LCChan.LCActor.ffRevertPositions();
	}
	ProcessTraceHit(Other, HitLocation, HitNormal, X,Y,Z);
	FireOffset = RealOffset;
}

//Unified tracer LC v2
simulated function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local UT_Shellcase s;
	local int EffIdx;
	local Actor SpawnOwner;
	local bool bIsLC;

	bIsLC = IsLC();
	if ( bIsLC )	SpawnOwner = Owner; //Needs to be hidden from someone
	EffIdx = int(bIsLC && (Level.NetMode != NM_Client) && LCChan.LCActor.bNeedsHiddenEffects);

	s = Spawn( ShellCaseClass[EffIdx], SpawnOwner, '', Owner.Location + CalcDrawOffset() + 20 * X + FireOffset.Y * Y + Z);
	if ( s != None )
	{
		s.Eject(((FRand()*0.3+0.4)*X + (FRand()*0.2+0.2)*Y + (FRand()*0.3+1.0) * Z)*160);              
		s.SetPropertyText("bNotRelevantToOwner",string(bIsLC));
	}
	if (Other == Level) 
	{
		if ( bIsSlave || (SlaveEnforcer != None) )
			Spawn( DoubleWallHitClass[EffIdx], SpawnOwner,, HitLocation+HitNormal, rotator(HitNormal)).SetPropertyText("bNotRelevantToOwner",string(bIsLC));
		else
			Spawn( SingleWallHitClass[EffIdx], SpawnOwner,, HitLocation+HitNormal, rotator(HitNormal)).SetPropertyText("bNotRelevantToOwner",string(bIsLC));
	}
	else if ((Other != self) && (Other != Owner) && (Other != None) ) 
	{
		if ( FRand() < 0.2 )
			X *= 5;
		Other.TakeDamage(HitDamage, Pawn(Owner), HitLocation, 3000.0*X, MyDamageType);
		if ( !Other.bIsPawn && !Other.IsA('Carcass') )
			Spawn( SmokeHitClass[EffIdx], SpawnOwner,,HitLocation+HitNormal*9).SetPropertyText("bNotRelevantToOwner",string(bIsLC));
		else
			Other.PlaySound(Sound 'ChunkHit',, 4.0,,100);

	}		
}

function SetTwoHands()
{
	if ( SlaveEnforcer == None )
		return;

    if ( SlaveEnforcer.IsA('LCEnforcer') )
    {
		SlaveEnforcer.HitDamage = HitDamage;
		LCEnforcer(SlaveEnforcer).AccuracyScale = AccuracyScale;
		LCEnforcer(SlaveEnforcer).LCChan = LCChan;
    }

    Super.SetTwoHands();
}

state ClientFiring
{
	simulated function AnimEnd()
	{
		if ( (Pawn(Owner) == None) || (Ammotype.AmmoAmount <= 0) )
		{
			PlayIdleAnim();
			GotoState('');
		}
		else if ( !bIsSlave && !bCanClientFire )
			GotoState('');
		else if ( Pawn(Owner).bFire != 0 )
			Global.ClientFire(0);
		else if ( Pawn(Owner).bAltFire != 0 )
			Global.ClientAltFire(0);
		else
		{
			PlayIdleAnim();
			GotoState('');
		}
	}
}


state ClientAltFiring
{
	simulated function AnimEnd()
	{
		if ( Pawn(Owner) == None )
			GotoState('');
		else if ( Ammotype.AmmoAmount <= 0 )
		{
			PlayAnim('T2', 0.9, 0.05);	
			GotoState('');
		}
		else if ( !bIsSlave && !bCanClientFire )
			GotoState('');
		else if ( bFirstFire || Pawn(Owner).bAltFire != 0 )
		{
			if ( AnimSequence == 'T2' )
				PlayAltFiring();
			else
			{
				PlayRepeatFiring();
				bFirstFire = false;
			}
		}
		else if ( Pawn(Owner).bFire != 0 )
		{
			if ( AnimSequence != 'T2' )
				PlayAnim('T2', 0.9, 0.05);	
			else
				Global.ClientFire(0);
		}
		else
		{
			if ( AnimSequence != 'T2' )
				PlayAnim('T2', 0.9, 0.05);	
			else
				GotoState('');
		}
	}
}

State ClientActive
{
	simulated function AnimEnd()
	{
		bBringingUp = false;
		if ( !bIsSlave )
		{
			Super.AnimEnd();
			if ( (LCEnforcer(SlaveEnforcer) != none) && (LCEnforcer(SlaveEnforcer).LCChan != LCChan) )
				LCEnforcer(SlaveEnforcer).LCChan = LCChan;
			if ( (SlaveEnforcer != None) && !IsInState('ClientActive') )
			{
				if ( (GetStateName() == 'None') || (GetStateName() == 'LCEnforcer') )
					SlaveEnforcer.GotoState('');
				else
					SlaveEnforcer.GotoState(GetStateName());
			}
		}
	}
}


function bool HandlePickupQuery( inventory Item )
{
	local Pawn P;
	local Inventory Copy;

	if ( (Item.class == class) && (SlaveEnforcer == None) ) 
	{
		P = Pawn(Owner);
		// spawn a double
		Copy = Spawn(class, P);
		Copy.BecomeItem();
		ItemName = DoubleName;
		SlaveEnforcer = Enforcer(Copy);

		SlaveEnforcer.PickupAmmoCount = Enforcer(Item).PickupAmmoCount;
		SlaveEnforcer.AmmoName = AmmoName;
		PickupAmmoCount = SlaveEnforcer.PickupAmmoCount;

		SetTwoHands();
		AIRating = 0.4;
		SlaveEnforcer.SetUpSlave( Pawn(Owner).Weapon == self );
		SlaveEnforcer.SetDisplayProperties(Style, Texture, bUnlit, bMeshEnviromap);
		SetTwoHands();
		P.ReceiveLocalizedMessage( class'PickupMessagePlus', 0, None, None, Self.Class );
		Item.PlaySound(Item.PickupSound);
		if (Level.Game.LocalLog != None)
			Level.Game.LocalLog.LogPickup(Item, Pawn(Owner));
		if (Level.Game.WorldLog != None)
			Level.Game.WorldLog.LogPickup(Item, Pawn(Owner));
		Item.SetRespawn();
		return true;
	}
	return Super(TournamentWeapon).HandlePickupQuery(Item);
}


defaultproperties
{
     AccuracyScale=1.000000
     hitdamage=17
     ShellCaseClass(0)=class'UT_ShellCase'
     ShellCaseClass(1)=class'zp_ShellCase'
     SingleWallHitClass(0)=class'UT_WallHit'
     SingleWallHitClass(1)=class'LCWallHit'
     DoubleWallHitClass(0)=class'UT_LightWallHitEffect'
     DoubleWallHitClass(1)=class'LCLightWallHitEffect'
     SmokeHitClass(0)=class'UT_SpriteSmokePuff'
     SmokeHitClass(1)=class'zp_SpriteSmokePuff'
}
