//Shared utilitary functions
//By Higor


class LCStatics expands Object
	abstract;

#exec OBJ LOAD FILE="LCPureUtil.u" PACKAGE=LCWeapons_0022
#exec OBJ LOAD FILE="SiegeUtil_A.u" PACKAGE=LCWeapons_0022

const MULTIPLIER = 0x015a4e35;
const INCREMENT = 1;

var int XCGE_Version;
var bool bXCGE;
var bool bXCGE_LevelHook; //Indicates that level has been hooked
var bool bXCGE_NotRelevantToOwner; //Indicates that bNotRelevantToOwner feature exists on this server

var const string RoleText[5];

//XC_Engine interface
native(3560) static final function bool ReplaceFunction( class<Object> ReplaceClass, class<Object> WithClass, name ReplaceFunction, name WithFunction, optional name InState);
native(3561) static final function bool RestoreFunction( class<Object> RestoreClass, name RestoreFunction, optional name InState);


//*********************
// Detect XC_GameEngine
//*********************

static final function bool DetectXCGE( Actor Other)
{
	default.bXCGE = InStr( Other.XLevel.GetPropertyText("Engine"), "XC_GameEngine") >= 0;
	default.XCGE_Version = int(Other.Level.ConsoleCommand("get ini:Engine.Engine.GameEngine XC_Version"));
	default.bXCGE_LevelHook = bool( Other.Level.ConsoleCommand("get ini:Engine.Engine.GameEngine bUseLevelHook"));
	if ( default.XCGE_Version >= 19 ) //XC_Core version 7 or above
	{
	}
	if ( default.XCGE_Version >= 20 ) //Static-safe XCGE replacer
	{
	}
	Other.Level.ConsoleCommand("set XC_ClientPhysics bRelevantIfOwnerIs 1");
	return default.bXCGE;
}


//************************************************************************
//Use the util to get a player's rotation while keeping Pure compatibility
//************************************************************************
static final function rotator PlayerRot( Pawn P)
{
	return class'LCPureRotation'.static.PlayerRot(P);
}


//*****************
//Swap two integers
//*****************
static function ffSwap( out private int U, out private int H)
{
	local private int L;
	
	L = U;
	U = H;
	H = L;
}


//*************************
//Client friendly TraceShot
//*************************
static final function Actor ffTraceShot( out vector HitLocation, out vector HitNormal, vector EndTrace, vector StartTrace, Pawn P)
{
	local Actor A;
	local float OldEyeHeight, OldBaseEyeHeight;
	local bool bHit;
	local byte OldRole;
	
	if ( P == None )
		return None;
		
	ForEach P.TraceActors( class'Actor', A, HitLocation, HitNormal, EndTrace, StartTrace)
	{
		if ( TraceStopper( A) )
			return A;
		else if ( Pawn(A) != None )
		{
			OldEyeHeight = Pawn(A).EyeHeight;
			OldBaseEyeHeight = Pawn(A).BaseEyeHeight;
			if ( (A.Mesh != None) && A.HasAnim( A.AnimSequence) )
			{
				if ( (A.GetAnimGroup( A.AnimSequence) == 'Ducking') && (A.AnimFrame > -0.03) )
				{
					Pawn(A).BaseEyeHeight = Pawn(A).default.BaseEyeHeight * 0.1;
					Pawn(A).EyeHeight = Pawn(A).BaseEyeHeight;
				}
				else if ( InStr( string(A.AnimSequence),"Dead") != -1 || InStr( string(A.AnimSequence),"DeathEnd") != -1 )
				{
					Pawn(A).BaseEyeHeight = 0;
					Pawn(A).EyeHeight = 0;
				}
			}
			OldRole = A.Role;
			A.Role = ROLE_Authority; //SOME PAWNS DON'T DEFINE THE FUNC AS SIMULATED!
			bHit = Pawn(A).AdjustHitLocation( HitLocation, EndTrace - StartTrace); 
			A.SetPropertyText( "Role", default.RoleText[OldRole]);
			
			Pawn(A).BaseEyeHeight = OldBaseEyeHeight;
			Pawn(A).EyeHeight = OldEyeHeight;
			if ( bHit && (A != P) ) //Safeguard
				return A;
		}
		else if ( A.bProjTarget || (A.bBlockActors && A.bBlockPlayers) )
			return A;
	}
	HitLocation = EndTrace;
	HitNormal = Normal( StartTrace - EndTrace);
	return None;
}

//************************************
//Server TraceShot for missed ZP shots
//************************************
static final function Actor ffIrrelevantShot(out vector ffHitLocation, out vector ffHitNormal, vector ffEndTrace, vector ffStartTrace, private Pawn ffTmp, private float ffPing)
{
	local private vector ffRealHit;
	local private Actor ffOther;

	if ( ffTmp == none )
		return none;
	ForEach ffTmp.TraceActors( class'Actor', ffOther, ffHitLocation, ffHitNormal, ffEndTrace, ffStartTrace)
	{
		if ( TraceStopper( ffOther) )
			return ffOther;
		if ( (!ffOther.bProjTarget && !ffOther.bBlockActors) || RelevantHitActor(ffOther, PlayerPawn(ffTmp), ffPing) ) //Non-solids or client hit actors ignored
			continue;
		if ( ffOther.bIsPawn && !Pawn(ffOther).AdjustHitLocation(ffHitLocation, ffEndTrace - ffStartTrace) )
			continue;
		return ffOther;
	}
	return none;
}

//*************************************
//Server trace of LC sub-engine weapons
//*************************************
static final function Actor LCTrace( out vector HitLocation, out vector HitNormal, vector EndTrace, vector StartTrace, Pawn Shooter)
{
	local Actor A;
	
	ForEach Shooter.TraceActors( class'Actor', A, HitLocation, HitNormal, EndTrace, StartTrace)
	{
		if ( !TraceStopper( A) )
		{
			if ( (!A.bProjTarget && !A.bBlockActors) //Unhittable
				|| CompensatedType(A) //Hit compensator instead
				|| (A.bIsPawn && !Pawn(A).AdjustHitLocation(HitLocation, EndTrace - StartTrace)) ) //Missed
				continue;
		}
		return CompensatedHitActor( A, HitLocation);
	}
	return None;
}


//*********************************
//Byte reversal in a simple integer
//*********************************
static final function int ffRevertByte( private int nani2)
{
	local private int nani, HackMe;
	For ( HackMe=0 ; HackMe<32 ; HackMe++ )
		nani = nani | ( ((nani2 >>> HackMe) & 1) << (31-HackMe));
}


//********************************
//Turn a rotator into a single INT
//********************************
static final function int CompressRotator( rotator R)
{
	return (R.Pitch << 16) | (R.Yaw & 65535);
}

//*************************
//Turn a INT into a rotator
//*************************
static final function rotator DecompressRotator( int A)
{
	local rotator aRot;
	aRot.Yaw = A & 65535;
	aRot.Pitch = (A >>> 16);
	return aRot;
}

//***********************************************************
//Sees if LC compressed and player compressed rotations match
//***********************************************************
static final function bool CompareRotation( rotator A, rotator B)
{
	return (Abs((A.Yaw & 65535) - (B.Yaw & 65535)) < 3)
	&& (Abs((A.Pitch & 65535) - (B.Pitch & 65535)) < 3);
}

//****************************************************************
//Verify that a middle point belongs to a possible rotation change
//****************************************************************
static final function bool ContainsRotator( rotator Sample, rotator A, rotator B, float Expand)
{
	local rotator rr;
	local vector vA, vB, vS, DirH, DirV, MidPoint, PointRelative;
	local float Radius, HDist, VDist;
	
	Expand = FMax( 0.1, Expand);
	
	vA.X = A.Pitch & 65534; //Starting point
	vA.Y = A.Yaw & 65534;
	rr.Pitch = (B.Pitch - A.Pitch) & 65534; //Establish direction of A->B
	rr.Yaw   = (B.Yaw   - A.Yaw  ) & 65534;
	if ( rr.Pitch > 32768 ) rr.Pitch -= 32768;
	if ( rr.Yaw   > 32768 ) rr.Yaw   -= 32768;
	vB.X = vA.X + rr.Pitch; //End point
	vB.Y = vA.Y + rr.Yaw;
	rr.Pitch = (Sample.Pitch - A.Pitch) & 65534; //Establish direction of A->Sample
	rr.Yaw   = (Sample.Yaw   - A.Yaw  ) & 65534;
	if ( rr.Pitch > 32768 ) rr.Pitch -= 32768;
	if ( rr.Yaw   > 32768 ) rr.Yaw   -= 32768;
	vS.X = vA.X + rr.Pitch; //Sample point
	vS.Y = vA.Y + rr.Yaw;
	MidPoint = (vA+vB)*0.5; //Center point
	DirH = Normal(vA-vB); //Direction between points
	DirV.X = DirH.Y; //Perpendicular direction
	DirV.Y = -DirH.X;
	Radius = Abs( (MidPoint - vB) dot DirH); //Large radius of elypse
	
//	Log( Sample @ A @ B);
	
	PointRelative = vS - MidPoint; //Relative sample on elypse
	HDist = (PointRelative dot DirH) / Radius; //H coordinate of relative
	VDist = (PointRelative dot DirV) / Radius; //V coordinate of relative (adjustable to Expand)
//	Log("H="$HDist@"V="$VDist);
	return Square(HDist) + Square(VDist/Expand) <= 1.2; //Rotation compression adds error
}


//*************************************************
//Obtain a 'middle' point between 2 given rotations
//*************************************************
static final function rotator AlphaRotation( rotator End, rotator Start, float Alpha)
{
	local rotator Middle;
	Middle.Yaw   = (Start.Yaw   + (End.Yaw   - Start.Yaw  ) * Alpha) & 65535;
	Middle.Pitch = (Start.Pitch + (End.Pitch - Start.Pitch) * Alpha) & 65535;
	Middle.Roll  = (Start.Roll  + (End.Roll  - Start.Roll ) * Alpha) & 65535;
	return Middle;
}

//**********************************************************************
//Effects that support LC hiding/XCGE no owner replication become hidden
//**********************************************************************
static final function SetHiddenEffect( Actor Effect, Actor Owner, XC_CompensatorChannel Channel)
{
	if ( (Channel != None) && (Channel.Level.NetMode != NM_Client) && Channel.bUseLC && (Effect != None) && (Channel.Owner == Owner) && (PlayerPawn(Owner) != None) )
	{
		Effect.SetOwner( Owner);
		Effect.SetPropertyText("bIsLC","1");
		Effect.SetPropertyText("bNotRelevantToOwner","1");
	}
}

//*******************************
//Sees if this weapon supports LC
//*******************************
static final function bool IsLCWeapon( Weapon W)
{
	local byte OldRole;
	local bool bIsLC;
	
	if ( W != None )
	{
		OldRole = W.Role;
		W.Role = ROLE_Authority;
		bIsLC = W.GetPropertyText("LCChan") != "";
		W.SetPropertyText( "Role", default.RoleText[OldRole] );
	}
	return bIsLC;
}

//*************************************************************
//Finds out if this hit actor should be considered for ZP shots
//*************************************************************
static final function bool RelevantHitActor( Actor Other, optional PlayerPawn P, optional float Ping)
{
	if ( Other.bIsPawn && (StationaryPawn(Other) == none) )
		return true;
	if ( Projectile(Other) != none )
	{
		if ( P != none )
		{
			if ( P.Level.NetMode != NM_Client ) //Client shot processed on server
			{
				if ( (Other.Instigator == P) ) //Player shoots his own stuff
				{
					if ( (ShockProj(Other) != none) && ((Other.Default.LifeSpan - Other.LifeSpan)/Other.Level.TimeDilation < Ping) )
						return false; //Combo possible on huge pings
				}
				else //Player shoots foreign stuff
				{
					if ( (Other.IsA('WarShell') || Other.IsA('sgWarShell')) && ((Other.Default.LifeSpan - Other.LifeSpan)/Other.Level.TimeDilation < Ping * 0.8) )
						return false; //Player can take down nukes using prediction
				}
			}
		}
		return true;
	}
	return false;
}

//******************************************************************
//This actor is always the end of a shot, regardless of other checks
//******************************************************************
static final function bool TraceStopper( Actor Other)
{
	if ( Other == Other.Level || Other.IsA('Mover') )
		return true;
	return false;
}

//********************************************************************************
//This actor should not be targeted by Traces!!, target their compensators instead
//********************************************************************************
static final function bool CompensatedType( actor Other)
{
	if ( Other.bIsPawn )
	{
		if ( Pawn(Other).PlayerReplicationInfo != none || ScriptedPawn(Other) != none )
			return true;
	}
	else if ( (Projectile(Other) != none) && !Other.default.bNetTemporary && Other.bProjTarget )
		return true;
}


//****************************************************
//If this is a lag compensator, return the real victim
//****************************************************
static final function Actor CompensatedHitActor( Actor Other, out vector HitLocation)
{
	if ( Other == none || Other.bIsPawn || Other == Other.Level ) //Super fast checks
		return Other; //Should deprecate
	if ( XC_LagCompensator(Other) != none )
	{
		HitLocation += XC_LagCompensator(Other).ffOwner.Location - Other.Location;
		return XC_LagCompensator(Other).ffOwner;
	}
	if ( XC_GenericPosList(Other) != none )
	{
		HitLocation += XC_GenericPosList(Other).Compensated.Location - Other.Location;
		return XC_GenericPosList(Other).Compensated;
	}
	return Other;
}

//*****************************************************************************************************
//Parse next parameter from this command string using a custom delimiter, prepare string for next parse
//*****************************************************************************************************
static final function string NextParameter( out string Commands, string Delimiter)
{
	local string result;
	local int i;
	
	if ( Delimiter == "" )
	{	result = Commands;
		Commands = "";
		return result;
	}

	i = InStr(Commands, Delimiter);
	if ( i < 0 )
	{
		result = Commands;
		Commands = "";
		return result;
	}
	if ( i == 0 ) //Idiot parse
	{
		Commands = Mid( Commands, Len(Delimiter));
		return NextParameter( Commands, Delimiter);
	}
	result = Left( Commands, i);
	Commands = Mid( Commands, i + Len(Delimiter) );
	return result;
}

//**************************************************************************************************
//Parses a parameter from this command using a delimiter, can seek and doesn't modify initial string
//**************************************************************************************************
static final function string ByDelimiter( string Str, string Delimiter, optional int Skip)
{
	local int i;

	AGAIN:
	i = InStr( Str, Delimiter);
	if ( i < 0 )
	{
		if ( Skip == 0 )
			return Str;
		return "";
	}
	else
	{
		if ( Skip == 0 )
			return Left( Str, i);
		Str = Mid( Str, i + Len(Delimiter) );
		Skip--;
		Goto AGAIN;
	}
}

//***********************************
//Remove initial spaces from a string
//***********************************
static final function string ClearSpaces( string Text)
{
	local int i;

	i = InStr(Text, " ");
	while( i == 0 )
	{
		Text = Mid( Text, 1);
		i = InStr(Text, " ");
	}
	return Text;
}

//*************
//Replaces text
//*************
static final function ReplaceText(out string Text, string Replace, string With)
{
	local int i;
	local string Input;
		
	Input = Text;
	Text = "";
	i = InStr(Input, Replace);
	while(i != -1)
	{	
		Text = Text $ Left(Input, i) $ With;
		Input = Mid(Input, i + Len(Replace));	
		i = InStr(Input, Replace);
	}
	Text = Text $ Input;
}


//*****************************************************************************
//Obtains time it gets to complete an animation (in case of loop ignores tween)
//*****************************************************************************
static final function float AnimationTime( Actor Other)
{
	if ( Other.AnimRate <= 0 || Other.AnimLast <= 0 )
		return 0;
	else if ( Other.bAnimLoop )
		return 1 / Other.AnimRate;
	else
		return (1.0 - Other.AnimLast) / Other.TweenRate + Other.AnimLast / Other.AnimRate;
}


//**************************************
// Spawns an enhanced copy of a LCWeapon
//**************************************
//Customized to allow respawning with custom ammo amounts
static final function Inventory SpawnCopy( Pawn Other, Weapon W )
{
	local Weapon Copy;
	if( W.Level.Game.ShouldRespawn(W) )
	{
		Copy = W.spawn(W.Class,Other,,,rot(0,0,0));
		Copy.Tag           = W.Tag;
		Copy.Event         = W.Event;
		Copy.PickupAmmoCount = W.PickupAmmoCount;
		Copy.AmmoName		= W.AmmoName;
		if ( !W.bWeaponStay )
			W.GotoState('Sleeping');
	}
	else
		Copy = W;
	Copy.RespawnTime = 0.0;
	Copy.bHeldItem = true;
	Copy.bTossedOut = false;
	GiveTo( Other, Copy);
	Copy.Instigator = Other;
	Copy.GiveAmmo(Other);
	Copy.SetSwitchPriority(Other);
	if ( !Other.bNeverSwitchOnPickup )
		Copy.WeaponSet(Other);
	Copy.AmbientGlow = 0;
	return Copy;
}


//*****************************************************************
// Delete previous weapon of same class to prevent double-switching
//*****************************************************************
static final function GiveTo( Pawn Other, Weapon W)
{
	local Weapon W2;
	local inventory I;
	
	W.SetPropertyText("LCChan","");
	W.Instigator = Other;
	W.BecomeItem();
	W2 = Weapon(Other.FindInventoryType( W.class ));
	if ( W2 == W )
	{ //WTF happened here?
	}
	else if ( W2 != none ) //Replace weapon in Pawn's chain
	{
		W.Inventory = W2.Inventory;
		if ( W2 == Other.Inventory )
			Other.Inventory = W;
		else
		{
			For ( I=Other.Inventory ; I!=none ; I=I.Inventory )
				if ( I.Inventory == W2 )
				{
					I.Inventory = W;
					break;
				}
		}
		W.SetOwner( Other);
		if ( Other.Weapon == W2 )
		{
			Other.PendingWeapon = W;
			Other.Weapon = none;
			Other.ChangedWeapon();
			if ( PlayerPawn(Other) != none )
				W.SetHand( PlayerPawn(Other).Handedness);
		}
		if ( W.AmmoType == none )
		{
			W.AmmoType = W2.AmmoType;
			W2.AmmoType = none;
		}
		W2.SetOwner( none);
		W2.Instigator = none;
		W2.Destroy();
	}
	else
		Other.AddInventory(W);
	if ( Other.Weapon != W )
		W.GotoState('Idle2');
}


//**********************************
//Finds Weapon based on a superclass
//**********************************
static final function Weapon FindBasedWeapon( Pawn Other, class<Weapon> WC)
{
	local Weapon First, Cur;
	local inventory Inv;
	local bool bNext;
	local int i;
	
	For ( Inv=Other.Inventory ; Inv!=none ; Inv=Inv.Inventory )
	{
		if ( (i++ > 200) || (Weapon(Inv) == none) )
			continue;
		if ( ClassIsChildOf( Inv.Class, WC) )
		{
			if ( (Weapon(Inv).AmmoType != none) && (Weapon(Inv).AmmoType.AmmoAmount <= 0) )
				continue;
			if ( First == none )
				First = Weapon(Inv);
			if ( bNext )
			{
				Cur = Weapon(Inv);
				Goto WSWITCH;
			}
		}
		if ( Other.Weapon == Inv )
			bNext = True;
	}
	Cur = First;
	WSWITCH:
	if ( Other.Weapon == Cur )
		return Cur;
	if ( Other.Weapon != none )
	{
		Other.Weapon.PutDown();
		Other.PendingWeapon = Cur;
	}
	else
	{
		Other.Weapon = Cur;
		Other.Weapon.BringUp();
	}
	return Cur;
}

//**********************************************************************
// Generates a semi random number based on a given seed, seed is updated
// Ranges from -1 to 1 *************************************************
static final function float fRandom_Seed(float Scale, out int RandomSeed)
{
	local int aRs;
	local float Result;

	if ( Scale == 0 )
		Scale = 1;

	RandomSeed = MULTIPLIER * RandomSeed + INCREMENT;
	aRs = ((RandomSeed >>> 16) & 65535) - 32768; //Sign is kept, precision increased
//	Log("Seed is now: "$RandomSeed@" aRs is: "$aRs);
	Result = Scale * aRs / 32768f;
	return Result;
}

//*******************************************
// Provide quick aim error using random seeds
//*******************************************
static final function vector StaticAimError( vector Y, vector Z, float Accuracy, int RandomSeed)
{
	return (fRandom_Seed( 500, RandomSeed) * Y + fRandom_Seed( 500, RandomSeed) * Z) * Accuracy;
}
static final function vector SyncAimError( vector Y, vector Z, float Accuracy, int RandomSeed, out int NewSeed)
{
	NewSeed = RandomSeed;
	return (fRandom_Seed( 500, NewSeed) * Y + fRandom_Seed( 500, NewSeed) * Z) * Accuracy;
}

//*******************************
// Placement and comparison utils
//*******************************
static final function float HSize( vector aVec)
{
	return VSize(aVec * vect(1,1,0));
}

static final function bool ActorsTouching( actor A, actor B)
{
	if ( abs(A.Location.Z - B.Location.Z) > (A.CollisionHeight + B.CollisionHeight) )
		return false;
	return HSize( A.Location - B.Location) <= (A.CollisionRadius + B.CollisionRadius);
}

static final function vector VLerp( float Alpha, vector A, vector B)
{
	return A + (B-A) * Alpha;
}

static final function float GetAlpha( float Value, float A, float B)
{
	return fClamp( (Value-A) / (B-A) ,0,1);
}


//*************************************************
// Adjusts a trace to hit the cylinder from outside
//*************************************************
static final function vector CylinderEntrance( vector TStart, vector TDir, float CRadius, float CHeight, optional vector CCenter)
{
	local float fX, fY, fZ;
	local vector Y, result;

	TStart -= CCenter;

	Y = Normal(TDir * vect(1,1,0));
	if ( Y == vect(0,0,0) )
	{
		Y = vect(1,0,0); //Hard fix if player is aiming up or down
		TStart.Z = CCenter.Z;
		if ( TDir.Z > 0 )
			return TStart - vect(0,0,1) * CHeight; //Bottom of cylinder
		return TStart + vect(0,0,1) * CHeight; //Top of cylinder
	}
	//Rotates 90º to right
	Y.Z = Y.X;
	Y.X = Y.Y;
	Y.Y = -Y.Z;
	Y.Z = 0;
	fY = (TStart dot Y);
	if ( fY > CRadius )
	{
		Log("ERROR AT CYLINDER ENTRANCE CALC, SHOT WAS MISSED AT SIDE",'LagCompensator');
		return vect(0,0,0); //Error
	}
	fX = sqrt(1 - square(fY/CRadius)); //This is positive
	fX /= (TDir dot Normal(TDir * vect(1,1,0))); //Expand fX to compensate the Z comp of TDir
	fX *= CRadius; //If we turn to negative, we go behind from center point, which is ENTRANCE!
	result = TStart - fY * Y; //Adjust origin for line to cross Z axis
	fZ = result.Z - (result.X * TDir.Z / TDir.X); //Get the intersection Z coord

	result = (fY * Y) - (fX * TDir) + (fZ * vect(0,0,1)); //Intersect whole line with endless cylinder
	if ( abs(result.Z) <= CHeight ) //Accept if within CHeight boundaries
		return CCenter + result;
	if ( TDir.Z == 0 )
		return vect(0,0,0); //Will never intercept floor or ceiling
	result = TStart;
	if ( TDir.Z > 0 ) //Find floor
		result.Z += CHeight;
	else			//Find ceil
		result.Z -= CHeight;
	result.X -= (result.Z * TDir.X / TDir.Z);
	result.Y -= (result.Z * TDir.Y / TDir.Z);
	result.Z = 0;
	if ( VSize( result) > CRadius )
	{
		Log("ERROR AT CYLINDER ENTRANCE CALC, SHOT WAS MISSED AT HEIGHT",'LagCompensator');
		return vect(0,0,0);
	}
	if ( TDir.Z > 0 )
		result.Z = -CHeight;
	else
		result.Z = CHeight;
	return CCenter + result;
}

//***********************************
// Returns the actor's CylinderExtent
//***********************************
static final function vector CylinderExtent( Actor Other)
{
	return vect(1,1,0)*Other.CollisionRadius + vect(0,0,1)*Other.CollisionHeight;
}


//******************************************************
// Returns an array index based on an actor's Owner team
//******************************************************
static final function int FVOwnerTeam( Actor Other)
{
	return FVTeam( Pawn(Other.Owner) );
}

static final function int FVTeam( Pawn Other)
{
	if ( Other == none || Other.PlayerReplicationInfo == none )
		return 4;
	return Min( Other.PlayerReplicationInfo.Team, 4);
}

//*********************************************
// Find a first saved move beyond time stamp
// Ported from SiegeIV_0019
//*********************************************
static final function SavedMove FindMoveBeyond( PlayerPawn Other, float TimeStamp)
{
	local SavedMove Result;
	Result = Other.SavedMoves;
	while ( Result != none )
	{
		if ( Result.TimeStamp > TimeStamp )
			return Result;
		Result = Result.NextMove;
	}
}


//*********************************************************************
// Replaces def switch priority, lets weapons use non-class based names
//*********************************************************************
static final function SetSwitchPriority( Pawn Other, Weapon Weap, name CustomName)
{
	local int i;
	local name temp, carried;

	if ( PlayerPawn(Other) != None )
	{
		for ( i=0; i<ArrayCount(PlayerPawn(Other).WeaponPriority); i++)
			if ( PlayerPawn(Other).WeaponPriority[i] == CustomName )
			{
				Weap.AutoSwitchPriority = i;
				return;
			}
		// else, register this weapon
		carried = CustomName;
		for ( i=Weap.AutoSwitchPriority; i<ArrayCount(PlayerPawn(Other).WeaponPriority); i++ )
		{
			if ( PlayerPawn(Other).WeaponPriority[i] == '' )
			{
				PlayerPawn(Other).WeaponPriority[i] = carried;
				return;
			}
			else if ( i<ArrayCount(PlayerPawn(Other).WeaponPriority)-1 )
			{
				temp = PlayerPawn(Other).WeaponPriority[i];
				PlayerPawn(Other).WeaponPriority[i] = carried;
				carried = temp;
			}
		}
	}		
}


defaultproperties
{
	RoleText(0)="ROLE_None"
	RoleText(1)="ROLE_DumbProxy"
	RoleText(2)="ROLE_SimulatedProxy"
	RoleText(3)="ROLE_AutonomousProxy"
	RoleText(4)="ROLE_Authority"
}