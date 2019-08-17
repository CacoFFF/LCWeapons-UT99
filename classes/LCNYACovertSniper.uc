//********************************
// NYACovertSniper, adapted to LC
//********************************

class LCNYACovertSniper expands LCSniperRifle;

var bool bZoom;

simulated function ModifyFireRate()
{
	local bool bFastFire;
	
	bFastFire = (Owner.Physics != PHYS_Falling && Owner.Physics != PHYS_Swimming && Pawn(Owner).BaseEyeHeight <= 0) || Owner.Velocity == vect(0,0,0);
	if ( bFastFire )
	{
		FireAnimRate = 5;
		ffAimError = 0;
	}
	else
	{
		FireAnimRate = default.FireAnimRate;
		if ( FiringAnimation() )
			ffAimError = default.ffAimError;
		else
			ffAimError = 1.6;
	}
}

simulated function PostRender( canvas Canvas )
{
	local PlayerPawn P;
	local float Scale;

	Super(TournamentWeapon).PostRender(Canvas);
	P = PlayerPawn(Owner);
	if ( (P != None) && (P.DesiredFOV != P.DefaultFOV) )
	{
		bOwnsCrossHair = true;

		if ( Level.bHighDetailMode )
			Canvas.Style = ERenderStyle.STY_Translucent;
		else
			Canvas.Style = ERenderStyle.STY_Normal;

		// Square
		Canvas.SetPos( 3*Canvas.ClipX/7, 3*Canvas.ClipY/7 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/7, Canvas.ClipY/7, 0, 0, 256, 193 );

		// Top Line
		Canvas.SetPos( 200*Canvas.ClipX/401, Canvas.ClipY/229*(90-P.DesiredFOV)+0.6*Canvas.ClipY/28 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/401, Canvas.ClipY/28, 0, 20, 3, 10 );

		// Bottom Line
		Canvas.SetPos( 200*Canvas.ClipX/401, 15.35*Canvas.ClipY/28 + Canvas.ClipY/229*P.DesiredFOV );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/401, Canvas.ClipY/28, 0, 20, 3, 10 );

		// Left Line
		Canvas.SetPos( Canvas.ClipX/229*(90-P.DesiredFOV)+0.6*Canvas.ClipX/28, 200*Canvas.ClipY/401 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/28, Canvas.ClipY/401, 10, 0, 10, 3 );

		// Right Line
		Canvas.SetPos( 15.35*Canvas.ClipX/28 + Canvas.ClipX/229*P.DesiredFOV, 200*Canvas.ClipY/401 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/28, Canvas.ClipY/401, 10, 0, 10, 3 );

		// Dot
	//	Canvas.SetPos( (9*Canvas.ClipX/19) + (Canvas.ClipX/P.DesiredFOV/6), (9*Canvas.ClipY/19) + (Canvas.ClipY/P.DesiredFOV/6) );
	//	Canvas.DrawTile( Crosshair,
	//		(Canvas.ClipX/19) - (Canvas.ClipX/P.DesiredFOV/3), (Canvas.ClipY/19) - (Canvas.ClipY/P.DesiredFOV/3), 0, 202, 53, 53 );
		Canvas.SetPos( 199.5*Canvas.ClipX/401, 199.5*Canvas.ClipY/401 );
		Canvas.DrawTile( Crosshair, 2*Canvas.ClipX/401, 2*Canvas.ClipY/401, 0, 202, 53, 53 );

		// Top Gradient
		Canvas.SetPos( 200*Canvas.ClipX/401, 4*Canvas.ClipY/9 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/401, Canvas.ClipY/1360*(90-P.DesiredFOV), 129, 197, 3, 54 );

		// Left Gradient
		Canvas.SetPos( 4*Canvas.ClipX/9, 200*Canvas.ClipY/401 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/1360*(90-P.DesiredFOV), Canvas.ClipY/401, 69, 200, 54, 3 );

		//Bottom Gradient
		Canvas.SetPos( 200*Canvas.ClipX/401, 5*Canvas.ClipY/9 - Canvas.ClipY/1360*(90-P.DesiredFOV) );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/401, Canvas.ClipY/1360*(90-P.DesiredFOV), 144, 199, 3, 54 );

		//Right Gradient
		Canvas.SetPos( 5*Canvas.ClipX/9 - Canvas.ClipX/1360*(90-P.DesiredFOV), 200*Canvas.ClipY/401 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/1360*(90-P.DesiredFOV), Canvas.ClipY/401, 163, 199, 54, 3 );

		// Magnification Display
		Canvas.SetPos( 202*Canvas.ClipX/401, 4*Canvas.ClipY/7 + Canvas.ClipY/401 );
		Canvas.Font = Font'Botpack.WhiteFont';
		Canvas.DrawColor.R = 0;
		Canvas.DrawColor.G = 255;
		Canvas.DrawColor.B = 0;
		Scale = P.DefaultFOV/P.DesiredFOV;
		Canvas.DrawText("{NYA}MikeyRifle x"$int(Scale)$"."$int(10 * Scale - 10 * int(Scale)));
	}
	else
		bOwnsCrossHair = false;
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
			if ( PlayerPawn(Owner).DesiredFOV > 5 )
				PlayerPawn(Owner).DesiredFOV -= PlayerPawn(Owner).DesiredFOV*DeltaTime*3.4;

			if ( PlayerPawn(Owner).DesiredFOV <=5 )
			{
				PlayerPawn(Owner).DesiredFOV = 5;
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
    ffAimError=20
    DeathMessage="%k sent %o to an early grave"
    ItemName=NYACovertSniper
    PickupMessage="You picked up a {NYA}Covert Sniper Rifle!"
    PickupAmmoCount=600
}
