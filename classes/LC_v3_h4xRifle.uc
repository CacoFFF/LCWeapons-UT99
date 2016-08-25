//********************************
// h4xRifle, adapted to LC
//********************************

class LC_v3_h4xRifle expands LCSniperRifle;

var bool bFastFire;
var bool bGraphicsInitialized;
var bool bZoom;

simulated event Spawned()
{
	if ( !bGraphicsInitialized )
		InitGraphics();
}

simulated function InitGraphics()
{
	local class<TournamentWeapon> OrgClass;

	default.bGraphicsInitialized = true;
	OrgClass = class<TournamentWeapon>( DynamicLoadObject("h4xRiflev3.h4x_Rifle",class'class') );
	default.FireSound = OrgClass.default.FireSound;
	FireSound = default.FireSound;
	default.AmmoName = OrgClass.default.AmmoName;
	AmmoName = default.AmmoName;
}

simulated function CheckMove()
{
	bFastFire = (Owner.Physics != PHYS_Falling && Owner.Physics != PHYS_Swimming && Pawn(Owner).BaseEyeHeight <= 0) || Owner.Velocity == vect(0,0,0);
	if ( bFastFire )
		ffRefireTimer = default.ffRefireTimer / 9.8;
	else
		ffRefireTimer = default.ffRefireTimer;
}

simulated function PlayFiring()
{
	if ( Level.NetMode == NM_Client )
	{
		CheckMove();
		ffAimError = default.ffAimError;
	}

	PlayOwnedSound(FireSound, SLOT_None, Pawn(Owner).SoundDampening*3.0);

	if ( bFastFire )	PlayAnim(FireAnims[Rand(5)], 3 + 3 * FireAdjust, 0.05);
	else			PlayAnim(FireAnims[Rand(5)], 0.3 + 0.3 * FireAdjust, 0.05);

	if ( (PlayerPawn(Owner) != None) && (PlayerPawn(Owner).DesiredFOV == PlayerPawn(Owner).DefaultFOV) )
		bMuzzleFlash++;
	if ( IsLC() && (Level.NetMode == NM_Client) )
		LCChan.bDelayedFire = true;
}

function TraceFire( float Accuracy )
{
	if ( bFastFire )
		Super.TraceFire(0);
	else
		Super.TraceFire( ffAimError);
}

simulated event KillCredit( actor Other)
{
	if ( XC_CompensatorChannel(Other) != none )
	{
		LCChan = XC_CompensatorChannel(Other);
		if ( LCChan.bDelayedFire )
		{
			LCChan.bDelayedFire = false;
			if ( bFastFire )
				ffTraceFire();
			else
				ffTraceFire(ffAimError);
		}
	}
}

event Tick( float DeltaTime)
{
	if ( Owner != none && Pawn(Owner).Weapon == self )
		CheckMove();
}

state NormalFire
{
Begin:
	FlashCount++;
	Sleep(0.2); //This time is the window to reset aim error
	ffAimError = default.ffAimError; //Should be 50
}

state Idle
{
	event BeginState()
	{
		ffAimError = default.ffAimError;
	}
Begin:
	bPointing=False;
	if ( AmmoType.AmmoAmount<=0 )
		Pawn(Owner).SwitchToBestWeapon();  //Goto Weapon that has Ammo
	if ( Pawn(Owner).bFire!=0 ) Fire(0.0);
	Disable('AnimEnd');
	PlayIdleAnim();
}

simulated function PostRender( canvas Canvas )
{
	Super(TournamentWeapon).PostRender(Canvas);
}


///////////////////////////////////////////////////////
state Zooming
{
	simulated function Tick(float DeltaTime)
	{
		if ( Pawn(Owner).bAltFire == 0 )
		{
			bZoom = false;
			SetTimer(0.0,False);
			GoToState('Idle');
		}
		else if ( bZoom )
		{
			if ( PlayerPawn(Owner).DesiredFOV > 3 )
				PlayerPawn(Owner).DesiredFOV -= PlayerPawn(Owner).DesiredFOV*DeltaTime*4;

			if ( PlayerPawn(Owner).DesiredFOV <=3 )
			{
				PlayerPawn(Owner).DesiredFOV = 3;
				bZoom = false;
				SetTimer(0.0,False);
				GoToState('Idle');
			}
		}
	}

	simulated function BeginState()
	{
		if ( Owner.IsA('PlayerPawn') )
		{
			if ( PlayerPawn(Owner).DesiredFOV == PlayerPawn(Owner).DefaultFOV )
			{
				bZoom = true;
				SetTimer(0.2,True);
			}
			else if ( bZoom == false )
			{
				PlayerPawn(Owner).DesiredFOV = PlayerPawn(Owner).DefaultFOV;
				Pawn(Owner).bAltFire = 0;
			}
		}
		else
		{
			Pawn(Owner).bFire = 1;
			Pawn(Owner).bAltFire = 0;
			Global.Fire(0);
		}
	}
}

defaultproperties
{
    ffAimError=6.4
    DeathMessage="%k fucked %o up"
    ItemName="h4x Sniper Rifle"
    PickupMessage="You Picked Up A h4x Sniper Rifle."
    PickupAmmoCount=500
	ffRefireTimer=0.778
	SelectSound=None
	HeadshotDamage=100000
}
