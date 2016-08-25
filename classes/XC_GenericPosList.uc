//
//  Player position holder actor, designed for lag compensation
///////////////////////////////////////////////////////////////
class XC_GenericPosList expands Info;

var float STimeStamp[32];
//var float CTimeStamp[32];
var float ExtraDist[32];
var vector SavedLoc[32];
var int Flags[32];
//1 - Ghost
//2 - Duck
//4 - Teleported

var XC_LagCompensation Master;
var Actor Compensated;
var XC_GenericPosList PrevG, NextG;
var vector SizeVec;
var bool bPingHandicap;

state Active
{
	event BeginState()
	{
		UpdateNow();
	}
Begin:
	if ( Compensated == none || Compensated.bDeleteMe )
	{
		UnHook();
		Stop;
	}
	if ( Master.bUpdateGeneric )
		UpdateNow();
	Sleep(0.0);
	Goto('Begin');
}

//Used for Alpha
state Dummy
{
	event BeginState()
	{
		Compensated = self;
	}
Begin:
	if ( Master.bUpdateGeneric )
		UpdateNow();
	Sleep(0.0);
	Goto('Begin');
}




function UpdateNow()
{
	local byte i, j;
	local int NewFlags;
	i = Master.GenericPos;
	j = (i - 1) % 32;
	SavedLoc[i] = Compensated.Location;
	ExtraDist[i] = VSize(Compensated.Velocity) * 0.2;
	if ( !(Compensated.bProjTarget && Compensated.bCollideActors) )
		NewFlags = 1;
	if ( VSize( SavedLoc[i] - SavedLoc[j]) > 170 )
		NewFlags += 4;
	Flags[i] = NewFlags;
	STimeStamp[i] = Level.TimeSeconds;
	SizeVec.X = Compensated.CollisionHeight;
	SizeVec.Y = Compensated.CollisionRadius;
}

function UnHook()
{
	GotoState('');
	if ( PrevG == none )
	{
		if ( Master.ActiveGen == self )
		{
			Master.ActiveGen = NextG;
			if ( NextG != none )
				NextG.PrevG = none;
		}
		else
			Log("XC_GenericPosList erratic UnHook!!",'Bug');
	}
	else
	{
		PrevG.NextG = NextG;
		if ( NextG != none )
			NextG.PrevG = PrevG;
	}
	NextG = Master.InActiveGen;
	PrevG = none;
	Master.InActiveGen = self;
	Compensated = none;
	bPingHandicap = false;
}


//Top slot is the newer location of said segment
//This function is super optimized
function int FindTopSlot( private float ffDelayed) //Time dilation must be applied to ffDelayed
{
	local byte i, j;
	local int count; //0-31... 32 is 0, and we can't return 31 due to requiring the next position

	ffDelayed *= Level.TimeDilation; //Because ping > real time is magnified otherwise
	j = Master.GenericPos; //UNDOCUMENTED > WE DON'T KNOW IF MASTER ALREADY TICKED

	ADVANCE:
	i = ByteDiff( j, count += 4 );
	if ( (Level.TimeSeconds - STimeStamp[i]) < ffDelayed )
	{
		if ( count < 28 )
			Goto ADVANCE;
		//Check the last row [29], or return 30-31 (new+old)
		i = ByteDiff( j, ++count);
		if ( (Level.TimeSeconds - STimeStamp[i]) > ffDelayed )
			return ByteDiff( j, count-1);
		return ByteDiff( j, 30); //Hardcoded
	}

	count -= 4;
	While ( (++count % 4) != 0 )
	{
		i = ByteDiff(j,count);
		if ( (Level.TimeSeconds - STimeStamp[i]) > ffDelayed )
			return ByteDiff(j,count-1);
	}
	return ByteDiff(j,count-1); //Means the %4 was the right one
}


function byte ByteDiff( byte bBase, int Diff)
{
	return (bBase - Diff) % 32;	
}

function float GetEDist( int Slot)
{
	return ExtraDist[Slot];
}

function vector GetLoc( int Slot)
{
	return SavedLoc[Slot];
}

//Fix pause
function CorrectTimeStamp( float Offset)
{
	local int i;
	For ( i=0 ; i<32 ; i++ )
		STimeStamp[i] += Offset;
}

function float AlphaSlots( byte Slot, float Delay)
{
	return class'LCStatics'.static.GetAlpha( Delay * Level.TimeDilation, STimeStamp[Slot], STimeStamp[byte(Slot - 1) % 32]);
}

function vector AlphaLoc( byte Slot, float Alpha)
{
	return class'LCStatics'.static.VLerp( Alpha, SavedLoc[Slot], SavedLoc[byte(Slot - 1) % 32]);
}

function bool HasTeleported( byte Slot)
{
	return ((Flags[Slot] & 4) != 0);
}

function bool HasDucked( byte Slot)
{
	return ((Flags[Slot] & 2) != 0);
}

//TheLoc should be my past location
function bool CanHit( vector Start, vector TheLoc, vector X, vector Y, vector Z)
{
	TheLoc -= Start;
	if ( VSize( TheLoc) > VSize( TheLoc + 5*X) )
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
