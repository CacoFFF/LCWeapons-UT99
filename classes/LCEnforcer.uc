//=============================================================================
// Enforcer
// * Revised by 7DS'Lust
// * Lag Compensation with random seed generation by Higor
// Meh, no random seed for now
//=============================================================================
class LCEnforcer extends Enforcer;

var float AccuracyScale;

var XC_CompensatorChannel LCChan;
var int LCMode;
var bool bBulletNow;

replication
{
	reliable if ( Role == ROLE_Authority )
		FixOffset; //Needed for Slave enforcer
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


simulated function PlayFiring()
{
	if ( Level.NetMode == NM_DedicatedServer ) //HACK: ENSURE SOUND IS PLAYED AT RIGHT POSITION
		SetLocation(Owner.Location);
	Super.PlayFiring();
	if ( IsLC() && (Level.NetMode == NM_Client) )
	{
		TraceFire( 0.2);
		LCChan.ClientFire(); //Force player to send positional update
	}
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
		TraceFire( AltAccuracy);
	}
}

simulated function TraceFire( float Accuracy)
{
	local vector RealOffset;
    local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local Actor Other;
	local Pawn PawnOwner;
	local int ExtraFlags;

	PawnOwner = Pawn(Owner);
	if ( PawnOwner == none )
		return;

	RealOffset = FireOffset;
	FireOffset *= 0.35;
	if ( (SlaveEnforcer != None) || bIsSlave )
		Accuracy = FClamp(3*Accuracy,0.75,3);
	else if ( Owner.IsA('Bot') && !Bot(Owner).bNovice )
		Accuracy = FMax(Accuracy, 0.45);
    Accuracy *= AccuracyScale;

	Owner.MakeNoise(PawnOwner.SoundDampening);
	GetAxes( class'LCStatics'.static.PlayerRot(PawnOwner), X,Y,Z);
	StartTrace = GetStartTrace( ExtraFlags, X,Y,Z); 
	AdjustedAim = PawnOwner.AdjustAim(1000000, StartTrace, 2*AimError, False, False);	
	X = vector(AdjustedAim);
	EndTrace = StartTrace
		+ X * GetRange( ExtraFlags)
		+ Accuracy * (FRand() - 0.5 ) * Y * 1000
		+ Accuracy * (FRand() - 0.5 ) * Z * 1000;
	if ( IsLC() )
		Other = LCChan.LCTraceShot(HitLocation,HitNormal,EndTrace,StartTrace,LCMode);
	else
		Other = PawnOwner.TraceShot(HitLocation,HitNormal,EndTrace,StartTrace);
	ProcessTraceHit(Other, HitLocation, HitNormal, X,Y,Z);
	FireOffset = RealOffset;
}

//Unified tracer LC v2
simulated function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local UT_Shellcase s;
	local Actor HitEffect;

	s = Spawn( class'FV_ShellCase',,, Owner.Location + CalcDrawOffset() + 20 * X + FireOffset.Y * Y + Z);
	if ( s != None )
	{
		s.Eject(((FRand()*0.3+0.4)*X + (FRand()*0.2+0.2)*Y + (FRand()*0.3+1.0) * Z)*160);              
		class'LCStatics'.static.SetHiddenEffect( s, Owner, LCChan);
	}
	if (Other == Level) 
	{
		if ( bIsSlave || (SlaveEnforcer != None) )
			HitEffect = Spawn( class'FV_LightWallHitEffect',,, HitLocation+HitNormal, rotator(HitNormal));
		else
			HitEffect = Spawn( class'FV_WallHit',,, HitLocation+HitNormal, rotator(HitNormal));
		class'LCStatics'.static.SetHiddenEffect( HitEffect, Owner, LCChan);
	}
	else if ((Other != self) && (Other != Owner) && (Other != None) ) 
	{
		if ( FRand() < 0.2 )
			X *= 5;
		Other.TakeDamage(HitDamage, Pawn(Owner), HitLocation, 3000.0*X, MyDamageType);
		if ( !Other.bIsPawn && !Other.IsA('Carcass') )
		{
			HitEffect = Spawn( class'FV_SpriteSmokePuff',,, HitLocation+HitNormal*9);
			class'LCStatics'.static.SetHiddenEffect( HitEffect, Owner, LCChan);
		}
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
simulated function float GetRange( out int ExtraFlags)
{
	return 10000;
}
simulated function vector GetStartTrace( out int ExtraFlags, vector X, vector Y, vector Z)
{
	return Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
}
simulated function bool IsLC()
{
	return (LCChan != none) && LCChan.bUseLC && (LCChan.Owner == Owner);
}
simulated function float GetAimError()
{
	return 0.2;
}
simulated function bool HandleLCFire( bool bFire, bool bAltFire)
{
	return false; //Don't let LCChan hitscan fire
}
function SetHand( float hand)
{
	Super.SetHand(hand);
	FixOffset(FireOffset.Y);
}
simulated function FixOffset( float Y)
{
	FireOffset.Y = Y;
}


defaultproperties
{
     AccuracyScale=1.000000
     hitdamage=17
}
