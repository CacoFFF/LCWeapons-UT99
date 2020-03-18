//
//  Base position holder actor, designed for lag compensation
/////////////////////////////////////////////////////////////
class XC_PosList expands Info;

var XC_LagCompensation Mutator;
var bool bClientAdvance;
var bool bPingHandicap;

var float StartingTimeSeconds; //Only consider shots originated at this time or later
var vector Position[32];
var vector Extent[32]; //X=radius, Z=height (VSize = Bounding Sphere)
var float EyeHeight[32];
var int Flags[32];
//1 - Ghost
//2 - Duck (deprecated)
//4 - Teleported


event PostBeginPlay()
{
	StartingTimeSeconds = Level.TimeSeconds;
}

event Tick( float DeltaTime)
{
	if ( Owner == None || Owner.bDeleteMe )
		Destroy();
	else if ( Mutator.bAddPosition )
		UpdateNow();
}

function UpdateNow() 
{
	local int OldIndex;
	local int NewFlags;
	
	Position[Mutator.PositionIndex] = Owner.Location;
	Extent[Mutator.PositionIndex].X = Owner.CollisionRadius + float(bPingHandicap);
	Extent[Mutator.PositionIndex].Z = Owner.CollisionHeight + float(bPingHandicap);
	if ( Pawn(Owner) != None )
		EyeHeight[Mutator.PositionIndex] = class'LCStatics'.static.GetEyeHeight( Pawn(Owner) );
	
	OldIndex = (Mutator.PositionIndex - 1) & 31;
	if ( !Owner.bCollideActors )
		NewFlags += 1;
	if ( VSize( Position[OldIndex] - Owner.Location) > 200 )
		NewFlags += 4;
	Flags[Mutator.PositionIndex] = NewFlags;
}


function vector GetExtent( int Index)
{
	return Extent[Index];
} 

function SetupCollision( float TraceTimeStamp, vector StartTrace, vector X, vector Y, vector Z)
{
	local int i, Index;
	local vector OldPosition, OldExtent;
	
	i = int(bClientAdvance);
	
	//Eliminate objects that cannot be hit.
	if ( (Flags[Mutator.Marker[i].Index] & 1) != 0 //Ghost = fail
	   || TraceTimeStamp < StartingTimeSeconds ) //Shooting before 'Start' = fail
	   return;
	
	OldPosition = GetOldPosition( Mutator.Marker[i].Index, Mutator.Marker[i].IndexNext, Mutator.Marker[i].Alpha );
	OldPosition -= StartTrace;
	
	//Eliminate OldPositions behind the trace
	if ( OldPosition dot X < 0 ) 
		return;

	//Eliminate anything too far from the line's orthogonal projection of said OldPosition.
	X.X = 0;
	X.Y = OldPosition dot Y;
	X.Z = OldPosition dot Z;
	OldExtent = Extent[Mutator.Marker[i].Index];
	if ( VSize(X) > VSize(OldExtent) ) 
		return;
		
	//Passed all checks
	OldPosition += StartTrace;
	SetCollisionSize( OldExtent.X, OldExtent.Z);
	SetLocation( OldPosition );
	SetCollision( true, false, false);
	bProjTarget = true;
	Tag = 'CollidingPosList';
}

function DisableCollision()
{
	Tag = '';
	SetCollision( false );
}


function vector GetOldPosition( int Index, int IndexNext, float Alpha)
{
	local bool bTeleported;
	local vector NextPosition;
	
	if ( IndexNext >= 0 )
	{
		bTeleported = (Flags[IndexNext] & 4) != 0;
		NextPosition = Position[IndexNext];
	}
	else
	{
		bTeleported = VSize( Position[Index] - Owner.Location ) > 200;
		NextPosition = Owner.Location;
	}

	if ( bTeleported )
	{
		if ( Alpha > 0.01 )
			Alpha = 1;
	}

	return class'LCStatics'.static.VLerp( Alpha, Position[Index], NextPosition);
}


//Additional distance to add to error checks
//In case of teleportation, treat as stationary
function vector GetVelocity( int Index, int IndexNext)
{
	local float Time;
	local bool bTeleported;
	local vector NextPosition;

	Time = Mutator.PositionTimeStamp[Index];
	if ( IndexNext >= 0 )
	{
		Time -= Mutator.PositionTimeStamp[IndexNext];
		bTeleported = (Flags[IndexNext] & 4) != 0;
		NextPosition = Position[IndexNext];
	}
	else
	{
		bTeleported = VSize( Position[Index] - Owner.Location ) > 200;
		NextPosition = Owner.Location;
	}
	if ( bTeleported )
		return vect(0,0,0);

	Time = fMax( Time, Mutator.PositionStep / 10.0);
	return (Position[Index] - NextPosition) / Time;
}


defaultproperties
{
	RemoteRole=ROLE_None
}