//
// MH2 Sniper Rifle adaptation
//
// BROKEN(?)

class LCMH2Rifle expands LCSniperRifle;


var bool bGraphicsInitialized;
var bool bZoom;
var Texture Crosshair;
var int RifleDamage;
var class<TournamentWeapon> OrgClass;
var class<Blood2> BloodClass;


simulated event Spawned()
{
	if ( !bGraphicsInitialized )
		InitGraphics();
}

simulated function InitGraphics()
{
	local string Pkg;

	if ( OrgClass == none )
	{
		Log("Original class still fails!");
		return;
	}
	else
		default.bGraphicsInitialized = true;
	Pkg = string(OrgClass);	
	Pkg = class'LCStatics'.static.ByDelimiter( Pkg, ".");
	Crosshair = Texture( DynamicLoadObject(Pkg$".crosshair",class'Texture') );
	Default.Crosshair = Crosshair;
	MultiSkins[0] = Texture( DynamicLoadObject(Pkg$".Rifle.AA",class'Texture') );
	MultiSkins[1] = Texture( DynamicLoadObject(Pkg$".Rifle.SR",class'Texture') );
	MultiSkins[2] = Texture( DynamicLoadObject(Pkg$".Skins.RifleFloor",class'Texture') );
	Default.MultiSkins[0] = MultiSkins[0];
	Default.MultiSkins[1] = MultiSkins[1];
	Default.MultiSkins[2] = MultiSkins[2];
	BloodClass = Class<Blood2>( DynamicLoadObject(Pkg$".BloodDrop",class'class') );
	Default.BloodClass = BloodClass;
	if ( Level.NetMode != NM_Client )
		Spawn(class'LCMH2RifleLoader').TCL = OrgClass;
}

simulated event RenderOverlays( canvas Canvas )
{
	MultiSkins[2] = none;
	Super.RenderOverlays(Canvas);
	MultiSkins[2] = Default.MultiSkins[2];
}

simulated function PlayFiring()
{
	PlayOwnedSound(FireSound, SLOT_None, Pawn(Owner).SoundDampening*3.0);
	PlayAnim(FireAnims[Rand(5)],0.8 + 0.8 * FireAdjust, 0.05);
	if ( (PlayerPawn(Owner) != None) && (PlayerPawn(Owner).DesiredFOV == PlayerPawn(Owner).DefaultFOV) )
		bMuzzleFlash++;
	if ( IsLC() && (Level.NetMode == NM_Client) )
		LCChan.bDelayedFire = true;
}

simulated function PostRender( canvas Canvas )
{
	local PlayerPawn P;
	local float Scale;
        local float Size;
        local float Xlength;
	local float range;
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
   	local actor Other;
	local float radpitch;

	if ( Crosshair == none )
	{
		Super.PostRender(Canvas);
		return;
	}
	else
		Super(TournamentWeapon).PostRender(Canvas);
	P = PlayerPawn(Owner);
	if ( (P != None) && (P.DesiredFOV != P.DefaultFOV) )
	{
		bOwnsCrossHair = true;

		Canvas.Style = ERenderStyle.STY_Translucent;

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

		Canvas.SetPos( 202*Canvas.ClipX/401-75, 4*Canvas.ClipY/7 + Canvas.ClipY/401 );
		Canvas.Font = Font'Botpack.WhiteFont';
		Canvas.DrawColor.R = 255;
		Canvas.DrawColor.G = 0;
		Canvas.DrawColor.B = 0;
                Canvas.DrawText( ""$int(range)$"."$int(10 * range -10 * int(range))$"");

		Canvas.SetPos( 202*Canvas.ClipX/401, 4*Canvas.ClipY/7 + Canvas.ClipY/401 );
		Canvas.Font = Font'Botpack.WhiteFont';
		Canvas.DrawColor.R = 255;
		Canvas.DrawColor.G = 0;
		Canvas.DrawColor.B = 0;
		Scale = P.DefaultFOV/P.DesiredFOV;
		Canvas.DrawText("x"$int(Scale)$"."$int(10 * Scale - 10 * int(Scale)));
	}
	else
		bOwnsCrossHair = false;
}


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
			if ( PlayerPawn(Owner).DesiredFOV > 1.5)
			{
				PlayerPawn(Owner).DesiredFOV -= PlayerPawn(Owner).DesiredFOV*DeltaTime*3.6;
			}

			if ( PlayerPawn(Owner).DesiredFOV <=1.5)
			{
				PlayerPawn(Owner).DesiredFOV = 1.5;
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

simulated function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
   local vector v;
   local int i;
   local Blood2 b;

	if ( (Level.NetMode == NM_Client) || (BloodClass == none) )
	{
		Super.ProcessTraceHit( Other, HitLocation, HitNormal, X, Y, Z);
		return;
	}

   if ((Other !=none) && (Other == Level))
      Spawn(class'UT_HeavyWallHitEffect',,, HitLocation+HitNormal, Rotator(HitNormal));
   else if ((Other != self) && (Other != Owner) && (Other != None))
   {
      if ( Other.bIsPawn )
      {
         Other.PlaySound(Sound 'ChunkHit',, 4.0,,100);
         Other.PlaySound(Sound 'UnrealI.Razorjack.BladeThunk',, 4.0,,100);
         PlayOwnedSound(Sound 'UnrealI.Razorjack.BladeThunk',, 4.0,,10);
      }
      if ( Other.bIsPawn && (HitLocation.Z - Other.Location.Z > 0.62 * Other.CollisionHeight)
         && (instigator.IsA('PlayerPawn') || (instigator.IsA('Bot') && !Bot(Instigator).bNovice)))
      {
         if ( Pawn(Other).Health > 0 )
	 {
            Other.TakeDamage(RifleDamage, Pawn(Owner), HitLocation, 35000 * X, AltDamageType);
	    if ( Pawn(Other).Health < 1 )
            {
               AmmoType.AddAmmo(3);
               Spawn(class'UT_BigBloodHit',,, HitLocation);
  	       for (i=0; i<(6); i++)
	       {
		  v = HitLocation;
		  v.X += 10 * FRand();
		  v.X -= 15 * FRand();
		  v.Y += 10 * FRand();
		  v.Y -= 15 * FRand();
		  v.Z += 10 * FRand();
		  v.Z -= 15 * FRand();
		  Spawn(class'UT_BloodHit',,, v);
               }
	       for (i=0; i<(3); i++)
               {
		  v = HitLocation;
		  v.X += 5 * FRand();
		  v.X -= 7 * FRand();
		  v.Y += 5 * FRand();
		  v.Y -= 7 * FRand();
		  v.Z += 5 * FRand();
		  v.Z -= 7 * FRand();
		  Spawn(class'BloodBurst',,, v);

		  v = HitLocation;
		  v.X += 7 * FRand();
		  v.X -= 10 * FRand();
		  v.Y += 7 * FRand();
		  v.Y -= 10 * FRand();
		  v.Z += 7 * FRand();
		  v.Z -= 10 * FRand();
		  Spawn(class'BloodBurst',,, v);
               }
 	       for (i=0; i<(80); i++)
               {
		  b = Spawn( BloodClass,,, HitLocation);
		  b.Velocity = vector( RotRand() ) * ( FRand() * 200 );
		  b.DrawScale *= 2 * Frand();
	       }
	       for (i=0; i<80; i++)
               {
		  b = Spawn( BloodClass,,, HitLocation);
		  b.Velocity.Z = i * 5;
		  b.Velocity.X += (i / 7) * FRand();
		  b.Velocity.X -= (i * 1.5 / 7) * FRand();
		  b.Velocity.Y += (i / 7) * FRand();
		  b.Velocity.Y -= (i * 1.5 / 7) * FRand();
		  b.DrawScale += i * 0.00375 * FRand();
		  b.SetPropertyText("bDecal","0");
	       }
            }
         }
         else Other.TakeDamage(RifleDamage, Pawn(Owner), HitLocation, 35000 * X, AltDamageType);
     }
     else Other.TakeDamage(RifleDamage,  Pawn(Owner), HitLocation, 30000.0*X, MyDamageType);

     if ( !Other.bIsPawn && !Other.IsA('Carcass') )
    	spawn(class'UT_SpriteSmokePuff',,,HitLocation+HitNormal*9);
   }
}

defaultproperties
{
    WeaponDescription="MH2 Rifle"
    FiringSpeed=1.8
    ffRefireTimer=0.407
}