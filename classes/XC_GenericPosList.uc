//
//  Generic position holder actor, designed for lag compensation
///////////////////////////////////////////////////////////////
class XC_GenericPosList expands XC_PosList;

var float STimeStamp[32];
var float ExtraDist[32];
var vector SavedLoc[32];
var int Flags[32];
//1 - Ghost
//2 - Duck
//4 - Teleported

var XC_GenericPosList PrevG, NextG;
var bool bPingHandicap;

state Active
{
	event BeginState()
	{
		UpdateNow();
	}
Begin:
	if ( Owner == none || Owner.bDeleteMe )
	{
		UnHook();
		Stop;
	}
	if ( Mutator.bUpdateGeneric )
		UpdateNow();
	Sleep(0.0);
	Goto('Begin');
}


function UpdateNow()
{
	local byte i, j;
	local int NewFlags;
	i = Mutator.GenericPos;
	j = (i - 1) & 0x1F; //32
	SavedLoc[i] = Owner.Location;
	ExtraDist[i] = VSize(Owner.Velocity) * 0.2;
	if ( !(Owner.bProjTarget && Owner.bCollideActors) )
		NewFlags = 1;
	if ( VSize( SavedLoc[i] - SavedLoc[j]) > 170 )
		NewFlags += 4;
	Flags[i] = NewFlags;
	STimeStamp[i] = Level.TimeSeconds;
	ActorSphere.X = Owner.CollisionHeight;
	ActorSphere.Y = Owner.CollisionRadius;
}

function UnHook()
{
	GotoState('');
	if ( PrevG == none )
	{
		if ( Mutator.ActiveGen == self )
		{
			Mutator.ActiveGen = NextG;
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
	NextG = Mutator.InActiveGen;
	PrevG = None;
	Mutator.InActiveGen = self;
	SetOwner(None);
	bPingHandicap = false;
}


//Top slot is the newer location of said segment
//This function is super optimized
function int FindTopSlot( float Delayed) //Time dilation must be applied to Delayed
{
	local byte i, j;
	local int count; //0-31... 32 is 0, and we can't return 31 due to requiring the next position

	Delayed *= Level.TimeDilation; //Because ping > real time is magnified otherwise
	j = Mutator.GenericPos; //UNDOCUMENTED > WE DON'T KNOW IF MASTER ALREADY TICKED

	ADVANCE:
	i = ByteDiff( j, count += 4 );
	if ( (Level.TimeSeconds - STimeStamp[i]) < Delayed )
	{
		if ( count < 28 )
			Goto ADVANCE;
		//Check the last row [29], or return 30-31 (new+old)
		i = ByteDiff( j, ++count);
		if ( (Level.TimeSeconds - STimeStamp[i]) > Delayed )
			return ByteDiff( j, count-1);
		return ByteDiff( j, 30); //Hardcoded
	}

	count -= 4;
	While ( (++count % 4) != 0 )
	{
		i = ByteDiff(j,count);
		if ( (Level.TimeSeconds - STimeStamp[i]) > Delayed )
			return ByteDiff(j,count-1);
	}
	return ByteDiff(j,count-1); //Means the %4 was the right one
}


function byte ByteDiff( byte bBase, int Diff)
{
	return (bBase - Diff) & 0x1F; //32
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
	return class'LCStatics'.static.GetAlpha( Delay * Level.TimeDilation, STimeStamp[Slot], STimeStamp[(Slot - 1) & 0x1F]);
}

function vector AlphaLoc( byte Slot, float Alpha)
{
	return class'LCStatics'.static.VLerp( Alpha, SavedLoc[Slot], SavedLoc[(Slot - 1) & 0x1F]);
}

function bool HasTeleported( byte Slot)
{
	return ((Flags[Slot] & 4) != 0);
}

function bool HasDucked( byte Slot)
{
	return ((Flags[Slot] & 2) != 0);
}



defaultproperties
{
	bHidden=True
	bCollideWhenPlacing=False
	RemoteRole=ROLE_None
}
