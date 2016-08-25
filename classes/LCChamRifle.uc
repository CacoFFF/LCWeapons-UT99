//********************************
// NYACovertSniper, adapted to LC
//********************************

class LCChamRifle expands LCSniperRifle;

var bool bFastFire;
var bool bGraphicsInitialized;
var bool bZoom;
var Texture Crosshair;

simulated event Spawned()
{
	if ( !bGraphicsInitialized )
		InitGraphics();
}

simulated function InitGraphics()
{
	local class<TournamentWeapon> OrgClass;
	local int i;

	default.bGraphicsInitialized = true;
	OrgClass = class<TournamentWeapon>( DynamicLoadObject("ChamRifle_v2.ChamV2SniperRifle",class'class') );
	default.FireSound = OrgClass.default.FireSound;
	FireSound = default.FireSound;
	default.SelectSound = OrgClass.default.SelectSound;
	SelectSound = default.SelectSound;
	default.Misc1Sound = OrgClass.default.Misc1Sound;
	Misc1Sound = default.Misc1Sound;
	default.Misc2Sound = OrgClass.default.Misc2Sound;
	Misc2Sound = default.Misc2Sound;
	default.Misc3Sound = OrgClass.default.Misc3Sound;
	Misc3Sound = default.Misc3Sound;
	default.AmmoName = OrgClass.default.AmmoName;
	AmmoName = default.AmmoName;
	default.Crosshair = OrgClass.default.MultiSkins[7];
	Crosshair = default.Crosshair;
	For ( i=0 ; i<5 ; i++ )
	{
		default.MultiSkins[i] = OrgClass.default.MultiSkins[i];
		MultiSkins[i] = default.MultiSkins[i];
	}
	default.MultiSkins[5] = default.MultiSkins[2];
	MultiSkins[5] = default.MultiSkins[5];
}

simulated event RenderOverlays( canvas Canvas )
{
	MultiSkins[2] = MultiSkins[4];
	Super.RenderOverlays(Canvas);
	MultiSkins[2] = MultiSkins[5];
}

simulated function CheckMove()
{
	bFastFire = (Owner.Physics != PHYS_Falling && Owner.Physics != PHYS_Swimming && Pawn(Owner).BaseEyeHeight <= 0) || Owner.Velocity == vect(0,0,0);
	if ( bFastFire )
		ffRefireTimer = default.ffRefireTimer / 5.9;
	else
		ffRefireTimer = default.ffRefireTimer * 1.66;
}

simulated function PlayFiring()
{
	if ( Level.NetMode == NM_Client )
	{
		CheckMove();
		if ( IsInState('ClientFiring') )
			ffAimError = default.ffAimError;
		else
			ffAimError = 0;
	}

	PlayOwnedSound(FireSound, SLOT_None, Pawn(Owner).SoundDampening*3.0);

	if ( bFastFire )	PlayAnim(FireAnims[4], 3 + 3 * FireAdjust, 0.05);
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
		ffAimError = 0;
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
   local PlayerPawn P;
   //local float HudScale;
	local float Scale;
        local float Xlength;
        local float range;
        local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
        local actor Other;
        local float radpitch;




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

       	XLength=255.0;
		GetAxes(Pawn(owner).ViewRotation,X,Y,Z);
		if ((Pawn(Owner).ViewRotation.Pitch >= 0) && (Pawn(Owner).ViewRotation.Pitch <= 18000))
			radpitch = float(Pawn(Owner).ViewRotation.Pitch) / float(182) * (Pi/float(180));
		else
			radpitch = float(Pawn(Owner).ViewRotation.Pitch - 65535) / float(182) * (Pi/float(180));

		StartTrace = Owner.Location + Pawn(Owner).EyeHeight*Z*cos(radpitch);
	    	AdjustedAim = pawn(owner).AdjustAim(1000000, StartTrace, 2.75*AimError, False, False);
		EndTrace = StartTrace +(20000 * vector(AdjustedAim));
		Other = Pawn(Owner).TraceShot(HitLocation,HitNormal,EndTrace,StartTrace);
		range = Vsize(StartTrace-HitLocation)/48-0.25;

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
	local bool bSpecialEff;

	bSpecialEff = IsLC() && (Level.NetMode != NM_Client); //Spawn for LC clients

	if (Other == Level) 
	{
		if ( bSpecialEff )		Spawn(class'zp_HeavyWallHitEffect',Owner,, HitLocation+HitNormal, Rotator(HitNormal));
		else		Spawn(class'UT_HeavyWallHitEffect',,, HitLocation+HitNormal, Rotator(HitNormal));
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
			if ( bSpecialEff )			spawn(class'zp_SpriteSmokePuff',Owner,,HitLocation+HitNormal*9);	
			else			spawn(class'UT_SpriteSmokePuff',,,HitLocation+HitNormal*9);	
		}
	}
}


defaultproperties
{
    ffAimError=16
    DeathMessage="%k FuckedUp %o with the sexy Rifle."
    ItemName=ChamRifle
    PickupMessage="You picked up the Rifle!"
    PickupAmmoCount=600
}
