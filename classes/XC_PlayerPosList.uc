//
//  Player position holder actor, designed for lag compensation
///////////////////////////////////////////////////////////////
class XC_PlayerPosList expands Info;

var float STimeStamp[128];
//var float CTimeStamp[128];
var float ExtraDist[128];
var vector SavedLoc[128];
var int Flags[128];
//1 - Ghost
//2 - Duck
//4 - Teleported
var float LastDeathTimeStamp;

var XC_LagCompensation Master;
var XC_LagCompensator ffOwner;
var vector SizeVec;



event Tick( float DeltaTime)
{
	local byte i, j;
	local int NewFlags;

	i = Master.GlobalPos;
	j = (i - 1) % 128;
	SavedLoc[i] = ffOwner.ffOwner.Location;
	ExtraDist[i] = VSize(ffOwner.ffOwner.Velocity) * 0.2;
	if ( !(ffOwner.ffOwner.bProjTarget && ffOwner.ffOwner.bCollideActors) )
		NewFlags = 1;
	if ( ffOwner.ffOwner.BaseEyeHeight < 1 )
		NewFlags += 2;
	if ( VSize( SavedLoc[i] - SavedLoc[j]) > 170 )
		NewFlags += 4;
	Flags[i] = NewFlags;
	STimeStamp[i] = Level.TimeSeconds;
	SizeVec.X = ffOwner.CollisionHeight;
	SizeVec.Y = ffOwner.CollisionRadius;
}


//Top slot is the newer location of said segment
//This function is super optimized
function int FindTopSlot( private float ffDelayed) //Time dilation must be applied to ffDelayed
{
	local byte i, j;
	local int count; //0-127... 128 is 0, and we can't return 127 due to requiring the next position

	ffDelayed *= Level.TimeDilation; //Because ping > real time is magnified otherwise
	j = Master.GlobalPos; //UNDOCUMENTED > WE DON'T KNOW IF MASTER ALREADY TICKED

	ADVANCE:
	i = ByteDiff( j, count += 8 );
	if ( (Level.TimeSeconds - STimeStamp[i]) < ffDelayed )
	{
		if ( count < 120 )
			Goto ADVANCE;
		//Check the last row [121,125], or return 126-127 (new+old)
		While ( ++count < 127 )
		{
			i = ByteDiff( j, count);
			if ( (Level.TimeSeconds - STimeStamp[i]) > ffDelayed )
				return ByteDiff( j, count-1);
		}
		return ByteDiff( j, 126); //Hardcoded
	}

	count -= 8;
	While ( (++count % 8) != 0 )
	{
		i = ByteDiff(j,count);
		if ( (Level.TimeSeconds - STimeStamp[i]) > ffDelayed )
			return ByteDiff(j,count-1);
	}
	return ByteDiff(j,count-1); //Means the %8 was the right one
}


final function byte ByteDiff( byte bBase, int Diff)
{
	return (bBase - Diff) & 0x7F;	
}

final function float GetEDist( int Slot)
{
	return ExtraDist[Slot];
}

final function vector GetLoc( int Slot)
{
	return SavedLoc[Slot];
}

//Fix pause
function CorrectTimeStamp( float Offset)
{
	local int i;
	For ( i=0 ; i<128 ; i++ )
		STimeStamp[i] += Offset;
}


/*
//Returns an alpha location between said slot and its older
function vector DelayLoc( int Slot, float Delay)
{
	local byte i;
	
	Delay *= Level.TimeDilation;
	if ( (Level.TimeSeconds - STimeStamp[Slot]) > Delay )
		return SavedLoc[Slot];
	i = (Slot - 1) % 128;
	if ( (Level.TimeSeconds - STimeStamp[i]) < Delay )
		return SavedLoc[i];
	Delay -= Level.TimeSeconds - STimeStamp[Slot];
	Delay /= (STimeStamp[Slot] - STimeStamp[i]); //Now it's Alpha
	return SavedLoc[Slot] - (STimeStamp[Slot] - STimeStamp[i]) * Delay;
}
*/
function float AlphaSlots( byte Slot, float Delay)
{
	return class'LCStatics'.static.GetAlpha( Delay * Level.TimeDilation, STimeStamp[Slot], STimeStamp[byte(Slot - 1) % 128]);
}

function vector AlphaLoc( byte Slot, float Alpha)
{
	return class'LCStatics'.static.VLerp( Alpha, SavedLoc[Slot], SavedLoc[byte(Slot - 1) % 128]);
}

function bool HasTeleported( byte Slot)
{
	return ((Flags[Slot] & 4) != 0);
}

function bool HasDucked( byte Slot)
{
	return ((Flags[Slot] & 2) != 0);
}

function bool IsHittable( byte Slot, float ShotTimeStamp)
{
	return ((Flags[Slot] & 1) == 0) && (ShotTimeStamp >= LastDeathTimeStamp); //Equal preffered to avoid floating point truncation at high numbers
}

//TheLoc should be my past location
function bool CanHit( vector Start, vector TheLoc, vector X, vector Y, vector Z)
{
	TheLoc -= Start;
	if ( TheLoc dot X < 0 )
		return false;
	X.X = 0;
	X.Y = TheLoc dot Y;
	X.Z = TheLoc dot Z;
	return VSize(X) <= VSize(SizeVec);
}


defaultproperties
{
	bHidden=True
	bCollideWhenPlacing=False
	RemoteRole=ROLE_None
}
