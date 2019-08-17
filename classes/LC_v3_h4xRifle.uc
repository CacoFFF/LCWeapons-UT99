//********************************
// h4xRifle, adapted to LC
//********************************

class LC_v3_h4xRifle expands LCSniperRifle;

var bool bZoom;


simulated function ModifyFireRate()
{
	local bool bFastFire;
	
	bFastFire = (Owner.Physics != PHYS_Falling && Owner.Physics != PHYS_Swimming && Pawn(Owner).BaseEyeHeight <= 0) || Owner.Velocity == vect(0,0,0);
	if ( bFastFire )
	{
		FireAnimRate = 6;
		ffAimError = 0;
	}
	else
	{
		FireAnimRate = default.FireAnimRate;
		ffAimError = default.ffAimError;
	}
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
	FireAnimRate=0.6
    DeathMessage="%k fucked %o up"
    ItemName="h4x Sniper Rifle"
    PickupMessage="You Picked Up A h4x Sniper Rifle."
    PickupAmmoCount=500
	ffRefireTimer=0.778
	SelectSound=None
	HeadshotDamage=100000
}
