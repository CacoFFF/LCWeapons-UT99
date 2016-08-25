//********************************
// NYACovertSniper, adapted to LC
//********************************

class LCNYACovertSniper expands LCSniperRifle;

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

	default.bGraphicsInitialized = true;
	OrgClass = class<TournamentWeapon>( DynamicLoadObject("NYACovertSniper.NYACovertSniper",class'class') );
	default.FireSound = OrgClass.default.FireSound;
	FireSound = default.FireSound;
	default.AmmoName = OrgClass.default.AmmoName;
	AmmoName = default.AmmoName;
	default.Crosshair = Texture( DynamicLoadObject("NYACovertSniper.Crosshair",class'Texture') );
	Crosshair = default.Crosshair;
	default.MultiSkins[0] = Texture( DynamicLoadObject("NYACovertSniper.Rifle.WolfRifle2A0",class'Texture') );
	default.MultiSkins[1] = Texture( DynamicLoadObject("NYACovertSniper.Rifle.WolfRifle2B0",class'Texture') );
	MultiSkins[0] = default.MultiSkins[0];
	MultiSkins[1] = default.MultiSkins[1];
}

simulated function CheckMove()
{
	bFastFire = (Owner.Physics != PHYS_Falling && Owner.Physics != PHYS_Swimming && Pawn(Owner).BaseEyeHeight <= 0) || Owner.Velocity == vect(0,0,0);
	if ( bFastFire )
		ffRefireTimer = default.ffRefireTimer / 4.9;
	else
		ffRefireTimer = default.ffRefireTimer;
}

simulated function PlayFiring()
{
	if ( Level.NetMode == NM_Client )
	{
		CheckMove();
		if ( IsInState('ClientFiring') )
			ffAimError = default.ffAimError;
		else
			ffAimError = 1.6;
	}

	PlayOwnedSound(FireSound, SLOT_None, Pawn(Owner).SoundDampening*3.0);

	if ( bFastFire )	PlayAnim(FireAnims[Rand(5)], 2.5 + 2.5 * FireAdjust, 0.05);
	else			PlayAnim(FireAnims[Rand(5)], 0.5 + 0.5 * FireAdjust, 0.05);

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
		ffAimError = 1.6;
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
