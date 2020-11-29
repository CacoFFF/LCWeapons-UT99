//********************************
// NYACovertSniper, adapted to LC
//********************************
class LCChamRifle expands LCSniperRifle;

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
			ffAimError = 0;
	}
}

simulated function PostRender( canvas Canvas )
{
	local PlayerPawn P;
	//local float HudScale;
	local float Scale;
	local float range;
	local vector HitLocation, AdjustedHitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local int ExtraFlags;




	Super(TournamentWeapon).PostRender(Canvas);
	P = PlayerPawn(Owner);
	if ( (P != None) && (P.DesiredFOV != P.DefaultFOV) )
	{
		bOwnsCrossHair = true;

		if ( Level.bHighDetailMode )
			Canvas.Style = ERenderStyle.STY_Normal;
		else
			Canvas.Style = ERenderStyle.STY_Normal;

		Canvas.SetPos( 3*Canvas.ClipX/7, 3*Canvas.ClipY/7 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/7, Canvas.ClipY/7, 0, 0, 256, 193 );
		Canvas.SetPos( 200*Canvas.ClipX/401, Canvas.ClipY/229*(90-P.DesiredFOV)+0.6*Canvas.ClipY/28 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/401, Canvas.ClipY/28, 0, 20, 3, 10 );
		Canvas.SetPos( 200*Canvas.ClipX/401, 15.35*Canvas.ClipY/28 + Canvas.ClipY/229*P.DesiredFOV );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/401, Canvas.ClipY/28, 0, 20, 3, 10 );
		Canvas.SetPos( Canvas.ClipX/229*(90-P.DesiredFOV)+0.6*Canvas.ClipX/28, 200*Canvas.ClipY/401 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/28, Canvas.ClipY/401, 10, 0, 10, 3 );
		Canvas.SetPos( 15.35*Canvas.ClipX/28 + Canvas.ClipX/229*P.DesiredFOV, 200*Canvas.ClipY/401 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/28, Canvas.ClipY/401, 10, 0, 10, 3 );
		Canvas.SetPos( 199.5*Canvas.ClipX/401, 199.5*Canvas.ClipY/401 );
		Canvas.DrawTile( Crosshair, 2*Canvas.ClipX/401, 2*Canvas.ClipY/401, 0, 202, 53, 53 );
		Canvas.SetPos( 200*Canvas.ClipX/401, 4*Canvas.ClipY/9 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/401, Canvas.ClipY/1360*(90-P.DesiredFOV), 129, 197, 3, 54 );
		Canvas.SetPos( 4*Canvas.ClipX/9, 200*Canvas.ClipY/401 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/1360*(90-P.DesiredFOV), Canvas.ClipY/401, 69, 200, 54, 3 );
		Canvas.SetPos( 200*Canvas.ClipX/401, 5*Canvas.ClipY/9 - Canvas.ClipY/1360*(90-P.DesiredFOV) );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/401, Canvas.ClipY/1360*(90-P.DesiredFOV), 144, 199, 3, 54 );
		Canvas.SetPos( 5*Canvas.ClipX/9 - Canvas.ClipX/1360*(90-P.DesiredFOV), 200*Canvas.ClipY/401 );
		Canvas.DrawTile( Crosshair, Canvas.ClipX/1360*(90-P.DesiredFOV), Canvas.ClipY/401, 163, 199, 54, 3 );

		GetAxes( P.ViewRotation,X,Y,Z);
		StartTrace = GetStartTrace( ExtraFlags, X,Y,Z);
		EndTrace = StartTrace + X * GetRange( ExtraFlags);
		class'LCStatics'.static.ClientTraceShot( HitLocation, AdjustedHitLocation, HitNormal, EndTrace, StartTrace, P);
		range = VSize( StartTrace-HitLocation) / 48 - 0.25;

         // Range Display
		Canvas.SetPos( 202*Canvas.ClipX/401-75, 4*Canvas.ClipY/7 + Canvas.ClipY/401 );
		Canvas.Font = Font'Botpack.WhiteFont';
		Canvas.DrawColor.R = 255;
		Canvas.DrawColor.G = 0;
		Canvas.DrawColor.B = 0;
        Canvas.DrawText( "ZSZ"$int(range)$"."$int(10 * range -10 * int(range))$"");

		// Magnification Display
		Canvas.SetPos( 202*Canvas.ClipX/401, 4*Canvas.ClipY/7 + Canvas.ClipY/401 );
		Canvas.Font = Font'Botpack.WhiteFont';
		Canvas.DrawColor.R = 255;
		Canvas.DrawColor.G = 0;
		Canvas.DrawColor.B = 0;
		Scale = P.DefaultFOV/P.DesiredFOV;
		Canvas.DrawText("ZOOM x"$int(Scale)$"."$int(10 * Scale - 10 * int(Scale)));
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
			if ( (PlayerPawn(Owner) != None) && PlayerPawn(Owner).Player.IsA('ViewPort') )
				PlayerPawn(Owner).StopZoom();
			PlayOwnedSound(Misc2Sound, SLOT_Misc, 1.0*Pawn(Owner).SoundDampening,,, Level.TimeDilation-0.1);
			bZoom = false;
			SetTimer(0.0,False);
			GoToState('Idle');
		}
		else if ( bZoom )
		{
			if ( PlayerPawn(Owner).DesiredFOV > 3.0 )
				PlayerPawn(Owner).DesiredFOV -= PlayerPawn(Owner).DesiredFOV*DeltaTime*3.4;
			if ( PlayerPawn(Owner).DesiredFOV <=3.0 )
			{
				PlayerPawn(Owner).DesiredFOV = 3.0;
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
			PlayOwnedSound(Misc1Sound, SLOT_Misc, 1.0*Pawn(Owner).SoundDampening,,, Level.TimeDilation-0.1);
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


simulated function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local Actor HitEffect;
	local bool bSpecialEff;

	bSpecialEff = IsLC() && (Level.NetMode != NM_Client); //Spawn for LC clients

	if (Other == Level) 
	{
		HitEffect = Spawn( class'FV_HeavyWallHitEffect',,, HitLocation+HitNormal, Rotator(HitNormal));
		if ( LCChan != None )
			LCChan.SetHiddenEffect( HitEffect, Owner);
	}
	else if ( (Other != self) && (Other != Owner) && (Other != None) )
	{
		if ( Other.bIsPawn )
		{
			if ( true ) //Handle this with extreme care
			{
				Other.PlaySound( Misc3Sound,, 4.0,,100);
				Other.PlaySound(sound 'UnrealI.Razorjack.BladeThunk',, 4.0,,100);
			}
			PlayOwnedSound( Misc3Sound,, 4.0,,10);
		}
		if ( Level.NetMode != NM_Client )
		{
			if ( Other.bIsPawn && (HitLocation.Z - Other.Location.Z > 0.62 * Other.CollisionHeight)
			&& (instigator.IsA('PlayerPawn') || (instigator.IsA('Bot') && !Bot(Instigator).bNovice))
			&& ((Owner.Physics != PHYS_Falling && Owner.Physics != PHYS_Swimming && Pawn(Owner).bDuck != 0)
			|| Owner.Velocity == 0 * Owner.Velocity) )
			{
				if ( Pawn(Other).Health > 0 )
				{
					Other.TakeDamage(100000, Pawn(Owner), HitLocation, 35000 * X, AltDamageType);
	
					if ( Pawn(Other).Health < 1
					    && (!Level.Game.bTeamGame || Pawn(Owner).PlayerReplicationInfo.Team != Pawn(Other).PlayerReplicationInfo.Team) )
						AmmoType.AddAmmo(3);
				}
				else
					Other.TakeDamage(100000, Pawn(Owner), HitLocation, 35000 * X, AltDamageType);
			}
			else
				Other.TakeDamage(45,  Pawn(Owner), HitLocation, 30000.0*X, MyDamageType);
		}
		if ( !Other.bIsPawn && !Other.IsA('Carcass') )
		{
			HitEffect = Spawn( class'FV_SpriteSmokePuff',,, HitLocation+HitNormal*9);
			if ( LCChan != None )
				LCChan.SetHiddenEffect( HitEffect, Owner);
		}
	}
}


defaultproperties
{
    ffAimError=16
	FireAnimRate=0.6
    DeathMessage="%k FuckedUp %o with the sexy Rifle."
    ItemName=ChamRifle
    PickupMessage="You picked up the Rifle!"
    PickupAmmoCount=600
}
