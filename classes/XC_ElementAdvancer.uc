//=============================================================================
// XC_ElementAdvancer.
// Made by Higor
// Register as HUD mutator, and use it to alter positions between Tick and PostRender
// This shit works by miracle, so whatever
//=============================================================================
class XC_ElementAdvancer expands Mutator;

var() float SmoothFactor;
var() vector DevFactor; //vect(0.65,0.65,0.3)
const DebugTickConstant = 100;

struct AdvanceInfo
{
	var Actor Actor;
	var vector PrevRelative;
	var vector OldLoc;
	var vector LocDeltas[4];
	var float LocDeltaTimes[4];
	var vector Velocity;
	var vector ChosenLoc;
	var rotator Rotation;

	var Actor Base; //For future support
	var vector BaseLocation;

	var bool bAdvanced;
};

struct TrailerInfo
{
	var Actor Actor;
	var vector Offset;
	var vector OldLoc;
	var bool bAdvanced;
};

var XC_CompensatorChannel Channel;
var XC_AdvancerTicker Ticker;

var AdvanceInfo Advanced[512]; //Slot 511 is never taken (empty struct)
var int iAdvance;
var TrailerInfo Trailers[128]; //Slot 127 is never taken (empty struct)
var int iTrailer;
var(Debug) bool bAdvanced;

event PreBeginPlay()
{
	if ( Level.NetMode != NM_Client )
		Destroy();

	Ticker = Spawn(class'XC_AdvancerTicker');
	Ticker.Advancer = self;
	SetOwner( Ticker); //Level tick will tick me at the end of all operations, convenient.

	ConsoleCommand( "XC_Console_Level Mutate Prediction _ping_|Select your LCWeapons prediction cap (in MS)|Disable prediction: _ping_ = 0|Let server control prediction cap: _ping_ = default or negative");
	ConsoleCommand( "XC_Console_Level Mutate GetPrediction|Ask the LCWeapons server which prediction cap it's using");
}


simulated event PostRender( canvas Canvas )
{
	if ( NextHUDMutator != none )
		NextHUDMutator.PostRender( Canvas);
	if ( bAdvanced )
		DeAdvancePositions();
}

function XC_ElementAdvancer Setup( XC_CompensatorChannel Other)
{
	local Pawn P;
	Channel = Other;
	NextHUDMutator = Channel.LocalPlayer.myHud.HUDMutator;
	Channel.LocalPlayer.myHUD.HUDMutator = Self;
	bHUDMutator = True;

	ForEach AllActors (class'Pawn', P)
	{
		if ( P.Role != ROLE_SimulatedProxy || StationaryPawn(P) != none )
			continue;
		RegisterAdvance( P);
	}

	return self;
}

//Since i'm owned by an actor spawned after me, I'll tick at the very end of the chain.
//How convenient
event Tick( float DeltaTime)
{
	AdvancePositions( DeltaTime);

	//Fire process after advancement in case I ever decide to mix it again with LC
	Channel.ClientWeaponFire();
}

function AdvancePositions( float DeltaTime)
{
	local int i, j, stepsleft;
	local vector RelativePos, FilteredRel;
	local vector Deviation, HitLocation, HitNormal;
	local Actor ToAdvance;
	local bool bOldCA, bOldBA, bOldBP;
	local Actor TraceCheck;
	local int AdvCode;
	
	if ( Channel.ProjAdv == 0 )
		return;
	
	if ( Channel.LocalPlayer != none )
		AdvCode = AdvanceCode( Channel.LocalPlayer.Weapon);
	if ( AdvCode == 2 ) //NewNet weapon, do not move objects
		return;
	
	for ( i=0 ; i<iAdvance ; i++ )
	{
		if ( !ValidAdvance(i) )
		{
			Advanced[i--] = Advanced[--iAdvance];
			Advanced[iAdvance] = Advanced[511];
			continue;
		}
		ToAdvance = Advanced[i].Actor;
		if ( ToAdvance.bTicked != bTicked ) //Do not advance actors that haven't been ticked
			continue;
		if ( ToAdvance.bIsPawn && AdvCode == 1 )
			continue;
		
		for ( j=3 ; j>0 ; j-- )
		{
			Advanced[i].LocDeltas[j] = Advanced[i].LocDeltas[j-1];
			Advanced[i].LocDeltaTimes[j] = Advanced[i].LocDeltaTimes[j-1];
		}
		Advanced[i].LocDeltas[0] = ToAdvance.Location - Advanced[i].OldLoc;
		Advanced[i].LocDeltaTimes[0] = DeltaTime;

		Deviation = vect(0,0,0);
		if ( VSize(Advanced[i].LocDeltas[0]) < 200 )
		{
			for ( j=1 ; j<4 ; j++ )
			{
				if ( VSize(Advanced[i].LocDeltas[j]) > 200 || (Advanced[i].LocDeltaTimes[j] <= 0) )
					break;
				Deviation += (Advanced[i].LocDeltas[j-1] - Advanced[i].LocDeltas[j]) / Advanced[i].LocDeltaTimes[j];
			}
			Deviation *= DevFactor * Channel.ProjAdv / j;
			if ( Deviation.Z < 0 && ToAdvance.Velocity.Z != 0 ) //This should take care of dodges looking ackward
				Deviation.Z *= 3;
		}
		if ( ToAdvance.Physics == PHYS_Falling )
			Deviation.Z += ToAdvance.Region.Zone.ZoneGravity.Z * 0.35 * Channel.ProjAdv * Channel.ProjAdv;
		Advanced[i].OldLoc = ToAdvance.Location;
		
		RelativePos = ToAdvance.Velocity * Channel.ProjAdv + Deviation;
		Advanced[i].Base = ToAdvance.Base;
		if ( ToAdvance.Base != none )
			Advanced[i].BaseLocation = ToAdvance.Base.Location;
		else
			Advanced[i].BaseLocation = vect(0,0,0);
		if ( VSize(RelativePos) < 2 )
		{
			Advanced[i].PrevRelative = RelativePos;
			continue;
		}

		//Smooth
		FilteredRel = Advanced[i].PrevRelative * (1.f - SmoothFactor * DeltaTime) + RelativePos * SmoothFactor * DeltaTime;
//		FilteredRel = RelativePos;
		if ( bAdvanced ) //There was no de-advancement, just use this function to continue to store advance data
			continue; //I should implement a recovery method here

		if ( ToAdvance.bCollideActors )
		{
			bOldCA = true;
			bOldBA = ToAdvance.bBlockActors; //Prevent encroachment checks on non-hashed actors (wtf epic?)
			bOldBP = ToAdvance.bBlockPlayers;
			ToAdvance.SetCollision( false, false, false);
		}
		StepsLeft = 4;
		Deviation = ToAdvance.Location + FilteredRel;
		if ( ToAdvance.Physics == PHYS_Projectile || ToAdvance.IsA('Projectile') )
			ToAdvance.Move( FilteredRel);
		else
		{
			ToAdvance.MoveSmooth( FilteredRel); //The old collision hash is unstable, let's not overload it with move commands
			//Failed to reach destination, maybe go up a step
			if ( ToAdvance.bIsPawn && (ToAdvance.Velocity.Z == 0) && (class'LCStatics'.static.HSize(ToAdvance.Location - Deviation) > 2) )
			{
				ToAdvance.SetLocation( Advanced[i].OldLoc + vect(0,0,1.10) * Pawn(ToAdvance).MaxStepHeight);
				ToAdvance.MoveSmooth( FilteredRel);
				ToAdvance.SetLocation( ToAdvance.Location - vect(0,0,1.10) * Pawn(ToAdvance).MaxStepHeight);
			}
		}
		if ( bOldCA )
		{
			bOldCA = false;
			ToAdvance.SetCollision( true, bOldBA, bOldBP);
		}
		FilteredRel = ToAdvance.Location - Advanced[i].OldLoc;
		Advanced[i].bAdvanced = true;
		Advanced[i].PrevRelative = FilteredRel;
		Advanced[i].ChosenLoc = ToAdvance.Location;
	}
	
	for ( i=0 ; i<iTrailer ; i++ )
	{
		ToAdvance = Trailers[i].Actor;
		if ( !ValidTrailer(ToAdvance) )
		{
			Trailers[i--] = Trailers[--iTrailer];
			Trailers[iTrailer] = Trailers[127];
			continue;
		}
		Trailers[i].OldLoc = ToAdvance.Location;
//		ToAdvance.SetLocation( ToAdvance.Owner.Location + Trailers[i].Offset);
		ToAdvance.AutonomousPhysics( 0.0);
		Trailers[i].bAdvanced = true;
	}
	
	bAdvanced = true;
}

/*
native(277) final function Actor Trace
(
	out vector      HitLocation,
	out vector      HitNormal,
	vector          TraceEnd,
	optional vector TraceStart,
	optional bool   bTraceActors,
	optional vector Extent
);
*/

function DeAdvancePositions()
{
	local int i;
	local bool bOldCA;
	local vector TargetLocation, DiffChosen;
	local Actor ToAdvance;

	for ( i=0 ; i<iAdvance ; i++ )
	{
		if ( !ValidAdvance(i) )
		{
			Advanced[i--] = Advanced[--iAdvance];
			Advanced[iAdvance] = Advanced[511];
			continue;
		}

		if ( !Advanced[i].bAdvanced )
			continue;

		ToAdvance = Advanced[i].Actor;
		DiffChosen = ToAdvance.Location - Advanced[i].ChosenLoc;
		if ( ToAdvance.bCollideActors )
		{
			bOldCA = true;
			ToAdvance.SetCollision( false, ToAdvance.bBlockActors, ToAdvance.bBlockPlayers);
		}
		TargetLocation = Advanced[i].OldLoc + DiffChosen;
		ToAdvance.SetBase( Advanced[i].Base);
		if ( ToAdvance.Base != none && (ToAdvance.Base.Location - Advanced[i].BaseLocation != vect(0,0,0)) )
			TargetLocation -= ToAdvance.Base.Location - Advanced[i].BaseLocation;
		ToAdvance.SetLocation( TargetLocation ); //The old collision hash is unstable, let's not overload it with move commands
		if ( bOldCA )
		{
			bOldCA = false;
			ToAdvance.SetCollision( true, ToAdvance.bBlockActors, ToAdvance.bBlockPlayers);
		}

		Advanced[i].bAdvanced = false;
	}
	

	for ( i=0 ; i<iTrailer ; i++ )
	{
		if ( !Trailers[i].bAdvanced )
			continue;
		ToAdvance = Trailers[i].Actor;
		if ( !ValidTrailer( ToAdvance) )
		{
			Trailers[i--] = Trailers[--iTrailer];
			Trailers[iTrailer] = Trailers[127];
			continue;
		}
		ToAdvance.SetLocation( Trailers[i].OldLoc);
		Trailers[i].bAdvanced = false;
	}

	bAdvanced = false;
}

//This function call occurs way too often.
//Keeping it as FINAL will speedup the call opcode
final function bool ValidAdvance( int i)
{
	if ( Advanced[i].Actor == none || Advanced[i].Actor.bDeleteMe )
		return false;
	if ( Projectile(Advanced[i].Actor) != none )
	{
		if ( Advanced[i].Actor.Role == ROLE_None || Advanced[i].Actor.Role == ROLE_AutonomousProxy ) //Fix SP's and players for now
			return false;
		if ( Advanced[i].Actor.Velocity == vect(0,0,0) ) //Projectile's stopped
			return false;
	}
	return true;
}
final function bool ValidTrailer( Actor Trailer)
{
	return (Trailer != none) && !Trailer.bDeleteMe
		&& (Trailer.Physics == PHYS_Trailer)
		&& (Trailer.Owner != none) && !Trailer.Owner.bDeleteMe;
}

//0 means pawns and projectiles
//1 means projectiles
//2 means none
function int AdvanceCode( Weapon Other)
{
	local int LCMode;

	if ( Other == none )
		return 0;
	if ( Other.Owner != none && Other.Owner.IsA('bbPlayer') ) //UTPURE PLAYER
	{
		if ( Left( string(Other.Name), 3) ~= "ST_" ) //This is a newnet weapon
			return 2;
	}
	if ( !Channel.bUseLC || !class'LCStatics'.static.IsLCWeapon(Other,LCMode) )
		return 0;
	return 1;
}

function RegisterAdvance( Actor Other)
{
	Advanced[iAdvance].Actor = Other;
	Advanced[iAdvance].OldLoc = Other.Location;
	if ( Pawn(Other) != none )
		Advanced[iAdvance].Rotation = Pawn(Other).ViewRotation;
	else
		Advanced[iAdvance].Rotation = Other.Rotation;
	iAdvance++;
}

function RegisterTrailer( Actor Other)
{
	Trailers[iTrailer].Actor = Other;
	Trailers[iTrailer].OldLoc = Other.Location;
	Trailers[iTrailer].Offset = Other.Location - Other.Owner.Location;
	iTrailer++;
}

defaultproperties
{
    RemoteRole=ROLE_None
    SmoothFactor=5.00
    DevFactor=(X=0.85,Y=0.85,Z=0.30)
}