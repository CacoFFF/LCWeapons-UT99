//********************************
// AlienAssaultRifleV17, adapted to LC
//********************************

class LC_AARV17 expands LCSniperRifle;

var bool bGraphicsInitialized;
var bool bZoom;
var Texture Scope, Lines;
var class<UT_BloodDrop> BloodClass;

simulated event Spawned()
{
	if ( !bGraphicsInitialized )
		InitGraphics();
}

simulated function InitGraphics()
{
	local class<TournamentWeapon> OrgClass;

	default.bGraphicsInitialized = true;
	OrgClass = class<TournamentWeapon>( DynamicLoadObject("AARV17.AlienAssaultRifle",class'class') );

	default.Scope = Texture( DynamicLoadObject("AARV17.Scope",class'Texture') );
	default.Lines = Texture( DynamicLoadObject("AARV17.Lines",class'Texture') );
	Lines = default.Lines;
	Scope = default.Scope;

	BloodClass = Class<UT_BloodDrop>( DynamicLoadObject("AARV17.BloodDrop",class'class') );
	Default.BloodClass = BloodClass;
}

simulated function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
   local vector v;
   local int i;
   local UT_BloodDrop b;
	local Actor HitEffect;
   
	if ( (Level.NetMode == NM_Client) || (BloodClass == none) )
	{
		Super.ProcessTraceHit( Other, HitLocation, HitNormal, X, Y, Z);
		return;
	}

	if ( Other == Level )
	{
		HitEffect = Spawn( class'FV_HeavyWallHitEffect',,, HitLocation+HitNormal, Rotator(HitNormal));
		class'LCStatics'.static.SetHiddenEffect( HitEffect, Owner, LCChan);
	}
	else if ((Other != self) && (Other != Owner) && (Other != None))
	{
		if ( Other.bIsPawn )
		{
			Other.PlaySound(Sound 'ChunkHit',, 4.0,,100);
			Other.PlaySound(Sound 'UnrealI.Razorjack.BladeThunk',, 4.0,,100);
			PlayOwnedSound(Sound 'UnrealI.Razorjack.BladeThunk',, 4.0,,10);
		}
		if ( Other.bIsPawn && (HitLocation.Z - Other.Location.Z > 0.62 * Other.CollisionHeight)
		&& (instigator.IsA('PlayerPawn') || (instigator.IsA('Bot') && !Bot(Instigator).bNovice))
		&& ((Owner.Physics != PHYS_Falling && Owner.Physics != PHYS_Swimming && Pawn(Owner).bDuck != 0)
		|| Owner.Velocity == 0 * Owner.Velocity) )
		{
			if ( Pawn(Other).Health > 0 )
			{
				Other.TakeDamage( HeadshotDamage, Pawn(Owner), HitLocation, 35000 * X, AltDamageType);
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
					if ( BloodClass == None )
						return;
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
		else 
			Other.TakeDamage( HeadshotDamage, Pawn(Owner), HitLocation, 35000 * X, AltDamageType);
	}
	else
		Other.TakeDamage( NormalDamage,  Pawn(Owner), HitLocation, 30000.0*X, MyDamageType);

		if ( !Other.bIsPawn && !Other.IsA('Carcass') )
		{
			HitEffect = Spawn( class'FV_SpriteSmokePuff',,, HitLocation+HitNormal*9);
			class'LCStatics'.static.SetHiddenEffect( HitEffect, Owner, LCChan);
		}
	}
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

	Super(TournamentWeapon).PostRender(Canvas);
	P = PlayerPawn(Owner);
	Size = 256;

	if ( (P != None) && (P.DesiredFOV != P.DefaultFOV) ) 
	{
		bOwnsCrossHair = true;

		Scale = 1;			
		Canvas.SetPos(0.5 * Canvas.ClipX - Size/2 * Scale, 0.5 * Canvas.ClipY - Size/2 * Scale );
		if ( Level.bHighDetailMode )
			Canvas.Style = ERenderStyle.STY_Translucent;
		else
			Canvas.Style = ERenderStyle.STY_Normal;			
		Canvas.DrawIcon( Scope, Scale);
	
		// Top Line  
		Canvas.SetPos( Canvas.ClipX/2, Canvas.ClipY/2-Size*2 + (Size/2*3-P.DesiredFOV/2*3) + 10);
		Canvas.DrawTile( Lines, 1, Size/2, 64, 2, 0, 63 );
		
		// Bottom Line  
		Canvas.SetPos( Canvas.ClipX/2, Canvas.ClipY/2 + Size+Size/2 -(Size/2*3-P.DesiredFOV/2*3)+1 -10);
		Canvas.DrawTile( Lines, 1, Size/2, 64, 64, 0, 63 );

		// Left Line 
		Canvas.SetPos( Canvas.ClipX/2 - Size*2 +(Size/2*3-P.DesiredFOV/2*3) +10 , Canvas.ClipY/2-1 );
		Canvas.DrawTile( Lines, Size/2, 1, 2, 64, 63, 0 );

		// Right Line 
		Canvas.SetPos( Canvas.ClipX/2 + Size+Size/2 - (Size/2*3-P.DesiredFOV/2*3)+1 -10 , Canvas.ClipY/2-1 );
		Canvas.DrawTile( Lines, Size/2, 1, 65, 64, 63, 0 );

	        // Calc range
        	XLength=255.0;
		GetAxes(P.ViewRotation,X,Y,Z);
		if ((Pawn(Owner).ViewRotation.Pitch >= 0) && (P.ViewRotation.Pitch <= 18000))
			radpitch = float(P.ViewRotation.Pitch) / float(182) * (Pi/float(180));
		else
			radpitch = float(P.ViewRotation.Pitch - 65535) / float(182) * (Pi/float(180));

		StartTrace = Owner.Location + P.EyeHeight*Z*cos(radpitch);
		EndTrace = StartTrace + 20000 * X;
		Other = P.TraceShot(HitLocation,HitNormal,EndTrace,StartTrace);
		range = Vsize(StartTrace-HitLocation)/48-0.25;


		// Magnification Display
		Canvas.SetPos( Canvas.ClipX/2 + Size/2 -20, Canvas.ClipY/2 +Size/2 -20 );
		Canvas.Font = Font'Botpack.WhiteFont';
		Canvas.DrawColor.R = 255;
		Canvas.DrawColor.G = 255;
		Canvas.DrawColor.B = 255;
		Scale = P.DefaultFOV/P.DesiredFOV;
		Canvas.DrawText("     Alien zoom  :"$int(Scale)$"."$int(10 * Scale - 10 * int(Scale))$"");
		
		// Range Display
		Canvas.SetPos( Canvas.ClipX/2 + Size/2 -20, Canvas.ClipY/2 +Size/2 );
		Canvas.Font = Font'Botpack.WhiteFont';
		Canvas.DrawColor.R = 255;
		Canvas.DrawColor.G = 255;
		Canvas.DrawColor.B = 255;
	        Canvas.DrawText( "          Range :"$int(range)$"."$int(10 * range -10 * int(range))$"");

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
		PlayOwnedSound(Misc1Sound, SLOT_Misc, 1.0*Pawn(Owner).SoundDampening,,, Level.TimeDilation-0.1);
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
    ffRefireTimer=0.133
	FireAnimRate=5
    DeathMessage="%k put a alienbullet through %o's brain."
    ItemName="Alien Sniper Rifle"
    PickupMessage="You picked up a AlienAssaultRifle."
    PickupAmmoCount=999
    HeadshotDamage=100000
}
